; -----------------------------------------------------------------------------
; KERNEL 
; for the l-star and replica 1
; Martin Heermance <mheermance@gmail.com>
;
; First version  9. Dec 2016
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

.alias k_ramend $5900   ; End of continuous RAM that starts at $0000
                        ; redefined by Forth 

; -----------------------------------------------------------------------------
; CHIP ADDRESSES 
; -----------------------------------------------------------------------------
; Change these for target system


; Other Variables

.alias KBD      $D010         ;  PIA.A keyboard input
.alias KBDCR    $D011         ;  PIA.A keyboard control register
.alias DSP      $D012         ;  PIA.B display output register
.alias DSPCR    $D013         ;  PIA.B display control register

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
	rts
                LDY #$7F        ; Mask for DSP data direction register.
                STY DSP         ; Set it up.
                LDA #$A7        ; KBD and DSP control register mask.
                STA KBDCR       ; Enable interrupts, set CA1, CB1, for
                STA DSPCR       ; positive edge sense/output mode.
        rts

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
; The PS/2 keyboard and video together are the console.
.scope
k_getchrConsole:
*
        lda KBDCR               ; Key ready?
        bpl -                   ; Loop until ready.
        lda KBD                 ; Load character.
	and #$7F                ; clear B7 which is an Apple 1 thing.
	rts

k_wrtchrConsole:
        bit DSP                 ; bit (B7) cleared yet?
        bmi k_wrtchrConsole     ; No, wait for display.
        sta DSP                 ; Output character. Sets DA.
        rts

; -----------------------------------------------------------------------------
; Write a string to the console. Assumes string address is in k_str. 
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
        jsr k_wrtchrConsole     ; if not, write one character
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
; Get a character from the ACIA (blocking)
k_getchrACIA:
.scope
        rts
.scend

;
; non-waiting get character routine 
;
k_getchr_asyncACIA:
.scope
        rts
.scend

; -----------------------------------------------------------------------------
; Write a character to the ACIA. Assumes character is in A. Because this is
; "write" command, there is no line feed at the end
k_wrtchrACIA:
.scope
        rts                     ; done
.scend

; -----------------------------------------------------------------------------
; The IEC port is a byte oriented input/output device.
k_getchrIEC:
        nop
        rts

k_wrtchrIEC:
        nop
        rts
.scend

; =============================================================================
; KERNEL STRINGS
; =============================================================================
; Strings beginn with ks_ and are terminated by 0

; General OS strings
ks_welcome: .byte "Booting Kernel for the L-Star/Replica1",0
ks_author:  .byte "Scot W. Stevenson <scot.stevenson@gmail.com>",0
ks_version: .byte "Kernel Version Alpha 001 (10. Dec 2016)",0

; =============================================================================
; END
