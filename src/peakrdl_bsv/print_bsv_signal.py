"""Write Bluespec Signal class."""
import logging
import sys

from jinja2 import Environment, PackageLoader, select_autoescape
from systemrdl import RDLCompiler, RDLListener, RDLWalker

from .common import HierarchyMixin, resolve_signal_ref, signal_port_name

logger = logging.getLogger(__name__)

#: Field properties the generated BSV does not model; flagged at generation
#: time so the user is not silently handed wrong RTL.
UNSUPPORTED_FIELD_PROPS = (
    "ruser",
    "wuser",
    "sticky",
    "stickybit",
    "intr",
    # Per-bit hw update masking: hw may update every bit of the field.
    "hwenable",
    "hwmask",
    # Combinational next-value expression: not wired into the generated
    # storage rule.
    "next",
    # Field always resets from the module's single global reset signal.
    "resetsignal",
)


# Define a listener that will print out the register model hierarchy
class PrintBSVSignal(HierarchyMixin, RDLListener):
    """Write Bluespec Signal class."""

    def __init__(self, bsvfile, test, default_regwidth):
        """Initialize."""
        self.indent = 0
        self.file = bsvfile
        self.gentest = test
        self.field_count = 0
        self.default_regwidth = default_regwidth
        self.hier = []

    def enter_Addrmap(self, node):
        """Address Map Handler."""
        self._enter_scope(node)
        self.addrmap_name = node.get_path_segment()

    def enter_Reg(self, node):
        """Reg  Handler."""
        self.reg_name = self._reg_name(node)
        if node.external:
            logger.warning(
                "%s: external registers are not supported by the BSV "
                "generator; internal storage is generated instead.",
                self.reg_name,
            )

    def _resolve_write_enable_gates(self, node, attr, name):
        """Resolve we/wel (hw write-enable) and swwe/swwel (sw
        write-enable) gating: only a `signal` reference is modeled (see
        common.resolve_signal_ref -- a Field/PropertyReference value is a
        valid SystemRDL construct but, like `next`, doesn't resolve
        through this compiler's namespace lookup in practice). The plain
        bool form needs no handling: `we=true`/`swwe=true`/unset is
        already the generator's default (always enabled to write)."""
        prop_to_attr = {
            "we": "we_port",
            "wel": "wel_port",
            "swwe": "swwe_port",
            "swwel": "swwel_port",
        }
        for prop, attr_key in prop_to_attr.items():
            attr[attr_key] = None
        for prop, attr_key in prop_to_attr.items():
            value = node.get_property(prop)
            if value is None or isinstance(value, bool):
                continue
            sig = resolve_signal_ref(node, prop)
            if sig is not None:
                attr[attr_key] = signal_port_name(sig)
                attr["ext_signals"][attr[attr_key]] = 1
            else:
                logger.warning(
                    "%s.%s: %s referencing a field/property (not a plain "
                    "signal) is not supported by the BSV generator; the "
                    "generated code ignores it.",
                    self.reg_name,
                    name,
                    prop,
                )

    def _resolve_counter_side(self, node, name, prop_value_name, bool_default):
        """Resolve a bool/int/dynamic-ref counter refinement property
        (incrsaturate, decrsaturate, incrthreshold) to a literal int, or
        None if unset or unsupported (dynamic signal/field reference)."""
        value = node.get_property(prop_value_name)
        if value is None or value is False:
            return None
        if value is True:
            return bool_default
        if isinstance(value, int):
            return value
        logger.warning(
            "%s.%s: %s referencing an external signal/field is not "
            "supported by the BSV generator; the generated code ignores it.",
            self.reg_name,
            name,
            prop_value_name,
        )
        return None

    def _resolve_counter(self, node, attr, name):
        """Resolve counter refinement properties (direction, incr/decr
        value & width, saturation, threshold, overflow/underflow) using
        the compiler's own is_up_counter/is_down_counter inference so the
        generated interface matches the SystemRDL-specified direction and
        default increment amount, not just a blanket incr()/decr() pair."""
        width = node.width
        max_val = (1 << width) - 1

        attr["counter_up"] = node.is_up_counter
        attr["counter_down"] = node.is_down_counter

        incrvalue = node.get_property("incrvalue")
        attr["incr_is_pulse"] = attr["counter_up"] and isinstance(incrvalue, int)
        attr["incr_const"] = incrvalue if attr["incr_is_pulse"] else None
        attr["incr_width"] = node.get_property("incrwidth") or width
        if attr["counter_up"] and not attr["incr_is_pulse"] and incrvalue is not None:
            logger.warning(
                "%s.%s: incrvalue referencing an external signal/field is "
                "not supported by the BSV generator; the generated code "
                "ignores it.",
                self.reg_name,
                name,
            )

        decrvalue = node.get_property("decrvalue")
        attr["decr_is_pulse"] = attr["counter_down"] and isinstance(decrvalue, int)
        attr["decr_const"] = decrvalue if attr["decr_is_pulse"] else None
        attr["decr_width"] = node.get_property("decrwidth") or width
        if attr["counter_down"] and not attr["decr_is_pulse"] and decrvalue is not None:
            logger.warning(
                "%s.%s: decrvalue referencing an external signal/field is "
                "not supported by the BSV generator; the generated code "
                "ignores it.",
                self.reg_name,
                name,
            )

        attr["incr_sat_max"] = (
            self._resolve_counter_side(node, name, "incrsaturate", max_val)
            if attr["counter_up"]
            else None
        )
        attr["decr_sat_min"] = (
            self._resolve_counter_side(node, name, "decrsaturate", 0)
            if attr["counter_down"]
            else None
        )
        attr["incr_threshold"] = (
            self._resolve_counter_side(node, name, "incrthreshold", max_val)
            if attr["counter_up"]
            else None
        )
        attr["has_overflow"] = attr["counter_up"] and bool(
            node.get_property("overflow")
        )
        attr["has_underflow"] = attr["counter_down"] and bool(
            node.get_property("underflow")
        )
        # The compiler itself rejects incrsaturate+overflow (and
        # decrsaturate+underflow) on the same field as meaningless, so
        # overflow/underflow detection never needs to share logic with the
        # saturating-clamp datapath below; only the clamp needs the wider
        # (width+1) intermediate to compare against a custom ceiling/floor.
        attr["incr_needs_wide"] = attr["incr_sat_max"] is not None
        attr["decr_needs_wide"] = attr["decr_sat_min"] is not None

    def enter_Field(self, node):
        """Field  Handler."""
        name = node.get_path_segment()
        # Collect the explicitly assigned properties through the public API.
        attr = {prop: node.get_property(prop) for prop in node.list_properties()}
        # Normalize longhand onread/onwrite assignments to the shorthand flags
        # the template keys on, so both RDL spellings generate the same code.
        for prop in ("onread", "onwrite"):
            side_effect = node.get_property(prop)
            if side_effect is not None:
                attr[side_effect.name] = True
        attr["width"] = node.width
        attr["signal_name"] = name
        attr["reg_name"] = self.reg_name
        attr["hw_readable"] = node.is_hw_readable
        attr["hw_writable"] = node.is_hw_writable
        attr["sw_readable"] = node.is_sw_readable
        attr["sw_writable"] = node.is_sw_writable
        if "sw" in attr:
            attr["sw"] = f"{attr['sw']}"
        if "hw" in attr:
            attr["hw"] = f"{attr['hw']}"
        # precedence has a spec default (sw) even when not explicitly
        # assigned, so always resolve it rather than gating on presence
        # in list_properties() like the other properties above.
        attr["precedence"] = f"{node.get_property('precedence')}"
        # port_name -> width, for every external `signal` this field
        # references (we/wel/swwe/swwel now; hwenable/hwmask/next later).
        # Populated generically so the template can emit one Wire +
        # top-level Ifc_CSRSignal_* method per port without hardcoding
        # which property it came from.
        attr["ext_signals"] = {}
        self._resolve_write_enable_gates(node, attr, name)
        if attr.get("counter"):
            self._resolve_counter(node, attr, name)
        for prop in UNSUPPORTED_FIELD_PROPS:
            # Membership, not truthiness: several of these (incrvalue,
            # decrwidth, threshold, ...) are integer-valued and a
            # legitimately-assigned 0 must still warn.
            if prop in attr:
                logger.warning(
                    "%s.%s: property '%s' is not supported by the BSV "
                    "generator; the generated code ignores it.",
                    self.reg_name,
                    name,
                    prop,
                )
        if attr.get("sw") in ("AccessType.w1", "AccessType.rw1"):
            logger.warning(
                "%s.%s: write-once (sw=%s) is generated as plain read/write; "
                "the once-only restriction is not enforced.",
                self.reg_name,
                name,
                attr["sw"],
            )

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
        self._exit_scope(node)


if __name__ == "__main__":
    input_files = sys.argv[1:]
    rdlc = RDLCompiler()
    try:
        for input_file in input_files:
            rdlc.compile_file(input_file)
            root = rdlc.elaborate()
    except Exception:
        logger.exception("Failed to compile %s", input_files)
        sys.exit(1)
    walker = RDLWalker(unroll=True)
    with open("bsv_test_signal.bsv", "w") as of:
        walker.walk(root, PrintBSVSignal(of, test=True))
