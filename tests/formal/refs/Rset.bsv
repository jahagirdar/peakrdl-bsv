// Rset.bsv
//
// Config #8: sw=r (readable only), hw=w (unconditional overwrite, no
// other hw-side property), onread=rset.
//
// Understanding of the spec:
//   - Same shape as Rclr.bsv, but onread=rset: "immediately after a
//     software read returns the field's current value, the field is
//     set to all-ones," instead of cleared.
//
// Judgment calls:
//   - Same two judgment calls as Rclr.bsv: (1) the read returns the
//     pre-side-effect snapshot via ActionValue, with the set-to-all-ones
//     effect landing on the next clock edge; (2) a same-cycle race
//     between rset's storage effect and a hw write is not covered by
//     the spec's `precedence` section, so by extension of the stated
//     sw-default, rset wins over a same-cycle hw write.
package Rset;

interface Rset;
    method ActionValue#(Bit#(8)) swRead;
    method Action hwWrite(Bit#(8) data);
endinterface

module mkRset(Rset);
    Reg#(Bit#(8)) r <- mkRegA(0);
    RWire#(Bit#(8)) hwReq <- mkRWire;
    PulseWire swReadFired <- mkPulseWire;

    (* fire_when_enabled *)
    rule arbitrate;
        if (swReadFired) begin
            // rset: sw's read-triggered set wins a same-cycle race
            // against a hw write (judgment call -- see header comment).
            r <= 8'hFF;
        end else if (hwReq.wget matches tagged Valid .d) begin
            r <= d;
        end
    endrule

    method ActionValue#(Bit#(8)) swRead;
        swReadFired.send;
        return r;
    endmethod

    method Action hwWrite(Bit#(8) data);
        hwReq.wset(data);
    endmethod
endmodule

endpackage
