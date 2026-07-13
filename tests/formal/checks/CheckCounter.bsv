// NOTE: imports CounterRef.bsv, a byte-for-byte rename of
// refs/Counter.bsv (package/interface/module Counter -> CounterRef,
// mkCounter -> mkCounterRef) needed only because BSC ships its own
// built-in library package named `Counter`
// (/opt/tools/bsc/lib/Libraries/Counter.bo) which collided at compile
// time ("package BlueCheck was compiled using a different version of
// Counter.bo"). No logic was changed; refs/Counter.bsv itself is
// untouched.
//
// BlueCheck equivalence: BLIND reference (refs/Counter.bsv, package
// Counter, mkCounter) vs REAL peakrdl-bsv generated RTL
// (Counter_signal.bsv, mkCSRSignal_reg0_field0), config: sw=r, hw=r,
// counter, incrsaturate (bool form, clamps at 8'hFF), incr_const=1,
// no decrement, no overflow, no threshold, width=8 (counter.rdl,
// reused unchanged from scratchpad/bluecheck/checks -- confirmed to
// match refs/Counter.bsv's stated assumptions exactly: sw=r/hw=r,
// `counter; incrsaturate;` with no incrvalue/incrwidth/decrvalue/
// decrwidth/overflow/incrthreshold configured).
//
// Interface bridging note: the blind reference has a single `rd` value
// method serving both the sw-visible and hw-visible read (no onread
// side effects differentiate them for this config, and sw has no write
// port at all: sw=r). The real generator instead exposes two separate
// read paths -- bus.read() (ActionValue#(8), generic sw-side shape) and
// hw._read (plain value) -- plus hw.incr() (Action) and hw.clear()
// (Action, generic boilerplate). We bridge purely at the type level:
// spec.rd (value) -> ActionValue#(8) for the bus.read() comparison, and
// spec.rd directly (value vs value) for hw._read/currentValue. No new
// logic added on either side. incr() is compared directly (Action vs
// Action, no bridging needed).
//
// hw.clear(): counter.rdl has no onclear/hwclr property, and the blind
// reference correctly implements no clear support. As in the other
// configs, we leave the real generator's generic hw.clear() unexercised
// here (not called), consistent with the Yosys side tying EN_hw_clear=0.
import BlueCheck :: *;
import StmtFSM :: *;
import Counter_signal :: *;
import CounterRef :: *;

module [BlueCheck] checkCounter ();
   CounterRef spec <- mkCounterRef();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   function ActionValue#(Bit#(8)) specSwRead();
      actionvalue
         return spec.rd;
      endactionvalue
   endfunction

   equiv("incr", spec.incr, imp.hw.incr);
   equiv("swRead", specSwRead, imp.bus.read);
   equiv("hwRead", spec.rd, imp.hw._read);
   equiv("currentValue", spec.rd, imp.currentValue);
endmodule

module [Module] testCounter ();
   blueCheck(checkCounter);
endmodule
