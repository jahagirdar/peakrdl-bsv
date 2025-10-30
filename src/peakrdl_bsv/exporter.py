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
    ):
        """Writeout the BSV code."""
        rdlc = RDLCompiler()
        try:
            for input_file in input_files:
                rdlc.compile_file(input_file)
                root = rdlc.elaborate()
        except Exception:
            sys.exit()
        fname = f"{outputpath}/{top_node.inst.inst_name}"
        with open(fname + "_signal.bsv", "w") as file:
            walker = RDLWalker(unroll=True)
            walker.walk(root, PrintBSVSignal(file, test))
        with open(fname + "_reg.bsv", "w") as file:
            walker = RDLWalker(unroll=True)
            walker.walk(root, PrintBSVReg(file, test))
        with open(fname + "_csr.bsv", "w") as file:
            walker = RDLWalker(unroll=True)
            walker.walk(root, PrintBSVCSR(file, test))
