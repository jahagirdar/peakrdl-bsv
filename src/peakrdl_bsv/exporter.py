"""PeakRDL BSV exporter."""

__authors__ = [
    "Vijayvithal Jahagirdar <jahagirdar.vs@gmail.com>",
]

from collections import OrderedDict
from dataclasses import dataclass
from functools import reduce
from operator import mul
from pathlib import Path
from typing import List, Optional, Union
import sys

from systemrdl.messages import MessageHandler  # type: ignore
from systemrdl.node import (  # type: ignore
    AddressableNode,
    AddrmapNode,
    FieldNode,
    MemNode,
    Node,
    RegfileNode,
    RegNode,
    RootNode,
)

from systemrdl import RDLCompiler, RDLCompileError, RDLWalker
from .bsv import PrintReadReg, PrintWriteReg
from .verilog import PrintVerilog
from .bsvinfo import PrintBSVInfo
from .newbsv import PrintBSV


class BSVExporter:  # pylint: disable=too-few-public-methods
    """PeakRDL BSV exporter main class."""

    def export(self,
               top_node: Union[AddrmapNode, RootNode],
               outputpath: str,
               input_files: Optional[List[str]] = None,
               rename: Optional[str] = None,
               depth: int = 0,
               ):
        print(f"{top_node.inst.inst_name} {input_files} {outputpath}")
        rdlc = RDLCompiler()
        try:
            for input_file in input_files:
                rdlc.compile_file(input_file)
                root=rdlc.elaborate()
        except:
            sys.exit()
        fname=f"{outputpath}/{top_node.inst.inst_name}"
        with open(fname+'.bsv','w') as file:
            walker=RDLWalker(unroll=True)
            walker.walk(root,PrintReadReg(file))
            walker.walk(root,PrintWriteReg(file))
            walker.walk(root,PrintBSV(file))
        with open(fname+".v",'w') as vfile:
            walker.walk(root,PrintVerilog(vfile))
        with open(fname+".vinfo",'w') as bsvfile:
            walker.walk(root,PrintBSVInfo(bsvfile))
