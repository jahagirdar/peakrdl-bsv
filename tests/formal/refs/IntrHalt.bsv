// IntrHalt.bsv
//
// Config #8: a single field, sw=rw, hw=w, onwrite=woclr, intr, AND
// haltenable as an 8-bit external condition (separate from any
// interrupt enable/mask -- this field has no enable/mask, only
// haltenable). Models both the register-level "interrupt pending"
// output (unqualified, since no enable/mask on this field -- the raw
// field value's OR-reduction) AND the register-level "halt" output
// (qualified by haltenable).
//
// Understanding of the spec:
//   - onwrite=woclr: "writing a 1 to a bit position clears that bit to
//     0. A 0 in a bit position leaves that bit unchanged." Gated by
//     wstrb as usual (wstrb selects which bits of `data` are considered
//     "written 1").
//   - hw=w: hardware can write but not read the field; no hwenable/
//     hwmask/we/wel is configured for this field, so a hw write
//     unconditionally replaces the stored value (the general default
//     hw-write rule), same as a plain hw=rw field's write path.
//   - precedence is unspecified for this config, so the default
//     (precedence=sw) applies: on a genuine same-cycle race between a
//     woclr-qualified sw write and a hw write, sw's (woclr'd) result
//     wins and the hw write is discarded that cycle.
//   - intr: "that output is 1 whenever ANY bit of ANY intr-marked field
//     in the register currently holds a 1 (after that field's own
//     enable/mask qualification is applied)." No `enable`/`mask` is
//     configured on this field, so the qualification is the identity --
//     the raw OR-reduction of the stored value.
//   - haltenable: "qualifies contributions to a *completely separate*
//     one-bit aggregate output ... conventionally called halt ...
//     independent of the interrupt aggregate above." Only bit positions
//     where haltenable==1 contribute to halt; positions where it's 0
//     never contribute regardless of the stored bit's value.
//
// Judgment calls:
//   - Since this is modeled as a single-field register, the "register-
//     level" intr and halt aggregates reduce to this one field's own
//     (qualified) OR-reduction -- there is no second intr-marked field
//     to aggregate with.
//   - haltenable is passed as a plain Bit#(8) module parameter (a
//     continuously-driven external condition), consistent with how
//     hwenable/hwmask-style N-bit conditions are modeled elsewhere,
//     since it is a per-bit qualifier sampled combinationally to produce
//     the halt output rather than an event/pulse.
package IntrHalt;

interface IntrHalt;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    method Action hwWrite(Bit#(8) data);
    method Bit#(8) rd;
    // intr aggregate contribution: unqualified OR-reduction (no enable/mask).
    method Bool intrPending;
    // halt aggregate contribution: OR-reduction qualified by haltenable.
    method Bool halt;
endinterface

// haltenable: external 8-bit condition qualifying which bits of this
// field contribute to the halt aggregate.
module mkIntrHalt#(Bit#(8) haltenable)(IntrHalt);
    Reg#(Bit#(8)) r <- mkRegA(0);
    RWire#(Tuple2#(Bit#(8), Bit#(8))) swReq <- mkRWire;
    RWire#(Bit#(8)) hwReq <- mkRWire;

    rule arbitrate;
        Bool swFires = False;
        Bit#(8) swNext = r;
        if (swReq.wget matches tagged Valid {.data, .wstrb} &&& wstrb != 0) begin
            swFires = True;
            // woclr: written-1 (and wstrb-selected) bits clear; others unchanged.
            Bit#(8) clearMask = data & wstrb;
            swNext = r & ~clearMask;
        end

        Bool hwFires = False;
        Bit#(8) hwNext = r;
        if (hwReq.wget matches tagged Valid .data) begin
            hwFires = True;
            hwNext = data;      // hw=w, no gating condition configured: plain overwrite
        end

        if (swFires)
            r <= swNext;        // default precedence=sw: sw (woclr'd) wins a genuine race
        else if (hwFires)
            r <= hwNext;
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

    method Bool intrPending;
        return (r != 0);           // unqualified OR-reduction: no enable/mask on this field
    endmethod

    method Bool halt;
        return ((r & haltenable) != 0);   // haltenable-qualified OR-reduction
    endmethod
endmodule

endpackage
