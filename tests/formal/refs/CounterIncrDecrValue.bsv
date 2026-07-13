// CounterIncrDecrValue.bsv
//
// Config #1: sw=r, hw=r, counter with incrvalue=5 AND decrvalue=3
// (bidirectional, both fixed-amount pulses, no data argument on either
// side).
//
// Understanding of the spec (Counter section):
//   - incrvalue=N: "increment direction is active; each increment pulse
//     (hardware supplies no data, just a pulse) adds a fixed constant N."
//     Here N=5.
//   - decrvalue=N: same idea for decrement; here N=3.
//   - incrvalue/decrvalue are the "fixed constant" forms, mutually
//     exclusive with incrwidth/decrwidth (the "variable per-call amount"
//     forms) in each respective direction. Neither incrwidth nor
//     decrwidth is configured here.
//   - No incrsaturate/decrsaturate/overflow/underflow/incrthreshold is
//     configured for this config, so plain wraparound arithmetic applies
//     in both directions (no clamping, no pulse/level outputs beyond the
//     stored value itself).
//   - sw=r: no software write port; hw=r: the value is readable by
//     hardware/status logic too, but that's the same `rd` method used by
//     software here since neither side has any distinguishing access
//     restriction beyond "read-only".
//
// Judgment calls:
//   - Two independent data-less pulse methods, `incr` and `decr`, model
//     the incrvalue/decrvalue fixed-amount pulses.
//   - If both incr and decr are pulsed the same cycle, we apply both
//     deltas together (r + 5 - 3) since the spec doesn't call out any
//     special same-cycle incr/decr interaction for this config (overflow/
//     underflow/saturate logic -- which WOULD need to arbitrate that --
//     is simply absent here).
package CounterIncrDecrValue;

interface CounterIncrDecrValue;
    // incrvalue=5: hardware's data-less increment pulse, adds a fixed 5.
    method Action incr;
    // decrvalue=3: hardware's data-less decrement pulse, subtracts a fixed 3.
    method Action decr;
    method Bit#(8) rd;
endinterface

module mkCounterIncrDecrValue(CounterIncrDecrValue);
    Reg#(Bit#(8)) r <- mkRegA(0);
    RWire#(Bool) incrPulse <- mkRWire;
    RWire#(Bool) decrPulse <- mkRWire;

    rule doCount;
        Bit#(8) next = r;
        Bool doIncr = isValid(incrPulse.wget);
        Bool doDecr = isValid(decrPulse.wget);
        if (doIncr)
            next = next + 5;
        if (doDecr)
            next = next - 3;
        if (doIncr || doDecr)
            r <= next;
    endrule

    method Action incr;
        incrPulse.wset(True);
    endmethod

    method Action decr;
        decrPulse.wset(True);
    endmethod

    method Bit#(8) rd;
        return r;
    endmethod
endmodule

endpackage
