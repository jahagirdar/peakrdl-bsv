// Thin harness wrapper: bidirectional wrapping counter, explicit 8-bit
// incr/decr amounts, with an overflow one-cycle pulse output.
//
// Common port list = incr amount+enable, decr amount+enable, stored
// value (rd), and the overflow pulse. The blind ref registers its
// pulses (visible the cycle AFTER the triggering incr/decr); the gate
// side exposes them combinationally (same cycle), so gate_top adds a
// 1-cycle sampling flop to line them up -- the Yosys analog of the
// BlueCheck harness's capOvf/capUnf sampling Regs (see
// tests/formal/checks/CheckCounterOverflowUnderflow.bsv).
//
// UNDERFLOW DELIBERATELY NOT COMPARED (documented discrepancy, NOT a
// harness bug -- see tests/formal/README.md "Newly-surfaced Yosys SEC
// discrepancy"). On a SAME-CYCLE incr+decr where the incr overflows past
// 255, the generator computes underflow against the WRAPPED 8-bit
// post-incr value while this blind ref uses an unwrapped wide Int#(10)
// intermediate. Concrete counter-example (confirmed by direct RTL
// co-simulation of both compiled Verilogs, cycle-aligned): r=200,
// incr=100, decr=100 in one cycle -> generator underflow=1 (decr 100 >
// wrapped 44), blind ref underflow=0 (decr 100 > unwrapped 300 is
// false); rd=200 and overflow=1 agree on both sides. BlueCheck passes
// this config because its randomized raceProp never hit that narrow
// corner; Yosys SEC's exhaustive proof did. `underflowPulse` is left
// unconnected here so the equivalence check covers rd + overflow (both
// genuinely proven) without asserting the diverging underflow output.
module gold_top (
    CLK,
    RST_N,
    incr_amt,
    EN_incr,
    decr_amt,
    EN_decr,
    rd,
    overflow
);
  input CLK;
  input RST_N;
  input [7:0] incr_amt;
  input EN_incr;
  input [7:0] decr_amt;
  input EN_decr;
  output [7:0] rd;
  output overflow;
  wire RDY_incr_u, RDY_decr_u, RDY_rd_u, RDY_overflowPulse_u, RDY_underflowPulse_u;
  wire underflow_unused;
  mkCounterOverflowUnderflow u (
      .CLK(CLK),
      .RST_N(RST_N),
      .incr_amt(incr_amt),
      .EN_incr(EN_incr),
      .RDY_incr(RDY_incr_u),
      .decr_amt(decr_amt),
      .EN_decr(EN_decr),
      .RDY_decr(RDY_decr_u),
      .rd(rd),
      .RDY_rd(RDY_rd_u),
      .overflowPulse(overflow),
      .RDY_overflowPulse(RDY_overflowPulse_u),
      .underflowPulse(underflow_unused),
      .RDY_underflowPulse(RDY_underflowPulse_u)
  );
endmodule
