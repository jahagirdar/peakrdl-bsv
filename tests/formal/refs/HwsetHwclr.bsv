// HwsetHwclr.bsv
//
// Config #14: sw=r, hw=r, hwset AND hwclr both configured (two
// independent pulse inputs). If both pulse the same cycle, hwclr wins.
//
// Understanding of the spec:
//   - sw=r, hw=r: neither side can write the field via a normal
//     data-carrying write path; the field's value is driven purely by
//     the hwset/hwclr pulses (this is the classic sw=r/hw=r "hw sets
//     it, sw reads it, and hw/sw both need a way to clear it" status
//     register shape).
//   - hwset: "hardware has a dedicated pulse input; when pulsed, the
//     field is forced to all-ones that cycle, taking priority over
//     everything else... that cycle."
//   - hwclr: same, but forces the field to all-zeros, also taking
//     precedence over sw/hw writes that cycle.
//   - "If both fire the same cycle, clear wins (matches the general
//     principle that clear-type operations are the highest-priority
//     override in these semantics)."
//
// Judgment calls:
//   - Since there is no other write path in this config (sw=r, hw=r,
//     i.e. no normal hw "write a value" method), the "clear wins over
//     everything else that cycle" language reduces here to just:
//     hwclr-pulse beats hwset-pulse when both fire in the same cycle.
//     There is no separate "hw write" or "sw write" for either pulse to
//     out-race.
package HwsetHwclr;

interface HwsetHwclr;
    method Action pulseHwset;
    method Action pulseHwclr;
    method Bit#(8) swRead;
    method Bit#(8) hwRead;
endinterface

module mkHwsetHwclr(HwsetHwclr);
    Reg#(Bit#(8)) r <- mkRegA(0);
    PulseWire hwsetFired <- mkPulseWire;
    PulseWire hwclrFired <- mkPulseWire;

    rule update (hwsetFired || hwclrFired);
        if (hwclrFired)
            r <= 0;        // clear wins on a simultaneous hwset+hwclr
        else
            r <= 8'hFF;    // hwset only
    endrule

    method Action pulseHwset;
        hwsetFired.send;
    endmethod

    method Action pulseHwclr;
        hwclrFired.send;
    endmethod

    method Bit#(8) swRead;
        return r;
    endmethod

    method Bit#(8) hwRead;
        return r;
    endmethod
endmodule

endpackage
