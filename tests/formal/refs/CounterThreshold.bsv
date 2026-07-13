// CounterThreshold.bsv
//
// Config #4: sw=r, hw=r, counter (bare, default increment-only, fixed
// +1) with incrthreshold=200 (integer form). Exposes the threshold's
// level output.
//
// Understanding of the spec (Counter section):
//   - "bare" counter, no incrvalue/incrwidth configured: "increment-only,
//     incrementing by a fixed amount of 1 each time hardware pulses a
//     (data-less) increment control."
//   - incrthreshold (integer form, N=200): "a level output (not a pulse)
//     that is 1 whenever the counter's *current stored value* is at or
//     above a threshold ... N (integer form)." This is a combinational
//     level derived from the stored value, not a clocked pulse -- it
//     reflects `r >= 200` continuously, updating the same cycle the
//     stored value itself changes (since it's a function of state, not
//     an edge-triggered event).
//   - No incrsaturate/overflow configured, so plain wraparound at 255->0
//     applies to the increment itself; incrthreshold only affects the
//     level output, not the counting arithmetic.
//
// Judgment call: the threshold level is exposed as a plain (non-Action)
// method computed directly from the current register value each time
// it's read (`r >= 200`), since it's explicitly a level, not a
// stateful/pulsed quantity -- no separate register is needed to hold it.
package CounterThreshold;

interface CounterThreshold;
    // Bare counter: hardware's data-less increment pulse, fixed +1.
    method Action incr;
    method Bit#(8) rd;
    // incrthreshold=200: level output, 1 iff current value >= 200.
    method Bool thresholdLevel;
endinterface

module mkCounterThreshold(CounterThreshold);
    Reg#(Bit#(8)) r <- mkRegA(0);
    RWire#(Bool) incrPulse <- mkRWire;

    rule doIncr (incrPulse.wget matches tagged Valid .fire &&& fire);
        r <= r + 1;     // fixed +1, plain wraparound (255 -> 0), no saturate
    endrule

    method Action incr;
        incrPulse.wset(True);
    endmethod

    method Bit#(8) rd;
        return r;
    endmethod

    method Bool thresholdLevel;
        return r >= 200;
    endmethod
endmodule

endpackage
