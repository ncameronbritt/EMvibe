/*
Midi chans 1-9: OMNI mode -- volume is per chan or global; spectrum is global only
Midi chans 10-16: POLY mode -- spectrum/volume both per chan; global paramaeter changes also avail.

Messages:
	noteOn => noteOn (noteOn w/ vel == 0 is noteOff)
	noteOff => noteOff
	CC 7 => global volume
	CC 1 => global spectrum
	Poly aftertouch => volume
	Chan aftertouch => spectrum -- poly mode only

TODO:
initial gain for noteOns -- different for omni/poly? use velocity?
Make this into class

class vars:
midi device num
everything else set specifically for EMvibe? e.g. audio chans, etc


Usage:
EMvibeMain main;
0 => main.setDevice;
// or "IAC Driver IAC Bus 1" => main.setDevice;

//infinite loop
while(true) 1::second => now;
//should just work if a midi device is hooked up


*/


public class EMvibeMain {

	//*** midi device number for input ***
	0 => int inputDevice;
	
	/*
	EMvibeReadTable table;
	//path to file with tunings -- should be in the path with the other files
	"tuning.txt" => table.set;
	//get frequency array
	table.getTable() @=> float freqs[];
	*/

	//hard code tuning. To read from file uncomment above (doesn't do tuning right).
	float freqs[0][2];
	[175.21, 703.0] @=> freqs["53"];
	[185.838, 744.1] @=> freqs["54"];
	[196.7, 788.29] @=> freqs["55"];
	[208.36, 834.5] @=> freqs["56"];
	[220.73, 884.93] @=> freqs["57"];
	[233.99, 936.56] @=> freqs["58"];
	[247.87, 992.84] @=> freqs["59"];
	[262.6, 1052.74] @=> freqs["60"];
	[278.1, 1113.77] @=> freqs["61"];
	[294.66, 1180.4] @=> freqs["62"];
	[312.24, 1249.92] @=> freqs["63"];
	[330.6, 1324.503] @=> freqs["64"];
	[350.24, 1403.0] @=> freqs["65"];
	[370.82, 1487.37] @=> freqs["66"];
	[392.98, 1575.35] @=> freqs["67"];
	[416.18, 1668.33] @=> freqs["68"];
	[440.9, 1766.78] @=> freqs["69"];
	[467.0, 1873.131] @=> freqs["70"];
	[494.7, 1981.14] @=> freqs["71"];
	[524.35, 2099.1] @=> freqs["72"];
	[555.66, 2225.0] @=> freqs["73"];
	[588.47, 2357.65] @=> freqs["74"];
	[623.28, 2498.41] @=> freqs["75"];
	[660.11, 2644.36] @=> freqs["76"];
	[699.31, 2806.0] @=> freqs["77"];
	[740.75, 2967.72] @=> freqs["78"];
	[784.79, 3160.68] @=> freqs["79"];
	[831.15, 3353.49] @=> freqs["80"];
	[880.35, 3515.4] @=> freqs["81"];
	[932.9, 0.0] @=> freqs["82"];
	[987.5, 0.0] @=> freqs["83"];
	[1046.49, 0.0] @=> freqs["84"];
	[1108.65, 0.0] @=> freqs["85"];
	[1174.78, 0.0] @=> freqs["86"];
	[1244.41, 0.0] @=> freqs["87"];
	[1317.83, 0.0] @=> freqs["88"];
	[1395.86, 0.0] @=> freqs["89"];
	//zero out frequencies above 3675 to guarantee 3 samps btw peaks

	
	EMvibeVoiceManager mgr;
	
	//array of coils/midi nums should be in same order of shift registers

	[
	53,55,57,59,60,62,64,0,
	65,67,69,71,72,74,76,0,
	77,79,81,83,84,86,88,0,
	89,87,85,82,80,78,0,0,
	75,73,0,70,68,66,0,0,
	63,61,58,56,0,54,0,0
	] @=> int coils[]; //F-E

	//[64,65,67,69,71,74,76] @=> int coils[];
	//give this array to voice manager
	coils => mgr.set;
	//device num for microcontroller if using usbmidi
	mgr.begin(); 
	
	//number of dac channels (must be >= 2 b/c 0 is always NO_OUTPUT)
	8 => int numChannels;
	//mgr needs to know numChannels too
	numChannels => mgr.numChans;
	
	//oscillators
	EMvibeOsc2 osc[numChannels]; 
	//assign each to dac channel
	//leave osc[0] unconnected
	for(1 => int i; i < numChannels; i++) {
		i => osc[i].setChan; //setChan method actually starts audio processing
		1.0 => osc[i].setMix;
		1.0 => osc[i].setGain;
	}
	
	MidiIn min;
	MidiMsg msg;

	
	string index1, index2;
	int vx;
	int midiChan; //keep up with midi channel for poly mode
	int channelArray[16]; //one for each midi channel (only actually use indexes 9-15)
	float gain, mix;
	
	//*** edit instrument range ***
	53 => int lowestNote;
	89 => int highestNote;
	
	//open by device number
	fun void setDevice(int device) {
		device => inputDevice;
		if(!min.open(inputDevice)) me.exit();
		<<< "MIDI device, Main reciever:", min.num(), " -> ", min.name() >>>;
		spork ~ listen();
	}
	//open midi device by name
	fun void setDevice(string deviceName) {;
		if(!min.open(deviceName)) {
			<<<"Can't open", deviceName, ". Are you sure it's connected?">>>;
			me.exit();
		}
		<<<"MIDI device, Main reciever:", min.name()>>>;
		spork ~listen();
	}

	//sounding notes array controlled by VoiceManager
	fun int[] getSoundingNotes() {
		return mgr.getSoundingNotes();
	}
	/*
	//get array of sounding freqs
	fun float[] getSoundingFreqs() {
		float soundingFreqs[8];
		string temp;
		mgr.getSoundingNotes() @=> int midiNotes[];
		for(0 => int i; i < freqs.cap(); i++) {
			midiNotes[i] => Std.itoa => temp;
			freqs[temp] => soundingFreqs[i];
		}
		return soundingFreqs;	
	}
	*/
	fun void listen() {	
		//main loop
		while(true) {
			min => now;
				
			while(min.recv(msg)) {
				//<<<msg.data1, msg.data2, msg.data3>>>;
				//control change messages
				if(msg.data1 > 175 && msg.data1 < 192) {
					//GLOBAL VOLUME controller 7
					if(msg.data2 == 7) {
						Math.pow(msg.data3/127.0, 2) => gain;
						for(1 => int i; i < numChannels; i++) {
							gain/2.0 => osc[i].setGain;
							//<<<"Gain", gain>>>;
						}
					}
					//GLOBAL SPECTRUM controller 1
					//0 is full fundamental (seems more intuitive)
					if(msg.data2 == 1) {
						for(1 => int i; i < numChannels; i++) {
							Math.pow(((127 - msg.data3)/127.0), 2) => mix;
							mix => osc[i].setMix;
							//<<<"Mix:", mix>>>;
						}
					}
				}
				// NOTE OFF
				if(msg.data1 > 127  && msg.data1 < 144) {
					//turn note off
					mgr.newNote(msg.data2, 0) => vx;
					//update midi chan/vx array -- put in a 0
					msg.data1 - 128 => midiChan;
					vx => channelArray[midiChan];
		
				}
		
				// NOTE ON -- ch 1-9 -- OMNI mode
				if(msg.data1 > 143  && msg.data1 < 153) {
					//ignore messages outside of range
					if(msg.data2 < lowestNote || msg.data2 > highestNote) continue;
	
					//get voice and reset shift registers
					mgr.newNote(msg.data2, msg.data3) => vx;
					//if new vx set the frequency for that vx
					if(vx != 0) {
						/* for reading freqs from file
						//convert midi num to string for freq[] index
						msg.data2 => Std.itoa => index1;
						//for 2 8ve harmonic
						msg.data2 + 24 => Std.itoa  => index2;
						
						//set the freqs
						freqs[index1] => osc[vx].setFreq1;
						freqs[index2] => osc[vx].setFreq2;
						//set gain -- do I want this to be fixed to one val?
						//(msg.data3/127.0)/2.0 => osc[vx].setGain;
						//<<<freqs[index1], freqs[index2], vx>>>;
						*/
						// for hard coded freqs
						msg.data2 => Std.itoa => index1;
						freqs[index1][0] => osc[vx].setFreq1;
						freqs[index1][1] => osc[vx].setFreq2;
						//<<<freqs[index1][0], freqs[index1][1], vx>>>;
					}		
				}
		
				//NOTE ON -- ch 10-16 -- POLY mode
				if(msg.data1 > 152  && msg.data1 < 160) {
					//get midi chan
					msg.data1 - 144 => midiChan;
					//ignore messages outside of range
					if(msg.data2 < lowestNote || msg.data2 > highestNote) continue;
		
					//get voice and reset shift registers
					mgr.newNote(msg.data2, msg.data3) => vx;
		
					//keep up with what midiChannel vx is associated with for chan aftertouch
					vx => channelArray[midiChan];
		
					//if new vx set the frequency for that vx
					if(vx != 0) {
						/* for reading from file
						//convert midi num to string for freq[] index
						msg.data2 => Std.itoa => index1;
						//for 2 8ve harmonic
						msg.data2 + 24 => Std.itoa  => index2;
						
						//set the freqs
						freqs[index1] => osc[vx].setFreq1;
						freqs[index2] => osc[vx].setFreq2;
						//set gain -- do I want this to be fixed to one val?
						//(msg.data3/127.0)/2.0 => osc[vx].setGain;
						//<<<index1, index2, vx>>>;
						*/
						//for hard-coded freqs
						msg.data2 => Std.itoa => index1;
						freqs[index1][0] => osc[vx].setFreq1;
						freqs[index1][1] => osc[vx].setFreq2;
						//<<<freqs[index1][0], freqs[index1][1], vx>>>;
					}		
				}
				//GAIN per chan -- works for all midi channels
				//polyphonic aftertouch
				if(msg.data1 > 159 && msg.data1 < 176) {
					//get voice for midi note
					//can ignore midi channel 
					//<<<msg.data1, msg.data2, msg.data3>>>;
					msg.data1 - 168 => vx;
					mgr.getChan(msg.data2) => vx;
					Math.pow(msg.data3/127.0, 2)/2.0 => osc[vx].setGain;
					//<<<"Vx", vx, "gain:", osc[vx].getGain()>>>;
				}
				//SPECTRUM per chan -- only for midi chans 10-16
				//channel aftertouch
				if(msg.data1 > 216 && msg.data1 < 224) {
					msg.data1 - 208 => midiChan;
					//get vx associated with midiChan and set mix
					Math.pow(((127 - msg.data2)/127.0), 2) => mix;
					mix => osc[channelArray[midiChan]].setMix;
					//no data3 for this msg type
					//<<<"Channel", midiChan+1, "Spectrum", mix>>>;
				}
		
			}
		}
	}
}
