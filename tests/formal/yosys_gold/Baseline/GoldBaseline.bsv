// NEW adapter file (not editing refs/Baseline.bsv or the real
// generator). Wraps the blind reference `Baseline` (refs/Baseline.bsv)
// behind an interface with the exact same shape/method-names as the
// real generator's Ifc_CSRSignal_reg0_field0 for this config (see
// yosys_eq/baseline/test_signal.bsv: sw=rw, hw=r, no we/onwrite/onread
// properties), so that `bsc -verilog` produces a module with an
// identical port list/names to the generator's compiled
// testcsrreg_reg0_field0.v, for Yosys SAT equivalence.
//
// Bridging: the blind ref's swRead/hwRead are plain value methods; the
// real generator's bus.read() is an ActionValue#(Bit#(8)) (generic
// shape shared across all configs, even though this config's generated
// code has no actual read side effect). We wrap the pure value in an
// actionvalue block -- a type-level bridge only, no new logic.
//
// hw.clear(): this config's RDL has no onclear/hwclr property, and the
// blind reference correctly implements no clear support (nothing in the
// spec to model). The real generator still exposes a generic hw.clear()
// as universal boilerplate that unconditionally zeros the storage
// register. Since the blind reference's Reg is fully encapsulated with
// no external force-clear path, we leave hw.clear() as a no-op stub
// here (matching the We/Wel/etc. precedent) and tie EN_hw_clear=0 in
// the top-level wrapper used for the SAT proof, so it is never
// exercised on either side.
import Baseline :: *;

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
   Baseline spec <- mkBaseline();

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
