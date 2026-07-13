// Thin wrapper around the BLIND reference SwmodWoclr.bsv (mkSwmodWoclr)
// that re-exposes it with the same method names/interface shape as the
// REAL generator's Ifc_CSRSignal_reg0_field0 for sw=rw, hw=r, onwrite=
// woclr, swmod: bus_write/bus_read/hw._read/hw.swmod()/currentValue.
import SwmodWoclr :: *;

interface GoldSwmodWoclr;
   method Action bus_write(Bit#(8) data, Bit#(8) wstrb);
   method ActionValue#(Bit#(8)) bus_read();
   method Bit#(8) hw_read();
   method Bool hw_swmod();
   method Bit#(8) currentValue();
endinterface

(*synthesize*)
module mkGoldSwmodWoclr(GoldSwmodWoclr);
   SwmodWoclr spec <- mkSwmodWoclr();

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

   method Bool hw_swmod();
      return spec.swmodPulse;
   endmethod

   method Bit#(8) currentValue();
      return spec.swRead;
   endmethod
endmodule
