/*
Tunes one partial on one coil at a time.
Should send audio out on chan 1 only; chan 0 should be silent

*/

//osc stuff -- recv from Max
OscRecv recv;
6449 => recv.port;
recv.listen();
recv.event("/em-vibe/tuning, f") @=> OscEvent tuning;
recv.event("/em-vibe/next_coil, i") @=> OscEvent next;
recv.event("/em-vibe/gain, f") @=> OscEvent gain;

OscSend snd;
"localhost" => string hostname;
6448 => int port;
snd.setHost(hostname, port);

//midi for Teensy
//3 => int device; //***edit device number***
"Teensy MIDI" => string device;
MidiOut mout;
MidiMsg msg;
if(!mout.open(device)) me.exit();
<<< "MIDI device:", mout.num(), " -> ", mout.name() >>>;


//SimpleOsc s; //make some sound
48 => int numberOfCoils;//edit numCoils
int numCoils[0]; 
if(numberOfCoils % 2 == 0) numberOfCoils => numCoils.size;
else numberOfCoils + 1 => numCoils.size;

int coil;
numCoils.cap() - 1 => int counter;

2 => int numChannels;
EMvibeOsc1 osc[numChannels];
for(1 => int i; i < numChannels; i++) {
	i => osc[i].setChan;
}


class SwitchEvent extends Event {
	int chan;
}
SwitchEvent switcher;

spork ~ tune(tuning);
spork ~ selectCoil(next);
spork ~ changeCoil(switcher);
spork ~ changeGain(gain);

//initialize all to 0 -- no output
for(0 => int i; i < numCoils.size(); i++) {
	0 => numCoils[i];
}
setShiftRegisters();

while(true) {
	1::second => now;
}


fun void changeGain(OscEvent e) {
	while(true) {
		e => now;
		while(e.nextMsg() != 0) {
			e.getFloat() => osc[1].setGain; //where does msg go?
			<<<osc[1].getGain()>>>;
		}
	}
}

fun void tune(OscEvent e) {
	while(true) {
		e => now;
		while(e.nextMsg() != 0) {
			e.getFloat() => osc[1].setFreq; //where does msg go?
			<<<osc[1].getFreq()>>>;
		}
	}
}

fun void selectCoil(OscEvent e) {
	while(true) {
		e => now;
		while(e.nextMsg() != 0) {
			e.getInt() => int temp; 
			if(coil > numCoils.cap()) continue;
			temp => switcher.chan;
			switcher.signal();
		}
	}
}

fun void changeCoil(SwitchEvent e) {
	int which;
	while(true) {
		e => now;
		e.chan => which;
		<<<"coil #", which>>>;
		//set all to no output
		for(0 => int i; i < numCoils.cap(); i++) {
			0 => numCoils[i];
		}
		//now switch on the one we want;
		if(which > numberOfCoils || which == 0) {
			setShiftRegisters();
		}
		//avoid array out of bounds, make sure chan 0 == 0
		else {
			1 => numCoils[which - 1];
			setShiftRegisters();
		}
	}
}

fun void setShiftRegisters() {
	int dataByte;
	counter => int internalCount;
	while(internalCount >= 0) {
		0 => dataByte; //reset each time through loop
		//use shiftRegisterOrder to index used channels
		//shift first num left, then add the second to make 8-bit byte
		//combining two 4-bit chars to make 8-bit word
		numCoils[internalCount] << 3 => dataByte;
		numCoils[internalCount - 1] +=> dataByte;
		//send message
		sendMsg(dataByte);
		me.yield();
		2 -=> internalCount;
	}
	latch();
	<<<"**********">>>;
}

//send program change message to shift registers
fun void sendMsg(int data) {
	176 => msg.data1; //control change
	1 => msg.data2;
	data => msg.data3;
	mout.send(msg);
	<<<"data:", data>>>;
	//snd.startMsg("/EMvibe", "i");
	//data => snd.addInt;
}

fun void latch() {
	144 => msg.data1;
	60 => msg.data2;
	127 => msg.data3;
	mout.send(msg);
	//<<<"latch">>>;
	//snd.startMsg("/EMvibe", "i");
	//255 => snd.addInt;
}


class EMvibeOsc1 {
	/*
	This mixes two frequencies using "pulse train width modulation" hack
	This should keep both oscillators in phase
	It should also ensure that the pulsewidth isn't too wide (capped at 50%)
	*/


	//class vars
	1 => int dac_chan;
	float freq1;
	float gain;
	float threshhold;

	SinOsc s => blackhole;
	Step i;

	/*
	//stereo (for testing)
	if(dac.channels() == 2) {
		i => dac;
	}

	//mutichannel
	if(dac.channels() > 2) {
		i => dac.chan(dac_chan);
	}
	*/
	//initial setup
	setFreq(Std.mtof(53));
	//setFreq(Std.mtof(64));
	0.5 => setGain; 


	//spork ~ play();

	fun void play() {
		float val;
		while(true) {
			s.last() => val;
			if(val < threshhold && val > threshhold * -1.0) 0 => i.next;
			else if(val >= threshhold) 0.1 => i.next;
			else -0.1 => i.next;

			1::samp => now;
		}
	}

	fun void setFreq(float f1) {
		f1 => s.freq => freq1;
		<<<freq1>>>;

	}
	fun void setGain(float g) {
		g * 0.5 => gain;
		Std.fabs(gain - 1.0) => threshhold;
		//when sine exceeds +/- threshhold 1/-1 is sent
		//lower threshhold = wider pulsewidth
		//*make sure pulsewidth doesn't exceed 0.5 to avoid MOSFET shoot-through
		if(threshhold < 0.5) 0.5 => threshhold;
	}


	fun void setChan(int chan) {
		chan => dac_chan;
		i => dac.chan(dac_chan);
		spork ~ play();
	}

	fun float getFreq() { return s.freq(); }
	fun float getGain() { return gain; }
	fun int getDAC() { return dac_chan; }


}