// BlueCheck equivalence: BLIND reference (refs2/Rset.bsv, package Rset,
// mkRset) vs REAL peakrdl-bsv generated RTL (Rset_signal.bsv,
// mkCSRSignal_reg0_f), config: sw=r, hw=w, onread=rset, width=8.
//
// SPECIAL CAUTION (per task instructions): same judgment call as Rclr,
// but for onread=rset -- the blind ref extrapolates that a same-cycle
// rset (sw read side effect) wins over a same-cycle hw write. Probed
// explicitly by raceProp below.
import BlueCheck :: *;
import StmtFSM :: *;
import Rset_signal :: *;
import Rset :: *;

module [BlueCheck] checkRset ();
   Rset spec <- mkRset();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   equiv("hwWrite", spec.hwWrite, imp.hw._write);
   equiv("swRead", spec.swRead, imp.bus.read);

   function Stmt raceProp(Bit#(8) hwdata) =
      seq
         action
            let sv <- spec.swRead;
            let iv <- imp.bus.read;
            spec.hwWrite(hwdata);
            imp.hw._write(hwdata);
            ensure(sv == iv);
         endaction
         action
            let sv2 <- spec.swRead;
            let iv2 <- imp.bus.read;
            ensure(sv2 == iv2);
         endaction
      endseq;
   prop("race_rset_vs_hwWrite", raceProp);

endmodule

module [Module] testRset ();
   blueCheck(checkRset);
endmodule
