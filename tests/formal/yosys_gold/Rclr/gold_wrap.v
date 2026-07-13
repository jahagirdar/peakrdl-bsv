// Thin harness wrapper (touches neither side's logic): exposes a common
// port set (EN_read/read_data/RDY_read, write_data/EN_write/RDY_write)
// so gold (blind ref) and gate (generator) can be compared directly by
// Yosys equiv_make, despite their differing native BSV interface method
// names (swRead/hwWrite vs bus.read/hw._write). Instantiates mkGoldTop
// unchanged.
module gold (
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

  mkGoldTop u (
      .CLK(CLK),
      .RST_N(RST_N),
      .EN_swRead(EN_read),
      .swRead(read_data),
      .RDY_swRead(RDY_read),
      .hwWrite_data(write_data),
      .EN_hwWrite(EN_write),
      .RDY_hwWrite(RDY_write)
  );
endmodule
