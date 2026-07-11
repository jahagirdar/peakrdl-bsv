"""Write Bluespec Register file."""
from systemrdl import RDLListener

from .common import (
    HierarchyMixin,
    reset_signal_port_name,
    resolve_signal_ref,
    signal_port_name,
)

#: Field properties whose value may be an external `signal` reference
#: that this register-level module needs to relay down to the
#: consuming field's Ifc_CSRSignal_* module (see print_bsv_signal.py).
_EXT_SIGNAL_PROPS = ("we", "wel", "swwe", "swwel", "hwenable", "hwmask", "next")


class PrintBSVReg(HierarchyMixin, RDLListener):
    """Write Register defination file."""

    def __init__(self, bsvfile, test, default_regwidth):
        """Initialize."""
        self.file = bsvfile
        self.gentest = test
        self.hier = []
        self.default_regwidth = default_regwidth

    def enter_Addrmap(self, node):
        """Addressmap Handler."""
        if not self.hier:
            # All registers, including those of nested addrmaps, use the
            # signal package generated for the top addrmap.
            self.addrmap_name = node.get_path_segment()
            print(f"import {self.addrmap_name}_signal::*;", file=self.file)
        self._enter_scope(node)

    def exit_Addrmap(self, node):
        """Addressmap Handler."""
        self._exit_scope(node)

    def enter_Reg(self, node):
        """RegHandler."""
        self.reg_name = self._reg_name(node)
        self.interface = ""
        self.reg_val = []
        self.instance = ""
        self.method = ""
        self.write_method = "//write methods\n"
        self.read_method = "//read methods\n"
        # port_name -> width, deduped across every field in this register
        # that references an external `signal`.
        self.reg_ext_signals = {}
        # (field_signal_name, port_name) pairs needing a relay rule.
        self.ext_signal_consumers = []
        # Ordered, deduped list of resetsignal port names this register's
        # own module signature needs (constructor-argument plumbing --
        # see print_bsv_signal.py._resolve_resetsignal for why this can't
        # reuse the Action-method ext_signals mechanism above).
        self.reg_reset_ports = []
        # BSV Bool expressions contributing to this register's
        # interrupt/halt aggregate (one per intr field with
        # haltenable/haltmask set, for halt).
        self.intr_terms = []
        self.halt_terms = []

    def enter_Field(self, node):
        """Field Handler."""
        self.signal_name = node.get_path_segment()
        reset = node.get_property("reset")
        if reset is None:
            reset = 0
        self.interface += (
            f"interface HW_{self.reg_name}_{self.signal_name} s{self.signal_name};\n"
        )
        reset_sig = resolve_signal_ref(node, "resetsignal")
        ctor_args = f"{reset}"
        if reset_sig is not None:
            reset_port = reset_signal_port_name(reset_sig)
            if reset_port not in self.reg_reset_ports:
                self.reg_reset_ports.append(reset_port)
            ctor_args += f", rst_{reset_port}"
        self.instance += f"Ifc_CSRSignal_{self.reg_name}_{self.signal_name} sig_{self.signal_name} <- mkCSRSignal_{self.reg_name}_{self.signal_name}({ctor_args});\n"
        self.method += f"interface HW_{self.reg_name}_{self.signal_name} s{self.signal_name} = sig_{self.signal_name}.hw;\n"
        if node.is_sw_writable:
            self.write_method += f"sig_{self.signal_name}.bus.write(data[{node.high}:{node.low}],wstrb[{node.high}:{node.low}]);\n"
        if node.is_sw_readable:
            self.read_method += f"let var_{self.signal_name}<-sig_{self.signal_name}.bus.read();\nrv[{node.high}:{node.low}]=var_{self.signal_name};\n"
        # currentValue() is always present on Ifc_CSRSignal_* regardless of
        # hw/sw access mode (see config_signal.bsv), so the register-level
        # value() aggregation always reflects the field's real stored value
        # — previously this hardcoded a literal 0 for hw=w fields (e.g.
        # INTERRUPT, STS), since the hw sub-interface only exposes _read
        # when hw_readable, with no equivalent fallback for hw=w.
        self.reg_val.append(
            (f"sig_{self.signal_name}.currentValue()", node.high, node.low)
        )
        for prop in _EXT_SIGNAL_PROPS:
            sig = resolve_signal_ref(node, prop)
            if sig is None:
                continue
            port = signal_port_name(sig)
            self.reg_ext_signals[port] = sig.width
            self.ext_signal_consumers.append((self.signal_name, port))

        # intr: this field contributes to the register's interrupt
        # aggregate (see exit_Reg). enable/mask (mutually exclusive) and
        # haltenable/haltmask qualify which bits count -- only a
        # `signal` reference is modeled, same limitation as we/wel etc.
        # Consumed locally here (via a Wire declared alongside the other
        # ext_signals, but never relayed to any field), not pushed down.
        if node.get_property("intr"):
            enable_sig = resolve_signal_ref(node, "enable")
            mask_sig = resolve_signal_ref(node, "mask")
            value_expr = f"sig_{self.signal_name}.currentValue()"
            if enable_sig is not None:
                port = signal_port_name(enable_sig)
                self.reg_ext_signals[port] = enable_sig.width
                value_expr = f"({value_expr} & w_{port})"
            elif mask_sig is not None:
                port = signal_port_name(mask_sig)
                self.reg_ext_signals[port] = mask_sig.width
                value_expr = f"({value_expr} & ~w_{port})"
            self.intr_terms.append(f"(|({value_expr}) == 1'b1)")

            haltenable_sig = resolve_signal_ref(node, "haltenable")
            haltmask_sig = resolve_signal_ref(node, "haltmask")
            if haltenable_sig is not None or haltmask_sig is not None:
                halt_expr = f"sig_{self.signal_name}.currentValue()"
                if haltenable_sig is not None:
                    port = signal_port_name(haltenable_sig)
                    self.reg_ext_signals[port] = haltenable_sig.width
                    halt_expr = f"({halt_expr} & w_{port})"
                else:
                    port = signal_port_name(haltmask_sig)
                    self.reg_ext_signals[port] = haltmask_sig.width
                    halt_expr = f"({halt_expr} & ~w_{port})"
                self.halt_terms.append(f"(|({halt_expr}) == 1'b1)")

    def exit_Reg(self, node):
        """Write out register file."""
        if "regwidth" in node.list_properties():
            width = node.get_property("regwidth")
        elif self.default_regwidth is not None:
            width = self.default_regwidth
        else:
            # SystemRDL spec default (32).
            width = node.get_property("regwidth")

        value_method = []
        value_method.append("let rv=0;")
        for r in self.reg_val:
            value_method.append(f"rv[{r[1]}:{r[2]}]={r[0]};")
        value_method_joined = "\n".join(value_method)
        # Relay ports for fields in this register that reference an
        # external `signal` (we/wel, ...): one Action method + backing
        # Wire per unique port on ConfigReg's own interface, plus an
        # always-firing rule per consuming field forwarding the value
        # down into that field's Ifc_CSRSignal_* module.
        ext_signal_iface = "\n".join(
            f"method Action set_{port}(Bit#({w}) v);"
            for port, w in self.reg_ext_signals.items()
        )
        ext_signal_wires = "\n".join(
            f"Wire#(Bit#({w})) w_{port} <-mkDWire(0);"
            for port, w in self.reg_ext_signals.items()
        )
        ext_signal_impls = "\n".join(
            f"method Action set_{port}(Bit#({w}) v);\n    w_{port} <= v;\nendmethod"
            for port, w in self.reg_ext_signals.items()
        )
        ext_signal_relays = "\n".join(
            f"rule rl_relay_{port}_{field};\n    sig_{field}.set_{port}(w_{port});\nendrule"
            for field, port in self.ext_signal_consumers
        )
        # Interrupt/halt aggregates: an OR-reduction across every intr
        # field in this register (each field's bits qualified by its own
        # enable/mask or haltenable/haltmask, if set). Only emitted when
        # at least one field actually contributes.
        interrupt_iface = "method Bool interrupt();" if self.intr_terms else ""
        interrupt_impl = (
            f"method Bool interrupt();\n    return {' || '.join(self.intr_terms)};\nendmethod"
            if self.intr_terms
            else ""
        )
        halt_iface = "method Bool halt();" if self.halt_terms else ""
        halt_impl = (
            f"method Bool halt();\n    return {' || '.join(self.halt_terms)};\nendmethod"
            if self.halt_terms
            else ""
        )
        # resetsignal: a plain pass-through constructor argument (not a
        # Wire/method/relay-rule triple like the ext_signals above --
        # see print_bsv_signal.py._resolve_resetsignal), since it just
        # needs to reach the consuming field's own mkCSRSignal_* call
        # unchanged.
        reset_ctor_params = ", ".join(
            f"Bool rst_{port}" for port in self.reg_reset_ports
        )
        module_params = f"#({reset_ctor_params})" if reset_ctor_params else ""
        print(
            f"""
interface ConfigReg_HW_{self.reg_name};
    {self.interface}
    method Bit#({width}) value();
    {interrupt_iface}
    {halt_iface}
endinterface

interface ConfigReg_Bus_{self.reg_name};
    method Action write( Bit#({width}) data,Bit#({width})wstrb);
    method ActionValue#(Bit#({width})) read();
endinterface

interface ConfigReg_{self.reg_name};
interface ConfigReg_HW_{self.reg_name} hw;
interface ConfigReg_Bus_{self.reg_name} bus;
    {ext_signal_iface}
endinterface
module mkConfigReg_{self.reg_name}{module_params}(ConfigReg_{self.reg_name});
    {self.instance}
    {ext_signal_wires}
    {ext_signal_relays}
interface ConfigReg_HW_{self.reg_name} hw;
    {self.method}
    method Bit#({width}) value();
    {value_method_joined}
    return rv;
    endmethod
    {interrupt_impl}
    {halt_impl}
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
    {ext_signal_impls}
endmodule
                  """,
            file=self.file,
        )
