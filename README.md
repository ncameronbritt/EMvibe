# EMvibe
This is the performance software for the [EMvibe](http://www.ncameronbritt.com/emvibe/). The EMvibe is an electromagnetically actuated vibraphone. The software uses [ChucK](http://chuck.cs.princeton.edu/) and [Max](https://cycling74.com/). 

As ChucK can only have one public class per file, runMaxCtl.ck adds all of the necessary classes to the VM. 
* EMvibeMain_class.ck patches everything together. It also includes the MIDI listener.
* EMvibeOsc2_class.ck contains the synthesis software
* EMvibeVoiceManager_class.ck allocates audio channels and sets the shift registers on the instrument itself via a [Teensy 2.0] (https://www.pjrc.com/store/teensy.html) microcontroller 
* EMvibeReadTable_class.ck reads frequencies and MIDI note numbers from a text. Not used anymore; frequencies are hard coded
* maxCtl.ck translates OSC messages (coming from Max) to the appropriate MIDI messages, defining things like envelopes, but also defining more complex behaviors. 
* EMvibePerformanceInterface_new.maxpat is the main way the performer interacts with the EMvibe. It includes a pitch-tracker for detecting incoming audio, a matrix for assigning different effects to different notes on the instrument, and a display that gives the user feedback about the state of the instrument.
* Other Max files define presets and different effects.

NB Needless to say this software doesn't do much (anything, really) without the EMvibe itself. 
