// NEW adapter (Yosys side): exposes the real-generator field module
// (gate_core.v == testcsrreg_reg0_field0, unchanged, reused from
// yosys_eq/precedence_sw/testcsrreg_reg0_field0.v) under the same common
// port naming convention as gold_wrap.v. EN_hw_clear/EN_bus_read are tied
// off (0) since the blind reference does not model those generic/unused
// interface features for this RDL (no hwclr property configured, and
// bus_read has no side effect for this field) -- this is an
// interface-shape bridge only, not a change to either side's update
// logic.
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
