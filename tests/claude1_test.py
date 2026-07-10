"""
Comprehensive test suite for peakrdl-bsv.

Verifies that the BSV exporter generates structurally correct Bluespec code
for every field property defined in the SystemRDL 2.0 specification.

Install dependencies before running:
    pip install systemrdl peakrdl jinja2 pytest

Run:
    pytest test_peakrdl_bsv.py -v
"""

import os
import re
import sys
import tempfile
import textwrap
import pytest

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _compile_and_export(rdl_text: str, tmpdir: str, test: bool = False):
    """
    Compile *rdl_text* with systemrdl and export BSV files into *tmpdir*.

    Returns a dict with keys 'signal', 'reg', 'csr' containing the
    text contents of the three generated files.
    """
    from systemrdl import RDLCompiler, RDLWalker
    import sys
    import io

    # Write the RDL source to a temp file
    rdl_path = os.path.join(tmpdir, "test.rdl")
    with open(rdl_path, "w") as f:
        f.write(rdl_text)

    rdlc = RDLCompiler()
    rdlc.compile_file(rdl_path)
    root = rdlc.elaborate()

    # Import the local package (project directory must be on sys.path)
    project_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if project_dir not in sys.path:
        sys.path.insert(0, project_dir)

    from peakrdl_bsv.print_bsv_signal import PrintBSVSignal
    from peakrdl_bsv.print_bsv_reg import PrintBSVReg
    from peakrdl_bsv.print_bsv_csr import PrintBSVCSR

    results = {}
    for suffix, cls in [
        ("signal", PrintBSVSignal),
        ("reg", PrintBSVReg),
        ("csr", PrintBSVCSR),
    ]:
        out_path = os.path.join(tmpdir, f"test_{suffix}.bsv")
        walker = RDLWalker(unroll=True)
        with open(out_path, "w") as f:
            walker.walk(root, cls(f, test, 32))
        with open(out_path) as f:
            results[suffix] = f.read()

    return results


def _has(text: str, pattern: str) -> bool:
    """Return True when *pattern* (regex) is found anywhere in *text*."""
    return bool(re.search(pattern, text))


def _not_has(text: str, pattern: str) -> bool:
    return not _has(text, pattern)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def tmpdir_str(tmp_path):
    return str(tmp_path)


# ===========================================================================
#  1. SW ACCESS PROPERTIES  (sw = r | w | rw | na)
# ===========================================================================


class TestSwAccess:
    """Tests for software access type (sw property)."""

    RDL_TEMPLATE = textwrap.dedent(
        """\
        addrmap test {{
            default hw = r;
            reg test_reg {{
                field {{ sw = {sw}; }} field0[8] = 0;
            }};
            test_reg reg0 @ 0x0;
        }};
    """
    )

    def test_sw_rw_generates_both_read_and_write_methods(self, tmpdir_str):
        rdl = self.RDL_TEMPLATE.format(sw="rw")
        bsv = _compile_and_export(rdl, tmpdir_str)
        sig = bsv["signal"]
        assert _has(sig, r"method Action write\("), "sw=rw must expose write method"
        assert _has(sig, r"method ActionValue.*read"), "sw=rw must expose read method"

    def test_sw_r_generates_only_read_method(self, tmpdir_str):
        rdl = self.RDL_TEMPLATE.format(sw="r")
        bsv = _compile_and_export(rdl, tmpdir_str)
        sig = bsv["signal"]
        assert _not_has(
            sig, r"method Action write\("
        ), "sw=r must NOT expose write method"
        assert _has(sig, r"method ActionValue.*read"), "sw=r must expose read method"

    def test_sw_w_generates_only_write_method(self, tmpdir_str):
        rdl = self.RDL_TEMPLATE.format(sw="w")
        bsv = _compile_and_export(rdl, tmpdir_str)
        sig = bsv["signal"]
        assert _has(sig, r"method Action write\("), "sw=w must expose write method"
        assert _not_has(
            sig, r"method ActionValue.*read"
        ), "sw=w must NOT expose read method"

    def test_sw_na_generates_no_bus_methods(self, tmpdir_str):
        # sw=na with hw=rw to avoid 'meaningless combination' compile error
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = na; hw = rw; } field0[8] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        sig = bsv["signal"]
        assert _not_has(
            sig, r"method Action write\("
        ), "sw=na must NOT expose write method"
        assert _not_has(
            sig, r"method ActionValue.*read"
        ), "sw=na must NOT expose read method"


# ===========================================================================
#  2. HW ACCESS PROPERTIES  (hw = r | w | rw | na)
# ===========================================================================


class TestHwAccess:
    """Tests for hardware access type (hw property)."""

    def _rdl(self, hw):
        return textwrap.dedent(
            f"""\
            addrmap test {{
                reg test_reg {{
                    field {{ sw = rw; hw = {hw}; }} field0[8] = 0;
                }};
                test_reg reg0 @ 0x0;
            }};
        """
        )

    def test_hw_r_generates_hw_read_method(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("r"), tmpdir_str)
        assert _has(
            bsv["signal"], r"method Bit.*_read"
        ), "hw=r must expose _read method"
        assert _not_has(
            bsv["signal"], r"method Action _write"
        ), "hw=r must NOT expose _write method"

    def test_hw_w_generates_hw_write_method(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("w"), tmpdir_str)
        assert _has(
            bsv["signal"], r"method Action _write"
        ), "hw=w must expose _write method"
        assert _not_has(
            bsv["signal"], r"method Bit.*_read"
        ), "hw=w must NOT expose _read method"

    def test_hw_rw_generates_both_hw_methods(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("rw"), tmpdir_str)
        sig = bsv["signal"]
        assert _has(sig, r"method Bit.*_read"), "hw=rw must expose _read"
        assert _has(sig, r"method Action _write"), "hw=rw must expose _write"

    def test_hw_na_generates_no_hw_methods(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = na; } field0[8] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        sig = bsv["signal"]
        assert _not_has(sig, r"method Bit.*_read"), "hw=na must NOT expose _read"
        assert _not_has(sig, r"method Action _write"), "hw=na must NOT expose _write"


# ===========================================================================
#  3. RESET PROPERTY
# ===========================================================================


class TestReset:
    """Tests for the reset property."""

    def test_nonzero_reset_value_passed_to_module(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = r; } field0[8] = 8'hAB;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        # The reg file instantiates mkCSRSignal_... with the reset value
        assert _has(
            bsv["reg"], r"mkCSRSignal_test_reg_field0\(171\)"
        ), "Reset value 0xAB (171 decimal) must appear in module instantiation"

    def test_zero_reset_value(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = r; } field0[8] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        assert _has(
            bsv["reg"], r"mkCSRSignal_test_reg_field0\(0\)"
        ), "Zero reset value must appear in module instantiation"


# ===========================================================================
#  4. SINGLEPULSE PROPERTY
# ===========================================================================


class TestSinglepulse:
    """Tests for the singlepulse property."""

    def test_singlepulse_generates_pulse_method(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = r; singlepulse; } field0[1] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        sig = bsv["signal"]
        assert _has(
            sig, r"method Bool pulse\(\)"
        ), "singlepulse must generate pulse() method"

    def test_singlepulse_field_self_clears(self, tmpdir_str):
        """The rule body must contain 'rr = 0' to self-clear on every cycle."""
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = r; singlepulse; } field0[1] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        assert _has(
            bsv["signal"], r"rr\s*=\s*0"
        ), "singlepulse must have self-clear assignment (rr = 0) in rule body"

    def test_no_singlepulse_no_pulse_method(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = r; } field0[1] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        assert _not_has(
            bsv["signal"], r"method Bool pulse\(\)"
        ), "Without singlepulse, pulse() must NOT be generated"


# ===========================================================================
#  5. SWACC / SWMOD PROPERTIES
# ===========================================================================


class TestSwaccSwmod:
    """Tests for swacc and swmod signal properties."""

    def test_swacc_generates_swacc_method(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = r; swacc; } field0[8] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        assert _has(
            bsv["signal"], r"method Bool swacc\(\)"
        ), "swacc property must generate swacc() Bool method"

    def test_swmod_generates_swmod_method(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = r; swmod; } field0[8] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        assert _has(
            bsv["signal"], r"method Bool swmod\(\)"
        ), "swmod property must generate swmod() Bool method"

    def test_no_swacc_no_swacc_method(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = r; } field0[8] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        assert _not_has(
            bsv["signal"], r"method Bool swacc\(\)"
        ), "Without swacc, swacc() must NOT be generated"

    def test_no_swmod_no_swmod_method(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = r; } field0[8] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        assert _not_has(
            bsv["signal"], r"method Bool swmod\(\)"
        ), "Without swmod, swmod() must NOT be generated"


# ===========================================================================
#  6. ANDED / ORED / XORED PROPERTIES
# ===========================================================================


class TestReductionProperties:
    """Tests for anded, ored, and xored reduction methods."""

    def _rdl(self, prop):
        return textwrap.dedent(
            f"""\
            addrmap test {{
                reg test_reg {{
                    field {{ sw = rw; hw = r; {prop}; }} field0[8] = 0;
                }};
                test_reg reg0 @ 0x0;
            }};
        """
        )

    def test_anded_generates_anded_method(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("anded"), tmpdir_str)
        assert _has(
            bsv["signal"], r"method Bool anded\(\)"
        ), "anded must generate anded() method"

    def test_ored_generates_ored_method(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("ored"), tmpdir_str)
        assert _has(
            bsv["signal"], r"method Bool ored\(\)"
        ), "ored must generate ored() method"

    def test_xored_generates_xored_method(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("xored"), tmpdir_str)
        assert _has(
            bsv["signal"], r"method Bool xored\(\)"
        ), "xored must generate xored() method"

    def test_none_generates_no_reduction_methods(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = r; } field0[8] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        sig = bsv["signal"]
        assert _not_has(
            sig, r"method Bool anded\(\)"
        ), "anded() must not appear without anded property"
        assert _not_has(
            sig, r"method Bool ored\(\)"
        ), "ored() must not appear without ored property"
        assert _not_has(
            sig, r"method Bool xored\(\)"
        ), "xored() must not appear without xored property"


# ===========================================================================
#  7. COUNTER PROPERTY
# ===========================================================================


class TestCounter:
    """Tests for the counter property and related incr/decr methods."""

    def test_counter_generates_incr_decr_methods(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = r; hw = r; counter; } field0[8] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        sig = bsv["signal"]
        assert _has(sig, r"method Action incr\("), "counter must generate incr() method"
        assert _has(sig, r"method Action decr\("), "counter must generate decr() method"

    def test_no_counter_no_incr_decr(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = r; } field0[8] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        sig = bsv["signal"]
        assert _not_has(
            sig, r"method Action incr\("
        ), "Without counter, incr() must NOT be generated"
        assert _not_has(
            sig, r"method Action decr\("
        ), "Without counter, decr() must NOT be generated"

    def test_counter_uses_rwire_for_incr_decr(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = r; hw = r; counter; } field0[8] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        sig = bsv["signal"]
        assert _has(sig, r"r_incr"), "counter must declare r_incr RWire"
        assert _has(sig, r"r_decr"), "counter must declare r_decr RWire"


# ===========================================================================
#  8. ONREAD PROPERTY  (rclr, rset)
# ===========================================================================


class TestOnread:
    """Tests for the onread property values."""

    def test_rclr_triggers_clear_on_read(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = r; hw = w; onread = rclr; } field0[8] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        # The read method body must send pw_clear
        assert _has(
            bsv["signal"], r"pw_clear\.send\(\)"
        ), "onread=rclr must call pw_clear.send() inside read method"

    def test_rset_triggers_set_on_read(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = r; hw = w; onread = rset; } field0[8] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        assert _has(
            bsv["signal"], r"pw_set\.send\(\)"
        ), "onread=rset must call pw_set.send() inside read method"


# ===========================================================================
#  9. ONWRITE PROPERTY  (woset, woclr)
# ===========================================================================


class TestOnwrite:
    """Tests for the onwrite property values."""

    def test_woclr_triggers_clear_on_write_one(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = r; onwrite = woclr; } field0[8] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        # woclr means write-1-to-clear: pw_clear.send() when data==1
        assert _has(
            bsv["signal"], r"pw_clear\.send\(\)"
        ), "onwrite=woclr must call pw_clear.send() inside write method"

    def test_woset_triggers_set_on_write_one(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = r; onwrite = woset; } field0[8] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        assert _has(
            bsv["signal"], r"pw_set\.send\(\)"
        ), "onwrite=woset must call pw_set.send() inside write method"


# ===========================================================================
# 10. REGISTER-LEVEL STRUCTURE
# ===========================================================================


class TestRegisterStructure:
    """Tests for the generated register-level BSV module."""

    def _rdl_multi_field(self):
        return textwrap.dedent(
            """\
            addrmap test {
                reg ctrl_reg {
                    field { sw = rw; hw = r; } enable[1] = 0;
                    field { sw = rw; hw = r; } mode[3] = 0;
                    field { sw = r;  hw = w; } status[4] = 0;
                };
                ctrl_reg reg0 @ 0x0;
            };
        """
        )

    def test_reg_file_imports_signal_file(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_multi_field(), tmpdir_str)
        assert _has(
            bsv["reg"], r"import test_signal"
        ), "Reg file must import the signal file"

    def test_reg_module_interface_declared(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_multi_field(), tmpdir_str)
        assert _has(
            bsv["reg"], r"interface ConfigReg_ctrl_reg"
        ), "Reg file must define ConfigReg_ctrl_reg interface"

    def test_reg_module_declared(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_multi_field(), tmpdir_str)
        assert _has(
            bsv["reg"], r"module mkConfigReg_ctrl_reg"
        ), "Reg file must define mkConfigReg_ctrl_reg module"

    def test_reg_all_fields_instantiated(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_multi_field(), tmpdir_str)
        reg = bsv["reg"]
        assert _has(
            reg, r"mkCSRSignal_ctrl_reg_enable"
        ), "enable signal must be instantiated"
        assert _has(
            reg, r"mkCSRSignal_ctrl_reg_mode"
        ), "mode signal must be instantiated"
        assert _has(
            reg, r"mkCSRSignal_ctrl_reg_status"
        ), "status signal must be instantiated"

    def test_sw_writable_field_in_write_method(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_multi_field(), tmpdir_str)
        reg = bsv["reg"]
        # enable and mode are sw=rw → appear in write method
        assert _has(
            reg, r"sig_enable\.bus\.write"
        ), "sw-writable enable field must appear in write method"
        assert _has(
            reg, r"sig_mode\.bus\.write"
        ), "sw-writable mode field must appear in write method"

    def test_sw_readonly_field_not_in_write_method(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_multi_field(), tmpdir_str)
        reg = bsv["reg"]
        assert _not_has(
            reg, r"sig_status\.bus\.write"
        ), "sw=r status field must NOT appear in register write method"

    def test_sw_readable_field_in_read_method(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_multi_field(), tmpdir_str)
        reg = bsv["reg"]
        assert _has(
            reg, r"sig_enable\.bus\.read"
        ), "sw-readable enable must appear in read method"
        assert _has(
            reg, r"sig_mode\.bus\.read"
        ), "sw-readable mode must appear in read method"
        assert _has(
            reg, r"sig_status\.bus\.read"
        ), "sw-readable status must appear in read method"

    def test_hw_interface_exposes_hw_readable_fields(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_multi_field(), tmpdir_str)
        reg = bsv["reg"]
        # hw=r fields must be reflected by sig_X.hw in the value() method
        assert _has(
            reg, r"sig_enable\.hw"
        ), "hw-readable enable must contribute to value()"
        assert _has(reg, r"sig_mode\.hw"), "hw-readable mode must contribute to value()"

    def test_hw_writeonly_field_zero_padded_in_value(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_multi_field(), tmpdir_str)
        reg = bsv["reg"]
        # status is hw=w (not hw readable by HW from reg perspective) → padded with 0
        assert _has(
            reg, r"'b0"
        ), "hw-write-only status field must contribute 0 to value()"

    def test_reg_bus_interface_declared(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_multi_field(), tmpdir_str)
        reg = bsv["reg"]
        assert _has(
            reg, r"interface ConfigReg_Bus_ctrl_reg"
        ), "Bus interface must be declared"
        assert _has(
            reg, r"method Action write\("
        ), "Register bus write method must be present"
        assert _has(
            reg, r"method ActionValue.*read"
        ), "Register bus read method must be present"


# ===========================================================================
# 11. FIELD BIT-POSITION / WIDTH
# ===========================================================================


class TestBitPositions:
    """Verify that high/low bit positions are correctly reflected in reg file."""

    def test_field_bit_range_in_write_strobe(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = r; } lo_field[4] = 0;   // bits [3:0]
                    field { sw = rw; hw = r; } hi_field[4] = 0;   // bits [7:4]
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        reg = bsv["reg"]
        # lo_field occupies [3:0]
        assert _has(
            reg, r"\[3:0\]"
        ), "Low field bit range [3:0] must appear in reg file"
        # hi_field occupies [7:4]
        assert _has(
            reg, r"\[7:4\]"
        ), "High field bit range [7:4] must appear in reg file"

    def test_wide_field_width_reflected(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = r; } wide[16] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        sig = bsv["signal"]
        assert _has(
            sig, r"Bit#\(16\)"
        ), "16-bit field width must appear in signal interface"


# ===========================================================================
# 12. REGISTER WIDTH (regwidth)
# ===========================================================================


class TestRegWidth:
    """Tests that regwidth property is reflected in generated code."""

    def test_default_32bit_register(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = r; } field0[8] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        reg = bsv["reg"]
        # Default regwidth is 32
        assert _has(
            reg, r"Bit#\(32\)"
        ), "Default 32-bit regwidth must appear in reg interface"

    def test_explicit_64bit_register(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    regwidth = 64;
                    field { sw = rw; hw = r; } field0[8] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        reg = bsv["reg"]
        assert _has(
            reg, r"Bit#\(64\)"
        ), "Explicit 64-bit regwidth must appear in reg interface"


# ===========================================================================
# 13. CSR MODULE (address decoding)
# ===========================================================================


class TestCSRModule:
    """Tests for the top-level CSR address-decoding module."""

    def _rdl_two_regs(self):
        return textwrap.dedent(
            """\
            addrmap test {
                reg reg_a {
                    field { sw = rw; hw = r; } data[8] = 0;
                };
                reg reg_b {
                    field { sw = rw; hw = r; } ctrl[8] = 0;
                };
                reg_a a @ 0x00;
                reg_b b @ 0x04;
            };
        """
        )

    def test_csr_imports_reg_file(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_two_regs(), tmpdir_str)
        assert _has(bsv["csr"], r"import test_reg"), "CSR file must import the reg file"

    def test_csr_imports_vector(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_two_regs(), tmpdir_str)
        assert _has(bsv["csr"], r"import Vector"), "CSR file must import Vector library"

    def test_csr_interface_declared(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_two_regs(), tmpdir_str)
        assert _has(
            bsv["csr"], r"interface ConfigCSR_test"
        ), "CSR module must declare ConfigCSR_test interface"

    def test_csr_module_declared(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_two_regs(), tmpdir_str)
        assert _has(
            bsv["csr"], r"module mkConfigCSR_test"
        ), "CSR module must declare mkConfigCSR_test module"

    def test_csr_synthesize_attribute(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_two_regs(), tmpdir_str)
        assert _has(
            bsv["csr"], r"\(\*synthesize\*\)"
        ), "CSR module must have (*synthesize*) attribute"

    def test_csr_both_registers_instantiated(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_two_regs(), tmpdir_str)
        csr = bsv["csr"]
        assert _has(csr, r"mkConfigReg_a"), "Register a must be instantiated in CSR"
        assert _has(csr, r"mkConfigReg_b"), "Register b must be instantiated in CSR"

    def test_csr_address_constants_declared(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_two_regs(), tmpdir_str)
        csr = bsv["csr"]
        assert _has(csr, r"address_a"), "Address alias for reg a must be declared"
        assert _has(csr, r"address_b"), "Address alias for reg b must be declared"

    def test_csr_address_values_correct(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_two_regs(), tmpdir_str)
        csr = bsv["csr"]
        assert _has(csr, r"= 0;"), "Address 0x0 must appear"
        assert _has(csr, r"= 4;"), "Address 0x4 must appear"

    def test_csr_write_dispatches_to_both_regs(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_two_regs(), tmpdir_str)
        csr = bsv["csr"]
        assert _has(csr, r"reg_a\.bus\.write"), "CSR write must dispatch to reg_a"
        assert _has(csr, r"reg_b\.bus\.write"), "CSR write must dispatch to reg_b"

    def test_csr_read_dispatches_to_both_regs(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_two_regs(), tmpdir_str)
        csr = bsv["csr"]
        assert _has(csr, r"reg_a\.bus\.read"), "CSR read must dispatch to reg_a"
        assert _has(csr, r"reg_b\.bus\.read"), "CSR read must dispatch to reg_b"

    def test_csr_write_strobe_expansion(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_two_regs(), tmpdir_str)
        csr = bsv["csr"]
        # The wstrb expansion uses Vector and unpack
        assert _has(
            csr, r"wstrb_expanded"
        ), "CSR must expand wstrb to bit-granular mask"

    def test_csr_hw_interfaces_exposed(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_two_regs(), tmpdir_str)
        csr = bsv["csr"]
        assert _has(csr, r"ConfigReg_HW_a"), "CSR must expose HW interface for reg a"
        assert _has(csr, r"ConfigReg_HW_b"), "CSR must expose HW interface for reg b"

    def test_csr_address_width_sufficient(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_two_regs(), tmpdir_str)
        csr = bsv["csr"]
        # Address space is ≥8 bytes → addr_width = ceil(log2(total_size))
        assert _has(csr, r"Bit#\(\d+\)"), "CSR must declare address width"


# ===========================================================================
# 14. MULTIPLE REGISTERS / MULTI-FIELD INTEGRATION
# ===========================================================================


class TestIntegration:
    """End-to-end integration tests with realistic register maps."""

    def test_full_control_status_map(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap soc_csr {
                reg control {
                    field { sw = rw; hw = r; } enable[1]  = 0;
                    field { sw = rw; hw = r; } speed[3]   = 0;
                    field { sw = rw; hw = r; } mode[4]    = 0;
                };
                reg status {
                    field { sw = r; hw = w; } ready[1]   = 0;
                    field { sw = r; hw = w; } error[1]   = 0;
                    field { sw = r; hw = w; } count[6]   = 0;
                };
                reg irq_ctrl {
                    field { sw = rw; hw = r; swacc; } irq_en[8] = 0;
                };
                reg irq_status {
                    field { sw = rw; hw = w; onread = rclr; swmod; } irq_pend[8] = 0;
                };
                control  ctrl   @ 0x00;
                status   stat   @ 0x04;
                irq_ctrl ic     @ 0x08;
                irq_status is   @ 0x0C;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)

        # Signal file checks
        sig = bsv["signal"]
        assert _has(sig, r"method Bool swacc\(\)"), "irq_en swacc method missing"
        assert _has(sig, r"method Bool swmod\(\)"), "irq_pend swmod method missing"
        assert _has(sig, r"pw_clear\.send\(\)"), "irq_pend rclr missing"

        # Reg file checks
        reg = bsv["reg"]
        assert _has(reg, r"mkConfigReg_control"), f"control module missing {reg=}"
        assert _has(reg, r"mkConfigReg_status"), "status module missing"
        assert _has(reg, r"mkConfigReg_irq_ctrl"), "irq_ctrl module missing"
        assert _has(reg, r"mkConfigReg_irq_status"), "irq_status module missing"

        # CSR file checks
        csr = bsv["csr"]
        assert _has(csr, r"import soc_csr_reg"), "CSR must import reg file"
        assert _has(csr, r"mkConfigCSR_soc_csr"), "CSR module name wrong"
        assert _has(csr, r"address_ctrl"), "ctrl address alias missing"
        assert _has(csr, r"address_stat"), "stat address alias missing"
        assert _has(csr, r"address_ic"), "ic address alias missing"
        assert _has(csr, r"address_is"), "is address alias missing"

    def test_counter_register(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg perf_cnt {
                    field { sw = r; hw = r; counter; } hits[16] = 0;
                    field { sw = r; hw = r; counter; } misses[16] = 0;
                };
                perf_cnt pc @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        sig = bsv["signal"]
        assert _has(
            sig, r"method Action incr\(Bit#\(16\)"
        ), "hits incr method must be 16-bit"
        assert _has(
            sig, r"method Action decr\(Bit#\(16\)"
        ), "hits decr method must be 16-bit"

    def test_singlepulse_control_register(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg trigger {
                    field { sw = rw; hw = r; singlepulse; } go[1] = 0;
                    field { sw = rw; hw = r; singlepulse; } reset[1] = 0;
                };
                trigger trig @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        sig = bsv["signal"]
        # Both fields should have pulse() methods
        pulse_count = len(re.findall(r"method Bool pulse\(\)", sig))
        assert pulse_count >= 2, f"Expected 2 pulse() methods, got {pulse_count}"

    def test_event_register_with_rclr_and_hwset(self, tmpdir_str):
        """Event register: hw sets it, SW read clears it."""
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg event_reg {
                    field { sw = r; hw = w; hwset; onread = rclr; precedence = hw; } ev[8] = 0;
                };
                event_reg er @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        sig = bsv["signal"]
        assert _has(sig, r"pw_clear\.send\(\)"), "onread=rclr must clear on sw read"
        assert _has(
            sig, r"method Action _write\("
        ), "hwset=w field must have HW write method"


# ===========================================================================
# 15. TEST MODE (gentest flag)
# ===========================================================================


class TestGentest:
    """Tests for the test-mode synthesize wrapper generation."""

    def _simple_rdl(self):
        return textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = r; } field0[8] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )

    def test_gentest_true_creates_synthesize_wrapper(self, tmpdir_str):
        bsv = _compile_and_export(self._simple_rdl(), tmpdir_str, test=True)
        sig = bsv["signal"]
        assert _has(
            sig, r"testcsrreg_test_reg_field0"
        ), "With gentest=True, a testcsrreg_ synthesize wrapper must be generated"
        assert _has(
            sig, r"\(\*synthesize\*\)"
        ), "Test wrapper must carry (*synthesize*) attribute"

    def test_gentest_false_omits_wrapper(self, tmpdir_str):
        bsv = _compile_and_export(self._simple_rdl(), tmpdir_str, test=False)
        sig = bsv["signal"]
        assert _not_has(
            sig, r"testcsrreg_test_reg_field0"
        ), "With gentest=False, no testcsrreg_ wrapper should be generated"


# ===========================================================================
# 16. SIGNAL FILE – INTERNAL WIRE DECLARATIONS
# ===========================================================================


class TestSignalInternals:
    """Verify correct internal BSV wire declarations inside signal modules."""

    def _simple_rdl(self):
        return textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = r; } field0[8] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )

    def test_register_storage_declared(self, tmpdir_str):
        bsv = _compile_and_export(self._simple_rdl(), tmpdir_str)
        assert _has(
            bsv["signal"], r"Reg#\(Bit#\(\d+\)\)\s+r"
        ), "Signal module must declare a Reg storage element"

    def test_pulse_wires_declared(self, tmpdir_str):
        bsv = _compile_and_export(self._simple_rdl(), tmpdir_str)
        sig = bsv["signal"]
        assert _has(sig, r"PulseWire\s+pw_set"), "pw_set PulseWire must be declared"
        assert _has(sig, r"PulseWire\s+pw_clear"), "pw_clear PulseWire must be declared"

    def test_rwire_for_sw_write_declared(self, tmpdir_str):
        bsv = _compile_and_export(self._simple_rdl(), tmpdir_str)
        assert _has(
            bsv["signal"], r"sw_wdata"
        ), "sw_wdata RWire must be declared for sw-writable field"

    def test_rule_r_write_declared(self, tmpdir_str):
        bsv = _compile_and_export(self._simple_rdl(), tmpdir_str)
        assert _has(
            bsv["signal"], r"rule r_write"
        ), "Storage update rule r_write must be declared"

    def test_interface_nesting_structure(self, tmpdir_str):
        bsv = _compile_and_export(self._simple_rdl(), tmpdir_str)
        sig = bsv["signal"]
        # Outer module exposes both hw and bus sub-interfaces
        assert _has(
            sig, r"interface HW_test_reg_field0 hw"
        ), "Signal module must expose 'hw' sub-interface"
        assert _has(
            sig, r"interface SW_test_reg_field0 bus"
        ), "Signal module must expose 'bus' (SW) sub-interface"


# ===========================================================================
# 17. WSTRB (write-strobe) MASK LOGIC
# ===========================================================================


class TestWriteStrobe:
    """Tests that the write-strobe masking logic is correctly generated."""

    def test_write_method_accepts_wstrb_parameter(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = r; } field0[8] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        sig = bsv["signal"]
        # SW write method signature includes both data and wstrb params
        assert _has(
            sig, r"method Action write\(Bit#.*data.*wstrb\)"
        ), "SW write method must accept both data and wstrb parameters"

    def test_wstrb_combined_with_data_in_rule(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = r; } field0[8] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        sig = bsv["signal"]
        # The masked-write expression: (data & wstrb) | (~wstrb & r)
        assert _has(
            sig, r"tpl_2\(v\)"
        ), "Wstrb must be extracted via tpl_2 in rule body for masked writes"


# ===========================================================================
# 18. MULTIPLE ADDRESS MAPS (nested)
# ===========================================================================


class TestNestedAddrmap:
    """Tests for nested/multiple address map handling."""

    def test_nested_addrmap_all_registers_exported(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap outer {
                reg reg_x {
                    field { sw = rw; hw = r; } x[8] = 0;
                };
                reg reg_y {
                    field { sw = r; hw = w; } y[8] = 0;
                };
                reg_x rx @ 0x0;
                reg_y ry @ 0x4;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        csr = bsv["csr"]
        assert _has(csr, r"mkConfigReg_reg_x"), "reg_x must appear in CSR"
        assert _has(csr, r"mkConfigReg_reg_y"), "reg_y must appear in CSR"


# ===========================================================================
# 19. NAME / DESC PROPERTIES  (metadata – should not crash export)
# ===========================================================================


class TestMetadataProperties:
    """Verify that desc/name metadata properties do not break code generation."""

    def test_name_and_desc_do_not_break_export(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg ctrl {
                    name = "Control Register";
                    desc = "Top-level control register for the device.";
                    field {
                        name = "Enable Bit";
                        desc = "Set to 1 to enable the device.";
                        sw = rw; hw = r;
                    } enable[1] = 0;
                };
                ctrl c @ 0x0;
            };
        """
        )
        # Should complete without raising an exception
        bsv = _compile_and_export(rdl, tmpdir_str)
        assert _has(
            bsv["signal"], r"mkCSRSignal_ctrl_enable"
        ), f"Signal module must be generated even when name/desc are set {bsv=}"


# ===========================================================================
# 20. EDGE CASES
# ===========================================================================


class TestEdgeCases:
    """Boundary and edge-case tests."""

    def test_single_bit_field(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = r; } bit0[1] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        assert _has(
            bsv["signal"], r"Bit#\(1\)"
        ), "1-bit field width must appear correctly"

    def test_32_bit_field_fills_register(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = r; } full[32] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        assert _has(
            bsv["signal"], r"Bit#\(32\)"
        ), "32-bit field width must appear correctly"

    def test_many_fields_in_one_register(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg dense {
                    field { sw = rw; hw = r; } f0[4] = 0;
                    field { sw = rw; hw = r; } f1[4] = 0;
                    field { sw = rw; hw = r; } f2[4] = 0;
                    field { sw = rw; hw = r; } f3[4] = 0;
                    field { sw = rw; hw = r; } f4[4] = 0;
                    field { sw = rw; hw = r; } f5[4] = 0;
                    field { sw = rw; hw = r; } f6[4] = 0;
                    field { sw = rw; hw = r; } f7[4] = 0;
                };
                dense d @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        reg = bsv["reg"]
        for i in range(8):
            assert _has(reg, rf"sig_f{i}"), f"Field f{i} must appear in reg file"

    def test_address_at_high_offset(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = r; } d[8] = 0;
                };
                test_reg r0 @ 0x100;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        assert _has(
            bsv["csr"], r"256"
        ), "Address offset 0x100 (256 decimal) must appear in CSR"

    def test_nonzero_hexadecimal_reset(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = rw; hw = r; } d[8] = 8'hFF;
                };
                test_reg r0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        # 0xFF = 255
        assert _has(
            bsv["reg"], r"255"
        ), "Reset value 0xFF (255) must appear in reg instantiation"
