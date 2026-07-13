// NEW adapter (Yosys side): exposes the blind-reference PrecedenceSw
// module (mkTop.v, compiled unchanged from refs/PrecedenceSw.bsv) under
// a common port naming convention shared with gate_wrap.v, for equiv_make.
// No logic is added beyond straight port renaming.
module gold_wrap (
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

  mkTop u_gold (
      .CLK(CLK),
      .RST_N(RST_N),
      .swWrite_data(sw_data),
      .swWrite_wstrb(sw_wstrb),
      .EN_swWrite(EN_sw),
      .hwWrite_data(hw_data),
      .EN_hwWrite(EN_hw),
      .rd(val),
      .RDY_rd(),
      .RDY_swWrite(),
      .RDY_hwWrite()
  );
endmodule
