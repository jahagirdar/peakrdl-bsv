// Thin harness wrapper: sw=rw/hw=r with the anded/ored/xored reduction
// outputs. Common port list = a sw masked-merge write input + stored
// value read (rd) + the three 1-bit reduction outputs. swRead maps to
// the gate's currentValue; anded/ored/xored map to the gate's
// hw_anded/hw_ored/hw_xored.
module gold_top (
    CLK,
    RST_N,
    swWrite_data,
    swWrite_wstrb,
    EN_swWrite,
    rd,
    anded,
    ored,
    xored
);
  input CLK;
  input RST_N;
  input [7:0] swWrite_data;
  input [7:0] swWrite_wstrb;
  input EN_swWrite;
  output [7:0] rd;
  output anded;
  output ored;
  output xored;
  wire RDY_swWrite_u, RDY_swRead_u, RDY_hwRead_u, RDY_anded_u, RDY_ored_u, RDY_xored_u;
  wire [7:0] hwRead_u;
  mkReductions u (
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
      .anded(anded),
      .RDY_anded(RDY_anded_u),
      .ored(ored),
      .RDY_ored(RDY_ored_u),
      .xored(xored),
      .RDY_xored(RDY_xored_u)
  );
endmodule
