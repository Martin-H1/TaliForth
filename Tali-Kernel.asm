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

; SIMULATOR LINES MARKED WITH "+PY65+", CHANGE THESE FOR PRODUCTION

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
; Definitions for the py65mon emulator TODO comment for final code
; -----------------------------------------------------------------------------
; Note these are in a really, really bad place because they are easily 
; overwritten if our code reaches from $e000 into $f000
.alias py65_putc    $f001
.alias py65_getc    $f004
; .alias py65_blkgetc $f005       ; TODO Removed in new versions of py65

; -----------------------------------------------------------------------------
; CHIP ADDRESSES 
; -----------------------------------------------------------------------------
; Change these for target system

; 6551 ACIA UART
.alias ACIA1base $7F70          ; ACIA base address
.alias ACIA1dat  ACIA1base+0     ; ACIA control register
.alias ACIA1sta  ACIA1base+1     ; ACIA status register
.alias ACIA1cmd  ACIA1base+2     ; ACIA transmit buffer 
.alias ACIA1ctl  ACIA1base+3     ; ACIA receive buffer

; 65c22 VIA I/O Chip
.alias VIAbase  $7F60           ; VIA base address
.alias VIAorb   VIAbase+0       ; Output register for Port B
.alias VIAora   VIAbase+1       ; Output register for Port A with handshake
.alias VIAddrb  VIAbase+2       ; Data direction register B
.alias VIAddra  VIAbase+3       ; Data direction register A
.alias VIArt1l  VIAbase+4       ; Read Timer 1 Counter lo-order byte
.alias VIArt1h  VIAbase+5       ; Read Timer 1 Counter hi-order byte
.alias VIAat1l  VIAbase+6       ; Access Timer 1 Counter lo-order byte
.alias VIAat1h  VIAbase+7       ; Access Timer 1 Counter hi-order byte
.alias VIArt2l  VIAbase+8       ; Read Timer 2 Counter lo-order byte
.alias VIArt2h  VIAbase+9       ; Read Timer 2 Counter hi-order byte
.alias VIAser   VIAbase+$A      ; Serial I/O shirt register
.alias VIAacr   VIAbase+$B      ; Auxiliary Control Register
.alias VIApcr   VIAbase+$C      ; Peripheral control register
.alias VIAifr   VIAbase+$D      ; Interrupt flag register
.alias VIAier   VIAbase+$E      ; Interrupt enable register
.alias VIAorah  VIAbase+$F      ; Output register for Port A without handshake

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
        jsr k_initIO    ; initialize I/O (ACIA1, VIA)

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
        ; VIA 65c22 data (4 entries)
        ; Reset makes all lines input, clears all internal registers

        .word VIAier    ; VIA Interrupt Enable Register
        .byte %01111111 ;  - disable all interrupts (automatic after reset)
        .word VIAddrA   ; VIA data dir reg Port A
        .byte $00       ;  - set all pins to input
        .word VIAddrB   ; VIA data dir reg Port B
        .byte $FF       ;  - set all pins to output
        .word VIApcr    ; VIA peripheral control register
        .byte $00       ;  - make all control lines inputs
.scend

; =============================================================================
; KERNEL FUNCTIONS AND SUBROUTINES
; =============================================================================
; These start with k_

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
; Write characters to the VIA ports. TODO code these. 

.scope
k_getchrVIAa:
        nop
        rts

k_getchrVIAb:
        nop
        rts

k_wrtchrVIAa:
        nop
        rts

k_wrtchrVIAb:
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
