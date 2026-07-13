module gate_wrap (
    CLK,
    RST_N,
    sw_data,
    sw_wstrb,
    EN_sw,
    hw_data,
    EN_hw,
    val
);
  input CLK, RST_N;
  input [7:0] sw_data, sw_wstrb, hw_data;
  input EN_sw, EN_hw;
  output [7:0] val;

  testcsrreg_reg0_field0 u_gate (
      .CLK(CLK),
      .RST_N(RST_N),
      .hw__write_data(hw_data),
      .EN_hw__write(EN_hw),
      .RDY_hw__write(),
      .hw__read(),
      .RDY_hw__read(),
      .EN_hw_clear(1'b0),
      .RDY_hw_clear(),
      .bus_write_data(sw_data),
      .bus_write_wstrb(sw_wstrb),
      .EN_bus_write(EN_sw),
      .RDY_bus_write(),
      .EN_bus_read(1'b0),
      .bus_read(),
      .RDY_bus_read(),
      .currentValue(val),
      .RDY_currentValue()
  );
endmodule
