// SwmodWoclr.bsv
//
// Config #11: sw=rw, hw=r, swmod + onwrite=woclr together.
//
// Understanding of the spec:
//   - onwrite=woclr: clearMask = data & wstrb; next = r & ~clearMask.
//   - swmod (combined note): "swmod must pulse only when the woclr
//     operation actually clears at least one bit that was previously
//     set -- not on every qualifying write."
//   - So the pulse condition is NOT simply "next != r" evaluated
//     generically (though for woclr specifically those are equivalent):
//     a bit only changes under woclr if it was 1 in r AND selected by
//     clearMask, i.e. (clearMask & r) != 0. This is the same as next !=
//     r for this particular onwrite policy, but I compute it directly
//     as "bits actually cleared" per the spec wording, rather than via a
//     generic next-vs-current comparison, to make the intent explicit.
//   - wstrb == 0 is the standard glitch no-op: no register update, no
//     swmod pulse.
//
// Judgment calls:
//   - None beyond the direct reading above; "actually clears at least
//     one bit that was previously set" is modeled as
//     (clearMask & r) != 0, i.e. the intersection of "bits the write
//     targeted for clearing" and "bits that were 1 beforehand" is
//     nonempty.
package SwmodWoclr;

interface SwmodWoclr;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    method Bit#(8) swRead;
    method Bit#(8) hwRead;
    method Bool swmodPulse;
endinterface

module mkSwmodWoclr(SwmodWoclr);
    Reg#(Bit#(8)) r <- mkRegA(0);
    PulseWire modFired <- mkPulseWire;

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
        if (wstrb != 0) begin
            Bit#(8) clearMask   = data & wstrb;
            Bit#(8) actuallyClr = clearMask & r;
            if (actuallyClr != 0) begin
                r <= r & ~clearMask;
                modFired.send;
            end
        end
    endmethod

    method Bit#(8) swRead;
        return r;
    endmethod

    method Bit#(8) hwRead;
        return r;
    endmethod

    method Bool swmodPulse;
        return modFired;
    endmethod
endmodule

endpackage
