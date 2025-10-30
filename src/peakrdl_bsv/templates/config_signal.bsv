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
method Action write(Bit#({{node.width}}) data);
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
{%if attr['hw_writable']%} method Action _write(Bit#({{node.width}}) data); {%endif%}
{%if attr['hw_readable']%} method Bit#({{node.width}}) _read; {%endif%}
{%if attr['counter']%}method Action incr(Bit#({{node.width}}) count);{%endif%}
{%if attr['counter']%}method Action decr(Bit#({{node.width}}) count);{%endif%}
	method Action clear();
endinterface

interface Ifc_CSRSignal_{{attr['reg_name']}}_{{attr['signal_name']}};
interface HW_{{attr['reg_name']}}_{{attr['signal_name']}} hw;
interface SW_{{attr['reg_name']}}_{{attr['signal_name']}} bus;
// method Action bus_write(Bit#(width) data);
// method  ActionValue#(Bit#(width)) bus_read;
endinterface




module mkCSRSignal_{{attr['reg_name']}}_{{attr['signal_name']}}#(Integer resetValue)(Ifc_CSRSignal_{{attr['reg_name']}}_{{attr['signal_name']}});

	Reg#(Bit#({{node.width}})) r<-mkRegA(fromInteger(resetValue));
PulseWire pw_set <-mkPulseWire();
PulseWire pw_clear <-mkPulseWire();
PulseWire pw_swacc <-mkPulseWire();
PulseWire pw_swmod <-mkPulseWire();
RWire#(Bit#({{node.width}}))sw_wdata <-mkRWire();
RWire#(Bit#({{node.width}}))hw_wdata <-mkRWire();
RWire#(Bit#({{node.width}}))r_incr <-mkRWire();
RWire#(Bit#({{node.width}}))r_decr <-mkRWire();

rule r_write;
	let rr = r;
	{%if attr['singlepulse']%} rr = 0;{%endif%}
	if(pw_clear) rr =0;
	else if(pw_set) rr =1;
	else if(sw_wdata.wget( ) matches tagged Valid .v) rr = v;
	else if(hw_wdata.wget( ) matches tagged Valid .v) rr = v;
	else if(r_incr.wget( ) matches tagged Valid .v)   rr = r + v;
	else if(r_decr.wget( ) matches tagged Valid .v)   rr = r - v;
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
{%if attr['counter']%}
method Action incr(Bit#({{node.width}}) count);
		r_incr.wset(count);
endmethod
method Action decr(Bit#({{node.width}}) count);
		r_decr.wset(count);
endmethod
{%endif%}
endinterface
interface SW_{{attr['reg_name']}}_{{attr['signal_name']}} bus;
{%if attr['sw_writable']%}
method Action write(Bit#({{node.width}}) data);
	let mod=False;
	{%if attr['sw'] in ['AccessType.rw','AccessType.w']%} sw_wdata.wset(data);{%endif%}
	{%if attr['swmod']%} mod=(data!=r);{%endif%}
	{%if attr['swacc']%} pw_swacc.send();{%endif%}
	{%if attr['woclr']%} if(data ==1) pw_clear.send();{%endif%}
	{%if attr['woset']%}if( data ==1) pw_set.send();{%endif%}
        {%if attr['swmod'] and  attr['woclr']%} mod=(r!=0);{%endif%}
        {%if attr['swmod'] and attr['woset']%} mod=(r!=1); {%endif%}
	if(mod)
		pw_swmod.send();
endmethod
{%endif%}
{%if attr['sw_readable']%}
method ActionValue#(Bit#({{node.width}})) read;
	let rv=0;
	let mod=False;
	{%if attr['sw_acc']%} pw_swacc.send(); {%endif%}
        {%if attr['rclr']%} pw_clear.send();{%endif%}
        {%if attr['swmod'] and  attr['rclr']%} mod=(r!=0); {%endif%}
{%if attr['swmod'] and attr['rset']%} mod=(r!=1))  ; {%endif%}
{%if attr['rset']%} pw_set.send(); {%endif%}
	if(mod)
		pw_swmod.send();
		rv=r;
	return rv;
endmethod
{%endif%}
endinterface
endmodule
{%if gentest%}
(*synthesize*)
module testcsrreg_{{attr['reg_name']}}_{{attr['signal_name']}}(Ifc_CSRSignal_{{attr['reg_name']}}_{{attr['signal_name']}});
Ifc_CSRSignal_{{attr['reg_name']}}_{{attr['signal_name']}} ipaddress_r<-mkCSRSignal_{{attr['reg_name']}}_{{attr['signal_name']}}('h0);
return ipaddress_r;
endmodule
{%endif%}
// End getting CSR Code
