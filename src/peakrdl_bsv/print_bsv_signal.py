import sys
from systemrdl import RDLCompiler, RDLWalker
from jinja2 import Environment, PackageLoader, select_autoescape


from systemrdl import RDLListener
# from systemrdl.node import FieldNode, RegNode, AddressableNode

# Define a listener that will print out the register model hierarchy


class PrintBSVSignal(RDLListener):
    def __init__(self,bsvfile):
        self.indent = 0
        self.file=bsvfile
        self.field_count=0
        self.addressmap=[]

    def enter_Addrmap(self, node):
        self.addressmap.append(node.get_path_segment())
        self.addrmap_name=node.get_path_segment()
    def enter_Reg(self, node):
        self.reg_name=node.get_path_segment()
        self.hier_path = [*self.addressmap, self.reg_name]

    def enter_Field(self, node):
        name=node.get_path_segment()
        attr=node.inst.properties
        attr['width']=node.width
        attr['signal_name']=name
        attr['reg_name']=self.reg_name
        if('sw' in node.inst.properties):
            attr['sw']=f"{node.inst.properties['sw']}"
        if('hw' in node.inst.properties):
            attr['hw']=f"{node.inst.properties['hw']}"

        env = Environment(
            loader=PackageLoader("peakrdl_bsv"),
            autoescape=select_autoescape(),
        )
        template = env.get_template("config_signal.bsv")
        print(template.render(attr=attr,node=node), file=self.file)


    def exit_Reg(self, node):
        self.indent -= 1

    def exit_Addrmap(self, node):
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
    with open("bsv_test_signal.bsv",'w') as of:
        walker.walk(root, PrintBSVSignal(of))
