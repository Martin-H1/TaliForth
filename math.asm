.macro andw
	lda TOS_LSB,x
	and NOS_LSB,x
	sta NOS_LSB,x
	lda TOS_MSB,x
	and NOS_MSB,x
	sta NOS_MSB,x
	`drop
.macend

.macro invert
	lda #$FF
	eor TOS_LSB,x
	sta TOS_LSB,x
	lda #$FF
	eor TOS_MSB,x
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

.macro xorw
	lda TOS_LSB,x
	eor NOS_LSB,x
	sta NOS_LSB,x
	lda TOS_MSB,x
	eor NOS_MSB,x
	sta NOS_MSB,x
	`drop
.macend
