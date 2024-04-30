import sys
import os
from systemrdl import RDLCompiler, RDLCompileError, RDLWalker


from systemrdl import RDLListener
from systemrdl.node import FieldNode, RegNode, AddressableNode

# Define a listener that will print out the register model hierarchy


class PrintReg(RDLListener):
    def __init__(self,file):
        self.indent = 0
        self.file=file

    def isPrintable(self):
        raise NotImplementedError

    def enter_Reg(self, node):
        print("\t"*self.indent, "typedef struct {",file=self.file)
        self.indent += 1

    def enter_Field(self, node):
        # Print some stuff about the field
        bsv_type = ''
        if node.high == node.low:
            bsv_type = "Bool"
        else:
            bsv_type = f"Bit#({node.high-node.low +1})"
        if self.isPrintable(node):
            print(self.indent*'\t', f"{bsv_type} {node.get_path_segment()};",file=self.file)

    def exit_Reg(self, node):
        print("\t"*self.indent, "}",
              f"{node.get_path_segment()}_{self.suffix}_st deriving(Bits, Eq, FShow) ;" ,file=self.file)
        self.indent -= 1

    def exit_Addrmap(self, node):
        glb_has_printable = []
        st = "typedef struct {\n"
        for reg in node.registers():
            hasPrintable = [self.isPrintable(x) for x in reg.fields()]
            if (any(hasPrintable)):
                st = st + \
                    f"{reg.get_path_segment()}_{self.suffix}_st {reg.get_path_segment().lower()};\n"
            glb_has_printable.extend(hasPrintable)
        st += "}" + f"{node.get_path_segment()}_{self.suffix}  deriving(Bits, Eq, FShow) ;"
        print(st,file=self.file)


class PrintWriteReg(PrintReg):
    def __init__(self,file):
        self.suffix = "Write"
        super().__init__(file)

    def isPrintable(self, node):
        return node.is_hw_writable


class PrintReadReg(PrintReg):
    def __init__(self,file):
        self.suffix = "Read"
        super().__init__(file)

    def isPrintable(self, node):
        return node.is_hw_readable


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
    listener = PrintReadReg()
    walker.walk(root, listener)
    listener = PrintWriteReg()
    walker.walk(root, listener)
