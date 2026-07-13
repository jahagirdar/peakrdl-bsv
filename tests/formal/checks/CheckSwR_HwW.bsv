// BlueCheck equivalence: BLIND reference (refs2/SwR_HwW.bsv, package
// SwR_HwW, mkSwR_HwW) vs REAL peakrdl-bsv generated RTL
// (SwR_HwW_signal.bsv, mkCSRSignal_reg0_f), config: sw=r, hw=w, no
// onread/onwrite/side-effect properties at all, width=8.
import BlueCheck :: *;
import StmtFSM :: *;
import SwR_HwW_signal :: *;
import SwR_HwW :: *;

module [BlueCheck] checkSwR_HwW ();
   SwR_HwW spec <- mkSwR_HwW();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   equiv("hwWrite", spec.hwWrite, imp.hw._write);

   function Stmt readProp() =
      seq
         ensure(spec.swRead == imp.currentValue);
      endseq;
   prop("swRead", readProp);

endmodule

module [Module] testSwR_HwW ();
   blueCheck(checkSwR_HwW);
endmodule
