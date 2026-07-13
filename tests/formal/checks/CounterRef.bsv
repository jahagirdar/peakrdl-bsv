// CounterRef.bsv -- verbatim copy of refs/Counter.bsv with ONLY the
// package/interface/module names changed (Counter -> CounterRef), to
// avoid a name collision with BSC's own built-in library package
// `Counter` (/opt/tools/bsc/lib/Libraries/Counter.bo, a stdlib up/down
// counter utility unrelated to this SystemRDL counter field). This is a
// pure renaming for build hygiene -- no method signatures, no rule
// logic, no semantics were changed. See refs/Counter.bsv for the
// authoritative header comment and semantics; this file's logic must be
// kept byte-identical to it modulo the name change.
//
// Config #15: sw=r (read-only, no software write port at all), hw=r
// (the value is also readable by hardware, e.g. for status/reductions
// elsewhere, though no such consumer exists in this standalone model),
// counter property with incrsaturate (bool form -- clamps at the
// field's maximum representable value, 255 for this 8-bit field).
package CounterRef;

interface CounterRef;
    // Hardware's data-less increment pulse: add 1, clamped at 255.
    method Action incr;
    method Bit#(8) rd;
endinterface

module mkCounterRef(CounterRef);
    Reg#(Bit#(8)) r <- mkRegA(0);
    RWire#(Bool) incrPulse <- mkRWire;

    rule doIncr (incrPulse.wget matches tagged Valid .fire &&& fire);
        if (r == 8'hFF)
            r <= 8'hFF;     // incrsaturate: clamp at max (255), no wrap
        else
            r <= r + 1;
    endrule

    method Action incr;
        incrPulse.wset(True);
    endmethod

    method Bit#(8) rd;
        return r;
    endmethod
endmodule

endpackage
