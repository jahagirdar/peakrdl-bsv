// ComboSwweWoclr.bsv
//
// Config #12: sw=rw, hw=r, onwrite=woclr AND an active-high swwe
// condition together (woclr only takes effect while swwe==1).
//
// Understanding of the spec ("swwe/swwel" + "onwrite" + "Combining
// multiple properties" sections):
//   - swwe: "requires the condition to be 1 for a software write to
//     take effect (masked-merge, woclr, etc. -- whatever onwrite policy
//     is configured). When the condition doesn't hold, software's write
//     attempt has no effect (as if it never wrote) that cycle."
//   - onwrite=woclr: "writing a 1 to a bit position clears that bit to
//     0. A 0 in a bit position leaves that bit unchanged," gated by
//     wstrb as usual -- but per swwe, this entire mechanism is itself
//     gated by swwe==1: while swwe==0, even a wstrb!=0 write is void.
//   - hw=r: hardware can only read the field (e.g. for status use
//     elsewhere), never write it -- no hw write method or arbitration
//     logic is needed at all.
//
// Judgment call: swwe is sampled alongside the sw write's own arguments
// (data, wstrb) in the same swWrite call, since -- like `we` for the
// hardware side in We.bsv -- it is only meaningful evaluated together
// with a genuine write attempt (nonzero wstrb): a swWrite call with
// swwe==0 is not a "real" write attempt at all, matching the spec's "as
// if it never wrote" wording.
package ComboSwweWoclr;

interface ComboSwweWoclr;
    // swwe: active-high software write-enable, sampled alongside the write.
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb, Bool swwe);
    method Bit#(8) rd;
endinterface

module mkComboSwweWoclr(ComboSwweWoclr);
    Reg#(Bit#(8)) r <- mkRegA(0);
    RWire#(Tuple3#(Bit#(8), Bit#(8), Bool)) swReq <- mkRWire;

    rule doWrite (swReq.wget matches tagged Valid {.data, .wstrb, .swwe}
                  &&& (wstrb != 0) &&& swwe);
        // woclr: written-1 (wstrb-selected) bits clear; all other bits unchanged.
        Bit#(8) clearMask = data & wstrb;
        r <= r & ~clearMask;
    endrule
    // Note: when swwe==0 or wstrb==0, no rule fires at all this cycle --
    // the write attempt has exactly zero effect, matching "as if it
    // never wrote."

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb, Bool swwe);
        swReq.wset(tuple3(data, wstrb, swwe));
    endmethod

    method Bit#(8) rd;
        return r;
    endmethod
endmodule

endpackage
