// BlueCheck equivalence check for the "field0" field of the IntrRegister
// config: sw=rw woclr, hw=w, intr, enable=ext (enable/mask irrelevant to
// per-field storage logic, only to the register-level pending
// aggregate, so this check isolates just the field storage/precedence
// behavior).
//
// SCOPE GAP (migration disclosure): this harness only ever exercised
// field0 (the `enable`-qualified intr field) in the original audit --
// there is no corresponding CheckField1 for the `mask`-qualified second
// field, and no harness at all for the register-level interrupt-pending
// aggregate (the OR-of-qualified-fields output described in
// refs/IntrRegister.bsv's header comment). That is exactly what was
// migrated here: field1 and the pending aggregate remain UNVERIFIED by
// this suite. See tests/formal/README.md.
//
// spec  = blind reference (refs/IntrRegister.bsv), using only its
//         sw0Write/sw0Read/hw0Write methods (adapter: thin pass-through,
//         no logic change).
// imp   = real generator's field-level module mkCSRSignal_reg0_field0,
//         generated from rdl/IntrRegister.rdl.
//
// KNOWN FAILING TEST (confirmed real, not a migration artifact): this
// harness currently reproduces a genuine counter-example, both against
// freshly-generated RTL from rdl/IntrRegister.rdl AND against the
// original audit's pre-built `testField0` binary
// (compare/IntrRegister/testField0 in the source scratch tree) --
// confirming this is a real, pre-existing generator/spec discrepancy
// that was apparently never reported (no run.log was ever saved
// alongside that binary). Root cause, read directly out of the
// generated reg0_field0 write rule:
//   else if(hw_wdata.wget() matches tagged Valid .v) rr = r | (v);
// For an `intr` field, the generator's hw write is an OR-merge (hw sets
// pending bits, conventional interrupt-status-field semantics), NOT a
// plain unconditional replace. The blind reference (written from
// specs/field_property_semantics.md alone, before this generator was
// ever consulted) modeled hw=w's general "General field shape" default
// (unconditional replace) for hw0Write, since the spec text does not
// call out `intr` as changing hw's write semantics. Left RED
// intentionally -- see tests/formal/README.md's "Known failing test"
// section.

import BlueCheck :: *;
import StmtFSM :: *;
import IntrRegister :: *;
import IntrRegister_signal :: *;

interface F0Spec;
   method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
   method ActionValue#(Bit#(8)) swRead;
   method Action hwWrite(Bit#(8) data);
   method Bit#(8) currentValue;
endinterface

module mkF0Spec(F0Spec);
   IntrRegister full <- mkIntrRegister();

   method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
      full.sw0Write(data, wstrb);
   endmethod

   method ActionValue#(Bit#(8)) swRead;
      let v = full.sw0Read;
      return v;
   endmethod

   method Action hwWrite(Bit#(8) data);
      full.hw0Write(data);
   endmethod

   method Bit#(8) currentValue;
      return full.sw0Read;
   endmethod
endmodule

interface F0Imp;
   method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
   method ActionValue#(Bit#(8)) swRead;
   method Action hwWrite(Bit#(8) data);
   method Bit#(8) currentValue;
endinterface

module mkF0Imp(F0Imp);
   Ifc_CSRSignal_reg0_field0 f <- mkCSRSignal_reg0_field0(0);

   method Action swWrite(Bit#(8) data, Bit#(8) wstrb);
      f.bus.write(data, wstrb);
   endmethod

   method ActionValue#(Bit#(8)) swRead;
      let v <- f.bus.read;
      return v;
   endmethod

   method Action hwWrite(Bit#(8) data);
      f.hw._write(data);
   endmethod

   method Bit#(8) currentValue;
      return f.currentValue;
   endmethod
endmodule

module [BlueCheck] checkIntrRegister ();
   F0Spec spec <- mkF0Spec();
   F0Imp  imp  <- mkF0Imp();

   equiv("swWrite", spec.swWrite, imp.swWrite);
   equiv("swRead", spec.swRead, imp.swRead);
   equiv("hwWrite", spec.hwWrite, imp.hwWrite);
   equiv("currentValue", spec.currentValue, imp.currentValue);
endmodule

module [Module] testIntrRegister ();
   blueCheck(checkIntrRegister);
endmodule
