// BlueCheck equivalence: BLIND reference (refs2/CounterIncrDecrValue.bsv)
// vs REAL peakrdl-bsv generated RTL (top_signal.bsv, mkCSRSignal_reg0_field0),
// config: sw=r, hw=r, counter, incrvalue=5, decrvalue=3, width=8.
//
// Separate incr-only and decr-only props first (single-pulse per cycle),
// then a same-cycle-both prop to probe the incr+decr interaction the
// blind ref explicitly flagged as a judgment call (combined delta,
// r+5-3) versus whatever the generator actually implements.
import BlueCheck :: *;
import StmtFSM :: *;
import CounterIncrDecrValue_signal :: *;
import CounterIncrDecrValue :: *;

module [BlueCheck] checkCounterIncrDecrValue ();
   CounterIncrDecrValue spec <- mkCounterIncrDecrValue();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   function Stmt incrOnly() =
      seq
         action
            spec.incr();
            imp.hw.incr();
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("incr_only", incrOnly);

   function Stmt decrOnly() =
      seq
         action
            spec.decr();
            imp.hw.decr();
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("decr_only", decrOnly);

   function Stmt bothSameCycle() =
      seq
         action
            spec.incr();
            spec.decr();
            imp.hw.incr();
            imp.hw.decr();
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("incr_and_decr_same_cycle", bothSameCycle);
endmodule

module [Module] testCounterIncrDecrValue ();
   blueCheck(checkCounterIncrDecrValue);
endmodule
