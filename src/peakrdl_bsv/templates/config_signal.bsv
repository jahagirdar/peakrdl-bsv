// {{attr}}
// {{node.get_property('hw')}}
// {{node.get_property('sw')}}
//{{node.is_sw_writable}}
//{{node.is_hw_writable}}
//{{node.is_hw_readable}}
//{{node.is_sw_readable}}
//{{node.width}}
interface SW_{{attr['reg_name']}}_{{attr['signal_name']}};
{%if attr['sw_writable']%}
method Action write(Bit#({{node.width}}) data,Bit#({{node.width}}) wstrb);
{%endif%}
{%if attr['sw_readable']%}
method ActionValue#(Bit#({{node.width}})) read ();
{%endif%}
endinterface

interface HW_{{attr['reg_name']}}_{{attr['signal_name']}};
	{%if attr['singlepulse']%} method Bool pulse(); {%endif%}
	{%if attr['swacc']%} method Bool swacc();{%endif%}
	{%if attr['swmod']%} method Bool swmod();{%endif%}
	{%if attr['anded']%} method Bool anded();{%endif%}
	{%if attr['ored']%} method Bool ored();{%endif%}
	{%if attr['xored']%} method Bool xored();{%endif%}
	{%if attr['hwset']%} method Action hwset();{%endif%}
	{%if attr['hwclr']%} method Action hwclr();{%endif%}
{%if attr['hw_writable']%} method Action _write(Bit#({{node.width}}) data); {%endif%}
{%if attr['hw_readable']%} method Bit#({{node.width}}) _read; {%endif%}
{%if attr['counter_up']%}
{%if attr['incr_is_pulse']%}method Action incr();{%else%}method Action incr(Bit#({{attr['incr_width']}}) count);{%endif%}
{%if attr['has_overflow']%} method Bool overflow();{%endif%}
{%if attr['incr_threshold'] is not none%} method Bool incrthreshold();{%endif%}
{%endif%}
{%if attr['counter_down']%}
{%if attr['decr_is_pulse']%}method Action decr();{%else%}method Action decr(Bit#({{attr['decr_width']}}) count);{%endif%}
{%if attr['has_underflow']%} method Bool underflow();{%endif%}
{%endif%}
	method Action clear();
endinterface

interface Ifc_CSRSignal_{{attr['reg_name']}}_{{attr['signal_name']}};
interface HW_{{attr['reg_name']}}_{{attr['signal_name']}} hw;
interface SW_{{attr['reg_name']}}_{{attr['signal_name']}} bus;
// method Action bus_write(Bit#(width) data);
// method  ActionValue#(Bit#(width)) bus_read;
// Always present regardless of hw/sw access mode: the register-level
// value() aggregation (see print_bsv_reg.py) reads every field's current
// stored value through this, rather than special-casing hw=r vs hw=w.
method Bit#({{node.width}}) currentValue();
endinterface




module mkCSRSignal_{{attr['reg_name']}}_{{attr['signal_name']}}#(Integer resetValue)(Ifc_CSRSignal_{{attr['reg_name']}}_{{attr['signal_name']}});

	Reg#(Bit#({{node.width}})) r<-mkRegA(fromInteger(resetValue));
PulseWire pw_set <-mkPulseWire();
PulseWire pw_clear <-mkPulseWire();
PulseWire pw_swacc <-mkPulseWire();
PulseWire pw_swmod <-mkPulseWire();
RWire#(Tuple2#(Bit#({{node.width}}),Bit#({{node.width}})))sw_wdata <-mkRWire();
RWire#(Bit#({{node.width}}))hw_wdata <-mkRWire();
{%if attr['counter_up']%}
{%if attr['incr_is_pulse']%}
PulseWire pw_incr <-mkPulseWire();
{%else%}
RWire#(Bit#({{attr['incr_width']}}))r_incr <-mkRWire();
{%endif%}
{%if attr['has_overflow']%}
PulseWire pw_overflow <-mkPulseWire();
{%endif%}
{%endif%}
{%if attr['counter_down']%}
{%if attr['decr_is_pulse']%}
PulseWire pw_decr <-mkPulseWire();
{%else%}
RWire#(Bit#({{attr['decr_width']}}))r_decr <-mkRWire();
{%endif%}
{%if attr['has_underflow']%}
PulseWire pw_underflow <-mkPulseWire();
{%endif%}
{%endif%}

rule r_write;
	let rr = r;
	{%if attr['singlepulse']%} rr = 0;{%endif%}
	if(pw_clear) rr =0;
	else if(pw_set) rr = ~0;
	{%- set sw_write_block %}
	{#- The register-level write() method calls every field's bus.write()
	    on any write to the parent register, even for fields whose bytes
	    weren't targeted (wstrb=0 for this field's slice). Guard on a
	    nonzero wstrb so a zero-strobe write to a sibling field can't
	    spuriously win this branch and starve a genuine same-cycle hw
	    write. -#}
	else if(sw_wdata.wget( ) matches tagged Valid .v &&& (tpl_2(v) != 0)) begin
		let wdata = tpl_1(v) & tpl_2(v);
		{#- Software write effect per the SystemRDL onwrite property. -#}
		{%if attr['woclr']%}
		rr = rr & ~wdata;
		{%elif attr['woset']%}
		rr = rr | wdata;
		{%elif attr['wot']%}
		rr = rr ^ wdata;
		{%elif attr['wzc']%}
		rr = rr & (tpl_1(v) | ~tpl_2(v));
		{%elif attr['wzs']%}
		rr = rr | (~tpl_1(v) & tpl_2(v));
		{%elif attr['wclr']%}
		rr = 0;
		{%elif attr['wset']%}
		rr = ~0;
		{%else%}
		rr = (wdata | (~tpl_2(v) & rr));
		{%endif%}
	end
	{%- endset %}
	{%- set hw_write_block %}
	else if(hw_wdata.wget( ) matches tagged Valid .v) rr = v;
	{%- endset %}
	{#- SystemRDL precedence property (default sw): decides which of a
	    simultaneous hw write and sw write wins by checking that side's
	    branch first in this if/elif chain. -#}
	{%if attr['precedence'] == 'PrecedenceType.hw'%}
	{{ hw_write_block }}
	{{ sw_write_block }}
	{%else%}
	{{ sw_write_block }}
	{{ hw_write_block }}
	{%endif%}
	{%if attr['counter_up']%}
	else if({%if attr['incr_is_pulse']%}pw_incr{%else%}r_incr.wget( ) matches tagged Valid .v{%endif%}) begin
		{%if attr['incr_is_pulse']%}
		let amt = {{node.width}}'d{{attr['incr_const']}};
		{%else%}
		let amt = zeroExtend(v);
		{%endif%}
		{%if attr['incr_needs_wide']%}
		Bit#(TAdd#({{node.width}},1)) wideSum = zeroExtend(r) + zeroExtend(amt);
		rr = (wideSum > zeroExtend({{node.width}}'d{{attr['incr_sat_max']}})) ? {{node.width}}'d{{attr['incr_sat_max']}} : truncate(wideSum);
		{%else%}
		{%if attr['has_overflow']%}
		if (amt > ~r) pw_overflow.send();
		{%endif%}
		rr = r + amt;
		{%endif%}
	end
	{%endif%}
	{%if attr['counter_down']%}
	else if({%if attr['decr_is_pulse']%}pw_decr{%else%}r_decr.wget( ) matches tagged Valid .v{%endif%}) begin
		{%if attr['decr_is_pulse']%}
		let amt = {{node.width}}'d{{attr['decr_const']}};
		{%else%}
		let amt = zeroExtend(v);
		{%endif%}
		{%if attr['decr_needs_wide']%}
		Bit#(TAdd#({{node.width}},1)) floorPlusAmt = zeroExtend(amt) + zeroExtend({{node.width}}'d{{attr['decr_sat_min']}});
		rr = (floorPlusAmt > zeroExtend(r)) ? {{node.width}}'d{{attr['decr_sat_min']}} : (r - amt);
		{%else%}
		{%if attr['has_underflow']%}
		if (amt > r) pw_underflow.send();
		{%endif%}
		rr = r - amt;
		{%endif%}
	end
	{%endif%}
	r<=rr;
endrule
interface HW_{{attr['reg_name']}}_{{attr['signal_name']}} hw;
{%if attr['singlepulse']%}
method Bool pulse();
	return r==1;
endmethod
{%endif%}
{%if attr['swacc']%}
method Bool swacc();
	return pw_swacc;
endmethod
{%endif%}
{%if attr['swmod']%}
method Bool swmod();
	return pw_swmod;
endmethod
{%endif%}
{%if attr['anded']%}
method Bool anded();
	return &r==1;
endmethod
{%endif%}
{%if attr['ored']%}
method Bool ored();
	return |r==1;
endmethod
{%endif%}
{%if attr['xored']%}
method Bool xored();
	return ^r==1;
endmethod
{%endif%}
{%if attr['hwset']%}
method Action hwset();
	pw_set.send();
endmethod
{%endif%}
{%if attr['hwclr']%}
method Action hwclr();
	pw_clear.send();
endmethod
{%endif%}
method Action clear();
	pw_clear.send();
endmethod
{%if attr['hw_writable']%}
method Action _write(Bit#({{node.width}}) data);
	hw_wdata.wset(data);
endmethod
{%endif%}
{%if attr['hw_readable']%}
method Bit#({{node.width}}) _read;
	return r;
endmethod
{%endif%}
{%if attr['counter_up']%}
{%if attr['incr_is_pulse']%}
method Action incr();
		pw_incr.send();
endmethod
{%else%}
method Action incr(Bit#({{attr['incr_width']}}) count);
		r_incr.wset(count);
endmethod
{%endif%}
{%if attr['has_overflow']%}
method Bool overflow();
	return pw_overflow;
endmethod
{%endif%}
{%if attr['incr_threshold'] is not none%}
method Bool incrthreshold();
	return r >= {{node.width}}'d{{attr['incr_threshold']}};
endmethod
{%endif%}
{%endif%}
{%if attr['counter_down']%}
{%if attr['decr_is_pulse']%}
method Action decr();
		pw_decr.send();
endmethod
{%else%}
method Action decr(Bit#({{attr['decr_width']}}) count);
		r_decr.wset(count);
endmethod
{%endif%}
{%if attr['has_underflow']%}
method Bool underflow();
	return pw_underflow;
endmethod
{%endif%}
{%endif%}
endinterface
interface SW_{{attr['reg_name']}}_{{attr['signal_name']}} bus;
{%if attr['sw_writable']%}
method Action write(Bit#({{node.width}}) data, Bit#({{node.width}}) wstrb);
	let mod=False;
	sw_wdata.wset(tuple2(data,wstrb));
    if (wstrb !=0)begin
	    {%if attr['swacc']%} pw_swacc.send();{%endif%}
	    {%if attr['swmod'] and attr['woclr']%} mod=((r & data & wstrb)!=0);
	    {%elif attr['swmod'] and attr['woset']%} mod=((~r & data & wstrb)!=0);
	    {%elif attr['swmod']%} mod=((data & wstrb)!=(r & wstrb));
	    {%endif%}
	    if(mod)
		    pw_swmod.send();
    end
endmethod
{%endif%}
{%if attr['sw_readable']%}
method ActionValue#(Bit#({{node.width}})) read;
	let rv=0;
	let mod=False;
	{%if attr['swacc']%} pw_swacc.send(); {%endif%}
        {%if attr['rclr']%} pw_clear.send();{%endif%}
        {%if attr['swmod'] and attr['rclr']%} mod=(r!=0); {%endif%}
        {%if attr['swmod'] and attr['rset']%} mod=(r!= ~0); {%endif%}
{%if attr['rset']%} pw_set.send(); {%endif%}
	if(mod)
		pw_swmod.send();
		rv=r;
	return rv;
endmethod
{%endif%}
endinterface
method Bit#({{node.width}}) currentValue();
	return r;
endmethod
endmodule
{%if gentest%}
(*synthesize*)
module testcsrreg_{{attr['reg_name']}}_{{attr['signal_name']}}(Ifc_CSRSignal_{{attr['reg_name']}}_{{attr['signal_name']}});
Ifc_CSRSignal_{{attr['reg_name']}}_{{attr['signal_name']}} ipaddress_r<-mkCSRSignal_{{attr['reg_name']}}_{{attr['signal_name']}}('h0);
return ipaddress_r;
endmodule
{%endif%}
// End getting CSR Code
