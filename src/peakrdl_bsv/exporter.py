"""PeakRDL BSV exporter."""

__authors__ = [
    "Vijayvithal Jahagirdar <jahagirdar.vs@gmail.com>",
]

from typing import List, Optional, Union
import sys

from systemrdl.node import (  # type: ignore
    AddrmapNode,
    RootNode,
)

from systemrdl import RDLCompiler, RDLWalker
from .print_bsv_signal import PrintBSVSignal
from .print_bsv_reg import PrintBSVReg
from .print_bsv_csr import PrintBSVCSR
import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(module)s %(funcName)s %(lineno)d %(levelname)s:: %(message)s",
)
logger = logging.getLogger(__name__)


class BSVExporter:  # pylint: disable=too-few-public-methods
    """PeakRDL BSV exporter main class."""

    def export(
        self,
        top_node: Union[AddrmapNode, RootNode],
        outputpath: str,
        input_files: Optional[List[str]] = None,
        rename: Optional[str] = None,
        depth: int = 0,
        test: bool = False,
        default_regwidth=None,
    ):
        """Writeout the BSV code."""
        logger.info(
            f"Options {top_node=}, {outputpath=}, {input_files=}, {rename=}, {depth=}, {test=}, {default_regwidth=}"
        )
        rdlc = RDLCompiler()
        try:
            for input_file in input_files:
                rdlc.compile_file(input_file)
                root = rdlc.elaborate()
        except Exception:
            sys.exit()
        # rename (--rename) changes top_node.inst_name away from the RDL's
        # own addrmap name; the output files are always named after
        # top_node.inst_name, so the cross-file `import X_signal::*;`/
        # `import X_reg::*;` statements in the reg/csr files must use the
        # same name too, not re-derive it from the addrmap node itself
        # (see PrintBSVReg/PrintBSVCSR's import_name parameter) -- doing
        # so previously left those imports referencing a package that
        # doesn't exist whenever --rename was used.
        import_name = top_node.inst_name
        fname = f"{outputpath}/{top_node.inst_name}"
        with open(fname + "_signal.bsv", "w") as file:
            walker = RDLWalker(unroll=True)
            walker.walk(root, PrintBSVSignal(file, test, default_regwidth))
        with open(fname + "_reg.bsv", "w") as file:
            walker = RDLWalker(unroll=True)
            walker.walk(root, PrintBSVReg(file, test, default_regwidth, import_name))
        with open(fname + "_csr.bsv", "w") as file:
            walker = RDLWalker(unroll=True)
            walker.walk(root, PrintBSVCSR(file, test, default_regwidth, import_name))
