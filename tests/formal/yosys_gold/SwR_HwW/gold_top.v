// Thin harness wrapper (touches neither side's logic): sw=r/hw=w
// config. Common port list = a hw-write input + the stored value read
// out (rd). The blind ref's plain value method swRead maps to the gate
// side's currentValue (both are a side-effect-free read of the same
// stored value).
module gold_top (
    CLK,
    RST_N,
    EN_hwWrite,
    hwWrite_data,
    rd,
    RDY_rd
);
  input CLK;
  input RST_N;
  input EN_hwWrite;
  input [7:0] hwWrite_data;
  output [7:0] rd;
  output RDY_rd;
  wire RDY_swRead_u, RDY_hwWrite_u;
  mkSwR_HwW u (
      .CLK(CLK),
      .RST_N(RST_N),
      .swRead(rd),
      .RDY_swRead(RDY_swRead_u),
      .hwWrite_data(hwWrite_data),
      .EN_hwWrite(EN_hwWrite),
      .RDY_hwWrite(RDY_hwWrite_u)
  );
  assign RDY_rd = 1'b1;
endmodule
