// HwNa.bsv
//
// Config #17: sw=rw (normal read/write), hw=na (hardware has no read or
// write port at all -- pure software-only register).
//
// Understanding of the spec:
//   - "hw = na: hardware can neither read nor write the field -- it
//     behaves as pure software-only storage (still has whatever
//     onwrite/onread side effects are configured; only the hw port is
//     absent)."
//   - No onwrite/onread property is named for this config, so the write
//     path is the plain default masked merge, and there is no onread
//     side effect either.
//
// Judgment calls:
//   - The interface simply omits any hw-facing method whatsoever (no
//     hwRead, no hwWrite, no hw pulse inputs) -- this is the literal
//     reading of "no hw interface methods whatsoever" from the task
//     description.
package HwNa;

interface HwNa;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    method Bit#(8) swRead;
endinterface

module mkHwNa(HwNa);
    Reg#(Bit#(8)) r <- mkRegA(0);

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
        if (wstrb != 0) begin
            r <= (data & wstrb) | (~wstrb & r);
        end
    endmethod

    method Bit#(8) swRead;
        return r;
    endmethod
endmodule

endpackage
