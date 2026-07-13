// NEW adapter (see yosys/swwe/GoldSwwe.bsv for rationale; swwel is the
// active-low counterpart, polarity handled entirely inside refs/Swwel.bsv).
import Swwel :: *;

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
   Swwel spec <- mkSwwel();

   Wire#(Bit#(1))          w_gate <- mkDWire(0);
   RWire#(Tuple2#(Bit#(8), Bit#(8))) swReq <- mkRWire;

   rule doSw;
      if (swReq.wget matches tagged Valid {.d, .wstrb})
         spec.swWrite(d, wstrb, w_gate == 1);
   endrule

   interface HW_reg0_field0 hw;
      method Action _write(Bit#(8) data);
         spec.hwWrite(data);
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
         swReq.wset(tuple2(data, wstrb));
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
