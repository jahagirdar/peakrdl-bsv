module gate_top (
    CLK,
    RST_N,
    EN_incr,
    RDY_incr,
    rd,
    RDY_rd,
    thresholdLevel,
    RDY_thresholdLevel
);
  input CLK;
  input RST_N;
  input EN_incr;
  output RDY_incr;
  output [7:0] rd;
  output RDY_rd;
  output thresholdLevel;
  output RDY_thresholdLevel;

  wire [7:0] hw_read_unused;
  wire RDY_hw_read_unused;
  wire RDY_hw_clear_unused;
  wire [7:0] bus_read_unused;
  wire RDY_bus_read_unused;

  testcsrreg_reg0_field0 u (
      .CLK(CLK),
      .RST_N(RST_N),
      .hw__read(hw_read_unused),
      .RDY_hw__read(RDY_hw_read_unused),
      .EN_hw_incr(EN_incr),
      .RDY_hw_incr(RDY_incr),
      .hw_incrthreshold(thresholdLevel),
      .RDY_hw_incrthreshold(RDY_thresholdLevel),
      .EN_hw_clear(1'b0),
      .RDY_hw_clear(RDY_hw_clear_unused),
      .EN_bus_read(1'b1),
      .bus_read(bus_read_unused),
      .RDY_bus_read(RDY_bus_read_unused),
      .currentValue(rd),
      .RDY_currentValue(RDY_rd)
  );
endmodule
