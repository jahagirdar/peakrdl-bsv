"""PeakRDL Markdown plug-in."""

__authors__ = ["Vijayvithal Jahagirdar < jahagirdar.vs@gmail.com>"]

from typing import TYPE_CHECKING

from peakrdl.plugins.exporter import ExporterSubcommandPlugin  # type: ignore

from .exporter import BSVExporter

if TYPE_CHECKING:
    import argparse
    from typing import Union

    from systemrdl.node import AddrmapNode, RootNode  # type: ignore


class Exporter(ExporterSubcommandPlugin):  # pylint: disable=too-few-public-methods
    """PeakRDL BSV exporter plug-in."""

    short_desc = "Generate BSV Wrappers over code generated by regblock"
    long_desc = "Export the register model to BSV"

    def add_exporter_arguments(self, arg_group: "argparse._ActionsContainer"):  # type: ignore
        """Add PeakRDL exporter arguments."""
        arg_group.add_argument(
            "--depth",
            dest="depth",
            default=0,
            type=int,
            help="Depth of generation (0 means all)",
        )

    def do_export(
        self, top_node: "Union[AddrmapNode, RootNode]", options: "argparse.Namespace"
    ):
        """Perform the export of SystemRDL node to BSV.

        Arguments:
            top_node -- top node to export.
            options -- argparse options from the `peakrdl` tool.
        """
        BSVExporter().export(
            top_node,
            options.output,
            input_files=options.input_files,
            rename=options.inst_name,
            depth=options.depth,
        )
