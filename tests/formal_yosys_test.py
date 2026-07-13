"""Yosys sequential-equivalence-checking (SEC) side of the formal-audit migration.

This is a SECOND, independent proof method that was run against a
SUBSET of the 48 field-property configs covered by
tests/formal_regression_test.py (BlueCheck randomized equivalence
testing). Where BlueCheck compares the blind reference against the real
generator's RTL via randomized simulation, this suite compares the same
two sides via Yosys `equiv_induct`/`equiv_status` sequential-equivalence
checking (a SAT/BDD-based proof, not simulation) -- a second, differently
-shaped confirmation of the same behavioral-equivalence claim.

Scope: see tests/formal/README.md's "Yosys SEC scope" section for the
full, honest accounting of which 33 of the 48 configs actually have real
Yosys artifacts to migrate (NOT all 48, and NOT the 36 originally assumed
before the scratch directories were actually inspected -- three
apparently-covered round-1 directories turned out to be empty).

For each config in YOSYS_CONFIGS, this test:
  1. Regenerates the real gate-side RTL via the same `peakrdl bsv` CLI
     step used by tests/formal_regression_test.py, but with `--test
     True` so the exporter also emits the single-field synthesizable
     top `testcsrreg_reg0_field0` (needed for `bsc -verilog`; the
     BlueCheck driver doesn't need this since it never calls `bsc
     -verilog`).
  2. `bsc -verilog`-compiles the gold side: either
     tests/formal/yosys_gold/<Config>/Gold<Config>.bsv (a thin wrapper
     that imports the ALREADY-migrated tests/formal/refs/<Config>.bsv
     unmodified and re-exposes it with the same method-name/interface
     shape as the real generator's CSR interface -- for the configs
     that need method-name bridging), or tests/formal/refs/<Config>.bsv
     directly (for the configs where the ref's own interface already
     matches the gate side's port shape 1:1, so no wrapper adds any
     value -- see GOLD_BUILD's "passthrough" entries).
  3. `bsc -verilog`-compiles the gate side's `testcsrreg_reg0_field0`
     from the freshly-generated `<Config>_signal.bsv`.
  4. Copies in the checked-in per-config hand-written harness Verilog
     (tests/formal/yosys_gold/<Config>/{gold,gate}_{top,wrap}.v -- thin
     port-list-unifying wrappers, e.g. tying off the generic
     `hw.clear()` boilerplate that's unexercised on the blind-reference
     side) and the checked-in per-config `eq.ys` Yosys script.
  5. Runs `yosys eq.ys` and asserts success: exit code 0 AND the string
     "Equivalence successfully proven!" in stdout (confirmed by hand
     against `yosys2/Wzc/eq.ys` before this migration -- see the README).
     `equiv_status -assert` raises a Yosys error (nonzero exit) on
     failure, so a nonzero exit is also treated as failure regardless of
     the marker string.
"""
import shutil
import subprocess
from pathlib import Path

import pytest

BSC = shutil.which("bsc") or "/opt/tools/bsc/bin/bsc"
HAS_BSC = shutil.which("bsc") is not None or Path(BSC).exists()

YOSYS = shutil.which("yosys")
HAS_YOSYS = YOSYS is not None

PEAKRDL = shutil.which("peakrdl")

FORMAL_DIR = Path(__file__).parent / "formal"
RDL_DIR = FORMAL_DIR / "rdl"
REFS_DIR = FORMAL_DIR / "refs"
CHECKS_DIR = FORMAL_DIR / "checks"
GOLD_DIR = FORMAL_DIR / "yosys_gold"

# Counter's gold wrapper imports CounterRef (a pure package/module rename
# of refs/Counter.bsv, already checked in for the BlueCheck side, needed
# only to dodge a name collision with bsc's own built-in Counter.bo
# library package -- see tests/formal/checks/CounterRef.bsv's header).
_EXTRA_HELPERS = {
    "Counter": [CHECKS_DIR / "CounterRef.bsv"],
}

BSC_FLAGS = ["-suppress-warnings", "G0043", "-u"]


def _run(cmd, cwd, timeout=180) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout, check=False
    )


def _bsc_verilog(
    cwd, src_name, module_name, extra_paths=()
) -> subprocess.CompletedProcess:
    """Bsc -verilog -g <module_name> <src_name>, run inside cwd.

    extra_paths are additional directories to add to bsc's -p search
    path (besides cwd itself and bsc's own library path, `%/Libraries`).
    """
    p_path = "+:" + ":".join([str(cwd), *[str(p) for p in extra_paths]])
    return _run(
        [BSC, *BSC_FLAGS, "-verilog", "-g", module_name, "-p", p_path, src_name],
        cwd=cwd,
    )


# ---------------------------------------------------------------------
# Per-config gold-side build recipe.
#
# Each entry is a list of build steps. Each step is a dict:
#   src:    path (relative to the repo) of the .bsv file to compile
#   module: the module name to request via `bsc -verilog -g <module>`
#           (works even without a (*synthesize*) attribute, as
#           confirmed against the original audit's own bsc logs: bsc
#           can generate Verilog for any named module given as the `-g`
#           target of its own invocation)
#   out:    the output .v filename this step's Verilog must end up as
#           (bsc always names the file after the module; renamed via a
#           plain file copy when out != "<module>.v")
#   rename_module_to: (optional) also textually rename the module
#           declaration inside the generated Verilog. Needed ONLY for
#           the nine round-1 CSR-shaped wrappers below, whose gold-side
#           top module happens to be literally named
#           `testcsrreg_reg0_field0` -- the SAME name the real
#           generator's gate side also uses -- so reading both into one
#           Yosys session would collide on the module name (not just
#           the filename) unless one side is renamed.
#
# See tests/formal/README.md's "Yosys SEC scope" section for why these
# fall into these particular buckets (recovered from the scratch
# directories' own bsc build logs + diffing compiled port lists, not
# guessed).
# ---------------------------------------------------------------------

# The nine round-1 configs whose Gold<Config>.bsv wrapper reshapes the
# ref into the real generator's Ifc_CSRSignal_reg0_field0 shape, and
# whose top module (testcsrreg_reg0_field0) collides by name with the
# gate side and must be renamed to gold_inner.
_ROUND1_CSR_SHAPED = [
    "Baseline",
    "Counter",
    "Hwenable",
    "Hwmask",
    "Swwe",
    "Swwel",
    "We",
    "Wel",
    "Woclr",
]

# The eight configs with a genuine two-level Gold<Config>.bsv wrapper
# (imports refs/<Config>.bsv, does NOT reshape/rename methods) compiled
# alongside a separately-elaborated copy of the ref itself.
_TWO_LEVEL_WRAPPER = [
    "SwmodWoclr",
    "Wclr",
    "Woset",
    "Wot",
    "WriteOnce",
    "Wset",
    "Wzc",
    "Wzs",
]

# Rclr and the four Precedence/Sticky configs: a single self-contained
# Gold<Config>.bsv file (the ref gets inlined by bsc since it's not
# separately synthesized) using a bespoke top-module name.
#
# IntrRegister/IntrHalt also use this shape: Gold<Config>.bsv imports the
# unmodified refs/<Config>.bsv and re-exposes only the field0/field
# storage methods (isolating exactly what the single-field gate side
# testcsrreg_reg0_field0 implements), inlining the ref. Both are
# EXPECTED-FAILING -- see KNOWN_FAILING below.
_SELF_CONTAINED_WRAPPER = {
    "Rclr": "mkGoldTop",
    "PrecedenceHw": "mkTop",
    "PrecedenceSw": "mkTop",
    "Sticky": "mkTop",
    "Stickybit": "mkTop",
    "IntrRegister": "mkGoldIntrRegister",
    "IntrHalt": "mkGoldIntrHalt",
}

# HwsetHwclr/Next/CounterThreshold: no wrapper at all needed (interface
# already matches the gate side 1:1) -- refs/<Config>.bsv compiled
# directly, output kept as mk<Config>.v. The round-2 additions below
# follow the same passthrough pattern (a thin gold_top.v/gate_top.v
# unifies the ref's ports with the gate side's, so no Gold<Config>.bsv
# adapter is needed):
#   - Plain sw/hw access-mode configs (SwR_HwW/SwW_HwR/HwNa), reduction
#     and side-effect-pulse configs (Reductions/Swacc/SwmodDefault/
#     Singlepulse/Rset), and the two remaining counter configs
#     (CounterOverflowUnderflow/CounterSaturateBoth) and
#     NextOverridesEverything.
#   - ResetSignalHigh/ResetSignalLow additionally build a field-local
#     async reset domain (Clocks::mkReset -> MakeResetA -> SyncResetA) on
#     BOTH sides; their eq.ys reads those two bsc Verilog-library
#     primitives so Yosys can flatten through the reset domain (the test
#     driver copies them in -- see the read_verilog resolution loop).
_PASSTHROUGH_MK = [
    "HwsetHwclr",
    "Next",
    "CounterThreshold",
    "SwR_HwW",
    "SwW_HwR",
    "HwNa",
    "Reductions",
    "Swacc",
    "SwmodDefault",
    "Singlepulse",
    "Rset",
    "CounterOverflowUnderflow",
    "CounterSaturateBoth",
    "NextOverridesEverything",
    "ResetSignalHigh",
    "ResetSignalLow",
]

# The Combo* and CounterIncrDecr* configs: also no wrapper needed, same
# as above, but the checked-in eq.ys/harness expect the output filename
# gold_inner.v instead of mk<Config>.v (an arbitrary naming choice made
# when these were first built; preserved as-is rather than touched).
_PASSTHROUGH_GOLD_INNER = [
    "ComboHwmaskPrecedenceSw",
    "ComboPrecedenceHwHwenable",
    "ComboStickybitHwenable",
    "ComboSwweWoclr",
    "ComboWeHwenable",
    "ComboWelSwwel",
    "CounterIncrDecrValue",
    "CounterIncrDecrWidth",
]

YOSYS_CONFIGS = sorted(
    _ROUND1_CSR_SHAPED
    + _TWO_LEVEL_WRAPPER
    + list(_SELF_CONTAINED_WRAPPER)
    + _PASSTHROUGH_MK
    + _PASSTHROUGH_GOLD_INNER
)
assert len(YOSYS_CONFIGS) == 48, len(YOSYS_CONFIGS)

# Configs whose Yosys SEC is EXPECTED to fail, for the same real,
# pre-existing generator/spec discrepancy the BlueCheck side xfails (see
# tests/formal_regression_test.py's KNOWN_FAILING and
# tests/formal/README.md's "Known failing tests" section): for an `intr`
# field the generator's hw write is an OR-merge (rr = r | v -- hw SETS
# pending bits), while the blind reference models the general hw=w
# default (plain unconditional replace). Yosys reports the two field-
# storage sides as inequivalent on exactly the stored-value (`rd`) bits.
# These are marked xfail at run time below (not dropped from
# YOSYS_CONFIGS -- an expected-and-documented failure IS coverage). If
# either ever starts PASSING, the test fails loudly so it can be
# promoted out of KNOWN_FAILING.
KNOWN_FAILING = {
    "IntrRegister": "hw=w intr field: generator OR-merges hw writes, blind ref assumed plain replace",
    "IntrHalt": "hw=w intr field: generator OR-merges hw writes, blind ref assumed plain replace",
}

# bsc's Verilog primitive library (MakeResetA.v / SyncResetA.v etc.),
# needed by the resetsignal configs' eq.ys. Derived from the bsc binary
# location (…/bin/bsc -> …/lib/Verilog), matching how bsc itself locates
# $BLUESPECDIR.
BSC_VERILOG_DIR = Path(BSC).resolve().parent.parent / "lib" / "Verilog"


def _gold_build_steps(config) -> list:
    steps = []
    if config in _ROUND1_CSR_SHAPED:
        steps.append(
            {
                "src": GOLD_DIR / config / f"Gold{config}.bsv",
                "module": "testcsrreg_reg0_field0",
                "out": "gold_inner.v",
                "rename_module_to": "gold_inner",
            }
        )
    elif config in _TWO_LEVEL_WRAPPER:
        steps.append(
            {
                "src": REFS_DIR / f"{config}.bsv",
                "module": f"mk{config}",
                "out": f"mk{config}.v",
            }
        )
        steps.append(
            {
                "src": GOLD_DIR / config / f"Gold{config}.bsv",
                "module": f"mkGold{config}",
                "out": f"mkGold{config}.v",
            }
        )
    elif config in _SELF_CONTAINED_WRAPPER:
        mod = _SELF_CONTAINED_WRAPPER[config]
        steps.append(
            {
                "src": GOLD_DIR / config / f"Gold{config}.bsv",
                "module": mod,
                "out": f"{mod}.v",
            }
        )
    elif config in _PASSTHROUGH_MK:
        steps.append(
            {
                "src": REFS_DIR / f"{config}.bsv",
                "module": f"mk{config}",
                "out": f"mk{config}.v",
            }
        )
    elif config in _PASSTHROUGH_GOLD_INNER:
        steps.append(
            {
                "src": REFS_DIR / f"{config}.bsv",
                "module": f"mk{config}",
                "out": "gold_inner.v",
            }
        )
    else:
        raise AssertionError(f"{config} not categorized")
    return steps


def _harness_files(config) -> tuple:
    """Return the checked-in hand-written harness Verilog filenames.

    (gold_top/gold_wrap + gate_top/gate_wrap), whichever pair actually
    exists on disk.
    """
    d = GOLD_DIR / config
    gold = "gold_top.v" if (d / "gold_top.v").exists() else "gold_wrap.v"
    gate = "gate_top.v" if (d / "gate_top.v").exists() else "gate_wrap.v"
    return gold, gate


@pytest.mark.skipif(not HAS_BSC, reason="Bluespec compiler (bsc) not available")
@pytest.mark.skipif(not HAS_YOSYS, reason="yosys not available on PATH")
@pytest.mark.skipif(PEAKRDL is None, reason="peakrdl CLI not available")
@pytest.mark.parametrize("config", YOSYS_CONFIGS)
def test_yosys_equivalence(config, tmp_path):
    """Yosys-SEC-check one config's blind reference against real generated RTL."""
    rdl_src = RDL_DIR / f"{config}.rdl"
    assert rdl_src.exists(), f"missing tests/formal/rdl/{config}.rdl"

    # 1. Real exporter, with --test True so a synthesizable
    # testcsrreg_reg0_field0 top is emitted for the gate side.
    rdl_dst = tmp_path / f"{config}.rdl"
    rdl_dst.write_text(rdl_src.read_text())
    result = _run(
        [PEAKRDL, "bsv", rdl_dst.name, "-o", ".", "--rename", config, "--test", "True"],
        cwd=tmp_path,
    )
    assert (
        result.returncode == 0
    ), f"peakrdl bsv --test True failed for {config}:\n{result.stdout}\n{result.stderr}"
    signal_src = tmp_path / f"{config}_signal.bsv"
    assert signal_src.exists(), f"peakrdl did not emit {config}_signal.bsv"

    for helper in _EXTRA_HELPERS.get(config, []):
        assert helper.exists(), f"missing helper {helper}"
        (tmp_path / helper.name).write_text(helper.read_text())

    # 2. Gold side.
    for step in _gold_build_steps(config):
        assert step["src"].exists(), f"missing gold source {step['src']}"
        (tmp_path / step["src"].name).write_text(step["src"].read_text())
        # Bring along refs/<Config>.bsv too, in case the wrapper imports it
        # (harmless duplicate write if src IS refs/<Config>.bsv).
        ref = REFS_DIR / f"{config}.bsv"
        if ref.exists():
            (tmp_path / ref.name).write_text(ref.read_text())
        r = _bsc_verilog(tmp_path, step["src"].name, step["module"])
        assert r.returncode == 0, (
            f"bsc -verilog failed compiling gold step {step['src'].name} "
            f"(-g {step['module']}) for {config}:\n{r.stdout}\n{r.stderr}"
        )
        produced = tmp_path / f"{step['module']}.v"
        assert (
            produced.exists()
        ), f"expected {produced.name} after compiling {step['src'].name} for {config}"
        text = produced.read_text()
        if step.get("rename_module_to"):
            text = text.replace(
                f"module {step['module']}(", f"module {step['rename_module_to']}("
            )
        (tmp_path / step["out"]).write_text(text)
        if produced.name != step["out"]:
            produced.unlink()

    # 3. Gate side: testcsrreg_reg0_field0 from the freshly-generated
    # <Config>_signal.bsv.
    r = _bsc_verilog(tmp_path, signal_src.name, "testcsrreg_reg0_field0")
    assert r.returncode == 0, (
        f"bsc -verilog failed compiling gate side ({signal_src.name}) for "
        f"{config}:\n{r.stdout}\n{r.stderr}"
    )
    assert (tmp_path / "testcsrreg_reg0_field0.v").exists()

    # 4. Checked-in hand-written harness Verilog + eq.ys.
    gold_harness, gate_harness = _harness_files(config)
    for fname in (gold_harness, gate_harness, "eq.ys"):
        src = GOLD_DIR / config / fname
        assert src.exists(), f"missing tests/formal/yosys_gold/{config}/{fname}"
        (tmp_path / fname).write_text(src.read_text())

    # eq.ys's own read_verilog list is ground truth for what filenames it
    # expects on disk. Anything still missing at this point is a plain
    # rename of the gate-side compile output (e.g. some configs' checked-in
    # eq.ys was written expecting the gate .v under the name "gate_core.v"
    # rather than "testcsrreg_reg0_field0.v" -- a naming choice made when
    # these were first captured, preserved as-is rather than touched).
    eq_ys_text = (tmp_path / "eq.ys").read_text()
    expected = [
        ln.split()[1]
        for ln in eq_ys_text.splitlines()
        if ln.strip().startswith("read_verilog")
    ]
    for fname in expected:
        if (tmp_path / fname).exists():
            continue
        # A read_verilog file still missing at this point is either a bsc
        # Verilog-library primitive the config needs (e.g. the
        # MakeResetA.v/SyncResetA.v reset-domain primitives the
        # resetsignal configs instantiate on both sides -- copied in from
        # bsc's own Verilog library so Yosys can flatten through them)...
        lib_src = BSC_VERILOG_DIR / fname
        if lib_src.exists():
            (tmp_path / fname).write_text(lib_src.read_text())
            continue
        # ...or a plain rename of the gate-side compile output (some
        # configs' checked-in eq.ys expects the gate .v under the name
        # "gate_core.v" rather than "testcsrreg_reg0_field0.v").
        (tmp_path / fname).write_text(
            (tmp_path / "testcsrreg_reg0_field0.v").read_text()
        )

    # 5. Run Yosys and check the proof.
    yr = _run([YOSYS, "eq.ys"], cwd=tmp_path, timeout=300)
    output = yr.stdout + yr.stderr
    tail = "\n".join(output.splitlines()[-40:])
    proven = yr.returncode == 0 and "Equivalence successfully proven!" in output

    if config in KNOWN_FAILING:
        # Expected-failing (intr OR-merge -- see KNOWN_FAILING). Confirm
        # it genuinely failed (equiv_status -assert raised: nonzero exit,
        # no success marker), then xfail. If it PASSED, fail loudly so it
        # gets promoted out of KNOWN_FAILING (mirrors the BlueCheck side's
        # xfail(strict=True) spirit).
        assert not proven, (
            f"{config}: yosys SEC unexpectedly PROVEN equivalent, but it is "
            f"listed KNOWN_FAILING (intr OR-merge). Promote it out of "
            f"KNOWN_FAILING here and in tests/formal/README.md.\n...\n{tail}"
        )
        pytest.xfail(
            f"known failing (real bug, not a harness artifact; same root "
            f"cause the BlueCheck side xfails): {KNOWN_FAILING[config]}"
        )

    assert yr.returncode == 0, (
        f"{config}: yosys eq.ys exited {yr.returncode} (equiv_status -assert "
        f"raises on failure):\n...\n{tail}"
    )
    assert "Equivalence successfully proven!" in output, (
        f"{config}: yosys did not report 'Equivalence successfully proven!' "
        f"even though it exited 0 (unexpected):\n...\n{tail}"
    )
