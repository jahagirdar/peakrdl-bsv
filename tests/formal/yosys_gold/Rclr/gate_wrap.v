// Thin harness wrapper (touches neither side's logic): exposes the same
// common port set as gold_wrap.v. Ties EN_hw_clear=0 internally so the
// generic hw.clear() boilerplate (not present in the blind ref, since
// this config's RDL has no onclear/hwclr property) is never exercised
// on the generator side of the SAT equivalence check, and leaves
// currentValue() unconnected (not modeled on the blind-ref side either).
// Instantiates testcsrreg_reg0_field0 unchanged.
module gate (
    CLK,
    RST_N,
    EN_read,
    read_data,
    RDY_read,
    write_data,
    EN_write,
    RDY_write
);
  input CLK;
  input RST_N;
  input EN_read;
  output [7:0] read_data;
  output RDY_read;
  input [7:0] write_data;
  input EN_write;
  output RDY_write;

  wire RDY_hw_clear_unused;
  wire [7:0] currentValue_unused;
  wire RDY_currentValue_unused;

  testcsrreg_reg0_field0 u (
      .CLK(CLK),
      .RST_N(RST_N),
      .hw__write_data(write_data),
      .EN_hw__write(EN_write),
      .RDY_hw__write(RDY_write),
      .EN_hw_clear(1'b0),
      .RDY_hw_clear(RDY_hw_clear_unused),
      .EN_bus_read(EN_read),
      .bus_read(read_data),
      .RDY_bus_read(RDY_read),
      .currentValue(currentValue_unused),
      .RDY_currentValue(RDY_currentValue_unused)
  );
endmodule
