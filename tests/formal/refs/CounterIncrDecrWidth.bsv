// CounterIncrDecrWidth.bsv
//
// Config #2: sw=r, hw=r, counter with incrwidth=8 AND decrwidth=8
// (bidirectional, both take an explicit 8-bit count argument each
// operation).
//
// Understanding of the spec (Counter section):
//   - incrwidth=N: "increment direction is active; hardware supplies an
//     explicit N-bit count value with each increment operation (the
//     amount varies per-call, not fixed)." Here N=8, matching the
//     field's own width, so the increment amount can be any value
//     0..255 per call.
//   - decrwidth=N: same idea for decrement; here N=8 as well.
//   - No saturate/overflow/underflow/threshold configured, so plain
//     wraparound arithmetic in both directions.
//
// Judgment calls:
//   - Each direction gets its own Action method taking a Bit#(8) amount
//     argument, since incrwidth/decrwidth explicitly means "hardware
//     supplies an explicit N-bit count value" (as opposed to the
//     data-less pulse of incrvalue/decrvalue).
//   - As with CounterIncrDecrValue, if both incr and decr fire the same
//     cycle, both amounts are applied together (r + incrAmt - decrAmt);
//     nothing in the spec suggests same-cycle incr+decr should be
//     mutually exclusive or prioritized absent saturate/overflow logic.
package CounterIncrDecrWidth;

interface CounterIncrDecrWidth;
    // incrwidth=8: hardware supplies an explicit 8-bit increment amount.
    method Action incr(Bit#(8) amt);
    // decrwidth=8: hardware supplies an explicit 8-bit decrement amount.
    method Action decr(Bit#(8) amt);
    method Bit#(8) rd;
endinterface

module mkCounterIncrDecrWidth(CounterIncrDecrWidth);
    Reg#(Bit#(8)) r <- mkRegA(0);
    RWire#(Bit#(8)) incrReq <- mkRWire;
    RWire#(Bit#(8)) decrReq <- mkRWire;

    rule doCount;
        Bit#(8) next = r;
        Bool doIncr = isValid(incrReq.wget);
        Bool doDecr = isValid(decrReq.wget);
        if (incrReq.wget matches tagged Valid .amt)
            next = next + amt;
        if (decrReq.wget matches tagged Valid .amt)
            next = next - amt;
        if (doIncr || doDecr)
            r <= next;
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
endmodule

endpackage
