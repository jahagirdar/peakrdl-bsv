// BlueCheck equivalence: BLIND reference (HwNa.bsv, package HwNa,
// mkHwNa) vs REAL peakrdl-bsv generated RTL (HwNa_signal.bsv,
// mkCSRSignal_reg0_field0), config: sw=rw, hw=na (no onwrite/onread).
//
// Interface bridging note: the blind reference omits any hw-facing
// method entirely. The real generator's HW_reg0_field0 interface is
// NOT actually empty even for hw=na -- it still exposes the generic
// unconditional `method Action clear()` boilerplate present on every
// field regardless of any onclear/hwclr property (see
// print_bsv_signal.py: `method Action clear(); pw_clear.send();
// endmethod` is emitted with no guard). Consistent with the prior
// round's established convention (see we/CheckWe.bsv's closing note),
// this generic hw.clear() is left unexercised here since this config's
// RDL has no onclear/hwclr for the blind ref to model against.
import BlueCheck :: *;
import StmtFSM :: *;
import HwNa_signal :: *;
import HwNa :: *;

module [BlueCheck] checkHwNa ();
   HwNa spec <- mkHwNa();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   equiv("swWrite", spec.swWrite, imp.bus.write);

   function ActionValue#(Bit#(8)) specSwRead();
      actionvalue
         return spec.swRead;
      endactionvalue
   endfunction
   equiv("swRead", specSwRead, imp.bus.read);
   equiv("currentValue", spec.swRead, imp.currentValue);
endmodule

module [Module] testHwNa ();
   blueCheck(checkHwNa);
endmodule
