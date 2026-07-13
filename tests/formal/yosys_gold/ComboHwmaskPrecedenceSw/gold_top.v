// Thin harness wrapper (touches neither side's logic): exposes a common
// port list for the gold (blind ref) side. hwmask/swWrite/hwWrite/rd
// map directly onto the ref's own ports.
module gold_top (
    CLK,
    RST_N,
    swWrite_data,
    swWrite_wstrb,
    EN_swWrite,
    RDY_swWrite,
    hwWrite_data,
    EN_hwWrite,
    RDY_hwWrite,
    hwmask,
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
  input EN_hwWrite;
  output RDY_hwWrite;
  input [7:0] hwmask;
  output [7:0] rd;
  output RDY_rd;

  mkComboHwmaskPrecedenceSw u (
      .hwmask(hwmask),
      .CLK(CLK),
      .RST_N(RST_N),
      .swWrite_data(swWrite_data),
      .swWrite_wstrb(swWrite_wstrb),
      .EN_swWrite(EN_swWrite),
      .RDY_swWrite(RDY_swWrite),
      .hwWrite_data(hwWrite_data),
      .EN_hwWrite(EN_hwWrite),
      .RDY_hwWrite(RDY_hwWrite),
      .rd(rd),
      .RDY_rd(RDY_rd)
  );
endmodule
