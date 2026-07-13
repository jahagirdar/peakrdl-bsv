// Woclr.bsv
//
// Config #2: sw=rw, hw=r, onwrite=woclr.
//
// Understanding of the spec:
//   - Same base shape as Baseline (8-bit field, hw read-only).
//   - onwrite=woclr replaces the *default* masked-merge write policy:
//     "writing a 1 to a bit position clears that bit to 0. A 0 in a bit
//     position leaves that bit unchanged." wstrb still gates which bits
//     of `data` even count as "written 1" at all.
//   - So the bits that actually get cleared are exactly the bits where
//     both wstrb==1 AND data==1; every other bit (wstrb==0, or wstrb==1
//     but data==0) is left at its current value.
//       clearMask = data & wstrb
//       next      = r & ~clearMask
//   - wstrb == 0 (whole write) is still a total no-op (clearMask is all
//     zero automatically in that case, so no extra gating is strictly
//     required, but we still guard on wstrb != 0 for symmetry/clarity
//     with the other configs and in case of a future property that would
//     need the distinction).
//
// Judgment calls:
//   - None of the onread/swacc/swmod properties are in play for this
//     config, so a plain read method suffices.
package Woclr;

interface Woclr;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    method Bit#(8) swRead;
    method Bit#(8) hwRead;
endinterface

module mkWoclr(Woclr);
    Reg#(Bit#(8)) r <- mkRegA(0);

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
        if (wstrb != 0) begin
            Bit#(8) clearMask = data & wstrb;
            r <= r & ~clearMask;
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
