#include <stdint.h>
#include <stdlib.h>
#include <conio.h>
#include "memorymap.h"

#define BUF_SIZE 8000

void putx8(uint8_t x)
{
   static const char hex[16] = "0123456789ABCDEF";
   cputc(hex[(x>>4) & 0x0F]);
   cputc(hex[(x>>0) & 0x0F]);
}

void main(void)
{
   uint8_t loop_counter = 0;

   // Allocate receive buffer. This will never be free'd.
   // Using malloc avoids a call to memset generated by the compiler.
   // This reduces simulation time.
   uint8_t *pBuf = (uint8_t *) malloc(BUF_SIZE);  // Fairly small buffer to test wrap-around.

   // Configure Ethernet DMA
   MEMIO_CONFIG->ethEnable = 0;  // DMA must be disabled during configuration.
   MEMIO_CONFIG->ethStart  = (uint16_t) pBuf;
   MEMIO_CONFIG->ethEnd    = (uint16_t) pBuf + BUF_SIZE;
   MEMIO_CONFIG->ethRdPtr  = MEMIO_CONFIG->ethStart;
   MEMIO_CONFIG->ethEnable = 1;
   
   gotoxy(0, 0);

   // Wait for data to be received, and print to the screen
   while (1)
   {
      loop_counter += 1;   // This generates a write to the main memory.
      if (MEMIO_CONFIG->ethRdPtr == MEMIO_STATUS->ethWrPtr)
         continue;   // Go back and wait for data

      putx8(*(uint8_t *)(MEMIO_CONFIG->ethRdPtr));

      if (MEMIO_CONFIG->ethRdPtr != MEMIO_CONFIG->ethEnd)
      {
         MEMIO_CONFIG->ethRdPtr += 1;
      }
      else
      {
         MEMIO_CONFIG->ethRdPtr = MEMIO_CONFIG->ethStart;
      }
   }

} // end of main

