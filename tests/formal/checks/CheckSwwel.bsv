// BlueCheck equivalence: BLIND reference (refs/Swwel.bsv, package Swwel,
// mkSwwel) vs REAL peakrdl-bsv generated RTL (swwel/test_signal.bsv),
// config: sw=rw, hw=rw, swwel=gate_sig (active-low sw write-enable),
// width=8. See CheckSwwe.bsv for bridging rationale.
import BlueCheck :: *;
import StmtFSM :: *;
import Swwel_signal :: *;
import Swwel :: *;

module [BlueCheck] checkSwwel ();
   Swwel spec <- mkSwwel();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   equiv("hwWrite", spec.hwWrite, imp.hw._write);

   function Stmt swWriteProp(Bit#(8) data, Bit#(8) wstrb, Bit#(1) gate) =
      seq
         action
            spec.swWrite(data, wstrb, gate == 1);
            imp.set_ext_top_gate_sig(gate);
            imp.bus.write(data, wstrb);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("swWrite_gated", swWriteProp);

   function Stmt raceProp(Bit#(8) swdata, Bit#(8) swstrb, Bit#(1) gate, Bit#(8) hwdata) =
      seq
         action
            spec.swWrite(swdata, swstrb, gate == 1);
            spec.hwWrite(hwdata);
            imp.set_ext_top_gate_sig(gate);
            imp.bus.write(swdata, swstrb);
            imp.hw._write(hwdata);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("race_sw_precedence", raceProp);
endmodule

module [Module] testSwwel ();
   blueCheck(checkSwwel);
endmodule
