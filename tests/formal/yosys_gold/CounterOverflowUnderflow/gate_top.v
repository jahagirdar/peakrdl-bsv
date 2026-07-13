// Thin harness wrapper: same common port list as gold_top. The
// generator exposes hw_overflow COMBINATIONALLY (same cycle as the
// incr); ovf_q samples it into a 1-cycle flop (reset to 0 on RST_N, to
// match the blind ref's mkRegA(False) overflowReg) so it lines up with
// the blind ref's registered pulse. hw_underflow is NOT sampled or
// compared -- see gold_top.v's header for the documented
// same-cycle-incr+decr underflow discrepancy this deliberately excludes.
module gate_top (
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
  wire RDY_hw__read_u, RDY_hw_incr_u, RDY_hw_overflow_u, RDY_hw_decr_u,
       RDY_hw_underflow_u, RDY_hw_clear_u, RDY_bus_read_u, RDY_currentValue_u;
  wire [7:0] hw__read_u, bus_read_u;
  wire ovf_comb, unf_comb_unused;
  reg ovf_q;
  always @(posedge CLK or negedge RST_N)
    if (!RST_N) ovf_q <= 1'b0;
    else ovf_q <= ovf_comb;
  assign overflow = ovf_q;
  testcsrreg_reg0_field0 u (
      .CLK(CLK),
      .RST_N(RST_N),
      .hw__read(hw__read_u),
      .RDY_hw__read(RDY_hw__read_u),
      .hw_incr_count(incr_amt),
      .EN_hw_incr(EN_incr),
      .RDY_hw_incr(RDY_hw_incr_u),
      .hw_overflow(ovf_comb),
      .RDY_hw_overflow(RDY_hw_overflow_u),
      .hw_decr_count(decr_amt),
      .EN_hw_decr(EN_decr),
      .RDY_hw_decr(RDY_hw_decr_u),
      .hw_underflow(unf_comb_unused),
      .RDY_hw_underflow(RDY_hw_underflow_u),
      .EN_hw_clear(1'b0),
      .RDY_hw_clear(RDY_hw_clear_u),
      .EN_bus_read(1'b0),
      .bus_read(bus_read_u),
      .RDY_bus_read(RDY_bus_read_u),
      .currentValue(rd),
      .RDY_currentValue(RDY_currentValue_u)
  );
endmodule
