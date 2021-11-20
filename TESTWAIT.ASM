;=========================================================================
; testwait.asm - measure the number of wait cycles on 8088/8086/V20 CPU
;
; Distributed under the terms of the GNU General Public License
; Copyright (c) 2021 Sergey Kiselev
;-------------------------------------------------------------------------

TITLE TESTWAIT
JUMPS
.model small

;=========================================================================
; constants
;-------------------------------------------------------------------------
test_size	equ	400h		; run this number of data transfers
v20_lodsb_cycl	equ	9		; REP LODSB takes 9 cycles on NEC V20
i88_lodsb_cycl	equ	13		; REP LODSB takes 13 cycles on i8088
v20_insb_cycl	equ	8		; REP INSB takes 8 cycles on NEC V20
i88_insb_cycl	equ	28		; IN AL,DX; LOOP sequence on i8088

;=========================================================================
; allocate stack
;-------------------------------------------------------------------------
.stack	100h

;=========================================================================
; data starts here
;-------------------------------------------------------------------------
.data

msg_banner	db	"TESTWAIT - Measure memory and I/O wait states"
		db	0Dh, 0Ah
		db	"Version 1.0. Copyright (C) Sergey Kiselev", 0Dh, 0Ah
		db	"Distributed under the terms of "
		db	"the GNU General Public License", 0Dh, 0Ah, 00h
msg_cpu_v20	db	"CPU Type: NEC V20/V30", 0Dh, 0Ah, 00h
msg_cpu_i88	db	"CPU Type: Intel 8088/8086", 0Dh, 0Ah, 00h
msg_no_cpu	db	"ERROR: This program only supports Intel 8088/8086 "
		db	"and NEC V20/V30 CPUs", 0Dh, 0Ah, 00h
msg_run_tests	db	"Tests (MainMem, VideoMem, BIOS, OnboardIO, BusIO): ", 00h
msg_clk_period	db	"CPU Clock period: ", 00h
msg_ns_ibm	db	" ns [209 ns on an IBM PC/XT running at 4.77 MHz]"
		db	0Dh, 0Ah, 00h
msg_vid_memr	db	"Video memory read wait states:  ", 00h
msg_bios_memr	db	"BIOS ROM read wait states:      ", 00h
msg_board_ior	db	"On-board I/O read wait states:  ", 00h
msg_com1_ior	db	"COM1 MSR I/O read wait states:  ", 00h
msg_coma	db	", ", 00h
msg_cr_lf	db	0Dh, 0Ah, 00h
main_memr_time	dw	?
vid_memr_ws	dw	?
bios_memr_ws	dw	?
board_ior_ws	dw	?
com1_ior_ws	dw	?
cpu_has_insb	db	?
lodsb_cycles	dw	?
insb_cycles	dw	?
test_area	db	test_size dup (?)

;=========================================================================
; code starts here
;-------------------------------------------------------------------------
.code
.8086            			; the code should run on 8088/V20

start:		mov	ax,@data
		mov	ds,ax		; initialize DS to data segment
		mov	es,ax		; initialize ES to data segment
		mov	si,offset msg_banner
		call	print

; check if we are running on NEC V20 (or NEC V30)
		mov	si,offset msg_cpu_v20
		mov	ax,0101h
		aad	10h
		cmp	al,0Bh
		je	nec_v20

; check if we are running on 8088 (or 8086)
		mov	si,offset msg_cpu_i88
		pushf
		pop	ax
		and	ax,0FFFh	; try to clear upper 4-bits of FLAGS
		push 	ax
		popf
		pushf
		pop	ax
		and	ax,0F000h	; keep upper 4-bits of FLAGS
		cmp	ax,0F000h
		je	intel_8088
		mov	si,offset msg_no_cpu
		call	print
		mov	al,01h		; failure - unsupported CPU
		jmp	exit
intel_8088:
		mov	byte ptr [cpu_has_insb],0
		mov	word ptr [lodsb_cycles],i88_lodsb_cycl
		mov	word ptr [insb_cycles],i88_insb_cycl
		jmp	print_cpu
nec_v20:
		mov	byte ptr [cpu_has_insb],1
		mov	word ptr [lodsb_cycles],v20_lodsb_cycl
		mov	word ptr [insb_cycles],v20_insb_cycl
print_cpu:
		call	print		; print CPU type
; run the measurements
		mov	si,offset msg_run_tests
		call	print
; measure main memory read speed
		mov	si,offset test_area
		call	test_mem_read	; measure memory read speed
		call	print_dec
		mov	si,offset msg_coma
		call	print
		mov	dx,0
		mov	cx,word ptr [lodsb_cycles]
		div	cx
		dec	ax		; dec by 1 to avoid rounding errors
		mov	word ptr [main_memr_time],ax
		call	print_dec
		mov	si,offset msg_coma
		call	print
; measure video memory read speed
		push	ds
		mov	ah,0Fh		; Int 10 function 0Fh - get video mode
		int	10h
		cmp	al,0Dh
		jae	ega_mem
		cmp	al,07h
		je	mda_mem
		mov	ax,0B800h	; CGA video memory segment
		jmp	test_video

mda_mem:
		mov	ax,0B000h	; MDA/HGC video memory segment
		jmp	test_video

ega_mem:
		mov	ax,0A000h	; EGA/VGA video memory segment
		jmp	test_video

test_video:
		mov	ds,ax
		mov	si,0000h
		call	test_mem_read	; measure memory read speed
		pop	ds
		call	print_dec
		mov	si,offset msg_coma
		call	print
		xor	dx,dx
		mov	cx,word ptr [main_memr_time]
		div	cx
		sub	ax,word ptr [lodsb_cycles]
		mov	word ptr [vid_memr_ws],ax
; measure BIOS ROM read speed
		push	ds
		mov	ax,0FC00h
		mov	ds,ax
		mov	si,0000h
		call	test_mem_read	; measure memory read speed
		pop	ds
		call	print_dec
		mov	si,offset msg_coma
		call	print
		xor	dx,dx
		mov	cx,word ptr [main_memr_time]
		div	cx
		sub	ax,word ptr [lodsb_cycles]
		mov	word ptr [bios_memr_ws],ax
; measure on-board I/O read speed
		mov	dx,61h		; use PORT B as the source
		mov	di,offset test_area
		call	test_io_read	; measure I/O read speed
		call	print_dec
		mov	si,offset msg_coma
		call	print
		xor	dx,dx
		mov	cx,word ptr [main_memr_time]
		div	cx
		sub	ax,word ptr [insb_cycles]
		mov	word ptr [board_ior_ws],ax
; measure COM1 MSR I/O read speed
		mov	dx,3F8h+6	; COM1 MSR
		mov	di,offset test_area
		call	test_io_read	; measure I/O read speed
		call	print_dec
		mov	si,offset msg_cr_lf
		call	print
		xor	dx,dx
		mov	cx,word ptr [main_memr_time]
		div	cx
		sub	ax,word ptr [insb_cycles]
		mov	word ptr [com1_ior_ws],ax
; print the results
;		mov	al,03h		; turn off turbo
;		out	63h,al		; write chipset control register
		mov	si,offset msg_clk_period
		call	print
		mov	cx,209		; period on 4.77 MHz machine
		mov	ax,word ptr [main_memr_time]
		inc	ax		; increment back to the original value
		mul	cx
		mov	cx,test_size/4	; timer ticks for test_size CPU cycles
					; on 4.77 MHz machine
		div	cx
		call	print_dec
		mov	si,offset msg_ns_ibm
		call	print
		mov	si,offset msg_vid_memr
		call	print
		mov	ax,word ptr [vid_memr_ws]
		call	print_dec
		mov	si,offset msg_cr_lf
		call	print
		mov	si,offset msg_bios_memr
		call	print
		mov	ax,word ptr [bios_memr_ws]
		call	print_dec
		mov	si,offset msg_cr_lf
		call	print
		mov	si,offset msg_board_ior
		call	print
		mov	ax,word ptr [board_ior_ws]
		call	print_dec
		mov	si,offset msg_cr_lf
		call	print
		mov	si,offset msg_com1_ior
		call	print
		mov	ax,word ptr [com1_ior_ws]
		call	print_dec
		mov	si,offset msg_cr_lf
		call	print
; done
		mov	al,00h		; success
exit:
		mov	ah,4ch	; terminate program
		int	21h

;=========================================================================
; print_dec - print 16-bit number in decimal
; Input:
;	AX - number to print
; Output:
;	none
;-------------------------------------------------------------------------
print_dec	proc
		push	ax
		push	cx
		push	dx
		mov	cx,10		; base = 10
		call	print_rec
		pop	dx
		pop	cx
		pop	ax
		ret

print_rec:
		push	dx
		xor	dx,dx
		div	cx
		cmp	ax,0
		je	print_below10
		call	print_rec
print_below10:
		mov	ax,dx
		call	print_digit
		pop	dx
		ret
print_dec	endp

;=========================================================================
; print_digit - print hexadecimal digit
; Input:
;	AL - bits 3...0 - digit to print (0...F)
; Output:
;	none
;-------------------------------------------------------------------------
print_digit	proc
		push	ax
		push	bx
		and	al,0Fh
		add	al,'0'		; convert to ASCII
		cmp	al,'9'		; less or equal to 9?
		jna	print_digit_1
		add	al,'A'-'9'-1	; a hex digit
print_digit_1:
		mov	ah,0Eh		; Int 10 function 0Eh - teletype output
		mov	bl,07h		; just in case we're is graphic mode
		int	10h
		pop	bx
		pop	ax
		ret
print_digit	endp

;=========================================================================
; print - print ASCIIZ string to the console
; Input:
;	DS:SI - pointer to string to print
; Output:
;	none
;-------------------------------------------------------------------------
print		proc
		pushf
		push	ax
		push	bx
		push	si
		cld
print_loop:
		lodsb
		or	al,al
		jz	print_exit
		mov	ah,0Eh
		mov	bl,07h
		int	10h
		jmp	print_loop
print_exit:
		pop	si
		pop	bx
		pop	ax
		popf
		ret
print		endp

;=========================================================================
; test_mem_read - measure memory read speed
; Input:
; 	DS:SI - available memory for memory reads
; Output:
;	AX - number of timer ticks
;-------------------------------------------------------------------------
test_mem_read	proc
		push	cx
		push	si
		mov	cx,test_size
		cli
		cld
		in	al,61h
		mov	ah,al		; save PORT B to AH
		and	al,0FEh		; disable 8254 PIT channel 2 GATE
		out	61h,al		; write to PORT B
		mov	al,0B8h		; set PIT channel 2 to mode 4
		out	43h,al		; write control word to PIT
		mov	al,0FFh		; set PIT channel 2 count to 0FFFFh
		out	42h,al		; write LSB to PIT channel 2
		out	42h,al		; write MSB to PIT channel 2
		mov	al,ah
		or	al,01h		; enable PIT channel 2 - start counting
		out	61h,al		; write to PORT B
	rep	lodsb			; run memory reads
		mov	al,ah
		and	al,0FEh		; disable PIT channel 2 - stop counting
		out	61h,al
		in	al,42h		; read LSB from PIT channel 2
		mov	cl,al
		in	al,42h		; read MSB from PIT channel 2
		mov	ch,al
		sti			; re-enable interrupts
		mov	ax,0FFFFh
		sub	ax,cx
		pop	si
		pop	cx
		ret
test_mem_read	endp

;=========================================================================
; test_io_read - measure I/O read speed
; Input:
; 	DX	- register to read
;	ES:DI	- available memory to store the read data to
; Output:
;	AX	- number of timer ticks
;-------------------------------------------------------------------------
test_io_read	proc
		push	cx
		push	di
		mov	cx,test_size
		cli
		cld
		in	al,61h
		mov	ah,al		; save PORT B to AH
		and	al,0FEh		; disable 8254 PIT channel 2 GATE
		out	61h,al		; write to PORT B
		mov	al,0B8h		; set PIT channel 2 to mode 4
		out	43h,al		; write control word to PIT
		mov	al,0FFh		; set PIT channel 2 count to 0FFFFh
		out	42h,al		; write LSB to PIT channel 2
		out	42h,al		; write MSB to PIT channel 2
		mov	al,ah
		or	al,01h		; enable PIT channel 2 - start counting
		out	61h,al		; write to PORT B
		cmp	byte ptr [cpu_has_insb],0
		jz	test_ior_8088
.186					; INSB is only available in V20/186+
	rep	insb			; run I/O reads
		jmp	test_ior_done
test_ior_8088:
		in	al,dx
		loop	test_ior_8088
.8086
test_ior_done:
		mov	al,ah
		and	al,0FEh		; disable PIT channel 2 - stop counting
		out	61h,al
		in	al,42h		; read LSB from PIT channel 2
		mov	cl,al
		in	al,42h		; read MSB from PIT channel 2
		mov	ch,al
		sti			; re-enable interrupts
		mov	ax,0FFFFh
		sub	ax,cx
		pop	di
		pop	cx
		ret
test_io_read	endp

		end	start