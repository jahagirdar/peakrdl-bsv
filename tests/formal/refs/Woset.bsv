// Woset.bsv
//
// Config #1: sw=rw, hw=r, onwrite=woset.
//
// Understanding of the spec:
//   - Base 8-bit field, hw read-only, sw read/write.
//   - onwrite=woset replaces the default masked-merge write policy:
//     "writing a 1 to a bit position sets that bit to 1. A 0 leaves it
//     unchanged." wstrb still gates which bits of `data` count as
//     "written 1" at all.
//   - setMask = data & wstrb (bits genuinely written as 1)
//     next     = r | setMask
//   - wstrb == 0 is a total no-op (setMask is all-zero, no update at all).
//
// Judgment calls:
//   - None: onread/swacc/swmod are not in play for this config, so plain
//     read methods suffice.
package Woset;

interface Woset;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    method Bit#(8) swRead;
    method Bit#(8) hwRead;
endinterface

module mkWoset(Woset);
    Reg#(Bit#(8)) r <- mkRegA(0);

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
        if (wstrb != 0) begin
            Bit#(8) setMask = data & wstrb;
            r <= r | setMask;
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
