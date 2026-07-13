// Wclr.bsv
//
// Config #5: sw=rw, hw=r, onwrite=wclr.
//
// Understanding of the spec:
//   - onwrite=wclr: "any qualifying write (wstrb != 0 anywhere) clears
//     the ENTIRE field to all-zeros, regardless of the data value."
//   - The `data` payload is completely irrelevant here; only whether the
//     write is "qualifying" (wstrb != 0) matters.
//
// Judgment calls:
//   - "wstrb != 0 anywhere" is read as "wstrb is not the all-zero
//     pattern" (i.e. at least one bit position is being written),
//     matching the general wstrb no-op rule used throughout this
//     document; a fully-zero wstrb is the glitch no-op case.
package Wclr;

interface Wclr;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    method Bit#(8) swRead;
    method Bit#(8) hwRead;
endinterface

module mkWclr(Wclr);
    Reg#(Bit#(8)) r <- mkRegA(0);

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
        if (wstrb != 0) begin
            r <= 0;
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
