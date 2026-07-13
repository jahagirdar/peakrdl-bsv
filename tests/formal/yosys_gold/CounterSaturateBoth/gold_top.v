// Thin harness wrapper: bidirectional saturating counter (incrsaturate=
// 200, decrsaturate floor 0), explicit 8-bit incr/decr amounts. Common
// port list = incr amount+enable, decr amount+enable, stored value (rd).
module gold_top (
    CLK,
    RST_N,
    incr_amt,
    EN_incr,
    decr_amt,
    EN_decr,
    rd,
    RDY_rd
);
  input CLK;
  input RST_N;
  input [7:0] incr_amt;
  input EN_incr;
  input [7:0] decr_amt;
  input EN_decr;
  output [7:0] rd;
  output RDY_rd;
  wire RDY_incr_u, RDY_decr_u;
  mkCounterSaturateBoth u (
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
