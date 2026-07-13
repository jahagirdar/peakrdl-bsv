module gate_top (
    CLK,
    RST_N,
    swWrite_data,
    swWrite_wstrb,
    EN_swWrite,
    RDY_swWrite,
    hwWrite_data,
    hwWrite_we,
    EN_hwWrite,
    RDY_hwWrite,
    hwenable,
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
  input hwWrite_we;
  input EN_hwWrite;
  output RDY_hwWrite;
  input [7:0] hwenable;
  output [7:0] rd;
  output RDY_rd;

  wire RDY_hw_clear_u, RDY_bus_read_u, RDY_hw__read_u, RDY_currentValue_u;
  wire RDY_set_we_u, RDY_set_en_u;
  wire [7:0] hw__read_u, bus_read_u;

  testcsrreg_reg0_field0 u (
      .CLK(CLK),
      .RST_N(RST_N),
      .hw__write_data(hwWrite_data),
      .EN_hw__write(EN_hwWrite),
      .RDY_hw__write(RDY_hwWrite),
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
      .set_ext_top_we_sig_v(hwWrite_we),
      .EN_set_ext_top_we_sig(1'b1),
      .RDY_set_ext_top_we_sig(RDY_set_we_u),
      .set_ext_top_en_sig_v(hwenable),
      .EN_set_ext_top_en_sig(1'b1),
      .RDY_set_ext_top_en_sig(RDY_set_en_u)
  );
  assign RDY_rd = 1'b1;
endmodule
