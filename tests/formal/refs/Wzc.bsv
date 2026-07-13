// Wzc.bsv
//
// Config #3: sw=rw, hw=r, onwrite=wzc ("write zero to clear").
//
// Understanding of the spec:
//   - onwrite=wzc: "writing a 0 to a bit position (where wstrb selects
//     that bit) clears that bit to 0. A 1 leaves it unchanged."
//   - A bit is cleared exactly when wstrb selects it (wstrb==1) AND the
//     presented data bit is 0.
//       clearMask = wstrb & ~data
//       next      = r & ~clearMask
//   - wstrb == 0 is a total no-op: clearMask is all-zero automatically
//     since wstrb gates every term, but we still guard on wstrb != 0
//     explicitly to keep the "no qualifying write at all" case obvious
//     and consistent with every other onwrite config in this set.
//
// Judgment calls:
//   - None beyond the wstrb-gating already described.
package Wzc;

interface Wzc;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    method Bit#(8) swRead;
    method Bit#(8) hwRead;
endinterface

module mkWzc(Wzc);
    Reg#(Bit#(8)) r <- mkRegA(0);

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
        if (wstrb != 0) begin
            Bit#(8) clearMask = wstrb & ~data;
            r <= r & ~clearMask;
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
