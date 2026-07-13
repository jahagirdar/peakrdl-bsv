// Baseline.bsv
//
// Config #1: plain field, sw=rw, hw=r (hardware may read the stored value
// but never writes it), no onread/onwrite/side-effect properties at all.
//
// Understanding of the spec (General field shape + no exceptions):
//   - Storage is an 8-bit register `r`.
//   - Software write: presents `data` (8b) and `wstrb` (8b, bit-strobed
//     per the doc's simplifying assumption). wstrb == 0 is a total no-op
//     glitch: it must not touch `r` at all (not even a same-value write).
//   - Software write with wstrb != 0: default masked merge,
//       next = (data & wstrb) | (~wstrb & current)
//   - Software read: simply returns the current value of `r`, no side
//     effects (no onread property configured for this config).
//   - Hardware: read-only view of `r`. There is no hardware write port on
//     this interface at all, since hw=r.
//
// Judgment calls:
//   - "sw read" and "hw read" are exposed as two separate methods even
//     though they return the same value, to keep the interface shape
//     uniform with the other configs (some of which do differentiate
//     sw-visible vs hw-visible values via onread side effects).
package Baseline;

interface Baseline;
    // Software-facing write port. wstrb qualifies which bits are written;
    // wstrb == 0 must be a complete no-op.
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    // Software-facing read port (no side effects for this config).
    method Bit#(8) swRead;
    // Hardware-facing read-only view of the stored value.
    method Bit#(8) hwRead;
endinterface

module mkBaseline(Baseline);
    // Async-reset storage register, resets to 0.
    Reg#(Bit#(8)) r <- mkRegA(0);

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
        // wstrb == 0 => wstrb & data == 0 and ~wstrb & r == r, so the
        // masked-merge formula is already a no-op in that case; but we
        // gate explicitly per the spec's "must not affect ... any side
        // effect" language, since later configs' side effects (swacc,
        // swmod, onwrite) truly depend on this gate, and we want this
        // baseline to look structurally like those.
        if (wstrb != 0) begin
            r <= (data & wstrb) | (~wstrb & r);
        end
    endmethod

    method Bit#(8) swRead;
        return r;
    endmethod

    method Bit#(8) hwRead;
        return r;
    endmethod
endmodule

endpackage
