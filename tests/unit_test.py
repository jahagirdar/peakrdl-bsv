"""Unit tests for the BSV generators.

These tests compile small inline RDL snippets and assert structural
properties of the generated Bluespec code. They only use the public
systemrdl-compiler API and run without a Bluespec compiler.
"""
import io
import re
import textwrap

import pytest
from systemrdl import RDLCompiler, RDLWalker

from peakrdl_bsv.print_bsv_csr import PrintBSVCSR
from peakrdl_bsv.print_bsv_reg import PrintBSVReg
from peakrdl_bsv.print_bsv_signal import PrintBSVSignal


def generate(rdl_text, tmp_path, default_regwidth=None, test=False):
    """Compile RDL text and return the generated signal/reg/csr BSV text."""
    rdl = tmp_path / "test.rdl"
    rdl.write_text(textwrap.dedent(rdl_text))
    rdlc = RDLCompiler()
    rdlc.compile_file(str(rdl))
    root = rdlc.elaborate()
    out = {}
    for key, cls in (
        ("signal", PrintBSVSignal),
        ("reg", PrintBSVReg),
        ("csr", PrintBSVCSR),
    ):
        buf = io.StringIO()
        RDLWalker(unroll=True).walk(root, cls(buf, test, default_regwidth))
        out[key] = buf.getvalue()
    return out


CTRL_RDL = """\
    addrmap top {
        reg {
            field {sw=rw; hw=r;} mode[3:0]=5;
            field {sw=r; hw=w;} status[7:4]=0;
            field {sw=w; hw=r;} cmd[11:8]=0;
        } ctrl;
    };
"""


@pytest.fixture(scope="module")
def ctrl(tmp_path_factory):
    return generate(CTRL_RDL, tmp_path_factory.mktemp("ctrl"))


def test_minimal_rdl_no_explicit_properties(tmp_path):
    """RDL relying on spec defaults must not crash (issue-6 class of bug)
    and must fall back to the spec default regwidth of 32."""
    out = generate("addrmap top { reg { field {} f; } myreg; };", tmp_path)
    assert "Bit#(32)" in out["reg"]
    assert "Bit#(32)" in out["csr"]


def test_default_regwidth_option(tmp_path):
    """The default_regwidth option applies when the RDL sets no regwidth."""
    out = generate(
        "addrmap top { reg { field {} f[7:0]; } myreg; };",
        tmp_path,
        default_regwidth=16,
    )
    assert "Bit#(16)" in out["reg"]


def test_explicit_regwidth_wins(tmp_path):
    """An explicit regwidth beats the default_regwidth option."""
    out = generate(
        "addrmap top { reg { regwidth=64; field {} f[7:0]; } myreg; };",
        tmp_path,
        default_regwidth=16,
    )
    assert "Bit#(64)" in out["reg"]
    assert "Bit#(16)" not in out["reg"]


def test_reset_value_in_instantiation(ctrl):
    """Field reset values must be passed to the signal module instantiation."""
    assert "mkCSRSignal_ctrl_mode(5)" in ctrl["reg"]


def test_missing_reset_defaults_to_zero(tmp_path):
    out = generate("addrmap top { reg { field {} f[3:0]; } r1; };", tmp_path)
    assert "mkCSRSignal_r1_f(0)" in out["reg"]


def test_sw_readonly_field_has_no_bus_write(ctrl):
    """sw=r fields expose no bus write method and no write dispatch."""
    sw_ifc = re.search(
        r"interface SW_ctrl_status;(.*?)endinterface",
        ctrl["signal"],
        re.S,
    ).group(1)
    assert "method Action write" not in sw_ifc
    assert "sig_status.bus.write" not in ctrl["reg"]


def test_sw_writeonly_field_has_no_bus_read(ctrl):
    """sw=w fields expose no bus read method and no read dispatch."""
    sw_ifc = re.search(
        r"interface SW_ctrl_cmd;(.*?)endinterface",
        ctrl["signal"],
        re.S,
    ).group(1)
    assert "method ActionValue" not in sw_ifc
    assert "var_cmd<-sig_cmd.bus.read" not in ctrl["reg"]


def test_hw_writable_field_has_hw_write(ctrl):
    """hw=w fields get a HW _write method."""
    module = re.search(
        r"module mkCSRSignal_ctrl_status.*?endmodule",
        ctrl["signal"],
        re.S,
    ).group(0)
    assert "method Action _write" in module


def test_rclr_clears_on_read(tmp_path):
    out = generate(
        "addrmap top { reg { field {rclr; hw=w;} err[0:0]=0; } r1; };",
        tmp_path,
    )
    read_method = re.search(
        r"method ActionValue.*?read;(.*?)endmethod",
        out["signal"],
        re.S,
    ).group(1)
    assert "pw_clear.send()" in read_method


def test_woclr_clears_written_ones(tmp_path):
    """woclr clears exactly the bits written as 1 (per-bit, any width)."""
    out = generate(
        "addrmap top { reg { field {sw=rw; woclr; hw=w;} intr[0:0]=0; } r1; };",
        tmp_path,
    )
    assert re.search(r"rr = rr & ~wdata;", out["signal"])


def test_woset_sets_written_ones(tmp_path):
    out = generate(
        "addrmap top { reg { field {sw=rw; woset; hw=r;} go[0:0]=0; } r1; };",
        tmp_path,
    )
    assert re.search(r"rr = rr \| wdata;", out["signal"])


def test_singlepulse_has_pulse_method(tmp_path):
    out = generate(
        "addrmap top { reg { field {singlepulse; hw=r;} start[0:0]=0; } r1; };",
        tmp_path,
    )
    assert "method Bool pulse()" in out["signal"]


def test_counter_has_incr_decr(tmp_path):
    # incrwidth/decrwidth explicitly configure both directions; a bare
    # `counter;` alone is increment-only (see claude1_test.py's
    # TestCounter for the bare-counter and bidirectional cases).
    out = generate(
        """\
        addrmap top { reg {
            field {sw=r; hw=r; counter; incrwidth=4; decrwidth=4;} count[3:0]=0;
        } r1; };""",
        tmp_path,
    )
    assert "method Action incr" in out["signal"]
    assert "method Action decr" in out["signal"]


def test_reg_instantiations_match_signal_definitions(ctrl):
    """Every module instantiated by the reg file is defined in the signal file."""
    instantiated = set(re.findall(r"<- (mkCSRSignal_\w+)\(", ctrl["reg"]))
    defined = set(re.findall(r"module (mkCSRSignal_\w+)#", ctrl["signal"]))
    assert instantiated, "expected at least one signal instantiation"
    assert instantiated <= defined


def test_csr_address_decode(tmp_path):
    """The CSR module must decode each register at its address offset."""
    out = generate(
        """\
        addrmap top {
            reg { field {} f; } r1 @0x0;
            reg { field {} f; } r2 @0x8;
        };""",
        tmp_path,
    )
    assert re.search(r"address_r1 = 0;", out["csr"])
    assert re.search(r"address_r2 = 8;", out["csr"])
    assert "if(address== address_r2)reg_r2.bus.write" in out["csr"]
    assert "if(address== address_r2)rv<-reg_r2.bus.read()" in out["csr"]


def test_gentest_wrapper(tmp_path):
    """test=True emits a synthesizable test wrapper per signal."""
    out = generate(
        "addrmap top { reg { field {} f; } r1; };",
        tmp_path,
        test=True,
    )
    assert "(*synthesize*)" in out["signal"]
    assert "module testcsrreg_r1_f" in out["signal"]
