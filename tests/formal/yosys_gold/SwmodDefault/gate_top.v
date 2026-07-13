// Thin harness wrapper: same common port list as gold_top. EN_hw_clear
// tied to 0; bus.read unexercised; currentValue used for rd; hw_swmod
// maps to the gold swmod pulse.
module gate_top (
    CLK,
    RST_N,
    swWrite_data,
    swWrite_wstrb,
    EN_swWrite,
    rd,
    swmod
);
  input CLK;
  input RST_N;
  input [7:0] swWrite_data;
  input [7:0] swWrite_wstrb;
  input EN_swWrite;
  output [7:0] rd;
  output swmod;
  wire RDY_hw_swmod_u, RDY_hw__read_u, RDY_hw_clear_u, RDY_bus_write_u, RDY_bus_read_u, RDY_currentValue_u;
  wire [7:0] hw__read_u, bus_read_u;
  testcsrreg_reg0_field0 u (
      .CLK(CLK),
      .RST_N(RST_N),
      .hw_swmod(swmod),
      .RDY_hw_swmod(RDY_hw_swmod_u),
      .hw__read(hw__read_u),
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
