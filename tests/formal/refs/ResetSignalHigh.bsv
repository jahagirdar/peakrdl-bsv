// ResetSignalHigh.bsv
//
// Config #5: sw=rw, hw=r, with an activehigh `resetsignal` external
// condition as an extra module input.
//
// Understanding of the spec:
//   - resetsignal describes a *field-local*, independently-triggerable
//     reset that is genuinely separate from the design's own default
//     reset -- not just "force the register to 0 combinationally when a
//     condition holds". The task explicitly asks for a second,
//     independently-resettable Reg built via BSV's Clocks package.
//   - activehigh: the field resets (back to its reset value, 0 for this
//     model) whenever the external condition reads as 1.
//
// Implementation approach (Clocks package):
//   - `mkReset` creates a fresh Reset signal (`new_rst`) plus an
//     `assertReset` action method that pulses that new reset domain.
//   - A rule, guarded by the (sampled) external condition, calls
//     `assertReset` every cycle the condition holds -- so the reset stays
//     asserted for as long as the external condition is asserted, and
//     deasserts (allowing normal operation to resume) as soon as the
//     condition drops, exactly matching a level-sensitive resetsignal.
//   - The field's storage register is built with `mkRegA(0, reset_by
//     rstIfc.new_rst)`, i.e. its *sole* reset source is this new domain
//     -- NOT the module's ambient/default reset. This matches "distinct
//     from the design's own default/global reset": whether the ambient
//     reset also affects the field is left out of scope for this model,
//     since the spec calls out resetsignal as an independent mechanism
//     to be modeled in isolation.
//
// Judgment calls:
//   - The external condition is exposed as a per-cycle input via an
//     "always fed" method (`setResetCond`), sampled through an RWire, on
//     the assumption a testbench drives it exactly once per cycle (like
//     an always_ready/always_enabled hardware input port). If it is not
//     driven in a given cycle we default to "not asserted" (False) so
//     the field behaves like a normal rw register absent explicit
//     resetsignal activity.
//   - Used `mkReset(1, True, curClk)`: a 1-cycle reset delay parameter
//     and `True` for the reset's default/inactive polarity value used by
//     the library API; this is the conventional minimal instantiation
//     and is not meant to imply any particular synchronizer depth.
//   - While the new reset domain is asserted, sw writes are also
//     naturally suppressed (a reset register ignores its D input), which
//     matches the intuitive meaning of "resets ... whenever asserted".
package ResetSignalHigh;

import Clocks::*;

interface ResetSignalHigh;
    // External activehigh reset condition; sample every cycle.
    method Action setResetCond(Bool cond);
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    method Bit#(8) swRead;
    method Bit#(8) hwRead;
endinterface

module mkResetSignalHigh(ResetSignalHigh);
    Clock curClk <- exposeCurrentClock;
    MakeResetIfc rstIfc <- mkReset(1, True, curClk);

    RWire#(Bool) condWire <- mkRWire;

    // Keep the new reset domain asserted for as long as the external
    // condition is asserted this cycle (default False if undriven).
    rule driveReset (fromMaybe(False, condWire.wget));
        rstIfc.assertReset;
    endrule

    Reg#(Bit#(8)) r <- mkRegA(0, reset_by rstIfc.new_rst);

    method Action setResetCond(Bool cond);
        condWire.wset(cond);
    endmethod

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
        if (wstrb != 0) begin
            r <= (data & wstrb) | (~wstrb & r);
        end
    endmethod

    method Bit#(8) swRead;
        return r;
    endmethod

    method Bit#(8) hwRead;
        return r;
    endmethod
endmodule

endpackage
