from peakrdl_bsv.print_bsv_reg import PrintBSVReg
import pytest
from systemrdl import RDLCompiler, RDLWalker, RDLListener


def test_readable(mocker):
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
    walker.walk(root, PRINT())


class PRINT(RDLListener):
    def enter_Field(self, node):
        print(
            f'''
// inst.properties['sw']:                   , {node.inst.properties.get('sw')}
// node.get_property('sw'):                 , {node.get_property('sw')}
// type(get_property('sw')):                , {type(node.get_property('sw'))}
// node.inst.properties.get('sw_readable'): , {node.inst.properties.get('sw_readable')}
// node.is_sw_readable:                     , {node.is_sw_readable}
            \n"""
            '''
        )
        assert node.is_sw_readable, "Should be readable"


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
    with open("test" + "_reg.bsv", "w") as file:
        walker.walk(root, PrintBSVReg(file, False))
        assert 1
