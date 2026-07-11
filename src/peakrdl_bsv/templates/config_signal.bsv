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
{%for port, width in attr['ext_signals'].items()%}
// Driven every cycle by an always-firing relay rule in the enclosing
// ConfigReg/ConfigCSR modules (see print_bsv_reg.py/print_bsv_csr.py),
// which thread this external `signal`'s value down from the top-level
// module boundary.
method Action set_{{port}}(Bit#({{width}}) v);
{%endfor%}
endinterface




module mkCSRSignal_{{attr['reg_name']}}_{{attr['signal_name']}}#(Integer resetValue{%if attr['resetsignal_port']%}, Bool rst_{{attr['resetsignal_port']}}{%endif%})(Ifc_CSRSignal_{{attr['reg_name']}}_{{attr['signal_name']}});

	{%if attr['resetsignal_port']%}
	{#- resetsignal (SystemRDL 9.5): the field resets from this signal
	    instead of the module's ambient reset. mkReset/assertReset builds
	    a genuine independent async Reset domain, driven from a rule
	    guarded by the live constructor-argument value (a plain Bool,
	    not an Action-pushed Wire like we/wel/etc -- see
	    common.reset_signal_port_name for why). -#}
	Clock clk_rstsig <- exposeCurrentClock;
	MakeResetIfc mr_rstsig <- mkReset(1, False, clk_rstsig);
	rule rl_assert_resetsignal ({%if attr['resetsignal_active_low']%}!rst_{{attr['resetsignal_port']}}{%else%}rst_{{attr['resetsignal_port']}}{%endif%});
		mr_rstsig.assertReset;
	endrule
	Reg#(Bit#({{node.width}})) r<-mkRegA(fromInteger(resetValue), reset_by mr_rstsig.new_rst);
	{%else%}
	Reg#(Bit#({{node.width}})) r<-mkRegA(fromInteger(resetValue));
	{%endif%}
PulseWire pw_set <-mkPulseWire();
PulseWire pw_clear <-mkPulseWire();
PulseWire pw_swacc <-mkPulseWire();
PulseWire pw_swmod <-mkPulseWire();
RWire#(Tuple2#(Bit#({{node.width}}),Bit#({{node.width}})))sw_wdata <-mkRWire();
RWire#(Bit#({{node.width}}))hw_wdata <-mkRWire();
{%for port, width in attr['ext_signals'].items()%}
Wire#(Bit#({{width}})) w_{{port}} <-mkDWire(0);
{%endfor%}
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
	{#- next (SystemRDL 9.5) is the field's flip-flop D-input: when
	    modeled (a same-cycle-driven external signal, see
	    print_bsv_signal.py._resolve_masking_and_next), it unconditionally
	    supersedes every other update source below -- clear/set/sw/hw
	    writes don't actually reach the D-input once next= is wired in
	    real hardware. -#}
	{%if attr['next_port']%}
	rr = w_{{attr['next_port']}};
	{%else%}
	if(pw_clear) rr =0;
	else if(pw_set) rr = ~0;
	{%- set sw_write_block %}
	{#- The register-level write() method calls every field's bus.write()
	    on any write to the parent register, even for fields whose bytes
	    weren't targeted (wstrb=0 for this field's slice). Guard on a
	    nonzero wstrb so a zero-strobe write to a sibling field can't
	    spuriously win this branch and starve a genuine same-cycle hw
	    write. swwe/swwel additionally gate the whole branch on an
	    external signal. -#}
	else if(sw_wdata.wget( ) matches tagged Valid .v &&& (tpl_2(v) != 0){%if attr['swwe_port']%} &&& (w_{{attr['swwe_port']}}==1){%elif attr['swwel_port']%} &&& (w_{{attr['swwel_port']}}==0){%endif%}) begin
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
	{%- set hw_write_value %}{%if attr['hwenable_port']%}(v & w_{{attr['hwenable_port']}}) | (r & ~w_{{attr['hwenable_port']}}){%elif attr['hwmask_port']%}(v & ~w_{{attr['hwmask_port']}}) | (r & w_{{attr['hwmask_port']}}){%else%}v{%endif%}{%- endset %}
	{%- set hw_write_block %}
	{#- we/wel gate whether a genuine hw _write() call actually reaches
	    the storage this cycle; unset/bool true is today's unconditional
	    default. hwenable/hwmask (mutually exclusive per the compiler)
	    merge only the enabled/unmasked bits of the write with the
	    field's current value, instead of overwriting it whole. sticky/
	    stickybit (also mutually exclusive, both with each other and
	    with hwenable/hwmask) wrap that result again: stickybit means a
	    bit hw sets can never be hw-cleared (OR instead of replace);
	    sticky means the whole field freezes once nonzero, ignoring
	    further hw writes entirely until something else (sw/woclr/rclr/
	    hwclr/clear()) resets it. -#}
	else if(hw_wdata.wget( ) matches tagged Valid .v{%if attr['we_port']%} &&& (w_{{attr['we_port']}}==1){%elif attr['wel_port']%} &&& (w_{{attr['wel_port']}}==0){%endif%}) rr = {%if attr['sticky']%}(r != 0) ? r : ({{hw_write_value}}){%elif attr['stickybit']%}r | ({{hw_write_value}}){%else%}{{hw_write_value}}{%endif%};
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
{%for port, width in attr['ext_signals'].items()%}
method Action set_{{port}}(Bit#({{width}}) v);
	w_{{port}} <= v;
endmethod
{%endfor%}
endmodule
{%if gentest%}
(*synthesize*)
module testcsrreg_{{attr['reg_name']}}_{{attr['signal_name']}}{%if attr['resetsignal_port']%}#(Bool rst_{{attr['resetsignal_port']}}){%endif%}(Ifc_CSRSignal_{{attr['reg_name']}}_{{attr['signal_name']}});
Ifc_CSRSignal_{{attr['reg_name']}}_{{attr['signal_name']}} ipaddress_r<-mkCSRSignal_{{attr['reg_name']}}_{{attr['signal_name']}}('h0{%if attr['resetsignal_port']%}, rst_{{attr['resetsignal_port']}}{%endif%});
return ipaddress_r;
endmodule
{%endif%}
// End getting CSR Code
