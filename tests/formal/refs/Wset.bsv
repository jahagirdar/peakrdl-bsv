// Wset.bsv
//
// Config #6: sw=rw, hw=r, onwrite=wset.
//
// Understanding of the spec:
//   - onwrite=wset: "any qualifying write sets the ENTIRE field to
//     all-ones, regardless of the data value."
//   - Mirror image of Wclr.bsv: `data` is irrelevant, only whether the
//     write is qualifying (wstrb != 0) matters.
//
// Judgment calls:
//   - Same wstrb-qualification reading as Wclr.bsv: "wstrb != 0
//     anywhere" means wstrb is not the all-zero pattern.
package Wset;

interface Wset;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    method Bit#(8) swRead;
    method Bit#(8) hwRead;
endinterface

module mkWset(Wset);
    Reg#(Bit#(8)) r <- mkRegA(0);

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
        if (wstrb != 0) begin
            r <= 8'hFF;
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
