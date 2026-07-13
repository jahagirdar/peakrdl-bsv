// Thin harness wrapper: same common port list as gold_top. hw__write
// (the OR-merging intr hw write path) takes the hw-write input;
// bus.write takes the woclr sw write. EN_hw_clear tied to 0; bus.read
// unexercised; currentValue used for rd.
module gate_top (
    CLK,
    RST_N,
    hwWrite_data,
    EN_hwWrite,
    swWrite_data,
    swWrite_wstrb,
    EN_swWrite,
    rd,
    RDY_rd
);
  input CLK;
  input RST_N;
  input [7:0] hwWrite_data;
  input EN_hwWrite;
  input [7:0] swWrite_data;
  input [7:0] swWrite_wstrb;
  input EN_swWrite;
  output [7:0] rd;
  output RDY_rd;
  wire RDY_hw__write_u, RDY_hw_clear_u, RDY_bus_write_u, RDY_bus_read_u, RDY_currentValue_u;
  wire [7:0] bus_read_u;
  testcsrreg_reg0_field0 u (
      .CLK(CLK),
      .RST_N(RST_N),
      .hw__write_data(hwWrite_data),
      .EN_hw__write(EN_hwWrite),
      .RDY_hw__write(RDY_hw__write_u),
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
  assign RDY_rd = 1'b1;
endmodule
