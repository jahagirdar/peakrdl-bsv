// SwR_HwW.bsv
//
// Config #15: sw=r (sw can only read), hw=w (hw can only write,
// unconditional overwrite, no other hw-side properties). No
// onread/onwrite/side-effect properties at all.
//
// Understanding of the spec:
//   - sw=r: only a read method exists on the sw side; there is no sw
//     write path/method whatsoever.
//   - hw=w: "A hardware write presents a new N-bit value and
//     unconditionally replaces the field's stored value" -- plain
//     overwrite, no we/wel/hwenable/hwmask/sticky/stickybit in this
//     config.
//
// Judgment calls:
//   - None; this is the simplest possible shape -- a hw-driven,
//     sw-readable status register with no side effects at all.
package SwR_HwW;

interface SwR_HwW;
    method Bit#(8) swRead;
    method Action hwWrite(Bit#(8) data);
endinterface

module mkSwR_HwW(SwR_HwW);
    Reg#(Bit#(8)) r <- mkRegA(0);

    method Bit#(8) swRead;
        return r;
    endmethod

    method Action hwWrite(Bit#(8) data);
        r <= data;
    endmethod
endmodule

endpackage
