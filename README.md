# peakrdl-bsv
Peakrdl plugin for using generated rtl with bluespec.

Peakrdl regblock generated a systemverilog implementation of the register space. This implementation has two ports `hwif_in` and `hwif_out` which contains a hierarchical data structure encapsulating the registers and individial fields in the design.

This plugin writes the same data structure in BSV format. To use the generated BSV file in your design you can do the following

```
mkdir out
peakrdl bsv example/accelera_simplified_example.rdl -o out
```
This will generate a bsv file `out/some_register_map.bsv`

You can now write the following code in your module

```
import some_register_map::*;
interface Yourmodule_ifc
(*always_enabled,always_ready*)
method Action cfg(some_register_map_Read x);
(*always_enabled,always_ready*)
method some_register_map_Write status();
endinterface
module mkModule(Yourmodule_ifc);
...
endmodule
```
