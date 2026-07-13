// PrecedenceHw.bsv
//
// Config #4: identical to PrecedenceSw except precedence=hw: on a genuine
// same-cycle race between a real sw write (wstrb != 0) and a real hw
// write, hardware's new value wins and software's write is discarded.
// When only one side writes, that side's write always takes effect
// (precedence only resolves true races), exactly as in PrecedenceSw.
//
// See PrecedenceSw.bsv for the full discussion of why the same-cycle race
// is modeled via two RWires feeding one arbitrating rule rather than
// letting the two Action methods write the Reg directly.
package PrecedenceHw;

interface PrecedenceHw;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    method Action hwWrite(Bit#(8) data);
    method Bit#(8) rd;
endinterface

module mkPrecedenceHw(PrecedenceHw);
    Reg#(Bit#(8)) r <- mkRegA(0);
    RWire#(Tuple2#(Bit#(8), Bit#(8))) swReq <- mkRWire;
    RWire#(Bit#(8)) hwReq <- mkRWire;

    rule arbitrate;
        let swVal = swReq.wget;
        let hwVal = hwReq.wget;

        Bool swFires = False;
        Bit#(8) swNext = r;
        if (swVal matches tagged Valid {.data, .wstrb} &&& wstrb != 0) begin
            swFires = True;
            swNext = (data & wstrb) | (~wstrb & r);
        end

        if (hwVal matches tagged Valid .hwData) begin
            // hw fired this cycle: hw wins the race unconditionally,
            // whether or not sw also fired.
            r <= hwData;
        end else if (swFires) begin
            r <= swNext;       // sw write only, no race
        end
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
