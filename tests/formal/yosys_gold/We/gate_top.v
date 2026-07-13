// New thin harness wrapper (touches neither side's logic): exposes the
// same testcsrreg_reg0_field0 port list minus EN_hw_clear/RDY_hw_clear,
// tying EN_hw_clear=0 internally so the unmodeled generic hw.clear()
// boilerplate (not present in the blind ref, since this config's RDL
// has no onclear/hwclr) is never exercised on either side of the SAT
// equivalence check. Instantiates the gold module unchanged.
module gate_top (
    CLK,
    RST_N,
    hw__write_data,
    EN_hw__write,
    RDY_hw__write,
    hw__read,
    RDY_hw__read,
    bus_write_data,
    bus_write_wstrb,
    EN_bus_write,
    RDY_bus_write,
    EN_bus_read,
    bus_read,
    RDY_bus_read,
    currentValue,
    RDY_currentValue,
    set_ext_top_gate_sig_v,
    EN_set_ext_top_gate_sig,
    RDY_set_ext_top_gate_sig
);
  input CLK;
  input RST_N;
  input [7:0] hw__write_data;
  input EN_hw__write;
  output RDY_hw__write;
  output [7:0] hw__read;
  output RDY_hw__read;
  input [7:0] bus_write_data;
  input [7:0] bus_write_wstrb;
  input EN_bus_write;
  output RDY_bus_write;
  input EN_bus_read;
  output [7:0] bus_read;
  output RDY_bus_read;
  output [7:0] currentValue;
  output RDY_currentValue;
  input set_ext_top_gate_sig_v;
  input EN_set_ext_top_gate_sig;
  output RDY_set_ext_top_gate_sig;

  wire RDY_hw_clear_unused;

  testcsrreg_reg0_field0 u (
      .CLK(CLK),
      .RST_N(RST_N),
      .hw__write_data(hw__write_data),
      .EN_hw__write(EN_hw__write),
      .RDY_hw__write(RDY_hw__write),
      .hw__read(hw__read),
      .RDY_hw__read(RDY_hw__read),
      .EN_hw_clear(1'b0),
      .RDY_hw_clear(RDY_hw_clear_unused),
      .bus_write_data(bus_write_data),
      .bus_write_wstrb(bus_write_wstrb),
      .EN_bus_write(EN_bus_write),
      .RDY_bus_write(RDY_bus_write),
      .EN_bus_read(EN_bus_read),
      .bus_read(bus_read),
      .RDY_bus_read(RDY_bus_read),
      .currentValue(currentValue),
      .RDY_currentValue(RDY_currentValue),
      .set_ext_top_gate_sig_v(set_ext_top_gate_sig_v),
      .EN_set_ext_top_gate_sig(EN_set_ext_top_gate_sig),
      .RDY_set_ext_top_gate_sig(RDY_set_ext_top_gate_sig)
  );
endmodule
