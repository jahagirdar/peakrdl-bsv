// SwmodDefault.bsv
//
// Config #10: sw=rw, hw=r, swmod property, default onwrite (masked
// merge, no woclr/woset/etc).
//
// Understanding of the spec:
//   - swmod: "produces a one-cycle pulse output whenever a software
//     access actually *modifies* the field's stored value... A
//     write/read that doesn't change anything (e.g. writing the same
//     value, or rclr on an already-zero field) must NOT pulse swmod."
//   - This config has no onread property, so only the write side can
//     ever modify the value; a plain read never pulses swmod here.
//   - For the default masked-merge write: next = (data & wstrb) | (~wstrb
//     & r). swmod pulses iff wstrb != 0 AND next != r. A wstrb == 0
//     write is the standard glitch no-op (no update, no pulse). A
//     wstrb != 0 write whose masked-merge result happens to equal the
//     current value (e.g. writing back the same data) must not pulse.
//
// Judgment calls:
//   - Register update is skipped entirely (not just the pulse) when
//     next == r, since there's nothing to change; this is functionally
//     equivalent to always assigning r <= next but makes the "no real
//     change" case explicit and avoids an unnecessary toggle in the
//     underlying storage element.
package SwmodDefault;

interface SwmodDefault;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    method Bit#(8) swRead;
    method Bit#(8) hwRead;
    method Bool swmodPulse;
endinterface

module mkSwmodDefault(SwmodDefault);
    Reg#(Bit#(8)) r <- mkRegA(0);
    PulseWire modFired <- mkPulseWire;

    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
        if (wstrb != 0) begin
            Bit#(8) next = (data & wstrb) | (~wstrb & r);
            if (next != r) begin
                r <= next;
                modFired.send;
            end
        end
    endmethod

    method Bit#(8) swRead;
        return r;
    endmethod

    method Bit#(8) hwRead;
        return r;
    endmethod

    method Bool swmodPulse;
        return modFired;
    endmethod
endmodule

endpackage
