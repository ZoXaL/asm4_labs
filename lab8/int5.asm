.model small
.data 
.stack 100h
.code
start:
	int 05h
    mov ax, 4C00h
	int 21h
end start