// BlueCheck equivalence: BLIND reference (refs2/SwW_HwR.bsv, package
// SwW_HwR, mkSwW_HwR) vs REAL peakrdl-bsv generated RTL
// (SwW_HwR_signal.bsv, mkCSRSignal_reg0_f), config: sw=w, hw=r, default
// masked-merge write, width=8.
import BlueCheck :: *;
import StmtFSM :: *;
import SwW_HwR_signal :: *;
import SwW_HwR :: *;

module [BlueCheck] checkSwW_HwR ();
   SwW_HwR spec <- mkSwW_HwR();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   equiv("swWrite", spec.swWrite, imp.bus.write);

   function Stmt readProp() =
      seq
         ensure(spec.hwRead == imp.hw._read);
      endseq;
   prop("hwRead", readProp);

endmodule

module [Module] testSwW_HwR ();
   blueCheck(checkSwW_HwR);
endmodule
