// Swacc.bsv
//
// Config #9: sw=rw, hw=r, swacc property (default onwrite -- masked
// merge, since no onwrite property is named for this config).
//
// Understanding of the spec:
//   - swacc: "produces a one-cycle pulse output whenever software
//     accesses the field at all -- any read, or any write with a
//     nonzero wstrb -- regardless of whether the stored value actually
//     changes."
//   - So the pulse fires on every genuine read call AND on every write
//     call with wstrb != 0, even a write that reproduces the same data
//     or a no-op-valued write (wstrb!=0 is what counts, not whether data
//     changes).
//   - A write with wstrb == 0 is the standard glitch no-op: no storage
//     update AND no swacc pulse (it is "as if it didn't happen").
//
// Judgment calls:
//   - The read method must be an Action (ActionValue, since it also
//     returns the value) rather than a plain combinational value method,
//     so that "a read happened this cycle" is an observable event we can
//     pulse from. This mirrors the ActionValue read pattern used for
//     rclr/rset, even though a plain swacc read has no storage side
//     effect of its own.
//   - swacc output is exposed as a same-cycle combinational Bool method
//     (`swaccPulse`) that is true iff a genuine read or a wstrb!=0 write
//     method was called this same cycle.
package Swacc;

interface Swacc;
    method ActionValue#(Bit#(8)) swRead;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    method Bit#(8) hwRead;
    method Bool swaccPulse;
endinterface

module mkSwacc(Swacc);
    Reg#(Bit#(8)) r <- mkRegA(0);
    PulseWire readFired <- mkPulseWire;
    PulseWire writeFired <- mkPulseWire;

    method ActionValue#(Bit#(8)) swRead;
        readFired.send;
        return r;
    endmethod

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
        if (wstrb != 0) begin
            r <= (data & wstrb) | (~wstrb & r);
            writeFired.send;
        end
    endmethod

    method Bit#(8) hwRead;
        return r;
    endmethod

    method Bool swaccPulse;
        return readFired || writeFired;
    endmethod
endmodule

endpackage
