import sys
import os
from systemrdl import RDLCompiler, RDLCompileError, RDLWalker


from systemrdl import RDLListener
from systemrdl.node import FieldNode, RegNode, AddressableNode

# Define a listener that will print out the register model hierarchy


class PrintReg(RDLListener):
    def __init__(self,bsvfile):
        self.indent = 0
        self.file=bsvfile
        self.field_count=0

    def isPrintable(self):
        raise NotImplementedError

    def enter_Reg(self, node):
        self.reg_st+="\t"*self.indent+ "typedef struct {\n"
        self.indent += 1

    def enter_Field(self, node):
        name=node.get_path_segment()
        bsv_type = ''
        #if node.high == node.low:
        #    bsv_type = "Bool"
        #else:
        #    bsv_type = f"Bit#({node.width})"
        bsv_type = f"Bit#({node.width})"
        ext_f=[]
        for ext in self.ext:
            if ext in node.inst.properties:
                ext_f.append(f'Bit#(1) {ext};')
        ext_joined='\n'.join(ext_f)

        if self.isPrintable(node) or len(ext_f)>0:
            self.reg_st+=f"{name.upper()}{self.field_count}_{self.suffix}_st {name};\n"
            self.field_st+='\n\ntypedef struct {\n'
            if self.isPrintable(node):
                self.field_st+=self.indent*'\t'+ f"{bsv_type} {self.value};\n"
                self.field_st+=f"{ext_joined}"
            self.field_st+= '}'+name.upper()+f"{self.field_count}_{self.suffix}_st deriving(Bits, Eq, FShow) ;\n"
        # sys.stderr.write(f"{name}: {self.field_st} \n")
        self.field_count+=1

    def exit_Reg(self, node):
        name=node.get_path_segment()
        self.reg_st+="\t"*self.indent+ "}"+ f"{name}_{self.suffix}_st deriving(Bits, Eq, FShow) ;\n"
        self.indent -= 1

    def enter_Addrmap(self, node):
        self.field_st=''
        self.reg_st=''
    def exit_Addrmap(self, node):
        glb_has_printable = []
        st = f'''
        {self.field_st}
        {self.reg_st}
        '''+"\n\ntypedef struct {\n"
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
        self.value='next'
        self.ext=[]
        super().__init__(file)

    def isPrintable(self, node):
        return node.is_hw_writable


class PrintReadReg(PrintReg):
    def __init__(self,file):
        self.suffix = "Read"
        self.value='value'
        self.ext=['singlepulse','swacc','swmod','anded','ored','xored']
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
    with open("bsv_test.bsv",'w') as of:
        walker.walk(root, PrintReadReg(of))
        walker.walk(root, PrintWriteReg(of))
