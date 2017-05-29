.model small
.stack 100h
.code
    start: 
        mov ax, @data
        mov ds, ax
        mov dx, offset message
        mov ah, 9
        int 21h
        mov ah, 4Ch
        int 21h
.data
    message db "Hello World!", 13, 10, '$'
end start