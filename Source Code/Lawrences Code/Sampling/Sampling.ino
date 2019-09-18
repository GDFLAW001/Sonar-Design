unsigned long Start;
unsigned long Count;
int t;


void setup() {
  Serial.begin(9600); // Open a serial coms channel
//  analogReadResolution(16); // Can be 8, 10, 12, 16
//  analogReadAveraging(1); // can be 1, 2, 4, 8, 16 or 32
//  analogReference(0); // Voltage reference - see docs

}

void loop() {
  if (Serial.available()){ // Waiting for commands from the computer
    uint8_t input = Serial.read(); // read the command
    if (input == 19) Serial.write(uint8_t(19));
    else Serial.write(input);
    
//    if (input == 'a'){ // Take a single reading and send over serial (pin A21)
//      Serial.write(analogRead(A14));
//      //Serial.println("hello");
//    }
//    
//    if (input == 'b'){ // Take 20k readings and send over serial (read one, send one)
//      int noOfReads = 100;
//      int a0; 
//      int reads[noOfReads];
//      t = micros();
//      for(int i = 0; i < noOfReads ; i++){// read data
//        reads[i] = analogRead(A14);             
//      }
//     // t = micros() - t;
//      for(int i = 0; i < noOfReads ; i++){//send data (as two bytes rather than text)
//        a0 = reads[i];
//        Serial.write((a0 >> 8) & 0xFF); // Send the upper byte first
//        Serial.write((a0 & 0xFF)); // Send the lower byte
//      }
//    }
//       
//    if (input == 't'){ // Return the time taken (in microseconds) for the most recetn operation.
//      Serial.println(t);
//    }
  }
}
