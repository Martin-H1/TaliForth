; The 6502 is a pure eight bit processor and math beyond eight bits
; requires helper functions. This module creates macros which use the
; data stack like an RPN calculator or Forth to pass inputs and outputs.

; adds two 16 bit quantities on the argument stack and puts the result
; on the stack.
.macro addw
	clc
	lda TOS_LSB,x
	adc NOS_LSB,x
	sta NOS_LSB,x

	lda TOS_MSB,x
	adc NOS_MSB,x
	sta NOS_MSB,x
	`drop
.macend

.macro andw
	lda TOS_LSB,x
	and NOS_LSB,x
	sta NOS_LSB,x
	lda TOS_MSB,x
	and NOS_MSB,x
	sta NOS_MSB,x
	`drop
.macend

; compares two 16 bit quantities on the argument stack to set the flag bits.
.macro comparew
	lda TOS_LSB,x
	cmp NOS_LSB,x
	beq _equal

	lda TOS_MSB,x		; low bytes are not equal, compare MSB
	sbc NOS_MSB,x
	ora #$01		; Make Zero Flag 0 because we're not equal
	bvs _overflow
	bra _notequal
_equal:				; low bytes are equal, so we compare high bytes
	lda TOS_MSB,x
	sbc NOS_MSB,x
	bvc _done
_overflow:			; handle overflow because we use signed numbers
	eor #$80		; complement negative flag

_notequal:
	ora #$01		; if overflow, we can't be equal
_done:
.macend

; determines if two 16 bit quantities are equal and pushes flag
.macro equalw
	lda TOS_LSB,x
	cmp NOS_LSB,x
	bne _false
	lda TOS_MSB,x
	cmp NOS_MSB,x
	bne _false
	lda #$FF
	bra _done
_false:
	lda #$00                ; drop through to _done
_done:
	`drop
	`loadTosAA
.macend

.macro invert
	lda #$FF
	eor TOS_LSB,x
	sta TOS_LSB,x
	lda #$FF
	eor TOS_MSB,x
	sta TOS_MSB,x
.macend

; Shift cell u bits to the left. We mask the anything except the lower
; 4 bit of u so we shift maximal of 16 bit
.macro lshift
	lda TOS_LSB,x
	and #%00001111
	beq _done         ; if it is zero, don't do anything
	tay
_while:	asl NOS_LSB,x
	rol NOS_MSB,x
	dey
	bne _while
_done:	`drop
.macend

.macro dnegate
	lda NOS_LSB,x
	eor #$FF
	clc
	adc #$01
	sta NOS_LSB,x

	lda NOS_MSB,x
	eor #$FF
	adc #$00
	sta NOS_MSB,x

	lda TOS_LSB,x
	eor #$FF
	adc #$00
	sta TOS_LSB,x

	lda TOS_MSB,x
	eor #$FF
	adc #$00
	sta TOS_MSB,x
.macend

.macro negate
	lda TOS_LSB,x
	eor #$FF        ; invert and add one
	clc
	adc #$01
	sta TOS_LSB,x
	lda TOS_MSB,x
	eor #$FF       	; invert and add any carry
	adc #$00
	sta TOS_MSB,x
.macend

.macro orw
	lda TOS_LSB,x
	ora NOS_LSB,x
	sta NOS_LSB,x
	lda TOS_MSB,x
	ora NOS_MSB,x
	sta NOS_MSB,x
	`drop
.macend

; Shift cell u bits to the right. We mask the anything except the lower
; 4 bit of u so we can maximally move 16 bit.
.macro rshift
	lda TOS_LSB,x
	and #%00001111
	beq _done         ; if it is zero, don't do anything
	tay
_while:	lsr NOS_MSB,x
	ror NOS_LSB,x
	dey
	bne _while
_done:	`drop
.macend

; subtract two 16 bit quantities on the argument stack and puts the result
; on the stack.
.macro subw
	sec
	lda NOS_LSB,x
	sbc TOS_LSB,x
	sta NOS_LSB,x

	lda NOS_MSB,x
	sbc TOS_MSB,x
	sta NOS_MSB,x
	`drop
.macend

.macro xorw
	lda TOS_LSB,x
	eor NOS_LSB,x
	sta NOS_LSB,x
	lda TOS_MSB,x
	eor NOS_MSB,x
	sta NOS_MSB,x
	`drop
.macend
