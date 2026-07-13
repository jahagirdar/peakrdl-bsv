// Thin wrapper around the BLIND reference WriteOnce.bsv (mkWriteOnce)
// that re-exposes it with the same method names/interface shape as the
// REAL generator's Ifc_CSRSignal_reg0_field0 for sw=w1 (no bus.read
// method, since sw_readable=False): bus_write/hw._read/currentValue.
import WriteOnce :: *;

interface GoldWriteOnce;
   method Action bus_write(Bit#(8) data, Bit#(8) wstrb);
   method Bit#(8) hw_read();
   method Bit#(8) currentValue();
endinterface

(*synthesize*)
module mkGoldWriteOnce(GoldWriteOnce);
   WriteOnce spec <- mkWriteOnce();

   method Action bus_write(Bit#(8) data, Bit#(8) wstrb);
      spec.swWrite(data, wstrb);
   endmethod

   method Bit#(8) hw_read();
      return spec.hwRead;
   endmethod

   method Bit#(8) currentValue();
      return spec.hwRead;
   endmethod
endmodule
