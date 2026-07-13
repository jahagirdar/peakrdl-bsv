// CounterOverflowUnderflow.bsv
//
// Config #5: sw=r, hw=r, counter with incrwidth=8 AND decrwidth=8
// (bidirectional, explicit counts), overflow AND underflow both
// configured. Exposes both pulse outputs.
//
// Understanding of the spec (Counter section):
//   - incrwidth=8 / decrwidth=8: hardware supplies an explicit 8-bit
//     count with each increment/decrement operation.
//   - overflow: "a one-cycle pulse, asserted exactly on a cycle where an
//     increment operation's true mathematical result would exceed the
//     field's maximum representable value (i.e. it would wrap)."
//     Mutually exclusive with incrsaturate (not configured here), so
//     the counter DOES wrap on overflow, and the pulse simply flags that
//     it happened.
//   - underflow: same idea for decrement going below zero; the counter
//     wraps to a large value and the pulse flags it.
//   - Neither incrsaturate/decrsaturate/incrthreshold is configured, so
//     no clamping and no level output here.
//
// Judgment calls:
//   - Overflow/underflow are computed from the true mathematical
//     (unclamped, unwrapped) result in a wider intermediate (Int#(10)),
//     comparing against 255/0 BEFORE truncating back to Bit#(8) for the
//     actual wraparound store -- this matches "true mathematical result"
//     language distinctly from the final wrapped stored value.
//   - If both incr and decr fire the same cycle, each is evaluated (and
//     its own overflow/underflow flag raised if applicable) against the
//     current value in sequence (increment's result feeds decrement's
//     input), consistent with the same-cycle combination judgment made
//     in CounterIncrDecrWidth/CounterSaturateBoth.
//   - Both pulse outputs are exposed as plain Bool methods representing
//     "did this fire on the immediately-preceding doCount rule firing"
//     via a pulse register (set for exactly one cycle), following the
//     "one-cycle pulse" wording literally.
package CounterOverflowUnderflow;

interface CounterOverflowUnderflow;
    method Action incr(Bit#(8) amt);
    method Action decr(Bit#(8) amt);
    method Bit#(8) rd;
    // overflow: one-cycle pulse, true increment result exceeded 255.
    method Bool overflowPulse;
    // underflow: one-cycle pulse, true decrement result went below 0.
    method Bool underflowPulse;
endinterface

module mkCounterOverflowUnderflow(CounterOverflowUnderflow);
    Reg#(Bit#(8)) r <- mkRegA(0);
    Reg#(Bool) overflowReg  <- mkRegA(False);
    Reg#(Bool) underflowReg <- mkRegA(False);
    RWire#(Bit#(8)) incrReq <- mkRWire;
    RWire#(Bit#(8)) decrReq <- mkRWire;

    rule doCount;
        Int#(10) cur = unpack(zeroExtend(r));
        Bool doIncr = isValid(incrReq.wget);
        Bool doDecr = isValid(decrReq.wget);
        Bool ovf = False;
        Bool unf = False;

        if (incrReq.wget matches tagged Valid .amt) begin
            Int#(10) sum = cur + unpack(zeroExtend(amt));
            if (sum > 255) ovf = True;     // true mathematical result exceeds max
            cur = sum;                      // wrap happens naturally via truncate below
        end

        if (decrReq.wget matches tagged Valid .amt) begin
            Int#(10) diff = cur - unpack(zeroExtend(amt));
            if (diff < 0) unf = True;      // true mathematical result below 0
            cur = diff;
        end

        if (doIncr || doDecr)
            r <= truncate(pack(cur));       // natural wraparound (no saturate configured)
        overflowReg  <= doIncr && ovf;
        underflowReg <= doDecr && unf;
    endrule

    method Action incr(Bit#(8) amt);
        incrReq.wset(amt);
    endmethod

    method Action decr(Bit#(8) amt);
        decrReq.wset(amt);
    endmethod

    method Bit#(8) rd;
        return r;
    endmethod

    method Bool overflowPulse;
        return overflowReg;
    endmethod

    method Bool underflowPulse;
        return underflowReg;
    endmethod
endmodule

endpackage
