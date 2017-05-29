.model small
.data
.stack 100h
string db 80, 80 dup('$')
plsEnter db 'Please, enter the string: $'
yourString db 10, 13, 'Your string: $'
.code
; used procedures:
; next word
; swap words
; compare_words
; word_end
; reverse          
main: 
    ; initializing
    mov ax, @data
    mov ds, ax
    mov es, ax
    
    ; Please, enter the string
    mov dx, offset plsEnter
    mov ah, 09h
    int 21h
    ;reading the string
    mov ah, 0Ah
    mov dx, offset string
    int 21h 
    ;Your string:
    lea dx, yourString
    mov ah, 09h
    int 21h
    ; prepare data: si -- begin, di -- end
    lea si, string
    add si, 2
    mov di, si
    mov dl, string[1]
    add di, dx
    mov string[di], '$'
    
    mov bx, si ;position_to_place_next
    mov dx, si ;max_word
    mov cx, si ;current_word

outer_loop:
    inner_loop:         ; find max word
        call next_word       ; new at di
        cmp di, -1
        je out_of_inner ; end of string
        mov si, dx      ; max at si
        call compare_words
        cmp ax, -1
        jne not_greater
        mov dx, di      ;di is greater then si, save current max
        not_greater: 

        mov cx, di      ; prepare si for the next loop
        mov si, cx
        jmp inner_loop
    out_of_inner:
    mov si, bx          ; prepare to swap
    mov di, dx
    call swap_words
    call next_word
    mov bx, di      ; next position to place word
    mov si, bx
    call next_word
    cmp di, -1 
    je out_of_outer
    mov dx, si      ; dx contains max current word
    jmp outer_loop

out_of_outer:
    mov dx, 2

    mov ah, 09h
    int 21h

program_exit:
    mov ah, 4Ch    
    int 21h 


    ; input:
    ; si -- current word first letter ptr
    ; output:
    ; di -- next word first letter ptr, -1 if no next
next_word proc
    push ax
    push bx
    call word_end
    inc ax
    mov bx, ax
skip_blank_loop:
    cmp byte ptr [bx], 0Ah   ;new line
    je not_found_next_word
    cmp byte ptr [bx], 24h   ;$
    je not_found_next_word
    cmp byte ptr [bx], 0h    ;null
    je not_found_next_word

    cmp byte ptr [bx], 20h   ;space
    jne found_next_word
    inc bx
    jmp skip_blank_loop    
    
not_found_next_word:
    mov bx, -1
found_next_word:
    mov di, bx
    pop bx
    pop ax
    ret
next_word endp

    ;procedure for swapping words
    ;si -- left word
    ;di -- right word
swap_words proc 
    cmp di, si
    je equal_si_di

    push ax
    push bx
    push cx
    push dx
    push si
    push di

    call word_end   ; ax -- b
    mov bx, ax
    push si 
    mov si, di
    call word_end   ; ax -- d
    mov cx, di
    mov di, ax    
    pop si
    ; a -- si, b -- bx, c -- cx, d -- di

    call reverse ; 1

    push di
    add di, si
    sub di, cx
    mov ax, di  ;save a+d-c

    call reverse ; 2

    pop di
    add si, di
    sub si, bx

    call reverse ;3, si -- a+d-b
    
    mov bx, si
    dec bx
    mov di, bx

    inc ax
    mov si, ax

    call reverse ; 4

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
equal_si_di:
    ret
swap_words endp

    ;returns word end ptr
    ;takes:
    ;si -- word first letter ptr
    ;returns:
    ;ax -- last letter ptr
word_end proc 
    push si
last_letter_loop:   
    cmp byte ptr [si], 20h   ;space
    je proc_end
    cmp byte ptr [si], 0Ah   ;new line
    je proc_end
    cmp byte ptr [si], 24h   ;$
    je proc_end
    cmp byte ptr [si], 0h    ;null
    je proc_end
    inc si
    jmp last_letter_loop

proc_end:
    dec si
    mov ax, si    
    pop si
    ret
word_end endp

    ; compare strings procedure
    ; takes:
    ; si -- first word ptr, first letter
    ; di -- second word ptr, first letter
    ; returns:
    ; al -- -1 (first less), 0 (eq), 1 (second less)
compare_words proc 
    push si
    push di
    cld
cmp_loop:
    cmpsb
    jl less
    jg greater
    cmp byte ptr [si], 20h   ;space
    je less
    cmp byte ptr [si], 0Ah   ;new line
    je less
    cmp byte ptr [si], 24h   ;$
    je less
    cmp byte ptr [si], 0h    ;null
    je less

    cmp byte ptr [di], 20h   ;space
    je greater
    cmp byte ptr [di], 0Ah   ;new line
    je greater
    cmp byte ptr [di], 24h   ;$
    je greater
    cmp byte ptr [di], 0h    ;null
    je greater
    jmp cmp_loop
less:
    mov ax, 1
    jmp end_proc
equals:
    mov ax, 0
    jmp end_proc
greater:
    mov ax, -1
end_proc:
    pop di
    pop si
    ret
compare_words endp

    ;reverse procedure
    ;si -- begin
    ;di -- end
reverse proc
    
    push ax     ;currenct letter      
    push bx     ;counter to right
    push cx     ;distance
    push di
    mov bx, 0
    mov cx, di
    sub cx, si   
    jle reverse_out ;start position should be less then end position
pushing: 
    mov ax, [si+bx]
    push ax         ;pushing letter
    inc bx
    cmp bx, cx
    jle pushing
    
    cld ; prepare string
    mov di, si
poping:
    pop ax
    stosb 
    loop poping ;dec cx, distance
    pop ax
    stosb       
reverse_out:
    pop di
    pop cx
    pop bx
    pop ax  
    ret
reverse endp 
end main