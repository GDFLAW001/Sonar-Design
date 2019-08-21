// Simple DAC sine wave test on Teensy 3.1

//elapsedMicros usec = 0;

#include "Prac2.h"

elapsedMicros usec = 0;

#define DAC0(a) *(volatile int *)&(DAC0_DAT0L)=a
void setup() {
  //Serial.begin(115200);
  analogWriteResolution(12);
  //Serial.println("ready");

  extern int chirp [40000];
  extern int sine [3700];


  /*
  while(1){
    for (int i = 0;i<3700;i++ ){
      analogWrite(A22,sine[i]);       
    }

   delay(10000);
  }
  */

  SIM_SCGC2 |= SIM_SCGC2_DAC0; // enable DAC clock
  DAC0_C0 = DAC_C0_DACEN | DAC_C0_DACRFS; // enable the DAC module, 3.3V reference

   while (1){
      for (int i = 0; i < 40000; i++){
        DAC0(chirp[i]);
      }
      delay(10000);
   }

    //noInterrupts();
}


  
void loop(){
}
