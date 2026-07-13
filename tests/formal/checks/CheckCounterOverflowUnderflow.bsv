// BlueCheck equivalence: BLIND reference (CounterOverflowUnderflow.bsv,
// package CounterOverflowUnderflow, mkCounterOverflowUnderflow) vs REAL
// peakrdl-bsv generated RTL (CounterOverflowUnderflow_signal.bsv,
// mkCSRSignal_reg0_field0), config: sw=r, hw=r, counter,
// incrwidth=8, decrwidth=8, overflow, underflow.
//
// Phase-alignment bridging note: the blind reference exposes
// overflowPulse/underflowPulse as REGISTERED one-cycle-delayed pulses
// (visible the cycle AFTER the triggering incr/decr call, since
// overflowReg/underflowReg are Regs written inside the same rule that
// processes the count). The real generator exposes hw.overflow()/
// hw.underflow() as COMBINATIONAL PulseWire reads, visible in the SAME
// cycle the incr()/decr() method is called (consistent with how the
// generator treats every other "pulse" style output -- swacc/swmod/
// hwset/hwclr -- across the whole codebase). Neither side's logic is
// touched; we sample imp's combinational pulse into a Reg the same
// cycle it's produced, then compare that captured (one-cycle-delayed)
// value against spec's own registered pulse on the following step, so
// both sides are compared at the same logical point in time.
import BlueCheck :: *;
import StmtFSM :: *;
import CounterOverflowUnderflow_signal :: *;
import CounterOverflowUnderflow :: *;

module [BlueCheck] checkCounterOverflowUnderflow ();
   CounterOverflowUnderflow spec <- mkCounterOverflowUnderflow();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   Reg#(Bool) capOvf <- mkRegA(False);
   Reg#(Bool) capUnf <- mkRegA(False);

   // Always-firing background capture rule (same idiom as the
   // generator's own ext_signal relay rules): sampling imp's
   // combinational (same-cycle) pulse into a Reg has to happen from a
   // rule that is NOT the same atomic action that also drives the
   // RWire the pulse is derived from -- otherwise BSC reports a
   // circular scheduling conflict (the triggering action would need to
   // fire both before AND after imp's own r_write rule in the same
   // cycle) and silently generates a rule that can never fire.
   rule captureImpPulses;
      capOvf <= imp.hw.overflow;
      capUnf <= imp.hw.underflow;
   endrule

   function ActionValue#(Bit#(8)) specSwRead();
      actionvalue
         return spec.rd;
      endactionvalue
   endfunction
   equiv("swRead", specSwRead, imp.bus.read);
   equiv("currentValue", spec.rd, imp.currentValue);

   function Stmt incrProp(Bit#(8) amt) =
      seq
         action
            spec.incr(amt);
            imp.hw.incr(amt);
         endaction
         ensure(spec.rd == imp.currentValue);
         ensure(spec.overflowPulse == capOvf);
      endseq;
   prop("incrOnly", incrProp);

   function Stmt decrProp(Bit#(8) amt) =
      seq
         action
            spec.decr(amt);
            imp.hw.decr(amt);
         endaction
         ensure(spec.rd == imp.currentValue);
         ensure(spec.underflowPulse == capUnf);
      endseq;
   prop("decrOnly", decrProp);

   // Same-cycle race: hw pulses incr AND decr together. This is the key
   // scrutiny case -- the blind reference's judgment call applies BOTH
   // deltas in the same cycle (incr's result feeds decr's input), while
   // the generator's rule body is a single if/else-if chain where the
   // counter-up branch and counter-down branch are mutually exclusive
   // ("else if"): if the up-branch's condition (incr requested) is true,
   // the down-branch is never evaluated at all that cycle, so a
   // simultaneous decr request is silently dropped whenever incr also
   // fires. Checking this to characterize the divergence precisely.
   function Stmt raceProp(Bit#(8) incrAmt, Bit#(8) decrAmt) =
      seq
         action
            spec.incr(incrAmt);
            spec.decr(decrAmt);
            imp.hw.incr(incrAmt);
            imp.hw.decr(decrAmt);
         endaction
         ensure(spec.rd == imp.currentValue);
         ensure(spec.overflowPulse == capOvf);
         ensure(spec.underflowPulse == capUnf);
      endseq;
   prop("race_incr_decr", raceProp);
endmodule

module [Module] testCounterOverflowUnderflow ();
   blueCheck(checkCounterOverflowUnderflow);
endmodule
