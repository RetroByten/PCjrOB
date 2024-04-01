SETUP_DEFAULT_SEGMENTS PROC NEAR
	mov		ax,cs
	mov		ds,ax ; Setup DS
	mov		ax,segment_video_memory
	mov		es,ax ; Setup ES
	ret
SETUP_DEFAULT_SEGMENTS ENDP

SAVE_VIDEO PROC NEAR
	mov		ah,svc_video_get_mode
	int		int_video_10 ; AL = videomode, BH = active page
	mov		[ram_save_video_mode],al
	mov		[ram_save_video_page],bh
	ret
SAVE_VIDEO ENDP
RESTORE_VIDEO PROC NEAR
	mov		ah,svc_video_set_mode
	mov		al,[ram_save_video_mode]
	int		int_video_10 ; Set Video mode back to original
	mov		ah,svc_video_set_page
	mov		al,[ram_save_video_page]
	int		int_video_10 ; Set Video page back to original
	ret
RESTORE_VIDEO ENDP

FILL_SCREEN PROC NEAR ; al contains nibble to fill
	push	cx
	push	ax
		mov		cx,4
		shl		ax,cl
	pop		cx ; CH contains 1 pixel, high nibble
	or		ax,cx ; AL now contains 2 pixels
	mov		ah,al ; now AX contains 4 pixels
	xor		di,di ; B800:0000
	mov		cx,video_memory_size_words
	cld
	rep		stosw ; rep = cx times, ES:DI = ax
	pop		cx
	ret
FILL_SCREEN ENDP

;;; Set CRTCPU
; al 83 = crt + cpu
; al 80 = read
; bh = crt, bl = cpu

SWITCH_TO_VIDEOA PROC NEAR
	;; Setup Video
	mov		ax,(svc_video_set_mode SHL 8) OR val_mode_a
	int		int_video_10 ; Set video mode
	
	;; Print Menu
	mov		dx,offset menu_options
	mov		ah,svc_dos_print_str
	int		int_dos_21
	ret
SWITCH_TO_VIDEOA ENDP

SWITCH_TO_VIDEOB PROC NEAR
	;; Setup Video
	mov		ax,(svc_video_set_mode SHL 8) OR val_mode_b
	int		int_video_10 ; Set video mode
	;; Setup page
	;mov		ax,(svc_video_set_page SHL 8) OR val_set_cpucrt_page
	;mov		bx,(val_page_1 SHL 8) OR val_page_1
	;int		int_video_10
	; Fill with color 0 by default
	mov		al,color_black
	call	FILL_SCREEN
	ret
SWITCH_TO_VIDEOB ENDP

WAIT_4_KEY PROC NEAR
	;mov		ah,svc_keyboard_input_status
	;int		int_keyboard_16
	;jz		WAIT_4_KEY ; If no key is pressed, loop
	mov		ah,svc_keyboard_read_chr
	int		int_keyboard_16
	ret
WAIT_4_KEY ENDP

VBLANK_INT PROC NEAR
	;; TODO - this is bad form to do a bunch of work in the int
	;; Eventually fix this to only do the palette swap
	;; And move the logic into the main code
	sti ; Disable Interrupts
	push	ax ; Save Regs
	push	dx
	;; DO WORK
	;; Figure out current frame color
	mov		ax,cs:[ram_command_word]
	shl		ax,1 ; grab next bit
	mov		cs:[ram_command_word],ax
	jc		SET_GREEN
SET_BLACK:
	mov		al,color_black
	jmp		SET_COLOR
SET_GREEN:
	mov		al,color_green
SET_COLOR:
	mov		dx,port_vga_register
	push	ax
	cli
	in		al,dx ; force VGA register into address mode
	mov		al,vga_address_palette0
	out		dx,al ; Set VGA address register to palette 0, now in value mode
	pop		ax
	out		dx,al ; Put color into palette 0, back in address mode
	mov		al,vga_address_mode_ctrl1 ; Put in 
	out		dx,al ; Sets address to < 10h
	in		al,dx ; We're done now
	sti

	;; Check if done with command
	mov		al,cs:[ram_command_count]
	inc		al
	mov		cs:[ram_command_count],al
	cmp		al,10h ; 16 Frames
	jne		VBLANK_INT_ACKRET
VBLANK_INT_COMPLETE:
	mov		al,game_mode_waiting_for_game
	mov		cs:[ram_game_mode],al
	;; DONE work
VBLANK_INT_ACKRET:
	mov		al,val_pic_eoi
	out		port_pic_cmd,al ; Acknowledge the hardware interrupt
	pop		dx
	pop		ax ; Restore regs
	iret
VBLANK_INT ENDP


GAME_MODE_MENU_P PROC NEAR
	call	SWITCH_TO_VIDEOA
	
G_MENU_LOOP:
	mov		ah,svc_keyboard_read_chr
	int		int_keyboard_16
G_MENU_Q:
	cmp		al,'q'
	jne		G_MENU_I ; ----
	mov		al,game_mode_exit
	mov		[ram_game_mode],al
	jmp		G_MENU_LOOP_END
;; Check if i
G_MENU_I:
	cmp		al,'i'
	jne		G_MENU_0 ; ----
	mov		al,game_mode_cmd
	mov		[ram_game_mode],al
	mov		al,10h ; Command[16]
	mov		[ram_command_index],al
	jmp		G_MENU_LOOP_END ; -----
G_MENU_0:
	cmp		al,'0' ; -----
	jne		G_MENU_1 ; -------
	mov		al,game_mode_cmd
	mov		[ram_game_mode],al
	mov		al,0h ; Command [0]
	mov		[ram_command_index],al
	jmp		G_MENU_LOOP_END ; -----
G_MENU_1:
	cmp		al,'1' ; -----
	jne		G_MENU_2 ; -------
	mov		al,game_mode_cmd
	mov		[ram_game_mode],al
	mov		al,1h ; Command [1]
	mov		[ram_command_index],al
	jmp		G_MENU_LOOP_END ; -----
G_MENU_2:
	cmp		al,'2' ; -----
	jne		G_MENU_3 ; -------
	mov		al,game_mode_cmd
	mov		[ram_game_mode],al
	mov		al,2h ; Command [2]
	mov		[ram_command_index],al
	jmp		G_MENU_LOOP_END ; -----
G_MENU_3:
	cmp		al,'3' ; -----
	jne		G_MENU_4 ; -------
	mov		al,game_mode_cmd
	mov		[ram_game_mode],al
	mov		al,3h ; Command [3]
	mov		[ram_command_index],al
	jmp		G_MENU_LOOP_END ; -----
G_MENU_4:
	cmp		al,'4' ; -----
	jne		G_MENU_5 ; -------
	mov		al,game_mode_cmd
	mov		[ram_game_mode],al
	mov		al,4h ; Command [4]
	mov		[ram_command_index],al
	jmp		G_MENU_LOOP_END ; -----
G_MENU_5:
	cmp		al,'5' ; -----
	jne		G_MENU_6 ; -------
	mov		al,game_mode_cmd
	mov		[ram_game_mode],al
	mov		al,5h ; Command [5]
	mov		[ram_command_index],al
	jmp		G_MENU_LOOP_END ; -----
G_MENU_6:
	cmp		al,'6' ; -----
	jne		G_MENU_7 ; -------
	mov		al,game_mode_cmd
	mov		[ram_game_mode],al
	mov		al,6h ; Command [6]
	mov		[ram_command_index],al
	jmp		G_MENU_LOOP_END ; -----	
G_MENU_7:
	cmp		al,'7' ; -----
	jne		G_MENU_8 ; -------
	mov		al,game_mode_cmd
	mov		[ram_game_mode],al
	mov		al,7h ; Command [7]
	mov		[ram_command_index],al
	jmp		G_MENU_LOOP_END ; -----	
G_MENU_8:
	cmp		al,'8' ; -----
	jne		G_MENU_9 ; -------
	mov		al,game_mode_cmd
	mov		[ram_game_mode],al
	mov		al,8h ; Command [8]
	mov		[ram_command_index],al
	jmp		G_MENU_LOOP_END ; -----
G_MENU_9:
	cmp		al,'9' ; -----
	jne		G_MENU_A ; -------
	mov		al,game_mode_cmd
	mov		[ram_game_mode],al
	mov		al,9h ; Command [9]
	mov		[ram_command_index],al
	jmp		G_MENU_LOOP_END ; -----	
G_MENU_A:
	cmp		al,'a' ; -----
	jne		G_MENU_B ; -------
	mov		al,game_mode_cmd
	mov		[ram_game_mode],al
	mov		al,0Ah ; Command [A]
	mov		[ram_command_index],al
	jmp		G_MENU_LOOP_END ; -----		
G_MENU_B:
	cmp		al,'b' ; -----
	jne		G_MENU_C ; -------
	mov		al,game_mode_cmd
	mov		[ram_game_mode],al
	mov		al,0Bh ; Command [B]
	mov		[ram_command_index],al
	jmp		G_MENU_LOOP_END ; -----
G_MENU_C:
	cmp		al,'c' ; -----
	jne		G_MENU_D ; -------
	mov		al,game_mode_cmd
	mov		[ram_game_mode],al
	mov		al,0Ch ; Command [C]
	mov		[ram_command_index],al
	jmp		G_MENU_LOOP_END ; -----
G_MENU_D:
	cmp		al,'d' ; -----
	jne		G_MENU_E ; -------
	mov		al,game_mode_cmd
	mov		[ram_game_mode],al
	mov		al,0Dh ; Command [D]
	mov		[ram_command_index],al
	jmp		G_MENU_LOOP_END ; -----
G_MENU_E:
	cmp		al,'e' ; -----
	jne		G_MENU_F ; -------
	mov		al,game_mode_cmd
	mov		[ram_game_mode],al
	mov		al,0Eh ; Command [E]
	mov		[ram_command_index],al
	jmp		G_MENU_LOOP_END ; -----	
G_MENU_F:
	cmp		al,'f' ; -----
	jne		G_MENU_LOOP_CONT ; -------
	mov		al,game_mode_cmd
	mov		[ram_game_mode],al
	mov		al,0Fh ; Command [F]
	mov		[ram_command_index],al
	jmp		G_MENU_LOOP_END ; -----
	
G_MENU_LOOP_CONT:
	jmp		G_MENU_LOOP

G_MENU_LOOP_END:
	
	ret
GAME_MODE_MENU_P ENDP

GAME_MODE_CMD_P PROC NEAR
	call	SWITCH_TO_VIDEOB
	;; Setup vblank routine
	;; Let it run 16x
	;; Unsetup vblank routine
	;; Go back to menu1
	
	xor		bh,bh
	mov		bl,[ram_command_index]; Retrieve intended command index
	shl		bx,1 ; Multiply by 2 (because it is indexing a word)
	mov		ax,[command_words][bx] ; retrieve actual command
	mov		[ram_command_word],ax ; Store command word
	xor		al,al ; Set current shift count to 0
	mov		[ram_command_count],al ; Will be used to shift through the bits
	
	; Save Vertical Retrace interrupt offset
	push	es
	xor		ax,ax
	mov		es,ax ; Set ES to 0
	mov		ax,es:[int_vblank_0D_offset]
	mov		[ram_old_vblank_offset],ax
	mov		ax,es:[int_vblank_0D_segment]
	mov		[ram_old_vblank_segment],ax
	pop		es
	
	; Save HW mask
	in		al,port_pic_data
	mov		[ram_hw_int_masks],al
	
	; Disable interrupts
	cli
	; Set vertical retrace interrupt
	push	es
	xor		ax,ax
	mov		es,ax ; Set ES to 0
	mov		ax,offset VBLANK_INT
	mov		es:[int_vblank_0D_offset],ax
	mov		ax,cs
	mov		es:[int_vblank_0D_segment],ax
	pop		es
	; Enable interrupts
	sti
	
	;; Unmask vblank
	in		al,port_pic_data
	and		al,mask_enable_vertical_retrace
	cli
	out		port_pic_data,al ;; At this point, VBLANK IS HOT
	sti

	; Set game mode to "waiting_for_vblank"
	mov		al,game_mode_waiting_for_vblank
	mov		[ram_game_mode],al

	;; Wait for VBLANK to set mode to waiting_for_game
GAME_MODE_CMD_WAIT:
	mov		al,[ram_game_mode]
	cmp		al,game_mode_waiting_for_game
	jne		GAME_MODE_CMD_WAIT

	;; Restore HW Mask VBLANK
	cli
	mov		al,[ram_hw_int_masks]
	out		port_pic_data,al ;; AT THIS POINT, VBLANK IS COLD
	sti
	
	;; Disable interrupts
	cli
	push	es
	xor		ax,ax
	mov		es,ax ; Set ES to 0
	;; Restore vertical retrace interrupt
	mov		[ram_old_vblank_offset],ax
	mov		ax,es:[int_vblank_0D_offset]
	mov		[ram_old_vblank_segment],ax
	mov		ax,es:[int_vblank_0D_segment]
	pop		es
	;; Enable interrupts
	sti
	
	;; Set mode back to menu
	mov		al,game_mode_menu
	mov		[ram_game_mode],al
GAME_MODE_END:
	ret
GAME_MODE_CMD_P ENDP

