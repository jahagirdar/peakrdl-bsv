// We.bsv
//
// Config #7: sw=rw, hw=rw, with a `we` (active-high hardware
// write-enable) external condition.
//
// Understanding of the spec:
//   - `we` gates only the HARDWARE write path: a hardware write attempt
//     only actually changes the stored value while `we` == 1 that cycle.
//     While we == 0, a hw write attempt has no effect at all (field
//     keeps its previous value from hw's perspective that cycle).
//   - Software's write path is completely unaffected by `we` (still
//     default masked-merge, gated only by wstrb != 0 as usual).
//   - The spec's `we` section says nothing about precedence explicitly,
//     but the general precedence section says sw wins same-cycle races
//     by default when unspecified, so we treat a "genuine hw write" here
//     as "hwWrite called AND we==1" and otherwise apply the same
//     sw-wins-race arbitration as PrecedenceSw.
//
// Judgment call: `we` is passed alongside the hw write data as method
// arguments (rather than as a separately-driven per-cycle input), since
// the two are only meaningful together -- an hwWrite call with we==0 is,
// by definition, not a genuine write attempt at all.
package We;

interface We;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    // we: active-high hardware write-enable, sampled alongside hwWrite.
    method Action hwWrite(Bit#(8) data, Bool we);
    method Bit#(8) rd;
endinterface

module mkWe(We);
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
        if (hwReq.wget matches tagged Valid {.data, .we} &&& we) begin
            hwFires = True;
            hwNext = data;
        end

        if (swFires)
            r <= swNext;        // sw always wins a genuine race (default precedence=sw)
        else if (hwFires)
            r <= hwNext;
        // else: neither a genuine sw write nor a we-qualified hw write -> hold.
    endrule

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
        swReq.wset(tuple2(data, wstrb));
    endmethod

    method Action hwWrite(Bit#(8) data, Bool we);
        hwReq.wset(tuple2(data, we));
    endmethod

    method Bit#(8) rd;
        return r;
    endmethod
endmodule

endpackage
