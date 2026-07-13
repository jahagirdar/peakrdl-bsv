// Thin wrapper around the BLIND reference Woset.bsv (mkWoset) that
// re-exposes it with the same method names/interface shape as the REAL
// generator's Ifc_CSRSignal_reg0_field0 (bus.write/bus.read/hw._read/
// currentValue), purely for Yosys SEC purposes -- no logic added.
import Woset :: *;

interface GoldWoset;
   method Action bus_write(Bit#(8) data, Bit#(8) wstrb);
   method ActionValue#(Bit#(8)) bus_read();
   method Bit#(8) hw_read();
   method Bit#(8) currentValue();
endinterface

(*synthesize*)
module mkGoldWoset(GoldWoset);
   Woset spec <- mkWoset();

   method Action bus_write(Bit#(8) data, Bit#(8) wstrb);
      spec.swWrite(data, wstrb);
   endmethod

   method ActionValue#(Bit#(8)) bus_read();
      actionvalue
         return spec.swRead;
      endactionvalue
   endmethod

   method Bit#(8) hw_read();
      return spec.hwRead;
   endmethod

   method Bit#(8) currentValue();
      return spec.swRead;
   endmethod
endmodule
