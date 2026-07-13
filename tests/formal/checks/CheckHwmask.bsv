// BlueCheck equivalence: BLIND reference (refs/Hwmask.bsv, package
// Hwmask, mkHwmask) vs REAL peakrdl-bsv generated RTL
// (hwmask/test_signal.bsv), config: sw=rw, hw=rw, hwmask=gate_sig[8]
// (per-bit hw write exclusion mask), width=8. See CheckHwenable.bsv for
// bridging rationale.
import BlueCheck :: *;
import StmtFSM :: *;
import Hwmask_signal :: *;
import Hwmask :: *;

module [BlueCheck] checkHwmask ();
   Hwmask spec <- mkHwmask();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   equiv("swWrite", spec.swWrite, imp.bus.write);

   function Stmt hwWriteProp(Bit#(8) data, Bit#(8) hwmask) =
      seq
         action
            spec.hwWrite(data, hwmask);
            imp.set_ext_top_gate_sig(hwmask);
            imp.hw._write(data);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("hwWrite_masked", hwWriteProp);

   function Stmt raceProp(Bit#(8) hwdata, Bit#(8) hwmask, Bit#(8) swdata, Bit#(8) swstrb) =
      seq
         action
            spec.hwWrite(hwdata, hwmask);
            spec.swWrite(swdata, swstrb);
            imp.set_ext_top_gate_sig(hwmask);
            imp.hw._write(hwdata);
            imp.bus.write(swdata, swstrb);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("race_sw_precedence", raceProp);
endmodule

module [Module] testHwmask ();
   blueCheck(checkHwmask);
endmodule
