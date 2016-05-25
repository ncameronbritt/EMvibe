
public class EMvibeReadTable {

	FileIO fio;
	StringTokenizer st;

	string filename;
	string temp;
	float freq[0]; //array to hold frequencies; capacity doesn't matter
	int countLines;
	string midiFromFile;
	float freqFromFile;

	fun void set(string f) {
		f => filename;
		// open a file
		fio.open( filename, FileIO.READ );

		// ensure it's ok
		if( !fio.good() ) {
			cherr <= "can't open file: " <= filename <= " for reading..." <= IO.newline();
    		me.exit();
		}
		// read the file in
		//makes associative array where the index is the midi number as a string
		while( fio.more() ) {
    		fio.readLine() => temp => st.set;
			while(st.more() ) {
				st.next() => midiFromFile; 
				st.next() => Std.atof => freqFromFile;
			}
			freqFromFile => freq[midiFromFile];
			countLines++;

		}
	}
	fun float[] getTable() {
		return freq;
	}
	fun int size() {
		//Hack to ignore final carriage return from Max
		return countLines - 1;
	}


}


