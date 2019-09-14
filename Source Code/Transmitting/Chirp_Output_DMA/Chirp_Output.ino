// high frequency chirp generation using teensy 3.6 DAC0 and DMA.

#include "chirpout.h"
#include <DMAChannel.h>
#include "pdb.h"

DMAChannel dma(false);


void setup() {
  
  dma.begin(true);
  
  extern volatile uint16_t chirp[58374];

  SIM_SCGC2 |= SIM_SCGC2_DAC0; // enable DAC clock
  DAC0_C0 = DAC_C0_DACEN | DAC_C0_DACRFS; // enable the DAC module, 3.3V reference

   // slowly ramp up to DC voltage, approx 1/4 second
  for (int16_t i=0; i<2048; i+=8)
  {
    *(volatile int16_t *)&(DAC0_DAT0L) = i;
    delay(1);
  }
  
  // set the programmable delay block to trigger DMA requests
  SIM_SCGC6 |= SIM_SCGC6_PDB; // enable PDB clock
  PDB0_IDLY = 0; // interrupt delay register
  PDB0_MOD = 0; //PDB_PERIOD; // modulus register, sets period
  
  PDB0_SC = PDB_CONFIG | PDB_SC_LDOK; // load registers from buffers
  PDB0_SC = PDB_CONFIG | PDB_SC_SWTRIG; // reset and restart
  PDB0_CH0C1 = 0x0101; // channel n control register?
  
  dma.sourceBuffer(chirp, sizeof(chirp));
  dma.destination(*(volatile uint16_t *)&(DAC0_DAT0L));
  dma.triggerAtHardwareEvent(DMAMUX_SOURCE_PDB);
  dma.enable();
}

  
void loop(){
}
