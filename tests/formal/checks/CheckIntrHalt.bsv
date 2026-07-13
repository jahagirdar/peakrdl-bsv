// BlueCheck equivalence: BLIND reference (IntrHalt.bsv, package
// IntrHalt, mkIntrHalt#(haltenable)) vs REAL peakrdl-bsv generated RTL
// (IntrHalt_reg.bsv/IntrHalt_signal.bsv, mkConfigReg_reg0), config:
// single field, sw=rw, hw=w, onwrite=woclr, intr (no enable/mask),
// haltenable=external 8-bit signal.
//
// KNOWN FAILING TEST (confirmed real, not a migration artifact): this
// harness currently reproduces a genuine counter-example ('ensure'
// statement failed after hwWrite('h1e); swWrite('h79,'h7d);
// hwWrite('he9)), both against freshly-generated RTL from
// rdl/IntrHalt.rdl AND against the original audit's pre-built
// `testIntrHalt` binary (compare2/IntrHalt/testIntrHalt in the source
// scratch tree) -- confirming this is a real, pre-existing discrepancy
// that was apparently never reported (no run.log was ever saved
// alongside that binary). Root cause is the SAME one documented in
// tests/formal/checks/CheckIntrRegister.bsv: for an `intr` field, the
// generator's hw write is an OR-merge (hw sets pending bits), not a
// plain unconditional replace, while the blind reference modeled hw=w's
// general-shape default (plain replace) since the spec text does not
// call out `intr` as changing hw's write semantics. Left RED
// intentionally -- see tests/formal/README.md's "Known failing tests"
// section.
//
// This is the REG-level (not signal-level) generated module, since
// intr/halt are register-level aggregates (print_bsv_reg.py), not
// per-field ones -- the field's own Ifc_CSRSignal_reg0_field0 has no
// intrPending/halt method at all.
//
// Interface bridging notes:
//  - Register width: the RDL's default_regwidth is 32 (no explicit
//    regwidth set), so ConfigReg_reg0's bus.write/read operate on
//    Bit#(32), with this one field occupying bits [7:0] and the
//    register-level write/read methods only ever touching those bits
//    (confirmed from IntrHalt_reg.bsv: `sig_field0.bus.write(data[7:0],
//    wstrb[7:0])`). We zero-extend the blind reference's Bit#(8)
//    data/wstrb up to Bit#(32) for the real side and truncate the read
//    result back down, so BlueCheck's random generator still explores
//    the full 8-bit space that actually matters.
//  - haltenable: the blind reference takes it as a fixed Bit#(8)
//    module constructor argument (a compile-time constant for the
//    whole test run), while the real generator exposes it as a
//    runtime, continuously-driven external signal
//    (set_ext_IntrHalt_halt_en_sig, backed by a mkDWire(0) that must be
//    re-driven every cycle or it reverts to 0). We bridge this by
//    picking a fixed haltenable constant for spec's module parameter
//    and continuously re-driving imp's wire to that same constant via
//    an always-firing background rule, so both sides see the same
//    (unchanging) qualifier value throughout the test.
//  - hw write: hw=w with no we/wel/hwenable/hwmask/sticky/stickybit
//    configured, so a hw write is a plain unconditional overwrite on
//    both sides -- compared directly via imp.hw.sfield0._write.
import BlueCheck :: *;
import StmtFSM :: *;
import IntrHalt_signal :: *;
import IntrHalt_reg :: *;
import IntrHalt :: *;

Bit#(8) haltEnableConst = 8'hA5;

module [BlueCheck] checkIntrHalt ();
   IntrHalt spec <- mkIntrHalt(haltEnableConst);
   ConfigReg_reg0 imp <- mkConfigReg_reg0();

   Ensure ensure <- getEnsure;

   rule driveHaltEnable;
      imp.set_ext_IntrHalt_halt_en_sig(haltEnableConst);
   endrule

   function ActionValue#(Bit#(32)) impRead32();
      actionvalue
         let v <- imp.bus.read;
         return v;
      endactionvalue
   endfunction

   function Stmt swWriteProp(Bit#(8) data, Bit#(8) wstrb) =
      seq
         action
            spec.swWrite(data, wstrb);
            imp.bus.write(zeroExtend(data), zeroExtend(wstrb));
         endaction
         ensure(zeroExtend(spec.rd) == imp.hw.value);
      endseq;
   prop("swWrite", swWriteProp);

   function Stmt hwWriteProp(Bit#(8) data) =
      seq
         action
            spec.hwWrite(data);
            imp.hw.sfield0._write(data);
         endaction
         ensure(zeroExtend(spec.rd) == imp.hw.value);
      endseq;
   prop("hwWrite", hwWriteProp);

   // Genuine same-cycle race: sw (woclr'd) write vs hw write.
   // precedence is unspecified -> default sw wins.
   function Stmt raceProp(Bit#(8) swdata, Bit#(8) swstrb, Bit#(8) hwdata) =
      seq
         action
            spec.swWrite(swdata, swstrb);
            spec.hwWrite(hwdata);
            imp.bus.write(zeroExtend(swdata), zeroExtend(swstrb));
            imp.hw.sfield0._write(hwdata);
         endaction
         ensure(zeroExtend(spec.rd) == imp.hw.value);
      endseq;
   prop("race_sw_precedence", raceProp);

   function ActionValue#(Bit#(8)) specSwRead();
      actionvalue
         return spec.rd;
      endactionvalue
   endfunction

   function Stmt swReadProp() =
      seq
         action
            let sv <- specSwRead();
            let iv <- impRead32();
            ensure(zeroExtend(sv) == iv);
         endaction
      endseq;
   prop("swRead", swReadProp);

   equiv("intrPending", spec.intrPending, imp.hw.interrupt);
   equiv("halt", spec.halt, imp.hw.halt);
endmodule

module [Module] testIntrHalt ();
   blueCheck(checkIntrHalt);
endmodule
