"""Shared helpers for the BSV generator walkers."""
import re

from systemrdl.node import SignalNode

_INDEX_RE = re.compile(r"\[(\d+)\]")
_NON_IDENT_RE = re.compile(r"[^0-9a-zA-Z_]")


def sanitize(segment):
    """Make a path segment a legal BSV identifier part (Arr[2] -> Arr_2)."""
    return _INDEX_RE.sub(r"_\1", segment)


def resolve_signal_ref(node, prop_name):
    """Return the SignalNode a property references, or None when it's
    unset, a plain bool, or a Field/PropertyReference value.

    Field/PropertyReference values are a valid SystemRDL construct per the
    property's valid_types, but (like the `next` property) don't resolve
    through this compiler's namespace lookup for simple instance-name
    references -- only a `signal` component reference actually parses. So
    in practice a SignalNode is the only dynamic form reachable here.
    """
    value = node.get_property(prop_name)
    if isinstance(value, SignalNode):
        return value
    return None


def signal_port_name(signal_node):
    """Stable, BSV-legal method/port name for an external signal, derived
    from its full elaborated path so identically-named signals declared
    in different scopes don't collide. The same signal instance
    referenced from multiple fields/registers resolves to the same path
    and therefore the same port name, so callers can dedup by name."""
    return "ext_" + _NON_IDENT_RE.sub("_", signal_node.get_path())


class HierarchyMixin:
    """Track the addrmap/regfile hierarchy so registers in nested scopes get
    unique, identifier-safe names.

    Registers directly under the exported addrmap keep their plain instance
    name; registers in nested addrmaps/regfiles are prefixed with the scope
    path (e.g. ``s1_r1``).
    """

    hier: list

    def _enter_scope(self, node):
        self.hier.append(sanitize(node.get_path_segment()))

    def _exit_scope(self, node):
        self.hier.pop()

    def _reg_name(self, node):
        return "_".join([*self.hier[1:], sanitize(node.get_path_segment())])

    enter_Regfile = _enter_scope
    exit_Regfile = _exit_scope
