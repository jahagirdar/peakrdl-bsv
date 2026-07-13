// Next.bsv
//
// Config #6: sw=r (readable only), hw=rw, `next` configured as an
// external 8-bit condition.
//
// Understanding of the spec ("next" section):
//   - "When `next` is configured, the field's stored value is NOT
//     arbitrated between hw/sw writes at all. Instead, every clock
//     cycle, the field unconditionally takes on whatever value the
//     external `next` condition currently presents -- a direct
//     continuous feed into the storage element, with no other write
//     mechanism ... having any effect once `next` is configured."
//   - This is the simplest possible reference model: the stored value
//     IS the registered version of the `next` input every single cycle,
//     full stop. There is no sw write port, no hw write port, no
//     onwrite/onread side effects, no counter logic -- none of that is
//     reachable when next is present.
//
// Judgment calls:
//   - sw is modeled as read-only (per the task's framing: "next
//     overrides all writes anyway so sw's own write capability, if any,
//     would be moot -- keep it read-only to keep the model simple"), so
//     there is no swWrite method at all.
//   - hw=rw is nominally the declared access mode, but since `next`
//     overrides everything, there is no separate hw "write" method
//     either -- the only hw-facing port is the external `next` condition
//     itself, which continuously drives storage. `rd` serves both sw and
//     hw "read" needs, since nothing distinguishes them here.
//   - The `next` condition is modeled as a combinational Bit#(8) input
//     wire (via a submodule interface argument) rather than a method
//     call, since the spec describes it as "whatever value the external
//     next condition currently presents" every cycle -- a continuously
//     driven signal, not an event/pulse.
package Next;

interface Next;
    method Bit#(8) rd;
endinterface

// `next` is a continuously-driven external 8-bit condition, supplied as
// a combinational input to the module (e.g. wired from another
// interface's output) rather than via an Action/pulse method, since it
// must be sampled every cycle regardless of any other activity.
module mkNext#(Bit#(8) next)(Next);
    Reg#(Bit#(8)) r <- mkRegA(0);

    rule feedNext;
        r <= next;      // unconditional continuous feed, every cycle, no exceptions
    endrule

    method Bit#(8) rd;
        return r;
    endmethod
endmodule

endpackage
