// BlueCheck equivalence: BLIND reference (refs2/Wzc.bsv, package Wzc,
// mkWzc) vs REAL peakrdl-bsv generated RTL (Wzc_signal.bsv,
// mkCSRSignal_reg0_field0), config: sw=rw, hw=r, onwrite=wzc, width=8
// (Wzc.rdl in this dir).
import BlueCheck :: *;
import StmtFSM :: *;
import Wzc_signal :: *;
import Wzc :: *;

module [BlueCheck] checkWzc ();
   Wzc spec <- mkWzc();
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

module [Module] testWzc ();
   blueCheck(checkWzc);
endmodule
