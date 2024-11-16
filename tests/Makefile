run:
	peakrdl bsv test.rdl -o .
	bsc -bdir bo -elab Foo_signal.bsv
	bsc -bdir bo -elab Foo_reg.bsv
	bsc -bdir bo -elab Foo_csr.bsv
