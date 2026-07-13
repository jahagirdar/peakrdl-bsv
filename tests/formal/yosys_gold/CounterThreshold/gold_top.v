module gold_top (
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

  mkCounterThreshold u (
      .CLK(CLK),
      .RST_N(RST_N),
      .EN_incr(EN_incr),
      .RDY_incr(RDY_incr),
      .rd(rd),
      .RDY_rd(RDY_rd),
      .thresholdLevel(thresholdLevel),
      .RDY_thresholdLevel(RDY_thresholdLevel)
  );
endmodule
