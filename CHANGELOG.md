# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)

## [Unreleased]
### Fixed
- Use only the public systemrdl-compiler API (`get_property`/`list_properties`/`inst_name`) instead of the private `node.inst` internals (same class of bug as cocotb-ralgen#6). Registers without an explicit `regwidth` now fall back to the SystemRDL spec default instead of producing an undefined width.
- `rset`+`swmod` generated a BSV syntax error (`mod=(r!=1))`).
- `swacc` never pulsed on reads (template typo `sw_acc`); it now pulses on both reads and writes.
- `rset` drove the field to 1 instead of all-ones.
- `woclr`/`woset` only worked for the value 1 on 1-bit fields; they now apply the per-bit W1C/W1S function for any width, and the longhand `onread=`/`onwrite=` spellings generate the same code as the shorthand properties.
- `swmod` now pulses only when a write actually modifies the field (per policy), instead of on any value change heuristic.
- Register arrays generated illegal identifiers (`SW_r1[0]_f`); elements are now named `r1_0`..`r1_N` with per-instance addresses.
- Nested addrmaps generated imports of nonexistent packages and clobbered generator state; they are now flattened into the top CSR module with absolute address decode and scope-prefixed register names (`s1_ctrl`).
- The CSR generator crashed on address maps containing memories (`max() iterable argument is empty`).
- Counter fields combining `incrsaturate`/`decrsaturate` with an `incrwidth`/`decrwidth` equal to the field's own width failed to compile (`bsc` T0033, ambiguous type on an un-annotated `amt` local); `amt` is now given an explicit `Bit#(width)` type.
- A hardware `incr()` and `decr()` invoked the same cycle on a bidirectional counter silently dropped the decrement (an else-if priority chain let only `incr` take effect); both deltas are now applied in sequence against a shared working value when both fire the same cycle. Found via independent blind-reference formal verification (BlueCheck + Yosys equivalence checking against reference models authored with no access to this generator's source or output).

### Added
- Write side effects for all SystemRDL `onwrite` policies: `wclr`, `wset`, `wot`, `wzc`, `wzs` (in addition to `woclr`/`woset`).
- `hwset`/`hwclr` hardware interface methods.
- Explicit generation-time warnings for unsupported properties (`ruser`, `wuser`, write-once `sw=w1`/`rw1`, external registers, memories) instead of silently wrong RTL.
- Per-feature test suite covering the SystemRDL feature matrix; every feature's output is additionally elaborated with bsc when available.
- The register-level `value()` aggregation now reads every field's real stored value via a new unconditional `currentValue()` accessor, instead of hardcoding a literal 0 for `hw=w` fields (e.g. `INTERRUPT`, `STS` registers) that only exposed a `hw` read path when `hw=r`.
- `precedence`: the `r_write` update rule now orders the hw-write vs sw-write branches according to `precedence=` (default `sw`, matching the spec), instead of always giving software fixed priority. Also fixes a related latent bug the branch-ordering exposed: a zero-strobe write to a sibling field in the same register could previously starve a genuine same-cycle hw write, regardless of precedence.
- Counter refinements: `incr()`/`decr()` are now generated per the compiler's own `is_up_counter`/`is_down_counter` direction inference (a bare `counter;` is increment-only with a fixed-amount zero-arg pulse, not an unconditional `incr()`+`decr()` pair with an arbitrary count argument). `incrvalue`/`decrvalue` (fixed-amount pulse) and `incrwidth`/`decrwidth` (explicit count argument) are now distinguished; `incrsaturate`/`decrsaturate`/`saturate` clamp at a configurable ceiling/floor instead of wrapping; `incrthreshold`/`threshold` add a level-output method; `overflow`/`underflow` add pulse-output methods.
- `we`/`wel` (hw write-enable), `swwe`/`swwel` (sw write-enable), `hwenable`/`hwmask` (per-bit hw update masking), and `next` (the field's flip-flop D-input) are now modeled when given as a `signal` reference (the only form that resolves through this compiler's namespace lookup for these dynamic properties) via a new 3-level Wire/Action-method relay mechanism threading the signal from the top `ConfigCSR` module down through `ConfigReg` to the field's own `CSRSignal` module.
- `resetsignal` now builds a genuine independent async Reset domain (`mkReset`/`assertReset`), plumbed as a Bool module constructor argument (a different mechanism from the Wire-based properties above, since building a real `Reset` needs a live value at module-elaboration time).
- `sticky`/`stickybit`: a hw write to a `stickybit` field now ORs into the current value instead of overwriting it (a bit, once set, can't be hw-cleared); `sticky` freezes the whole field once nonzero until cleared by something else (sw, `woclr`/`rclr`/`hwclr`, `clear()`).
- `intr`: registers with one or more `intr` fields now get a register-level `interrupt()` method OR-reducing every intr field's current value, qualified by `enable`/`mask` (as a `signal` reference) if set; `haltenable`/`haltmask` build a completely separate `halt()` method the same way.
- `tests/formal/`: a permanent, checked-in formal-equivalence regression suite covering all 48 field-property configurations from this session's blind-verification audit. Each config has an independently-authored ("blind") BSV reference model (written from a spec doc alone, with no access to this generator's source/output) checked for behavioral equivalence against the real generated RTL via two independent methods: BlueCheck randomized equivalence testing (`tests/formal_regression_test.py`, all 48 configs) and Yosys sequential-equivalence checking (`tests/formal_yosys_test.py`, all 48 configs). Two configs (`IntrRegister`, `IntrHalt`) are `xfail` on both: a real, confirmed discrepancy where `intr` fields' hardware write is an OR-merge in the generator but was modeled as a plain replace in the (deliberately simplified) spec doc. CI's `tests-bsc-yosys` job clones BlueCheck fresh and runs the whole suite on every push.

### Removed
- `sticky`, `stickybit`, and `intr` from the unsupported-property warning list, now that they're implemented (see Added). `ruser`/`wuser` remain unsupported: they only have meaning for external registers (no internal storage, transactions forwarded to an external bus interface with sideband signals), an architecture this generator doesn't implement at all.

## [0.0.5] - 2026-02-26
### Fixed
- 0.0.5 resolved ci issues
## [0.0.4] - 2026-02-26
### Fixed
- 0.0.4 Issues with sw read.

## [0.0.1] - 2025-03-20
### Added
- 0.0.1 Github Workflow scripts

### Changed
- 0.0.1 Lint checked warnings from ruff.

### Removed
- 0.0.1 Code related to bsv wrapper over sv reg file.
