from peakrdl_bsv.print_bsv_reg import PrintBSVReg
import pytest
from systemrdl import RDLCompiler, RDLWalker, RDLListener


def test_readable_withpeakrdl(mocker):
    mock_file = mocker.mock_open(
        read_data="""
addrmap Foo {
  alignment=4;
default hw=na;
default sw=na;
  default regwidth=32;
    reg{
field {sw=r;desc="major_rev";} major_rev[23:16]=10;
        }foo;
    };
"""
    )
    mocker.patch("builtins.open", mock_file)

    rdlc = RDLCompiler()
    rdlc.compile_file("dummy.rdl")
    root = rdlc.elaborate()
    walker = RDLWalker(unroll=True)
    with open("test_reg.bsv", "w") as file:
        walker.walk(root, PrintBSVReg(file, False))
        assert 1
