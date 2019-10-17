.macro andw
	lda TOS_LSB,x
	and NOS_LSB,x
	sta NOS_LSB,x
	lda TOS_MSB,x
	and NOS_MSB,x
	sta NOS_MSB,x
	`drop
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
