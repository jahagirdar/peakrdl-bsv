// BlueCheck equivalence: BLIND reference (refs2/Singlepulse.bsv, package
// Singlepulse, mkSinglepulse) vs REAL peakrdl-bsv generated RTL
// (Singlepulse_signal.bsv, mkCSRSignal_reg0_f), config: sw=rw, hw=r,
// singlepulse, width=1.
//
// SPECIAL CAUTION (per task instructions): `singlepulse` has NO
// definition anywhere in the spec doc. The blind ref extrapolates
// "auto-clear after one cycle unless sw re-writes it that same cycle"
// from general SystemRDL knowledge. This harness probes the exact
// multi-cycle auto-clear timing against a genuine sw write, plus the
// case of sw writing while the field is still 1 from a prior write, to
// see whether behavior differs from the blind model's judgment call.
import BlueCheck :: *;
import StmtFSM :: *;
import Singlepulse_signal :: *;
import Singlepulse :: *;

module [BlueCheck] checkSinglepulse ();
   Singlepulse spec <- mkSinglepulse();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   // Plain single sw write, no coordinated multi-cycle check (covers
   // basic masked-merge write behavior on its own schedule).
   equiv("swWrite", spec.swWrite, imp.bus.write);

   // Coordinated multi-cycle sequence: sw write (data,wstrb), then
   // observe hwRead/pulse for the following 3 cycles with NO further sw
   // write, to check the auto-clear timing precisely.
   function Stmt pulseProp(Bit#(1) data, Bit#(1) wstrb) =
      seq
         action
            spec.swWrite(data, wstrb);
            imp.bus.write(data, wstrb);
         endaction
         action
            Bool ok = (spec.hwRead == imp.hw._read)
                   && (pack(imp.hw.pulse) == imp.hw._read);
            ensure(ok);
         endaction
         action
            ensure(spec.hwRead == imp.hw._read);
         endaction
         action
            ensure(spec.hwRead == imp.hw._read);
         endaction
      endseq;
   prop("pulse_autoclear_timing", pulseProp);

   // Re-write-while-still-1 case: force the field to 1 via a write,
   // then attempt another sw write on the very next cycle (the cycle
   // where auto-clear would otherwise have fired) and check who wins.
   function Stmt rewriteRaceProp(Bit#(1) data2, Bit#(1) wstrb2) =
      seq
         action
            spec.swWrite(1, 1);
            imp.bus.write(1, 1);
         endaction
         action
            ensure(spec.hwRead == imp.hw._read);
            spec.swWrite(data2, wstrb2);
            imp.bus.write(data2, wstrb2);
         endaction
         action
            ensure(spec.hwRead == imp.hw._read);
         endaction
      endseq;
   prop("rewrite_vs_autoclear_race", rewriteRaceProp);

endmodule

module [Module] testSinglepulse ();
   blueCheck(checkSinglepulse);
endmodule
