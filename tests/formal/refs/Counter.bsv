// Counter.bsv
//
// Config #15: sw=r (read-only, no software write port at all), hw=r
// (the value is also readable by hardware, e.g. for status/reductions
// elsewhere, though no such consumer exists in this standalone model),
// counter property with incrsaturate (bool form -- clamps at the
// field's maximum representable value, 255 for this 8-bit field).
//
// Understanding of the spec (Counter section):
//   - "If nothing about direction is specified at all, the field is
//     increment-only, incrementing by a fixed amount of 1 each time
//     hardware pulses a (data-less) increment control." No incrvalue,
//     incrwidth, decrvalue, or decrwidth is configured for this config,
//     so: increment-only, no decrement direction at all, fixed +1 per
//     pulse, no data accompanies the pulse.
//   - incrsaturate (bool form): "when incrementing would exceed the
//     field's maximum representable value ... the result clamps at that
//     ceiling instead of wrapping around." For an 8-bit field the max
//     representable value is 255, so incrementing while at 255 holds at
//     255 rather than wrapping to 0.
//   - overflow is mutually exclusive with incrsaturate and is not
//     configured here, so there is no overflow pulse output.
//   - incrthreshold is not configured for this config, so no threshold
//     level output either.
//
// Judgment calls:
//   - sw=r means there is no swWrite method at all on this interface (a
//     genuinely read-only field from software's perspective); only a
//     read method and the hw increment-pulse method are exposed.
//   - "hardware pulses a (data-less) increment control" is modeled as a
//     bare Action method `incr()` with no arguments, since this counter
//     variant carries no incrwidth (variable per-call amount) at all.
package Counter;

interface Counter;
    // Hardware's data-less increment pulse: add 1, clamped at 255.
    method Action incr;
    method Bit#(8) rd;
endinterface

module mkCounter(Counter);
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
