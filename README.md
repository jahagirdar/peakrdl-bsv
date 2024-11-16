# peakrdl-bsv Generating BSV Configuration registers from SystemRDL code.

Peakrdl plugin for generated bluespec rtl from system RDL file.

This plugin takes an input `file.rdl` and generates three bluespec files

1. `file_signal.bsv` This contains the module definition of each individual signal in the rdl file.
2. `file_reg.bsv` This groups the signals into their containing register module.
3. `file_csr.bsv` This creates a module with the registers, address decoding and S/W read write methods.

# Installation and usage

Installing the application

```
pip3 install peakrdl-bsv
```

Generating BSV files from test.rdl

```
	peakrdl bsv test.rdl -o .
```

This can then be used in your design as follows

```
import file_csr::*;
...
ConfigCSR_file csr <- mkConfigCSR_file;

rule xyz;
csr.reg.signal.write(...)
endrule
```

The hardware side methods defined on a signal module are

* `method Bool pulse()` returns true when a 1 is written to the signal. self clearing.
* `method Bool swacc()` returns true when a s/w read or write operation is performed.
* `method Bool swmod()` returns true when a write or a read with sideeffect operation is performed.
* `method Bool anded()` Returns an AND reduced value of the signal.
* `method Bool ored();` Returns an OR reduced value of the signal.
* `method Bool xored()` Returns an XOR reduced value of the signal.
* `method Action clear()` Set's the signal to 0.
* `method Action _write(Bit#(n) data)` writes `data` to the register.
* `method Bit#(n) _rea` Returns the value of the register.

# Example

To see an example

```
cd tests
make
```

This will generate the required files from the test.rdl file
