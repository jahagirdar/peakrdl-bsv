// Thin harness wrapper (touches neither side's logic): exposes the same
// comparable port list as gold_top.v mapped onto the generator's
// testcsrreg_reg0_field0 port names. Ties EN_hw_clear=0 / EN_bus_read=0 internally so
// the unmodeled generic hw.clear()/bus.read() boilerplate (not present
// in the blind ref for this config) is never exercised on either side.
module gate_top (
    CLK,
    RST_N,
    swWrite_data,
    swWrite_wstrb,
    EN_swWrite,
    RDY_swWrite,
    hwWrite_data,
    EN_hwWrite,
    RDY_hwWrite,
    hwmask,
    rd,
    RDY_rd
);
  input CLK;
  input RST_N;
  input [7:0] swWrite_data;
  input [7:0] swWrite_wstrb;
  input EN_swWrite;
  output RDY_swWrite;
  input [7:0] hwWrite_data;
  input EN_hwWrite;
  output RDY_hwWrite;
  input [7:0] hwmask;
  output [7:0] rd;
  output RDY_rd;

  wire RDY_hw_clear_unused, RDY_bus_read_unused, RDY_hw__read_unused;
  wire [7:0] hw__read_unused, bus_read_unused;
  wire RDY_currentValue_unused, RDY_set_ext_unused;

  testcsrreg_reg0_field0 u (
      .CLK(CLK),
      .RST_N(RST_N),
      .hw__write_data(hwWrite_data),
      .EN_hw__write(EN_hwWrite),
      .RDY_hw__write(RDY_hwWrite),
      .hw__read(hw__read_unused),
      .RDY_hw__read(RDY_hw__read_unused),
      .EN_hw_clear(1'b0),
      .RDY_hw_clear(RDY_hw_clear_unused),
      .bus_write_data(swWrite_data),
      .bus_write_wstrb(swWrite_wstrb),
      .EN_bus_write(EN_swWrite),
      .RDY_bus_write(RDY_swWrite),
      .EN_bus_read(1'b0),
      .bus_read(bus_read_unused),
      .RDY_bus_read(RDY_bus_read_unused),
      .currentValue(rd),
      .RDY_currentValue(RDY_currentValue_unused),
      .set_ext_top_mask_sig_v(hwmask),
      .EN_set_ext_top_mask_sig(1'b1),
      .RDY_set_ext_top_mask_sig(RDY_set_ext_unused)
  );
  assign RDY_rd = 1'b1;
endmodule
