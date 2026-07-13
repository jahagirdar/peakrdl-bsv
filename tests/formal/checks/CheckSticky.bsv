// NEW comparison harness. spec = blind reference Sticky (refs/Sticky.bsv,
// UNCHANGED). imp = real generator output for
// { sw=rw; hw=rw; sticky; } field0[8], reused directly from
// yosys_eq/sticky/test_signal.bsv (UNCHANGED). No adapter needed. Extra
// generator method hw.clear() left untested (out of scope: no hwclr
// property on this RDL).
//
// Special focus: the sticky freeze test must use the register's
// start-of-cycle value (r), not any value computed later in the same
// cycle. hwSeqProp below issues a sequence of solo hw writes with no
// intervening sw write, which is exactly the scenario that would expose
// a start-of-cycle-vs-end-of-cycle freeze-check discrepancy. raceProp
// additionally forces a true same-cycle sw+hw race while sticky is either
// frozen or unlocked.

import BlueCheck :: *;
import StmtFSM :: *;
import Sticky :: *;
import Sticky_signal :: *;

module [BlueCheck] checkSticky ();
   Sticky spec <- mkSticky();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   equiv("swWrite", spec.swWrite, imp.bus.write);
   equiv("hwWrite_single", spec.hwWrite, imp.hw._write);
   equiv("currentValue", spec.rd, imp.currentValue);

   // Sequence of solo hw writes, no intervening sw write: first nonzero
   // write should freeze the field; subsequent hw writes must have no
   // effect until sw unsticks it.
   function Stmt hwSeqProp(Bit#(8) d1, Bit#(8) d2, Bit#(8) d3) =
      seq
         action spec.hwWrite(d1); imp.hw._write(d1); endaction
         ensure(spec.rd == imp.currentValue);
         action spec.hwWrite(d2); imp.hw._write(d2); endaction
         ensure(spec.rd == imp.currentValue);
         action spec.hwWrite(d3); imp.hw._write(d3); endaction
         ensure(spec.rd == imp.currentValue);
      endseq;

   prop("hw_freezes_after_first_nonzero", hwSeqProp);

   // sw can unstick the field (including writing it back to a nonzero
   // value); a subsequent hw write must then re-apply the freeze test
   // against that fresh value.
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

   // True same-cycle race: sw and hw both fire in the same action block,
   // starting from whatever state the field is already in (may be frozen
   // or unlocked at that point in the sequence).
   function Stmt raceProp(Bit#(8) d0, Bit#(8) swdata, Bit#(8) swstrb, Bit#(8) hwdata) =
      seq
         // Optionally seed a nonzero (frozen) state via a solo hw write
         // first, using whatever d0 the random driver picked.
         action spec.hwWrite(d0); imp.hw._write(d0); endaction
         action
            spec.swWrite(swdata, swstrb);
            spec.hwWrite(hwdata);
            imp.bus.write(swdata, swstrb);
            imp.hw._write(hwdata);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;

   prop("race_from_either_lock_state", raceProp);
endmodule

module [Module] testSticky ();
   blueCheck(checkSticky);
endmodule
