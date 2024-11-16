from systemrdl import RDLListener


class PrintBSVCSR(RDLListener):
    def __init__(self, bsvfile):
        self.file = bsvfile
        self.addressmap = []

    def enter_Addrmap(self, node):
        self.addrmap_name = node.get_path_segment()
        print(f"import {self.addrmap_name}_reg::*;", file=self.file)
        self.interface = ""
        self.instance = ""
        self.method = ""
        self.write_method = ""
        self.read_method = ""
        self.addressmap.append(node.get_path_segment())

    def enter_Reg(self, node):
        # print(node.inst.__dict__)
        self.reg_name = node.get_path_segment()
        self.hier_path = [*self.addressmap, self.reg_name]
        self.interface += f"interface ConfigReg_HW_{self.reg_name} {self.reg_name.lower()};\n"
        self.instance += f"ConfigReg_{self.reg_name} reg_{self.reg_name} <- mkConfigReg_{self.reg_name}();\n"
        self.method += f"interface ConfigReg_HW_{self.reg_name} {self.reg_name.lower()} = reg_{self.reg_name}.hw;\n"
        self.write_method += f'if(address== {node.address_offset})reg_{self.reg_name}.bus.write(data);\n'
        self.read_method += f'if(address== {node.address_offset})rv<-reg_{self.reg_name}.bus.read();\n'

    def exit_Addrmap(self, node):
        # print(node,node.inst.properties)
        print(
            f"""
interface ConfigCSR_{self.addrmap_name};
    {self.interface}
    method Action write(Bit#(32) address, Bit#(32) data);
    method ActionValue#(Bit#(32)) read(Bit#(32) address);
endinterface

(*synthesize*)
module mkConfigCSR_{self.addrmap_name}(ConfigCSR_{self.addrmap_name});
    {self.instance}
    {self.method}
    method Action write(Bit#(32) address,Bit#(32) data);
    {self.write_method}
    endmethod
    method ActionValue#(Bit#(32)) read(Bit#(32) address);
        let rv=0;
    {self.read_method}
    return rv;
    endmethod
endmodule
                  """,
            file=self.file,
        )
