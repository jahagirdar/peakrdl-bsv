// WriteOnce.bsv
//
// Config #18: sw=w1 (write-only; "write-once" explicitly NOT enforced
// per the spec document's note -- modeled as plain sw=w), hw=r.
//
// Understanding of the spec:
//   - "sw = w1 / sw = rw1: ... For the purposes of these reference
//     models, assume the write-once restriction is NOT enforced by the
//     design under test (i.e. behave exactly like plain w/rw) -- only
//     model the base read/write behavior, do not add any one-shot-
//     lockout logic."
//   - Combined with hw=r (hw read-only) and no onwrite property named,
//     this reduces to exactly the same behavior as plain sw=w, hw=r
//     with default masked-merge writes.
//
// Judgment calls:
//   - This file is intentionally structurally identical to
//     SwW_HwR.bsv: per the spec's explicit instruction to ignore the
//     write-once restriction, sw=w1 and sw=w are indistinguishable in
//     these reference models. Modeled separately (rather than reusing
//     the same module) only because the task lists it as its own named
//     config with its own file.
//   - No lockout register, no "has this been written since reset"
//     tracking state of any kind is included, per the spec's explicit
//     instruction.
package WriteOnce;

interface WriteOnce;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    method Bit#(8) hwRead;
endinterface

module mkWriteOnce(WriteOnce);
    Reg#(Bit#(8)) r <- mkRegA(0);

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
        if (wstrb != 0) begin
            r <= (data & wstrb) | (~wstrb & r);
        end
    endmethod

    method Bit#(8) hwRead;
        return r;
    endmethod
endmodule

endpackage
