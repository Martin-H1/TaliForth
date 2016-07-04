; -----------------------------------------------------------------------------
; KERNEL 
; for the Übersquirrel Mark Zero 
; Scot W. Stevenson <scot.stevenson@gmail.com>
;
; First version 19. Jan 2014
; This version  11. Feb 2015
; -----------------------------------------------------------------------------
; Very basic and thin software layer to provide a basis for the Forth system 
; to run on. 

; -----------------------------------------------------------------------------
; Used with the Ophis assembler and the py65mon simulator
; -----------------------------------------------------------------------------

;==============================================================================
; DEFINITIONS
;==============================================================================
; These should be changed by the user. Note that the Forth memory map is a
; separate file that needs to be changed as well. They are not combined
; into one definition file so it is easier to move Forth to a different system
; with its own kernel.

.alias k_ramend $7FFF   ; End of continuous RAM that starts at $0000
                        ; redefined by Forth 

; -----------------------------------------------------------------------------
; CHIP ADDRESSES 
; -----------------------------------------------------------------------------
; Change these for target system

; 6551 ACIA UART
.alias ACIA1base $7F70          ; ACIA base address
.alias ACIA1dat  ACIA1base+0    ; ACIA control register
.alias ACIA1sta  ACIA1base+1    ; ACIA status register
.alias ACIA1cmd  ACIA1base+2    ; ACIA transmit buffer 
.alias ACIA1ctl  ACIA1base+3    ; ACIA receive buffer

; 65c22 VIA 1 I/O Chip
.alias VIA1base  $7F50          ; VIA1 base address
.alias VIA1orb   VIA1base+0     ; Output register for Port B
.alias VIA1ora   VIA1base+1     ; Output register for Port A with handshake
.alias VIA1ddrb  VIA1base+2     ; Data direction register B
.alias VIA1ddra  VIA1base+3     ; Data direction register A
.alias VIA1rt1l  VIA1base+4     ; Read Timer 1 Counter lo-order byte
.alias VIA1rt1h  VIA1base+5     ; Read Timer 1 Counter hi-order byte
.alias VIA1at1l  VIA1base+6     ; Access Timer 1 Counter lo-order byte
.alias VIA1at1h  VIA1base+7     ; Access Timer 1 Counter hi-order byte
.alias VIA1rt2l  VIA1base+8     ; Read Timer 2 Counter lo-order byte
.alias VIA1rt2h  VIA1base+9     ; Read Timer 2 Counter hi-order byte
.alias VIA1ser   VIA1base+$A    ; Serial I/O shirt register
.alias VIA1acr   VIA1base+$B    ; Auxiliary Control Register
.alias VIA1pcr   VIA1base+$C    ; Peripheral control register
.alias VIA1ifr   VIA1base+$D    ; Interrupt flag register
.alias VIA1ier   VIA1base+$E    ; Interrupt enable register
.alias VIA1orah  VIA1base+$F    ; Output register for Port A without handshake

; 65c22 VIA 2 I/O Chip
.alias VIA2base  $7F60          ; VIA2 base address
.alias VIA2orb   VIA2base+0     ; Output register for Port B
.alias VIA2ora   VIA2base+1     ; Output register for Port A with handshake
.alias VIA2ddrb  VIA2base+2     ; Data direction register B
.alias VIA2ddra  VIA2base+3     ; Data direction register A
.alias VIA2rt1l  VIA2base+4     ; Read Timer 1 Counter lo-order byte
.alias VIA2rt1h  VIA2base+5     ; Read Timer 1 Counter hi-order byte
.alias VIA2at1l  VIA2base+6     ; Access Timer 1 Counter lo-order byte
.alias VIA2at1h  VIA2base+7     ; Access Timer 1 Counter hi-order byte
.alias VIA2rt2l  VIA2base+8     ; Read Timer 2 Counter lo-order byte
.alias VIA2rt2h  VIA2base+9     ; Read Timer 2 Counter hi-order byte
.alias VIA2ser   VIA2base+$A    ; Serial I/O shirt register
.alias VIA2acr   VIA2base+$B    ; Auxiliary Control Register
.alias VIA2pcr   VIA2base+$C    ; Peripheral control register
.alias VIA2ifr   VIA2base+$D    ; Interrupt flag register
.alias VIA2ier   VIA2base+$E    ; Interrupt enable register
.alias VIA2orah  VIA2base+$F    ; Output register for Port A without handshake

; -----------------------------------------------------------------------------
; Zero Page Defines
; -----------------------------------------------------------------------------
; $D0 to $EF are used by the kernel for booting, Packrat doesn't touch them

.alias k_com1_l $D0 ; lo byte for general kernel communication, first word
.alias k_com1_h $D1 ; hi byte for general kernel communication 
.alias k_com2_l $D2 ; lo byte for general kernel communication, second word 
.alias k_com2_h $D3 ; hi byte for general kernel communication 
.alias k_str_l  $D4 ; lo byte of string address for print routine
.alias k_str_h  $D5 ; hi byte of string address for print routine
.alias zp0      $D6 ; General use ZP entry
.alias zp1      $D7 ; General use ZP entry
.alias zp2      $D8 ; General use ZP entry
.alias zp3      $D9 ; General use ZP entry
.alias zp4      $DA ; General use ZP entry

; =============================================================================
; INITIALIZATION
; =============================================================================
; Kernel Interrupt Handler for RESET button, also boot sequence. 
.scope
k_resetv: 
        jmp k_init65c02 ; initialize CPU

_ContPost65c02:
        jmp k_initRAM   ; initialize and clear RAM

_ContPostRAM:
        jsr k_initIO    ; initialize I/O (ACIA1, VIA1, and VIA2)

        ; Print kernel boot message
        .invoke newline
        .invoke prtline ks_welcome
        .invoke prtline ks_author   
        .invoke prtline ks_version  

        ; Turn over control to Forth
        jmp FORTH 

; -----------------------------------------------------------------------------
; Initialize 65c02. Cannot be a subroutine because we clear the stack
; pointer
k_init65c02:

        ldx #$FF        ; reset stack pointer
        txs

        lda #$00        ; clear all three registers
        tax
        tay

        pha             ; clear all flags
        plp             
        sei             ; disable interrupts

        bra _ContPost65c02   

; -----------------------------------------------------------------------------
; Initialize system RAM, clearing from RamStr to RamEnd. Cannot be a
; subroutine because the stack is cleared, too. Currently assumes that
; memory starts at $0000 and is 32 kByte or less. 
k_initRAM:
        lda #<k_ramend
        sta $00
        lda #>k_ramend  ; start clearing from the bottom
        sta $01         ; hi byte used for counter

        lda #$00
        tay 

*       sta ($00),y     ; clear a page of the ram
        dey             ; wraps to zero 
        bne - 

        dec $01         ; next hi byte value
        bpl -           ; wrapping to $FF sets the 7th bit, "negative"

        stz $00         ; clear top bytes
        stz $01         
        
        bra _ContPostRAM
.scend

; -----------------------------------------------------------------------------
; Initialize the I/O: 6850, 65c22 
k_initIO:
.scope
        lda #<_IOTable          ; save start address of table
        sta k_com1_l
        lda #>_IOTable          
        sta k_com1_h

        ; Change next value for different hardware
        ldx #$06                ; number of ports to initialize, ends when zero

_loop:
        ldy #$00                ; clear index
        
        lda (k_com1_l),y        ; get low and hi byte of register address
        sta k_com2_l
        iny 
        lda (k_com1_l),y        
        sta k_com2_h
        iny

        lda (k_com1_l),y        ; get value for register
        sta (k_com2_l)          ; output to port, only 65c02

        lda k_com1_l            ; move to next array entry
        clc
        adc #$03
        sta k_com1_l
        bcc +                   ; if we carried, incease hi byte as well
        inc k_com1_h
        
*       dex                     ; loop counter
        bne _loop

        rts

_IOTable:
        ; Each entry has three bytes: Address of register (lo, hi) and 
        ; the initializing data
        ; TODO Enable interrupts

        ; -------------------------------
        ; ACIA1 6551 data (2 entries)

        .word ACIA1ctl	  ; ACIA control register, for reset and configuration
        .byte $1F         ; reset, 19.2K/8/1
        .word ACIA1cmd    ; ACIA command register, for configuration
        .byte $0B         ; N parity/echo off/rx int off/ dtr active low

        ; -------------------------------
        ; VIA1 65c22 data (4 entries)
        ; Reset makes all lines input, clears all internal registers

        .word VIA1ier    ; VIA1 Interrupt Enable Register
        .byte %01111111 ;  - disable all interrupts (automatic after reset)
        .word VIA1ddrA   ; VIA1 data dir reg Port A
        .byte $00       ;  - set all pins to input
        .word VIA1ddrB   ; VIA1 data dir reg Port B
        .byte $FF       ;  - set all pins to output
        .word VIA1pcr    ; VIA1 peripheral control register
        .byte $00       ;  - make all control lines inputs
.scend

; =============================================================================
; KERNEL FUNCTIONS AND SUBROUTINES
; =============================================================================
; These start with k_


.require "pckybd.asm"

; -----------------------------------------------------------------------------
; Kernel panic: Don't know what to do, so just reset the whole system. 
; We redirect the NMI interrupt vector here to be safe, though this 
; should never be reached. 
k_nmiv:
k_panic:
        jmp k_resetv       ; Reset the whole machine

; -----------------------------------------------------------------------------
; Get a character from the ACIA (blocking)
k_getchr:
.scope
*       lda   ACIA1Sta           ; Serial port status             
        and   #$08               ; is recvr full
        beq   -                  ; no char to get
        lda   ACIA1dat           ; get chr
        rts
.scend

;
; non-waiting get character routine 
;
k_getchr_async:
.scope
        clc
        lda   ACIA1Sta           ; Serial port status
        and   #$08               ; mask rcvr full bit
        beq   +
        lda   ACIA1dat           ; get chr
        sec
*       rts
.scend

; -----------------------------------------------------------------------------
; Write a character to the ACIA. Assumes character is in A. Because this is
; "write" command, there is no line feed at the end
k_wrtchr: 
.scope
        pha                     ; save the character to print
*       lda   ACIA1Sta          ; serial port status
        and   #$10              ; is tx buffer empty
        beq   -                 ; no
        pla                     ; get chr
        sta   ACIA1dat          ; put character to Port
        rts                     ; done
.scend

; -----------------------------------------------------------------------------
; Write a string to the ACIA. Assumes string address is in k_str. 
; If we come here from k_prtstr, we add a line feed
.scope
k_wrtstr:
        stz zp0                 ; flag: don't add line feed
        bra +

k_prtstr:
        lda #$01                ; flag: add line feed
        sta zp0   

*       phy                     ; save Y register
        ldy #$00                ; index

*       lda (k_str_l),y         ; get the string via address from zero page
        beq _done               ; if it is a zero, we quit and leave
        jsr k_wrtchr            ; if not, write one character
        iny                     ; get the next byte
        bra -              

_done:
        lda zp0                 ; if this is a print command, add linefeed
        beq _leave
        .invoke newline

_leave: 
        ply                     
        rts

.scend
; -----------------------------------------------------------------------------
; Write characters to the VIA1 ports. TODO code these. 

.scope
k_getchrVIA1a:
        nop
        rts

k_getchrVIA1b:
        nop
        rts

k_wrtchrVIA1a:
        nop
        rts

k_wrtchrVIA1b:
        nop
        rts
.scend

; =============================================================================
; KERNEL STRINGS
; =============================================================================
; Strings beginn with ks_ and are terminated by 0

; General OS strings
ks_welcome: .byte "Booting Kernel for the Uberquirrel Mark Zero",0
ks_author:  .byte "Scot W. Stevenson <scot.stevenson@gmail.com>",0
ks_version: .byte "Kernel Version Alpha 004 (11. Feb 2015)",0

; =============================================================================
; END
