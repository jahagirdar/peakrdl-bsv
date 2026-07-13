// Thin harness wrapper: same common port list as gold_top. EN_hw_clear
// tied to 0; bus.read unexercised; currentValue used for rd; hw__read
// maps to the gold hwRead. The gate's hw_pulse output has no blind-
// reference counterpart and is left unconnected.
module gate_top (
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
  wire RDY_hw_pulse_u, RDY_hw__read_u, RDY_hw_clear_u, RDY_bus_write_u, RDY_bus_read_u, RDY_currentValue_u;
  wire hw_pulse_u;
  wire [0:0] bus_read_u;
  testcsrreg_reg0_field0 u (
      .CLK(CLK),
      .RST_N(RST_N),
      .hw_pulse(hw_pulse_u),
      .RDY_hw_pulse(RDY_hw_pulse_u),
      .hw__read(hwrd),
      .RDY_hw__read(RDY_hw__read_u),
      .EN_hw_clear(1'b0),
      .RDY_hw_clear(RDY_hw_clear_u),
      .bus_write_data(swWrite_data),
      .bus_write_wstrb(swWrite_wstrb),
      .EN_bus_write(EN_swWrite),
      .RDY_bus_write(RDY_bus_write_u),
      .EN_bus_read(1'b0),
      .bus_read(bus_read_u),
      .RDY_bus_read(RDY_bus_read_u),
      .currentValue(rd),
      .RDY_currentValue(RDY_currentValue_u)
  );
endmodule
