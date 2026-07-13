// Thin harness wrapper: same common port list as gold_top. rstcond
// drives the generator's rst_rstsig_top_rst_sig async reset input.
// EN_hw_clear tied to 0; bus.read unexercised; currentValue used for
// rd; hw__read redundant.
module gate_top (
    CLK,
    RST_N,
    rstcond,
    swWrite_data,
    swWrite_wstrb,
    EN_swWrite,
    rd,
    RDY_rd
);
  input CLK;
  input RST_N;
  input rstcond;
  input [7:0] swWrite_data;
  input [7:0] swWrite_wstrb;
  input EN_swWrite;
  output [7:0] rd;
  output RDY_rd;
  wire [7:0] hw__read_u, bus_read_u;
  wire RDY_hw__read_u, RDY_hw_clear_u, RDY_bus_write_u, RDY_bus_read_u, RDY_currentValue_u;
  testcsrreg_reg0_field0 u (
      .rst_rstsig_top_rst_sig(rstcond),
      .CLK(CLK),
      .RST_N(RST_N),
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
  assign RDY_rd = 1'b1;
endmodule
