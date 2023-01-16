	section .data

arrofst: equ	0x0a
midline: equ	0xafc8
endline: equ	1800
;		| ASCII char | pattern |
;		| 15 ... 9   | 8 ... 0 |
codelut: dw	0x6034, 0x6321, 0x6461, 0x6760, 0x6831, 0x6b30, 0x6c70, 0x6e25, 0x7124, 0x7264, \
		0x8309, 0x8449, 0x8748, 0x8819, 0x8b18, 0x8c58, 0x8e0d, 0x910c, 0x924c, 0x941c, \
		0x9703, 0x9843, 0x9b42, 0x9c13, 0x9f12, 0xa052, 0xa207, 0xa506, 0xa646, 0xa816, \
		0xab81, 0xacc1, 0xafc0, 0xb091, 0xb390, 0xb4d0, 0x5a85, 0x5d84, 0x40c4, 0x48a8, \
		0x5ea2, 0x568a, 0x4a2a, 0x5494, 0x0000

	section .text

	GLOBAL readcode

readcode:
;	preamble
	push		rbp
	mov		rbp, rsp
	push		rbx
;	find middle line
	add		rdi, arrofst
	movzx		rdx, WORD [rdi]
	sub		rdi, arrofst
	add		rdi, rdx
	add		rdi, midline
;	find middle line end
	mov		rdx, rdi
	add		rdx, endline
;	rbp - 16: line end address
	push		rdx
;	rbp - 24: thin bar width
	push		0
;	rbp - 32: checksum
	push		0
;	rbp - 40: last index
	push		0
;	find first bar
	push		rdi
	push		0xff
	call		stride
	add		sp, 16
	cmp		rax, [rbp - 16]
	jge		readcode_fail
;	measure first bar
	push		rax
	push		0x00
	call		stride
	mov		rbx, [rsp + 8]
	add		sp, 16
	cmp		rax, [rbp - 16]
	jge		readcode_fail
	sub		rax, rbx
	mov		[rbp - 24], rax
;	find start symbol
	push		rbx
	push		rax
	call		symbol
	mov		rbx, rax
	add		sp, 16
	push		rdx
	call		decode
	add		sp, 8
	cmp		rax, 42
	jne		readcode_fail

	mov		rdi, rsi
readcode_loop:
;	skip gap
	push		rbx
	push		0xff
	call		stride
	add		sp, 16
	cmp		rax, [rbp - 16]
	ja		readcode_fail
;	read symbol
	push		rax
	push		QWORD [rbp - 24]
	call		symbol
	cmp		rax, 0
	jb		readcode_fail
	mov		rbx, rax
	add		sp, 16
	push		rdx
	call		decode
	add		sp, 8
;	exit at stop symbol
	cmp		rax, 42
	je		readcode_checksum
	mov		BYTE [rdi], al
	add		[rbp - 32], rdx
	mov		[rbp - 40], rdx
	inc		rdi
	jmp		readcode_loop

readcode_checksum:
	mov		rax, [rbp - 32]
	sub		rax, [rbp - 40]
	mov		rbx, 43
	div		bl
;	check for match
	shr		rax, 8
	cmp		rax, [rbp - 40]
	jne		readcode_fail
;	remove check symbol
	mov		BYTE [rdi - 1], 0
	xor		rax, rax
	jmp		readcode_ret
readcode_fail:
	mov		rax, -1
readcode_ret:
;	clean locals from stack
	add		sp, 32
;	epilogue
	pop		rbx
	pop		rbp
	ret


;==========================================================
; DESCRIPTION:
;	moves through bitmap until a different color found
; ARGUMENTS:
;	1 - starting color
;	2 - starting address
; RETURNS:
;	stop address
stride:
	push		rbp
	mov		rbp, rsp
	push		rcx

	movzx		rcx, BYTE [rbp + 16]
	mov		rax, [rbp + 24]
stride_loop:
	movzx		rdx, BYTE [rax]
	cmp		rdx, rcx
	jne		stride_ret
	add		rax, 3
	jmp		stride_loop
stride_ret:
	pop		rcx
	pop		rbp
	ret


;==========================================================
; DESCRIPTION:
;	reads a single code39 symbol
; ARGUMENTS:
;	1 - thin bar width
;	2 - starting address
; RETURNS:
;	rax - stop address or -1
;	rdx - symbol pattern
symbol:
	push		rbp
	mov		rbp, rsp
	push		rbx
	push		rsi
	push		rdi

;	threshold values
	mov		rdx, [rbp + 16]
	shl		rdx, 1
	push		rdx
	shl		rdx, 1
	push		rdx

	mov		rcx, 9
	mov		rax, [rbp + 24]
	xor		rdi, rdi
symbol_loop:
	push		rax
	movzx		rdx, BYTE [rax]
	push		rdx
	call		stride
	mov		rbx, rax
	mov		rdx, [rsp + 8]
	add		sp, 16

	sub		rbx, rdx
;	check size bounds
	cmp		rbx, [rbp + 16]
	jb		symbol_fail
	cmp		rbx, [rbp - 40]
	jge		symbol_fail
;	store bit
	cmp		rbx, [rbp - 32]
	jb		symbol_next
	or		rdi, 1
symbol_next:
	dec		rcx
	cmp		rcx, 0
	jz		symbol_ret
	shl		rdi, 1
	jmp		symbol_loop
symbol_fail:
	mov		rax, -1
symbol_ret:
	mov		rdx, rdi
	add		sp, 16
	pop		rdi
	pop		rsi
	pop		rbx
	pop		rbp
	ret


;==========================================================
; DESCRIPTION:
;	decodes a symbol pattern to ascii
; ARGUMENTS:
;	1 - bit pattern
; RETURNS:
;	rax - ascii char or 0 if failed
;	rdx - char index
decode:
	push		rbp
	mov		rbp, rsp
	push		rsi
	push		rdi

	lea		rsi, codelut
	mov		rdi, rsi
decode_search:
	movzx		rax, WORD [rdi]
	mov		rdx, rax
	shr		rdx, 9
	cmp		rax, 0
	jz		decode_ret
	and		rax, 0x1ff
	cmp		rax, [rbp + 16]
	je		decode_ret
	add		rdi, 2
	jmp		decode_search
decode_ret:
	mov		rax, rdx
	mov		rdx, rdi
	sub		rdx, rsi
	shr		rdx, 1

	pop		rdi
	pop		rsi
	pop		rbp
	ret
