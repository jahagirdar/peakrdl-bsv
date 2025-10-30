"""Write Bluespec Signal class."""
import sys
from systemrdl import RDLCompiler, RDLWalker
from jinja2 import Environment, PackageLoader, select_autoescape


from systemrdl import RDLListener

# from systemrdl.node import FieldNode, RegNode, AddressableNode

# Define a listener that will print out the register model hierarchy


class PrintBSVSignal(RDLListener):
    """Write Bluespec Signal class."""

    def __init__(self, bsvfile, test):
        """Initialize."""
        self.indent = 0
        self.file = bsvfile
        self.gentest = test
        self.field_count = 0
        self.addressmap = []

    def enter_Addrmap(self, node):
        """Address Map Handler."""
        self.addressmap.append(node.get_path_segment())
        self.addrmap_name = node.get_path_segment()

    def enter_Reg(self, node):
        """Reg  Handler."""
        self.reg_name = node.get_path_segment()
        self.hier_path = [*self.addressmap, self.reg_name]

    def enter_Field(self, node):
        """Field  Handler."""
        name = node.get_path_segment()
        attr = node.inst.properties
        attr["width"] = node.width
        attr["signal_name"] = name
        attr["reg_name"] = self.reg_name
        attr["hw_readable"] = node.is_hw_readable
        attr["hw_writable"] = node.is_hw_writable
        attr["sw_readable"] = node.is_sw_readable
        attr["sw_writable"] = node.is_sw_writable
        if "sw" in node.inst.properties:
            attr["sw"] = f"{node.inst.properties['sw']}"
        if "hw" in node.inst.properties:
            attr["hw"] = f"{node.inst.properties['hw']}"

        env = Environment(
            loader=PackageLoader("peakrdl_bsv"),
            autoescape=select_autoescape(),
        )
        template = env.get_template("config_signal.bsv")
        print(
            template.render(attr=attr, node=node, gentest=self.gentest), file=self.file
        )

    def exit_Reg(self, node):
        """Reg  Handler."""
        self.indent -= 1

    def exit_Addrmap(self, node):
        """Addrmap  Handler."""
        self.addressmap.pop()


if __name__ == "__main__":
    input_files = sys.argv[1:]
    rdlc = RDLCompiler()
    try:
        for input_file in input_files:
            rdlc.compile_file(input_file)
            root = rdlc.elaborate()
    except:
        sys.exit(1)
    walker = RDLWalker(unroll=True)
    with open("bsv_test_signal.bsv", "w") as of:
        walker.walk(root, PrintBSVSignal(of))
