// BlueCheck equivalence: BLIND reference (Next.bsv, package Next,
// mkNext#(next)) vs REAL peakrdl-bsv generated RTL (Next_signal.bsv,
// mkCSRSignal_reg0_field0), config: sw=r, hw=rw, next=external 8-bit
// signal.
//
// Confirmed from the generated source: when next is configured, the
// r_write rule body reduces to exactly `rr = w_ext_next_sig; r<=rr;`
// -- no sw/hw write logic, no onwrite side effects, generated at all
// for this field (dead-code elided at generation time, not merely
// unreachable at runtime), matching the blind reference's own
// "simplest possible reference model" read of the spec.
//
// Interface bridging: the blind reference models `next` as a genuine
// dynamic module-parameter wire (BSV lets a Bit#(n) module parameter
// be a real, continuously-sampled hardware input, not just an
// elaboration-time constant), so a plain Wire#(Bit#(8)) driven each
// cycle serves both spec's `next` argument (via BSV's automatic
// Reg/Wire-to-value read sugar) and imp's set_ext_..._next_sig method.
// The real generator's hw._write/_read methods exist on the interface
// (hw=rw is the declared access mode) but are functionally dead once
// next is wired in; not exercised here since the blind reference
// deliberately omits any hw write method (see NextOverridesEverything
// for the harness that DOES drive hw._write anyway, to confirm it is
// truly a no-op).
import BlueCheck :: *;
import StmtFSM :: *;
import Next_signal :: *;
import Next :: *;

module [BlueCheck] checkNext ();
   Wire#(Bit#(8)) w_next <- mkDWire(0);
   Next spec <- mkNext(w_next);
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   function Stmt nextProp(Bit#(8) v) =
      seq
         action
            w_next <= v;
            imp.set_ext_Next_next_sig(v);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("next", nextProp);

   function ActionValue#(Bit#(8)) specSwRead();
      actionvalue
         return spec.rd;
      endactionvalue
   endfunction
   equiv("swRead", specSwRead, imp.bus.read);
   equiv("currentValue", spec.rd, imp.currentValue);
endmodule

module [Module] testNext ();
   blueCheck(checkNext);
endmodule
