// Thin harness wrapper: sw=rw/hw=r with the swmod pulse (fires only on
// a software write that actually changes the stored value). Common port
// list = a sw masked-merge write input + stored value read (rd) + the
// 1-bit swmod pulse. No read side effect for this config, so no read
// enable is exercised.
module gold_top (
    CLK,
    RST_N,
    swWrite_data,
    swWrite_wstrb,
    EN_swWrite,
    rd,
    swmod
);
  input CLK;
  input RST_N;
  input [7:0] swWrite_data;
  input [7:0] swWrite_wstrb;
  input EN_swWrite;
  output [7:0] rd;
  output swmod;
  wire RDY_swWrite_u, RDY_swRead_u, RDY_hwRead_u, RDY_swmodPulse_u;
  wire [7:0] hwRead_u;
  mkSwmodDefault u (
      .CLK(CLK),
      .RST_N(RST_N),
      .swWrite_data(swWrite_data),
      .swWrite_wstrb(swWrite_wstrb),
      .EN_swWrite(EN_swWrite),
      .RDY_swWrite(RDY_swWrite_u),
      .swRead(rd),
      .RDY_swRead(RDY_swRead_u),
      .hwRead(hwRead_u),
      .RDY_hwRead(RDY_hwRead_u),
      .swmodPulse(swmod),
      .RDY_swmodPulse(RDY_swmodPulse_u)
  );
endmodule
