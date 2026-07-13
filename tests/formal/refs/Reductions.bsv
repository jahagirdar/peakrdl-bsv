// Reductions.bsv
//
// Config #13: sw=rw, hw=r, all three of anded/ored/xored on the same
// 8-bit field (default onwrite -- masked merge, none named).
//
// Understanding of the spec:
//   - anded: 1 exactly when every bit of the field is 1.
//   - ored: 1 exactly when at least one bit of the field is 1.
//   - xored: 1 exactly when an odd number of bits are 1 (parity).
//   - These are pure combinational functions of the current stored
//     value r; they have no effect on storage and no interaction with
//     the write path.
//
// Judgment calls:
//   - `anded` is r == 8'hFF (all eight bits 1), rather than a bitwise
//     AND-reduce primitive, for readability; both are equivalent.
//   - `xored` (parity) is implemented via BSV's `^` reduction operator
//     over the bits of r (`\^ r`), which computes the XOR of every bit
//     -- 1 iff an odd number of bits are set.
package Reductions;

interface Reductions;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    method Bit#(8) swRead;
    method Bit#(8) hwRead;
    method Bool anded;
    method Bool ored;
    method Bool xored;
endinterface

module mkReductions(Reductions);
    Reg#(Bit#(8)) r <- mkRegA(0);

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
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

    method Bool anded;
        return r == 8'hFF;
    endmethod

    method Bool ored;
        return r != 0;
    endmethod

    method Bool xored;
        return unpack(^r);
    endmethod
endmodule

endpackage
