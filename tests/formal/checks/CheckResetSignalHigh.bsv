// BlueCheck equivalence check for ResetSignalHigh (activehigh resetsignal,
// sw=rw, hw=r, width=8).
// spec = blind reference refs/ResetSignalHigh.bsv (unmodified).
// imp  = real generator's mkCSRSignal_reg0_field0, reused from
//        yosys_eq/resetsignal (activehigh RDL, matches blind assumption).
//        The generator threads the resetsignal condition down as a
//        Bool module "parameter" that is actually a continuously-wired
//        RTL input (a common BSV idiom distinct from Integer/numeric-type
//        params, which really are elaboration-time constants) -- so we
//        reproduce the same top-level DWire-driven wrapper the real
//        generator's CSR level uses, purely as wiring, no logic change.

import BlueCheck :: *;
import StmtFSM :: *;
import ResetSignalHigh :: *;
import ResetSignalHigh_signal :: *;

interface RSSpec;
   method Action setResetCond(Bool cond);
   method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
   method Bit#(8) swRead;
   method Bit#(8) hwRead;
endinterface

module mkRSSpec(RSSpec);
   ResetSignalHigh s <- mkResetSignalHigh();

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
   Wire#(Bool) condWire <- mkDWire(False);
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

module [BlueCheck] checkResetSignalHigh ();
   RSSpec spec <- mkRSSpec();
   RSImp  imp  <- mkRSImp();

   equiv("setResetCond", spec.setResetCond, imp.setResetCond);
   equiv("swWrite", spec.swWrite, imp.swWrite);
   equiv("swRead", spec.swRead, imp.swRead);
   equiv("hwRead", spec.hwRead, imp.hwRead);
endmodule

module [Module] testResetSignalHigh ();
   blueCheck(checkResetSignalHigh);
endmodule
