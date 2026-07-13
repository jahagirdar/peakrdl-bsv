// BlueCheck equivalence: BLIND reference (refs2/SwmodDefault.bsv,
// package SwmodDefault, mkSwmodDefault) vs REAL peakrdl-bsv generated
// RTL (SwmodDefault_signal.bsv, mkCSRSignal_reg0_f), config: sw=rw,
// hw=r, swmod, default onwrite (masked merge), width=8.
//
// PulseWire scheduling note (see CheckSwacc.bsv for the full repro):
// BSC forbids composing a method that calls PulseWire.send() together
// with a method reading the same PulseWire in a single atomic action,
// even across a module boundary. Worked around here the same way: a
// background monitor rule samples each side's swmod pulse into a
// register every cycle, and the FSM step reads the PREVIOUS cycle's
// sampled value one action later.
import BlueCheck :: *;
import StmtFSM :: *;
import SwmodDefault_signal :: *;
import SwmodDefault :: *;

module [BlueCheck] checkSwmodDefault ();
   SwmodDefault spec <- mkSwmodDefault();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Reg#(Bool) specSwmodSeen <- mkRegU;
   Reg#(Bool) impSwmodSeen  <- mkRegU;
   rule sampleSwmod;
      specSwmodSeen <= spec.swmodPulse;
      impSwmodSeen  <= imp.hw.swmod;
   endrule

   Ensure ensure <- getEnsure;

   function Stmt writeProp(Bit#(8) data, Bit#(8) wstrb) =
      seq
         action
            spec.swWrite(data, wstrb);
            imp.bus.write(data, wstrb);
         endaction
         action
            Bool ok = (specSwmodSeen == impSwmodSeen)
                   && (spec.hwRead == imp.currentValue);
            ensure(ok);
         endaction
      endseq;
   prop("swWrite_and_swmod", writeProp);

endmodule

module [Module] testSwmodDefault ();
   blueCheck(checkSwmodDefault);
endmodule
