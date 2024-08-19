 typedef struct {
	 } chip_id_reg_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(4) port0;
	 Bit#(4) port1;
	 Bit#(4) port2;
	 Bit#(4) port3;
	 } link_status_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(2) data0;
	 Bit#(2) data1;
	 Bit#(2) data2;
	 Bit#(2) data3;
	 Bit#(2) data4;
	 Bit#(2) data5;
	 Bit#(2) data6;
	 Bit#(2) data7;
	 Bit#(2) data8;
	 Bit#(2) data9;
	 Bit#(2) data10;
	 Bit#(2) data11;
	 Bit#(2) data12;
	 Bit#(2) data13;
	 Bit#(2) data14;
	 Bit#(2) data15;
	 } myRegInst_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(16) port1;
	 Bit#(16) port0;
	 } spi4_pkt_count_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(8) port3;
	 Bit#(8) port2;
	 Bit#(8) port1;
	 Bit#(8) port0;
	 } gige_pkt_count_reg_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } head_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } tail_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bool full;
	 Bool empty;
	 Bool almost_empty;
	 Bool almost_full;
	 } status_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } head_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } tail_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bool full;
	 Bool empty;
	 Bool almost_empty;
	 Bool almost_full;
	 } status_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } head_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } tail_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bool full;
	 Bool empty;
	 Bool almost_empty;
	 Bool almost_full;
	 } status_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } head_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } tail_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bool full;
	 Bool empty;
	 Bool almost_empty;
	 Bool almost_full;
	 } status_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } head_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } tail_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bool full;
	 Bool empty;
	 Bool almost_empty;
	 Bool almost_full;
	 } status_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } head_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } tail_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bool full;
	 Bool empty;
	 Bool almost_empty;
	 Bool almost_full;
	 } status_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } head_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } tail_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bool full;
	 Bool empty;
	 Bool almost_empty;
	 Bool almost_full;
	 } status_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } head_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } tail_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bool full;
	 Bool empty;
	 Bool almost_empty;
	 Bool almost_full;
	 } status_Read_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(2) data0;
	 Bit#(2) data1;
	 Bit#(2) data2;
	 Bit#(2) data3;
	 Bit#(2) data4;
	 Bit#(2) data5;
	 Bit#(2) data6;
	 Bit#(2) data7;
	 Bit#(2) data8;
	 Bit#(2) data9;
	 Bit#(2) data10;
	 Bit#(2) data11;
	 Bit#(2) data12;
	 Bit#(2) data13;
	 Bit#(2) data14;
	 Bit#(2) data15;
	 } regs[0]_Read_st deriving(Bits, Eq, FShow) ;
typedef struct {
}empty_addrmap_Read  deriving(Bits, Eq, FShow) ;
typedef struct {
link_status_Read_st link_status;
myRegInst_Read_st myreginst;
spi4_pkt_count_Read_st spi4_pkt_count;
gige_pkt_count_reg_Read_st gige_pkt_count_reg;
}some_register_map_Read  deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(28) part_num;
	 } chip_id_reg_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(4) port0;
	 Bit#(4) port1;
	 Bit#(4) port2;
	 Bit#(4) port3;
	 } link_status_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(2) data0;
	 Bit#(2) data1;
	 Bit#(2) data2;
	 Bit#(2) data3;
	 Bit#(2) data4;
	 Bit#(2) data5;
	 Bit#(2) data6;
	 Bit#(2) data7;
	 Bit#(2) data8;
	 Bit#(2) data9;
	 Bit#(2) data10;
	 Bit#(2) data11;
	 Bit#(2) data12;
	 Bit#(2) data13;
	 Bit#(2) data14;
	 Bit#(2) data15;
	 } myRegInst_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 } spi4_pkt_count_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 } gige_pkt_count_reg_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } head_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } tail_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bool full;
	 Bool empty;
	 Bool almost_empty;
	 Bool almost_full;
	 } status_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } head_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } tail_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bool full;
	 Bool empty;
	 Bool almost_empty;
	 Bool almost_full;
	 } status_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } head_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } tail_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bool full;
	 Bool empty;
	 Bool almost_empty;
	 Bool almost_full;
	 } status_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } head_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } tail_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bool full;
	 Bool empty;
	 Bool almost_empty;
	 Bool almost_full;
	 } status_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } head_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } tail_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bool full;
	 Bool empty;
	 Bool almost_empty;
	 Bool almost_full;
	 } status_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } head_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } tail_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bool full;
	 Bool empty;
	 Bool almost_empty;
	 Bool almost_full;
	 } status_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } head_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } tail_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bool full;
	 Bool empty;
	 Bool almost_empty;
	 Bool almost_full;
	 } status_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } head_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(32) data;
	 } tail_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bool full;
	 Bool empty;
	 Bool almost_empty;
	 Bool almost_full;
	 } status_Write_st deriving(Bits, Eq, FShow) ;
 typedef struct {
	 Bit#(2) data0;
	 Bit#(2) data1;
	 Bit#(2) data2;
	 Bit#(2) data3;
	 Bit#(2) data4;
	 Bit#(2) data5;
	 Bit#(2) data6;
	 Bit#(2) data7;
	 Bit#(2) data8;
	 Bit#(2) data9;
	 Bit#(2) data10;
	 Bit#(2) data11;
	 Bit#(2) data12;
	 Bit#(2) data13;
	 Bit#(2) data14;
	 Bit#(2) data15;
	 } regs[0]_Write_st deriving(Bits, Eq, FShow) ;
typedef struct {
}empty_addrmap_Write  deriving(Bits, Eq, FShow) ;
typedef struct {
chip_id_reg_Write_st chip_id_reg;
link_status_Write_st link_status;
myRegInst_Write_st myreginst;
}some_register_map_Write  deriving(Bits, Eq, FShow) ;
