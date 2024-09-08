import sys
from systemrdl import RDLListener
class PrintBSV(RDLListener):
    def __init__(self,bsvfile):
        self.vfile=bsvfile
        self.ifc=''
        self.module=''
        self.inst=''
    def enter_Addrmap(self,node):
        name=node.get_path_segment()
        self.module_name=name
        self.ifc=f'''
interface Ifc_{name}_CSR#(numeric type awidth,numeric type dwidth);
method Action write(Bit#(awidth) address,Bit#(dwidth) data);
method ActionValue#(Bit#(dwidth)) read (Bit#(awidth) address);
method {name}_Read hwif_read();
method Action hwif_write({name}_Write wdata);
endinterface
        '''

        self.dwidth=next(node.registers()).inst.properties['regwidth']
        self.m=f'''module mk{name}_CSR(Ifc_{name}_CSR#(awidth,{self.dwidth}));\n
Wire#({name}_Read) hwif_r <-mkWire();
Wire#({name}_Write) hwif_w <-mkWire();
Wire#(Bool) wtxn <- mkDWire(False);
Wire#(Bool) rtxn <- mkDWire(False);
Wire#(Bit#({self.dwidth})) rdata <-mkWire();
Wire#(Bit#({self.dwidth})) wdata <-mkWire();
Wire#(Bit#(awidth)) txn_address <-mkWire();
'''
        self.rule=f'rule rl_{name};\n let hwif_r_var =hwif_r;\n'
        self.actions=f'''
method Action write(Bit#(awidth) address,Bit#({self.dwidth}) data);
     txn_address <=address;
     wdata<=data;
     wtxn<=True;
 endmethod
method  ActionValue#(Bit#({self.dwidth}) ) read(Bit#(awidth) address);
     txn_address <=address;
     rtxn<=True;
     return rdata;
 endmethod
method {name}_Read hwif_read();
    return hwif_r;
endmethod
method Action hwif_write({name}_Write w);
     hwif_w<=w;
endmethod
     '''

    def enter_Reg(self,node):
        self.rname=node.get_path_segment().lower()
        self.raddress=node.address_offset
        self.m+=f"let const_{self.rname} ='h{node.raw_address_offset:x};\n"

    def enter_Field(self,node):
        signame=node.get_path_segment()
        name=f's{self.rname}{signame}'
        sigdata=f'wdata[{node.high} : {node.low}]'
        if node.implements_storage:
            #sys.stderr.write(f"{node.inst.properties}\n")
            self.m+=f"Reg#(Bit#({node.width})) {name} <-"
            if  'reset' in node.inst.properties:
                self.m+=f"mkRegA({node.inst.properties['reset']});\n"
            else:
                self.m+="mkRegU();\n"
        else:
            self.m+=f"Wire#(Bit#({node.width})) {name} <-"
            if 'reset' in node.inst.properties:
                self.m+=f"mkDWire({node.inst.properties['reset']});\n"
            else:
                self.m+="mkWire();\n"
        if 'swacc' in node.inst.properties:
            self.m+=f'Wire#(Bit#(1)) {name}_swacc <- mkDWire(0);\n'
        if 'swmod' in node.inst.properties:
            self.m+=f'Wire#(Bit#(1)) {name}_swmod <- mkDWire(0);\n'
        if 'anded' in node.inst.properties:
            self.m+=f'Wire#(Bit#(1)) {name}_anded <- mkWire();\n'
        if 'ored' in node.inst.properties:
            self.m+=f'Wire#(Bit#(1)) {name}_ored <- mkWire();\n'
        if 'xored' in node.inst.properties:
            self.m+=f'Wire#(Bit#(1)) {name}_xored <- mkWire();\n'
        if 'interrupt' in node.inst.properties:
            self.m+=f'Wire#(Bit#(1)) {name}_intr <- mkWire();\n'
        if 'swwe' in node.inst.properties:
            self.m+=f'Wire#(Bit#(1)) {name}_swwe <- mkWire();\n'
        if 'swwel' in node.inst.properties:
            self.m+=f'Wire#(Bit#(1)) {name}_swwel <- mkWire();\n'




        var=f'{name}_var'
        self.rule += f'''
        let {name}_wtxn= txn_address == {self.raddress} && wtxn;
        let {name}_rtxn= txn_address == {self.raddress} && rtxn;
        let {name}_rclr = {'rclr' in node.inst.properties} && {name}_rtxn;
        let {name}_rset = {'rset' in node.inst.properties} && {name}_rtxn;
        let {name}_swmod = {'swmod' in node.inst.properties} ;
        //let {name}_swwe = {'swwe'  in node.inst.properties } ? hwif_w.{self.rname}.{signame}.swwe:True;
        //let {name}_swwel = {'swwel'  in node.inst.properties } ? hwif_w.{self.rname}.{signame}.swwel:True;
        let {name}_woclr = {'woclr' in node.inst.properties} && {name}_wtxn && {sigdata} ==1;
        let {name}_woset = {'woset' in node.inst.properties} && {name}_wtxn && {sigdata} ==1;
        let {name}_anded = {'anded' in node.inst.properties};
        // TODO HWENABLE,HWMask,hwset,hwclr,we,wel

        Bit#({node.width}) {var}={name};
        if({name}_rclr||{name}_woclr) {var}=0;
        if({name}_rset||{name}_woset) {var}=1;
                '''
        ##############
        if 'swacc' in node.inst.properties:
          self.rule += f'hwif_r_var.{self.rname}.{signame}.swacc=pack({name}_rtxn || {name}_wtxn);\n'
        if 'swmod' in node.inst.properties:
            self.rule += f'hwif_r_var.{self.rname}.{signame}.swmod=pack((({name}_rclr || {name}_rset)) || {name}_wtxn);\n'
        if 'singlepulse' in node.inst.properties:
           self.rule+=f'{var}=pack({name}_wtxn && wdata[{node.high} : {node.low}] == 1);\n'
        if('anded' in node.inst.properties):
           self.rule+=f'hwif_r_var.{self.rname}.{signame}.anded= & {var};\n'
        if 'ored' in node.inst.properties :
            self.rule+=f'hwif_r_var.{self.rname}.{signame}.ored= | {var};\n'
        if('xored' in node.inst.properties):
            self.rule+=f'hwif_r_var.{self.rname}.{signame}.xored= ^ {var};\n'
        if node.is_hw_readable:
            self.rule+=f'hwif_r_var.{self.rname}.{signame}.{signame}={var};\n'
        if node.is_hw_writable:
            self.rule+=f'{var}=hwif_w.{self.rname}.{signame}.{signame};\n'
        if node.is_sw_readable :
            self.rule+=f'if(rtxn) rdata[{node.high}:{node.low}] <= {var};\n'

        if node.is_sw_writable:
            self.rule+=f'if(wtxn){var}={sigdata};\n'
        self.rule +=f'{name}<={var};\n'

    def exit_Addrmap(self,node):
        name=node.get_path_segment()
        self.rule+='''
        hwif_r<=hwif_r_var\n;
        endrule
        '''
        self.vfile.write(f'{self.ifc} {self.m} {self.rule}\n{self.actions}\nendmodule//{name}\n')

if __name__ == "__main__":
    import sys
    from systemrdl import RDLCompiler,  RDLWalker
    from systemrdl import RDLListener
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
        walker.walk(root, PrintBSV(of))
