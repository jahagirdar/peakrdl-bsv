// CounterSaturateBoth.bsv
//
// Config #3: sw=r, hw=r, counter with incrsaturate=200 (integer form --
// clamps at 200, not the field's max 255) AND decrsaturate (bool form --
// clamps at 0). Bidirectional via incrwidth=8/decrwidth=8, so both
// directions take an explicit hardware-supplied count.
//
// Understanding of the spec (Counter section):
//   - incrwidth=8 / decrwidth=8: hardware supplies an explicit 8-bit
//     count with each increment/decrement operation.
//   - incrsaturate (integer form, N=200): "clamps at that ceiling
//     instead of wrapping around" -- so incrementing that would take the
//     stored value above 200 instead clamps the result AT 200 exactly
//     (not at 255, the field's natural max).
//   - decrsaturate (bool form): "clamps instead of wrapping to a large
//     value" at the floor of 0 (the bool form's implicit floor, since no
//     integer N is given).
//   - overflow/underflow are mutually exclusive with incrsaturate/
//     decrsaturate respectively and are not configured here, so no pulse
//     outputs are modeled.
//
// Judgment calls:
//   - Saturation math is done in a wider intermediate (Int#(10)) to avoid
//     ambiguity around Bit#(8) wraparound while computing "would this
//     exceed 200 / go below 0" before clamping back down to Bit#(8).
//   - When both incr and decr fire the same cycle, each direction's
//     delta and its own saturation ceiling/floor are applied against the
//     current value in the same combinational step, i.e.
//     tmp = clampIncr(r + incrAmt); result = clampDecr(tmp - decrAmt).
//     This mirrors the CounterIncrDecrWidth judgment call (apply both
//     deltas together) but layers each side's own saturation rule on top
//     of its own delta, since the spec ties incrsaturate strictly to the
//     increment direction and decrsaturate strictly to the decrement
//     direction.
package CounterSaturateBoth;

interface CounterSaturateBoth;
    // incrwidth=8, incrsaturate=200: increment by an explicit amount,
    // clamping the result at 200.
    method Action incr(Bit#(8) amt);
    // decrwidth=8, decrsaturate (bool): decrement by an explicit amount,
    // clamping the result at 0.
    method Action decr(Bit#(8) amt);
    method Bit#(8) rd;
endinterface

module mkCounterSaturateBoth(CounterSaturateBoth);
    Reg#(Bit#(8)) r <- mkRegA(0);
    RWire#(Bit#(8)) incrReq <- mkRWire;
    RWire#(Bit#(8)) decrReq <- mkRWire;

    Int#(10) incrCeil = 200;

    rule doCount;
        Int#(10) cur = unpack(zeroExtend(r));
        Bool doIncr = isValid(incrReq.wget);
        Bool doDecr = isValid(decrReq.wget);

        if (incrReq.wget matches tagged Valid .amt) begin
            Int#(10) sum = cur + unpack(zeroExtend(amt));
            cur = (sum > incrCeil) ? incrCeil : sum;   // incrsaturate=200
        end

        if (decrReq.wget matches tagged Valid .amt) begin
            Int#(10) diff = cur - unpack(zeroExtend(amt));
            cur = (diff < 0) ? 0 : diff;                // decrsaturate: floor 0
        end

        if (doIncr || doDecr)
            r <= truncate(pack(cur));
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
