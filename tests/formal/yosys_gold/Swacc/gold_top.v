// Thin harness wrapper: sw=rw/hw=r with the swacc pulse (fires on any
// software access -- a read, or a write with wstrb!=0). Common port
// list = sw write input + a read-enable input (EN_read) + stored value
// read (rd) + the 1-bit swacc pulse. Because swacc pulses on reads too,
// the sw read is a genuine event: gold's ActionValue swRead is driven
// by EN_read; the side-effect-free stored value is taken from gold's
// hwRead. swaccPulse maps to the gate's hw_swacc.
module gold_top (
    CLK,
    RST_N,
    swWrite_data,
    swWrite_wstrb,
    EN_swWrite,
    EN_read,
    rd,
    swacc
);
  input CLK;
  input RST_N;
  input [7:0] swWrite_data;
  input [7:0] swWrite_wstrb;
  input EN_swWrite;
  input EN_read;
  output [7:0] rd;
  output swacc;
  wire RDY_swRead_u, RDY_swWrite_u, RDY_hwRead_u, RDY_swaccPulse_u;
  wire [7:0] swRead_u;
  mkSwacc u (
      .CLK(CLK),
      .RST_N(RST_N),
      .EN_swRead(EN_read),
      .swRead(swRead_u),
      .RDY_swRead(RDY_swRead_u),
      .swWrite_data(swWrite_data),
      .swWrite_wstrb(swWrite_wstrb),
      .EN_swWrite(EN_swWrite),
      .RDY_swWrite(RDY_swWrite_u),
      .hwRead(rd),
      .RDY_hwRead(RDY_hwRead_u),
      .swaccPulse(swacc),
      .RDY_swaccPulse(RDY_swaccPulse_u)
  );
endmodule
