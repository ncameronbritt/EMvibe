
public class EMvibeOsc2 {
	/*
	This mixes two frequencies using "pulse train width modulation" hack
	This should keep both oscillators in phase
	It should also ensure that the pulsewidth isn't too wide (capped at 50%)
	*/


	//class vars
	0 => int dac_chan;
	float freq1;
	float freq2;
	float gain, threshhold, negThreshold;
	float val, val2;
	float mix; //mix = % fundamental
	float lfoFreq;
	int changeMix;


	TriOsc s => blackhole;
	TriOsc s2 => blackhole;
	Step i;
	Phasor lfo => blackhole;

	/*
	//stereo
	if(dac.channels() == 2) {
		i => dac;
	}
	//mutichannel
	if(dac.channels() > 2) {
		i => dac.chan(dac_chan);
	}
	*/
	//initial setup
	setFreqs(440.9, 1766.78);
	35 => setLFO;
	0.15 => setGain;
	0.0 => setMix; 

	//keep up with which oscillator is playing so we can add 
	// dead space btw switches (avoid MOSFET shoot-through)
	1 => int whichOsc; 

	//spork ~ play();

	fun void play() {
		while(true) {
			//0 for 5::samp when mix changes
			if(changeMix != 0) {
				0 => i.next;
				5::samp => now;
				0 => changeMix;
			}
			if(mix == 1.0) {
				s.last() => val;
				if(val < threshhold && val > negThreshold) 0 => i.next;
				else if(val >= threshhold) 0.1 => i.next;
				else -0.1 => i.next;
				1 => whichOsc;
			}
			else if(mix == 0.0) {
				s2.last() => val2;
				if(val2 < threshhold && val2 > negThreshold) 0 => i.next;
				else if(val2 >= threshhold) 0.1 => i.next;
				else -0.1 => i.next;
				2 => whichOsc;
			}
			else if(lfo.last() < mix) { //send freq1 out
				//check if oscillators have switched
				//if so add 5::samp dead space
				if(whichOsc != 1) {
					0 => i.next;
					1::ms => now;
					1 => whichOsc; // 1 = this oscillator
				} 
				s.last() => val;
				if(val < threshhold && val > threshhold * -1.0) 0 => i.next;
				else if(val >= threshhold) 0.1 => i.next;
				else -0.1 => i.next;
			}
			else { //send freq2 out
				//check if oscillators have switched
				//if so add 5::samp dead space
				if(whichOsc != 2) {
					0 => i.next;
					1::ms => now;
					2 => whichOsc; //2 = this oscillator
				} 
				s2.last() => val2;
				if(val2 < threshhold && val2 > threshhold * -1.0) 0 => i.next;
				else if(val2 >= threshhold) 0.1 => i.next;
				else -0.1 => i.next;
			}
			1::samp => now;
		}
	}

	fun void setFreqs(float f1, float f2) {
		f1 => freq1 => s.freq;
		f2 => freq2 => s2.freq;
		//<<<"new freqs:", freq1, freq2>>>;
	}
	fun void setFreq1(float f1) {
		f1 => freq1 => s.freq;
	}
	fun void setFreq2(float f2) {
		f2 => freq2 => s2.freq;
	}	
	fun void setGain(float g) {
		g => gain;
		Std.fabs(gain - 1.0) => threshhold;
		//when sine exceeds +/- threshhold 1/-1 is sent
		//lower threshhold = wider pulsewidth
		//*make sure pulsewidth doesn't exceed 0.5 to avoid MOSFET shoot-through
		if(threshhold < 0.5) 0.5 => threshhold;
		threshhold * -1.0 => negThreshold;
	}
	fun void setMix(float m) {
		if(m < 0.0) 0 => mix;
		else if(m > 1.0) 1.0 => mix;
		else m => mix;
		1 => changeMix;
	}
	fun void setLFO(float freq) {
		freq => lfo.freq;
	}
	fun void setChan(int chan) {
		chan => dac_chan;
		i => dac.chan(dac_chan);
		spork ~ play();
	}

	fun float getFreq1() { return freq1; }
	fun float getFreq2() { return freq2; }
	fun float getGain() { return gain; }
	fun float getMix() { return mix; }
	fun float getLFO() { return lfo.freq(); }
	fun int getDAC() { return dac_chan; }


}