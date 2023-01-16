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
	push		ebp
	mov		ebp, esp
	push		ebx
	push		esi
	push		edi
;	find middle line
	mov		esi, DWORD [ebp + 8]
	add		esi, arrofst
	mov		edx, [esi]
	mov		esi, DWORD [ebp + 8]
	add		esi, edx
	add		esi, midline
;	save line end address
	mov		edx, esi
	add		edx, endline
	push		edx
;	persistent locals
	push		0
	push		0
	push		0
;	find first bar
	push		esi
	push		0xff
	call		stride
	add		sp, 8
	cmp		eax, [ebp - 16]
	jge		readcode_fail
;	measure first bar
	push		eax
	push		0x00
	call		stride
	mov		ebx, [esp + 4]
	add		sp, 8
	cmp		eax, [ebp - 16]
	jge		readcode_fail
	sub		eax, ebx
	mov		[ebp - 20], eax
;	find start symbol
	push		ebx
	push		eax
	call		symbol
	mov		ebx, eax
	add		sp, 8
	push		edx
	call		decode
	add		sp, 4
	cmp		eax, 42
	jne		readcode_fail

	mov		edi, DWORD [ebp + 12]
readcode_loop:
;	skip gap
	push		ebx
	push		0xff
	call		stride
	add		sp, 8
	cmp		eax, [ebp - 16]
	ja		readcode_fail
;	read symbol
	push		eax
	push		DWORD [ebp - 20]
	call		symbol
	cmp		eax, 0
	jb		readcode_fail
	mov		ebx, eax
	add		sp, 8
	push		edx
	call		decode
	add		sp, 4
;	exit at stop symbol
	cmp		eax, 42
	je		readcode_checksum
	mov		BYTE [edi], al
	add		[ebp - 24], edx
	mov		[ebp - 28], edx
	inc		edi
	jmp		readcode_loop
readcode_checksum:
	mov		eax, [ebp - 24]
	sub		eax, [ebp - 28]
	mov		ebx, 43
	div		bl
;	check for match
	shr		eax, 8
	cmp		eax, [ebp - 28]
	jne		readcode_fail
;	remove check symbol
	mov		BYTE [edi-1], 0
	xor		eax, eax
	jmp		readcode_ret
readcode_fail:
	mov		eax, -1
readcode_ret:
;	clean locals from stack
	add		sp, 16
;	epilogue
	pop		edi
	pop		esi
	pop		ebx
	pop		ebp
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
	push		ebp
	mov		ebp, esp
	push		ecx

	movzx		ecx, BYTE [ebp + 8]
	mov		eax, [ebp + 12]
stride_loop:
	movzx		edx, BYTE [eax]
	cmp		edx, ecx
	jne		stride_ret
	add		eax, 3
	jmp		stride_loop
stride_ret:
	pop		ecx
	pop		ebp
	ret


;==========================================================
; DESCRIPTION:
;	reads a single code39 symbol
; ARGUMENTS:
;	1 - thin bar width
;	2 - starting address
; RETURNS:
;	eax - stop address or -1
;	edx - symbol pattern
symbol:
	push		ebp
	mov		ebp, esp
	push		ebx
	push		esi
	push		edi

;	threshold values
	mov		edx, [ebp + 8]
	shl		edx, 1
	push		edx
	shl		edx, 1
	push		edx

	mov		ecx, 9
	mov		eax, [ebp + 12]
	xor		edi, edi
symbol_loop:
	push		eax
	movzx		edx, BYTE [eax]
	push		edx
	call		stride
	mov		ebx, eax
	mov		edx, [esp + 4]
	add		sp, 8

	sub		ebx, edx
;	check size bounds
	cmp		ebx, [ebp + 8]
	jb		symbol_fail
	cmp		ebx, [ebp - 20]
	jge		symbol_fail
;	store bit
	cmp		ebx, [ebp - 16]
	jb		symbol_next
	or		edi, 1
symbol_next:
	dec		ecx
	cmp		ecx, 0
	jz		symbol_ret
	shl		edi, 1
	jmp		symbol_loop
symbol_fail:
	mov		eax, -1
symbol_ret:
	mov		edx, edi
	add		sp, 8
	pop		edi
	pop		esi
	pop		ebx
	pop		ebp
	ret


;==========================================================
; DESCRIPTION:
;	decodes a symbol pattern to ascii
; ARGUMENTS:
;	1 - bit pattern
; RETURNS:
;	eax - ascii char or 0 if failed
;	edx - char index
decode:
	push		ebp
	mov		ebp, esp
	push		esi
	push		edi

	lea		esi, codelut
	mov		edi, esi
decode_search:
	movzx		eax, WORD [edi]
	mov		edx, eax
	shr		edx, 9
	cmp		eax, 0
	jz		decode_ret
	and		eax, 0x1ff
	cmp		eax, [ebp + 8]
	je		decode_ret
	add		edi, 2
	jmp		decode_search
decode_ret:
	mov		eax, edx
	mov		edx, edi
	sub		edx, esi
	shr		edx, 1

	pop		edi
	pop		esi
	pop		ebp
	ret
