.model small
.data 
.stack 100h
enterFirst db "Enter the first number: $"
enterSecond db 10, 13, "Enter the second number: $"
overflowMessage db 10, 13, "Overflow exception$"
illegalStringMessage db 10, 13, "Illegal string exception$"
sumLabel db 10, 13, "Sum: $"
subLabel db 10, 13, "Sub: $"
mulLabel db 10, 13, "Mul: $"
andLabel db 10, 13, "And: $"
orLabel db 10, 13, "Or: $"
first db 7, 8 dup('?')
						; size: 7 = 1(sign) + 5(digits) + 1(enter)
						; buffer: 8 = size+1 (received literals num)
second db 7, 8 dup('?')	
.code 
main:

	mov ax, @data
	mov ds, ax

	; ----- Entering first number -----
	lea dx, enterFirst
	mov ah, 09h
	int 21h

	lea dx, first
	inc ah
	int 21h
	;----------------------------------

	; -----Entering second number------
	lea dx, enterSecond
	dec ah
	int 21h

	lea dx, second
	inc ah
	int 21h
	;----------------------------------

	; ----- convert second -----
	lea dx, second
	add dx, 1
	mov si, dx

	call str_to_int
	cmp bx, 1
	je overflow_exception
	cmp bx, 2
	je illegal_string_exception
	mov bx, ax 	; OK
	push bx									; push bx
	;----------------------

	; ----- convert first -----
	lea dx, first
	add dx, 1
	mov si, dx

	call str_to_int
	cmp bx, 1
	je overflow_exception
	cmp bx, 2
	je illegal_string_exception
	;----------------------
	
	; ----- calculate sum -----
	pop bx									; pop bx
	call add_print_ints
	cmp cx, 1
	je overflow_exception
	; -------------------------

	; ----- calculate sub -----
	call sub_print_ints
	; -------------------------

	; ----- calculate mul -----
	call mul_print_ints
	cmp cx, 1
	je overflow_exception
	; -------------------------

	; ----- calculate and -----
	call and_print_ints
	; -------------------------
	; ----- calculate or -----
	call or_print_ints
	; -------------------------


	jmp program_end
overflow_exception:
	lea dx, overflowMessage
	mov ah, 09h
	int 21h
	jmp program_end
	
illegal_string_exception:
	lea dx, illegalStringMessage
	mov ah, 09h
	int 21h
	jmp program_end

program_end:
	mov ax, 4C00h
	int 21h

; casts string to integer. On overflow, leaves OF flag
; input:
; si -- source string (ends with 0D),
; si[0] -- string size
; output:
; ax -- integer
; errors:
; bx 0 if OK						???????push??????
; bx 1 if OF
; bx 2 if Illegal string
str_to_int PROC
	push dx
	xor ax, ax
	mov bx, 1
	cmp byte ptr [si+bx], 2Dh	; check for -		??????another approach to cmp word and byte?????
	jne not_negative
	push -1
	inc bx
	jmp convert_digit
not_negative:
	push 1
convert_digit:
	; ----- check for illegal_string -----
	cmp byte ptr [si+bx], 30h	
	jl illegal_string
	cmp byte ptr [si+bx], 39h
	jg illegal_string
	;-------------------------------------
	add al, byte ptr [si+bx]
	adc ah, 0	; overflow case
	sub ax, 0030h

	cmp bl, byte ptr [si]
	je one_digit_case
	mov dx, 0Ah
	mul dx
	jo overflow

	inc bx
	cmp bl, byte ptr [si]
	jl convert_digit
	; last symbol
	; ----- check for illegal_string -----
	cmp byte ptr [si+bx], 30h	
	jl illegal_string
	cmp byte ptr [si+bx], 39h
	jg illegal_string
	;-------------------------------------
	add al, byte ptr [si+bx]
	adc ah, 0	; overflow case
	sub ax, 0030h
one_digit_case:
	cmp ax, 8000h ; check sign, must be positive, 0 bit
	ja overflow 

	pop dx	; set sign
	mul dx

	pop dx
	mov bx, 0
	jmp proc_end
illegal_string:
	pop dx ; delete sign
	pop dx
	mov bx, 2
	jmp proc_end
overflow:
	pop dx ; delete sign
	pop dx
	mov bx, 1
	jmp proc_end
proc_end:
	ret
str_to_int endp

; prints integer to stdout
; input:
; ax -- integer
print_int  proc C uses ax bx dx cx

	; push ax
	; mov ah, 02h
	; mov dx, 10
	; int 21h
	; mov dx, 13
	; int 21h
	; pop ax

	mov bx, 10
	xor cx, cx
	; cmp ax, 0 ; wrong
	; je print_proc_end
	cmp ax, 8000h ; check sign, must be positive, 0 bit
	jb calculate_char_number

	push ax
	mov ah, 02h
	mov dx, 002Dh
	int 21h
	pop ax

	not ax
	inc ax
calculate_char_number:
	xor dx, dx
	div bx
	add dx, 30h
	push dx
	xor dx, dx
	inc cx
	cmp ax, 0
	jne calculate_char_number

	mov ah, 02h
print_char_numbers:
	pop dx
	int 21h
	loop print_char_numbers


print_proc_end:
	ret
print_int endp


; calculate sum of tho integers and print
; input:
; ax - first integer
; bx - second integer
; output:
; cx = 0 -- OK
; cx = 1 -- overflow
add_print_ints proc C uses ax bx
; 	cmp ax, 8000h
; 	jae ax_neg
; 	jb ax_pos
; ax_pos:
; 	cmp bx, 8000h
; 	jae one_neg
; 	jb all_pos
; ax_neg:
; 	cmp bx, 8000h
; 	jae all_neg
; 	jb one_neg

; all_neg:
; 	add ax, bx
; 	jno overflow_1
; 	jo print_sum
; all_pos:
 	add ax, bx
	jo overflow_1
	jno print_sum
; one_neg:
; 	jmp print_sum

overflow_1:
	mov cx, 1
	jmp proc_end_1
print_sum:
	push dx
	push ax
	lea dx, sumLabel
	mov ah, 09h
	int 21h
	pop ax
	pop dx
	call print_int
	mov cx, 0
	jmp proc_end_1
proc_end_1:

	ret
add_print_ints endp

; calculate sub of tho integers and prints result
; input:
; ax - first integer
; bx - second integer
sub_print_ints proc C uses ax bx
 	sub ax, bx
	push dx
	push ax
	lea dx, subLabel
	mov ah, 09h
	int 21h
	pop ax
	pop dx
	call print_int
	ret
sub_print_ints endp

; calculate mul of tho integers and prints result
; input:
; ax - first integer
; bx - second integer
; output:
; cx = 0 -- OK
; cx = 1 -- overflow
mul_print_ints proc C uses ax bx dx
 	imul bx
 	jo overflow_mul

	push dx
	push ax
	lea dx, mulLabel
	mov ah, 09h
	int 21h
	pop ax
	pop dx
	call print_int
	mov cx, 0
	jmp mul_end
overflow_mul:
	mov cx, 1
mul_end:
	ret
mul_print_ints endp


; calculate and of tho integers and prints result
; input:
; ax - first integer
; bx - second integer
and_print_ints proc C uses ax bx dx
 	and ax, bx

	push dx
	push ax
	lea dx, andLabel
	mov ah, 09h
	int 21h
	pop ax
	pop dx
	call print_int
	mov cx, 0
	ret
and_print_ints endp

; calculate or of tho integers and prints result
; input:
; ax - first integer
; bx - second integer
or_print_ints proc C uses ax bx dx
 	or ax, bx

	push dx
	push ax
	lea dx, orLabel
	mov ah, 09h
	int 21h
	pop ax
	pop dx
	call print_int
	mov cx, 0
	ret
or_print_ints endp

end main