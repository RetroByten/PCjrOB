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
MENU_KEY_LOOP:
	;; KEY PRESS LOGIC
	;; Check if 'q' - if equal Quit, direct case, MENU_DONE
	;; Check if 'i' - if equal command 16, direct case, EXECUTE COMMAND
	;; Check if below '0', if so invalid, jump back up
	;; Check if above '9', if not means number is between 0 and 9
		;; subtract '0', EXECUTE COMMAND
	;; Check if below 'a', if so invalid, jump back up
	;; Check if above 'f', if not means number is between a and for
		;; subtract 'a', add 0Ah, EXECUTE COMMAND 
	;; ERROR_IN_LOGIC: jump back up
	
	mov		ah,svc_keyboard_read_chr
	int		int_keyboard_16
	
	cmp		al,'q' ;; Quit
	jne		MENU_I 
		mov		al,game_mode_exit
		mov		[ram_game_mode],al ;; Set mode to EXIT
		ret ;; RETURN
MENU_I:
	cmp		al,'i' ;; Special case
	jne		MENU_TOO_LOW
		mov		al,10h ; Command [16]
		mov		[ram_command_index],al ;; Save CMD
		mov		al,game_mode_cmd
		mov		[ram_game_mode],al  ;; Set mode to CMD
		ret ;; RETURN
MENU_TOO_LOW:
	cmp		al,'0' ; if < '0', invalid entry
	jb		MENU_KEY_LOOP ;; INVALID, TRY AGAIN
MENU_NUM:
	cmp		al,'9' ;; '0' <= al <= '9', valid!
	ja		MENU_BELOW_LETTER
		sub		al,'0' ; Normalize to 0-9h
		mov		[ram_command_index],al ;; Save CMD
		mov		al,game_mode_cmd
		mov		[ram_game_mode],al  ;; Set mode to CMD
		ret ;; RETURN
MENU_BELOW_LETTER:
	cmp		al,'a' ; if '9' < al < 'a', invalid entry
	jb		MENU_KEY_LOOP ;; INVALID, TRY AGAIN
MENU_LETTER:
	cmp		al,'f'
	ja		MENU_KEY_LOOP ;; INVALID, TRY AGAIN
		;; if 'a' <= al <= 'f', valid!
		sub		al,'a' ;; Normalize to 0
		add		al,0ah ;; Normalize to A-Fh
		mov		[ram_command_index],al  ;; Save CMD
		mov		al,game_mode_cmd
		mov		[ram_game_mode],al  ;; Set mode to CMD
		ret ;; RETURN
ERROR_IN_LOGIC: ;; SHOULD NOT GET HERE
	jmp		MENU_KEY_LOOP
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