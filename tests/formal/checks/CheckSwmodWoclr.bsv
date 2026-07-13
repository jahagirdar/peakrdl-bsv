// BlueCheck equivalence: BLIND reference (refs2/SwmodWoclr.bsv, package
// SwmodWoclr, mkSwmodWoclr) vs REAL peakrdl-bsv generated RTL
// (SwmodWoclr_signal.bsv, mkCSRSignal_reg0_field0), config: sw=rw, hw=r,
// onwrite=woclr, swmod, width=8 (SwmodWoclr.rdl in this dir).
//
// swmod on the generator side is a level method hw.swmod() (returns the
// live pw_swmod PulseWire value); on the blind ref it's swmodPulse().
// Both are one-cycle PulseWire-backed outputs. Reading a PulseWire in
// the very same monolithic action that (conditionally) sends it -- as
// BlueCheck's FSM-generated `action...endaction` blocks do, since all
// statements in one `action` execute in parallel/same-cycle with no
// fixed order -- produced a real bsc scheduling error (G0004, "conflict
// in parallel" between .wset() and .whas() of the same PulseWire) when
// tried directly. The standard, well-supported PulseWire idiom instead
// has a SEPARATE always-firing rule read the pulse (a cross-rule
// send-then-read composition, which bsc schedules fine) and latch it
// into a plain Reg the same cycle; the FSM's `prop` then compares the
// two *registered* latches one cycle later, alongside the (already
// registered) currentValue comparison.
import BlueCheck :: *;
import StmtFSM :: *;
import SwmodWoclr_signal :: *;
import SwmodWoclr :: *;

module [BlueCheck] checkSwmodWoclr ();
   SwmodWoclr spec <- mkSwmodWoclr();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   function ActionValue#(Bit#(8)) specSwRead();
      actionvalue
         return spec.swRead;
      endactionvalue
   endfunction

   equiv("swRead", specSwRead, imp.bus.read);
   equiv("hwRead", spec.hwRead, imp.hw._read);
   equiv("currentValue", spec.swRead, imp.currentValue);

   Reg#(Bool) specModLatch <- mkRegU;
   Reg#(Bool) impModLatch  <- mkRegU;
   rule captureMod;
      specModLatch <= spec.swmodPulse;
      impModLatch  <= imp.hw.swmod;
   endrule

   function Stmt writeProp(Bit#(8) data, Bit#(8) wstrb) =
      seq
         action
            spec.swWrite(data, wstrb);
            imp.bus.write(data, wstrb);
         endaction
         ensure(spec.swRead == imp.currentValue);
         ensure(specModLatch == impModLatch);
      endseq;
   prop("swWrite_and_swmod", writeProp);
endmodule

module [Module] testSwmodWoclr ();
   blueCheck(checkSwmodWoclr);
endmodule
