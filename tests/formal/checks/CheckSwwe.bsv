// BlueCheck equivalence: BLIND reference (refs/Swwe.bsv, package Swwe,
// mkSwwe) vs REAL peakrdl-bsv generated RTL (swwe/test_signal.bsv),
// config: sw=rw, hw=rw, swwe=gate_sig (active-high sw write-enable),
// width=8. Gate bundled into swWrite(data,wstrb,swwe) on spec side vs
// continuous set_ext + bus.write on imp side (gate qualifies the sw
// branch of imp's arbitration rule, same wire used for both this and
// the hw._write path in We/Wel).
import BlueCheck :: *;
import StmtFSM :: *;
import Swwe_signal :: *;
import Swwe :: *;

module [BlueCheck] checkSwwe ();
   Swwe spec <- mkSwwe();
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

module [Module] testSwwe ();
   blueCheck(checkSwwe);
endmodule
