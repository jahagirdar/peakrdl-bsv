// Sticky.bsv
//
// Config #13: sw=rw, hw=rw, sticky property (whole-field freeze).
//
// Understanding of the spec:
//   - "Once the field's stored value becomes nonzero (via a hardware
//     write), the field is frozen: no subsequent hardware write can
//     change its value at all ... until the value is reset back to zero
//     by some other mechanism (a software write, an onwrite side effect,
//     or an explicit clear/hwclr condition)." This config has no onwrite
//     or hwclr configured, so the only way to unstick the field is a
//     plain software write that lands on 0.
//   - "While the stored value is still zero, hardware writes take effect
//     normally."
//   - Software's write path is completely unaffected by sticky (default
//     masked-merge as usual) -- sticky only ever gates HARDWARE writes.
//
// Judgment calls:
//   - The freeze test ("is the field currently nonzero") is evaluated
//     against the value the register holds at the START of the current
//     cycle (i.e. r's current value, before any update this cycle) --
//     standard synchronous-logic semantics; a hw write this cycle cannot
//     "unfreeze itself" by first checking its own not-yet-applied
//     result.
//   - Same-cycle race with a genuine sw write: sticky is purely a
//     hw-write qualifier, so we fold it into the same "genuine hw write"
//     test used elsewhere (We.bsv, etc.) -- if r != 0, a hw write is
//     simply not "genuine" this cycle (as if it never happened), and the
//     usual default sw-wins-race arbitration applies for whatever is
//     left.
package Sticky;

interface Sticky;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    method Action hwWrite(Bit#(8) data);
    method Bit#(8) rd;
endinterface

module mkSticky(Sticky);
    Reg#(Bit#(8)) r <- mkRegA(0);
    RWire#(Tuple2#(Bit#(8), Bit#(8))) swReq <- mkRWire;
    RWire#(Bit#(8)) hwReq <- mkRWire;

    rule arbitrate;
        Bool swFires = False;
        Bit#(8) swNext = r;
        if (swReq.wget matches tagged Valid {.data, .wstrb} &&& wstrb != 0) begin
            swFires = True;
            swNext = (data & wstrb) | (~wstrb & r);
        end

        // A hw write is only "genuine" (able to change the value) while
        // the field is currently all-zero; once nonzero it is frozen
        // against hw until something else (sw) clears it back to 0.
        Bool hwUnlocked = (r == 0);
        Bool hwFires = False;
        Bit#(8) hwNext = r;
        if (hwReq.wget matches tagged Valid .hwData &&& hwUnlocked) begin
            hwFires = True;
            hwNext = hwData;
        end

        if (swFires)
            r <= swNext;      // sw always wins a genuine race
        else if (hwFires)
            r <= hwNext;
        // else: hw attempted but was frozen (or no attempt) -> hold.
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
