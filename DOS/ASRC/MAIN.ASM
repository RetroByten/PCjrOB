TITLE PCjrOB Test Program

; This program will send the "TEST" command to R.O.B., turning on the head LED

;; TODO -
; 1.) Add keyboard reading (esc to quit) to send up, down, left, right, a (open), b (close)
; 2.) Display command on second page
; 3.) Make the command storage more compact/efficient
; 4.) Fix the initial entry to the loop, shouldn't need repeat the setup stuff

INCLUDE EQUATES.ASM

CODESEG SEGMENT
	assume CS:CODESEG, DS:CODESEG, SS:CODESEG
ORG 100h
PROGRAM: ; Needed for COM to later terminate the program
jmp	MAIN

FILL_COLOR PROC NEAR
	push	es
	mov		ax,segment_video_memory
	mov		es,ax
	xor		di,di ; B800:0000
	mov		ax, (color_black SHL 12) OR (color_black SHL 8) OR (color_black SHL 4) OR color_black 
	mov		cx,video_memory_size_words
	cld
	rep		stosw
	pop		es
	ret
FILL_COLOR ENDP

;; Video Mode Functions
SAVE_VIDEO_MODE PROC NEAR
	mov		ah,svc_video_get_mode
	int		int_video_10
	mov		[ram_video_mode],al
	ret
SAVE_VIDEO_MODE ENDP
SET_VIDEO_MODE PROC NEAR
	mov		ax,(svc_video_set_mode SHL 8) OR val_mode_160_200_co
	;mov	ax,(svc_video_set_mode SHL 8) OR val_mode_80_25_bw
	int		int_video_10
	ret
SET_VIDEO_MODE ENDP
RESTORE_VIDEO_MODE PROC NEAR
	mov		ah,svc_video_set_mode
	mov		al,[ram_video_mode]
	int		int_video_10
	ret
RESTORE_VIDEO_MODE ENDP

;; VBlank Interrupt Vector Functions
VBLANK_INT PROC NEAR
	sti ; Re-enable interrupts so other timers can fire
	push	ax
	push	dx
	push	ds
		;; Setup DS - can't assume it's good
		mov		ax,cs
		mov		ds,ax
		;; Check if game was still processing frame
		mov		al,[ram_game_mode]
		cmp		al,game_mode_waiting_for_vblank
		jnz		VBLANK_UNROLL ; if it was, just bail out
		
		;; VBLANK START WORK -----
		; Get color
		mov		al,[current_color]
		; swap palette 0
		mov		dx,port_vga_register
		cli ;; TODO - also mask keyboard interrupt
			in		al,dx
			mov		al,vga_address_palette0
			out		dx,al ; Put VGA register into address state
			mov		al,[current_color]
			out		dx,al
			mov		al,vga_address_mode_ctrl1
			out		dx,al  ; Set address back to < 10h
			in		al,dx ; Put VGA register into address state, probably isn't necessary
		sti
		;; VBLANK END WORK -----
		
		;; Update game state
		mov		al,game_mode_waiting_for_game
		mov		[ram_game_mode],al
VBLANK_UNROLL:
		mov		al,val_pic_eoi
		out		port_pic_cmd,al ; Acknowledge the hardware interrupt
	pop		ds
	pop		dx
	pop		ax
	iret
VBLANK_INT ENDP
SAVE_VBLANK_INT_VEC PROC NEAR
	push	es
	mov		ax,segment_interrupt_vector_table
	mov		es,ax
	mov		ax,es:[int_vblank_0D_offset]
	mov		[ram_vblank_int_offset],ax
	mov		ax,es:[int_vblank_0D_segment]
	mov		[ram_vblank_int_segment],ax
	pop		es
	ret
SAVE_VBLANK_INT_VEC ENDP
SET_VBLANK_INT_VEC PROC NEAR
	push	es
	mov		ax,segment_interrupt_vector_table
	mov		es,ax
	cli		;; TODO - also mask keyboard interrupt
		mov		ax,offset VBLANK_INT
		mov		es:[int_vblank_0D_offset],ax
		mov		ax,cs
		mov		es:[int_vblank_0D_segment],ax
	sti
	pop		es
	ret
SET_VBLANK_INT_VEC ENDP
RESTORE_VBLANK_INT_VEC PROC NEAR
	push	es
	mov		ax,segment_interrupt_vector_table
	mov		es,ax
	cli		;; TODO - also mask keyboard interrupt
		mov		ax,[ram_vblank_int_offset]
		mov		es:[int_vblank_0D_offset],ax
		mov		ax,[ram_vblank_int_segment]
		mov		es:[int_vblank_0D_segment],ax
	sti
	pop		es
	ret
RESTORE_VBLANK_INT_VEC ENDP

;; HW Interrupt Mask functions
SAVE_HW_INT_MASKS PROC NEAR
	in		al,port_pic_data
	mov		[ram_hw_int_masks],al
	ret
SAVE_HW_INT_MASKS ENDP
SET_HW_INT_MASKS PROC NEAR
	in		al,port_pic_data
	and		al,mask_enable_vertical_retrace
	cli
		out		port_pic_data,al
	sti
	ret
SET_HW_INT_MASKS ENDP
RESTORE_HW_INT_MASKS PROC NEAR
	cli			;; TODO - also mask keyboard interrupt
		mov		al,[ram_hw_int_masks]
		out		port_pic_data,al
	sti
	ret
RESTORE_HW_INT_MASKS ENDP

SAVE PROC NEAR
	call	SAVE_VIDEO_MODE
	call	SAVE_VBLANK_INT_VEC
	call	SAVE_HW_INT_MASKS
	ret
SAVE ENDP
SET PROC NEAR
	call	SET_VIDEO_MODE
	call	FILL_COLOR
	call	SET_VBLANK_INT_VEC
	call	SET_HW_INT_MASKS
	ret
SET ENDP
RESTORE PROC NEAR
	call	RESTORE_HW_INT_MASKS
	call	RESTORE_VBLANK_INT_VEC
	call	RESTORE_VIDEO_MODE
	ret
RESTORE ENDP
EXIT2DOS PROC NEAR
	mov		ax,(svc_dos_terminate SHL 8) OR val_dos_terminate_0 
	int		int_dos_21 ;; EXIT to DOS
HALT:
	jmp		HALT ; In case DOS somehow doesn't end the program, should never reach
EXIT2DOS ENDP

MAIN PROC NEAR
	mov		ax,cs	;; Setup DS
	mov		ds,ax

	call	SAVE
;; START PROGRAM ------------
	; SET INITIAL MODE
	mov		al,game_mode_waiting_for_game
	mov		[ram_game_mode],al
	; SET INITIAL COUNTER
	xor		al,al
	mov		[ram_vblank_counter],al
	;; Look up first color
	mov		al,[ram_vblank_counter]
	mov		bx,offset test_command_array
	xlat
	mov		[current_color],al
	mov		al,game_mode_waiting_for_vblank
	mov		[ram_game_mode],al
	
	; START 
	call	SET
MAINLOOP:
	mov		al,[ram_game_mode]
	cmp		al,game_mode_waiting_for_vblank
	jz		MAINLOOP ;; Sit here until VBLANK fires

	; Inc the vblank counter
	mov		al,[ram_vblank_counter]
	inc		al
	mov		[ram_vblank_counter],al
	
	cmp		al,10h ; Check if end of sequence
	jz		MAINLOOPEND ;
	
	;; Else look up the next color and store it
	mov		al,[ram_vblank_counter]
	mov		bx,offset test_command_array
	xlat
	mov		[current_color],al
	;; Set the mode to waiting for VBLANK
	mov		al,game_mode_waiting_for_vblank
	mov		[ram_game_mode],al
	jmp		MAINLOOP
MAINLOOPEND:
;; END PROGRAM ------------
	call	RESTORE
	jmp		EXIT2DOS ;; Intentional jump to not leave data on the stack
MAIN ENDP

ram_video_mode db ?
ram_hw_int_masks db ?
ram_vblank_int_offset dw ?
ram_vblank_int_segment dw ?
ram_vblank_counter db ?
ram_game_mode db ?

current_color db ?

; References for commands
;https://www.nesdev.org/wiki/R.O.B.
;http://problemkaputt.de/everynes.htm#robroboticoperatingbuddy
; Preface - 000101 w1x1y1z0
command_words dw 00010101010100B ;0000 - Unused
dw 00010101010110;0001 - Reset
dw 00010101010100;0010 - Down1 (1-step)
dw 00010101011110;0011 - Unused
dw 00010101110100;0100 - Left (1-step)
dw 00010101110110;0101 - Up2 (2-steps)
dw 00010101111100;0110 - Close (Arms)
dw 00010101111110;0111 - Unused

dw 00010111010100;1000 - Right (1-step)
dw 00010111010110;1001 - TEST (LED ON)
dw 00010111011100;1010 - Open (Arms)
dw 00010111011110;1011 - Unused
dw 00010111110100;1100 - Up1 (1-step)
dw 00010111110110;1101 - Down2 (2-steps)
dw 00010111111100;1110 - Unused
dw 00010111111110;1111 - Unused
dw 10101010101010; Blinks LED (allegedly) if keep repeating

; In this case, just the Turn HEAD LED ON COMMAND IS SENT
; Currently just hardcodes the color into it
test_command_array db 00h,00h,00h,00h,00h,0Ah,00h,0Ah,0Ah,0Ah,00h,0Ah,00h,0Ah,0Ah,00h 

CODESEG ENDS
END PROGRAM
