// Singlepulse.bsv
//
// Config #12: a 1-bit field, sw=rw, hw=r, singlepulse property.
//
// Understanding of the spec:
//   - The spec document (field_property_semantics.md) does NOT define
//     "singlepulse" anywhere -- it only appears in this task's config
//     list, not in any spec section. Per the task instructions, general
//     digital-register-design knowledge is used here instead (this is
//     the one config in this batch not fully grounded in the provided
//     document).
//   - General-knowledge understanding of "singlepulse" (as used in
//     SystemRDL-style register generators): a sw=rw field that, once
//     software writes it to 1, automatically clears itself back to 0 on
//     the very next clock cycle -- guaranteeing hardware only ever sees
//     a true single-cycle pulse, regardless of whether software (or
//     anything else) tries to hold it at 1.
//   - Base write behavior otherwise follows the general default
//     (masked-merge) write rule, since no onwrite property is named for
//     this config; for a 1-bit field that is operationally: writing 1
//     with wstrb=1 sets the bit, writing 0 with wstrb=1 clears it,
//     wstrb=0 is a no-op.
//
// Judgment calls (elevated to a flagged note since this property isn't
// in the spec document at all):
//   - Auto-clear only happens on a cycle where software does NOT also
//     write the field; if software writes a new value on the very cycle
//     that would have auto-cleared, the explicit software write wins for
//     that cycle (auto-clear is treated as a lower-priority background
//     rule, not a hardwired override of an explicit contemporaneous sw
//     write).
//   - hw has no write port here (hw=r only), so there is no
//     hw-write-vs-autoclear race to consider.
package Singlepulse;

interface Singlepulse;
    method Action swWrite(Bit#(1) data, Bit#(1) wstrb);
    method Bit#(1) swRead;
    method Bit#(1) hwRead;
endinterface

module mkSinglepulse(Singlepulse);
    Reg#(Bit#(1)) r <- mkRegA(0);
    RWire#(Bit#(1)) swReq <- mkRWire;

    rule update;
        if (swReq.wget matches tagged Valid .v) begin
            r <= v;                 // explicit sw write wins this cycle
        end else if (r == 1) begin
            r <= 0;                 // singlepulse auto-clear
        end
    endrule

    method Action swWrite(Bit#(1) data, Bit#(1) wstrb);
        if (wstrb != 0) begin
            Bit#(1) next = (data & wstrb) | (~wstrb & r);
            swReq.wset(next);
        end
    endmethod

    method Bit#(1) swRead;
        return r;
    endmethod

    method Bit#(1) hwRead;
        return r;
    endmethod
endmodule

endpackage
