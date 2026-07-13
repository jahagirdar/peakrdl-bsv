// BlueCheck equivalence: BLIND reference (refs2/ComboSwweWoclr.bsv)
// vs REAL peakrdl-bsv generated RTL (top_signal.bsv, mkCSRSignal_reg0_field0),
// config: sw=rw, hw=r, onwrite=woclr, swwe=swwe_sig, width=8.
// Ref bundles swwe as an argument to swWrite; generator exposes it as a
// continuously-driven wire (set_ext_top_swwe_sig). Sequence both sides'
// calls together per vector, like We.bsv's we-gated hwWrite comparison.
import BlueCheck :: *;
import StmtFSM :: *;
import ComboSwweWoclr_signal :: *;
import ComboSwweWoclr :: *;

module [BlueCheck] checkComboSwweWoclr ();
   ComboSwweWoclr spec <- mkComboSwweWoclr();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   function Stmt swWriteProp(Bit#(8) data, Bit#(8) wstrb, Bit#(1) swwe) =
      seq
         action
            spec.swWrite(data, wstrb, swwe == 1);
            imp.set_ext_top_swwe_sig(swwe);
            imp.bus.write(data, wstrb);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("swWrite_gated_woclr", swWriteProp);
endmodule

module [Module] testComboSwweWoclr ();
   blueCheck(checkComboSwweWoclr);
endmodule
