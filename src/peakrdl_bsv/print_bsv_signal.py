"""Write Bluespec Signal class."""
import logging
import sys

from jinja2 import Environment, PackageLoader, select_autoescape
from systemrdl import RDLCompiler, RDLListener, RDLWalker

from .common import HierarchyMixin

logger = logging.getLogger(__name__)

#: Field properties the generated BSV does not model; flagged at generation
#: time so the user is not silently handed wrong RTL.
UNSUPPORTED_FIELD_PROPS = ("ruser", "wuser", "sticky", "stickybit", "intr")


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
        for prop in UNSUPPORTED_FIELD_PROPS:
            if attr.get(prop):
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
