// BlueCheck equivalence: BLIND reference (refs/Baseline.bsv, package
// Baseline, mkBaseline) vs REAL peakrdl-bsv generated RTL
// (Baseline_signal.bsv, mkCSRSignal_reg0_field0), config: sw=rw, hw=r,
// width=8, no onwrite/onread properties (baseline.rdl in yosys_eq/baseline).
//
// Interface bridging note: the blind reference exposes swRead/hwRead as
// plain *value* methods (Bit#(8)), since it never saw the generator and
// modeled "read" as a pure, side-effect-free observation for this config
// (no onread/swacc/swmod in play). The real generator's `bus.read()` is
// uniformly an ActionValue#(Bit#(8)) (generic shape used for every field,
// since other configs *do* have read side effects), even though for this
// config the underlying generated code has no actual side effect (the
// `if(mod) pw_swmod.send();` guard is always false here since `mod` is
// a compile-time False literal in this config's generated code). We
// bridge purely at the type level -- wrapping the spec's pure value
// return in an `actionvalue` block -- without adding any new logic on
// either side.
//
// hw.clear(): baseline.rdl has no onclear/hwclr property, and the blind
// reference correctly implements no clear support at all (nothing in
// the spec to model). The real generator still exposes a generic
// hw.clear() as universal boilerplate (print_bsv_reg.py always emits
// it, functionally clearing the storage register to 0 unconditionally
// regardless of RDL properties). Since the blind reference's Reg is
// fully encapsulated with no external force-clear path, and inventing
// one here would mean adding NEW logic instead of adapting existing
// logic, we follow the same precedent used for the We/Wel/Swwe/etc.
// configs: leave it unexercised in this BlueCheck harness (not called
// at all), and correspondingly tie EN_hw_clear=0 in the Yosys top-level
// wrapper so it is never exercised on either side of the SAT proof either.
import BlueCheck :: *;
import StmtFSM :: *;
import Baseline_signal :: *;
import Baseline :: *;

module [BlueCheck] checkBaseline ();
   Baseline spec <- mkBaseline();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   // Type-level bridge only: spec.swRead (value) -> ActionValue#(Bit#(8)),
   // to match imp.bus.read()'s shape. No new logic, just a wrapper.
   function ActionValue#(Bit#(8)) specSwRead();
      actionvalue
         return spec.swRead;
      endactionvalue
   endfunction

   equiv("swWrite", spec.swWrite, imp.bus.write);
   equiv("swRead", specSwRead, imp.bus.read);
   equiv("hwRead", spec.hwRead, imp.hw._read);
   equiv("currentValue", spec.swRead, imp.currentValue);
endmodule

module [Module] testBaseline ();
   blueCheck(checkBaseline);
endmodule
