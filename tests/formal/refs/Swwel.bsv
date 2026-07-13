// Swwel.bsv
//
// Config #10: sw=rw, hw=rw, with a `swwel` (active-low software
// write-enable) external condition -- same concept as `swwe` but the sw
// write takes effect only while the condition reads 0.
//
// See Swwe.bsv for the full discussion (hw path unaffected, blocked sw
// writes don't count as a "genuine" write for race arbitration, and
// condition bundled with the swWrite call).
package Swwel;

interface Swwel;
    // swwel: active-low software write-enable; write blocked when swwel==1.
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb, Bool swwel);
    method Action hwWrite(Bit#(8) data);
    method Bit#(8) rd;
endinterface

module mkSwwel(Swwel);
    Reg#(Bit#(8)) r <- mkRegA(0);
    RWire#(Tuple3#(Bit#(8), Bit#(8), Bool)) swReq <- mkRWire;
    RWire#(Bit#(8)) hwReq <- mkRWire;

    rule arbitrate;
        Bool swFires = False;
        Bit#(8) swNext = r;
        if (swReq.wget matches tagged Valid {.data, .wstrb, .swwel} &&& (wstrb != 0 && !swwel)) begin
            swFires = True;
            swNext = (data & wstrb) | (~wstrb & r);
        end

        if (hwReq.wget matches tagged Valid .hwData) begin
            if (swFires)
                r <= swNext;
            else
                r <= hwData;
        end else if (swFires) begin
            r <= swNext;
        end
    endrule

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb, Bool swwel);
        swReq.wset(tuple3(data, wstrb, swwel));
    endmethod

    method Action hwWrite(Bit#(8) data);
        hwReq.wset(data);
    endmethod

    method Bit#(8) rd;
        return r;
    endmethod
endmodule

endpackage
