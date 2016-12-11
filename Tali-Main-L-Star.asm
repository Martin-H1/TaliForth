; -----------------------------------------------------------------------------
; MAIN FILE 
; Tali Forth for the l-star and replica 1
; Scot W. Stevenson <mheermance@gmail.com>
;
; First version  9. Dec 2016
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; Used with the Ophis assembler and the py65mon simulator
; -----------------------------------------------------------------------------
; This image is designed loaded in high ram via the Woz mon and started with
; 5A00R
.org $5900

.word $5A00

.org $5A00
jmp k_resetv

.alias RamSize          $59FF

; =============================================================================
; FORTH CODE 
FORTH: 
.require "Tali-Forth.asm"

; =============================================================================
; KERNEL 
.require "Tali-Kernel-L-Star.asm"

; =============================================================================
; LOAD ASSEMBLER MACROS
.require "macros.asm"

; =============================================================================
; END
