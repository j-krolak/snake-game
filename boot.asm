org 0x7c00       

; VGA constants
WIDTH equ 320
HEIGHT equ 200
FRAME_DELAY equ 5


; PRNG constants
PRNG_SEED equ 0x312
PRNG_A equ  13
PRNG_C equ 6

; Snake connstants
SNAKE_BASE equ 0x8000
SNAKE_WIDTH equ 10
SNAKE_COLOR equ 0x31

SNAKE_DOWN equ WIDTH * SNAKE_WIDTH
SNAKE_RIGHT equ SNAKE_WIDTH

APPLE_COLOR equ 0x0C

; Data
frame_counter dw 0
snake_length dw 1

struc GameState
 .direction resw 1
 .reversed_direction resb 1
 .state resb 1
 .apple resw 1
 .random resw 1
 .head resw 1
endstruc

game_state resb GameState


; Text section
start:
	; Set video mode 13h (320x200, 256 colors)
	mov ax, 0x0013
	int 0x10
	call clear_canvas

	call init

hang:
	call read_input
	call update_prng
	hlt
	inc word [frame_counter]
	cmp word [frame_counter], FRAME_DELAY

	jne hang

	mov word [frame_counter], 0 

	call loop
	jmp hang


loop: 
	call clear_canvas
	call draw_apple
	call move_snake	
	call draw_snake
	ret	
	
; ==== Functions ====

update_apple:
	pusha
	mov ax, [game_state + GameState.random]
	xor dx, dx
	mov bx, WIDTH/SNAKE_WIDTH
	div bx

	mov ax, dx
	mov bx, SNAKE_WIDTH
	mul bx
	mov word [game_state + GameState.apple], ax

	call update_prng

	mov ax, [game_state + GameState.random]
	xor dx, dx
	mov bx, HEIGHT/SNAKE_WIDTH
	div bx

	mov ax, dx
	mov bx, WIDTH*SNAKE_WIDTH
	mul bx
	mov bx, [game_state + GameState.apple]
	add bx, ax
	mov word [game_state + GameState.apple], bx



	popa
	ret

draw_apple:
	pusha
	mov ax, [game_state + GameState.apple]
	mov dl, SNAKE_WIDTH
	mov cl, APPLE_COLOR 
	call draw_rect
	popa
	ret

init:
	
 	mov ax, SNAKE_BASE
	mov es, ax


	mov byte [game_state + GameState.state], 0
	mov byte [game_state + GameState.reversed_direction], 0
	mov word [game_state + GameState.direction], SNAKE_RIGHT
	mov word [game_state + GameState.head], 0
	
	mov ax, 0
	mov si, ax

	mov word es:[si], 0 

	mov word [game_state + GameState.random], PRNG_SEED

	call update_apple
	ret

update_prng:
	pusha
	mov ax, [game_state + GameState.random]
	mov bx, PRNG_A
	mul bx
	add ax, PRNG_C
	mov word [game_state + GameState.random], ax
	popa
	ret

read_input:
	pusha

	;Checking if key is pressed
	mov ah, 0x01
	int 0x16
	jz end_read_input
	
	; Reading key
	mov ah, 0x00
	int 0x16

	cmp ah, 0x48       ; up arrow 
	je up_arrow

	cmp ah, 0x50       ; down arrow
	je down_arrow

	cmp ah, 0x4B       ; left arrow
	je left_arrow

	cmp ah, 0x4D       ; right arrow
	je right_arrow

; ==== handling events =====
down_arrow:
	mov word [game_state + GameState.direction], SNAKE_DOWN
	mov byte [game_state + GameState.reversed_direction], 0 
	popa
	ret

up_arrow:
	mov word [game_state + GameState.direction], SNAKE_DOWN
	mov byte [game_state + GameState.reversed_direction], 1 
	popa
	ret


right_arrow:
	mov word [game_state + GameState.direction], SNAKE_RIGHT
	mov byte [game_state + GameState.reversed_direction], 0 
	popa
	ret

left_arrow:
	mov word [game_state + GameState.direction], SNAKE_RIGHT
	mov byte [game_state + GameState.reversed_direction], 1
	popa
	ret

end_read_input:
	popa
	ret

move_snake:
	pusha
	; Save frist element to snake_head
	mov ax, SNAKE_BASE
	mov es, ax

	mov ax, es:[0]
	mov word [game_state + GameState.head], ax
	
	call move_head
	mov ax, [game_state + GameState.head]
	mov bx, [game_state + GameState.apple]
	cmp ax, bx

	jne dont_encounter_apple
	mov cx, [snake_length] ; Index of array
	add cx, 1
	mov word [snake_length], cx
	call update_apple


dont_encounter_apple:
	; Setup variable for moving
	mov cx, [snake_length] ; Index of array
	sub cx, 1

	jz end_move 

	; Move all parts of snake	
	move_loop:
		mov ax, cx
		dec ax
		shl ax, 1
	

		mov si, ax
		mov ax, SNAKE_BASE
		mov es, ax

		mov word bx, es:[si]
		mov word es:[si+2], bx
		dec cx
		cmp cx, 0
	jne move_loop

end_move:
	mov ax, SNAKE_BASE
	mov es, ax
	mov word ax, [game_state + GameState.head]
	mov word es:[0], ax

	popa
	ret


move_head: 
	pusha

	mov bx, [game_state + GameState.direction]
	
	mov cl, [game_state + GameState.reversed_direction]
	and cx, 0x00ff
	cmp cl, 1
	je reverse_direction

	add ax, bx
	mov [game_state + GameState.head], ax
	popa
	ret


reverse_direction:	
	sub ax, bx
	mov [game_state + GameState.head], ax
	popa
	ret

clear_canvas:
		pusha
		mov ax, 0xA000
		mov es, ax       ; ES = segment of video memory
		xor di, di       ; DI = offset into video memory
		mov cx, WIDTH*HEIGHT  ; number of pixels
		mov al, 0x00

		rep stosb
		popa
		ret


draw_snake:
	pusha
	mov bx, [snake_length]

	draw_snake_loop:
		mov si, bx	
		dec si
		shl si, 1

		mov ax, SNAKE_BASE
		mov es, ax

		mov ax, es:[si]
		mov dl, SNAKE_WIDTH
		mov cl, SNAKE_COLOR

		call draw_rect
		
		dec bx
	jnz draw_snake_loop

	popa
	ret
	
; ax - anchor
; cl - color
; dl - width of rect
draw_rect:
	pusha	

	mov bx, dx
	and bx, 0x00ff


	; index for iterating through vga array
	mov dh, bl

	rect_row_loop:
			
		mov dl,  bl

		rect_col_loop:
			
			call draw_pixel_anchor
			inc ax
			dec dl

			cmp dl, 0
		jnz rect_col_loop

		sub ax, bx
		add ax, WIDTH
		dec dh
		cmp dh, 0
	jnz rect_row_loop
	popa
	ret

; Inputs:
; 	ax - row
; 	bx - col
; 	cl - color
draw_pixel:
	pusha

	mov cx, WIDTH
	mul cx

	add ax, bx
	call draw_pixel_anchor

	popa
	ret

; Inputs:
; 	ax - anchor
; 	cl - color
draw_pixel_anchor:
	pusha

	mov dx, 0xA000
	mov es, dx

	mov di, ax
	mov al, cl
	stosb 

	popa
	ret



times 510-($-$$) db 0    
dw 0xAA55                ; Boot signature

