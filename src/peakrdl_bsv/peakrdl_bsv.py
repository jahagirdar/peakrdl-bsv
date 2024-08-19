"""Main module."""
from typing import TYPE_CHECKING
from bsvExporter import BSVExporter

from peakrdl.plugins.exporter import ExporterSubcommandPlugin

if TYPE_CHECKING:
    import argparse
    from systemrdl.node import AddrmapNode


class Exporter(ExporterSubcommandPlugin):
    short_desc = "Bluespec system verilog wrapper over the verilog file generated by peakrdl rtl exporter"

    def add_exporter_arguments(self, arg_group: 'argparse.ArgumentParser') -> None:
        arg_group.add_argument(
            "--vendor", default="dyumnin.com",
            help="Vendor URL String")

    def do_export(self, top_node='AddrmapNode', options='argparse.ArgumentParser') -> None:
        x = BSVExporter(
            standard=Standard(options.standard),
            vendor=options.vendor,
            library=options.library,
            version=options.version,
        )
        x.export(

            top_node,
            options.output,
            component_name=options.name
            )

    def __init__(self, **kwargs: Any):
