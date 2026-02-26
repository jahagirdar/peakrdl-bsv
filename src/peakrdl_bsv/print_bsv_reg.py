"""Write Bluespec Register file."""
from systemrdl import RDLListener


class PrintBSVReg(RDLListener):
    """Write Register defination file."""

    def __init__(self, bsvfile, test):
        """Initialize."""
        self.file = bsvfile
        self.gentest = test
        self.addressmap = []

    def enter_Addrmap(self, node):
        """Addressmap Handler."""
        self.addrmap_name = node.get_path_segment()
        print(f"import {self.addrmap_name}_signal::*;", file=self.file)
        self.addressmap.append(node.get_path_segment())

    def enter_Reg(self, node):
        """RegHandler."""
        self.reg_name = node.get_path_segment()
        self.hier_path = [*self.addressmap, self.reg_name]
        self.interface = ""
        self.reg_val = []
        self.instance = ""
        self.method = ""
        self.write_method = "//write methods\n"
        self.read_method = "//read methods\n"

    def enter_Field(self, node):
        """Field Handler."""
        self.signal_name = node.get_path_segment()
        reset = "0"
        if "reset" in node.inst.properties:
            reset = node.inst.properties["reset"]
        self.interface += (
            f"interface HW_{self.reg_name}_{self.signal_name} s{self.signal_name};\n"
        )
        self.instance += f"Ifc_CSRSignal_{self.reg_name}_{self.signal_name} sig_{self.signal_name} <- mkCSRSignal_{self.reg_name}_{self.signal_name}({reset});\n"
        self.method += f"interface HW_{self.reg_name}_{self.signal_name} s{self.signal_name} = sig_{self.signal_name}.hw;\n"
        if node.is_sw_writable:
            self.write_method += f"sig_{self.signal_name}.bus.write(data[{node.high}:{node.low}],wstrb[{node.high}:{node.low}]);\n"
        # print(
        #     self.reg_name,
        #     self.signal_name,
        #     node.is_sw_writable,
        #     node.is_sw_readable,
        #     node.inst.properties,
        # )
        if node.is_sw_readable:
            self.read_method += f"let var_{self.signal_name}<-sig_{self.signal_name}.bus.read();\nrv[{node.high}:{node.low}]=var_{self.signal_name};\n"
        if node.is_hw_readable:
            self.reg_val.append((f"sig_{self.signal_name}.hw", node.high, node.low))
        else:
            self.reg_val.append((f"{node.width}'b0", node.high, node.low))

    def exit_Reg(self, node):
        """Write out register file."""
        width = node.inst.properties["regwidth"]
        value_method = []
        value_method.append("let rv=0;")
        for r in self.reg_val:
            value_method.append(f"rv[{r[1]}:{r[2]}]={r[0]};")
        value_method_joined = "\n".join(value_method)
        print(
            f"""
interface ConfigReg_HW_{self.reg_name};
    {self.interface}
    method Bit#({width}) value();

endinterface

interface ConfigReg_Bus_{self.reg_name};
    method Action write( Bit#({width}) data,Bit#({width})wstrb);
    method ActionValue#(Bit#({width})) read();
endinterface

interface ConfigReg_{self.reg_name};
interface ConfigReg_HW_{self.reg_name} hw;
interface ConfigReg_Bus_{self.reg_name} bus;
endinterface
module mkConfigReg_{self.reg_name}(ConfigReg_{self.reg_name});
    {self.instance}
interface ConfigReg_HW_{self.reg_name} hw;
    {self.method}
    method Bit#({width}) value();
    {value_method_joined}
    return rv;
    endmethod
endinterface
interface ConfigReg_Bus_{self.reg_name} bus;
    method Action write(Bit#({width}) data,Bit#({width}) wstrb);
    {self.write_method}
    endmethod
    method ActionValue#(Bit#({width})) read;
        Bit#({width}) rv=0;
    {self.read_method}
    return rv;
    endmethod
endinterface
endmodule
                  """,
            file=self.file,
        )
