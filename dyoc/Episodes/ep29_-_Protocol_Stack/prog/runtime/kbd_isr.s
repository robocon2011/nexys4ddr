.setcpu		"6502"
.export		kbd_isr              ; Used in lib/irq.s
.export     _kbd_buffer_count, _kbd_buffer, _kbd_buffer_size
.export     check_for_abort_key

; The interrupt routine must be written entirely in assembler, because the C code is not re-entrant.
; Therefore, one shouldn't call C functions from this routine.
; Furthermore, it should be short and fast, so as not to slow down the main program.

; Address of memory mapped IO to read last keyboard event.
; Must match the corresponding address in prog/keyboard.h
KBD_DATA   = $7FE8

KBD_BUFFER_SIZE = 10


.segment	"RODATA"

_kbd_buffer_size:
   .byte KBD_BUFFER_SIZE


.segment	"BSS"

_kbd_buffer_count:
	.res	1,$00

_kbd_buffer:
	.res	KBD_BUFFER_SIZE, $00


.segment	"CODE"

; The interrupt service routine
; It will append the current keyboard event to the end of the buffer
; and increment the size of the buffer.
; If however the buffer is full, the current keyboard event is discarded.

kbd_isr:
   PHA                           ; Preserve A-register

   LDA KBD_DATA                  ; Get current keyboard event
   LDX _kbd_buffer_count         ; Get buffer size
   CPX _kbd_buffer_size          ; Is buffer full ?
   BCS end                       ; If yes, jump
   STA _kbd_buffer,X             ; Append to end of buffer
   INC _kbd_buffer_count         ; Increment buffer size
end:

   PLA                           ; Restore A-register
   RTS

check_for_abort_key:
   LDA _kbd_buffer_count
   BEQ no_key                    ; Jump if no keys in buffer
   TAY
   LDA _kbd_buffer-1,Y           ; Get last key pressed
   CMP #$03                      ; Is it ^C ?
   BNE no_key                    ; Jump if not
   SEC                           ; Last key pressed was ^C
   RTS
no_key:
   CLC                           ; Abort key not pressed
   RTS

