// BlueCheck equivalence: BLIND reference (refs2/Wset.bsv, package Wset,
// mkWset) vs REAL peakrdl-bsv generated RTL (Wset_signal.bsv,
// mkCSRSignal_reg0_field0), config: sw=rw, hw=r, onwrite=wset, width=8
// (Wset.rdl in this dir).
import BlueCheck :: *;
import StmtFSM :: *;
import Wset_signal :: *;
import Wset :: *;

module [BlueCheck] checkWset ();
   Wset spec <- mkWset();
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

module [Module] testWset ();
   blueCheck(checkWset);
endmodule
