// NEW comparison harness (not part of either the blind reference or the
// real generator). spec = blind reference PrecedenceSw (refs/PrecedenceSw.bsv,
// UNCHANGED, imported by package name). imp = real generator output for
// { sw=rw; hw=rw; precedence=sw; } field0[8] reused directly from
// yosys_eq/precedence_sw/test_signal.bsv (also UNCHANGED).
//
// No adapter file was needed: the blind reference's swWrite/hwWrite/rd
// method signatures already match the generator's bus.write/hw._write/
// currentValue signatures exactly, so both sides are wired straight into
// BlueCheck's equiv()/prop(). The generator's hw.clear() method is a
// generic always-present interface feature unrelated to the sw/hw/
// precedence property under test here (this RDL has no hwclr-style
// property configured) and is deliberately left untested by this harness.
//
// The prop() below drives spec.swWrite/spec.hwWrite AND imp.bus.write/
// imp.hw._write inside a single BSV action block -- i.e. within one clock
// edge / one rule firing -- to force the true same-cycle sw-vs-hw race
// (a plain per-method equiv() would never call both sides in the same
// cycle since it drives one side at a time).

import BlueCheck :: *;
import StmtFSM :: *;
import PrecedenceSw :: *;
import PrecedenceSw_signal :: *;

module [BlueCheck] checkPrecedenceSw ();
   PrecedenceSw spec <- mkPrecedenceSw();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   // Isolated (non-racing) paths.
   equiv("swWrite", spec.swWrite, imp.bus.write);
   equiv("hwWrite", spec.hwWrite, imp.hw._write);
   equiv("currentValue", spec.rd, imp.currentValue);

   // True-simultaneity race: both sides fire within one action block.
   function Stmt raceProp(Bit#(8) swdata, Bit#(8) swstrb, Bit#(8) hwdata) =
      seq
         action
            spec.swWrite(swdata, swstrb);
            spec.hwWrite(hwdata);
            imp.bus.write(swdata, swstrb);
            imp.hw._write(hwdata);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;

   prop("race_sw_wins", raceProp);
endmodule

module [Module] testPrecedenceSw ();
   blueCheck(checkPrecedenceSw);
endmodule
