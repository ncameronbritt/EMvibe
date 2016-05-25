private class MakeNote {
	MidiOut mout;
	MidiMsg msg;

	if(!mout.open("IAC Driver IAC Bus 2")) me.exit();
	<<< "MIDI device: ChucK internal", mout.num(), " -> ", mout.name() >>>;

	1 => int midiChannel;
	int activeNotes[127]; //status for toggled notes
	10 => int polyChan;

	fun void makeNote(int note, dur noteLength) {	
		//<<<note, noteLength>>>;
		noteOn(note);
		noteLength => now;
		noteOff(note);
	}
		fun void makeNote(int note, int chan, dur noteLength) {	
		//<<<note, noteLength>>>;
		noteOn(note, chan);
		noteLength => now;
		channelAftertouch(chan, 0);//reset aftertouch 
		noteOff(note, chan);
	}

	fun void makeNoteSpectrum(int note, int chan, int spectrum, dur noteLength) {
		//<<<note, noteLength, chan>>>;
		noteOn(note, chan);
		channelAftertouch(chan, spectrum);
		noteLength => now;
		channelAftertouch(chan, 0);
		noteOff(note, chan);
	}

	fun void noteOn(int note) {
		//<<<note, "on">>>;
		143 + midiChannel => msg.data1;
		note => msg.data2;
		90 => msg.data3;
		mout.send(msg);
	}

	fun void noteOn(int note, int chan) {
		//<<<note, "on">>>;
		143 + chan => msg.data1;
		note => msg.data2;
		90 => msg.data3;
		mout.send(msg);
	}

	fun void noteOff(int note) {
		//<<<note, "released">>>;
		143 + midiChannel => msg.data1;
		note => msg.data2;
		0 => msg.data3;
		mout.send(msg);
	}

	fun void noteOff(int note, int chan) {
		//<<<note, "released">>>;
		143 + chan => msg.data1;
		note => msg.data2;
		0 => msg.data3;
		mout.send(msg);
	}

	fun void setEMvibeGain(int val) {
		176 => msg.data1;
		7 => msg.data2;
		val => msg.data3;
		mout.send(msg);
	}
	fun void setEMvibeSpectrum(int val) {
		176 => msg.data1;
		1 => msg.data2;
		val => msg.data3;
		mout.send(msg);
	}
	//gain per note
	fun void polyAftertouch(int note, int val) {
		160 => msg.data1;
		note => msg.data2;
		val => msg.data3;
		mout.send(msg);
	}
	//spectrum per note
	fun void channelAftertouch(int channel, int val) {
		if(channel > 9 && channel < 17) {
			207 + channel => msg.data1;
			val => msg.data2;
			0 => msg.data3; //don't need 3rd data
			mout.send(msg);
		}
	}
	//single note pulsing harmonics
	fun void makeNoteAutoHarm(int note, int chan, dur noteLength) {
		Std.rand2(200, 400)::ms => dur pulse;
		0 => int counter;
		noteLength + now => time later;

		spork ~ makeNote(note, chan, noteLength);
		while(now < later) {
			if(counter > 1) 0 => counter;
			if(counter == 0) {
				channelAftertouch(chan, 127);
				0.33::pulse => now;
				counter++;
			}
			else {
				channelAftertouch(chan, 0);
				0.67::pulse => now;
				counter++;
			}		
		}
		channelAftertouch(chan, 0); //reset when done
	}
	fun void envNote(int note, dur attack, dur sustain, dur release) {
		Envelope e => blackhole;
		int midiEnv;
		attack => e.duration;
	
		noteOn(note);
		polyAftertouch(note, 1);
		e.keyOn();
		now + attack => time later;
		while(now < later) {
			(e.value() * 127.0) $ int => midiEnv;
			polyAftertouch(note, midiEnv);
			100::ms => now;
			//<<<midiEnv>>>;
		}
		polyAftertouch(note, 127);
		sustain => now;
		release => e.duration;
		now + release => later;
		e.keyOff();
		while(now < later) {
			(e.value() * 127.0) $ int => midiEnv;
			polyAftertouch(note, midiEnv);
			10::ms => now;
			//<<<midiEnv>>>;
		}
		noteOff(note);
	}

	fun void envNote(int note, dur attack, dur sustain) {
		Envelope e => blackhole;
		int midiEnv;
		attack => e.duration;
		//<<<sustain>>>;
		noteOn(note);
		//<<<note, "on">>>;
		polyAftertouch(note, 1);
		e.keyOn();
		now + attack => time later;
		while(now < later) {
			(e.value() * 127.0) $ int => midiEnv;
			polyAftertouch(note, midiEnv);
			10::ms => now;
			//<<<midiEnv>>>;
		}
		polyAftertouch(note, 127);
		sustain => now;
		noteOff(note);
		//<<<note, "off">>>;
	}
	//fade in note -- no noteOff
	fun void envNoteOn(int note, dur attack) {
		Envelope e => blackhole;
		int midiEnv;
		attack => e.duration;
	
		noteOn(note);
		polyAftertouch(note, 1);
		e.keyOn();
		now + attack => time later;
		while(now < later) {
			(e.value() * 127.0) $ int => midiEnv;
			polyAftertouch(note, midiEnv);
			10::ms => now;
			//<<<midiEnv>>>;
		}
		polyAftertouch(note, 127);
	}

	fun void arp(int note, dur gestureLength) {
		//<<<note, gestureLength>>>;
		note % 12 + 53 => note;
		[0, 7, 12, 19, 12, 7] @=> int add[];
		200::ms => dur pulse;
		int counter;
		now + gestureLength => time later;
		while(now < later) {
			if(counter >= add.cap()) 0 => counter;
			spork ~ makeNote(note + add[counter], pulse);
			counter++;
			pulse => now;
		}
		pulse => now; //so that child shreds don't get killed before noteOff
	}
		
	fun void makeOctave(int note, dur noteLength) {
		if(polyChan > 16) 10 => polyChan;
		if(note < 78) {
			spork ~ makeNote(note + 12, noteLength);
		}
		else {
			spork ~ makeNoteSpectrum(note-12, polyChan, 127, noteLength);
			polyChan++;
		}
	}
	fun void gliss(int start, int dest) {
		100::ms => dur waitTime;
		200::ms => dur noteLen;
		
		dest - start => int vector;
		Std.sgn(vector) $ int => int move;

		while(start != dest) {
			if(start == 0 || dest == 0) break;
			if(start == dest) break;
			start + move => start;
			spork ~ makeNote(start, noteLen);
			waitTime => now;
		}
		noteLen => now; //hang around to avoid stuck notes


	}
	
		//reset *status* for all toggled notes
	fun void toggleOff() {
		for(0 => int i; i < 127; i++) {
			0 => activeNotes[i];
		}
	}
	fun void panic() {
		for(0 => int i; i < 37; i++) {
			noteOff(i+53);
		}
		toggleOff();
		//reset aftertouch
		for(0 => int i; i < 16; i++) {
			channelAftertouch(i, 0);
		}
	}

}

public class MaxOSCtoMidi extends MakeNote {
	OscRecv recv;
	6449 => recv.port;
	recv.listen();
	recv.event("/EMvibe/fixedDurNote, i i") @=> OscEvent fixedDurNote;
	recv.event("/EMvibe/toggleNote, i") @=> OscEvent toggleNote;
	recv.event("/EMvibe/fixedDurOctave, i i") @=> OscEvent fixedDurOctave;
	recv.event("/EMvibe/arpeggiator, i i") @=> OscEvent arpeggiator;
	recv.event("/EMvibe/shimmer, i i") @=> OscEvent shimmer;
	recv.event("/EMvibe/envNoteOn, i i") @=> OscEvent fadeOn;
	recv.event("/EMvibe/envNoteFixed, i i i") @=> OscEvent envNoteFixed;
	recv.event("/EMvibe/envNote, i i i i") @=> OscEvent envNoteASR;
	recv.event("/EMvibe/gliss, i i") @=> OscEvent doGliss;
	recv.event("/EMvibe/panic") @=> OscEvent recvPanic;


	spork ~ fixedDurListener();
	spork ~ toggleNoteListener();
	spork ~ fixedDurOctaveListener();
	spork ~ arpeggiatorListener();
	spork ~ shimmerListener();
	spork ~ fadeOnListener();
	spork ~ envNoteFixedListener();
	spork ~ envNoteListener();
	spork ~ glissListener();
	spork ~ panicListener();
	
	int note;
	int duration;
	dur noteLength;
	dur fadeLength;
	dur releaseLength;

	//int activeNotes[127]; //status for toggled notes
	//10 => int polyChan; //for assigning channels for chan aftertouch

	fun void panicListener() {
		while(true) {
			recvPanic => now;
			while(recvPanic.nextMsg() != 0) {
				panic();
			}
		}
	}
	fun void fixedDurListener() {
		while(true) {
			fixedDurNote => now;
			while(fixedDurNote.nextMsg() != 0) {
				fixedDurNote.getInt() => note;
				fixedDurNote.getInt() => duration;
				duration::ms => noteLength;
				<<<note, noteLength>>>;
				spork ~ makeNote(note, noteLength);
			}
		}
	}

	fun void fixedDurOctaveListener() {
		while(true) {
			fixedDurOctave => now;
			while(fixedDurOctave.nextMsg() != 0) {
				fixedDurOctave.getInt() => note;
				fixedDurOctave.getInt() => duration;
				duration::ms => noteLength;
				makeOctave(note, noteLength);
			}
		}
	}

	fun void toggleNoteListener() {
		while(true) {
			toggleNote => now;
			while(toggleNote.nextMsg() != 0) {
				toggleNote.getInt() => note;
				if(checkActive(note)) noteOn(note);
				else noteOff(note);				
			}
		}
	}
	fun void arpeggiatorListener() {
		while(true) {
			arpeggiator => now;
			while(arpeggiator.nextMsg() != 0) {
				arpeggiator.getInt() => note;
				arpeggiator.getInt() => duration;
				duration::ms => noteLength;
				//<<<note, noteLength>>>;
				spork ~ arp(note, noteLength);
			}
		}
	}
	fun void shimmerListener() {
		while(true) {
			shimmer => now;
			while(shimmer.nextMsg() != 0) {
				shimmer.getInt() => note;
				shimmer.getInt() => duration;
				duration::ms => noteLength;
				if(polyChan > 16) 10 => polyChan;
				spork ~ makeNoteAutoHarm(note, polyChan, noteLength);
				//<<<note, polyChan, noteLength>>>;
				polyChan++;
			}
		}
	}
	fun void fadeOnListener() {
		while(true) {
			fadeOn => now;
			while(fadeOn.nextMsg() != 0) {
				fadeOn.getInt() => note;
				fadeOn.getInt() => duration;
				duration::ms => fadeLength;
				spork ~ envNoteOn(note, fadeLength);
			}
		}
	}
	fun void envNoteListener() {
		while(true) {
			envNoteASR => now;
			
			while(envNoteASR.nextMsg() != 0) {
				envNoteASR.getInt() => note;
				envNoteASR.getInt() => duration;
				duration::ms => fadeLength;
				envNoteASR.getInt() => duration;
				duration::ms => noteLength;
				envNoteASR.getInt() => duration;
				duration::ms => releaseLength;
				spork ~ envNote(note, fadeLength, noteLength, releaseLength);
			}
		}
	}
	fun void envNoteFixedListener() {
		while(true) {
			envNoteFixed => now;
			while(envNoteFixed.nextMsg() != 0) {
				envNoteFixed.getInt() => note;
				envNoteFixed.getInt() => duration;
				duration::ms => fadeLength;
				envNoteFixed.getInt() => duration;
				duration::ms => noteLength;
				spork ~ envNote(note, fadeLength, noteLength);
			}
		}
	}
	fun void glissListener() {
		int start, dest;
		while(true) {
			doGliss => now;
			while(doGliss.nextMsg() != 0) {
				doGliss.getInt() => dest;
				doGliss.getInt() => start;
				spork ~ gliss(start, dest);
			}
		}
	}

	fun int checkActive(int note) {
		activeNotes[note]++;
		if(activeNotes[note] > 1) {
			0 => activeNotes[note];
			return 0;
		}
		else {
			1 => activeNotes[note];
			return 1;
		}

	}


}