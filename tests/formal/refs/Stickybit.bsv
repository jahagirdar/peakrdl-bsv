// Stickybit.bsv
//
// Config #14: sw=rw, hw=rw, stickybit property (per-bit freeze).
//
// Understanding of the spec:
//   - "Once an individual bit of the field becomes 1 via a hardware
//     write, that specific bit can never be cleared back to 0 by a
//     further hardware write (only by software, or an explicit clear
//     mechanism) -- hardware writes effectively OR their value into the
//     field rather than replacing it. Hardware CAN still set additional
//     bits that were previously 0."
//   - This is exactly a bitwise OR of hw's presented data into the
//     current value: hwNext = r | hwData. Any bit that is 1 in r stays 1
//     regardless of what hw presents there; any bit that is 0 in r
//     becomes whatever hw presents there (0 stays 0, 1 becomes 1).
//   - Software's write path is completely unaffected (default
//     masked-merge, and CAN clear sticky bits back to 0, per spec: "only
//     by software ... [can they be cleared]").
//
// Judgment call: same-cycle race with a genuine sw write uses the same
// default sw-wins-the-whole-field precedence as the other configs (the
// per-bit nature of stickybit only affects how hw's own write is formed,
// not how it's arbitrated against a same-cycle sw write).
package Stickybit;

interface Stickybit;
    method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
    method Action hwWrite(Bit#(8) data);
    method Bit#(8) rd;
endinterface

module mkStickybit(Stickybit);
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

        if (hwReq.wget matches tagged Valid .hwData) begin
            Bit#(8) hwNext = r | hwData;  // per-bit OR: 1s are sticky
            if (swFires)
                r <= swNext;
            else
                r <= hwNext;
        end else if (swFires) begin
            r <= swNext;
        end
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
