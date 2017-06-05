.model small
.data 
.stack 100h
file_path db 120 dup('$')
program_segment dw 0
fd dw -1
usageMsg db "Usage: lab8 [file_to_print] [printscr_file]$"
open_file_errorMsg db "Can not open specified file$"
buffer db 100 dup(0)
buffer_size equ $-buffer

.code
print_file_path db 120 dup ('$')
screen_size equ 4000
print_file_fd dw -1
screen db 2050 dup ('-')

proc print_screen_listener far
	push ax
	push bx
	push cx
	push dx
	push ds
	push es
	push si

	mov ax, cs
	mov ds, ax

	; ----- try to open screen file -----
	mov ah, 3Ch
	mov cx, 0; mov cx, 0A001h 	;1010_0001
	lea dx, print_file_path
	int 21h
	jnc open_tmp_file_ok
		jmp print_screen_listener_error
	open_tmp_file_ok:
	mov print_file_fd, ax
	; -------------------------------------

	mov ax, 0B800h
	mov es, ax

	mov si, 0	; video buffer  position to read
	mov bx, 0	; screen position to write
	screen_to_buffer:
		cmp si, screen_size
		jae screen_to_buffer_out

		mov al, [es:si]
		mov byte ptr screen[bx], al
		add si, 2
		inc bx

		mov ax, si
		mov cl, 160
		div cl
		cmp ah, 0
		jne not_new_line
			mov byte ptr screen[bx], 10
			inc bx
			mov byte ptr screen[bx], 13
			inc bx
		not_new_line:

		jmp screen_to_buffer

	screen_to_buffer_out:

	; ----- fflush screen ------
	mov ah, 40h
	mov cx, bx
	mov bx, print_file_fd
	lea dx, screen
	int 21h
	; --------------------------

	; ----- close file ------
	mov ah, 3Eh
	mov bx, print_file_fd
	int 21h
	;------------------------

	print_screen_listener_error:

	pop si
	pop es
	pop ds
	pop dx
	pop cx
	pop bx
	pop ax
	iret
	ret
endp print_screen_listener
interruption_offset equ $ + 1

proc setup_prt_sc_listener
	push ds
	
	mov bx, cs
	mov ds, bx
	lea dx, print_screen_listener
	mov ah, 25h
	mov al, 05h
	int 21h

	pop ds
	ret
endp setup_prt_sc_listener

; lab8 [number] [file_paht]
; file_path = file_paht
; ax = result status, 0 on success
; NOTE: es -- data, ds -- psp
proc parse_cmd
	mov si, 82h	;81 is space, lol

	mov cx, 0
	mov cl, [ds:80h]
	cmp cl, 1
	jng parse_error

	sub cl, 1
	lea di, file_path

	parse_first_file:
	cmp ds:si, byte ptr 20h
	je parse_first_file_end
	cmp cl, 0
	je parse_error	
	mov al, word ptr ds:si
	mov word ptr es:di, al
	inc di
	inc si
	dec cl 
	jmp parse_first_file
	parse_first_file_end:

	mov es:di, byte ptr 0
	inc si
	dec cl

	push es
	mov ax, cs
	mov es, ax
	lea di, print_file_path
	repne movsb	; ds:si -> es:di
	mov es:di, byte ptr 0h
	pop es

	mov ax, 0
	jmp parse_cmd_exit

	parse_error: 
	mov ax, 1

	parse_cmd_exit:
	ret
endp parse_cmd

start:
	;------ get and parse cla -----
	mov ax, @data
	mov es, ax

	lea bx, program_segment
	mov [es:bx], ds

	call parse_cmd
	cmp ax, 0
	je validate_arg_ok
	jmp show_usage
	validate_arg_ok:

	mov bx, @data
	mov ds, bx
	;------------------------------

	; ----- try to open required file -----
	mov ah, 3Dh
	mov al, 0h 	; read only, compatability
	lea dx, file_path
	int 21h
	jnc open_file_ok
		jmp open_file_error
	open_file_ok:
	mov fd, ax
	; -------------------------------------

	mov bx, 0 	; buffer position
	copy_except_n_loop:
		; ----- get one symbol -----
		mov ah, 3Fh
		mov bx, fd
		mov cx, buffer_size
		dec cx
		lea dx, buffer
		int 21h
		; --------------------------

		cmp ax, 0
		je copy_except_n_loop_out

		mov bx, ax

		mov byte ptr [buffer + bx], '$'

		lea dx, buffer
	    mov ah, 9
	    int 21h  

		jmp copy_except_n_loop

	copy_except_n_loop_out:

	; ----- close file ------
	mov ah, 3Eh
	mov bx, fd
	int 21h
	;------------------------

	jmp main_end

	show_usage:
		mov ax, @data;
		mov ds, ax
		lea dx, usageMsg
		mov ah, 09h
		int 21h
		jmp main_end
	open_file_error:
		lea dx, open_file_errorMsg
		mov ah, 09h
		int 21h
		jmp main_end
	main_end:
		call setup_prt_sc_listener
		; ----- make program resident -----
		mov ax, @data;
		mov ds, ax
		mov dx, cs
		sub dx, program_segment
		mov ax, word ptr interruption_offset

		shr ax, 4
		inc ax

		add dx, ax
		int 27h	
		; ---------------------------------
		
	 	; mov ax, 4C00h
		; int 21h
end start