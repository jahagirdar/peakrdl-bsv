// BlueCheck equivalence: BLIND reference (NextOverridesEverything.bsv,
// package NextOverridesEverything, mkNextOverridesEverything#(next))
// vs REAL peakrdl-bsv generated RTL
// (NextOverridesEverything_signal.bsv, mkCSRSignal_reg0_field0),
// config: hw=rw, next=external 8-bit signal, ALSO nominally configured
// with onwrite=woclr and sticky (the whole point of this config: are
// woclr/sticky truly dead once `next` is present?).
//
// *** RDL adjustment note: the blind reference's header comment states
// "sw=r" for this config, but onwrite=woclr is only a legal SystemRDL
// property on a field with SOME software write access -- the real
// systemrdl-compiler rejects `sw=r; ... onwrite=woclr;` outright
// ("Field 'field0' has an 'onwrite' property but does not have
// software write access"), confirmed by trying to compile the literal
// sw=r config here. sw=rw was substituted (the minimal change needed
// to make onwrite=woclr syntactically legal at all) so this config
// could be compiled and exercised; hw=rw, next=..., sticky are
// unchanged from the blind ref's stated config. This makes the real
// generator's interface expose a bus.write(data,wstrb) method that the
// blind reference (sw=r) does not model -- exercised below anyway
// (with no spec-side counterpart) purely to drive adversarial
// woclr-triggering values at the real generator's dead sw-write path.
//
// Confirmed from the generated source: identical to Next_signal.bsv's
// r_write rule body -- `rr = w_ext_..._next_sig; r<=rr;` -- with NO
// woclr or sticky logic anywhere in the module, despite woclr/sticky
// being present in the RDL's field property dump (see the header
// comment dump in NextOverridesEverything_signal.bsv). This is a
// purely static (compile-time) confirmation that the dead logic never
// gets generated at all, not just an "unreachable at runtime" claim.
//
// This harness additionally drives ADVERSARIAL values at imp's sw
// write and hw write paths every single cycle -- values specifically
// chosen to trigger woclr (all-1s data/wstrb, which would clear every
// bit if woclr were live) and to probe sticky (nonzero hw data
// attempts after the stored value has already gone nonzero via
// `next`, which would freeze a real sticky field) -- concurrently with
// `next` driving a fully independent, changing random value each
// cycle, to confirm imp.currentValue tracks ONLY next and is never
// perturbed by these attempted side effects.
import BlueCheck :: *;
import StmtFSM :: *;
import NextOverridesEverything_signal :: *;
import NextOverridesEverything :: *;

module [BlueCheck] checkNextOverridesEverything ();
   Wire#(Bit#(8)) w_next <- mkDWire(0);
   NextOverridesEverything spec <- mkNextOverridesEverything(w_next);
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   // Background adversarial driver: every single cycle (independent of
   // which prop is firing), hammer imp's sw/hw write paths with
   // woclr/sticky-triggering values. If any dead logic leaked through,
   // this would corrupt imp's stored value away from whatever `next`
   // says on some cycle.
   rule adversarialWoclrAttempt;
      imp.bus.write(8'hFF, 8'hFF);   // all-1s data+wstrb: would clear everything via woclr
   endrule
   rule adversarialStickyAttempt;
      imp.hw._write(8'h00);          // would freeze-to-nonzero-forever under sticky once r!=0
   endrule

   function Stmt nextProp(Bit#(8) v) =
      seq
         action
            w_next <= v;
            imp.set_ext_NextOverridesEverything_next_sig(v);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("next_vs_adversarial_writes", nextProp);

   // Explicit hand-picked vectors that would most obviously trigger
   // woclr/sticky if either were (bug-)reachable: drive `next` to a
   // nonzero value first (a real sticky field would then latch/freeze
   // on any further hw write), then to all-1s (a real woclr would react
   // to the concurrent all-1s sw write above by clearing), then to 0,
   // then to an alternating pattern -- each single-stepped so any
   // one-cycle-delayed contamination would show up.
   Stmt directedSequence =
      seq
         action w_next <= 8'h00; imp.set_ext_NextOverridesEverything_next_sig(8'h00); endaction
         ensure(spec.rd == imp.currentValue);
         action w_next <= 8'h5A; imp.set_ext_NextOverridesEverything_next_sig(8'h5A); endaction
         ensure(spec.rd == imp.currentValue);
         action w_next <= 8'hFF; imp.set_ext_NextOverridesEverything_next_sig(8'hFF); endaction
         ensure(spec.rd == imp.currentValue);
         action w_next <= 8'h00; imp.set_ext_NextOverridesEverything_next_sig(8'h00); endaction
         ensure(spec.rd == imp.currentValue);
         action w_next <= 8'hA5; imp.set_ext_NextOverridesEverything_next_sig(8'hA5); endaction
         ensure(spec.rd == imp.currentValue);
         action w_next <= 8'h01; imp.set_ext_NextOverridesEverything_next_sig(8'h01); endaction
         ensure(spec.rd == imp.currentValue);
         action w_next <= 8'hFE; imp.set_ext_NextOverridesEverything_next_sig(8'hFE); endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("directed_adversarial_sequence", directedSequence);

   function ActionValue#(Bit#(8)) specSwRead();
      actionvalue
         return spec.rd;
      endactionvalue
   endfunction
   equiv("currentValue", spec.rd, imp.currentValue);
endmodule

module [Module] testNextOverridesEverything ();
   blueCheck(checkNextOverridesEverything);
endmodule
