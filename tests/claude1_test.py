"""
Comprehensive test suite for peakrdl-bsv.

Verifies that the BSV exporter generates structurally correct Bluespec code
for every field property defined in the SystemRDL 2.0 specification.

Install dependencies before running:
    pip install systemrdl peakrdl jinja2 pytest

Run:
    pytest test_peakrdl_bsv.py -v
"""

import logging
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


def _r_write_rule(sig: str, module: str = "mkCSRSignal") -> str:
    """Extract one signal module's r_write rule body."""
    m = re.search(rf"module {module}\S*?\(.*?rule r_write;(.*?)endrule", sig, re.S)
    assert m, f"r_write rule for {module} must be present"
    return m.group(1)


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

    def test_sw_na_rejected_by_compiler(self, tmpdir_str):
        # sw=na on a field inside a software register map is flagged by
        # systemrdl-compiler itself as a hard compile error ("not accessible
        # by software ... what's the point?") regardless of hw= — there is
        # no BSV to generate for this case, so just assert it's rejected.
        from systemrdl.messages import RDLCompileError

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
        with pytest.raises(RDLCompileError):
            _compile_and_export(rdl, tmpdir_str)


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
        # The reg file instantiates mkCSRSignal_... with the reset value.
        # Signal modules are named after the register INSTANCE (reg0), not
        # its type (test_reg), so multiple instances of the same reg type
        # (or register arrays) don't collide.
        assert _has(
            bsv["reg"], r"mkCSRSignal_reg0_field0\(171\)"
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
            bsv["reg"], r"mkCSRSignal_reg0_field0\(0\)"
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

    def test_bare_counter_is_increment_only(self, tmpdir_str):
        # A bare `counter;` field (no incr/decr-specific properties) is
        # increment-only per the compiler's own is_up_counter/
        # is_down_counter inference, and incrvalue defaults to a fixed 1,
        # so incr() is a zero-arg pulse rather than a count argument.
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
        assert _has(
            sig, r"method Action incr\(\)"
        ), "bare counter must generate a zero-arg incr() pulse"
        assert _not_has(
            sig, r"method Action decr"
        ), "bare (increment-only) counter must NOT generate decr()"

    def test_bidirectional_counter_with_explicit_widths(self, tmpdir_str):
        # Setting incrwidth/decrwidth explicitly both configures both
        # directions and switches each side to the count-argument form
        # instead of a fixed-amount pulse.
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = r; hw = r; counter; incrwidth=8; decrwidth=8; } field0[8] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        sig = bsv["signal"]
        assert _has(
            sig, r"method Action incr\(Bit#\(8\) count\)"
        ), "explicit incrwidth must generate an incr(count) method"
        assert _has(
            sig, r"method Action decr\(Bit#\(8\) count\)"
        ), "explicit decrwidth must generate a decr(count) method"

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
        # RWires back the count-argument form; a bare counter (fixed
        # incrvalue, no explicit width) uses a PulseWire instead since
        # there's no runtime data to carry.
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg test_reg {
                    field { sw = r; hw = r; counter; incrwidth=8; decrwidth=8; } field0[8] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        sig = bsv["signal"]
        assert _has(sig, r"r_incr"), "explicit incrwidth must declare r_incr RWire"
        assert _has(sig, r"r_decr"), "explicit decrwidth must declare r_decr RWire"

    def test_bare_counter_uses_pulsewire(self, tmpdir_str):
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
        assert _has(
            sig, r"PulseWire\s+pw_incr"
        ), "bare (fixed-amount) counter must use a PulseWire, not r_incr"
        assert _not_has(sig, r"r_incr"), "bare counter must NOT declare r_incr RWire"


# ===========================================================================
#  7b. COUNTER REFINEMENTS  (incrvalue/decrvalue, saturate, threshold,
#      overflow/underflow)
# ===========================================================================


class TestCounterRefinements:
    """Tests for counter refinements beyond the bare incr()/decr() pair."""

    def _rdl(self, field_body):
        return textwrap.dedent(
            f"""\
            addrmap test {{
                reg test_reg {{
                    field {{ sw = r; hw = r; counter; {field_body} }} field0[8] = 0;
                }};
                test_reg reg0 @ 0x0;
            }};
        """
        )

    def test_incrvalue_generates_zero_arg_pulse_with_fixed_amount(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("incrvalue = 5;"), tmpdir_str)
        sig = bsv["signal"]
        assert _has(
            sig, r"method Action incr\(\)"
        ), "fixed incrvalue must generate a zero-arg incr() pulse"
        assert _has(
            sig, r"8'd5"
        ), "the fixed increment amount must appear as a sized literal"

    def test_incrwidth_generates_narrower_count_argument(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("incrwidth = 3;"), tmpdir_str)
        sig = bsv["signal"]
        assert _has(
            sig, r"method Action incr\(Bit#\(3\) count\)"
        ), "incrwidth must narrow the incr() count argument"

    def test_incrsaturate_clamps_instead_of_wrapping(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("incrsaturate;"), tmpdir_str)
        rule = self._r_write_rule(bsv["signal"])
        assert _has(
            rule, r"TAdd#\(8,1\)"
        ), "incrsaturate must use a widened intermediate to detect the clamp"
        assert _has(
            rule, r"8'd255"
        ), "bool incrsaturate must clamp at the field's max value (255)"

    def test_incrsaturate_with_explicit_ceiling(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("incrsaturate = 100;"), tmpdir_str)
        rule = self._r_write_rule(bsv["signal"])
        assert _has(
            rule, r"8'd100"
        ), "int incrsaturate must clamp at the given ceiling, not the field max"

    def test_overflow_generates_pulse_output(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("overflow;"), tmpdir_str)
        sig = bsv["signal"]
        assert _has(
            sig, r"method Bool overflow\(\)"
        ), "overflow must generate an output pulse method"
        rule = self._r_write_rule(sig)
        assert _has(
            rule, r"pw_overflow\.send\(\)"
        ), "overflow must fire pw_overflow when the increment wraps"

    def test_incrthreshold_generates_level_output(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("incrthreshold = 200;"), tmpdir_str)
        sig = bsv["signal"]
        assert _has(
            sig, r"method Bool incrthreshold\(\)"
        ), "incrthreshold must generate an output method"
        assert _has(
            sig, r"r\s*>=\s*8'd200"
        ), "incrthreshold must compare the stored value against the given level"

    def test_decrvalue_generates_zero_arg_pulse_with_fixed_amount(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("decrvalue = 2;"), tmpdir_str)
        sig = bsv["signal"]
        assert _has(
            sig, r"method Action decr\(\)"
        ), "fixed decrvalue must generate a zero-arg decr() pulse"
        assert _not_has(
            sig, r"method Action incr"
        ), "decrvalue alone must make the counter decrement-only"

    def test_decrsaturate_clamps_instead_of_wrapping(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("decrsaturate = 10;"), tmpdir_str)
        rule = self._r_write_rule(bsv["signal"])
        assert _has(
            rule, r"TAdd#\(8,1\)"
        ), "decrsaturate must use a widened intermediate to detect the clamp"
        assert _has(rule, r"8'd10"), "decrsaturate must clamp at the given floor"

    def test_underflow_generates_pulse_output(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("underflow;"), tmpdir_str)
        sig = bsv["signal"]
        assert _has(
            sig, r"method Bool underflow\(\)"
        ), "underflow must generate an output pulse method"
        rule = self._r_write_rule(sig)
        assert _has(
            rule, r"pw_underflow\.send\(\)"
        ), "underflow must fire pw_underflow when the decrement would go negative"

    def test_dynamic_incrvalue_reference_warns(self, tmpdir_str, caplog):
        # incrvalue may reference an external signal/field per the spec;
        # that dynamic form isn't modeled, so it must warn (not silently
        # produce a fixed-amount pulse using some arbitrary default).
        rdl = textwrap.dedent(
            """\
            addrmap test {
                signal { } bump;
                reg test_reg {
                    field { sw = r; hw = r; counter; incrvalue = bump; } field0[8] = 0;
                };
                test_reg reg0 @ 0x0;
            };
        """
        )
        with caplog.at_level(logging.WARNING):
            bsv = _compile_and_export(rdl, tmpdir_str)
        assert any(
            "incrvalue" in rec.message for rec in caplog.records
        ), "a dynamic incrvalue reference must warn that it isn't supported"
        # Falls back to a plain count-argument incr(), not a bogus pulse.
        assert _has(bsv["signal"], r"method Action incr\(Bit#\(8\) count\)")

    @staticmethod
    def _r_write_rule(sig):
        m = re.search(r"rule r_write;.*?endrule", sig, re.S)
        assert m, "r_write rule must be present"
        return m.group(0)


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
        # woset applies a per-bit write-1-to-set function (not the whole-field
        # pw_set pulse, which is reserved for the singlepulse `rset` property)
        # so it works correctly on fields wider than 1 bit.
        assert _has(
            bsv["signal"], r"rr\s*=\s*rr\s*\|\s*wdata"
        ), "onwrite=woset must OR the write-enabled bits into the field"


# ===========================================================================
# 9b. PRECEDENCE PROPERTY
# ===========================================================================


class TestPrecedence:
    """Tests for the hw-vs-sw simultaneous-write precedence property."""

    def _rdl(self, precedence=None):
        prec_line = f"precedence = {precedence};" if precedence else ""
        return textwrap.dedent(
            f"""\
            addrmap test {{
                reg test_reg {{
                    field {{ sw = rw; hw = rw; {prec_line} }} field0[8] = 0;
                }};
                test_reg reg0 @ 0x0;
            }};
        """
        )

    def _r_write_rule(self, sig):
        m = re.search(r"rule r_write;.*?endrule", sig, re.S)
        assert m, "r_write rule must be present"
        return m.group(0)

    def test_default_precedence_is_sw_first(self, tmpdir_str):
        # SystemRDL default precedence (unassigned) is sw.
        bsv = _compile_and_export(self._rdl(), tmpdir_str)
        rule = self._r_write_rule(bsv["signal"])
        sw_pos = rule.index("sw_wdata.wget")
        hw_pos = rule.index("hw_wdata.wget")
        assert sw_pos < hw_pos, "default precedence must check sw_wdata before hw_wdata"

    def test_explicit_sw_precedence_checks_sw_first(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("sw"), tmpdir_str)
        rule = self._r_write_rule(bsv["signal"])
        sw_pos = rule.index("sw_wdata.wget")
        hw_pos = rule.index("hw_wdata.wget")
        assert sw_pos < hw_pos, "precedence=sw must check sw_wdata before hw_wdata"

    def test_explicit_hw_precedence_checks_hw_first(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("hw"), tmpdir_str)
        rule = self._r_write_rule(bsv["signal"])
        sw_pos = rule.index("sw_wdata.wget")
        hw_pos = rule.index("hw_wdata.wget")
        assert hw_pos < sw_pos, "precedence=hw must check hw_wdata before sw_wdata"

    def test_precedence_no_longer_warns(self, tmpdir_str, caplog):
        with caplog.at_level(logging.WARNING):
            _compile_and_export(self._rdl("hw"), tmpdir_str)
        assert not any(
            "precedence" in rec.message for rec in caplog.records
        ), "precedence is now implemented and must not be flagged as unsupported"

    def test_sw_branch_guarded_against_zero_strobe(self, tmpdir_str):
        # The register-level write() method calls bus.write() on every
        # field whenever the parent register is written, even for fields
        # whose bytes weren't targeted (wstrb=0 for that field's slice).
        # Without a nonzero-wstrb guard, that spurious sw_wdata validity
        # would win the mutually-exclusive else-if chain and starve a
        # genuine same-cycle hw write, regardless of precedence=.
        bsv = _compile_and_export(self._rdl(), tmpdir_str)
        rule = self._r_write_rule(bsv["signal"])
        assert _has(
            rule,
            r"sw_wdata\.wget\(\s*\)\s*matches\s*tagged\s*Valid\s*\.v\s*&&&\s*\(tpl_2\(v\)\s*!=\s*0\)",
        ), "sw_wdata branch must be guarded on a nonzero wstrb"


# ===========================================================================
#  9b. EXTERNAL SIGNAL GATING  (we/wel)
# ===========================================================================


class TestExternalSignalGating:
    """Tests for we/wel (hw write-enable) and swwe/swwel (sw write-enable)
    gated by an external `signal`.

    Only a `signal` reference is modeled (a Field/PropertyReference value
    is valid per the SystemRDL spec but doesn't resolve through this
    compiler's namespace lookup for simple instance-name references, the
    same limitation `next` hit), and the plain bool form needs no special
    handling since it matches the always-writable default.
    """

    def _rdl(self, prop, reg_name="r1", extra_field=""):
        return textwrap.dedent(
            f"""\
            addrmap topmap {{
                signal {{}} gate_sig;
                reg {reg_name} {{
                    field {{ sw = rw; hw = rw; {prop} = gate_sig; }} f0[8] = 0;
                    {extra_field}
                }};
                {reg_name} reg1 @ 0x0;
            }};
        """
        )

    def test_we_generates_top_level_port_and_gates_hw_write(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("we"), tmpdir_str)
        sig = _r_write_rule(bsv["signal"])
        assert _has(
            sig,
            r"hw_wdata\.wget\(\s*\)\s*matches\s*tagged\s*Valid\s*\.v\s*&&&\s*\(w_ext_\S+==1\)",
        ), "we must gate the hw write branch on the external signal == 1"
        assert _has(
            bsv["csr"], r"method Action set_ext_\S+\(Bit#\(1\) v\)"
        ), "we must expose a top-level ConfigCSR input for the signal"

    def test_wel_gates_hw_write_active_low(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("wel"), tmpdir_str)
        sig = _r_write_rule(bsv["signal"])
        assert _has(
            sig,
            r"hw_wdata\.wget\(\s*\)\s*matches\s*tagged\s*Valid\s*\.v\s*&&&\s*\(w_ext_\S+==0\)",
        ), "wel must gate the hw write branch on the external signal == 0"

    def test_we_true_bool_has_no_port_or_gating(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap topmap {
                reg r1 {
                    field { sw = rw; hw = rw; we = true; } f0[8] = 0;
                };
                r1 reg1 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        assert _not_has(
            bsv["signal"], r"set_ext_"
        ), "we=true must not generate an external signal port"

    def test_shared_signal_deduped_at_csr_level(self, tmpdir_str):
        # Two fields (in the same register here) referencing the same
        # signal must produce exactly one top-level port, not two.
        bsv = _compile_and_export(
            self._rdl(
                "we",
                extra_field="field { sw = rw; hw = rw; we = gate_sig; } f1[8] = 0;",
            ),
            tmpdir_str,
        )
        # One port appears twice in the generated text (interface
        # declaration + module implementation) -- what must be deduped
        # is the number of *distinct* port names, not raw occurrences.
        ports = set(re.findall(r"method Action (set_ext_\S+)\(", bsv["csr"]))
        assert len(ports) == 1, (
            "a signal referenced by multiple fields must be exposed as "
            f"exactly one distinct ConfigCSR input, got {ports}"
        )

    def test_reg_module_relays_signal_to_field(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("we"), tmpdir_str)
        reg = bsv["reg"]
        assert _has(
            reg, r"method Action set_ext_\S+\(Bit#\(1\) v\)"
        ), "ConfigReg must expose a relay input for the signal"
        assert _has(
            reg, r"rule rl_relay_ext_\S+;\s*sig_f0\.set_ext_\S+\(w_ext_\S+\);\s*endrule"
        ), "ConfigReg must relay the signal down to the consuming field"

    def test_swwe_gates_sw_write(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("swwe"), tmpdir_str)
        sig = _r_write_rule(bsv["signal"])
        assert _has(
            sig,
            r"sw_wdata\.wget\(\s*\)\s*matches\s*tagged\s*Valid\s*\.v\s*&&&\s*\(tpl_2\(v\)\s*!=\s*0\)\s*&&&\s*\(w_ext_\S+==1\)",
        ), "swwe must gate the sw write branch on the external signal == 1"

    def test_swwel_gates_sw_write_active_low(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("swwel"), tmpdir_str)
        sig = _r_write_rule(bsv["signal"])
        assert _has(
            sig,
            r"sw_wdata\.wget\(\s*\)\s*matches\s*tagged\s*Valid\s*\.v\s*&&&\s*\(tpl_2\(v\)\s*!=\s*0\)\s*&&&\s*\(w_ext_\S+==0\)",
        ), "swwel must gate the sw write branch on the external signal == 0"

    def test_swwe_true_bool_has_no_port_or_gating(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap topmap {
                reg r1 {
                    field { sw = rw; hw = rw; swwe = true; } f0[8] = 0;
                };
                r1 reg1 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        assert _not_has(
            bsv["signal"], r"set_ext_"
        ), "swwe=true must not generate an external signal port"


# ===========================================================================
#  9c. HWENABLE/HWMASK/NEXT  (full-width external signals)
# ===========================================================================


class TestHwEnableMaskNext:
    """Tests for hwenable/hwmask (per-bit hw update masking) and next (the
    field's flip-flop D-input), all modeled as a full-width `signal`
    reference -- the same signal-only limitation as we/wel/swwe/swwel."""

    def _rdl(self, prop, hw="rw"):
        return textwrap.dedent(
            f"""\
            addrmap topmap {{
                signal {{}} gate_sig[8];
                reg r1 {{
                    field {{ sw = rw; hw = {hw}; {prop} = gate_sig; }} f0[8] = 0;
                }};
                r1 reg1 @ 0x0;
            }};
        """
        )

    def test_hwenable_merges_enabled_bits(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("hwenable"), tmpdir_str)
        rule = _r_write_rule(bsv["signal"])
        assert _has(
            rule,
            r"rr\s*=\s*\(v\s*&\s*w_ext_\S+\)\s*\|\s*\(r\s*&\s*~w_ext_\S+\)",
        ), "hwenable must merge enabled bits of v with the unenabled bits of r"

    def test_hwmask_merges_unmasked_bits(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("hwmask"), tmpdir_str)
        rule = _r_write_rule(bsv["signal"])
        assert _has(
            rule,
            r"rr\s*=\s*\(v\s*&\s*~w_ext_\S+\)\s*\|\s*\(r\s*&\s*w_ext_\S+\)",
        ), "hwmask must merge unmasked bits of v with the masked bits of r"

    def test_next_overrides_everything_unconditionally(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("next", hw="rw"), tmpdir_str)
        rule = _r_write_rule(bsv["signal"])
        assert _has(
            rule, r"rr\s*=\s*w_ext_\S+;"
        ), "next must unconditionally set rr from the external signal"
        assert _not_has(
            rule, r"pw_clear"
        ), "next must skip the clear/set/sw/hw/counter chain entirely"

    def test_next_requires_hw_writable(self, tmpdir_str):
        # SystemRDL requires next's field to be hw-writable; hw=r should
        # be rejected by the compiler itself before generation even runs.
        from systemrdl.messages import RDLCompileError

        rdl = self._rdl("next", hw="r")
        with pytest.raises(RDLCompileError):
            _compile_and_export(rdl, tmpdir_str)


# ===========================================================================
#  9d. RESETSIGNAL  (true async reset domain)
# ===========================================================================


class TestResetSignal:
    """Tests for resetsignal: a genuine independent async Reset domain
    (mkReset/assertReset), built from a module *constructor argument*
    rather than the Action-method ext_signals mechanism (see
    common.reset_signal_port_name)."""

    def _rdl(self, polarity="activehigh"):
        return textwrap.dedent(
            f"""\
            addrmap topmap {{
                signal {{ {polarity}; }} rst_sig;
                reg r1 {{
                    field {{ sw = rw; hw = r; resetsignal = rst_sig; }} f0[8] = 0;
                }};
                r1 reg1 @ 0x0;
            }};
        """
        )

    def test_active_high_asserts_on_signal_high(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("activehigh"), tmpdir_str)
        sig = bsv["signal"]
        assert _has(
            sig, r"MakeResetIfc mr_rstsig <- mkReset\(1, False, clk_rstsig\)"
        ), "resetsignal must build an independent async Reset domain"
        assert _has(
            sig, r"rule rl_assert_resetsignal \(rst_rstsig_\S+\)"
        ), "active-high resetsignal must assert when the signal is 1"
        assert _has(
            sig, r"reset_by mr_rstsig\.new_rst"
        ), "the field's Reg must use the resetsignal-derived Reset"

    def test_active_low_inverts_assert_condition(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("activelow"), tmpdir_str)
        sig = bsv["signal"]
        assert _has(
            sig, r"rule rl_assert_resetsignal \(!rst_rstsig_\S+\)"
        ), "active-low resetsignal must assert when the signal is 0"

    def test_module_signature_takes_bool_ctor_arg(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl(), tmpdir_str)
        assert _has(
            bsv["signal"],
            r"module mkCSRSignal_\S+#\(Integer resetValue, Bool rst_rstsig_\S+\)",
        ), "resetsignal must be a Bool constructor argument, not an Action method"

    def test_reg_module_takes_and_forwards_bool_arg(self, tmpdir_str):
        # Modules are named after the register INSTANCE (reg1), not its
        # type (r1) -- see TestRegisterStructure et al.
        bsv = _compile_and_export(self._rdl(), tmpdir_str)
        reg = bsv["reg"]
        assert _has(
            reg, r"module mkConfigReg_reg1#\(Bool rst_rstsig_\S+\)\(ConfigReg_reg1\)"
        ), "ConfigReg must take the resetsignal as its own Bool ctor arg"
        assert _has(
            reg, r"mkCSRSignal_reg1_f0\(0, rst_rstsig_\S+\)"
        ), "ConfigReg must forward the Bool arg straight to the field"

    def test_csr_exposes_top_level_set_method(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl(), tmpdir_str)
        csr = bsv["csr"]
        assert _has(
            csr, r"method Action set_rst_rstsig_\S+\(Bool v\)"
        ), "ConfigCSR must expose a top-level Action method for the reset signal"
        assert _has(
            csr, r"mkConfigReg_reg1\(w_rst_rstsig_\S+\)"
        ), "ConfigCSR must pass its own Wire straight through to ConfigReg"


# ===========================================================================
#  9e. STICKY / STICKYBIT
# ===========================================================================


class TestStickyStickybit:
    """Tests for sticky (whole-field freeze) and stickybit (per-bit
    write-1-to-set-only) hw write behavior."""

    def _rdl(self, prop):
        return textwrap.dedent(
            f"""\
            addrmap test {{
                reg r1 {{
                    field {{ sw = rw; hw = rw; onwrite=woclr; {prop}; }} f0[8] = 0;
                }};
                r1 reg1 @ 0x0;
            }};
        """
        )

    def test_stickybit_ors_hw_write_into_current_value(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("stickybit"), tmpdir_str)
        rule = _r_write_rule(bsv["signal"])
        assert _has(
            rule, r"rr\s*=\s*r\s*\|\s*\(v\)"
        ), "stickybit must OR the hw write into the current value, not overwrite it"

    def test_sticky_freezes_whole_field_once_nonzero(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl("sticky"), tmpdir_str)
        rule = _r_write_rule(bsv["signal"])
        assert _has(
            rule, r"rr\s*=\s*\(r\s*!=\s*0\)\s*\?\s*r\s*:\s*\(v\)"
        ), "sticky must freeze the field at its current value once nonzero"

    def test_woclr_can_still_clear_a_sticky_field(self, tmpdir_str):
        # sticky/stickybit only gate the *hw* write path; sw-side onwrite
        # side effects (woclr here) are unaffected and still generated.
        bsv = _compile_and_export(self._rdl("stickybit"), tmpdir_str)
        rule = _r_write_rule(bsv["signal"])
        assert _has(
            rule, r"rr\s*=\s*rr\s*&\s*~wdata"
        ), "woclr must still be able to clear a stickybit field via software"


# ===========================================================================
#  9f. INTERRUPT/HALT AGGREGATION  (intr, enable/mask, haltenable/haltmask)
# ===========================================================================


class TestInterruptAggregation:
    """Tests for the register-level interrupt/halt aggregate ConfigReg
    builds by OR-reducing every intr field's (qualified) current value.

    enable/mask/haltenable/haltmask are only modeled as a `signal`
    reference, same limitation as we/wel/etc (a Field/PropertyReference
    value doesn't resolve through this compiler's namespace lookup).
    """

    def test_bare_intr_generates_interrupt_method(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg r1 {
                    field { sw = rw; hw = w; woclr; intr; } f0[8] = 0;
                };
                r1 reg1 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        reg = bsv["reg"]
        assert _has(
            reg, r"method Bool interrupt\(\)"
        ), "an intr field must generate a register-level interrupt() method"
        assert _has(
            reg, r"\|\(sig_f0\.currentValue\(\)\)\s*==\s*1'b1"
        ), "interrupt() must OR-reduce the field's current value"

    def test_no_intr_fields_omits_interrupt_method(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg r1 {
                    field { sw = rw; hw = r; } f0[8] = 0;
                };
                r1 reg1 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        assert _not_has(
            bsv["reg"], r"method Bool interrupt"
        ), "a register with no intr fields must not generate interrupt()"

    def test_multiple_intr_fields_or_together(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                reg r1 {
                    field { sw = rw; hw = w; woclr; intr; } f0[8] = 0;
                    field { sw = rw; hw = w; woclr; intr; } f1[8] = 0;
                };
                r1 reg1 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        reg = bsv["reg"]
        assert _has(reg, r"sig_f0\.currentValue\(\)")
        assert _has(reg, r"sig_f1\.currentValue\(\)")
        assert _has(
            reg, r"return .*\|\|.*;"
        ), "multiple intr fields must be OR'd together into one interrupt()"

    def test_enable_qualifies_which_bits_count(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                signal {} en_sig[8];
                reg r1 {
                    field { sw = rw; hw = w; woclr; intr; enable = en_sig; } f0[8] = 0;
                };
                r1 reg1 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        assert _has(
            bsv["reg"], r"sig_f0\.currentValue\(\)\s*&\s*w_ext_\S+"
        ), "enable must AND-mask the field's contribution to the aggregate"
        assert _has(
            bsv["csr"], r"method Action set_ext_\S+\(Bit#\(8\) v\)"
        ), "enable's signal must be relayed all the way to a top-level CSR port"

    def test_mask_inverts_the_qualification(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                signal {} mask_sig[8];
                reg r1 {
                    field { sw = rw; hw = w; woclr; intr; mask = mask_sig; } f0[8] = 0;
                };
                r1 reg1 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        assert _has(
            bsv["reg"], r"sig_f0\.currentValue\(\)\s*&\s*~w_ext_\S+"
        ), "mask must AND the field's contribution with the *complement* of the signal"

    def test_haltenable_generates_separate_halt_method(self, tmpdir_str):
        rdl = textwrap.dedent(
            """\
            addrmap test {
                signal {} halt_sig[8];
                reg r1 {
                    field { sw = rw; hw = w; woclr; intr; haltenable = halt_sig; } f0[8] = 0;
                };
                r1 reg1 @ 0x0;
            };
        """
        )
        bsv = _compile_and_export(rdl, tmpdir_str)
        reg = bsv["reg"]
        assert _has(
            reg, r"method Bool halt\(\)"
        ), "haltenable must generate a separate halt() method"
        assert _has(
            reg, r"method Bool interrupt\(\)"
        ), "the field must still contribute to interrupt() unconditionally"


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
        # Named after the register INSTANCE (reg0), not its type (ctrl_reg),
        # so multiple instances of the same reg type don't collide.
        assert _has(
            bsv["reg"], r"interface ConfigReg_reg0"
        ), "Reg file must define ConfigReg_reg0 interface"

    def test_reg_module_declared(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_multi_field(), tmpdir_str)
        assert _has(
            bsv["reg"], r"module mkConfigReg_reg0"
        ), "Reg file must define mkConfigReg_reg0 module"

    def test_reg_all_fields_instantiated(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_multi_field(), tmpdir_str)
        reg = bsv["reg"]
        assert _has(
            reg, r"mkCSRSignal_reg0_enable"
        ), "enable signal must be instantiated"
        assert _has(reg, r"mkCSRSignal_reg0_mode"), "mode signal must be instantiated"
        assert _has(
            reg, r"mkCSRSignal_reg0_status"
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

    def test_hw_writeonly_field_reflects_stored_value(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_multi_field(), tmpdir_str)
        reg = bsv["reg"]
        # status is hw=w (no hw _read method) but Ifc_CSRSignal_* always
        # exposes currentValue() regardless of hw/sw access mode, so
        # value() reflects what hw last wrote instead of a hardcoded 0
        # (software otherwise could never read back a hw=w field).
        assert _has(
            reg, r"sig_status\.currentValue\(\)"
        ), "hw-write-only status field must contribute its real value via currentValue()"

    def test_reg_bus_interface_declared(self, tmpdir_str):
        bsv = _compile_and_export(self._rdl_multi_field(), tmpdir_str)
        reg = bsv["reg"]
        assert _has(
            reg, r"interface ConfigReg_Bus_reg0"
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

        # Reg file checks — modules are named after the register INSTANCE
        # (ctrl/stat/ic/is), not the reg type (control/status/irq_ctrl/
        # irq_status), so multiple instances of the same type don't collide.
        reg = bsv["reg"]
        assert _has(reg, r"mkConfigReg_ctrl"), f"ctrl module missing {reg=}"
        assert _has(reg, r"mkConfigReg_stat"), "stat module missing"
        assert _has(reg, r"mkConfigReg_ic"), "ic module missing"
        assert _has(reg, r"mkConfigReg_is"), "is module missing"

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
                    field { sw = r; hw = r; counter; incrwidth=16; decrwidth=16; } hits[16] = 0;
                    field { sw = r; hw = r; counter; incrwidth=16; decrwidth=16; } misses[16] = 0;
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
        # Wrapper is named after the register INSTANCE (reg0), not its
        # type (test_reg), matching every other generated module name.
        assert _has(
            sig, r"testcsrreg_reg0_field0"
        ), "With gentest=True, a testcsrreg_ synthesize wrapper must be generated"
        assert _has(
            sig, r"\(\*synthesize\*\)"
        ), "Test wrapper must carry (*synthesize*) attribute"

    def test_gentest_false_omits_wrapper(self, tmpdir_str):
        bsv = _compile_and_export(self._simple_rdl(), tmpdir_str, test=False)
        sig = bsv["signal"]
        assert _not_has(
            sig, r"testcsrreg_reg0_field0"
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
        # Outer module exposes both hw and bus sub-interfaces, named after
        # the register INSTANCE (reg0), not its type (test_reg).
        assert _has(
            sig, r"interface HW_reg0_field0 hw"
        ), "Signal module must expose 'hw' sub-interface"
        assert _has(
            sig, r"interface SW_reg0_field0 bus"
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
        # Named after the register INSTANCE (rx/ry), not its type (reg_x/reg_y).
        assert _has(csr, r"mkConfigReg_rx"), "rx must appear in CSR"
        assert _has(csr, r"mkConfigReg_ry"), "ry must appear in CSR"


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
        # Should complete without raising an exception. Named after the
        # register INSTANCE (c), not its type (ctrl).
        bsv = _compile_and_export(rdl, tmpdir_str)
        assert _has(
            bsv["signal"], r"mkCSRSignal_c_enable"
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
