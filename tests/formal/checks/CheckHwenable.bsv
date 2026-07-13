// BlueCheck equivalence: BLIND reference (refs/Hwenable.bsv, package
// Hwenable, mkHwenable) vs REAL peakrdl-bsv generated RTL
// (hwenable/test_signal.bsv), config: sw=rw, hw=rw, hwenable=gate_sig[8]
// (per-bit hw write mask), width=8. Gate bundled into
// hwWrite(data,hwenable) on spec side vs continuous
// set_ext_top_gate_sig(Bit#(8)) + hw._write on imp side.
import BlueCheck :: *;
import StmtFSM :: *;
import Hwenable_signal :: *;
import Hwenable :: *;

module [BlueCheck] checkHwenable ();
   Hwenable spec <- mkHwenable();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   equiv("swWrite", spec.swWrite, imp.bus.write);

   function Stmt hwWriteProp(Bit#(8) data, Bit#(8) hwenable) =
      seq
         action
            spec.hwWrite(data, hwenable);
            imp.set_ext_top_gate_sig(hwenable);
            imp.hw._write(data);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("hwWrite_enabled", hwWriteProp);

   function Stmt raceProp(Bit#(8) hwdata, Bit#(8) hwenable, Bit#(8) swdata, Bit#(8) swstrb) =
      seq
         action
            spec.hwWrite(hwdata, hwenable);
            spec.swWrite(swdata, swstrb);
            imp.set_ext_top_gate_sig(hwenable);
            imp.hw._write(hwdata);
            imp.bus.write(swdata, swstrb);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("race_sw_precedence", raceProp);
endmodule

module [Module] testHwenable ();
   blueCheck(checkHwenable);
endmodule
