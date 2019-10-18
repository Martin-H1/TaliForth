; The origin of this code is Scot W. Stevenson's <scot.stevenson@gmail.com>
; Tali Forth for the 65C02. His ideas were sound, but his code was inline
; and lacked abstraction or resuability.
;
; My goal with these macros is to implement the stack abstract data type to
; make Tali Forth more readable, and create a resuable stack library. Most
; operations align with the classic data structure, but with the addition of
; methods to push to top of stack from different sources (e.g. accumulator,
; RAM, and return stack), and direct access to TOS and NOS for efficiency.
;
; The argument stack is the first half of zero page. It starts at $7F and
; grows downward towards $00 (128 bytes --> 64 words). This allows for
; over and underlow detection via highest bit being zero. It also reserves
; half of zero page for direct addressing.

.alias SPMAX    $00     ; top of parameter (data) stack
.alias SP0      $7F     ; bottom of parameter (data) stack

; offset from X register for NOS and TOS.
.alias TOS_LSB	$01
.alias TOS_MSB	$02
.alias NOS_LSB	$03
.alias NOS_MSB	$04
.alias THS_LSB	$05
.alias THS_MSB	$06

.macro decw
        lda _1
        bne _over
        dec _1+1
_over:  dec _1
.macend

.macro incw
        inc _1
        bne _over
        inc _1+1
_over:
.macend

; make room on the argument stack.
.macro advance
        dex
	dex
.macend

; drops a word from the stack
.macro drop
        inx
	inx
.macend

; check for tos equals zero.
.macro toszero?
	lda TOS_LSB, x
	ora TOS_MSB, x
.macend

; loads TOS with the word at location provided
.macro loadtos
	lda _1
	sta TOS_LSB,x
	lda _1+1
	sta TOS_MSB,x
.macend

; loads TOS with the immediate value
.macro loadtosi
        lda #<_1		; LSB
        sta TOS_LSB,x
        lda #>_1		; MSB
        sta TOS_MSB,x
.macend

;  loads the value by dereferencing the pointer at the argument.
.macro loadtosind
	lda (_1)
	sta TOS_LSB,x
	`incw _1
	lda (_1)
	sta TOS_MSB,x
.macend

; loads TOS with the accumulator padded with zeros.
.macro loadtosa
	sta TOS_LSB,x
	stz TOS_MSB,x
.macend

; loads TOS MSB and LSB with the accumulator.
.macro loadtosaa
	sta TOS_LSB,x
	sta TOS_MSB,x
.macend

; loads TOS with true (-1)
.macro loadtostrue
	lda #$FF
	sta TOS_LSB,x
	sta TOS_MSB,x
.macend

; makes the TOS zero
.macro loadtoszero
	stz TOS_LSB, x
	stz TOS_MSB, x
.macend

; decrements the TOS value
.macro dectos
	lda TOS_LSB,x
	bne _over
	dec TOS_MSB,x
_over:	dec TOS_LSB,x
.macend

; increments the TOS value
.macro inctos
        inc TOS_LSB,x
        bne _over
        inc TOS_MSB,x
_over:
.macend

; Nondestructively saves the word at TOS to the location provided.
.macro peek
	lda TOS_LSB,x
	sta _1
	lda TOS_MSB,x
	sta _1+1
.macend

; Destructively saves the word at TOS to the location provided.
.macro pop
	`peek _1
	`drop
.macend

; pushes the immediate literal provided as the argument
.macro pushi
        `advance
        `loadtosi _1
.macend

; pushes the value in the accumulator onto stack and zero extends it.
.macro pusha
        `advance
        `loadtosa
.macend

; pushes the value at the address specified at the argument.
.macro pushv
        `advance
	`loadtos _1
.macend

;  pushes the value by dereferencing the pointer at the argument.
.macro pushind
        `advance
        `loadtosind _1
.macend

; pushes true onto the stack
.macro pushtrue
	`advance
	`loadtostrue
.macend

; pushes zero onto the stack
.macro pushzero
	`advance
	`loadtoszero
.macend

; nondestructively saves the word at NOS to the location provided.
.macro peeknos
	lda NOS_LSB,x
	sta _1
	lda NOS_MSB,x
	sta _1+1
.macend

; increments the NOS value
.macro incnos
        inc NOS_LSB,x
        bne _over
        inc NOS_MSB,x
_over:
.macend

; loads the word at location provided to NOS
.macro loadnos
	lda _1
	sta NOS_LSB,x
	lda _1+1
	sta NOS_MSB,x
.macend

; loads the value in the accumulator to NOS and zero extends it.
.macro loadnosa
	sta NOS_LSB,x
	stz NOS_MSB,x
.macend

; loads the NOS with the value in TOS.
.macro loadNosFromTos
	lda TOS_LSB,x
	sta NOS_LSB,x
	lda TOS_MSB,x
	sta NOS_MSB,x
.macend

; duplicates the value at TOS on the stack.
.macro dup
        `advance
        lda NOS_LSB,x		; copy the word.
        sta TOS_LSB,x
        lda NOS_MSB,x
        sta TOS_MSB,x
.macend

; fetch dereferences the current TOS and replaces the value on TOS.
.macro fetch
        `peek _1
        `loadtosind _1
.macend

; deletes NOS on the stack.
.macro nip
	`loadNosFromTos
	`drop
.macend

; allocates a cell and stores the value in THS to TOS
.macro over
	`advance
	lda THS_LSB,x
	sta TOS_LSB,x
	lda THS_MSB,x
	sta TOS_MSB,x
.macend

; Rotate the top three entries upwards
.macro mrot
	lda TOS_MSB,x
	pha
	lda NOS_MSB,x
	sta TOS_MSB,x
	lda THS_MSB,x
	sta NOS_MSB,x
	pla
	sta THS_MSB,x

	lda TOS_LSB,x
	pha
	lda NOS_LSB,x
	sta TOS_LSB,x
	lda THS_LSB,x
	sta NOS_LSB,x
	pla
	sta THS_LSB,x
.macend

; Rotate the top three entries downwards
.macro rot
	lda THS_MSB,x
	pha
	lda NOS_MSB,x
	sta THS_MSB,x
	lda TOS_MSB,x
	sta NOS_MSB,x
	pla
	sta TOS_MSB,x

	lda THS_LSB,x
	pha
	lda NOS_LSB,x
	sta THS_LSB,x
	lda TOS_LSB,x
	sta NOS_LSB,x
	pla
	sta TOS_LSB,x
.macend

; stores the value in NOS at the address specified in TOS and drops
; the values from the stack.
.macro store
        lda NOS_LSB,x		; LSB
        sta (TOS_LSB,x)
	`inctos
	lda NOS_MSB,x		; MSB
        sta (TOS_LSB,x)

	`drop
	`drop
.macend

; swaps top of stack (TOS) to next on stack (NOS)
.macro swap
        lda NOS_LSB,x		; LSB of both words first
        pha			; use stack as a temporary
        lda TOS_LSB,x
        sta NOS_LSB,x
        pla
        sta TOS_LSB,x

        lda NOS_MSB,x		; MSB next
        pha
        lda TOS_MSB,x
        sta NOS_MSB,x
        pla
        sta TOS_MSB,x
.macend

;
; This set of macros manipulates the return stack.
;

; Moves TOS cell from the data stack to return stack.
.macro peekToR
	lda TOS_MSB,x
	pha
	lda TOS_LSB,x
	pha
.macend

; Moves NOS cell from the data stack to return stack.
.macro peekNosToR
	lda NOS_MSB,x
	pha
	lda NOS_LSB,x
	pha
.macend

; Moves a cell from return stack to memeory.
.macro popFromR
	pla
	sta _1
	pla
	sta _1+1
.macend

; Moves a cell from the data stack to return stack.
.macro popToR
	lda TOS_MSB,x
	pha
	lda TOS_LSB,x
	pha
	`drop
.macend

; Moves a cell from return stack to data stack.
.macro pushFromR
	`advance
	pla
	sta TOS_LSB,x
	pla
	sta TOS_MSB,x
.macend

; Moves a cell from memory to return stack.
.macro pushToR
	lda _1+1
	pha
	lda _1
	pha
.macend
