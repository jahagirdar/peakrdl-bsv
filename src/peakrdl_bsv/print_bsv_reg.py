"""Write Bluespec Register file."""
from systemrdl import RDLListener


class PrintBSVReg(RDLListener):
    """Write Register defination file."""

    def __init__(self, bsvfile):
        """Initialize."""
        self.file = bsvfile
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
        self.instance = ""
        self.method = ""
        self.write_method = ""
        self.read_method = ""

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
            self.write_method += (
                f"sig_{self.signal_name}.bus.write(data[{node.high}:{node.low}]);\n"
            )
        if node.is_sw_readable:
            self.read_method += f"let var_{self.signal_name}<-sig_{self.signal_name}.bus.read();\nrv[{node.high}:{node.low}]=var_{self.signal_name};\n"

    def exit_Reg(self, node):
        """Write out register file."""
        width = node.inst.properties["regwidth"]
        print(
            f"""
interface ConfigReg_HW_{self.reg_name};
    {self.interface}
endinterface

interface ConfigReg_Bus_{self.reg_name};
    method Action write( Bit#({width}) data);
    method ActionValue#(Bit#({width})) read();
endinterface

interface ConfigReg_{self.reg_name};
interface ConfigReg_HW_{self.reg_name} hw;
interface ConfigReg_Bus_{self.reg_name} bus;
endinterface
(*synthesize*)
module mkConfigReg_{self.reg_name}(ConfigReg_{self.reg_name});
    {self.instance}
interface ConfigReg_HW_{self.reg_name} hw;
    {self.method}
endinterface
interface ConfigReg_Bus_{self.reg_name} bus;
    method Action write(Bit#({width}) data);
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
