// Gold wrapper for the Yosys SEC check of the IntrHalt config's field
// storage. Imports the ALREADY-migrated blind reference
// refs/IntrHalt.bsv (unmodified) and re-exposes only its per-field
// storage methods (swWrite/hwWrite/rd) so they line up 1:1 with the
// gate side's testcsrreg_reg0_field0. The haltenable module parameter
// (a continuously-driven external qualifier that affects only the
// register-level halt aggregate, not per-field storage) is tied to 0
// here since the field-level gate top exposes no halt aggregate.
//
// EXPECTED-FAILING (see tests/formal_yosys_test.py KNOWN_FAILING and
// tests/formal/README.md): same intr-OR-merge discrepancy as
// IntrRegister -- the generator OR-merges hw writes for an intr field
// (rr = r | v) while this blind reference models plain replace.
package GoldIntrHalt;
import IntrHalt::*;

interface GoldIntrHalt;
   method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
   method Action hwWrite(Bit#(8) data);
   method Bit#(8) rd;
endinterface

module mkGoldIntrHalt(GoldIntrHalt);
   IntrHalt full <- mkIntrHalt(0);
   method Action swWrite(Bit#(8) data, Bit#(8) wstrb); full.swWrite(data, wstrb); endmethod
   method Action hwWrite(Bit#(8) data); full.hwWrite(data); endmethod
   method Bit#(8) rd; return full.rd; endmethod
endmodule
endpackage
