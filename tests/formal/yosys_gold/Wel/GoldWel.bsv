// NEW adapter (see yosys/we/GoldWe.bsv for full rationale). Same shape
// as We's adapter; wel's own active-low semantics live entirely inside
// refs/Wel.bsv (mkWel), unchanged here. hw.clear() left as a no-op stub,
// tied off externally by the wrap_*.v harness (this config's RDL has no
// onclear/hwclr property, matching what the blind ref implements).
import Wel :: *;

interface HW_reg0_field0;
   method Action _write(Bit#(8) data);
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
   method Action set_ext_topmap_gate_sig(Bit#(1) v);
endinterface

module mkCSRSignal_reg0_field0#(Integer resetValue)(Ifc_CSRSignal_reg0_field0);
   Wel spec <- mkWel();

   Wire#(Bit#(1))   w_gate <- mkDWire(0);
   RWire#(Bit#(8))  hwReq  <- mkRWire;

   rule doHw;
      if (hwReq.wget matches tagged Valid .d)
         spec.hwWrite(d, w_gate == 1);
   endrule

   interface HW_reg0_field0 hw;
      method Action _write(Bit#(8) data);
         hwReq.wset(data);
      endmethod
      method Bit#(8) _read;
         return spec.rd;
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
         return spec.rd;
      endmethod
   endinterface

   method Bit#(8) currentValue();
      return spec.rd;
   endmethod

   method Action set_ext_topmap_gate_sig(Bit#(1) v);
      w_gate <= v;
   endmethod
endmodule

(*synthesize*)
module testcsrreg_reg0_field0(Ifc_CSRSignal_reg0_field0);
   Ifc_CSRSignal_reg0_field0 ipaddress_r <- mkCSRSignal_reg0_field0('h0);
   return ipaddress_r;
endmodule
