// BlueCheck equivalence check for ResetSignalLow (activelow resetsignal,
// sw=rw, hw=r, width=8).
//
// NOTE (migration disclosure): unlike every other file in this suite,
// this harness was NOT recovered from the original formal-audit
// artifacts -- the round-1 scratch directory for ResetSignalLow
// (compare/ResetSignalLow/) only ever contained a "sanity" bsc-elaborate
// scaffold for the blind reference alone; no CheckResetSignalLow.bsv
// equivalence harness was ever actually built or run there. This file
// was authored fresh for this checked-in suite, by direct structural
// analogy with CheckResetSignalHigh.bsv (which WAS run successfully in
// the original audit): refs/ResetSignalLow.bsv exposes the identical
// interface shape (setResetCond/swWrite/swRead/hwRead) as
// ResetSignalHigh, differing only in which raw level of the external
// condition it treats as "asserted" internally -- so the same
// spec/imp/equiv wiring applies unchanged, just against the
// activelow-signal RDL/generated output instead of activehigh. See
// tests/formal/README.md for how this gap is reported.
//
// spec = blind reference refs/ResetSignalLow.bsv (unmodified).
// imp  = real generator's mkCSRSignal_reg0_field0, generated from
//        rdl/ResetSignalLow.rdl (signal {activelow;} rst_sig). The
//        generator threads the resetsignal condition down as a Bool
//        module "parameter" that is actually a continuously-wired RTL
//        input (a common BSV idiom distinct from Integer/numeric-type
//        params, which really are elaboration-time constants) -- so we
//        reproduce the same top-level DWire-driven wrapper the real
//        generator's CSR level uses, purely as wiring, no logic change.

import BlueCheck :: *;
import StmtFSM :: *;
import ResetSignalLow :: *;
import ResetSignalLow_signal :: *;

interface RSSpec;
   method Action setResetCond(Bool cond);
   method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
   method Bit#(8) swRead;
   method Bit#(8) hwRead;
endinterface

module mkRSSpec(RSSpec);
   ResetSignalLow s <- mkResetSignalLow();

   method Action setResetCond(Bool cond) = s.setResetCond(cond);
   method Action swWrite(Bit#(8) data, Bit#(8) wstrb) = s.swWrite(data, wstrb);
   method Bit#(8) swRead = s.swRead;
   method Bit#(8) hwRead = s.hwRead;
endmodule

interface RSImp;
   method Action setResetCond(Bool cond);
   method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
   method Bit#(8) swRead;
   method Bit#(8) hwRead;
endinterface

module mkRSImp(RSImp);
   // Unlike CheckResetSignalHigh's condWire (which defaults to False =
   // "not asserted" for an activehigh condition), an activelow
   // condition's inactive/default level is logic 1 -- so this DWire
   // must default to True, or the field would sit permanently in reset
   // on every cycle setResetCond() isn't actively re-driven (confirmed
   // empirically: defaulting to False here made bsim stall with no
   // forward progress, since the generated `rule
   // rl_assert_resetsignal(!rst_rstsig_..._rst_sig)` fires whenever the
   // port reads False).
   Wire#(Bool) condWire <- mkDWire(True);
   Ifc_CSRSignal_reg0_field0 f <- mkCSRSignal_reg0_field0(0, condWire);

   method Action setResetCond(Bool cond);
      condWire <= cond;
   endmethod

   method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
      f.bus.write(data, wstrb);
   endmethod

   method Bit#(8) swRead;
      return f.currentValue;
   endmethod

   method Bit#(8) hwRead;
      return f.hw._read;
   endmethod
endmodule

module [BlueCheck] checkResetSignalLow ();
   RSSpec spec <- mkRSSpec();
   RSImp  imp  <- mkRSImp();

   equiv("setResetCond", spec.setResetCond, imp.setResetCond);
   equiv("swWrite", spec.swWrite, imp.swWrite);
   equiv("swRead", spec.swRead, imp.swRead);
   equiv("hwRead", spec.hwRead, imp.hwRead);
endmodule

module [Module] testResetSignalLow ();
   blueCheck(checkResetSignalLow);
endmodule
