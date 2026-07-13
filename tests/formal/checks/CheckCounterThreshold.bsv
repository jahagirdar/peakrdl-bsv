// BlueCheck equivalence: BLIND reference (CounterThreshold.bsv,
// package CounterThreshold, mkCounterThreshold) vs REAL peakrdl-bsv
// generated RTL (CounterThreshold_signal.bsv,
// mkCSRSignal_reg0_field0), config: sw=r, hw=r, bare counter
// (increment-only, fixed +1, data-less pulse), incrthreshold=200
// (integer). Confirmed the generator's default incrvalue resolves to
// 1 with a data-less incr() pulse method (systemrdl-compiler applies
// the SystemRDL-spec default of incrvalue=1 even when unset), matching
// the blind reference's "bare counter" assumption exactly.
import BlueCheck :: *;
import StmtFSM :: *;
import CounterThreshold_signal :: *;
import CounterThreshold :: *;

module [BlueCheck] checkCounterThreshold ();
   CounterThreshold spec <- mkCounterThreshold();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   equiv("incr", spec.incr, imp.hw.incr);
   equiv("currentValue", spec.rd, imp.currentValue);
   equiv("thresholdLevel", spec.thresholdLevel, imp.hw.incrthreshold);

   function ActionValue#(Bit#(8)) specSwRead();
      actionvalue
         return spec.rd;
      endactionvalue
   endfunction
   equiv("swRead", specSwRead, imp.bus.read);
endmodule

module [Module] testCounterThreshold ();
   blueCheck(checkCounterThreshold);
endmodule
