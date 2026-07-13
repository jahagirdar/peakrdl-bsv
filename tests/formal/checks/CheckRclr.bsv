// BlueCheck equivalence: BLIND reference (refs2/Rclr.bsv, package Rclr,
// mkRclr) vs REAL peakrdl-bsv generated RTL (Rclr_signal.bsv,
// mkCSRSignal_reg0_f), config: sw=r, hw=w, onread=rclr, width=8.
//
// SPECIAL CAUTION (per task instructions): the blind reference's header
// comment flags an explicit judgment call -- that a same-cycle race
// between sw's read-triggered rclr and a hw write is not covered by the
// spec's `precedence` section, and extrapolates that rclr (as sw's own
// read-triggered storage effect) wins that race by extending the
// stated sw-write-wins-by-default rule. This harness specifically probes
// that exact race with the `raceProp` below.
import BlueCheck :: *;
import StmtFSM :: *;
import Rclr_signal :: *;
import Rclr :: *;

module [BlueCheck] checkRclr ();
   Rclr spec <- mkRclr();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   // Plain hw write (no concurrent sw read this cycle).
   equiv("hwWrite", spec.hwWrite, imp.hw._write);

   // Plain sw read (no concurrent hw write this cycle): both sides
   // return the pre-clear snapshot and both clear to 0 on the next edge.
   equiv("swRead", spec.swRead, imp.bus.read);

   // Same-cycle race: sw read (which clears) issued in the same cycle
   // as a hw write. Check (a) both sides return the same pre-clear
   // snapshot this cycle, and (b) both sides land on the same next-cycle
   // stored value (probed via a following read).
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
   prop("race_rclr_vs_hwWrite", raceProp);

endmodule

module [Module] testRclr ();
   blueCheck(checkRclr);
endmodule
