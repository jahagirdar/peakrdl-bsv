// Wot.bsv
//
// Config #2: sw=rw, hw=r, onwrite=wot.
//
// Understanding of the spec:
//   - onwrite=wot: "writing a 1 to a bit position toggles (inverts) that
//     bit. A 0 leaves it unchanged." wstrb still gates which bits of
//     `data` are considered "written 1".
//   - toggleMask = data & wstrb
//     next        = r ^ toggleMask
//   - wstrb == 0 is a total no-op (toggleMask all-zero -> XOR with 0 is
//     identity, but we still guard explicitly for clarity/symmetry with
//     the other onwrite configs).
//
// Judgment calls:
//   - None beyond the standard wstrb-gating already described.
package Wot;

interface Wot;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    method Bit#(8) swRead;
    method Bit#(8) hwRead;
endinterface

module mkWot(Wot);
    Reg#(Bit#(8)) r <- mkRegA(0);

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
        if (wstrb != 0) begin
            Bit#(8) toggleMask = data & wstrb;
            r <= r ^ toggleMask;
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
