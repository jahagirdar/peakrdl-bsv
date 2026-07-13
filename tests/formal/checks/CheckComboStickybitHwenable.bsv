// BlueCheck equivalence: BLIND reference (refs2/ComboStickybitHwenable.bsv)
// vs REAL peakrdl-bsv generated RTL (top_signal.bsv, mkCSRSignal_reg0_field0),
// config: sw=rw, hw=rw, stickybit, hwenable=en_sig, width=8.
import BlueCheck :: *;
import StmtFSM :: *;
import ComboStickybitHwenable_signal :: *;
import ComboStickybitHwenable :: *;

module [BlueCheck] checkComboStickybitHwenable ();
   Wire#(Bit#(8)) enWire <- mkDWire(0);
   ComboStickybitHwenable spec <- mkComboStickybitHwenable(enWire);
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   equiv("swWrite", spec.swWrite, imp.bus.write);

   function Stmt hwWriteProp(Bit#(8) data, Bit#(8) en) =
      seq
         action
            enWire <= en;
            imp.set_ext_top_en_sig(en);
            spec.hwWrite(data);
            imp.hw._write(data);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("hwWrite_stickybit_enabled", hwWriteProp);

   function Stmt raceProp(Bit#(8) hwdata, Bit#(8) en, Bit#(8) swdata, Bit#(8) swstrb) =
      seq
         action
            enWire <= en;
            imp.set_ext_top_en_sig(en);
            spec.hwWrite(hwdata);
            spec.swWrite(swdata, swstrb);
            imp.hw._write(hwdata);
            imp.bus.write(swdata, swstrb);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("race_sw_precedence", raceProp);
endmodule

module [Module] testComboStickybitHwenable ();
   blueCheck(checkComboStickybitHwenable);
endmodule
