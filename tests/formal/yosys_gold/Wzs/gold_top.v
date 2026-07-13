// Thin harness wrapper (touches neither side's logic): exposes a common
// port list for Yosys SEC. Instantiates the gold (blind-ref) module,
// generated from GoldWzs.bsv, unchanged.
module gold_top (
    CLK,
    RST_N,
    bus_write_data,
    bus_write_wstrb,
    EN_bus_write,
    RDY_bus_write,
    EN_bus_read,
    bus_read,
    RDY_bus_read,
    hw_read,
    RDY_hw_read,
    currentValue,
    RDY_currentValue
);
  input CLK;
  input RST_N;
  input [7:0] bus_write_data;
  input [7:0] bus_write_wstrb;
  input EN_bus_write;
  output RDY_bus_write;
  input EN_bus_read;
  output [7:0] bus_read;
  output RDY_bus_read;
  output [7:0] hw_read;
  output RDY_hw_read;
  output [7:0] currentValue;
  output RDY_currentValue;

  mkGoldWzs u (
      .CLK(CLK),
      .RST_N(RST_N),
      .bus_write_data(bus_write_data),
      .bus_write_wstrb(bus_write_wstrb),
      .EN_bus_write(EN_bus_write),
      .RDY_bus_write(RDY_bus_write),
      .EN_bus_read(EN_bus_read),
      .bus_read(bus_read),
      .RDY_bus_read(RDY_bus_read),
      .hw_read(hw_read),
      .RDY_hw_read(RDY_hw_read),
      .currentValue(currentValue),
      .RDY_currentValue(RDY_currentValue)
  );
endmodule
