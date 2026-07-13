// Wel.bsv
//
// Config #8: sw=rw, hw=rw, with a `wel` (active-low hardware
// write-enable) external condition -- same concept as `we` but the hw
// write takes effect only while the condition reads 0, and is blocked
// while it reads 1.
//
// See We.bsv for the full discussion (sw path unaffected, default
// sw-wins-race precedence assumption, condition bundled with the hw
// write call since they're only meaningful together).
package Wel;

interface Wel;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    // wel: active-low hardware write-enable; write blocked when wel==1.
    method Action hwWrite(Bit#(8) data, Bool wel);
    method Bit#(8) rd;
endinterface

module mkWel(Wel);
    Reg#(Bit#(8)) r <- mkRegA(0);
    RWire#(Tuple2#(Bit#(8), Bit#(8))) swReq <- mkRWire;
    RWire#(Tuple2#(Bit#(8), Bool))    hwReq <- mkRWire;

    rule arbitrate;
        Bool swFires = False;
        Bit#(8) swNext = r;
        if (swReq.wget matches tagged Valid {.data, .wstrb} &&& wstrb != 0) begin
            swFires = True;
            swNext = (data & wstrb) | (~wstrb & r);
        end

        Bool hwFires = False;
        Bit#(8) hwNext = r;
        if (hwReq.wget matches tagged Valid {.data, .wel} &&& !wel) begin
            hwFires = True;
            hwNext = data;
        end

        if (swFires)
            r <= swNext;
        else if (hwFires)
            r <= hwNext;
    endrule

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
        swReq.wset(tuple2(data, wstrb));
    endmethod

    method Action hwWrite(Bit#(8) data, Bool wel);
        hwReq.wset(tuple2(data, wel));
    endmethod

    method Bit#(8) rd;
        return r;
    endmethod
endmodule

endpackage
