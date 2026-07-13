// NEW adapter file (not editing refs/Counter.bsv or the real
// generator). Wraps CounterRef (a pure rename of refs/Counter.bsv, see
// compare/counter/CheckCounter.bsv's header note on why the rename was
// necessary -- BSC's own library package `Counter` collides otherwise)
// behind an interface with the exact same shape as the real generator's
// Ifc_CSRSignal_reg0_field0 for this config (sw=r, hw=r, counter,
// incrsaturate -- see bluecheck/checks/Counter_signal.bsv), for Yosys
// SAT equivalence.
//
// Bridging: the blind ref's `rd` is a single plain value method serving
// both sw/hw read (sw=r means no separate swacc/swmod distinction is
// possible or needed). The real generator exposes bus.read()
// (ActionValue#(8), generic shape) and hw._read (plain value)
// separately. We wrap the pure value in an actionvalue block for
// bus.read() and pass it straight through for hw._read/currentValue --
// a type-level bridge only, no new logic. incr() maps directly
// (Action -> Action, no bridging needed).
//
// hw.clear(): counter.rdl has no onclear/hwclr property, and the blind
// reference correctly implements no clear support. As in the other two
// configs, hw.clear() is left as a no-op stub here and tied to constant
// 0 in the top-level wrapper, so it is never exercised on either side
// of the SAT proof.
import CounterRef :: *;

interface HW_reg0_field0;
   method Bit#(8) _read;
   method Action incr();
   method Action clear();
endinterface

interface SW_reg0_field0;
   method ActionValue#(Bit#(8)) read();
endinterface

interface Ifc_CSRSignal_reg0_field0;
   interface HW_reg0_field0 hw;
   interface SW_reg0_field0 bus;
   method Bit#(8) currentValue();
endinterface

module mkCSRSignal_reg0_field0#(Integer resetValue)(Ifc_CSRSignal_reg0_field0);
   CounterRef spec <- mkCounterRef();

   interface HW_reg0_field0 hw;
      method Bit#(8) _read;
         return spec.rd;
      endmethod
      method Action incr();
         spec.incr;
      endmethod
      method Action clear();
         noAction;
      endmethod
   endinterface

   interface SW_reg0_field0 bus;
      method ActionValue#(Bit#(8)) read();
         return spec.rd;
      endmethod
   endinterface

   method Bit#(8) currentValue();
      return spec.rd;
   endmethod
endmodule

(*synthesize*)
module testcsrreg_reg0_field0(Ifc_CSRSignal_reg0_field0);
   Ifc_CSRSignal_reg0_field0 ipaddress_r <- mkCSRSignal_reg0_field0('h0);
   return ipaddress_r;
endmodule
