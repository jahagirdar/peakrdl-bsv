// Rclr.bsv
//
// Config #7: sw=r (readable only), hw=w (unconditional overwrite, no
// other hw-side property), onread=rclr.
//
// Understanding of the spec:
//   - sw=r: software may only read; there is no sw write path/method at
//     all in this config.
//   - hw=w: hardware unconditionally overwrites the stored value with
//     whatever it presents ("A hardware write presents a new N-bit value
//     and unconditionally replaces the field's stored value").
//   - onread=rclr: "immediately after a software read returns the
//     field's current value, the field is cleared to all-zeros."
//
// Judgment calls:
//   - Modeling the read+clear as a single ActionValue method: the
//     returned value is the pre-clear stored value (the read snapshot),
//     and the clear-to-zero takes effect on the following clock edge,
//     same as any registered side effect in these models. This matches
//     "immediately after [the read] returns... the field is cleared."
//   - Same-cycle race between a software read (which clears) and a
//     hardware write is NOT covered by the spec's `precedence` section
//     (that section only governs a genuine sw *write* vs. a genuine hw
//     write). Since precedence defaults to `sw` whenever unspecified,
//     and rclr is sw's own read-triggered storage effect, I extend that
//     same default here: a same-cycle rclr wins over a same-cycle hw
//     write. This is an explicit judgment call, not something the
//     spec states outright.
package Rclr;

interface Rclr;
    method ActionValue#(Bit#(8)) swRead;
    method Action hwWrite(Bit#(8) data);
endinterface

module mkRclr(Rclr);
    Reg#(Bit#(8)) r <- mkRegA(0);
    RWire#(Bit#(8)) hwReq <- mkRWire;
    PulseWire swReadFired <- mkPulseWire;

    (* fire_when_enabled *)
    rule arbitrate;
        if (swReadFired) begin
            // rclr: sw's read-triggered clear wins a same-cycle race
            // against a hw write (judgment call -- see header comment).
            r <= 0;
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
