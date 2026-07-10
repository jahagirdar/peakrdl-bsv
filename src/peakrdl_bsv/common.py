"""Shared helpers for the BSV generator walkers."""
import re

_INDEX_RE = re.compile(r"\[(\d+)\]")


def sanitize(segment):
    """Make a path segment a legal BSV identifier part (Arr[2] -> Arr_2)."""
    return _INDEX_RE.sub(r"_\1", segment)


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
