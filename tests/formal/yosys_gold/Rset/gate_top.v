// Thin harness wrapper: same common port list as gold_top. EN_read
// drives the gate's bus.read (whose rset side effect sets the field to
// all-ones). The compared output rd is the read's returned value
// (bus_read). currentValue (a plain side-effect-free read) has no blind-
// reference counterpart and is left unused. EN_hw_clear tied to 0.
module gate_top (
    CLK,
    RST_N,
    hwWrite_data,
    EN_hwWrite,
    EN_read,
    rd,
    RDY_rd
);
  input CLK;
  input RST_N;
  input [7:0] hwWrite_data;
  input EN_hwWrite;
  input EN_read;
  output [7:0] rd;
  output RDY_rd;
  wire RDY_hw__write_u, RDY_hw_clear_u, RDY_bus_read_u, RDY_currentValue_u;
  wire [7:0] currentValue_u;
  testcsrreg_reg0_field0 u (
      .CLK(CLK),
      .RST_N(RST_N),
      .hw__write_data(hwWrite_data),
      .EN_hw__write(EN_hwWrite),
      .RDY_hw__write(RDY_hw__write_u),
      .EN_hw_clear(1'b0),
      .RDY_hw_clear(RDY_hw_clear_u),
      .EN_bus_read(EN_read),
      .bus_read(rd),
      .RDY_bus_read(RDY_bus_read_u),
      .currentValue(currentValue_u),
      .RDY_currentValue(RDY_currentValue_u)
  );
  assign RDY_rd = 1'b1;
endmodule
