// SwW_HwR.bsv
//
// Config #16: sw=w (sw can only write, default masked-merge), hw=r
// (hw can only read).
//
// Understanding of the spec:
//   - sw=w: only a write method exists on the sw side; there is no sw
//     read path/method whatsoever (software is write-only, e.g. a
//     write-only command/trigger register).
//   - Default onwrite (none named): masked merge --
//     next = (data & wstrb) | (~wstrb & r).
//   - hw=r: hw can only read the stored value; no hw write path.
//   - wstrb == 0 is the standard glitch no-op: no update at all.
//
// Judgment calls:
//   - None; straightforward composition of "sw=w" (omit swRead) and
//     "hw=r" (omit hwWrite) with the default write policy.
package SwW_HwR;

interface SwW_HwR;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    method Bit#(8) hwRead;
endinterface

module mkSwW_HwR(SwW_HwR);
    Reg#(Bit#(8)) r <- mkRegA(0);

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
        if (wstrb != 0) begin
            r <= (data & wstrb) | (~wstrb & r);
        end
    endmethod

    method Bit#(8) hwRead;
        return r;
    endmethod
endmodule

endpackage
