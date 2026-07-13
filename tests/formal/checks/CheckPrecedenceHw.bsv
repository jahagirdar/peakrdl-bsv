// NEW comparison harness. spec = blind reference PrecedenceHw
// (refs/PrecedenceHw.bsv, UNCHANGED). imp = real generator output for
// { sw=rw; hw=rw; precedence=hw; } field0[8], reused directly from
// yosys_eq/precedence_hw/test_signal.bsv (UNCHANGED). No adapter needed
// (method signatures already match); generator's hw.clear() left untested
// as in CheckPrecedenceSw.bsv (out of scope for this property).

import BlueCheck :: *;
import StmtFSM :: *;
import PrecedenceHw :: *;
import PrecedenceHw_signal :: *;

module [BlueCheck] checkPrecedenceHw ();
   PrecedenceHw spec <- mkPrecedenceHw();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   equiv("swWrite", spec.swWrite, imp.bus.write);
   equiv("hwWrite", spec.hwWrite, imp.hw._write);
   equiv("currentValue", spec.rd, imp.currentValue);

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

   prop("race_hw_wins", raceProp);
endmodule

module [Module] testPrecedenceHw ();
   blueCheck(checkPrecedenceHw);
endmodule
