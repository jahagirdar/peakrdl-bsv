// ComboWeHwenable.bsv
//
// Config #10: sw=rw, hw=rw, an active-high `we` condition AND an 8-bit
// hwenable condition together (both hw-side gates active at once).
//
// Understanding of the spec ("we" + "hwenable" + "Combining multiple
// properties" sections):
//   - The combining section gives an explicit order: "a hw write first
//     has we/wel's enable check applied (does the write happen at all?),
//     then hwenable/hwmask's per-bit qualification (which bits of it
//     apply?)."
//   - we: "a hardware write attempt only actually changes the stored
//     value while the condition is asserted (logic 1). While the
//     condition is 0, a hardware write attempt has no effect at all."
//     So when we==0, the ENTIRE hw write is void this cycle -- hwenable
//     never even gets consulted.
//   - hwenable: when we==1 (the write does happen), only bit positions
//     where hwenable==1 are actually updated to hw's new value; other
//     bit positions keep their previous value.
//   - precedence is unspecified for this config, so default
//     precedence=sw applies for a genuine same-cycle race, where a
//     "genuine hw write" (for arbitration purposes) is one that actually
//     clears the we gate (we==1) -- a hwWrite call with we==0 is not a
//     write attempt at all per the we section's own wording, so it can't
//     be "genuine" for racing against sw either.
//
// Judgment call: unlike hwenable/hwmask (which qualify a write's per-bit
// RESULT but don't affect whether the write attempt counts as genuine),
// `we`==0 is explicitly "no effect at all" per the spec -- so we treat a
// we==0 hwWrite call as not a genuine write attempt for race-arbitration
// purposes at all (consistent with the existing We.bsv reference's
// judgment call), whereas ComboPrecedenceHwHwenable.bsv treats hwenable
// as not affecting genuineness.
package ComboWeHwenable;

interface ComboWeHwenable;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    // we: active-high hardware write-enable, sampled alongside hwWrite.
    method Action hwWrite(Bit#(8) data, Bool we);
    method Bit#(8) rd;
endinterface

// hwenable: external 8-bit per-bit hardware write mask, consulted only
// when we==1.
module mkComboWeHwenable#(Bit#(8) hwenable)(ComboWeHwenable);
    Reg#(Bit#(8)) r <- mkRegA(0);
    RWire#(Tuple2#(Bit#(8), Bit#(8))) swReq <- mkRWire;
    RWire#(Tuple2#(Bit#(8), Bool))    hwReq <- mkRWire;

    rule arbitrate;
        Bool swFires = False;
        Bit#(8) swNext = r;
        if (swReq.wget matches tagged Valid {.data, .wstrb} &&& wstrb != 0) begin
            swFires = True;
            swNext = (data & wstrb) | (~wstrb & r);
        end

        Bool hwFires = False;
        Bit#(8) hwNext = r;
        if (hwReq.wget matches tagged Valid {.data, .we} &&& we) begin
            hwFires = True;
            // we==1 gate passed; now apply hwenable per-bit qualification.
            hwNext = (data & hwenable) | (r & ~hwenable);
        end

        if (swFires)
            r <= swNext;        // default precedence=sw wins a genuine race
        else if (hwFires)
            r <= hwNext;
    endrule

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
        swReq.wset(tuple2(data, wstrb));
    endmethod

    method Action hwWrite(Bit#(8) data, Bool we);
        hwReq.wset(tuple2(data, we));
    endmethod

    method Bit#(8) rd;
        return r;
    endmethod
endmodule

endpackage
