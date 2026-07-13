module gold_top (
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

  wire RDY_incr_u, RDY_decr_u;
  mkCounterIncrDecrWidth u (
      .CLK(CLK),
      .RST_N(RST_N),
      .incr_amt(incr_amt),
      .EN_incr(EN_incr),
      .RDY_incr(RDY_incr_u),
      .decr_amt(decr_amt),
      .EN_decr(EN_decr),
      .RDY_decr(RDY_decr_u),
      .rd(rd),
      .RDY_rd(RDY_rd)
  );
endmodule
