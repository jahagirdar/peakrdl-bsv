from systemrdl import RDLListener


class PrintBSVInfo(RDLListener):
    axi_port = """
input clk {0 : 0} clock;
input arst_n {0 : 0} reset;
output s_axil_awready {0:0} none;
input  s_axil_awvalid {0:0} none;
input   s_axil_awaddr {4:0} none;
input   s_axil_awprot {2:0} none;
output s_axil_wready {0:0} none;
input  s_axil_wvalid {0:0} none;
input   s_axil_wdata {31:0} none;
input  s_axil_wstrb {3:0} none;
input  s_axil_bready {0:0} none;
output s_axil_bvalid {0:0} none;
output   s_axil_bresp {1:0} none;
output s_axil_arready {0:0} none;
input  s_axil_arvalid {0:0} none;
input   s_axil_araddr {4:0} none;
input   s_axil_arprot {2:0} none;
input  s_axil_rready {0:0} none;
output s_axil_rvalid {0:0} none;
output   s_axil_rdata {31:0} none;
output   s_axil_rresp {1:0} none;
"""

    def __init__(self, infofile):
        self.ifile = infofile
        self.m = ""
        self.wires = ""
        self.inst = ""

    def enter_Addrmap(self, node):
        name = node.get_path_segment()
        self.m = f"module {name}_Reg;\n" + self.axi_port
        self.inst = f"{name} U{name}(.*);\n"

    def enter_Reg(self, node):
        self.rname = node.get_path_segment()

    def exit_Addrmap(self, node):
        # name=node.get_path_segment()
        self.ifile.write(f"{self.m})")

    def enter_Field(self, node):
        signame = node.get_path_segment()
        if node.is_hw_readable:
            self.m += f"output {self.rname}_{signame}_value" + " {%d : %d} none;\n" % (
                node.high,
                node.low,
            )
        if "swacc" in node.inst.properties:
            self.m += f"output {self.rname}_{signame}_swacc" + " {%d : %d} none;\n" % (
                node.high,
                node.low,
            )
        if "swmod" in node.inst.properties:
            self.m += f"output {self.rname}_{signame}_swmod" + " {%d : %d} none;\n" % (
                node.high,
                node.low,
            )
        if "anded" in node.inst.properties:
            self.m += f"output {self.rname}_{signame}_anded" + " {%d : %d} none;\n" % (
                node.high,
                node.low,
            )
        if "ored" in node.inst.properties:
            self.m += f"output {self.rname}_{signame}_ored" + " {%d : %d} none;\n" % (
                node.high,
                node.low,
            )
        if "xored" in node.inst.properties:
            self.m += f"output {self.rname}_{signame}_xored" + " {%d : %d} none;\n" % (
                node.high,
                node.low,
            )
        if "interrupt" in node.inst.properties:
            self.m += f"output {self.rname}_{signame}_intr" + " {%d : %d} none;\n" % (
                node.high,
                node.low,
            )

        if node.is_hw_writable:
            self.m += f"input {self.rname}_{signame}_next" + " {%d : %d} none;\n" % (
                node.high,
                node.low,
            )

        if "swwe" in node.inst.properties:
            self.m += f"input {self.rname}_{signame}_swwe" + " {%d : %d} none;\n" % (
                node.high,
                node.low,
            )
        if "swwel" in node.inst.properties:
            self.m += f"input {self.rname}_{signame}_swwel" + " {%d : %d} none;\n" % (
                node.high,
                node.low,
            )
