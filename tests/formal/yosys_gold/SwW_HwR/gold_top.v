// Thin harness wrapper: sw=w/hw=r config. Common port list = a sw
// masked-merge write input + the stored value read out (rd). The blind
// ref's hwRead maps to the gate side's currentValue (both side-effect-
// free reads of the same stored value; sw is write-only here).
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
  wire RDY_swWrite_u, RDY_hwRead_u;
  mkSwW_HwR u (
      .CLK(CLK),
      .RST_N(RST_N),
      .swWrite_data(swWrite_data),
      .swWrite_wstrb(swWrite_wstrb),
      .EN_swWrite(EN_swWrite),
      .RDY_swWrite(RDY_swWrite_u),
      .hwRead(rd),
      .RDY_hwRead(RDY_hwRead_u)
  );
  assign RDY_rd = 1'b1;
endmodule
