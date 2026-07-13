// BlueCheck equivalence: BLIND reference (refs2/Swacc.bsv, package
// Swacc, mkSwacc) vs REAL peakrdl-bsv generated RTL (Swacc_signal.bsv,
// mkCSRSignal_reg0_f), config: sw=rw, hw=r, swacc, default onwrite
// (masked merge), width=8.
//
// PulseWire scheduling note: BSC forbids composing a method that
// internally calls PulseWire.send() together with a method that reads
// that same PulseWire (even across a module boundary) inside one
// atomic action -- confirmed via a minimal standalone repro (calling an
// Action method containing pw.send() alongside a Value method reading
// pw, from an external caller, in the same rule: BSC error G0004,
// "uses methods that conflict in parallel"). So we cannot directly
// write `imp.bus.write(...); ensure(pack(imp.hw.swacc) == ...)` in one
// action. Instead we add two small always-firing monitor rules that
// sample each side's swacc pulse output into a register every cycle;
// the FSM step that issues the write/read only reads the PREVIOUS
// cycle's sampled value (one action step later), which is legal since
// the monitor rule and the FSM step are separate scheduled rules (BSC
// can order them SB) rather than one composed atomic action.
import BlueCheck :: *;
import StmtFSM :: *;
import Swacc_signal :: *;
import Swacc :: *;

module [BlueCheck] checkSwacc ();
   Swacc spec <- mkSwacc();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Reg#(Bool) specSwaccSeen <- mkRegU;
   Reg#(Bool) impSwaccSeen  <- mkRegU;
   rule sampleSwacc;
      specSwaccSeen <= spec.swaccPulse;
      impSwaccSeen  <= imp.hw.swacc;
   endrule

   Ensure ensure <- getEnsure;

   // Write path: issue the write, then (one action/cycle later) check
   // both the swacc pulse that fired during the write cycle and the
   // storage value that settled afterward.
   function Stmt writeProp(Bit#(8) data, Bit#(8) wstrb) =
      seq
         action
            spec.swWrite(data, wstrb);
            imp.bus.write(data, wstrb);
         endaction
         action
            Bool ok = (specSwaccSeen == impSwaccSeen)
                   && (spec.hwRead == imp.currentValue);
            ensure(ok);
         endaction
      endseq;
   prop("swWrite_and_swacc", writeProp);

   // Read path: check swacc pulse fires on a genuine read too.
   function Stmt readProp() =
      seq
         action
            let sv <- spec.swRead;
            let iv <- imp.bus.read;
            ensure(sv == iv);
         endaction
         action
            ensure(specSwaccSeen == impSwaccSeen);
         endaction
      endseq;
   prop("swRead_and_swacc", readProp);

endmodule

module [Module] testSwacc ();
   blueCheck(checkSwacc);
endmodule
