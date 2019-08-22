// high frequency chirp generation using teensy 3.6 DAC0.

#include "chirpout.h"

#define DAC0(a) *(volatile int *)&(DAC0_DAT0L)=a
void setup() {
  analogWriteResolution(12);

  extern int chirp [79910];
  extern int sine [3700];

  SIM_SCGC2 |= SIM_SCGC2_DAC0; // enable DAC clock
  DAC0_C0 = DAC_C0_DACEN | DAC_C0_DACRFS; // enable the DAC module, 3.3V reference

   while (1){
      for (int i = 0; i < 79910; i++){
        DAC0(chirp[i]);
      }
      delay(10000);
   }

    //noInterrupts();
}


  
void loop(){
}
