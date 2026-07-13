// BlueCheck equivalence: BLIND reference (refs2/Wot.bsv, package Wot,
// mkWot) vs REAL peakrdl-bsv generated RTL (Wot_signal.bsv,
// mkCSRSignal_reg0_field0), config: sw=rw, hw=r, onwrite=wot, width=8
// (Wot.rdl in this dir).
import BlueCheck :: *;
import StmtFSM :: *;
import Wot_signal :: *;
import Wot :: *;

module [BlueCheck] checkWot ();
   Wot spec <- mkWot();
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

module [Module] testWot ();
   blueCheck(checkWot);
endmodule
