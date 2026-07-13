// BlueCheck equivalence: BLIND reference (refs/We.bsv, package We, mkWe)
// vs REAL peakrdl-bsv generated RTL (We_signal.bsv, mkCSRSignal_reg0_field0),
// config: sw=rw, hw=rw, we=gate_sig (active-high hw write-enable), width=8.
//
// Interface bridging note: the blind reference bundles the `we` gate as
// an argument to a single hwWrite(data,we) Action method, since it never
// saw the generator and modeled `we` as "only meaningful together with a
// genuine hw write attempt". The real generator instead exposes `we` as
// a continuously-driven wire (set_ext_top_gate_sig, a mkDWire sampled
// every cycle) separate from hw._write(data). Neither side's update
// logic is touched here -- we just script both sides' calls together
// per test vector (matching the established BlueCheck idiom for gated
// hw-write configs), the same way clear/currentValue are compared
// directly since the top-level storage semantics are what we're
// checking, not internal method arity.
import BlueCheck :: *;
import StmtFSM :: *;
import We_signal :: *;
import We :: *;

module [BlueCheck] checkWe ();
   We spec <- mkWe();
   Ifc_CSRSignal_reg0_field0 imp <- mkCSRSignal_reg0_field0(0);

   Ensure ensure <- getEnsure;

   equiv("swWrite", spec.swWrite, imp.bus.write);

   function Stmt hwWriteProp(Bit#(8) data, Bit#(1) gate) =
      seq
         action
            spec.hwWrite(data, gate == 1);
            imp.set_ext_top_gate_sig(gate);
            imp.hw._write(data);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("hwWrite_gated", hwWriteProp);

   function Stmt raceProp(Bit#(8) hwdata, Bit#(1) gate, Bit#(8) swdata, Bit#(8) swstrb) =
      seq
         action
            spec.hwWrite(hwdata, gate == 1);
            spec.swWrite(swdata, swstrb);
            imp.set_ext_top_gate_sig(gate);
            imp.hw._write(hwdata);
            imp.bus.write(swdata, swstrb);
         endaction
         ensure(spec.rd == imp.currentValue);
      endseq;
   prop("race_sw_precedence", raceProp);

   // Note: the real generator also exposes an unconditional hw.clear()
   // (present on every field's HW interface as generic accessor
   // boilerplate, per print_bsv_reg.py, regardless of whether the RDL
   // configured any clear-related property on this field). The blind
   // reference correctly did not model this since the `we` config's RDL
   // has no onclear/hwclr property -- nothing to check against on the
   // spec side, so intentionally not exercised here.
endmodule

module [Module] testWe ();
   blueCheck(checkWe);
endmodule
