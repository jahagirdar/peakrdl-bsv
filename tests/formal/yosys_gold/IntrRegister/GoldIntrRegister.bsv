// Gold wrapper for the Yosys SEC check of the IntrRegister config's
// field0 storage. Imports the ALREADY-migrated blind reference
// refs/IntrRegister.bsv (unmodified -- never a second copy of its
// logic) and re-exposes ONLY field0's per-field storage methods
// (sw0Write/hw0Write/sw0Read) under generic swWrite/hwWrite/rd names,
// mirroring the BlueCheck-side CheckIntrRegister.bsv's mkF0Spec adapter.
// This isolates the same single-field storage behavior that the gate
// side's testcsrreg_reg0_field0 implements, so the two can be compared
// 1:1 by Yosys.
//
// EXPECTED-FAILING (see tests/formal_yosys_test.py KNOWN_FAILING and
// tests/formal/README.md): for an `intr` field the generator's hw write
// is an OR-merge (rr = r | v), while this blind reference models the
// general hw=w default (plain unconditional replace). Yosys SEC
// therefore reports the two field-storage sides as inequivalent -- the
// exact same discrepancy the BlueCheck side xfails.
package GoldIntrRegister;
import IntrRegister::*;

interface GoldIntrRegister;
   method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
   method Action hwWrite(Bit#(8) data);
   method Bit#(8) rd;
endinterface

module mkGoldIntrRegister(GoldIntrRegister);
   IntrRegister full <- mkIntrRegister();
   method Action swWrite(Bit#(8) data, Bit#(8) wstrb); full.sw0Write(data, wstrb); endmethod
   method Action hwWrite(Bit#(8) data); full.hw0Write(data); endmethod
   method Bit#(8) rd; return full.sw0Read; endmethod
endmodule
endpackage
