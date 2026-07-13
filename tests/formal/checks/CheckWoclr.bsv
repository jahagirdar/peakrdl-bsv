// BlueCheck equivalence: BLIND reference (refs/Woclr.bsv, package Woclr,
// mkWoclr) vs REAL peakrdl-bsv generated RTL (Woclr_signal.bsv,
// mkCSRSignal_reg0_field0), config: sw=rw, hw=r, onwrite=woclr, width=8
// (woclr.rdl in yosys_eq/woclr).
//
// Same bridging rationale as CheckBaseline.bsv: spec.swRead/hwRead are
// plain value methods; imp.bus.read() is ActionValue#(Bit#(8)) (generic
// shape). Bridge is a pure type wrapper, no new logic. hw.clear() is
// left unexercised for the same reason (no onclear/hwclr configured on
// this field; onwrite=woclr is a distinct property from onclear).
import BlueCheck :: *;
import StmtFSM :: *;
import Woclr_signal :: *;
import Woclr :: *;

module [BlueCheck] checkWoclr ();
   Woclr spec <- mkWoclr();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   function ActionValue#(Bit#(8)) specSwRead();
      actionvalue
         return spec.swRead;
      endactionvalue
   endfunction

   equiv("swWrite", spec.swWrite, imp.bus.write);
   equiv("swRead", specSwRead, imp.bus.read);
   equiv("hwRead", spec.hwRead, imp.hw._read);
   equiv("currentValue", spec.swRead, imp.currentValue);
endmodule

module [Module] testWoclr ();
   blueCheck(checkWoclr);
endmodule
