// Thin harness wrapper: exposes the IntrRegister field0 storage (via
// mkGoldIntrRegister) under the gate side's common port list = a hw-write
// input, a sw masked-merge (woclr) write input, and the stored value
// read (rd). See GoldIntrRegister.bsv for the expected-failing (intr OR-merge)
// disclosure.
module gold_top (
    CLK,
    RST_N,
    hwWrite_data,
    EN_hwWrite,
    swWrite_data,
    swWrite_wstrb,
    EN_swWrite,
    rd,
    RDY_rd
);
  input CLK;
  input RST_N;
  input [7:0] hwWrite_data;
  input EN_hwWrite;
  input [7:0] swWrite_data;
  input [7:0] swWrite_wstrb;
  input EN_swWrite;
  output [7:0] rd;
  output RDY_rd;
  wire RDY_swWrite_u, RDY_hwWrite_u;
  mkGoldIntrRegister u (
      .CLK(CLK),
      .RST_N(RST_N),
      .swWrite_data(swWrite_data),
      .swWrite_wstrb(swWrite_wstrb),
      .EN_swWrite(EN_swWrite),
      .RDY_swWrite(RDY_swWrite_u),
      .hwWrite_data(hwWrite_data),
      .EN_hwWrite(EN_hwWrite),
      .RDY_hwWrite(RDY_hwWrite_u),
      .rd(rd),
      .RDY_rd(RDY_rd)
  );
endmodule
