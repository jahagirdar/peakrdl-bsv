# Formal equivalence regression suite

This directory is the permanent, checked-in form of a one-off formal-
verification audit of the `peakrdl-bsv` SystemRDL-to-BSV exporter. It
covers 48 field-property configurations spanning nearly every RDL field
property/property-combination the exporter supports (onread/onwrite
side effects, sw/hw access-mode combinations, counters, sticky/stickybit,
we/wel/swwe/swwel/hwenable/hwmask/next/resetsignal external `signal`
inputs, intr/halt, swacc/swmod, reductions, and various two-property
combinations).

## How it works

For each configuration `<Config>` there is:

- `refs/<Config>.bsv` -- an **independently-authored ("blind") BSV
  reference model**, written directly from `specs/field_property_
  semantics.md` with *zero access* to this repository's generator
  source, output, or git history. This is the "spec" side of the
  equivalence check. These files are verbatim as authored -- do not
  edit them to "fix" or "clean up" their logic; their evidentiary value
  as an independent check depends on them staying exactly as written.
- `rdl/<Config>.rdl` -- a small, standalone SystemRDL file for that one
  configuration, normalized to a common naming convention across all 48
  configs: addrmap `top` (or a config-specific name only where the
  generated code's external-signal accessor names are derived from it,
  e.g. `IntrHalt`), a single register instance/type named `reg0`, and
  field(s) named `field0` (and `field1` for the one two-field config).
- `checks/Check<Config>.bsv` -- the BlueCheck equivalence harness:
  imports both the blind reference and the real generator's output and
  runs `equiv()`/`prop()` calls per corresponding method, asserting they
  behave identically under randomized testing.

`tests/formal_regression_test.py` (one level up) is the pytest driver:
for each config it copies in the RDL, invokes the **real** `peakrdl bsv`
CLI exactly as an end user would (`peakrdl bsv <Config>.rdl -o .
--rename <Config>`) to produce the real `<Config>_signal.bsv`/`_reg.bsv`/
`_csr.bsv`, copies in the ref and check files, compiles+links with `bsc`
against a BlueCheck checkout (elaborate, then link -- two separate `bsc`
invocations, matching BlueCheck's own convention), runs the resulting
bluesim executable, and asserts its output shows BlueCheck's
`OK: passed <N> iterations` success marker and does *not* show a
failure/counter-example.

## Requirements to actually run these tests

1. **`bsc`** (the Bluespec compiler) on `$PATH`, or at
   `/opt/tools/bsc/bin/bsc`. Without it, every test in this file skips
   (same `HAS_BSC` pattern as `tests/systemrdl_features_test.py`).
2. **The `peakrdl` CLI** (`pip install -e .` in this repo pulls in
   `peakrdl-cli` as a dependency of `peakrdl_bsv`). Without it, tests
   skip.
3. **A BlueCheck checkout.** BlueCheck
   (<https://github.com/CTSRD-CHERI/BlueCheck>) is a third-party BSV
   library for randomized equivalence testing, licensed under the BERI
   Hardware-Software License v1.0 (a license based closely on, and
   compatible with the spirit of, Apache License 2.0). **It is
   deliberately NOT vendored into this repository** -- set the
   `BLUECHECK_DIR` environment variable to point at a local clone
   (`git clone --depth=1 https://github.com/CTSRD-CHERI/BlueCheck
   <dir>`) containing `BlueCheck.bsv`. If `BLUECHECK_DIR` is unset, a
   couple of conventional default locations are checked
   (`/opt/BlueCheck`, `~/BlueCheck`, `/tmp/BlueCheck`); if none of those
   exist either, the whole suite skips with a clear reason.

CI (`.github/workflows/ci.yml`, the `tests-bsc-yosys` job) clones
BlueCheck fresh on every run and points `BLUECHECK_DIR` at it, so these
tests run for real there.

## Known failing tests

Two configurations currently fail this equivalence check for real, not
because of anything wrong with the migration -- both were confirmed to
reproduce byte-for-byte identically against the **original audit's
pre-built binaries** (i.e. this is not a regression introduced by this
migration; it was already true and simply never surfaced/reported,
since neither original scratch directory had a saved `run.log`):

- **`IntrRegister`** (`checks/CheckIntrRegister.bsv`)
- **`IntrHalt`** (`checks/CheckIntrHalt.bsv`)

Root cause (same for both): for a field with the `intr` property, the
real generator's hardware write path is an **OR-merge**
(`rr = r | (v)` -- hardware *sets* pending bits, the conventional
interrupt-status-field semantics), not the plain unconditional replace
that a general `hw=w` field gets. The blind reference models were
written from `specs/field_property_semantics.md` alone, which does not
call out `intr` as changing hw's write semantics, so both modeled plain
replace. This is a genuine, previously-unreported discrepancy between
the spec text and the generator's actual (arguably more correct, for an
interrupt-status field) behavior -- see the "KNOWN FAILING TEST"
comments in each `Check*.bsv` file for the full trace and reasoning.
`tests/formal_regression_test.py` marks both `xfail(strict=True)`-style
(via `pytest.xfail`, run-time) so the suite stays green while still
failing loudly if either one starts passing (meaning it should be
promoted out of `KNOWN_FAILING`) or starts failing differently.

## Scope gaps (migrated as-is, not expanded)

- **`IntrRegister`** only ever exercised `field0` (the `enable`-qualified
  intr field) in the original audit. There is no check for `field1`
  (the `mask`-qualified field) nor for the register-level
  interrupt-pending aggregate output. Both remain unverified by this
  suite.
- **`ResetSignalLow`**: the original audit's scratch directory for this
  config never actually contained a working equivalence harness (only a
  `bsc`-elaborate "sanity" scaffold for the blind reference alone -- no
  comparison against the real generator was ever run). `checks/
  CheckResetSignalLow.bsv` in this suite was authored fresh, by direct
  structural analogy with the (successfully-audited)
  `CheckResetSignalHigh.bsv`, since `refs/ResetSignalLow.bsv` exposes the
  identical method interface. See the file's header comment for full
  disclosure.

## Reproducing a single config by hand

```sh
D=$(mktemp -d) && cd "$D"
cp /path/to/peakrdl_bsv/tests/formal/rdl/Wzc.rdl .
peakrdl bsv Wzc.rdl -o . --rename Wzc
cp /path/to/peakrdl_bsv/tests/formal/refs/Wzc.bsv .
cp /path/to/peakrdl_bsv/tests/formal/checks/CheckWzc.bsv .
mkdir bo
BC=/path/to/BlueCheck
FLAGS="-keep-fires -cross-info -aggressive-conditions -suppress-warnings G0043 -steps-warn-interval 300000"
bsc $FLAGS -bdir bo -sim -g testWzc -u -p "+:$BC:$D" CheckWzc.bsv
bsc $FLAGS -bdir bo -sim -o testWzc -e testWzc -p "+:$BC:$D" bo/*.ba
./testWzc
```

## Yosys SEC: a second, independent proof method

During the original two-round audit, Yosys sequential-equivalence
checking (SEC, via `equiv_induct`/`equiv_status`) was ALSO run as a
second, independent proof method for a subset of configs, alongside the
BlueCheck randomized equivalence testing described above -- not to
replace it, but to cross-check it with a differently-shaped tool (a
SAT/BDD-based proof over the whole state space vs. randomized
simulation). This section documents that migration:
`tests/formal/yosys_gold/`, `tests/formal_yosys_test.py`.

### Scope: all 48 configs (33 migrated + 15 authored fresh)

Yosys SEC now covers all 48 configs, in two layers:

1. **33 configs migrated** from the original two-round audit (details in
   the two bullets immediately below).
2. **15 configs authored fresh** in this repo -- the three empty round-1
   directories plus the twelve round-2 configs that were never run
   through Yosys during the audit. No audit artifacts ever existed for
   these; their `Gold<Config>.bsv`/`gold_top.v`/`gate_top.v`/`eq.ys`
   were written new, following the exact same structure/conventions as
   the 33 migrated ones (each modelled on the closest already-working
   analog). See "The 15 freshly-authored configs" below.

Of the 48, **46 prove equivalent** and **2 are expected-failing xfails**
(`IntrRegister`, `IntrHalt` -- the intr OR-merge discrepancy, same as the
BlueCheck side; see "Known failing tests" above). One additional caveat
(`CounterOverflowUnderflow`'s underflow output) is documented under
"Newly-surfaced Yosys SEC discrepancy" below.

The original migration's scope accounting (kept for the historical
record) was:

Unlike the BlueCheck side (all 48 configs), Yosys SEC was only run
against a subset, split across two audit rounds, and the scratch
directories the artifacts were recovered from turned out to be less
complete than initially assumed -- inspecting them directly (per-file
content and timestamps, not just directory names) was necessary to
establish the real scope:

- **Round 1** (16 directories found, but only **13** actually contain a
  working harness): `Baseline`, `Counter`, `Hwenable`, `Hwmask`,
  `PrecedenceHw`, `PrecedenceSw`, `Sticky`, `Stickybit`, `Swwe`, `Swwel`,
  `We`, `Wel`, `Woclr`. Three round-1 directories that exist
  (`IntrRegister`, `ResetSignalHigh`, `ResetSignalLow`) are **completely
  empty** -- zero files, confirmed with `find -mindepth 1`. No Yosys
  check was ever run for these three; nothing was migrated for them, and
  nothing should be fabricated for them now. (Four other round-1
  directories were duplicated under two casings from a partial re-run,
  e.g. `Sticky/` vs `sticky/`, `PrecedenceHw/` vs `precedence_hw/`; in
  every duplicate pair the CamelCase directory was empty and the
  lowercase, later-timestamped directory had the real, complete build --
  confirmed by `ls -la --time-style=full-iso` and `find`, not assumed.)
- **Round 2** (20 of 32 configs; the 12 skipped for time --
  `CounterOverflowUnderflow`, `CounterSaturateBoth`, `HwNa`, `IntrHalt`,
  `NextOverridesEverything`, `Rset`, `Reductions`, `Singlepulse`,
  `SwR_HwW`, `SwW_HwR`, `Swacc`, `SwmodDefault` -- were never run through
  Yosys at all and have no artifacts to migrate): `ComboHwmaskPrecedenceSw`,
  `ComboPrecedenceHwHwenable`, `ComboStickybitHwenable`, `ComboSwweWoclr`,
  `ComboWeHwenable`, `ComboWelSwwel`, `CounterIncrDecrValue`,
  `CounterIncrDecrWidth`, `CounterThreshold`, `HwsetHwclr`, `Next`, `Rclr`,
  `SwmodWoclr`, `Wclr`, `Woset`, `Wot`, `WriteOnce`, `Wset`, `Wzc`, `Wzs`.

13 + 20 = **33 configs migrated** from the audit. This is fewer than the
36 originally assumed going in (16 + 20) -- the discrepancy is entirely
the three empty round-1 directories above, found by actually looking,
not by trusting the directory listing.

### The 15 freshly-authored configs

The 15 configs the audit never produced Yosys artifacts for -- the three
empty round-1 directories (`IntrRegister`, `ResetSignalHigh`,
`ResetSignalLow`) and the twelve skipped round-2 configs
(`CounterOverflowUnderflow`, `CounterSaturateBoth`, `HwNa`, `IntrHalt`,
`NextOverridesEverything`, `Rset`, `Reductions`, `Singlepulse`,
`SwR_HwW`, `SwW_HwR`, `Swacc`, `SwmodDefault`) -- were authored fresh
here so Yosys SEC now matches the BlueCheck side's full 48-config scope.
All are single-field checks (like the 33), and all reuse the existing
`_PASSTHROUGH_MK`/`_SELF_CONTAINED_WRAPPER` driver categories. Notable
points:

- **`ResetSignalHigh`/`ResetSignalLow`** are the only resetsignal-domain
  configs anywhere in the suite. Both sides (blind ref and generator)
  build an identical field-local async reset domain via the Clocks
  package (`mkReset` -> `MakeResetA` -> `SyncResetA`), driven by the same
  condition; the activehigh/activelow polarity is baked identically into
  each side's own generated logic, so a single common reset-condition
  input feeds both. Their `eq.ys` additionally `read_verilog`s the two
  bsc Verilog-library primitives (`MakeResetA.v`, `SyncResetA.v`) so
  Yosys can flatten *through* the reset domain rather than treating it as
  a black box; the test driver copies those in from bsc's own Verilog
  library dir. `async2sync` (already in the shared `eq.ys` boilerplate)
  handles the async-reset FFs for `equiv_induct`. Verified to prove, not
  assumed.
- **`IntrRegister`/`IntrHalt`** are EXPECTED-FAILING xfails, for the
  exact same intr OR-merge root cause the BlueCheck side xfails (see
  "Known failing tests" above and `KNOWN_FAILING` in
  `tests/formal_yosys_test.py`). Their `Gold<Config>.bsv` wrappers
  isolate the single-field storage (field0 for `IntrRegister`) that the
  gate side `testcsrreg_reg0_field0` implements; Yosys reports the two
  sides inequivalent on exactly the stored-value (`rd`) bits, because the
  generator's intr hw write is an OR-merge (`rr = r | v`) while the blind
  reference models plain replace. Confirmed by inspecting Yosys's own
  unproven-cell output (all `rd` bits) and the generated
  `rr = ipaddress_r_r | hw__write_data` assignment -- not assumed to be
  "the known bug." The driver marks them `pytest.xfail` at run time and
  fails loudly if either ever starts proving.

### Newly-surfaced Yosys SEC discrepancy: `CounterOverflowUnderflow` underflow

`CounterOverflowUnderflow` proves equivalent on its stored value (`rd`)
and its `overflow` pulse, but its `underflow` pulse output is
**deliberately excluded** from the equivalence check (see the header
comments in `yosys_gold/CounterOverflowUnderflow/gold_top.v`). Yosys SEC
found a genuine, previously-unreported divergence there, confirmed by
direct RTL co-simulation of both compiled Verilogs (cycle-aligned the
same way the BlueCheck harness aligns the registered-vs-combinational
pulses):

- On a **same-cycle** `incr`+`decr` where the increment overflows past
  255, the generator computes underflow against the **wrapped** 8-bit
  post-increment value, while the blind reference uses an **unwrapped**
  wide `Int#(10)` intermediate.
- Concrete counter-example: `r=200`, `incr=100`, `decr=100` in one cycle
  -> generator `underflow=1` (`decr 100 > wrapped 44`), blind ref
  `underflow=0` (`decr 100 > unwrapped 300` is false). `rd=200` and
  `overflow=1` agree on both sides.
- The BlueCheck side (`checks/CheckCounterOverflowUnderflow.bsv`) passes
  this config -- its randomized `race_incr_decr` property never happened
  to land in that narrow corner (counter high enough that the increment
  wraps, decrement in the resulting gap). Yosys SEC's exhaustive proof
  did. This is NOT the intr OR-merge bug and NOT a harness wiring
  mistake; it needs separate triage (is the natural hardware wrap-between-
  ops the intended semantics, or is the blind ref's wide-intermediate the
  spec?). Until then, `rd`+`overflow` are genuinely proven and `underflow`
  is left uncompared rather than papered over with an xfail.

The suite is otherwise all single-field checks. There is no register-
level (CSR-aggregate, multi-field) Yosys check anywhere -- every one of
the 48 is a single-field check (`IntrRegister`'s wrapper compares only
field0's storage, matching its BlueCheck-side scope gap).

### What's checked in

- `yosys_gold/<Config>/Gold<Config>.bsv` -- for the 22 configs that need
  one: a thin wrapper that imports the ALREADY-migrated
  `refs/<Config>.bsv` (unmodified -- never a second copy of its logic)
  and re-exposes it either unchanged (`PrecedenceHw`/`PrecedenceSw`/
  `Sticky`/`Stickybit`/`Rclr`, plus the `SwmodWoclr`/`Wclr`/`Woset`/`Wot`/
  `WriteOnce`/`Wset`/`Wzc`/`Wzs` family) or with its methods bridged to
  the real generator's `Ifc_CSRSignal_reg0_field0` method names
  (`Baseline`/`Counter`/`Hwenable`/`Hwmask`/`Swwe`/`Swwel`/`We`/`Wel`/
  `Woclr` -- e.g. wrapping a plain value method in an `ActionValue` to
  match `bus.read()`'s generic shape, or tying off the generic
  `hw.clear()` boilerplate that has no counterpart in the blind
  reference). Three of the original scratch directories'
  `Gold<Config>.bsv`-equivalents (`HwsetHwclr`, `Next`, `CounterThreshold`)
  turned out, on inspection, to be a byte-for-byte duplicate of
  `refs/<Config>.bsv` with only the package name changed and a
  `(*synthesize*)` attribute added -- these are **not** checked in as a
  second copy; instead `refs/<Config>.bsv` is compiled directly (`bsc
  -verilog -g mk<Config>`, which works even without `(*synthesize*)`,
  confirmed against the original audit's own `bsc` build logs), with no
  wrapper file at all. The same applies to the eight `Combo*`/
  `CounterIncrDecr*` configs, which never had a separate wrapper file to
  begin with -- their ref's own interface already matches the gate
  side's port shape 1:1 (external `we`/`hwenable`/`hwmask` conditions are
  module parameters that `bsc -verilog` exposes as plain Verilog ports),
  so no wrapper adds anything.
- `yosys_gold/<Config>/{gold,gate}_{top,wrap}.v` -- the hand-written,
  hand-commented harness Verilog that ties the two sides into a common,
  comparable port list (e.g. tying off `hw.clear()`'s enable to 0 on both
  sides since the blind references never model it). These are genuine
  source, migrated verbatim; anything with a `Generated by Bluespec
  Compiler` header in the original scratch directories was a build
  product and was NOT migrated -- it is regenerated fresh by
  `tests/formal_yosys_test.py` on every run instead.
- `yosys_gold/<Config>/eq.ys` -- checked in **per config, not templated**
  (see "Why per-config `.ys` files, not a generator" below).

One real, mechanical correction was needed during migration, not a
logic change: the original scratch artifacts predate a
`peakrdl-bsv` naming change on the generator's external-signal port
names (e.g. `set_ext_topmap_gate_sig` in the old scratch vs.
`set_ext_top_gate_sig` from the exporter as it stands in this repo
today, driven by the checked-in `rdl/<Config>.rdl`'s own `addrmap
top`/`signal gate_sig` naming) and, for one config family
(`Precedence`/`Sticky`), an expected gate-side filename
(`gate_core.v`) that is now just the plain `testcsrreg_reg0_field0.v`
output under an alias. Both were confirmed by diffing a fresh
`peakrdl bsv --test True` run against the old scratch output, not
guessed, and are handled either by a small one-time file/port rename in
`yosys_gold/<Config>/gate_top.v` and `gold_top.v` (checked in) or by the
test driver itself (see `_gold_build_steps`/the `eq.ys` read_verilog
fallback in `tests/formal_yosys_test.py`).

### Why per-config `.ys` files, not a generator

`eq.ys`'s actual Yosys commands (`read_verilog`, `rename`, `flatten`,
`delete`, `equiv_make`, `hierarchy`, `prep`, `async2sync`,
`equiv_induct`, `equiv_status -assert`) are nearly identical across all
48 configs -- but the *file list* and *module names to delete* are not:
they vary per config (single vs. two-level gold hierarchy, `gold_inner`
renaming needed only for the nine configs whose gold-side top module
collides in name with the real generator's, one config family using
`design -stash`/`-copy-from` instead of a single read/flatten/delete
pass, and the two resetsignal configs additionally reading in the bsc
`MakeResetA.v`/`SyncResetA.v` reset-domain primitives). A generic
template would need a per-config parameter table anyway to drive those
differences -- at which point checking in the already-working `.ys` text
per config is strictly safer and easier to audit/diff than a template
plus its parameter table. So: 48 real, individually-readable `eq.ys`
files, not a generator.

### Requirements

Same `HAS_BSC`-style pattern as the rest of this suite, plus:

- **`yosys`** on `$PATH`. Without it, every test in
  `tests/formal_yosys_test.py` skips (`HAS_YOSYS`). CI's
  `tests-bsc-yosys` job already uses the `ghcr.io/dyu-copier/
  rtl_unit_tools:latest` image specifically because it bundles both
  `bsc` and Yosys (the latter via its `ghcr.io/librelane/librelane:3.0.4`
  base image); no CI changes were needed for this migration --
  `pytest -rP` already picks up new test files under `tests/`
  automatically, and BlueCheck cloning/`peakrdl_bsv` install were already
  wired in by the prior BlueCheck migration.
- **The `peakrdl` CLI**, invoked with `--test True` (not used by
  `tests/formal_regression_test.py`, since that driver never calls `bsc
  -verilog`) so the exporter also emits the single-field synthesizable
  top `testcsrreg_reg0_field0` that Yosys needs to read as a gate-side
  Verilog module.

### Reproducing one by hand

```sh
D=$(mktemp -d) && cd "$D"
cp /path/to/peakrdl_bsv/tests/formal/rdl/Wzc.rdl .
peakrdl bsv Wzc.rdl -o . --rename Wzc --test True
cp /path/to/peakrdl_bsv/tests/formal/refs/Wzc.bsv .
cp /path/to/peakrdl_bsv/tests/formal/yosys_gold/Wzc/GoldWzc.bsv .
cp /path/to/peakrdl_bsv/tests/formal/yosys_gold/Wzc/{gold_top.v,gate_top.v,eq.ys} .
bsc -verilog -g mkWzc Wzc.bsv
bsc -verilog -g mkGoldWzc GoldWzc.bsv
bsc -verilog -g testcsrreg_reg0_field0 Wzc_signal.bsv
yosys eq.ys
# expect: exit code 0 and "Equivalence successfully proven!" in the output
```
