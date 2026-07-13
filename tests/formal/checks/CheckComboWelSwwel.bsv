// BlueCheck equivalence: BLIND reference (refs2/ComboWelSwwel.bsv)
// vs REAL peakrdl-bsv generated RTL (top_signal.bsv, mkCSRSignal_reg0_field0),
// config: sw=rw, hw=rw, wel=wel_sig, swwel=swwel_sig, width=8.
import BlueCheck :: *;
import StmtFSM :: *;
import ComboWelSwwel_signal :: *;
import ComboWelSwwel :: *;

module [BlueCheck] checkComboWelSwwel ();
   ComboWelSwwel spec <- mkComboWelSwwel();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   function Stmt swWriteProp(Bit#(8) data, Bit#(8) wstrb, Bit#(1) swwel) =
      seq
         action
            spec.swWrite(data, wstrb, swwel == 1);
            imp.set_ext_top_swwel_sig(swwel);
            imp.bus.write(data, wstrb);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("swWrite_gated_swwel", swWriteProp);

   function Stmt hwWriteProp(Bit#(8) data, Bit#(1) wel) =
      seq
         action
            imp.set_ext_top_wel_sig(wel);
            spec.hwWrite(data, wel == 1);
            imp.hw._write(data);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("hwWrite_gated_wel", hwWriteProp);

   function Stmt raceProp(Bit#(8) hwdata, Bit#(1) wel, Bit#(8) swdata, Bit#(8) swstrb, Bit#(1) swwel) =
      seq
         action
            imp.set_ext_top_wel_sig(wel);
            imp.set_ext_top_swwel_sig(swwel);
            spec.hwWrite(hwdata, wel == 1);
            spec.swWrite(swdata, swstrb, swwel == 1);
            imp.hw._write(hwdata);
            imp.bus.write(swdata, swstrb);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("race_sw_precedence", raceProp);
endmodule

module [Module] testComboWelSwwel ();
   blueCheck(checkComboWelSwwel);
endmodule
