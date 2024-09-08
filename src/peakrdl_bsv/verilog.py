from systemrdl import RDLListener
class PrintVerilog(RDLListener):
    axi_port='''
input clk ,
input arst_n ,
output s_axil_awready,
input  s_axil_awvalid,
input [4:0]  s_axil_awaddr  ,
input [2:0]  s_axil_awprot  ,
output s_axil_wready,
input  s_axil_wvalid,
input  [31:0] s_axil_wdata ,
input  [3:0] s_axil_wstrb ,
input  s_axil_bready,
output s_axil_bvalid,
output [1:0]  s_axil_bresp  ,
output s_axil_arready,
input  s_axil_arvalid,
input  [4:0] s_axil_araddr  ,
input  [2:0] s_axil_arprot  ,
input  s_axil_rready,
output s_axil_rvalid,
output [31:0]  s_axil_rdata,
output [1:0]   s_axil_rresp,
                '''
    def __init__(self,verilogfile):
        self.vfile=verilogfile
        self.m=''
        self.wires=''
        self.inst=''
    def enter_Addrmap(self,node):
        name=node.get_path_segment()
        self.m=f'module {name}_blasted (\n{self.axi_port}\n'
        self.inst=f'{name} U{name}(.*);\n'
        self.wires=f'{name}_pkg::{name}__in_t hwif_in;\n{name}_pkg::{name}__out_t hwif_out;\n'
    def enter_Reg(self,node):
        self.rname=node.get_path_segment()
    def exit_Addrmap(self,node):
        name=node.get_path_segment()
        self.vfile.write(f'{self.m[:-2]}); {self.wires} {self.inst}\nendmodule//{name}\n')

    def enter_Field(self,node):
        signame=node.get_path_segment()
        if node.is_hw_readable:
            self.m+= f'output wire [{node.high} : {node.low}] {self.rname}_{signame}_value,\n'
            self.wires+=f'assign  {self.rname}_{signame}_value=hwif_out.{self.rname}.{signame}.value;\n'
        if 'swacc' in node.inst.properties:
            self.m+= f'output wire {self.rname}_{signame}_swacc,\n'
            self.wires+=f'assign  {self.rname}_{signame}_swacc=hwif_out.{self.rname}.{signame}.swacc;\n'
        if 'swmod' in node.inst.properties:
            self.m+= f'output wire {self.rname}_{signame}_swmod,\n'
            self.wires+=f'assign  {self.rname}_{signame}_swmod=hwif_out.{self.rname}.{signame}.swmod;\n'
        if 'anded' in node.inst.properties:
            self.m+= f'output wire {self.rname}_{signame}_anded,\n'
            self.wires+=f'assign  {self.rname}_{signame}_anded=hwif_out.{self.rname}.{signame}.anded;\n'
        if 'ored' in node.inst.properties:
            self.m+= f'output wire {self.rname}_{signame}_ored,\n'
            self.wires+=f'assign  {self.rname}_{signame}_ored=hwif_out.{self.rname}.{signame}.ored;\n'
        if 'xored' in node.inst.properties:
            self.m+= f'output wire {self.rname}_{signame}_xored,\n'
            self.wires+=f'assign  {self.rname}_{signame}_xored=hwif_out.{self.rname}.{signame}.xored;\n'
        if 'interrupt' in node.inst.properties:
            self.m+= f'output wire {self.rname}_{signame}_intr,\n'
            self.wires+=f'assign  {self.rname}_{signame}_intr=hwif_out.{self.rname}.{signame}.intr;\n'

        if node.is_hw_writable:
            self.m+= f'input wire [{node.high}:{node.low}] {self.rname}_{signame}_next,\n'
            self.wires+=f'assign  hwif_in.{self.rname}.{signame}.next={self.rname}_{signame}_next;\n'

        if 'swwe' in node.inst.properties:
            self.m+= f'input wire {self.rname}_{signame}_swwe,\n'
            self.wires+=f'assign  hwif_in.{self.rname}.{signame}.swwe={self.rname}_{signame}_swwe;\n'
        if 'swwel' in node.inst.properties:
            self.m+= f'input wire {self.rname}_{signame}_swwel,\n'
            self.wires+=f'assign  hwif_in.{self.rname}.{signame}.swwel={self.rname}_{signame}_swwel;\n'

