"""Per-feature tests for the BSV generator against SystemRDL 2.0.

Two layers of checking:

1. Semantic assertions on the generated Bluespec text for every supported
   field property and structural construct.
2. If the Bluespec compiler (bsc) is installed, every feature snippet is
   additionally elaborated with bsc, so the generated code is known to be
   legal BSV, not just plausible-looking text.

Features the generator does NOT model (ruser/wuser -- these require full
external-register bus forwarding, a different architecture entirely --
and write-once enforcement) must produce an explicit warning instead of
silently wrong RTL.
"""
import logging
import re
import shutil
import subprocess
import textwrap

import pytest
from systemrdl import RDLCompiler, RDLWalker

from peakrdl_bsv.print_bsv_csr import PrintBSVCSR
from peakrdl_bsv.print_bsv_reg import PrintBSVReg
from peakrdl_bsv.print_bsv_signal import PrintBSVSignal

BSC = shutil.which("bsc") or "/opt/tools/bsc/bin/bsc"
HAS_BSC = shutil.which("bsc") is not None or shutil.os.path.exists(BSC)


def reg_rdl(field_body):
    """Wrap one or more field declarations into a single-register addrmap."""
    return f"addrmap top {{ reg {{ {field_body} }} r1; }};"


FIELD_FEATURES = {
    # --- sw/hw access combinations ---
    "sw_rw_hw_r": "field {sw=rw; hw=r;} f[7:0]=0;",
    "sw_rw_hw_rw": "field {sw=rw; hw=rw; we;} f[7:0]=0;",
    "sw_rw_hw_na": "field {sw=rw; hw=na;} f[7:0]=0;",
    "sw_r_hw_w": "field {sw=r; hw=w;} f[7:0]=0;",
    "sw_r_hw_r_constant": "field {sw=r; hw=r;} f[7:0]=1;",
    "sw_w_hw_r": "field {sw=w; hw=r;} f[7:0]=0;",
    "sw_w1_hw_r": "field {sw=w1; hw=r;} f[7:0]=0;",
    "sw_rw1_hw_r": "field {sw=rw1; hw=r;} f[7:0]=0;",
    # --- onread side effects ---
    "rclr": "field {rclr; hw=w;} f[7:0]=0;",
    "rset": "field {rset; hw=w;} f[7:0]=0;",
    # --- onwrite side effects ---
    "woclr": "field {sw=rw; woclr; hw=w;} f[7:0]=0;",
    "woset": "field {sw=rw; woset; hw=w;} f[7:0]=0;",
    "wclr": "field {sw=rw; onwrite=wclr; hw=r;} f[7:0]=0;",
    "wset": "field {sw=rw; onwrite=wset; hw=r;} f[7:0]=0;",
    "wot": "field {sw=rw; onwrite=wot; hw=r;} f[7:0]=0;",
    "wzc": "field {sw=rw; onwrite=wzc; hw=r;} f[7:0]=0;",
    "wzs": "field {sw=rw; onwrite=wzs; hw=r;} f[7:0]=0;",
    # --- other field properties ---
    "singlepulse": "field {singlepulse; hw=r;} f[0:0]=0;",
    "swacc": "field {sw=rw; hw=r; swacc;} f[7:0]=0;",
    "swmod": "field {sw=rw; hw=r; swmod;} f[7:0]=0;",
    "swmod_rclr": "field {rclr; hw=w; swmod;} f[7:0]=0;",
    "swmod_rset": "field {rset; hw=w; swmod;} f[7:0]=0;",
    "swmod_woclr": "field {sw=rw; woclr; hw=w; swmod;} f[7:0]=0;",
    "hwset": "field {sw=r; hw=r; hwset;} f[0:0]=0;",
    "hwclr": "field {sw=r; hw=r; hwclr;} f[0:0]=0;",
    "counter": "field {sw=r; hw=r; counter;} f[7:0]=0;",
    "reductions": "field {sw=rw; hw=r; anded; ored; xored;} f[7:0]=0;",
    "intr": "field {intr; sw=rw; woclr; hw=w;} f[0:0]=0;",
    "intr_posedge": "field {posedge intr; sw=rw; woclr; hw=w;} f[0:0]=0;",
    "intr_multi_field": (
        "field {sw=rw; hw=w; woclr; intr;} f0[7:0]=0; "
        "field {sw=rw; hw=w; woclr; intr;} f1[15:8]=0;"
    ),
    "sticky": "field {sw=rw; hw=w; sticky;} f[7:0]=0;",
    "stickybit": "field {sw=rw; hw=w; stickybit;} f[0:0]=0;",
    "multifield": "field {sw=rw; hw=r;} a[3:0]=1; field {sw=rw; hw=r;} b[15:8]=2;",
    # --- precedence ---
    "precedence_hw": "field {sw=rw; hw=rw; precedence=hw;} f[7:0]=0;",
    "precedence_sw": "field {sw=rw; hw=rw; precedence=sw;} f[7:0]=0;",
    # --- counter refinements (bare `counter` is covered above) ---
    "incrvalue": "field {sw=r; hw=r; counter; incrvalue=5;} f[7:0]=0;",
    "decrvalue": "field {sw=r; hw=r; counter; decrvalue=3;} f[7:0]=0;",
    "incrwidth": "field {sw=r; hw=r; counter; incrwidth=4;} f[7:0]=0;",
    "decrwidth": "field {sw=r; hw=r; counter; decrwidth=4;} f[7:0]=0;",
    "incrsaturate": "field {sw=r; hw=r; counter; incrsaturate;} f[7:0]=0;",
    "decrsaturate": "field {sw=r; hw=r; counter; decrsaturate;} f[7:0]=0;",
    "incrsaturate_value": "field {sw=r; hw=r; counter; incrsaturate=200;} f[7:0]=0;",
    "incrthreshold": "field {sw=r; hw=r; counter; incrthreshold=200;} f[7:0]=0;",
    "overflow": "field {sw=r; hw=r; counter; overflow;} f[7:0]=0;",
    "underflow": "field {sw=r; hw=r; counter; underflow;} f[7:0]=0;",
    "bidirectional_counter": (
        "field {sw=r; hw=r; counter; incrwidth=8; decrwidth=8;} f[7:0]=0;"
    ),
}

STRUCT_FEATURES = {
    "two_regs": """\
        addrmap top {
            reg { field {sw=rw; hw=r;} f[7:0]=0; } r1 @0x0;
            reg { field {sw=rw; hw=r;} f[7:0]=0; } r2 @0x4;
        };""",
    "regwidth_64": "addrmap top { reg { regwidth=64; field {sw=rw; hw=r;} f[63:0]=0; } r1; };",
    "regwidth_8": "addrmap top { default regwidth=8; reg { field {sw=rw; hw=r;} f[7:0]=0; } r1; };",
    "spec_default_regwidth": "addrmap top { reg { field {} f; } r1; };",
    "reg_array": "addrmap top { reg { field {sw=rw; hw=r;} f[7:0]=0; } r1[4]; };",
    "regfile": "addrmap top { regfile { reg { field {sw=rw; hw=r;} f[7:0]=0; } inner; } rf; };",
    "regfile_array": "addrmap top { regfile { reg { field {sw=rw; hw=r;} f[7:0]=0; } inner; } rf[2]; };",
    "nested_addrmap": """\
        addrmap sub { reg { field {sw=rw; hw=r;} f[7:0]=0; } r1; };
        addrmap top { sub s1; };""",
    "memory": "addrmap top { reg { field {sw=rw; hw=r;} f[7:0]=0; } r1; external mem { mementries=16; memwidth=32; sw=rw; } m1; };",
    "external_reg": "addrmap top { external reg { field {sw=rw; hw=rw;} f[7:0]=0; } r1; };",
    # --- properties whose value is an external `signal` reference (the
    # only dynamic form these resolve -- see common.resolve_signal_ref)
    # -- these need addrmap-level `signal {}` declarations, which the
    # single-field-body FIELD_FEATURES/reg_rdl() wrapper has no slot for.
    "we_signal": "addrmap top { signal {} we_sig; reg { field {sw=rw; hw=rw; we=we_sig;} f[7:0]=0; } r1; };",
    "wel_signal": "addrmap top { signal {} wel_sig; reg { field {sw=rw; hw=rw; wel=wel_sig;} f[7:0]=0; } r1; };",
    "swwe_signal": "addrmap top { signal {} swwe_sig; reg { field {sw=rw; hw=rw; swwe=swwe_sig;} f[7:0]=0; } r1; };",
    "swwel_signal": "addrmap top { signal {} swwel_sig; reg { field {sw=rw; hw=rw; swwel=swwel_sig;} f[7:0]=0; } r1; };",
    "hwenable_signal": "addrmap top { signal {} en_sig[8]; reg { field {sw=rw; hw=rw; hwenable=en_sig;} f[7:0]=0; } r1; };",
    "hwmask_signal": "addrmap top { signal {} mask_sig[8]; reg { field {sw=rw; hw=rw; hwmask=mask_sig;} f[7:0]=0; } r1; };",
    "next_signal": "addrmap top { signal {} next_sig[8]; reg { field {sw=r; hw=rw; next=next_sig;} f[7:0]=0; } r1; };",
    "resetsignal_activehigh": "addrmap top { signal {activehigh;} rst_sig; reg { field {sw=rw; hw=r; resetsignal=rst_sig;} f[7:0]=0; } r1; };",
    "resetsignal_activelow": "addrmap top { signal {activelow;} rst_sig; reg { field {sw=rw; hw=r; resetsignal=rst_sig;} f[7:0]=0; } r1; };",
    "intr_enable": "addrmap top { signal {} en_sig[8]; reg { field {sw=rw; hw=w; woclr; intr; enable=en_sig;} f[7:0]=0; } r1; };",
    "intr_mask": "addrmap top { signal {} mask_sig[8]; reg { field {sw=rw; hw=w; woclr; intr; mask=mask_sig;} f[7:0]=0; } r1; };",
    "intr_haltenable": "addrmap top { signal {} halt_sig[8]; reg { field {sw=rw; hw=w; woclr; intr; haltenable=halt_sig;} f[7:0]=0; } r1; };",
    "intr_haltmask": "addrmap top { signal {} halt_sig[8]; reg { field {sw=rw; hw=w; woclr; intr; haltmask=halt_sig;} f[7:0]=0; } r1; };",
}

ALL_FEATURES = {**{k: reg_rdl(v) for k, v in FIELD_FEATURES.items()}, **STRUCT_FEATURES}


def generate(rdl_text, tmp_path, default_regwidth=32):
    """Generate the three BSV files; returns their text keyed by suffix."""
    rdl = tmp_path / "test.rdl"
    rdl.write_text(textwrap.dedent(rdl_text))
    rdlc = RDLCompiler()
    rdlc.compile_file(str(rdl))
    root = rdlc.elaborate()
    out = {}
    for suffix, cls in (
        ("signal", PrintBSVSignal),
        ("reg", PrintBSVReg),
        ("csr", PrintBSVCSR),
    ):
        path = tmp_path / f"top_{suffix}.bsv"
        with open(path, "w") as f:
            RDLWalker(unroll=True).walk(root, cls(f, False, default_regwidth))
        out[suffix] = path.read_text()
    return out


def gen_field(field_body, tmp_path):
    return generate(reg_rdl(field_body), tmp_path)


def module_body(signal_text, module="mkCSRSignal_r1_f"):
    """Extract one signal module's implementation (interface declarations at
    the top of the file share the same method signatures, so all method
    searches must be scoped to the module body)."""
    return re.search(rf"module {module}#.*?endmodule", signal_text, re.S).group(0)


def rule_body(signal_text, module="mkCSRSignal_r1_f"):
    """Extract the r_write rule body of a signal module."""
    return re.search(
        r"rule r_write;(.*?)endrule", module_body(signal_text, module), re.S
    ).group(1)


def sw_write_method(signal_text):
    return re.search(
        r"method Action write\(Bit.*?endmethod", module_body(signal_text), re.S
    ).group(0)


def sw_read_method(signal_text):
    return re.search(
        r"method ActionValue#\(Bit#\(\d+\)\) read;.*?endmethod",
        module_body(signal_text),
        re.S,
    ).group(0)


# ---------------------------------------------------------------------------
# bsc elaboration: gold-standard legality check for every feature
# ---------------------------------------------------------------------------


@pytest.mark.skipif(not HAS_BSC, reason="Bluespec compiler not available")
@pytest.mark.parametrize("feature", sorted(ALL_FEATURES))
def test_bsc_elaborates(feature, tmp_path):
    generate(ALL_FEATURES[feature], tmp_path)
    (tmp_path / "bo").mkdir()
    for suffix in ("signal", "reg", "csr"):
        result = subprocess.run(
            [BSC, "-bdir", "bo", "-elab", f"top_{suffix}.bsv"],
            cwd=tmp_path,
            capture_output=True,
            text=True,
            timeout=120,
        )
        assert result.returncode == 0, (
            f"bsc failed on top_{suffix}.bsv for feature {feature}:\n"
            f"{result.stdout}\n{result.stderr}"
        )


# ---------------------------------------------------------------------------
# onwrite semantics
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("rdl_prop", "expr"),
    [
        ("woclr", r"rr = rr & ~wdata;"),
        ("woset", r"rr = rr \| wdata;"),
        ("wot", r"rr = rr \^ wdata;"),
        ("wzc", r"rr = rr & \(tpl_1\(v\) \| ~tpl_2\(v\)\);"),
        ("wzs", r"rr = rr \| \(~tpl_1\(v\) & tpl_2\(v\)\);"),
        ("wclr", r"rr = 0;"),
        ("wset", r"rr = ~0;"),
    ],
)
def test_onwrite_write_effect(rdl_prop, expr, tmp_path):
    """Each onwrite policy applies its per-bit write function in the rule."""
    out = gen_field(f"field {{sw=rw; onwrite={rdl_prop}; hw=w;}} f[7:0]=0;", tmp_path)
    body = rule_body(out["signal"])
    assert re.search(expr, body), f"onwrite={rdl_prop} missing effect {expr}:\n{body}"
    # The plain read/write store must NOT also apply.
    assert not re.search(r"rr = \(wdata \| \(~tpl_2\(v\) & rr\)\);", body)


def test_onwrite_none_is_masked_store(tmp_path):
    """A plain rw field stores data under the write-strobe mask."""
    out = gen_field("field {sw=rw; hw=r;} f[7:0]=0;", tmp_path)
    assert re.search(
        r"rr = \(wdata \| \(~tpl_2\(v\) & rr\)\);", rule_body(out["signal"])
    )


def test_onwrite_shorthand_equals_longhand(tmp_path):
    """`woclr;` and `onwrite=woclr;` must generate identical code."""
    d1 = tmp_path / "short"
    d2 = tmp_path / "long"
    d1.mkdir()
    d2.mkdir()
    short = gen_field("field {sw=rw; woclr; hw=w;} f[7:0]=0;", d1)
    long = gen_field("field {sw=rw; onwrite=woclr; hw=w;} f[7:0]=0;", d2)
    assert rule_body(short["signal"]) == rule_body(long["signal"])
    assert sw_write_method(short["signal"]) == sw_write_method(long["signal"])


# ---------------------------------------------------------------------------
# onread semantics
# ---------------------------------------------------------------------------


def test_rclr_clears_on_read_only(tmp_path):
    out = gen_field("field {rclr; hw=w;} f[7:0]=0;", tmp_path)
    read = sw_read_method(out["signal"])
    assert "pw_clear.send()" in read
    assert "pw_set.send()" not in read


def test_rset_sets_all_ones_on_read(tmp_path):
    out = gen_field("field {rset; hw=w;} f[7:0]=0;", tmp_path)
    read = sw_read_method(out["signal"])
    assert "pw_set.send()" in read
    # rset drives the field to all-ones, not to 1.
    assert re.search(r"else if\(pw_set\) rr = ~0;", rule_body(out["signal"]))


def test_onread_shorthand_equals_longhand(tmp_path):
    d1 = tmp_path / "short"
    d2 = tmp_path / "long"
    d1.mkdir()
    d2.mkdir()
    short = gen_field("field {rclr; hw=w;} f[7:0]=0;", d1)
    long = gen_field("field {onread=rclr; hw=w;} f[7:0]=0;", d2)
    assert sw_read_method(short["signal"]) == sw_read_method(long["signal"])


# ---------------------------------------------------------------------------
# swacc / swmod
# ---------------------------------------------------------------------------


def test_swacc_fires_on_read_and_write(tmp_path):
    out = gen_field("field {sw=rw; hw=r; swacc;} f[7:0]=0;", tmp_path)
    assert "pw_swacc.send()" in sw_write_method(out["signal"])
    assert "pw_swacc.send()" in sw_read_method(out["signal"])
    assert "method Bool swacc()" in out["signal"]


@pytest.mark.parametrize(
    ("field", "mod_expr"),
    [
        (
            "field {sw=rw; hw=r; swmod;} f[7:0]=0;",
            r"mod=\(\(data & wstrb\)!=\(r & wstrb\)\);",
        ),
        (
            "field {sw=rw; woclr; hw=w; swmod;} f[7:0]=0;",
            r"mod=\(\(r & data & wstrb\)!=0\);",
        ),
        (
            "field {sw=rw; woset; hw=w; swmod;} f[7:0]=0;",
            r"mod=\(\(~r & data & wstrb\)!=0\);",
        ),
    ],
)
def test_swmod_on_write(field, mod_expr, tmp_path):
    """swmod pulses only when the write actually modifies the field."""
    out = gen_field(field, tmp_path)
    write = sw_write_method(out["signal"])
    assert re.search(mod_expr, write), write
    assert "pw_swmod.send()" in write


@pytest.mark.parametrize(
    ("field", "mod_expr"),
    [
        ("field {rclr; hw=w; swmod;} f[7:0]=0;", r"mod=\(r!=0\);"),
        ("field {rset; hw=w; swmod;} f[7:0]=0;", r"mod=\(r!= ~0\);"),
    ],
)
def test_swmod_on_destructive_read(field, mod_expr, tmp_path):
    out = gen_field(field, tmp_path)
    read = sw_read_method(out["signal"])
    assert re.search(mod_expr, read), read
    assert "pw_swmod.send()" in read


# ---------------------------------------------------------------------------
# hw-side properties
# ---------------------------------------------------------------------------


def test_hwset_hwclr_methods(tmp_path):
    out = gen_field("field {sw=r; hw=r; hwset; hwclr;} f[0:0]=0;", tmp_path)
    sig = module_body(out["signal"])
    hwset = re.search(r"method Action hwset\(\);(.*?)endmethod", sig, re.S).group(1)
    hwclr = re.search(r"method Action hwclr\(\);(.*?)endmethod", sig, re.S).group(1)
    assert "pw_set.send()" in hwset
    assert "pw_clear.send()" in hwclr


def test_hw_clear_beats_set_beats_sw_write(tmp_path):
    """Rule priority: clear, then set, then sw write, then hw write."""
    out = gen_field("field {sw=rw; hw=rw; we; hwset; hwclr;} f[0:0]=0;", tmp_path)
    body = rule_body(out["signal"])
    order = [
        body.index("if(pw_clear)"),
        body.index("else if(pw_set)"),
        body.index("else if(sw_wdata.wget"),
        body.index("else if(hw_wdata.wget"),
    ]
    assert order == sorted(order)


def test_counter_incr_decr(tmp_path):
    # incrwidth/decrwidth explicitly configure both directions in the
    # count-argument form; a bare `counter;` alone is increment-only with
    # a fixed-amount pulse (see test_bare_counter_is_increment_only in
    # claude1_test.py).
    out = gen_field(
        "field {sw=r; hw=r; counter; incrwidth=8; decrwidth=8;} f[7:0]=0;", tmp_path
    )
    sig = out["signal"]
    assert "method Action incr" in sig
    assert "method Action decr" in sig
    assert re.search(r"rr = r \+ amt;", rule_body(sig))
    assert re.search(r"rr = r - amt;", rule_body(sig))


def test_reductions(tmp_path):
    out = gen_field("field {sw=rw; hw=r; anded; ored; xored;} f[7:0]=0;", tmp_path)
    sig = out["signal"]
    assert re.search(r"return &r==1;", sig)
    assert re.search(r"return \|r==1;", sig)
    assert re.search(r"return \^r==1;", sig)


def test_singlepulse(tmp_path):
    out = gen_field("field {singlepulse; hw=r;} f[0:0]=0;", tmp_path)
    sig = out["signal"]
    assert "method Bool pulse()" in sig
    # The field self-clears every cycle unless rewritten.
    assert re.search(r"rr = 0;\s*\n\s*if\(pw_clear\)", rule_body(sig))


# ---------------------------------------------------------------------------
# unsupported features must warn, not silently generate wrong RTL
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "rdl",
    [
        # ruser/wuser are only legal on external instances per the spec.
        "addrmap top { external reg { field {sw=rw; onread=ruser; hw=w;} f[7:0]=0; } r1; };",
        "addrmap top { external reg { field {sw=rw; onwrite=wuser; hw=r;} f[7:0]=0; } r1; };",
        reg_rdl("field {sw=w1; hw=r;} f[7:0]=0;"),
        reg_rdl("field {sw=rw1; hw=r;} f[7:0]=0;"),
    ],
    ids=["ruser", "wuser", "w1", "rw1"],
)
def test_unsupported_field_property_warns(rdl, tmp_path, caplog):
    with caplog.at_level(logging.WARNING, logger="peakrdl_bsv.print_bsv_signal"):
        generate(rdl, tmp_path)
    assert any("not supported" in m or "not enforced" in m for m in caplog.messages)


def test_external_reg_warns(tmp_path, caplog):
    with caplog.at_level(logging.WARNING, logger="peakrdl_bsv.print_bsv_signal"):
        generate(STRUCT_FEATURES["external_reg"], tmp_path)
    assert any("external" in m for m in caplog.messages)


def test_memory_warns_and_generates(tmp_path, caplog):
    with caplog.at_level(logging.WARNING, logger="peakrdl_bsv.print_bsv_csr"):
        out = generate(STRUCT_FEATURES["memory"], tmp_path)
    assert any("memories are not supported" in m for m in caplog.messages)
    # The register part of the map must still be generated.
    assert "mkConfigCSR_top" in out["csr"]


# ---------------------------------------------------------------------------
# structure: arrays, regfiles, nested addrmaps
# ---------------------------------------------------------------------------


def test_reg_array_instances(tmp_path):
    out = generate(STRUCT_FEATURES["reg_array"], tmp_path)
    for i in range(4):
        assert f"module mkCSRSignal_r1_{i}_f#" in out["signal"]
        assert f"module mkConfigReg_r1_{i}(" in out["reg"]
    # Each element decodes at its own address.
    offsets = re.findall(r"address_r1_(\d) = (\d+);", out["csr"])
    assert {(i, o) for i, o in offsets} == {
        ("0", "0"),
        ("1", "4"),
        ("2", "8"),
        ("3", "12"),
    }
    assert "[" not in re.search(r"interface SW_\S+;", out["signal"]).group(0)


def test_regfile_naming(tmp_path):
    out = generate(STRUCT_FEATURES["regfile"], tmp_path)
    assert "module mkCSRSignal_rf_inner_f#" in out["signal"]
    assert "module mkConfigReg_rf_inner(" in out["reg"]
    assert re.search(r"address_rf_inner = 0;", out["csr"])


def test_regfile_array_unique_names(tmp_path):
    out = generate(STRUCT_FEATURES["regfile_array"], tmp_path)
    assert "module mkConfigReg_rf_0_inner(" in out["reg"]
    assert "module mkConfigReg_rf_1_inner(" in out["reg"]


def test_nested_addrmap_flattened(tmp_path):
    out = generate(STRUCT_FEATURES["nested_addrmap"], tmp_path)
    # One import of the top signal package only.
    assert out["reg"].count("import") == 1
    assert "import top_signal::*;" in out["reg"]
    # The nested register is folded into the single top CSR module.
    assert out["csr"].count("module mkConfigCSR_") == 1
    assert "module mkConfigCSR_top(" in out["csr"]
    assert re.search(r"address_s1_r1 = 0;", out["csr"])


def test_two_regs_address_decode(tmp_path):
    out = generate(STRUCT_FEATURES["two_regs"], tmp_path)
    assert re.search(r"address_r1 = 0;", out["csr"])
    assert re.search(r"address_r2 = 4;", out["csr"])


def test_reg_name_collision_avoided_across_scopes(tmp_path):
    """Registers with the same instance name in different scopes stay distinct."""
    rdl = """\
        addrmap sub { reg { field {sw=rw; hw=r;} f[7:0]=0; } ctrl; };
        addrmap top {
            reg { field {sw=rw; hw=r;} f[7:0]=0; } ctrl;
            sub s1;
            sub s2;
        };"""
    out = generate(rdl, tmp_path)
    for name in ("mkConfigReg_ctrl(", "mkConfigReg_s1_ctrl(", "mkConfigReg_s2_ctrl("):
        assert f"module {name}" in out["reg"]
