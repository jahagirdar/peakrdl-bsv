// BlueCheck equivalence: BLIND reference (refs2/WriteOnce.bsv, package
// WriteOnce, mkWriteOnce) vs REAL peakrdl-bsv generated RTL
// (WriteOnce_signal.bsv, mkCSRSignal_reg0_field0), config: sw=w1
// (write-only, no once-only lockout modeled per spec instruction), hw=r,
// width=8 (WriteOnce.rdl in this dir).
//
// Neither side has a swRead method (sw=w1 -> sw_readable=False on the
// generator side; the blind ref likewise has no swRead). We compare via
// hwRead and currentValue instead, which both expose the stored value.
import BlueCheck :: *;
import StmtFSM :: *;
import WriteOnce_signal :: *;
import WriteOnce :: *;

module [BlueCheck] checkWriteOnce ();
   WriteOnce spec <- mkWriteOnce();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   equiv("swWrite", spec.swWrite, imp.bus.write);
   equiv("hwRead", spec.hwRead, imp.hw._read);
   equiv("currentValue", spec.hwRead, imp.currentValue);
endmodule

module [Module] testWriteOnce ();
   blueCheck(checkWriteOnce);
endmodule
