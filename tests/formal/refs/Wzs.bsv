// Wzs.bsv
//
// Config #4: sw=rw, hw=r, onwrite=wzs ("write zero to set").
//
// Understanding of the spec:
//   - onwrite=wzs: "writing a 0 to a selected bit position sets that bit
//     to 1. A 1 leaves it unchanged."
//   - A bit is set exactly when wstrb selects it (wstrb==1) AND the
//     presented data bit is 0.
//       setMask = wstrb & ~data
//       next    = r | setMask
//   - wstrb == 0 is a total no-op (setMask all-zero automatically);
//     guarded explicitly for the same symmetry/clarity reasons as the
//     other onwrite configs.
//
// Judgment calls:
//   - None beyond the wstrb-gating already described.
package Wzs;

interface Wzs;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    method Bit#(8) swRead;
    method Bit#(8) hwRead;
endinterface

module mkWzs(Wzs);
    Reg#(Bit#(8)) r <- mkRegA(0);

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
        if (wstrb != 0) begin
            Bit#(8) setMask = wstrb & ~data;
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
