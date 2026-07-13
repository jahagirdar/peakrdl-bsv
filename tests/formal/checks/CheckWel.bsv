// BlueCheck equivalence: BLIND reference (refs/Wel.bsv, package Wel, mkWel)
// vs REAL peakrdl-bsv generated RTL (wel/test_signal.bsv), config:
// sw=rw, hw=rw, wel=gate_sig (active-low hw write-enable), width=8.
// See CheckWe.bsv for the bridging rationale (gate bundled into a single
// hwWrite(data,wel) on the spec side vs continuous set_ext + hw._write
// on the imp side); hw.clear() intentionally not exercised here for the
// same reason (blind ref has no clear-related property to model).
import BlueCheck :: *;
import StmtFSM :: *;
import Wel_signal :: *;
import Wel :: *;

module [BlueCheck] checkWel ();
   Wel spec <- mkWel();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   equiv("swWrite", spec.swWrite, imp.bus.write);

   function Stmt hwWriteProp(Bit#(8) data, Bit#(1) gate) =
      seq
         action
            spec.hwWrite(data, gate == 1);
            imp.set_ext_top_gate_sig(gate);
            imp.hw._write(data);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("hwWrite_gated", hwWriteProp);

   function Stmt raceProp(Bit#(8) hwdata, Bit#(1) gate, Bit#(8) swdata, Bit#(8) swstrb) =
      seq
         action
            spec.hwWrite(hwdata, gate == 1);
            spec.swWrite(swdata, swstrb);
            imp.set_ext_top_gate_sig(gate);
            imp.hw._write(hwdata);
            imp.bus.write(swdata, swstrb);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("race_sw_precedence", raceProp);
endmodule

module [Module] testWel ();
   blueCheck(checkWel);
endmodule
