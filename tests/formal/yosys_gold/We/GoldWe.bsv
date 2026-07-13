// NEW adapter file (not editing refs/We.bsv or the real generator).
// Wraps the blind reference `We` (refs/We.bsv) behind an interface with
// the exact same shape/method-names as the real generator's
// Ifc_CSRSignal_reg0_field0 (see yosys_eq/we/test_signal.bsv), so that
// `bsc -verilog` produces a module with an identical port list/names to
// the generator's compiled testcsrreg_reg0_field0.v, for Yosys SAT
// equivalence.
//
// Bridging: the blind ref bundles `we` into hwWrite(data,we) as a single
// atomic call. The real generator instead has two independent
// continuously-fireable methods: hw._write(data) (RWire-backed, only
// "genuine" the cycle it's called) and set_ext_topmap_gate_sig(v)
// (mkDWire-backed, default 0 every cycle unless re-driven). We reproduce
// that exact two-input/one-internal-rule shape here with our own DWire
// + RWire + rule, then forward the combined (data, we) into the spec's
// single hwWrite call the same cycle -- this exactly matches the timing
// discipline the real generator itself uses (DWire sampled combinationally
// against the RWire in one rule), so cycle alignment matches by
// construction, not by coincidence.
//
// hw.clear(): the We config's RDL has no onclear/hwclr property, and the
// blind reference correctly implements no clear support at all (nothing
// in the spec to model). The real generator still exposes a generic
// hw.clear() as universal boilerplate (print_bsv_reg.py always emits
// it). Since the blind ref's internal Reg is fully encapsulated inside
// `We` with no way to force it externally, and modeling a fake clear
// here would mean inventing NEW logic instead of adapting, we leave
// hw.clear() as a no-op stub on the gold side. It is intentionally tied
// to constant 0 (never asserted) on BOTH the gold and gate side by the
// wrapper harness (WeTop.bsv) used for the equivalence run, so this
// stub is never exercised and does not affect the SAT proof.
import We :: *;

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
   We spec <- mkWe();

   Wire#(Bit#(1))   w_we  <- mkDWire(0);
   RWire#(Bit#(8))  hwReq <- mkRWire;

   rule doHw;
      if (hwReq.wget matches tagged Valid .d)
         spec.hwWrite(d, w_we == 1);
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
      w_we <= v;
   endmethod
endmodule

(*synthesize*)
module testcsrreg_reg0_field0(Ifc_CSRSignal_reg0_field0);
   Ifc_CSRSignal_reg0_field0 ipaddress_r <- mkCSRSignal_reg0_field0('h0);
   return ipaddress_r;
endmodule
