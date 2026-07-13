// Hwmask.bsv
//
// Config #12: sw=rw, hw=rw, with an 8-bit `hwmask` per-bit external
// condition -- the inverse of hwenable: bit positions where hwmask==1
// are EXCLUDED from the hw write (held at previous value), positions
// where hwmask==0 are updated normally.
//       hwNext = (hwData & ~hwmask) | (r & hwmask)
//
// See Hwenable.bsv for the full discussion of the sw path (unaffected)
// and the same-cycle race judgment call (a genuine sw write wins the
// whole field by default precedence, independent of hwmask).
package Hwmask;

interface Hwmask;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    // hwmask: per-bit hw write exclusion mask. 1 = that bit position is
    // held (excluded from this hw write); 0 = updated normally.
    method Action hwWrite(Bit#(8) data, Bit#(8) hwmask);
    method Bit#(8) rd;
endinterface

module mkHwmask(Hwmask);
    Reg#(Bit#(8)) r <- mkRegA(0);
    RWire#(Tuple2#(Bit#(8), Bit#(8))) swReq <- mkRWire;
    RWire#(Tuple2#(Bit#(8), Bit#(8))) hwReq <- mkRWire;

    rule arbitrate;
        Bool swFires = False;
        Bit#(8) swNext = r;
        if (swReq.wget matches tagged Valid {.data, .wstrb} &&& wstrb != 0) begin
            swFires = True;
            swNext = (data & wstrb) | (~wstrb & r);
        end

        if (hwReq.wget matches tagged Valid {.hwData, .hwmask}) begin
            if (swFires)
                r <= swNext;
            else
                r <= (hwData & ~hwmask) | (r & hwmask);
        end else if (swFires) begin
            r <= swNext;
        end
    endrule

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
        swReq.wset(tuple2(data, wstrb));
    endmethod

    method Action hwWrite(Bit#(8) data, Bit#(8) hwmask);
        hwReq.wset(tuple2(data, hwmask));
    endmethod

    method Bit#(8) rd;
        return r;
    endmethod
endmodule

endpackage
