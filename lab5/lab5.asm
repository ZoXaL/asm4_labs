.model small
.data 
.stack 100h
message db "Trace"
n db -1
file_path db 120 dup('$')
tmp_file_path db "L:\tmp83792849961.txt", 0
fd dw -1
tmp_fd dw -1
usageMsg db "Usage: lab5 [positive_number] [file_path]$"
open_file_errorMsg db "Can not open specified file$"
open_tmp_file_errorMsg db "Can not open tmp file$"
current_line db 1
current_buffer_pos dw 0
buffer db 200 dup(0)
buffer_size equ $-buffer
.code

; lab5 [number] [file_paht]
; ax = number; -1 on parse error
; file_path = file_paht
; NOTE: es -- data, ds -- psp
proc parse_cla
	mov si, 82h	;81 is space, lol
	call str_to_int
	cmp bx, 0
	je parse_ok
	mov ax, -1
	jmp parse_end
	parse_ok:
	cmp ax, 0
	jne number_ok
	mov ax, -1
	jmp parse_end
	number_ok:
		inc si ; space after number

		mov cl, 81h
		add cl, [ds:80h]
		sub cx, si
		lea di, file_path
		repne movsb	; ds:si -> es:di
		mov es:di, byte ptr 0h
	parse_end:
	ret
endp parse_cla

; casts string to integer. On overflow, leaves OF flag
; input:
; si -- source string (ends with 0D)
; output:
; ax -- integer
; si -- position after the integer
; errors:
; bx 0 if OK						
; bx 1 if OF
; bx 2 if Illegal string
str_to_int PROC
	push dx
	line_end equ 20h
	xor ax, ax
convert_digit:
	mov dx, 0Ah
	mul dx
	jo overflow

	; ----- check for illegal_string -----
	cmp byte ptr [si], 30h	
	jl illegal_string
	cmp byte ptr [si], 39h
	jg illegal_string
	; ------------------------------------
	; ----- symbol to number -----
	add al, byte ptr [si]
	adc ah, 0	; overflow case
	sub ax, 0030h
	; ----------------------------
	inc si
	cmp byte ptr [si], line_end
	jne convert_digit
	mov bx, 0
	jmp proc_end
illegal_string:
	mov bx, 2
	jmp proc_end
overflow:
	mov bx, 1
	jmp proc_end
proc_end:
	pop dx
	ret
str_to_int endp


main:
	; ----- get and parse cla -----
	mov ax, @data
	mov es, ax
	call parse_cla
	mov bx, @data
	mov ds, bx
	mov n, al
	cmp ax, -1
	jne cla_ok
		jmp show_usage
	cla_ok:
	;------------------------------

	; lea dx, file_path
	; mov ah, 09h
	; int 21h

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

	; ----- try to create and open tmp file -----
	mov ah, 3Ch
	mov cx, 0A001h 	;1010_0001
	lea dx, tmp_file_path
	int 21h
	jnc open_tmp_file_ok
		jmp open_tmp_file_error
	open_tmp_file_ok:
	mov tmp_fd, ax	
	; -------------------------------------------

	; алгоритм

	; устанавливаем счётчик текущей строки в 1
	; устанавливаем позицию буффера в 0
	; цикл {
		; читаем символ из исходного файла, 			
			; если считали 0 символов, выгружаем буффер, выходим
			; если строка для удаления, не изменяем позицию записи в буффер
			; если буффер полон, выгружаем его в tmp-file, обнуляем позицию буффера
		; если символ новой строки, увеличиваем счётчик текущей строки
	; }
	; !! писать от 0 до current_buffer_pos НЕ включая
	;mov cx, 1	; current line
	;mov bx, 0 	; buffer position
	copy_except_n_loop:
		; ----- get one symbol -----
		mov ah, 3Fh
		mov bx, fd
		mov cx, 1
		lea dx, buffer
		add dx, current_buffer_pos
		int 21h
		; --------------------------

		cmp ax, 0
		je copy_except_n_loop_out

		; ----- check if odd line -----
		mov al, current_line
		mov dl, n
		div dl

		; have to inc n here if need
		; because if do it after current_buffer_pos change
		; you can not analyze if it was \n symbol
		lea bx, buffer 				
		add bx, current_buffer_pos
		cmp [bx], byte ptr 10
		jne not_new_line
			mov bl, current_line 	; inc n
			inc bl
			mov current_line, bl
		not_new_line:

		cmp ah, 0	; if true, don't buffer this line
		je after_odd_check
			mov ax, current_buffer_pos	; inc buffer
			inc ax
			mov current_buffer_pos, ax
		after_odd_check:

		; check if buffer is full
		mov ax, current_buffer_pos
		cmp ax, buffer_size
		jna	not_full_buffer; only if current_buffer_pos is greater
			; fflush buffer to tmp file
			mov ah, 40h
			mov bx, tmp_fd
			mov cx, current_buffer_pos
			lea dx, buffer
			int 21h
			mov current_buffer_pos, 0h
		not_full_buffer:

		jmp copy_except_n_loop

	copy_except_n_loop_out:

	cmp current_buffer_pos, 0h
	je no_need_fflush
		; fflush buffer to tmp file
		mov ah, 40h
		mov bx, tmp_fd
		mov cx, current_buffer_pos
		lea dx, buffer
		int 21h
	no_need_fflush:

	; ----- close file ------
	mov ah, 3Eh
	mov bx, fd
	int 21h
	;------------------------

	; ----- close tmp file -----
	mov ah, 3Eh
	mov bx, tmp_fd
	int 21h
	; --------------------------

	; ----- delete old file -----
	mov ah, 41h
	lea dx, file_path
	int 21h
	; ---------------------------

	; ----- rename tmp file -----
	mov ah, 56h
	lea dx, tmp_file_path
	lea di, file_path
	int 21h
	; ---------------------------

	jmp main_end

	show_usage:
		lea dx, usageMsg
		mov ah, 09h
		int 21h
		jmp main_end
	open_file_error:
		lea dx, open_file_errorMsg
		mov ah, 09h
		int 21h
		jmp main_end
	open_tmp_file_error:
		lea dx, open_tmp_file_errorMsg
		mov ah, 09h
		int 21h
		jmp main_end
	main_end:
	    mov ax, 4C00h
		int 21h
end main