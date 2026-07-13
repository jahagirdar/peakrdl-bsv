module gate_top (
    CLK,
    RST_N,
    incr_amt,
    decr_amt,
    EN_incr,
    EN_decr,
    rd,
    RDY_rd
);
  input CLK;
  input RST_N;
  input [7:0] incr_amt;
  input [7:0] decr_amt;
  input EN_incr;
  input EN_decr;
  output [7:0] rd;
  output RDY_rd;

  wire RDY_hw__read_u, RDY_hw_incr_u, RDY_hw_decr_u, RDY_hw_clear_u, RDY_bus_read_u, RDY_currentValue_u;
  wire [7:0] hw__read_u, bus_read_u;

  testcsrreg_reg0_field0 u (
      .CLK(CLK),
      .RST_N(RST_N),
      .hw__read(hw__read_u),
      .RDY_hw__read(RDY_hw__read_u),
      .hw_incr_count(incr_amt),
      .EN_hw_incr(EN_incr),
      .RDY_hw_incr(RDY_hw_incr_u),
      .hw_decr_count(decr_amt),
      .EN_hw_decr(EN_decr),
      .RDY_hw_decr(RDY_hw_decr_u),
      .EN_hw_clear(1'b0),
      .RDY_hw_clear(RDY_hw_clear_u),
      .EN_bus_read(1'b0),
      .bus_read(bus_read_u),
      .RDY_bus_read(RDY_bus_read_u),
      .currentValue(rd),
      .RDY_currentValue(RDY_currentValue_u)
  );
  assign RDY_rd = 1'b1;
endmodule
