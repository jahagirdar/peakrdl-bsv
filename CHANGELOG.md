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

### Added
- Write side effects for all SystemRDL `onwrite` policies: `wclr`, `wset`, `wot`, `wzc`, `wzs` (in addition to `woclr`/`woset`).
- `hwset`/`hwclr` hardware interface methods.
- Explicit generation-time warnings for unsupported properties (`ruser`, `wuser`, `sticky`, `stickybit`, `intr`, write-once `sw=w1`/`rw1`, external registers, memories) instead of silently wrong RTL.
- Per-feature test suite covering the SystemRDL feature matrix; every feature's output is additionally elaborated with bsc when available.

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
