module gold_top (
    CLK,
    RST_N,
    swWrite_data,
    swWrite_wstrb,
    swWrite_swwel,
    EN_swWrite,
    RDY_swWrite,
    hwWrite_data,
    hwWrite_wel,
    EN_hwWrite,
    RDY_hwWrite,
    rd,
    RDY_rd
);
  input CLK;
  input RST_N;
  input [7:0] swWrite_data;
  input [7:0] swWrite_wstrb;
  input swWrite_swwel;
  input EN_swWrite;
  output RDY_swWrite;
  input [7:0] hwWrite_data;
  input hwWrite_wel;
  input EN_hwWrite;
  output RDY_hwWrite;
  output [7:0] rd;
  output RDY_rd;

  mkComboWelSwwel u (
      .CLK(CLK),
      .RST_N(RST_N),
      .swWrite_data(swWrite_data),
      .swWrite_wstrb(swWrite_wstrb),
      .swWrite_swwel(swWrite_swwel),
      .EN_swWrite(EN_swWrite),
      .RDY_swWrite(RDY_swWrite),
      .hwWrite_data(hwWrite_data),
      .hwWrite_wel(hwWrite_wel),
      .EN_hwWrite(EN_hwWrite),
      .RDY_hwWrite(RDY_hwWrite),
      .rd(rd),
      .RDY_rd(RDY_rd)
  );
endmodule
