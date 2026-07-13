// Thin harness wrapper: `next` overrides everything -- storage follows
// the external next input every cycle. Common port list = next input +
// stored value read (rd). The blind ref takes `next` as a module
// parameter, which bsc exposes as a plain input port.
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
  mkNextOverridesEverything u (
      .next(next),
      .CLK(CLK),
      .RST_N(RST_N),
      .rd(rd),
      .RDY_rd(RDY_rd)
  );
endmodule
