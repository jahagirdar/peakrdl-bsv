// ComboStickybitHwenable.bsv
//
// Config #11: sw=rw, hw=rw, stickybit AND an 8-bit hwenable condition
// together (hw can only set enabled bits, and once set, no hw write --
// enabled or not -- can clear them).
//
// Understanding of the spec ("stickybit" + "hwenable" + "Combining
// multiple properties" sections):
//   - The combining section's stated order: hwenable/hwmask's per-bit
//     qualification applies first ("which bits of it apply?"), then
//     "sticky/stickybit's freeze/OR behavior wraps the result of that."
//   - hwenable alone would produce: qualified = (data & hwenable) |
//     (r & ~hwenable) -- new value on enabled bits, hold on disabled
//     bits.
//   - stickybit then wraps that: "hardware writes effectively OR their
//     value into the field rather than replacing it. Hardware CAN still
//     set additional bits that were previously 0." So the final hw-write
//     result is `qualified | r`, which algebraically simplifies to
//     `r | (data & hwenable)` (since `(r & ~hwenable) | r == r`): any bit
//     already 1 in the stored value stays 1 regardless of hwenable/data
//     that cycle (frozen), and only currently-0, hwenable-qualified bits
//     can newly become 1 from hw's data.
//   - Software's write path is completely independent of stickybit/
//     hwenable (per "Software writes and onwrite side effects ... are
//     entirely independent of any of the hardware-side properties"), so
//     sw can still clear any bit via a normal masked-merge write -- this
//     is the "explicit clear mechanism" the stickybit section alludes
//     to ("only by software, or an explicit clear mechanism").
//   - precedence is unspecified, so default precedence=sw applies for a
//     genuine same-cycle race.
//
// Judgment call: a "genuine hw write" for race-arbitration purposes is
// any hwWrite call this cycle, regardless of whether stickybit/hwenable
// happen to make its net effect a no-op that cycle (e.g. hwenable==0
// everywhere, or all target bits already frozen at 1) -- same reasoning
// as ComboPrecedenceHwHwenable.bsv's judgment call for hwenable alone.
package ComboStickybitHwenable;

interface ComboStickybitHwenable;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    method Action hwWrite(Bit#(8) data);
    method Bit#(8) rd;
endinterface

// hwenable: external 8-bit per-bit hardware write mask, combined with
// stickybit's per-bit freeze/OR behavior.
module mkComboStickybitHwenable#(Bit#(8) hwenable)(ComboStickybitHwenable);
    Reg#(Bit#(8)) r <- mkRegA(0);
    RWire#(Tuple2#(Bit#(8), Bit#(8))) swReq <- mkRWire;
    RWire#(Bit#(8)) hwReq <- mkRWire;

    rule arbitrate;
        Bool swFires = False;
        Bit#(8) swNext = r;
        if (swReq.wget matches tagged Valid {.data, .wstrb} &&& wstrb != 0) begin
            swFires = True;
            swNext = (data & wstrb) | (~wstrb & r);   // sw path: independent of stickybit/hwenable
        end

        Bool hwFires = False;
        Bit#(8) hwNext = r;
        if (hwReq.wget matches tagged Valid .data) begin
            hwFires = True;
            // hwenable qualification then stickybit OR-wrap, combined:
            // already-1 bits stay 1 (frozen); only 0 bits with hwenable=1
            // can newly be set from data.
            hwNext = r | (data & hwenable);
        end

        if (swFires)
            r <= swNext;        // default precedence=sw wins a genuine race
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
