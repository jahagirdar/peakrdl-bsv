// BlueCheck equivalence: BLIND reference (HwsetHwclr.bsv, package
// HwsetHwclr, mkHwsetHwclr) vs REAL peakrdl-bsv generated RTL
// (HwsetHwclr_signal.bsv, mkCSRSignal_reg0_field0), config: sw=r,
// hw=r, hwset AND hwclr both configured.
//
// Interface bridging note: the real generator's HW interface exposes
// a THIRD pulse method, the generic unconditional `clear()`
// boilerplate (same pw_clear PulseWire that hwclr() itself drives --
// see print_bsv_signal.py, always emitted regardless of hwclr). Not
// modeled by the blind reference (no separate onclear property beyond
// the explicit hwclr already tested) and left unexercised here,
// consistent with the established prior-round convention.
import BlueCheck :: *;
import StmtFSM :: *;
import HwsetHwclr_signal :: *;
import HwsetHwclr :: *;

module [BlueCheck] checkHwsetHwclr ();
   HwsetHwclr spec <- mkHwsetHwclr();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   function ActionValue#(Bit#(8)) specSwRead();
      actionvalue
         return spec.swRead;
      endactionvalue
   endfunction
   equiv("swRead", specSwRead, imp.bus.read);
   equiv("hwRead", spec.hwRead, imp.hw._read);
   equiv("currentValue", spec.hwRead, imp.currentValue);

   // Isolated pulses.
   function Stmt hwsetProp() =
      seq
         action
            spec.pulseHwset;
            imp.hw.hwset;
         endaction
         ensure(spec.hwRead == imp.currentValue);
      endseq;
   prop("hwsetOnly", hwsetProp);

   function Stmt hwclrProp() =
      seq
         action
            spec.pulseHwclr;
            imp.hw.hwclr;
         endaction
         ensure(spec.hwRead == imp.currentValue);
      endseq;
   prop("hwclrOnly", hwclrProp);

   // Same-cycle race: both pulse together -- spec says clear wins.
   function Stmt raceProp() =
      seq
         action
            spec.pulseHwset;
            spec.pulseHwclr;
            imp.hw.hwset;
            imp.hw.hwclr;
         endaction
         ensure(spec.hwRead == imp.currentValue);
         ensure(imp.currentValue == 0);   // clear must win
      endseq;
   prop("race_hwset_hwclr", raceProp);
endmodule

module [Module] testHwsetHwclr ();
   blueCheck(checkHwsetHwclr);
endmodule
