// Hwenable.bsv
//
// Config #11: sw=rw, hw=rw, with an 8-bit `hwenable` per-bit external
// condition.
//
// Understanding of the spec:
//   - hwenable qualifies hardware writes at bit granularity: when
//     hardware writes, only bit positions where hwenable==1 are actually
//     updated to hw's presented value; bit positions where hwenable==0
//     keep their previous value regardless of what hw presented there.
//       hwNext = (hwData & hwenable) | (r & ~hwenable)
//   - Software's write path is unaffected (plain default masked-merge).
//   - Precedence: the spec's precedence section talks about a single
//     genuine hw write vs a single genuine sw write for the whole field;
//     it doesn't explicitly say how hwenable interacts with a same-cycle
//     sw/hw race. Judgment call: we treat "hardware attempted a write
//     this cycle" (i.e. hwWrite was called at all) as the "genuine hw
//     write" for race-arbitration purposes, independent of what
//     hwenable happens to be that cycle -- and, per default precedence
//     = sw, a genuine sw write wins the *entire* field on a race (not
//     resolved bit-by-bit against hwenable). If sw doesn't fire, hw's
//     hwenable-qualified merge applies normally.
package Hwenable;

interface Hwenable;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    // hwenable: per-bit hw write mask, sampled alongside hwWrite. 1 =
    // that bit position is updated by this hw write; 0 = held.
    method Action hwWrite(Bit#(8) data, Bit#(8) hwenable);
    method Bit#(8) rd;
endinterface

module mkHwenable(Hwenable);
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

        if (hwReq.wget matches tagged Valid {.hwData, .hwenable}) begin
            if (swFires)
                r <= swNext;   // whole-field race: sw wins by default precedence
            else
                r <= (hwData & hwenable) | (r & ~hwenable);
        end else if (swFires) begin
            r <= swNext;
        end
    endrule

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
        swReq.wset(tuple2(data, wstrb));
    endmethod

    method Action hwWrite(Bit#(8) data, Bit#(8) hwenable);
        hwReq.wset(tuple2(data, hwenable));
    endmethod

    method Bit#(8) rd;
        return r;
    endmethod
endmodule

endpackage
