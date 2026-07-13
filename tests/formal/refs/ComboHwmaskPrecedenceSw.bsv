// ComboHwmaskPrecedenceSw.bsv
//
// Config #13: sw=rw, hw=rw, precedence=sw (the default) AND an 8-bit
// hwmask condition together.
//
// Understanding of the spec ("hwmask" + "precedence" + "Combining
// multiple properties" sections):
//   - hwmask: "the inverse [of hwenable] -- bit positions where the
//     condition is 1 are excluded from the hardware write (keep their
//     previous value); bit positions where the condition is 0 are
//     updated normally." So hw's per-bit-qualified next value is
//     `(data & ~hwmask) | (r & hwmask)`.
//   - precedence=sw is the explicit default: "software's new value
//     becomes the field's next value that cycle; the simultaneous
//     hardware write is discarded for that cycle" on a genuine
//     same-cycle race. Per the combining section, precedence resolves
//     AFTER each side's own qualification is already computed -- it does
//     not itself change hw's hwmask-qualified logic, it just decides
//     whose (fully-qualified) result the register takes on a race.
//   - When only one side writes in a given cycle, that side's own
//     qualified write always takes effect regardless of precedence.
//
// Judgment call: as with the other hwenable/hwmask configs, a "genuine
// hw write" for race-arbitration purposes is any hwWrite call this
// cycle, independent of whether hwmask happens to make its net effect a
// no-op for some/all bits that cycle.
package ComboHwmaskPrecedenceSw;

interface ComboHwmaskPrecedenceSw;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    method Action hwWrite(Bit#(8) data);
    method Bit#(8) rd;
endinterface

// hwmask: external 8-bit per-bit hardware write exclusion mask.
module mkComboHwmaskPrecedenceSw#(Bit#(8) hwmask)(ComboHwmaskPrecedenceSw);
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
            // hwmask: masked-1 bits keep previous value; masked-0 bits update.
            hwNext = (data & ~hwmask) | (r & hwmask);
        end

        if (swFires)
            r <= swNext;        // precedence=sw wins a genuine race
        else if (hwFires)
            r <= hwNext;
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
