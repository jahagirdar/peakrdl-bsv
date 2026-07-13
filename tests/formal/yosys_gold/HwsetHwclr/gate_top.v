// Thin harness wrapper (touches neither side's logic): exposes the
// same comparable port list as gold_top. The generic hw.clear()
// boilerplate (EN_hw_clear) is tied to 0 (unexercised, consistent with
// the blind reference which has no onclear/hwclr-independent clear
// path beyond the explicit hwclr already modeled). bus.read's EN is
// tied to 1 (sw=r has no side effect on read for this config, so this
// is always safe to fire) but its output is left unconnected at the
// top level -- currentValue is used instead, matching gold's swRead
// which is a plain value read.
module gate_top (
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

  wire RDY_hw_clear_unused;
  wire [7:0] bus_read_unused;
  wire RDY_bus_read_unused;

  testcsrreg_reg0_field0 u (
      .CLK(CLK),
      .RST_N(RST_N),
      .EN_hw_hwset(EN_hwset),
      .RDY_hw_hwset(RDY_hwset),
      .EN_hw_hwclr(EN_hwclr),
      .RDY_hw_hwclr(RDY_hwclr),
      .hw__read(hwRead),
      .RDY_hw__read(RDY_hwRead),
      .EN_hw_clear(1'b0),
      .RDY_hw_clear(RDY_hw_clear_unused),
      .EN_bus_read(1'b1),
      .bus_read(bus_read_unused),
      .RDY_bus_read(RDY_bus_read_unused),
      .currentValue(swRead),
      .RDY_currentValue(RDY_swRead)
  );
endmodule
