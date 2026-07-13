// NEW comparison harness. spec = blind reference Stickybit
// (refs/Stickybit.bsv, UNCHANGED). imp = real generator output for
// { sw=rw; hw=rw; stickybit; } field0[8], reused directly from
// yosys_eq/stickybit/test_signal.bsv (UNCHANGED). No adapter needed.
// hw.clear() left untested (out of scope, no hwclr on this RDL).

import BlueCheck :: *;
import StmtFSM :: *;
import Stickybit :: *;
import Stickybit_signal :: *;

module [BlueCheck] checkStickybit ();
   Stickybit spec <- mkStickybit();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   equiv("swWrite", spec.swWrite, imp.bus.write);
   equiv("hwWrite_single", spec.hwWrite, imp.hw._write);
   equiv("currentValue", spec.rd, imp.currentValue);

   // Sequence of solo hw writes (per-bit OR-in / sticky-1 behavior).
   function Stmt hwSeqProp(Bit#(8) d1, Bit#(8) d2, Bit#(8) d3) =
      seq
         action spec.hwWrite(d1); imp.hw._write(d1); endaction
         ensure(spec.rd == imp.currentValue);
         action spec.hwWrite(d2); imp.hw._write(d2); endaction
         ensure(spec.rd == imp.currentValue);
         action spec.hwWrite(d3); imp.hw._write(d3); endaction
         ensure(spec.rd == imp.currentValue);
      endseq;

   prop("hw_orsIn_bits_stick", hwSeqProp);

   // sw can clear sticky bits back to 0.
   function Stmt swThenHwProp(Bit#(8) sd, Bit#(8) sstrb, Bit#(8) hd) =
      seq
         action
            spec.swWrite(sd, sstrb);
            imp.bus.write(sd, sstrb);
         endaction
         action spec.hwWrite(hd); imp.hw._write(hd); endaction
         ensure(spec.rd == imp.currentValue);
      endseq;

   prop("sw_write_then_hw_write", swThenHwProp);

   // True same-cycle race, from an arbitrary prior state.
   function Stmt raceProp(Bit#(8) d0, Bit#(8) swdata, Bit#(8) swstrb, Bit#(8) hwdata) =
      seq
         action spec.hwWrite(d0); imp.hw._write(d0); endaction
         action
            spec.swWrite(swdata, swstrb);
            spec.hwWrite(hwdata);
            imp.bus.write(swdata, swstrb);
            imp.hw._write(hwdata);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;

   prop("race_sw_wins", raceProp);
endmodule

module [Module] testStickybit ();
   blueCheck(checkStickybit);
endmodule
