// BlueCheck equivalence: BLIND reference (refs2/ComboWeHwenable.bsv)
// vs REAL peakrdl-bsv generated RTL (top_signal.bsv, mkCSRSignal_reg0_field0),
// config: sw=rw, hw=rw, we=we_sig, hwenable=en_sig, width=8.
import BlueCheck :: *;
import StmtFSM :: *;
import ComboWeHwenable_signal :: *;
import ComboWeHwenable :: *;

module [BlueCheck] checkComboWeHwenable ();
   Wire#(Bit#(8)) enWire <- mkDWire(0);
   ComboWeHwenable spec <- mkComboWeHwenable(enWire);
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   equiv("swWrite", spec.swWrite, imp.bus.write);

   function Stmt hwWriteProp(Bit#(8) data, Bit#(1) we, Bit#(8) en) =
      seq
         action
            enWire <= en;
            imp.set_ext_top_en_sig(en);
            imp.set_ext_top_we_sig(we);
            spec.hwWrite(data, we == 1);
            imp.hw._write(data);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("hwWrite_we_hwenable", hwWriteProp);

   function Stmt raceProp(Bit#(8) hwdata, Bit#(1) we, Bit#(8) en, Bit#(8) swdata, Bit#(8) swstrb) =
      seq
         action
            enWire <= en;
            imp.set_ext_top_en_sig(en);
            imp.set_ext_top_we_sig(we);
            spec.hwWrite(hwdata, we == 1);
            spec.swWrite(swdata, swstrb);
            imp.hw._write(hwdata);
            imp.bus.write(swdata, swstrb);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("race_sw_precedence", raceProp);
endmodule

module [Module] testComboWeHwenable ();
   blueCheck(checkComboWeHwenable);
endmodule
