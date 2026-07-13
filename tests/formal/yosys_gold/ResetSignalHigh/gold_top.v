// Thin harness wrapper: sw=rw/hw=r field with an async, field-local
// resetsignal domain. The blind ref builds that domain internally from
// setResetCond via the Clocks package (mkReset -> MakeResetA); the
// generator builds an identical MakeResetA domain driven by the
// rst_rstsig_top_rst_sig port. Common port list = a single reset-
// condition input (rstcond) + a sw masked-merge write input + the
// stored value read (rd). rstcond feeds setResetCond_cond with
// EN_setResetCond tied high (per-cycle sampling); the High-polarity
// inversion is baked identically into each side's own generated logic.
module gold_top (
    CLK,
    RST_N,
    rstcond,
    swWrite_data,
    swWrite_wstrb,
    EN_swWrite,
    rd,
    RDY_rd
);
  input CLK;
  input RST_N;
  input rstcond;
  input [7:0] swWrite_data;
  input [7:0] swWrite_wstrb;
  input EN_swWrite;
  output [7:0] rd;
  output RDY_rd;
  wire RDY_setResetCond_u, RDY_swWrite_u, RDY_swRead_u, RDY_hwRead_u;
  wire [7:0] hwRead_u;
  mkResetSignalHigh u (
      .CLK(CLK),
      .RST_N(RST_N),
      .setResetCond_cond(rstcond),
      .EN_setResetCond(1'b1),
      .RDY_setResetCond(RDY_setResetCond_u),
      .swWrite_data(swWrite_data),
      .swWrite_wstrb(swWrite_wstrb),
      .EN_swWrite(EN_swWrite),
      .RDY_swWrite(RDY_swWrite_u),
      .swRead(rd),
      .RDY_swRead(RDY_swRead_u),
      .hwRead(hwRead_u),
      .RDY_hwRead(RDY_hwRead_u)
  );
  assign RDY_rd = 1'b1;
endmodule
