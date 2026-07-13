// Thin harness wrapper: same common port list as gold_top. The external
// next signal is driven continuously (EN_set_ext..=1) from `next`. All
// sw/hw write ports are tied off (EN=0) since next overrides them anyway
// and the blind reference models no write path. EN_hw_clear tied to 0;
// bus.read unexercised; currentValue used for rd.
module gate_top (
    CLK,
    RST_N,
    next,
    rd,
    RDY_rd
);
  input CLK;
  input RST_N;
  input [7:0] next;
  output [7:0] rd;
  output RDY_rd;
  wire RDY_hw__write_u, RDY_hw__read_u, RDY_hw_clear_u, RDY_bus_write_u,
       RDY_bus_read_u, RDY_currentValue_u, RDY_set_next_u;
  wire [7:0] hw__read_u, bus_read_u;
  testcsrreg_reg0_field0 u (
      .CLK(CLK),
      .RST_N(RST_N),
      .hw__write_data(8'h00),
      .EN_hw__write(1'b0),
      .RDY_hw__write(RDY_hw__write_u),
      .hw__read(hw__read_u),
      .RDY_hw__read(RDY_hw__read_u),
      .EN_hw_clear(1'b0),
      .RDY_hw_clear(RDY_hw_clear_u),
      .bus_write_data(8'h00),
      .bus_write_wstrb(8'h00),
      .EN_bus_write(1'b0),
      .RDY_bus_write(RDY_bus_write_u),
      .EN_bus_read(1'b0),
      .bus_read(bus_read_u),
      .RDY_bus_read(RDY_bus_read_u),
      .currentValue(rd),
      .RDY_currentValue(RDY_currentValue_u),
      .set_ext_NextOverridesEverything_next_sig_v(next),
      .EN_set_ext_NextOverridesEverything_next_sig(1'b1),
      .RDY_set_ext_NextOverridesEverything_next_sig(RDY_set_next_u)
  );
  assign RDY_rd = 1'b1;
endmodule
