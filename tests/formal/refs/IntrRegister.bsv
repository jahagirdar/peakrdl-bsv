// IntrRegister.bsv
//
// Config #16: a two-field register modeling the "intr" register-level
// aggregation section, using the spec's typical interrupt-status-field
// pattern for both fields:
//   - field0: intr, enable = 8-bit external condition. sw=rw, hw=w,
//     onwrite=woclr.
//   - field1: intr, mask = 8-bit external condition. sw=rw, hw=w,
//     onwrite=woclr.
// Plus a single register-level "interrupt pending" aggregate output.
//
// Understanding of the spec:
//   - Per-field behavior (same shape for field0 and field1, differing
//     only in enable vs mask):
//       * hw=w: hardware can WRITE the field but there is no hardware
//         read port on this interface (a pure status field -- hw sets
//         event bits, software is the only consumer that reads it back).
//         With no we/wel/hwenable configured, hw's write is the plain
//         "General field shape" default: unconditional replace.
//       * sw=rw with onwrite=woclr: software's *read* just returns the
//         current value; software's *write* clears (to 0) exactly the
//         bit positions where both wstrb==1 and data==1, per the woclr
//         rule from the spec's onwrite section. wstrb==0 is a no-op as
//         always.
//       * Same-cycle sw/hw race: the general precedence section's
//         default (precedence=sw, since neither field configures
//         precedence=hw) applies -- a genuine sw write (wstrb != 0)
//         wins over a same-cycle hw write attempt.
//   - Register-level intr aggregation (spec's "intr" section):
//       "that output is 1 whenever ANY bit of ANY intr-marked field in
//       the register currently holds a 1 (after that field's own
//       enable/mask qualification below is applied)."
//       * field0 (enable): only bit positions where enable==1 count.
//         contribution0 = |(field0 & enable)   (OR-reduction)
//       * field1 (mask): only bit positions where mask==0 count (mask
//         is the inverse sense of enable).
//         contribution1 = |(field1 & ~mask)    (OR-reduction)
//       * pending = contribution0 | contribution1
//   - haltenable/haltmask are not used by either field in this config,
//     so per spec ("a register only gets a halt output if at least one
//     of its fields sets haltenable or haltmask") this register has NO
//     halt output at all -- omitted from the interface entirely.
//
// Judgment calls:
//   - enable/mask are external per-bit conditions and, like we/hwenable
//     in the single-field configs, are read combinationally every cycle
//     for the aggregate computation; they are supplied via a dedicated
//     per-cycle method (`setQual`) sampled through RWires, independent of
//     whether a hw/sw write happens that cycle, since the interrupt
//     pending output must reflect the *currently stored* value at all
//     times, not just on write cycles. Undriven enable/mask default to
//     all-zero (enable=0 => field0 contributes nothing; mask=0 => field1
//     fully contributes) -- this default only matters before the
//     testbench starts driving the conditions.
//   - "pending" is exposed as a combinational (value) method, since the
//     spec describes it as a continuously-valid aggregate, not a pulse.
package IntrRegister;

interface IntrRegister;
    // Field0 (enable-qualified)
    method Action sw0Write(Bit#(8) data, Bit#(8) wstrb);
    method Bit#(8) sw0Read;
    method Action hw0Write(Bit#(8) data);

    // Field1 (mask-qualified)
    method Action sw1Write(Bit#(8) data, Bit#(8) wstrb);
    method Bit#(8) sw1Read;
    method Action hw1Write(Bit#(8) data);

    // Per-cycle external qualifier conditions for the intr aggregate.
    method Action setQual(Bit#(8) enable, Bit#(8) mask);

    // Register-level interrupt-pending aggregate output.
    method Bool pending;
endinterface

module mkIntrRegister(IntrRegister);
    Reg#(Bit#(8)) f0 <- mkRegA(0);
    Reg#(Bit#(8)) f1 <- mkRegA(0);

    RWire#(Tuple2#(Bit#(8), Bit#(8))) sw0Req <- mkRWire;
    RWire#(Bit#(8))                   hw0Req <- mkRWire;
    RWire#(Tuple2#(Bit#(8), Bit#(8))) sw1Req <- mkRWire;
    RWire#(Bit#(8))                   hw1Req <- mkRWire;

    RWire#(Tuple2#(Bit#(8), Bit#(8))) qualReq <- mkRWire;

    // field0: sw write (onwrite=woclr) vs hw write (unconditional),
    // default precedence = sw.
    rule updateField0;
        Bool swFires = False;
        Bit#(8) swNext = f0;
        if (sw0Req.wget matches tagged Valid {.data, .wstrb} &&& wstrb != 0) begin
            swFires = True;
            Bit#(8) clearMask = data & wstrb;
            swNext = f0 & ~clearMask;
        end

        if (hw0Req.wget matches tagged Valid .hwData) begin
            if (swFires)
                f0 <= swNext;
            else
                f0 <= hwData;
        end else if (swFires) begin
            f0 <= swNext;
        end
    endrule

    // field1: identical shape to field0, independent storage.
    rule updateField1;
        Bool swFires = False;
        Bit#(8) swNext = f1;
        if (sw1Req.wget matches tagged Valid {.data, .wstrb} &&& wstrb != 0) begin
            swFires = True;
            Bit#(8) clearMask = data & wstrb;
            swNext = f1 & ~clearMask;
        end

        if (hw1Req.wget matches tagged Valid .hwData) begin
            if (swFires)
                f1 <= swNext;
            else
                f1 <= hwData;
        end else if (swFires) begin
            f1 <= swNext;
        end
    endrule

    // Latch the qualifier conditions each cycle they're driven; default
    // to all-zero (see header comment) when not driven this cycle.
    Reg#(Bit#(8)) enableR <- mkRegA(0);
    Reg#(Bit#(8)) maskR   <- mkRegA(0);
    rule latchQual;
        if (qualReq.wget matches tagged Valid {.en, .mk}) begin
            enableR <= en;
            maskR   <= mk;
        end
    endrule

    method Action sw0Write(Bit#(8) data, Bit#(8) wstrb);
        sw0Req.wset(tuple2(data, wstrb));
    endmethod

    method Bit#(8) sw0Read;
        return f0;
    endmethod

    method Action hw0Write(Bit#(8) data);
        hw0Req.wset(data);
    endmethod

    method Action sw1Write(Bit#(8) data, Bit#(8) wstrb);
        sw1Req.wset(tuple2(data, wstrb));
    endmethod

    method Bit#(8) sw1Read;
        return f1;
    endmethod

    method Action hw1Write(Bit#(8) data);
        hw1Req.wset(data);
    endmethod

    method Action setQual(Bit#(8) enable, Bit#(8) mask);
        qualReq.wset(tuple2(enable, mask));
    endmethod

    method Bool pending;
        Bool contrib0 = (f0 & enableR) != 0;
        Bool contrib1 = (f1 & ~maskR) != 0;
        return contrib0 || contrib1;
    endmethod
endmodule

endpackage
