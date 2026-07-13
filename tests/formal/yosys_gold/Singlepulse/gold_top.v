// Thin harness wrapper: 1-bit sw=rw/hw=r singlepulse field. Common port
// list = a 1-bit sw masked-merge write input + the stored value read
// out (rd, 1 bit). swRead maps to the gate's currentValue; the hw-side
// read (gold hwRead) maps to the gate's hw__read. The gate's separate
// hw_pulse output has no blind-reference counterpart and is left
// unused (this check verifies the storage/auto-clear behavior).
module gold_top (
    CLK,
    RST_N,
    swWrite_data,
    swWrite_wstrb,
    EN_swWrite,
    rd,
    hwrd
);
  input CLK;
  input RST_N;
  input [0:0] swWrite_data;
  input [0:0] swWrite_wstrb;
  input EN_swWrite;
  output [0:0] rd;
  output [0:0] hwrd;
  wire RDY_swWrite_u, RDY_swRead_u, RDY_hwRead_u;
  mkSinglepulse u (
      .CLK(CLK),
      .RST_N(RST_N),
      .swWrite_data(swWrite_data),
      .swWrite_wstrb(swWrite_wstrb),
      .EN_swWrite(EN_swWrite),
      .RDY_swWrite(RDY_swWrite_u),
      .swRead(rd),
      .RDY_swRead(RDY_swRead_u),
      .hwRead(hwrd),
      .RDY_hwRead(RDY_hwRead_u)
  );
endmodule
