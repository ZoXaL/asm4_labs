.model small
.data 
.stack 100h
file_path db 120 dup('$')
program_segment dw 0
fd dw -1
usageMsg db "Usage: lab8 [file_path]$"
open_file_errorMsg db "Can not open specified file$"
buffer db 100 dup(0)
buffer_size equ $-buffer

.code
screen_size equ 4000
print_file_path db "C:\print.txt", 0, '$'
print_file_fd dw -1
screen db 2050 dup ('-')

proc print_screen_listener far
	push ds
	mov ax, cs
	mov ds, ax	 

    ; ----- try to open screen file -----
	mov ah, 3Ch
	mov cx, 0A001h 	;1010_0001
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
	
	pop ds
	iret
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
; NOTE: es -- data, ds -- psp
proc parse_cmd
	mov si, 82h	;81 is space, lol
	mov cl, [ds:80h]
	sub cl, 1
	lea di, file_path
	repne movsb	; ds:si -> es:di
	mov es:di, byte ptr 0h
	ret
endp parse_cmd

start:
	mov al, [ds:80h]
	cmp al, 1
	jg validate_arg_ok
	jmp show_usage
	validate_arg_ok:

	;------ get and parse cla -----
	mov ax, @data
	mov es, ax

	lea bx, program_segment
	mov [es:bx], ds

	call parse_cmd
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