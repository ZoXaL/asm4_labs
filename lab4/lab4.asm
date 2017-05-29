.model small
.data 
.stack 100h
message db "Trace", 13, 10, '$'
got_e db " got e ", '$'
kp db "Got key: ", 13, 10, '$'
new_line db "new_line", 13, 10, '$'
win_message db "YOU WIN!", 13, 10, '$'
lose_message db "YOU LOSE!", 13, 10, '$'
DESK_SIZE equ 12
DESK_PART equ 4
DESK_SPEED equ 2
DESK_LINE_OFFSET equ 3520; 22*160
deskX dw 34 ; 80 - DESK_SIZE, it's center
TICK_TIME dw 06h ; in sec/100
tmp dw 0
tmp2 dw 0
ballX dw 42
ballY dw 15
ballXS dw 0
ballYS dw -1
deskY dw 22
pause db 0
flag db 2
score dw 0
totalBlocks dw 20
blockX dw 0
blockY dw 0
blockColor db 11h
blocks 	db 	0, 0, 0, 0, 0, 0, 0, 0, 0, 0	; 10x18 all
		db	0, 1, 1, 1, 0, 0, 1, 1, 1, 0	; 8x2 each
		db	0, 1, 0, 1, 0, 0, 1, 0, 1, 0
		db	0, 1, 1, 1, 0, 0, 1, 1, 1, 0
		db	0, 1, 0, 1, 0, 0, 1, 0, 1, 0
		db	0, 0, 0, 0, 0, 0, 0, 0, 0, 0
		db	0, 0, 0, 0, 0, 0, 0, 0, 0, 0
		db	0, 0, 0, 0, 0, 0, 0, 0, 0, 0
		db	0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	
.code
proc wait_tick
	push ax
	push cx
	push dx
	mov ah, 2Ch	; get RTC time
	int 21h
	mov tmp2, dx ; tmp2 contains last dx value
	mov cx, dx
	add cx, word ptr TICK_TIME	; cx — time of next tick
	mov tmp, 0000h
	mov tmp2, 0000h
	mov flag, 00h

	check_sec_overflow:
		cmp cl, 64h
		jbe check_min_overflow
		sub cl, 64h
		add ch, 1
		mov flag, 01h ; means that got sec overflow
	
	check_min_overflow:
		cmp cx, 3C00h
		jbe after_time_overflow_checks
		sub cx, 3C00h
		jmp check_min_overflow

	after_time_overflow_checks:
	; cmp ch, 00h 					; if got overflow 
	; jne zero_sec_overflow_flag
	; cmp flag, 1 					; overflow because of ch++
	; je after_all_checks				; save flag

	; zero_sec_overflow_flag:
	; mov flag, 0	

	after_all_checks:
		mov tmp, cx
	wait_for_next_tick:	; waiting
		mov ax, 2C00h
		int 21h
		mov cx, tmp
		cmp dx, cx  
		jb wait_for_next_tick	; wait if not reach required time
		cmp ch, 00h
		ja wait_tick_end
		cmp dh, 3Bh
		jb wait_tick_end
		jmp wait_for_next_tick
		; cmp dx,  tmp2			; if dx decreases, means min overflow, zero flag
		; ja save_zero_sec_overflow_flag
		; mov flag, 0
		; save_zero_sec_overflow_flag: 
		; mov tmp2, dx
		; cmp flag, 1		
		; je wait_for_next_tick	; wait if next minute
	wait_tick_end:
	pop dx
	pop cx
	pop ax
	ret
endp wait_tick

; left: al = 1
; right al = 2
; top: ah = 1
; bot: ah = 2
proc update_board_position
	push ax
	update_board_position_left:
		cmp al, 1
		jne update_board_position_right
		cmp deskX, 0
		jbe update_board_position_right
		;mov ax, deskX
		;sub ax, DESK_SPEED
		;mov deskX, ax
		sub deskX, 2
		jmp update_board_position_right
	update_board_position_right:
		cmp al, 2
		jne update_board_position_top
		mov al, byte ptr 79
		sub al, DESK_SIZE
		cmp byte ptr deskX, al
		jae update_board_position_top
		mov ax, deskX
		add ax, DESK_SPEED
		mov deskX, ax

	update_board_position_top:
		cmp ah, 1
		jne update_board_position_bot
		cmp deskY, 23
		jb update_board_position_bot
		mov ax, deskY
		sub ax, 1
		mov deskY, ax
		jmp update_board_position_bot
	update_board_position_bot:
		cmp ah, 2
		jne update_board_position_exit
		cmp deskY, 22
		ja update_board_position_exit
		mov ax, deskY
		add ax, 1
		mov deskY, ax

		jmp update_board_position_exit

	update_board_position_exit:
	pop ax
	ret
endp update_board_position

proc process_keyboard_events
	push ax
	mov ah, 01h
	int 16h
	jz process_keyboard_events_exit
	mov ah, 00h
	int 16h
	mov tmp, ax

	; get only last press
	get_last_press:
		mov ah, 01h
		int 16h
		jz process_key
		mov ah, 00h
		int 16h
		mov tmp, ax
		jmp get_last_press

	process_key:
	cmp al, 71h		; 'q' — exit
	jne not_e 		; exit on 'q'
		mov ah, 09h
		lea dx, got_e
		int 21h
		mov ax, 4C00h
		int 21h
	not_e:
		cmp al, 61h		; 'a' — left
		jne not_left
		mov ax, 0001h
		call update_board_position
		jmp process_keyboard_events_exit
	not_left:
		cmp al, 64h		; 'd' — right
		jne not_right
		mov ax, 0002h
		call update_board_position
		jmp process_keyboard_events_exit
	not_right:
		cmp al, 77h		; 'w' — top
		jne not_top
		mov ax, 0100h
		call update_board_position
		jmp process_keyboard_events_exit
	not_top:
		cmp al, 73h		; 's' — down
		jne not_bot
		mov ax, 0200h
		call update_board_position
		jmp process_keyboard_events_exit
	not_bot:
		cmp al, 70h		; 'p' — pause
		jne process_keyboard_events_exit
		not tmp

	process_keyboard_events_exit:
	pop ax
	ret
endp process_keyboard_events

; ax — cell position
; bh - clear cell
; bl — cell color
; dl — cell symbol
proc set_cell
	push ax
	push di
	push es

	mov di, ax
	mov ax, 0B800h
	mov es, ax
	cmp bh, 1
	jne set_cell_label
		mov byte ptr [es:di], 44h 
		mov byte ptr [es:di+1], 00h 
	set_cell_label:
		mov byte ptr [es:di], dl 
		mov byte ptr [es:di+1], bl 

	pop es
	pop di
	pop ax
	ret
endp set_cell

proc clear_ball 
	push ax
	push dx
	push bx

	mov dx, 160
	mov ax, ballY
	mul dx
	add ax, ballX
	add ax, ballX

	mov bh, 1
	mov dl, 44h
	call set_cell

	pop bx
	pop dx
	pop ax
	ret
endp clear_ball

proc render_ball 
	push ax
	push dx
	push bx
	mov dx, 160
	mov ax, ballY
	mul dx
	add ax, ballX
	add ax, ballX

	mov bh, 00h
	mov bl, 00Fh
	mov dl, 40h

	call set_cell

	pop bx
	pop dx
	pop ax
	ret
endp render_ball

proc rerender_board
	push ax
	push di
	push es
	push cx

	mov ax, 0B800h
	mov es, ax

	mov di, DESK_LINE_OFFSET
	mov cx, 160
	clear_board_line:
		mov byte ptr [es:di], 44h 
		mov byte ptr [es:di+1], 00h 
		add di, 2
	loop clear_board_line

	mov cx, DESK_SIZE
	mov di, DESK_LINE_OFFSET
	add di, deskX
	add di, deskX
	cmp deskY, 23
		jne print_board
	add di, 160	
	print_board:
		mov byte ptr [es:di], 44h 
		mov byte ptr [es:di+1], 11h
		add di, 2
	loop print_board

	pop cx
	pop es
	pop di
	pop ax
	ret
endp rerender_board

proc udpate_ball_parameters
	push ax
	
	; check board
	; check screen edges
	; check blocks
		cmp ballX, 79
		jb left_ok
		mov ballXS, -1
		jmp right_ok
	left_ok:
		cmp ballX, 0
		ja right_ok
		mov ballXS, 1
	right_ok:
		cmp ballY, 0
		ja top_ok
		mov ballYS, 1
		jmp bot_ok
	top_ok:
		cmp ballY, 24
		jb bot_ok
		lea dx, lose_message
		mov ah, 09h
		int 21h
		mov ax, 4C00h
		int 21h
		mov ballYS, -1
	bot_ok:

	; board
	mov ax, deskY
	dec ax
	cmp ballY, ax
	je l1
	jmp not_board
	l1:
	cmp ballYS, 1
	je l2
	jmp not_board
	l2:
	; в угол слева при полете под углом
	left_board_from_left:
		cmp ballXS, 1
		jne right_board_from_right
		mov ax, ballX
		inc ax
		cmp deskX, ax
		jne right_board_from_right

		mov ballXS, -1
		mov ballYS, -1
		jmp not_board
	right_board_from_right:
		cmp ballXS, -1
		jne left_board
		mov ax, ballX
		sub ax, DESK_SIZE
		cmp deskX, ax
		jne left_board

		mov ballXS, 1
		mov ballYS, -1
		jmp not_board
	left_board:
		mov ax, deskX
		cmp ballX, ax
		jb center_board
		add ax, DESK_PART
		cmp ballX, ax
		jae center_board

		mov ballXS, -1
		mov ballYS, -1

		jmp not_board
	center_board:
		mov ax, deskX
		add ax, DESK_PART
		cmp ballX, ax
		jb right_board
		add ax, DESK_PART
		cmp ballX, ax
		ja right_board

		mov ballXS, 0
		mov ballYS, -1

		jmp not_board
	right_board:
		mov ax, deskX
		add ax, DESK_PART
		add ax, DESK_PART
		cmp ballX, ax
		jb not_board
		add ax, DESK_PART
		cmp ballX, ax
		jae not_board

		mov ballXS, 1
		mov ballYS, -1

		jmp not_board
	not_board:

	call check_block_clash

	apply_speed:
	mov ax, ballX
	add ax, ballXS
	mov ballX, ax

	mov ax, ballY
	add ax, ballYS
	mov ballY, ax

	pop ax
	ret
endp udpate_ball_parameters

proc render
	call rerender_board
	call render_ball
	ret
endp render


proc render_blocks
	push cx
	push bx
	push si
	push dx
	push ax
	mov cx, 0
	lea bx, blocks
	render_blocks_loop:
		mov si, cx
		cmp byte ptr [si+bx], 1
		jne render_blocks_loop_continue
		mov tmp, cx		
		mov tmp2, 0
		mov ax, cx
		cmp ax, 0
		je add_vertical_offset_loop_exit
		mov bl, 10
		div bl
		mov ah, 0
		cmp al, 0
		je add_vertical_offset_loop_exit
		add_vertical_offset_loop:
			add tmp2, 160
			dec ax
			cmp ax, 0
			jne add_vertical_offset_loop
		add_vertical_offset_loop_exit:

		mov ax, cx
		mov bx, 16
		mul bx	; 2*8
		mov bh, 0
		mov bl, blockColor
		mov dl, 44h
		add ax, tmp2
		mov cx, 8
		block_line_loop:
			call set_cell
			add ax, 2
			loop block_line_loop
		mov cx, 8
		add ax, 160
		sub ax, 16
		block_line_loop2:
			call set_cell
			add ax, 2
			loop block_line_loop2
		mov cx, tmp
		render_blocks_loop_continue:
		lea bx, blocks
		add blockColor, 11h
		jno not_block_color_overflow
		mov blockColor, 11h
		not_block_color_overflow:
		inc cx
		cmp cx, 180
		jb render_blocks_loop
	pop ax
	pop dx
	pop si
	pop bx
	pop cx
	ret
endp render_blocks

proc check_block_clash
	push ax
	push cx
	push bx
	push si
	push dx
	mov cx, 0
	lea bx, blocks
	clash_blocks_loop:
		mov si, cx
		cmp byte ptr [si+bx], 1
		je find_block
		jmp clash_blocks_loop_continue
		find_block:
		mov ax, cx
		mov dx, 0
		mov bx, 000Ah
		div bx
		mov blockX, dx
		mov blockY, ax

		mov ax, blockX
		mov dx, 8
		mul dx
		mov blockX, ax

		mov ax, blockY
		mov dx, 2
		mul dx
		mov blockY, ax		

		; blockY -- block y
		; blockX -- block x
		mov tmp, 0
		;left
		mov ax, blockX
		mov bx, ballX
		add bx, ballXS
		cmp ax, bx
		jne not_left_clash
		mov ax, blockY
		mov bx, ballY
		add bx, ballYS
		cmp bx, ax
		jl not_left_clash
		add ax, 1
		cmp bx, ax
		jg not_left_clash
			mov ballXS, -1
			mov tmp, 1
			call kill_block
		; right
		not_left_clash:
		mov ax, blockX
		add ax, 8
		mov bx, ballX
		add bx, ballXS
		cmp ax, bx
		jne not_right_clash
		mov ax, blockY
		mov bx, ballY
		add bx, ballYS
		cmp bx, ax
		jl not_right_clash
		add ax, 1
		cmp bx, ax
		jg not_right_clash
			mov ballXS, 1
			cmp tmp, 1
			je not_right_clash
			mov tmp, 1
			call kill_block
		; bot
		not_right_clash:
		mov ax, blockY
		inc ax
		mov bx, ballY
		add bx, ballYS
		cmp ax, bx
		jne not_bot_clash
		mov ax, blockX
		mov bx, ballX
		add bx, ballXS
		cmp ax, bx
		jg not_bot_clash
		add ax, 8
		cmp ax, bx
		jl not_bot_clash
			mov ballYS, 1
			cmp tmp, 1
			je not_bot_clash
			mov tmp, 1
			call kill_block
		; top
		not_bot_clash:
		mov ax, blockY
		mov bx, ballY
		add bx, ballYS
		cmp ax, bx
		jne not_top_clash
		mov ax, blockX
		mov bx, ballX
		add bx, ballXS
		cmp ax, bx
		jg not_top_clash
		add ax, 8
		cmp ax, bx
		jl not_top_clash
			mov ballYS, -1
			cmp tmp, 1
			je not_top_clash
			mov tmp, 1
			call kill_block
		; top
		not_top_clash:
		clash_blocks_loop_continue:
		lea bx, blocks
		inc cx
		cmp cx, 180
		jae clash_blocks_return
		jmp clash_blocks_loop
	clash_blocks_return:
	pop dx
	pop si
	pop bx
	pop cx
	pop ax
	ret
endp check_block_clash

;cx -- block number
proc kill_block
	push cx
	push ax
	push bx
	push dx
	push si

	mov si, cx
	lea bx, blocks
	mov byte ptr bx[si], 0
	inc score

	mov tmp, cx		
	mov tmp2, 0
	mov ax, cx
	cmp ax, 0
	je add_vertical_offset_loop_exit2
	mov bl, 10
	div bl
	mov ah, 0
	cmp al, 0
	je add_vertical_offset_loop_exit2
	add_vertical_offset_loop2:
		add tmp2, 160
		dec ax
		cmp ax, 0
		jne add_vertical_offset_loop2
	add_vertical_offset_loop_exit2:

	mov ax, cx
	mov bx, 16
	mul bx	; 2*8
	add ax, tmp2

	mov cx, 8
	block_line_loop3:
		mov bh, 1
		mov bl, 00h
		mov dl, 44h
		call set_cell
		add ax, 2
		dec cx
		jnz block_line_loop3

	mov cx, 8
	add ax, 160
	sub ax, 16
	block_line_loop4:
		mov bh, 1
		mov bl, 00h
		mov dl, 44h
		call set_cell
		add ax, 2
		dec cx
		jnz block_line_loop4

	call udpate_score
	pop si
	pop dx
	pop bx
	pop ax
	pop cx
	ret
endp kill_block

proc udpate_score
	push ax
	push dx
	push bx
	push cx
	xor cx, cx
	mov ax, score
	mov bx, 10
	calculate_char_number:
		xor dx, dx
		div bx
		add dx, 30h
		push dx
		inc cx
		cmp ax, 0
		jne calculate_char_number

	
	add ax, 150 ; смещение в конец строки
	add ax, 3840
	print_number:
		pop dx
		mov bl, 0Fh
		mov bh, 0
		call set_cell
		add ax, 2
		loop print_number

	mov ax, score
	cmp ax, totalBlocks
	jne udpate_score_return
		lea dx, win_message
		mov ah, 09h
		int 21h
		mov ax, 4C00h
		int 21h
	udpate_score_return:
	pop cx
	pop bx
	pop dx
	pop ax
	ret
endp udpate_score

main:
	mov ax, @data
	mov ds, ax
	mov ah, 00h
	mov al, 03h
	int 10h
	call render_blocks
	call udpate_score
	game_loop:
		call wait_tick
		call clear_ball 
		call process_keyboard_events
		call udpate_ball_parameters
		call render
		jmp game_loop
    mov ax, 4C00h
	int 21h
end main