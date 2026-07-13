module gold_top (
    CLK,
    RST_N,
    next,
    rd,
    RDY_rd
);
  input CLK;
  input RST_N;
  input [7:0] next;
  output [7:0] rd;
  output RDY_rd;

  mkNext u (
      .next(next),
      .CLK(CLK),
      .RST_N(RST_N),
      .rd(rd),
      .RDY_rd(RDY_rd)
  );
endmodule
