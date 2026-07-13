// BlueCheck equivalence: BLIND reference (refs2/ComboHwmaskPrecedenceSw.bsv)
// vs REAL peakrdl-bsv generated RTL (top_signal.bsv, mkCSRSignal_reg0_field0),
// config: sw=rw, hw=rw, precedence=sw (default), hwmask=mask_sig, width=8.
//
// The blind ref takes hwmask as a module constructor parameter (a plain
// Bit#(8) value) rather than a per-cycle method argument. We thread a
// live Wire into that parameter position so it can be varied per test
// vector exactly like the generator's own set_ext_top_mask_sig wire
// (both are mkDWire-style live nets, so there is no latency mismatch).
import BlueCheck :: *;
import StmtFSM :: *;
import ComboHwmaskPrecedenceSw_signal :: *;
import ComboHwmaskPrecedenceSw :: *;

module [BlueCheck] checkComboHwmaskPrecedenceSw ();
   Wire#(Bit#(8)) maskWire <- mkDWire(0);
   ComboHwmaskPrecedenceSw spec <- mkComboHwmaskPrecedenceSw(maskWire);
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   equiv("swWrite", spec.swWrite, imp.bus.write);

   function Stmt hwWriteProp(Bit#(8) data, Bit#(8) mask) =
      seq
         action
            maskWire <= mask;
            imp.set_ext_top_mask_sig(mask);
            spec.hwWrite(data);
            imp.hw._write(data);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("hwWrite_masked", hwWriteProp);

   function Stmt raceProp(Bit#(8) hwdata, Bit#(8) mask, Bit#(8) swdata, Bit#(8) swstrb) =
      seq
         action
            maskWire <= mask;
            imp.set_ext_top_mask_sig(mask);
            spec.hwWrite(hwdata);
            spec.swWrite(swdata, swstrb);
            imp.hw._write(hwdata);
            imp.bus.write(swdata, swstrb);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("race_sw_precedence", raceProp);
endmodule

module [Module] testComboHwmaskPrecedenceSw ();
   blueCheck(checkComboHwmaskPrecedenceSw);
endmodule
