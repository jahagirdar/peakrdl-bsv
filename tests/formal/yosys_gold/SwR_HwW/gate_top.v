// Thin harness wrapper: exposes the same common port list as gold_top.
// The generic hw.clear() boilerplate (EN_hw_clear) is tied to 0
// (unmodeled on the blind-reference side). bus.read is unexercised
// (sw=r has no read side effect for this config); currentValue is used
// as the stored-value read instead.
module gate_top (
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
  wire RDY_hw__write_u, RDY_hw_clear_u, RDY_bus_read_u, RDY_currentValue_u;
  wire [7:0] bus_read_u;
  testcsrreg_reg0_field0 u (
      .CLK(CLK),
      .RST_N(RST_N),
      .hw__write_data(hwWrite_data),
      .EN_hw__write(EN_hwWrite),
      .RDY_hw__write(RDY_hw__write_u),
      .EN_hw_clear(1'b0),
      .RDY_hw_clear(RDY_hw_clear_u),
      .EN_bus_read(1'b0),
      .bus_read(bus_read_u),
      .RDY_bus_read(RDY_bus_read_u),
      .currentValue(rd),
      .RDY_currentValue(RDY_currentValue_u)
  );
  assign RDY_rd = 1'b1;
endmodule
