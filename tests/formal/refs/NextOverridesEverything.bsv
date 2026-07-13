// NextOverridesEverything.bsv
//
// Config #7: same declared properties as Next.bsv (sw=rw, hw=rw, `next`
// configured as an external 8-bit condition -- sw must be rw, not r, for
// onwrite=woclr below to be a legal combination at all), but nominally
// ALSO configured with onwrite=woclr and sticky in the RDL sense -- i.e.
// this comment block records that those properties are notionally
// present in the configuration being modeled.
//
// Understanding of the spec ("Combining multiple properties" section):
//   - "`next`, when present, overrides *everything* else on that field
//     -- no other property in this document has any observable effect
//     once `next` is configured, since the field's storage takes its
//     value directly from the external `next` condition every cycle
//     regardless of any attempted sw write, hw write, onwrite side
//     effect, counter operation, or sticky/stickybit state."
//   - Therefore woclr (an onwrite side effect) and sticky (a hw-write
//     freeze behavior) are both entirely unreachable dead configuration
//     here: there is no sw write path for woclr to qualify, and no hw
//     write path for sticky to freeze -- `next` has already replaced
//     both of those mechanisms outright.
//   - The reference model is therefore IDENTICAL, line for line in
//     observable behavior, to Next.bsv: no woclr logic, no sticky
//     freeze/latch logic, no sw write method, no hw write method appear
//     anywhere below.
//
// This file exists specifically so that a later comparison against a
// real generator's output can confirm no dead/incorrect woclr or sticky
// logic leaks into the generated hardware when `next` is combined with
// those properties -- if the generator's output for this config differs
// observably from Next.bsv's, that is a bug (either dead logic leaking
// through, or next not being given true override priority).
package NextOverridesEverything;

interface NextOverridesEverything;
    method Bit#(8) rd;
endinterface

// Identical construction to Next.bsv: `next` is the sole driver of
// storage, every cycle, unconditionally. onwrite=woclr and sticky are
// nominally configured in the RDL being modeled but are unreachable --
// no woclr or sticky logic appears here, deliberately.
module mkNextOverridesEverything#(Bit#(8) next)(NextOverridesEverything);
    Reg#(Bit#(8)) r <- mkRegA(0);

    rule feedNext;
        r <= next;      // unconditional continuous feed; woclr/sticky never apply
    endrule

    method Bit#(8) rd;
        return r;
    endmethod
endmodule

endpackage
