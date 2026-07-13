// NEW adapter file (not editing refs/Woclr.bsv or the real generator).
// Same rationale/pattern as yosys/baseline/GoldBaseline.bsv: wraps the
// blind reference `Woclr` (refs/Woclr.bsv) behind an interface with the
// exact same shape as the real generator's Ifc_CSRSignal_reg0_field0
// for this config (sw=rw, hw=r, onwrite=woclr -- see
// yosys_eq/woclr/test_signal.bsv), for Yosys SAT equivalence. Bridging
// is a pure type-level wrap of the value-method swRead into
// ActionValue#(Bit#(8)) to match bus.read()'s generic shape; no new
// logic. hw.clear() is left as a no-op stub for the same reason as the
// Baseline case (no onclear/hwclr configured on this field; onwrite and
// onclear are distinct properties), tied to constant 0 in the top-level
// wrapper.
import Woclr :: *;

interface HW_reg0_field0;
   method Bit#(8) _read;
   method Action clear();
endinterface

interface SW_reg0_field0;
   method Action write(Bit#(8) data, Bit#(8) wstrb);
   method ActionValue#(Bit#(8)) read();
endinterface

interface Ifc_CSRSignal_reg0_field0;
   interface HW_reg0_field0 hw;
   interface SW_reg0_field0 bus;
   method Bit#(8) currentValue();
endinterface

module mkCSRSignal_reg0_field0#(Integer resetValue)(Ifc_CSRSignal_reg0_field0);
   Woclr spec <- mkWoclr();

   interface HW_reg0_field0 hw;
      method Bit#(8) _read;
         return spec.hwRead;
      endmethod
      method Action clear();
         noAction;
      endmethod
   endinterface

   interface SW_reg0_field0 bus;
      method Action write(Bit#(8) data, Bit#(8) wstrb);
         spec.swWrite(data, wstrb);
      endmethod
      method ActionValue#(Bit#(8)) read();
         return spec.swRead;
      endmethod
   endinterface

   method Bit#(8) currentValue();
      return spec.swRead;
   endmethod
endmodule

(*synthesize*)
module testcsrreg_reg0_field0(Ifc_CSRSignal_reg0_field0);
   Ifc_CSRSignal_reg0_field0 ipaddress_r <- mkCSRSignal_reg0_field0('h0);
   return ipaddress_r;
endmodule
