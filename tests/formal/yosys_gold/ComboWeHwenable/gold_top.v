module gold_top (
    CLK,
    RST_N,
    swWrite_data,
    swWrite_wstrb,
    EN_swWrite,
    RDY_swWrite,
    hwWrite_data,
    hwWrite_we,
    EN_hwWrite,
    RDY_hwWrite,
    hwenable,
    rd,
    RDY_rd
);
  input CLK;
  input RST_N;
  input [7:0] swWrite_data;
  input [7:0] swWrite_wstrb;
  input EN_swWrite;
  output RDY_swWrite;
  input [7:0] hwWrite_data;
  input hwWrite_we;
  input EN_hwWrite;
  output RDY_hwWrite;
  input [7:0] hwenable;
  output [7:0] rd;
  output RDY_rd;

  mkComboWeHwenable u (
      .hwenable(hwenable),
      .CLK(CLK),
      .RST_N(RST_N),
      .swWrite_data(swWrite_data),
      .swWrite_wstrb(swWrite_wstrb),
      .EN_swWrite(EN_swWrite),
      .RDY_swWrite(RDY_swWrite),
      .hwWrite_data(hwWrite_data),
      .hwWrite_we(hwWrite_we),
      .EN_hwWrite(EN_hwWrite),
      .RDY_hwWrite(RDY_hwWrite),
      .rd(rd),
      .RDY_rd(RDY_rd)
  );
endmodule
