"""Toplevel CSR Module generator."""
from systemrdl import RDLListener
import math


class PrintBSVCSR(RDLListener):
    """Class to write the CSR module."""

    def __init__(self, bsvfile):
        """Initialization."""
        self.file = bsvfile
        self.addressmap = []
        self.regwidth = []

    def enter_Addrmap(self, node):
        """Addressmap handler."""
        self.addrmap_name = node.get_path_segment()
        print(f"import {self.addrmap_name}_reg::*;", file=self.file)
        self.interface = ""
        self.instance = ""
        self.method = ""
        self.write_method = ""
        self.read_method = ""
        self.addressmap.append(node.get_path_segment())

    def enter_Reg(self, node):
        """Reg Handler."""
        # print(node.inst.__dict__)
        self.reg_name = node.get_path_segment()
        self.hier_path = [*self.addressmap, self.reg_name]
        self.regwidth.append(node.inst.properties["regwidth"])
        self.interface += (
            f"interface ConfigReg_HW_{self.reg_name} {self.reg_name.lower()};\n"
        )
        self.instance += f"ConfigReg_{self.reg_name} reg_{self.reg_name} <- mkConfigReg_{self.reg_name}();\n"
        self.method += f"interface ConfigReg_HW_{self.reg_name} {self.reg_name.lower()} = reg_{self.reg_name}.hw;\n"
        self.write_method += (
            f"if(address== {node.address_offset})reg_{self.reg_name}.bus.write(data);\n"
        )
        self.read_method += (
            f"if(address== {node.address_offset})rv<-reg_{self.reg_name}.bus.read();\n"
        )

    def exit_Addrmap(self, node):
        """Write code for addressmap."""
        # print(node.__dict__,node.__dir__(),node.inst.properties)
        # print(self.regwidth)
        # for i in node.__dir__():
        #     print(i,getattr(node,i))
        addr_width = math.ceil(math.log(node.total_size, 2))
        data_width = max(self.regwidth)
        print(
            f"""
interface ConfigCSR_{self.addrmap_name};
    {self.interface}
    method Action write(Bit#({addr_width}) address, Bit#({data_width}) data);
    method ActionValue#(Bit#({data_width})) read(Bit#({addr_width}) address);
endinterface

(*synthesize*)
module mkConfigCSR_{self.addrmap_name}(ConfigCSR_{self.addrmap_name});
    {self.instance}
    {self.method}
    method Action write(Bit#({addr_width}) address,Bit#({data_width}) data);
    {self.write_method}
    endmethod
    method ActionValue#(Bit#({data_width})) read(Bit#({addr_width}) address);
        let rv=0;
    {self.read_method}
    return rv;
    endmethod
endmodule
                  """,
            file=self.file,
        )
