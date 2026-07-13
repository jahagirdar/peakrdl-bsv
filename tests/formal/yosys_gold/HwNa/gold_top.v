// Thin harness wrapper: sw=rw/hw=na (pure software-only storage; the
// blind ref exposes no hw-facing method at all). Common port list = a
// sw masked-merge write input + the stored value read out (rd).
module gold_top (
    CLK,
    RST_N,
    swWrite_data,
    swWrite_wstrb,
    EN_swWrite,
    rd,
    RDY_rd
);
  input CLK;
  input RST_N;
  input [7:0] swWrite_data;
  input [7:0] swWrite_wstrb;
  input EN_swWrite;
  output [7:0] rd;
  output RDY_rd;
  wire RDY_swWrite_u, RDY_swRead_u;
  mkHwNa u (
      .CLK(CLK),
      .RST_N(RST_N),
      .swWrite_data(swWrite_data),
      .swWrite_wstrb(swWrite_wstrb),
      .EN_swWrite(EN_swWrite),
      .RDY_swWrite(RDY_swWrite_u),
      .swRead(rd),
      .RDY_swRead(RDY_swRead_u)
  );
  assign RDY_rd = 1'b1;
endmodule
