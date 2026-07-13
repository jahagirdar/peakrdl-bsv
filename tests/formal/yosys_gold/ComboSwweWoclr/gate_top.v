module gate_top (
    CLK,
    RST_N,
    swWrite_data,
    swWrite_wstrb,
    swWrite_swwe,
    EN_swWrite,
    RDY_swWrite,
    rd,
    RDY_rd
);
  input CLK;
  input RST_N;
  input [7:0] swWrite_data;
  input [7:0] swWrite_wstrb;
  input swWrite_swwe;
  input EN_swWrite;
  output RDY_swWrite;
  output [7:0] rd;
  output RDY_rd;

  wire RDY_hw_clear_u, RDY_bus_read_u, RDY_hw__read_u, RDY_currentValue_u, RDY_set_ext_u;
  wire [7:0] hw__read_u, bus_read_u;

  testcsrreg_reg0_field0 u (
      .CLK(CLK),
      .RST_N(RST_N),
      .hw__read(hw__read_u),
      .RDY_hw__read(RDY_hw__read_u),
      .EN_hw_clear(1'b0),
      .RDY_hw_clear(RDY_hw_clear_u),
      .bus_write_data(swWrite_data),
      .bus_write_wstrb(swWrite_wstrb),
      .EN_bus_write(EN_swWrite),
      .RDY_bus_write(RDY_swWrite),
      .EN_bus_read(1'b0),
      .bus_read(bus_read_u),
      .RDY_bus_read(RDY_bus_read_u),
      .currentValue(rd),
      .RDY_currentValue(RDY_currentValue_u),
      .set_ext_top_swwe_sig_v(swWrite_swwe),
      .EN_set_ext_top_swwe_sig(1'b1),
      .RDY_set_ext_top_swwe_sig(RDY_set_ext_u)
  );
  assign RDY_rd = 1'b1;
endmodule
