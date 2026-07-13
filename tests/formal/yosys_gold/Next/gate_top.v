// hw._write is tied off (EN=0) since the blind reference deliberately
// omits a hw write method for this config (next overrides it anyway,
// so it's moot) -- consistent with the Next.bsv header comment.
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

  wire RDY_hw_write_unused;
  wire [7:0] hw_read_unused;
  wire RDY_hw_read_unused;
  wire RDY_hw_clear_unused;
  wire [7:0] bus_read_unused;
  wire RDY_bus_read_unused;
  wire RDY_set_next_unused;

  testcsrreg_reg0_field0 u (
      .CLK(CLK),
      .RST_N(RST_N),
      .hw__write_data(8'h00),
      .EN_hw__write(1'b0),
      .RDY_hw__write(RDY_hw_write_unused),
      .hw__read(hw_read_unused),
      .RDY_hw__read(RDY_hw_read_unused),
      .EN_hw_clear(1'b0),
      .RDY_hw_clear(RDY_hw_clear_unused),
      .EN_bus_read(1'b1),
      .bus_read(bus_read_unused),
      .RDY_bus_read(RDY_bus_read_unused),
      .currentValue(rd),
      .RDY_currentValue(RDY_rd),
      .set_ext_Next_next_sig_v(next),
      .EN_set_ext_Next_next_sig(1'b1),
      .RDY_set_ext_Next_next_sig(RDY_set_next_unused)
  );
endmodule
