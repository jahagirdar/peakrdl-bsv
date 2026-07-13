// ResetSignalLow.bsv
//
// Config #6: same as ResetSignalHigh, but the external resetsignal
// condition is activelow: the field resets whenever the condition reads
// as 0 (and behaves normally while the condition reads as 1).
//
// See ResetSignalHigh.bsv for the full discussion of the Clocks-package
// approach and the per-cycle sampling assumption. The only difference
// here is the polarity of the rule guard driving assertReset, and the
// "undriven" default: since 1 = not-asserted for activelow, we default
// an undriven condWire to True (i.e. "not asserted") for consistency
// with "absent signal => resetsignal not currently triggering".
package ResetSignalLow;

import Clocks::*;

interface ResetSignalLow;
    // External activelow reset condition; sample every cycle. Reset is
    // asserted when this value is False (0).
    method Action setResetCond(Bool cond);
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    method Bit#(8) swRead;
    method Bit#(8) hwRead;
endinterface

module mkResetSignalLow(ResetSignalLow);
    Clock curClk <- exposeCurrentClock;
    MakeResetIfc rstIfc <- mkReset(1, True, curClk);

    RWire#(Bool) condWire <- mkRWire;

    // Assert the new reset domain while the external condition reads 0.
    // Undriven cycles default to True (not-asserted, condition == 1).
    rule driveReset (!fromMaybe(True, condWire.wget));
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
