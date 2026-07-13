module gate_top (
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
    hw_swmod,
    RDY_hw_swmod,
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
  output hw_swmod;
  output RDY_hw_swmod;
  output [7:0] currentValue;
  output RDY_currentValue;

  wire RDY_hw_clear_unused;

  testcsrreg_reg0_field0 u (
      .CLK(CLK),
      .RST_N(RST_N),
      .hw__read(hw_read),
      .RDY_hw__read(RDY_hw_read),
      .hw_swmod(hw_swmod),
      .RDY_hw_swmod(RDY_hw_swmod),
      .EN_hw_clear(1'b0),
      .RDY_hw_clear(RDY_hw_clear_unused),
      .bus_write_data(bus_write_data),
      .bus_write_wstrb(bus_write_wstrb),
      .EN_bus_write(EN_bus_write),
      .RDY_bus_write(RDY_bus_write),
      .EN_bus_read(EN_bus_read),
      .bus_read(bus_read),
      .RDY_bus_read(RDY_bus_read),
      .currentValue(currentValue),
      .RDY_currentValue(RDY_currentValue)
  );
endmodule
