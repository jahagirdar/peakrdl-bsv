// ComboWelSwwel.bsv
//
// Config #14: sw=rw, hw=rw, an active-low `wel` condition AND an
// active-low `swwel` condition together (independent gates on the hw
// and sw paths respectively).
//
// Understanding of the spec ("we/wel" + "swwe/swwel" sections):
//   - wel: "active-low -- a hardware write only takes effect while the
//     condition is 0; the write is blocked whenever the condition is 1."
//     Gates ONLY the hardware write path.
//   - swwel: "identical concept [to swwe], but ... requires the
//     condition to be 0" for a software write to take effect. Gates
//     ONLY the software write path.
//   - These are two independent external conditions on two independent
//     paths -- wel never affects sw's write, and swwel never affects
//     hw's write. Each is sampled alongside its own side's write
//     attempt, exactly like We.bsv (hw) and ComboSwweWoclr.bsv (sw) do
//     individually; this config simply has both active on the same
//     field at once, with no other interaction between them.
//   - precedence is unspecified, so default precedence=sw applies for a
//     genuine same-cycle race, where "genuine" on each side already
//     factors in that side's own gate (wel==0 for hw, swwel==0 for sw)
//     -- a gated-off write attempt is not a real write attempt at all,
//     per both sections' "no effect / as if it never wrote" wording.
//
// Judgment call: modeled as two separate, independently-driven 1-bit
// conditions (`wel` passed with each hwWrite call, `swwel` passed with
// each swWrite call) rather than a single shared signal, since the task
// describes them as "independent gates on the hw and sw paths
// respectively" with no indication they are the same physical signal.
package ComboWelSwwel;

interface ComboWelSwwel;
    // swwel: active-low software write-enable, sampled alongside the write.
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb, Bool swwel);
    // wel: active-low hardware write-enable, sampled alongside hwWrite.
    method Action hwWrite(Bit#(8) data, Bool wel);
    method Bit#(8) rd;
endinterface

module mkComboWelSwwel(ComboWelSwwel);
    Reg#(Bit#(8)) r <- mkRegA(0);
    RWire#(Tuple3#(Bit#(8), Bit#(8), Bool)) swReq <- mkRWire;
    RWire#(Tuple2#(Bit#(8), Bool))          hwReq <- mkRWire;

    rule arbitrate;
        Bool swFires = False;
        Bit#(8) swNext = r;
        if (swReq.wget matches tagged Valid {.data, .wstrb, .swwel}
                &&& (wstrb != 0) &&& !swwel) begin
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
            r <= swNext;        // default precedence=sw wins a genuine race
        else if (hwFires)
            r <= hwNext;
    endrule

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb, Bool swwel);
        swReq.wset(tuple3(data, wstrb, swwel));
    endmethod

    method Action hwWrite(Bit#(8) data, Bool wel);
        hwReq.wset(tuple2(data, wel));
    endmethod

    method Bit#(8) rd;
        return r;
    endmethod
endmodule

endpackage
