// high frequency chirp generation using teensy 3.6 DAC0.

#include "chirpout.h"

#define DAC0(a) *(volatile int16_t *)&(DAC0_DAT0L)=a
void setup() {
  analogWriteResolution(12);

  extern volatile uint16_t chirp[58374];

  SIM_SCGC2 |= SIM_SCGC2_DAC0; // enable DAC clock
  DAC0_C0 = DAC_C0_DACEN | DAC_C0_DACRFS; // enable the DAC module, 3.3V reference

   while (1){
      for (int i = 0; i < 58374; i++){
        DAC0(chirp[i]);
      }
      delay(50);
   }

    //noInterrupts();
}

  
void loop(){
}
