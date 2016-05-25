/*
Usage:
EMvibeVoiceManager mgmt;
//need to open HIDUINO, find device num using chuck --probe
2 => mgmt.device;

//give it array of midi nums corresponding to coils
//cap should be the same as number of coils
//Order is important!!! Order in which the shift registers are connected
[53,55,57,59,60,62,64] @=> int notes[];
notes => manage.set;

//can set number of channels -- 8 by default
//should be one more than you plan to use, ch 0 is NO_OUTPUT
8 => mgmt.numChans;

mgmt.newNote(note, velocity) => int voice;
//use set freq, etc for voice


*/

/* Order
[
	53,55,57,59,60,62,64, //F3-E4
	65,67,69,71,72,74,76, //F4-E5
	77,79,81,83,84,86,88, //F5-E6
	89,87,85,82,80,78,0, //F6, Eb6-F#5
	75,73,70,68,66,0,0, //Eb5-F#4
	63,61,58,56,54,0,0
] @=> int order[]; //Eb4-F3

*/


public class EMvibeVoiceManager{
	int deviceNum;
	MidiOut mout;
	MidiMsg msg;

	//OSC stuff, send to Max
	OscSend snd;
	"localhost" => string hostname;
	6448 => int port;
	snd.setHost(hostname, port);
	
	int usedChannels[127]; //one for each midinote
	
	int shiftRegisterOrder[]; //physical order of shit registers
	//need to worry about order in here!!!
	
	int counter;

	8 => int numChannels; //should be one more than number of channels used
	int channelTaken[numChannels];
	int soundingNotes[8];

	fun void numChans(int num) {
		num => numChannels;
	}

	fun void set(int order[]) {
		//<<<"set", me.id()>>>;
		order @=> shiftRegisterOrder;
		//hack if number of coils isn't multiple of 2
		if(shiftRegisterOrder.cap() % 2 == 0) shiftRegisterOrder.cap() => counter;
		else {
			shiftRegisterOrder.cap() + 1 => shiftRegisterOrder.size;
			shiftRegisterOrder.size() => counter;
		}
		//need this for setShiftRegisters() b/c
		//functions count down index numbers
		 1 -=> counter;


	}
	//don't need this one now b/c using Max/serial instead of midi
	fun void device(int dev) {
		dev => deviceNum;
		if(!mout.open(dev)) me.exit();
		<<< "MIDI device:", mout.num(), " -> ", mout.name() >>>;
	}

	fun void begin() {
		if(!mout.open("Teensy MIDI")) me.exit();
		<<< "MIDI device:", mout.num(), " -> ", mout.name() >>>;
		setShiftRegisters();
	}

	
	fun int newNote(int note, int vel) {
		//<<<"newNote", vel, me.id()>>>;
		
		if(vel > 0) { //for noteOn
			//check to make sure note isn't already in use
			if(usedChannels[note] == 0) {
				getVoice() => int chan;
				chan => usedChannels[note];
				//<<<chan>>>;
				//get the frequencies, connect audio, etc

				//keep up with what notes are sounding 
				note => soundingNotes[chan];		
				//setShiftRegisters();
				//send sounding notes to MAx
				if(chan != 0) sendSoundingNote(note, 1);
				return chan;
			}
			//if a note is already in use retrun its dac chan
			else return usedChannels[note];		
		}
		if(vel == 0) { // for noteOff
			usedChannels[note] => int chanToFree;
			0 => channelTaken[chanToFree]; //free chan 
			0 => usedChannels[note]; //set chan for this note to 0
			//for keeping track of what notes are sounding
			0 => soundingNotes[chanToFree];
			//<<<"Freeing ch", chanToFree>>>;
			//setShiftRegisters();
			//send sounding notes to MAx
			sendSoundingNote(note, 0);
			return 0;

		}
	}
	
	fun int getChan(int note) {
		if(usedChannels[note] != 0) return usedChannels[note];
		else return 0;

	}
	
	//returns channel number, if none available return 0 -- dummy chan
	fun int getVoice() {
		//<<<"getVoice", me.id()>>>;
		int whichChan;
		0 => int flag;
		for(1 => int i; i < numChannels; i++) {
			if(channelTaken[i] != 1) {
				i => whichChan; //offset by 1 to keep 0 a dummy channel
				1 => flag;
				1 => channelTaken[i];
				break;
			}
		}
		if(flag) { //if channel available
			return whichChan; //return chanel num
		}
		else {
			return 0; //dummy channel
		}
	
	}
	
	
	
	fun void setShiftRegisters() {
		//<<<"setShiftReg", me.id()>>>;
		int dataByte;
		counter => int internalCount;
		while(internalCount >= 0) {
			0 => dataByte; //reset each time through loop
			//use shiftRegisterOrder to index used channels
			//shift first num left, then add the second to make 8-bit byte
			//combining two 4-bit chars to make 8-bit word
			//set so odd channels are LSB. Arduino sends MSB first to ignore ch 7-8
			usedChannels[shiftRegisterOrder[internalCount]] << 3 => dataByte; //MSB
			usedChannels[shiftRegisterOrder[internalCount - 1]] +=> dataByte; //LSB

			//send message
			sendMsg(dataByte);
			2 -=> internalCount;
		//<<<dataByte>>>;
		}
		latch();
		//<<<"**********">>>;
		//for(0 => int i; i < 37; i++) {
		//	<<<i+53, usedChannels[i+53]>>>;
		//}
		/*
		for(0 => int i; i < channelTaken.cap(); i++) {
			<<<channelTaken[i]>>>; 
		}
		*/
		//<<<"##########">>>;
	}
	
	//send program change message to shift registers
	fun void sendMsg(int data) {
		176 => msg.data1; //control change
		1 => msg.data2;
		data => msg.data3;
		mout.send(msg);
		//snd.startMsg("/EMvibe", "i");
		//data => snd.addInt;
	}
	//send 255 to set latch pin on shift registers
	fun void latch() {
		144 => msg.data1;
		60 => msg.data2;
		127 => msg.data3;
		mout.send(msg);
		//snd.startMsg("/EMvibe", "i");
		//255 => snd.addInt;
	}

	fun int[] getSoundingNotes() {
		return soundingNotes;
	}
	fun void sendSoundingNote(int note, int status) {
		snd.startMsg("/EMvibe/soundingNote", "i, i");
		note => snd.addInt;
		status => snd.addInt;
	
	}
	
}