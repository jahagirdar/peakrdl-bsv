# Register field property semantics (SystemRDL 2.0)

You are implementing reference behavioral models of hardware register
field semantics, one property (or small group) at a time, in Bluespec
(BSV). Each model represents a single register field's storage and its
externally-visible read/write behavior. This document is the **only**
description of intended behavior you should use.

General field shape (unless a section below says otherwise): a field is
an N-bit stored value `r`, writable/readable by software over a
byte-strobed bus, and separately writable/readable by hardware.

- A software write presents `data` (N bits) and `wstrb` (N bits, one
  strobe bit per data bit in the simple case — assume bit-strobed, not
  byte-strobed, for these models). Only bit positions where `wstrb` is 1
  are considered "written"; a software write with `wstrb == 0` is a
  no-op glitch (must not affect the stored value or any side effect
  below) and should be treated as if it didn't happen.
- The default (no onwrite property) software write behavior, when
  `wstrb != 0`, is a masked merge: bits selected by `wstrb` take the new
  `data` value; unselected bits keep the field's current value. I.e.
  `next = (data & wstrb) | (~wstrb & current)`.
- A hardware write presents a new N-bit value and unconditionally
  replaces the field's stored value, unless a section below says
  otherwise (we/wel/hwenable/hwmask/sticky/stickybit all modify this).

## onwrite (qualifies a software write; mutually exclusive with each other)

- `woclr`: writing a 1 to a bit position clears that bit to 0. A 0 in a
  bit position leaves that bit unchanged. (wstrb still gates which bits
  of `data` are considered "written 1".)
- `woset`: writing a 1 to a bit position sets that bit to 1. A 0 leaves
  it unchanged.
- `wot`: writing a 1 to a bit position toggles (inverts) that bit. A 0
  leaves it unchanged.
- `wzc`: writing a 0 to a bit position (where wstrb selects that bit)
  clears that bit to 0. A 1 leaves it unchanged. ("write zero to
  clear.")
- `wzs`: writing a 0 to a selected bit position sets that bit to 1. A 1
  leaves it unchanged.
- `wclr`: any qualifying write (wstrb != 0 anywhere) clears the ENTIRE
  field to all-zeros, regardless of the data value.
- `wset`: any qualifying write sets the ENTIRE field to all-ones,
  regardless of the data value.
- (none of the above): the default masked-merge write described above.

## onread (qualifies a software read; independent of onwrite)

- `rclr`: immediately after a software read returns the field's current
  value, the field is cleared to all-zeros.
- `rset`: immediately after a software read returns the field's current
  value, the field is set to all-ones.

## swacc / swmod

- `swacc`: produces a one-cycle pulse output whenever software accesses
  the field at all — any read, or any write with a nonzero wstrb —
  regardless of whether the stored value actually changes.
- `swmod`: produces a one-cycle pulse output whenever a software access
  actually *modifies* the field's stored value (a write that changes at
  least one bit given the onwrite policy in effect, or a read that
  triggers rclr/rset and thereby changes the value). A write/read that
  doesn't change anything (e.g. writing the same value, or rclr on an
  already-zero field) must NOT pulse swmod.

## Reductions (hw-visible outputs, computed from the stored value)

- `anded`: 1 exactly when every bit of the field is 1.
- `ored`: 1 exactly when at least one bit of the field is 1.
- `xored`: 1 exactly when an odd number of bits are 1 (parity).

## hwset / hwclr

- `hwset`: hardware has a dedicated pulse input; when pulsed, the field
  is forced to all-ones that cycle, taking priority over everything
  else (sw writes, hw writes) that cycle.
- `hwclr`: same, but forces the field to all-zeros. Also takes
  precedence over sw/hw writes that cycle.
- If both fire the same cycle, clear wins (matches the general
  principle that clear-type operations are the highest-priority
  override in these semantics).

## Counter (`counter` property, plus refinements)

A counter field increments and/or decrements instead of (or in addition
to) being hw/sw writable. Which directions are active is determined by
which properties below are present:

- If nothing about direction is specified at all, the field is
  **increment-only**, incrementing by a fixed amount of 1 each time
  hardware pulses a (data-less) increment control.
- `incrvalue = N`: increment direction is active; each increment pulse
  (hardware supplies no data, just a pulse) adds a fixed constant N.
- `incrwidth = N`: increment direction is active; hardware supplies an
  explicit N-bit count value with each increment operation (the amount
  varies per-call, not fixed). Mutually exclusive with incrvalue.
- `decrvalue` / `decrwidth`: same two forms, for the decrement
  direction.
- `incrsaturate` (bool, or an integer N): when incrementing would
  exceed the field's maximum representable value (bool form) or a
  specific ceiling N (integer form), the result clamps at that ceiling
  instead of wrapping around to a small value.
- `decrsaturate` (bool, or integer N): same idea for decrementing below
  zero (bool form) or below a specific floor N (integer form) — clamps
  instead of wrapping to a large value.
- `incrthreshold` (bool, or integer N): a level output (not a pulse)
  that is 1 whenever the counter's *current stored value* is at or
  above a threshold — the field's max value (bool form) or N (integer
  form).
- `overflow`: a one-cycle pulse, asserted exactly on a cycle where an
  increment operation's true mathematical result would exceed the
  field's maximum representable value (i.e. it would wrap). Mutually
  exclusive with incrsaturate (if saturating, it never wraps, so
  overflow wouldn't fire).
- `underflow`: same idea, a one-cycle pulse when a decrement would go
  below zero. Mutually exclusive with decrsaturate.

## precedence (default: `sw`)

Determines who wins if, in the same clock cycle, both a genuine
hardware write and a genuine software write (nonzero wstrb) are
attempted simultaneously on the same field:

- `precedence = sw` (the default when unspecified): software's new
  value becomes the field's next value that cycle; the simultaneous
  hardware write is discarded for that cycle.
- `precedence = hw`: the opposite — hardware's new value wins; the
  simultaneous software write is discarded that cycle.
- When only one side writes in a given cycle (no race), that side's
  write always takes effect regardless of the precedence setting.

## we / wel (hardware write-enable, external condition)

- `we`: hardware's ability to write the field is gated by an external
  enable condition (a signal or boolean). A hardware write attempt only
  actually changes the stored value while the condition is asserted
  (logic 1). While the condition is 0, a hardware write attempt has no
  effect at all (the field keeps its previous value that cycle).
- `wel`: same concept, but active-low — a hardware write only takes
  effect while the condition is 0; the write is blocked whenever the
  condition is 1.

## swwe / swwel

Identical concept to we/wel, but the gated side is software's write
instead of hardware's: `swwe` requires the condition to be 1 for a
software write to take effect (masked-merge, woclr, etc. — whatever
onwrite policy is configured); `swwel` requires the condition to be 0.
When the condition doesn't hold, software's write attempt has no effect
(as if it never wrote) that cycle.

## hwenable / hwmask (per-bit hardware write mask, external N-bit condition)

- `hwenable`: an N-bit external condition. When hardware writes the
  field, only the bit positions where the condition is 1 are actually
  updated to the new value; bit positions where the condition is 0 keep
  their previous value, regardless of what hardware presented for that
  bit.
- `hwmask`: the inverse — bit positions where the condition is 1 are
  excluded from the hardware write (keep their previous value); bit
  positions where the condition is 0 are updated normally.
- Mutually exclusive with each other (a field has at most one of the
  two).

## next (external N-bit condition, completely overrides normal storage)

When `next` is configured, the field's stored value is NOT arbitrated
between hw/sw writes at all. Instead, every clock cycle, the field
unconditionally takes on whatever value the external `next` condition
currently presents — a direct continuous feed into the storage element,
with no other write mechanism (sw write, hw write, onwrite side
effects, counter logic, sticky, etc.) having any effect once `next` is
configured.

## resetsignal (external 1-bit condition, activehigh or activelow)

When configured, the field's storage element resets to its specified
reset value whenever this external condition is asserted (1 for
activehigh, 0 for activelow) — this is a genuinely separate,
independently-triggerable reset condition for just this field's
storage, distinct from the design's own default/global reset.

## sticky (whole-field freeze)

Once the field's stored value becomes nonzero (via a hardware write),
the field is frozen: no subsequent hardware write can change its value
at all, regardless of what hardware presents, until the value is reset
back to zero by some other mechanism (a software write, an onwrite side
effect such as woclr, or an explicit clear/hwclr condition). While the
stored value is still zero, hardware writes take effect normally.

## stickybit (per-bit freeze)

A per-bit version of the above: once an individual bit of the field
becomes 1 via a hardware write, that specific bit can never be cleared
back to 0 by a further hardware write (only by software, or an explicit
clear mechanism) — hardware writes effectively OR their value into the
field rather than replacing it. Hardware CAN still set additional bits
that were previously 0.

## intr (register-level interrupt aggregation)

A field marked `intr` contributes to a single-bit "interrupt pending"
output for its enclosing register: that output is 1 whenever ANY bit of
ANY intr-marked field in the register currently holds a 1 (after that
field's own enable/mask qualification below is applied). A register
with no intr-marked fields has no such output at all.

- `enable` (external N-bit condition, matching the field's width):
  qualifies which bits of THIS field contribute to the interrupt
  aggregate — only bit positions where the condition is 1 are
  considered; other bits never contribute regardless of their stored
  value.
- `mask` (external N-bit condition): the inverse of `enable` for the
  same purpose — bit positions where the condition is 1 are excluded
  from contributing; positions where it's 0 do contribute. Mutually
  exclusive with `enable`.
- `haltenable` / `haltmask`: identical concept and mutual exclusivity to
  `enable`/`mask`, but they qualify contributions to a *completely
  separate* one-bit aggregate output, conventionally called "halt",
  independent of the interrupt aggregate above. A register only gets a
  halt output if at least one of its fields sets haltenable or
  haltmask.

## sw access variants (na, w1/rw1)

- `sw = na`: software cannot read or write the field at all (no bus
  methods). Not modeled here as a standalone config since it has no
  read/write behavior to check; it's mentioned for completeness only.
- `sw = w1` / `sw = rw1`: readable-and/or-writable like `w`/`rw`, with
  an additional "write only once after reset" restriction *in the full
  SystemRDL spec*. For the purposes of these reference models, assume
  the write-once restriction is NOT enforced by the design under test
  (i.e. behave exactly like plain `w`/`rw`) — only model the base
  read/write behavior, do not add any one-shot-lockout logic.
- `hw = na`: hardware can neither read nor write the field — it behaves
  as pure software-only storage (still has whatever onwrite/onread side
  effects are configured; only the hw port is absent).

## Combining multiple properties on one field

Field configurations below may combine two or more of the properties
above on the same field. Unless stated otherwise, properties combine by
each applying its own transformation in the natural order implied by
their descriptions above — e.g. a hw write first has we/wel's enable
check applied (does the write happen at all?), then hwenable/hwmask's
per-bit qualification (which bits of it apply?), then sticky/stickybit's
freeze/OR behavior wraps the result of that. Software writes and
onwrite side effects (woclr etc.) are entirely independent of any of
the hardware-side properties (we/wel/hwenable/hwmask/sticky/stickybit)
since those only ever gate/transform the *hardware* write path.
`precedence` only matters when determining which side's change wins a
genuine same-cycle race; it does not change either side's own
already-qualified update logic. `next`, when present, overrides
*everything* else on that field — no other property in this document
has any observable effect once `next` is configured, since the field's
storage takes its value directly from the external `next` condition
every cycle regardless of any attempted sw write, hw write, onwrite
side effect, counter operation, or sticky/stickybit state.
`resetsignal` only affects when the storage resets to its declared
reset value; it doesn't change any of the update logic above.
