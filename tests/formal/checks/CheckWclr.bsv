// BlueCheck equivalence: BLIND reference (refs2/Wclr.bsv, package Wclr,
// mkWclr) vs REAL peakrdl-bsv generated RTL (Wclr_signal.bsv,
// mkCSRSignal_reg0_field0), config: sw=rw, hw=r, onwrite=wclr, width=8
// (Wclr.rdl in this dir).
//
// Same bridging idiom as CheckWoclr.bsv: spec.swRead/hwRead are plain
// value methods; imp.bus.read() is ActionValue#(Bit#(8)) (generic
// shape). Bridge is a pure type wrapper, no new logic.
import BlueCheck :: *;
import StmtFSM :: *;
import Wclr_signal :: *;
import Wclr :: *;

module [BlueCheck] checkWclr ();
   Wclr spec <- mkWclr();
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

module [Module] testWclr ();
   blueCheck(checkWclr);
endmodule
