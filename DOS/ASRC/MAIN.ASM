TITLE PCjrOB Test Program

;MAIN
;	SETUP_DS +
;	SAVE +
;		call	SAVE_VIDEO_MODE +
;		call	SAVE_VBLANK_INT_VEC +
;		call	SAVE_HW_INT_MASKS
;	SET +
;		call	SET_VIDEO_MODE +
;		call	SET_VBLANK_INT_VEC +
;		call	SET_HW_INT_MASKS +
;	RESTORE +
;		call	RESTORE_HW_INT_MASKS +
;		call	RESTORE_VBLANK_INT_VEC +
;		call	RESTORE_VIDEO_MODE +
;	EXIT2DOS

INCLUDE EQUATES.ASM

CODESEG SEGMENT
	assume CS:CODESEG, DS:CODESEG, SS:CODESEG
ORG 100h
PROGRAM: ; Needed for COM to later terminate the program
jmp	MAIN

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
	push	ds
		mov		ax,cs
		mov		ds,ax
		mov		al,[ram_vblank_counter]
		inc		al
		mov		[ram_vblank_counter],al
		mov		al,val_pic_eoi
		out		port_pic_cmd,al ; Acknowledge the hardware interrupt
	pop		ds
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
	xor		al,al
	mov		[ram_vblank_counter],al
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
	call	SET
MAINLOOP:
	mov		al,[ram_vblank_counter]
	cmp		al,0FFh
	jnz		MAINLOOP
;; END PROGRAM ------------
	call	RESTORE
	jmp		EXIT2DOS ;; Intentional jump to not leave data on the stack
MAIN ENDP

ram_video_mode db ?
ram_hw_int_masks db ?
ram_vblank_int_offset dw ?
ram_vblank_int_segment dw ?
ram_vblank_counter db ?

CODESEG ENDS
END PROGRAM
