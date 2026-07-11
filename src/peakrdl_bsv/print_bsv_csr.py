"""Toplevel CSR Module generator."""
import logging
import math

from systemrdl import RDLListener

from .common import HierarchyMixin, resolve_signal_ref, signal_port_name

logger = logging.getLogger(__name__)

#: Field properties whose value may be an external `signal` reference
#: that must be exposed as a top-level ConfigCSR input and relayed down
#: to whichever register(s) contain a consuming field.
_EXT_SIGNAL_PROPS = ("we", "wel")


class PrintBSVCSR(HierarchyMixin, RDLListener):
    """Class to write the CSR module.

    Nested addrmaps and regfiles are flattened into a single CSR module for
    the top addrmap; every register is decoded at its absolute address offset
    from the top of the exported map.
    """

    def __init__(self, bsvfile, test, default_regwidth):
        """Initialization."""
        self.file = bsvfile
        self.gentest = test
        self.hier = []
        self.regwidth = []
        self.default_regwidth = default_regwidth

    def enter_Addrmap(self, node):
        """Addressmap handler."""
        if not self.hier:
            self.addrmap_name = node.get_path_segment()
            print(
                f"import Vector::*;\nimport {self.addrmap_name}_reg::*;",
                file=self.file,
            )
            self.interface = ""
            self.instance = ""
            self.method = ""
            self.write_method = ""
            self.read_method = ""
            self.address_alias = ""
            self.regwidth = []
            self.base_address = node.absolute_address
            self.addr_width = max(1, math.ceil(math.log2(node.total_size)))
            # port_name -> width, deduped across the whole addrmap.
            self.csr_ext_signals = {}
            # reg_name -> set of port names that register needs relayed
            # to it (deduped per register; the register's own module
            # fans a port out to every consuming field internally).
            self.reg_ports = {}
        self._enter_scope(node)

    def enter_Mem(self, node):
        """Memory handler."""
        logger.warning(
            "%s: memories are not supported by the BSV generator; "
            "no bus decode is generated for it.",
            node.get_path(),
        )

    def enter_Reg(self, node):
        """Reg Handler."""
        self.reg_name = self._reg_name(node)
        if "regwidth" in node.list_properties():
            self.regwidth.append(node.get_property("regwidth"))
        elif self.default_regwidth is not None:
            self.regwidth.append(self.default_regwidth)
        else:
            # SystemRDL spec default (32).
            self.regwidth.append(node.get_property("regwidth"))

        offset = node.absolute_address - self.base_address
        self.address_alias += (
            f"Bit#({self.addr_width}) address_{self.reg_name} = {offset};\n"
        )
        self.interface += (
            f"interface ConfigReg_HW_{self.reg_name} {self.reg_name.lower()};\n"
        )
        self.instance += f"ConfigReg_{self.reg_name} reg_{self.reg_name} <- mkConfigReg_{self.reg_name}();\n"
        self.method += f"interface ConfigReg_HW_{self.reg_name} {self.reg_name.lower()} = reg_{self.reg_name}.hw;\n"
        self.write_method += f"if(address== address_{self.reg_name})reg_{self.reg_name}.bus.write(data,wstrb_expanded);\n"
        self.read_method += f"if(address== address_{self.reg_name})rv<-reg_{self.reg_name}.bus.read();\n"

    def enter_Field(self, node):
        """Field Handler: catalog external `signal` references so this
        top module can expose one input per unique signal and relay it
        down to whichever register(s) actually need it."""
        for prop in _EXT_SIGNAL_PROPS:
            sig = resolve_signal_ref(node, prop)
            if sig is None:
                continue
            port = signal_port_name(sig)
            self.csr_ext_signals[port] = sig.width
            self.reg_ports.setdefault(self.reg_name, set()).add(port)

    def exit_Addrmap(self, node):
        """Write code for addressmap."""
        self._exit_scope(node)
        if self.hier:
            # Nested addrmap: content is folded into the top module.
            return
        if not self.regwidth:
            logger.warning(
                "%s: no registers found; no CSR module generated.",
                self.addrmap_name,
            )
            return
        self.data_width = max(self.regwidth)
        # Top-level input for every external `signal` referenced anywhere
        # in the design (we/wel, ...), relayed down to each register that
        # contains a consuming field. See print_bsv_reg.py/
        # print_bsv_signal.py for the next two relay legs.
        ext_signal_iface = "\n".join(
            f"method Action set_{port}(Bit#({w}) v);"
            for port, w in self.csr_ext_signals.items()
        )
        ext_signal_wires = "\n".join(
            f"Wire#(Bit#({w})) w_{port} <-mkDWire(0);"
            for port, w in self.csr_ext_signals.items()
        )
        ext_signal_impls = "\n".join(
            f"method Action set_{port}(Bit#({w}) v);\n    w_{port} <= v;\nendmethod"
            for port, w in self.csr_ext_signals.items()
        )
        ext_signal_relays = "\n".join(
            f"rule rl_relay_{port}_{reg_name};\n    reg_{reg_name}.set_{port}(w_{port});\nendrule"
            for reg_name, ports in self.reg_ports.items()
            for port in ports
        )
        print(
            f"""
interface ConfigCSR_{self.addrmap_name};
    {self.interface}
    method Action write(Bit#({self.addr_width}) address, Bit#({self.data_width}) data, Bit#({self.data_width//8}) wstrb);
    method ActionValue#(Bit#({self.data_width})) read(Bit#({self.addr_width}) address);
    {ext_signal_iface}
endinterface
{self.address_alias}

(*synthesize*)
module mkConfigCSR_{self.addrmap_name}(ConfigCSR_{self.addrmap_name});
    {self.instance}
    {ext_signal_wires}
    {ext_signal_relays}
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
    {ext_signal_impls}
endmodule
                  """,
            file=self.file,
        )
