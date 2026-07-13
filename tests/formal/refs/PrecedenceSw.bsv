// PrecedenceSw.bsv
//
// Config #3: sw=rw, hw=rw (hardware CAN write, unconditionally replacing
// the value when it does), precedence=sw (the default when unspecified).
//
// Understanding of the spec:
//   - Both sw and hw can genuinely attempt a write in the very same
//     cycle. precedence=sw means: if both fire in the same cycle,
//     software's computed next-value wins and hardware's attempted write
//     is silently discarded for that cycle. If only one side fires, that
//     side's write always takes effect (precedence only matters on a
//     genuine same-cycle race between two *actual* writes).
//   - "actual" sw write = a swWrite call with wstrb != 0 (wstrb==0 is not
//     a real write attempt at all, per the general no-op rule, so it
//     can never win or block anything).
//   - "actual" hw write here is unconditional (no we/hwenable/etc in this
//     config), so any hwWrite call this cycle counts as a genuine write
//     attempt.
//
// Modeling the true same-cycle race in BSV:
//   Two independent Action methods (swWrite, hwWrite) can both be called
//   in the same clock cycle by a testbench/rule. To arbitrate correctly
//   regardless of *method call order*, we do NOT let either method drive
//   the storage register directly. Instead each method only deposits its
//   request into an RWire (a same-cycle, read-once communication wire);
//   a single rule reads back both RWires *after* all methods this cycle
//   have fired, decides who wins per the precedence policy, and performs
//   the one authoritative register update. This avoids any BSV scheduling
//   ambiguity/conflict between two methods trying to write the same Reg.
//
// Judgment call: if hw calls hwWrite but sw does NOT call swWrite (or
// calls it with wstrb==0), hw's write proceeds untouched -- there is no
// race, so precedence is irrelevant, matching "no race" wording in spec.
package PrecedenceSw;

interface PrecedenceSw;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    method Action hwWrite(Bit#(8) data);
    method Bit#(8) rd;
endinterface

module mkPrecedenceSw(PrecedenceSw);
    Reg#(Bit#(8)) r <- mkRegA(0);
    RWire#(Tuple2#(Bit#(8), Bit#(8))) swReq <- mkRWire;
    RWire#(Bit#(8)) hwReq <- mkRWire;

    rule arbitrate;
        let swVal = swReq.wget;
        let hwVal = hwReq.wget;

        Bool swFires = False;
        Bit#(8) swNext = r;
        if (swVal matches tagged Valid {.data, .wstrb} &&& wstrb != 0) begin
            swFires = True;
            swNext = (data & wstrb) | (~wstrb & r);
        end

        if (hwVal matches tagged Valid .hwData) begin
            if (swFires)
                r <= swNext;   // race: sw wins, hw discarded
            else
                r <= hwData;   // hw write only, no race
        end else if (swFires) begin
            r <= swNext;       // sw write only, no race
        end
        // else: neither side wrote this cycle -> r holds.
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
endmodule

endpackage
