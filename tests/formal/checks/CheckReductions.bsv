// BlueCheck equivalence: BLIND reference (refs2/Reductions.bsv, package
// Reductions, mkReductions) vs REAL peakrdl-bsv generated RTL
// (Reductions_signal.bsv, mkCSRSignal_reg0_f), config: sw=rw, hw=r,
// anded/ored/xored, default onwrite (masked merge), width=8.
//
// Interface bridging note: the blind reference exposes swRead/hwRead as
// plain value methods (no side effects configured for this property
// combination), while the generator's uniform template always emits an
// ActionValue read() on the sw side. Since neither side actually has any
// registered side effect for this config, we bridge by discarding the
// ActionValue's implicit "fire" via a Stmt wrapper -- functionally
// equivalent to a value read here.
import BlueCheck :: *;
import StmtFSM :: *;
import Reductions_signal :: *;
import Reductions :: *;

module [BlueCheck] checkReductions ();
   Reductions spec <- mkReductions();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   equiv("swWrite", spec.swWrite, imp.bus.write);

   function Stmt readProp() =
      seq
         action
            let iv <- imp.bus.read;
            Bool ok = (spec.swRead == iv)
                   && (spec.hwRead == imp.currentValue)
                   && (pack(spec.anded) == pack(imp.hw.anded))
                   && (pack(spec.ored) == pack(imp.hw.ored))
                   && (pack(spec.xored) == pack(imp.hw.xored));
            ensure(ok);
         endaction
      endseq;
   prop("read_and_reductions", readProp);

endmodule

module [Module] testReductions ();
   blueCheck(checkReductions);
endmodule
