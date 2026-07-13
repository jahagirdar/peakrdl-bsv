module gold_top (
    CLK,
    RST_N,
    EN_incr,
    EN_decr,
    rd,
    RDY_rd
);
  input CLK;
  input RST_N;
  input EN_incr;
  input EN_decr;
  output [7:0] rd;
  output RDY_rd;

  wire RDY_incr_u, RDY_decr_u;
  mkCounterIncrDecrValue u (
      .CLK(CLK),
      .RST_N(RST_N),
      .EN_incr(EN_incr),
      .RDY_incr(RDY_incr_u),
      .EN_decr(EN_decr),
      .RDY_decr(RDY_decr_u),
      .rd(rd),
      .RDY_rd(RDY_rd)
  );
endmodule
