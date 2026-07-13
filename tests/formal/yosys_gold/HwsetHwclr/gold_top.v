// Thin harness wrapper (touches neither side's logic): exposes a
// common comparable port list for gold (blind ref) vs gate
// (generator). swRead/hwRead on the gold side map to currentValue/
// hw__read on the gate side (both are plain value reads of the same
// stored value for this sw=r/hw=r config).
module gold_top (
    CLK,
    RST_N,
    EN_hwset,
    RDY_hwset,
    EN_hwclr,
    RDY_hwclr,
    swRead,
    RDY_swRead,
    hwRead,
    RDY_hwRead
);
  input CLK;
  input RST_N;
  input EN_hwset;
  output RDY_hwset;
  input EN_hwclr;
  output RDY_hwclr;
  output [7:0] swRead;
  output RDY_swRead;
  output [7:0] hwRead;
  output RDY_hwRead;

  mkHwsetHwclr u (
      .CLK(CLK),
      .RST_N(RST_N),
      .EN_pulseHwset(EN_hwset),
      .RDY_pulseHwset(RDY_hwset),
      .EN_pulseHwclr(EN_hwclr),
      .RDY_pulseHwclr(RDY_hwclr),
      .swRead(swRead),
      .RDY_swRead(RDY_swRead),
      .hwRead(hwRead),
      .RDY_hwRead(RDY_hwRead)
  );
endmodule
