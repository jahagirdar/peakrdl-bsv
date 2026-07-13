// Thin harness wrapper: sw=r (onread=rset)/hw=w. The software read has a
// storage side effect (sets the field to all-ones after returning the
// pre-effect value), so it is a genuine event driven by a common
// read-enable input (EN_read). The compared output rd is the read's
// returned value. hw writes come in via a hw-write input.
module gold_top (
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
  wire RDY_swRead_u, RDY_hwWrite_u;
  mkRset u (
      .CLK(CLK),
      .RST_N(RST_N),
      .EN_swRead(EN_read),
      .swRead(rd),
      .RDY_swRead(RDY_swRead_u),
      .hwWrite_data(hwWrite_data),
      .EN_hwWrite(EN_hwWrite),
      .RDY_hwWrite(RDY_hwWrite_u)
  );
  assign RDY_rd = 1'b1;
endmodule
