// Swwe.bsv
//
// Config #9: sw=rw, hw=rw, with a `swwe` (active-high software
// write-enable) external condition.
//
// Understanding of the spec:
//   - `swwe` gates only the SOFTWARE write path: sw's write (default
//     masked-merge here, since no onwrite property is configured for
//     this config) only takes effect while swwe==1. While swwe==0, a sw
//     write attempt (even with wstrb != 0) has no effect at all, "as if
//     it never wrote".
//   - Hardware's write path is completely unaffected by swwe (plain
//     unconditional-replace hw write, as in the general field shape).
//   - Precedence: a sw write attempt that swwe blocks is NOT a genuine
//     write for race-arbitration purposes -- if it's blocked, there's no
//     race at all and a same-cycle hw write proceeds normally. This
//     mirrors the treatment of `we` in We.bsv (an ineffective attempt
//     does not count as "genuine").
//
// Judgment call: swwe is bundled into the swWrite call's arguments,
// alongside data/wstrb, for the same reason `we`/`wel` were bundled with
// the hw write in We.bsv/Wel.bsv -- they are only meaningful together.
package Swwe;

interface Swwe;
    // swwe: active-high software write-enable, sampled alongside swWrite.
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb, Bool swwe);
    method Action hwWrite(Bit#(8) data);
    method Bit#(8) rd;
endinterface

module mkSwwe(Swwe);
    Reg#(Bit#(8)) r <- mkRegA(0);
    RWire#(Tuple3#(Bit#(8), Bit#(8), Bool)) swReq <- mkRWire;
    RWire#(Bit#(8)) hwReq <- mkRWire;

    rule arbitrate;
        Bool swFires = False;
        Bit#(8) swNext = r;
        if (swReq.wget matches tagged Valid {.data, .wstrb, .swwe} &&& (wstrb != 0 && swwe)) begin
            swFires = True;
            swNext = (data & wstrb) | (~wstrb & r);
        end

        if (hwReq.wget matches tagged Valid .hwData) begin
            if (swFires)
                r <= swNext;   // genuine race: sw wins (default precedence)
            else
                r <= hwData;   // hw write only, no race
        end else if (swFires) begin
            r <= swNext;       // sw write only, no race
        end
    endrule

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb, Bool swwe);
        swReq.wset(tuple3(data, wstrb, swwe));
    endmethod

    method Action hwWrite(Bit#(8) data);
        hwReq.wset(data);
    endmethod

    method Bit#(8) rd;
        return r;
    endmethod
endmodule

endpackage
