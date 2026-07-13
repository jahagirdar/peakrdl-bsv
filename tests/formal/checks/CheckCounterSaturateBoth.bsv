// BlueCheck equivalence: BLIND reference (CounterSaturateBoth.bsv,
// package CounterSaturateBoth, mkCounterSaturateBoth) vs REAL
// peakrdl-bsv generated RTL, config: sw=r, hw=r, counter, incrwidth=8,
// decrwidth=8, incrsaturate=200 (integer ceiling), decrsaturate (bool,
// floor 0).
//
// MIGRATION NOTE: at original-audit time, the generator's counter-
// saturate template had a real bug (T0033: ambiguous type on an
// un-annotated `amt` local used only inside another zeroExtend,
// whenever incrwidth/decrwidth equalled the field's own width together
// with incrsaturate/decrsaturate) that made the real, unmodified
// generator output FAIL TO COMPILE -- see the "bidirectional_counter_
// saturate" regression-guard test and its comment in
// tests/systemrdl_features_test.py, which confirms this was found via
// this same blind-reference formal verification effort and has SINCE
// BEEN FIXED upstream in print_bsv_signal.py/templates/config_signal.bsv.
// The audit-time harness therefore had to import a hand-patched local
// diagnostic copy (`CounterSaturateBoth_signal_patched.bsv`, adding
// explicit Bit#(TAdd#(n,1)) annotations, no logic change) instead of the
// generator's real output. That patch is NOT carried into this checked-
// in suite: this file now imports the plain `CounterSaturateBoth_signal`
// produced by the current (fixed) exporter directly, which compiles and
// runs cleanly (confirmed during migration).
//
// Same-cycle incr+decr note: the audit-time generator structured
// counter-up/counter-down as mutually exclusive "else if" branches, so a
// genuine same-cycle incr+decr race only ever applied the increment
// (decr silently dropped that cycle). The CURRENT generator applies both
// deltas in sequence against a shared value instead (see
// test_counter_incr_decr in tests/systemrdl_features_test.py) -- also
// already fixed upstream. raceProp below exercises this directly against
// today's generator.
import BlueCheck :: *;
import StmtFSM :: *;
import CounterSaturateBoth_signal :: *;
import CounterSaturateBoth :: *;

module [BlueCheck] checkCounterSaturateBoth ();
   CounterSaturateBoth spec <- mkCounterSaturateBoth();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

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
      endseq;
   prop("incrOnly", incrProp);

   function Stmt decrProp(Bit#(8) amt) =
      seq
         action
            spec.decr(amt);
            imp.hw.decr(amt);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("decrOnly", decrProp);

   function Stmt raceProp(Bit#(8) incrAmt, Bit#(8) decrAmt) =
      seq
         action
            spec.incr(incrAmt);
            spec.decr(decrAmt);
            imp.hw.incr(incrAmt);
            imp.hw.decr(decrAmt);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("race_incr_decr", raceProp);
endmodule

module [Module] testCounterSaturateBoth ();
   blueCheck(checkCounterSaturateBoth);
endmodule
