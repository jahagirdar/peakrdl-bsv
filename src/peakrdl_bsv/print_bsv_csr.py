"""Toplevel CSR Module generator."""
from systemrdl import RDLListener
import math


class PrintBSVCSR(RDLListener):
    """Class to write the CSR module."""

    def __init__(self, bsvfile, test):
        """Initialization."""
        self.file = bsvfile
        self.gentest = test
        self.addressmap = []
        self.regwidth = []

    def enter_Addrmap(self, node):
        """Addressmap handler."""
        self.addrmap_name = node.get_path_segment()
        print(f"import Vector::*;\nimport {self.addrmap_name}_reg::*;", file=self.file)
        self.interface = ""
        self.instance = ""
        self.method = ""
        self.write_method = ""
        self.read_method = ""
        self.address_alias = ""
        self.addressmap.append(node.get_path_segment())
        self.addr_width = math.ceil(math.log(node.total_size, 2))

    def enter_Reg(self, node):
        """Reg Handler."""
        # print(node.inst.__dict__)
        self.reg_name = node.get_path_segment()
        self.hier_path = [*self.addressmap, self.reg_name]
        self.regwidth.append(node.inst.properties["regwidth"])
        self.address_alias += f"Bit#({self.addr_width}) address_{self.reg_name} = {node.address_offset};\n"
        self.interface += (
            f"interface ConfigReg_HW_{self.reg_name} {self.reg_name.lower()};\n"
        )
        self.instance += f"ConfigReg_{self.reg_name} reg_{self.reg_name} <- mkConfigReg_{self.reg_name}();\n"
        self.method += f"interface ConfigReg_HW_{self.reg_name} {self.reg_name.lower()} = reg_{self.reg_name}.hw;\n"
        self.write_method += f"if(address== address_{self.reg_name})reg_{self.reg_name}.bus.write(data,wstrb_expanded);\n"
        self.read_method += f"if(address== address_{self.reg_name})rv<-reg_{self.reg_name}.bus.read();\n"

    def exit_Addrmap(self, node):
        """Write code for addressmap."""
        self.data_width = max(self.regwidth)
        print(
            f"""
interface ConfigCSR_{self.addrmap_name};
    {self.interface}
    method Action write(Bit#({self.addr_width}) address, Bit#({self.data_width}) data, Bit#({self.data_width//8}) wstrb);
    method ActionValue#(Bit#({self.data_width})) read(Bit#({self.addr_width}) address);
endinterface
{self.address_alias}

(*synthesize*)
module mkConfigCSR_{self.addrmap_name}(ConfigCSR_{self.addrmap_name});
    {self.instance}
    {self.method}
    method Action write(Bit#({self.addr_width}) address,Bit#({self.data_width}) data,Bit#({self.data_width//8}) wstrb);
     Vector#({self.data_width//8},Bit#(1)) wstrb_bin= unpack(wstrb);
     Vector#({self.data_width},Bit#(1)) wstrb_bin_{self.data_width}= concat(map(replicate,wstrb_bin));
     Bit#({self.data_width}) wstrb_expanded=pack(wstrb_bin_{self.data_width});

    {self.write_method}
    endmethod
    method ActionValue#(Bit#({self.data_width})) read(Bit#({self.addr_width}) address);
        let rv=0;
    {self.read_method}
    return rv;
    endmethod
endmodule
                  """,
            file=self.file,
        )
