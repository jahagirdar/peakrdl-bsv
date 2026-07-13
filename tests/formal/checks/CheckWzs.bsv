// BlueCheck equivalence: BLIND reference (refs2/Wzs.bsv, package Wzs,
// mkWzs) vs REAL peakrdl-bsv generated RTL (Wzs_signal.bsv,
// mkCSRSignal_reg0_field0), config: sw=rw, hw=r, onwrite=wzs, width=8
// (Wzs.rdl in this dir).
import BlueCheck :: *;
import StmtFSM :: *;
import Wzs_signal :: *;
import Wzs :: *;

module [BlueCheck] checkWzs ();
   Wzs spec <- mkWzs();
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

module [Module] testWzs ();
   blueCheck(checkWzs);
endmodule
