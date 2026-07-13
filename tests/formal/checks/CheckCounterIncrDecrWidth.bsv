// BlueCheck equivalence: BLIND reference (refs2/CounterIncrDecrWidth.bsv)
// vs REAL peakrdl-bsv generated RTL (top_signal.bsv, mkCSRSignal_reg0_field0),
// config: sw=r, hw=r, counter, incrwidth=8, decrwidth=8, width=8.
import BlueCheck :: *;
import StmtFSM :: *;
import CounterIncrDecrWidth_signal :: *;
import CounterIncrDecrWidth :: *;

module [BlueCheck] checkCounterIncrDecrWidth ();
   CounterIncrDecrWidth spec <- mkCounterIncrDecrWidth();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   function Stmt incrOnly(Bit#(8) amt) =
      seq
         action
            spec.incr(amt);
            imp.hw.incr(amt);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("incr_only", incrOnly);

   function Stmt decrOnly(Bit#(8) amt) =
      seq
         action
            spec.decr(amt);
            imp.hw.decr(amt);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("decr_only", decrOnly);

   function Stmt bothSameCycle(Bit#(8) incrAmt, Bit#(8) decrAmt) =
      seq
         action
            spec.incr(incrAmt);
            spec.decr(decrAmt);
            imp.hw.incr(incrAmt);
            imp.hw.decr(decrAmt);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("incr_and_decr_same_cycle", bothSameCycle);
endmodule

module [Module] testCounterIncrDecrWidth ();
   blueCheck(checkCounterIncrDecrWidth);
endmodule
