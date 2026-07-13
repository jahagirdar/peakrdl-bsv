// BlueCheck equivalence: BLIND reference (refs2/Woset.bsv, package Woset,
// mkWoset) vs REAL peakrdl-bsv generated RTL (Woset_signal.bsv,
// mkCSRSignal_reg0_field0), config: sw=rw, hw=r, onwrite=woset, width=8
// (Woset.rdl in this dir).
import BlueCheck :: *;
import StmtFSM :: *;
import Woset_signal :: *;
import Woset :: *;

module [BlueCheck] checkWoset ();
   Woset spec <- mkWoset();
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

module [Module] testWoset ();
   blueCheck(checkWoset);
endmodule
