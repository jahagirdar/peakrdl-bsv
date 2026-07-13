module gold_top (
    CLK,
    RST_N,
    swWrite_data,
    swWrite_wstrb,
    swWrite_swwe,
    EN_swWrite,
    RDY_swWrite,
    rd,
    RDY_rd
);
  input CLK;
  input RST_N;
  input [7:0] swWrite_data;
  input [7:0] swWrite_wstrb;
  input swWrite_swwe;
  input EN_swWrite;
  output RDY_swWrite;
  output [7:0] rd;
  output RDY_rd;

  mkComboSwweWoclr u (
      .CLK(CLK),
      .RST_N(RST_N),
      .swWrite_data(swWrite_data),
      .swWrite_wstrb(swWrite_wstrb),
      .swWrite_swwe(swWrite_swwe),
      .EN_swWrite(EN_swWrite),
      .RDY_swWrite(RDY_swWrite),
      .rd(rd),
      .RDY_rd(RDY_rd)
  );
endmodule
