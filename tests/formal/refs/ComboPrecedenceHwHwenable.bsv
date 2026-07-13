// ComboPrecedenceHwHwenable.bsv
//
// Config #9: sw=rw, hw=rw, precedence=hw AND an 8-bit hwenable condition
// together.
//
// Understanding of the spec ("precedence" + "hwenable" + "Combining
// multiple properties" sections):
//   - hwenable: "an N-bit external condition. When hardware writes the
//     field, only the bit positions where the condition is 1 are
//     actually updated to the new value; bit positions where the
//     condition is 0 keep their previous value." This produces hw's
//     fully-qualified next value BEFORE any precedence arbitration, per
//     the combining section's stated order ("a hw write first has
//     we/wel's enable check applied ..., then hwenable/hwmask's per-bit
//     qualification ...").
//   - precedence=hw: "the opposite [of default] -- hardware's new value
//     wins; the simultaneous software write is discarded that cycle."
//     Per the combining section, "precedence only matters when
//     determining which side's change wins a genuine same-cycle race; it
//     does not change either side's own already-qualified update logic."
//     So on a race, the register takes hw's ALREADY hwenable-qualified
//     next value wholesale (which itself may retain some bits from the
//     old value, for hwenable==0 positions) -- sw's computed next value
//     is discarded in its entirety, not merged bit-by-bit with hw's.
//   - When only one side writes in a given cycle (no race), that side's
//     own (already-qualified, for hw) write always takes effect
//     regardless of precedence.
//
// Judgment call: "genuine hw write" for race-detection purposes is any
// hwWrite call this cycle (i.e. the pulse/method firing), independent of
// whether hwenable happens to be all-zero that cycle (which would make
// its qualified next value equal to the old value) -- hwenable
// qualifies the RESULT of a hw write, not whether a hw write attempt
// counts as "genuine" for arbitration purposes.
package ComboPrecedenceHwHwenable;

interface ComboPrecedenceHwHwenable;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    method Action hwWrite(Bit#(8) data);
    method Bit#(8) rd;
endinterface

// hwenable: external 8-bit per-bit hardware write mask.
module mkComboPrecedenceHwHwenable#(Bit#(8) hwenable)(ComboPrecedenceHwHwenable);
    Reg#(Bit#(8)) r <- mkRegA(0);
    RWire#(Tuple2#(Bit#(8), Bit#(8))) swReq <- mkRWire;
    RWire#(Bit#(8)) hwReq <- mkRWire;

    rule arbitrate;
        Bool swFires = False;
        Bit#(8) swNext = r;
        if (swReq.wget matches tagged Valid {.data, .wstrb} &&& wstrb != 0) begin
            swFires = True;
            swNext = (data & wstrb) | (~wstrb & r);
        end

        Bool hwFires = False;
        Bit#(8) hwNext = r;
        if (hwReq.wget matches tagged Valid .data) begin
            hwFires = True;
            // hwenable per-bit qualification, applied before any arbitration.
            hwNext = (data & hwenable) | (r & ~hwenable);
        end

        if (swFires && hwFires)
            r <= hwNext;         // precedence=hw: hw's already-qualified value wins the race
        else if (hwFires)
            r <= hwNext;
        else if (swFires)
            r <= swNext;
    endrule

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
        swReq.wset(tuple2(data, wstrb));
    endmethod

    method Action hwWrite(Bit#(8) data);
        hwReq.wset(data);
    endmethod

    method Bit#(8) rd;
        return r;
    endmethod
endmodule

endpackage
