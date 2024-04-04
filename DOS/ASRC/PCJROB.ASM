TITLE PCjrOB Test Program
PAGE 66,80 ; 66 lines per page, 80 characters/line

;; This program will allow the user to send commands to the R.O.B.

%OUT Processing EQUATES.ASM
INCLUDE EQUATES.ASM

CODESEG SEGMENT
	assume CS:CODESEG, DS:CODESEG, SS:CODESEG
ORG 100h
PROGRAM: ; Needed for COM to later terminate the program
jmp	MAIN

%OUT Processing PROCS.ASM
INCLUDE PROCS.ASM

;; Outline
; 0.) Setup Default Segments (DS, ES)
; 1.) Save current video configuration
; 2.) Initialize mode (MENU)
; 3.) Program Loop - check what mode it is in, 
;     jump to function for that mode
;     3a.) Mode - MENU
;       
;     3b.) Mode - CMD
;     3c.) Mode - EXIT
; 4.) Restore Video 
; 5.) Return to DOS

%OUT Processing MAIN
MAIN PROC NEAR
	call	SETUP_DEFAULT_SEGMENTS
	
SAVE_STATE:
	call	SAVE_VIDEO
	
INITIALIZE:
	mov		al,game_mode_menu
	mov		[ram_game_mode],al

GAME_LOOP:
	mov		al,[ram_game_mode]
GAME_LOOP_EXIT:
	cmp		al,game_mode_exit
		je		RESTORE_STATE
GAME_LOOP_MENU:
	cmp		al,game_mode_menu
	jne		GAME_LOOP_CMD
		call	GAME_MODE_MENU_P
	jmp		GAME_LOOP_CONTINUE
GAME_LOOP_CMD:
	cmp		al,game_mode_cmd
	jne		GAME_LOOP_CONTINUE
		call GAME_MODE_CMD_P
	jmp		GAME_LOOP_CONTINUE
	
GAME_LOOP_CONTINUE:
	jmp		GAME_LOOP
RESTORE_STATE:
	call	RESTORE_VIDEO
EXIT2DOS:
	mov		ax,(svc_dos_terminate SHL 8) OR val_dos_terminate_0 
	int		int_dos_21 ;; EXIT to DOS
HALT:
	jmp		HALT ; In case DOS somehow doesn't end the program, should never reach
MAIN ENDP

;; RAM Values
ram_save_video_mode db ?
ram_save_video_page db ?
ram_game_mode db ?
ram_command_index db ?
ram_command_word dw ?
ram_command_count db ?
ram_old_vblank_offset dw ?
ram_old_vblank_segment dw ?
ram_hw_int_masks db ?
ram_current_color db ?

; References for commands
;https://www.nesdev.org/wiki/R.O.B.
;http://problemkaputt.de/everynes.htm#robroboticoperatingbuddy
; Preface - 000101 w1x1y1z0
command_words 	dw 00010101010100B;0000 - Unused
				dw 00010101010110B;0001 - Reset
				dw 00010101011100B;0010 - Down1 (1-step) 01 01 11 00
				dw 00010101011110B;0011 - Unused
				dw 00010101110100B;0100 - Left (1-step)
				dw 00010101110110B;0101 - Up2 (2-steps)
				dw 00010101111100B;0110 - Close (Arms)
				dw 00010101111110B;0111 - Unused

				dw 00010111010100B;1000 - Right (1-step)
				dw 00010111010110B;1001 - TEST (LED ON)
				dw 00010111011100B;1010 - Open (Arms)
				dw 00010111011110B;1011 - Unused
				dw 00010111110100B;1100 - Up1 (1-step)
				dw 00010111110110B;1101 - Down2 (2-steps)
				dw 00010111111100B;1110 - Unused
				dw 00010111111110B;1111 - Unused
				dw 10101010101010B; Blinks LED (allegedly) if keep repeating

menu_options db "R.O.B. Command Menu Options: ",0Dh,0Ah
db "	0.) Unused1",0Dh,0Ah
db "	1.) Reset",0Dh,0Ah
db "	2.) Down1",0Dh,0Ah
db "	3.) Unused2",0Dh,0Ah
db "	4.) Left",0Dh,0Ah
db "	5.) Up2",0Dh,0Ah
db "	6.) Close",0Dh,0Ah
db "	7.) Unused3",0Dh,0Ah

db "	8.) Right",0Dh,0Ah
db "	9.) TEST (LED ON)",0Dh,0Ah
db "	a.) Open",0Dh,0Ah
db "	b.) Unused4",0Dh,0Ah
db "	c.) Up1",0Dh,0Ah
db "	d.) Down2",0Dh,0Ah
db "	e.) Unused5",0Dh,0Ah
db "	f.) Unused6",0Dh,0Ah

db "	i.) Blinks LED (allegedly)",0Dh,0Ah
db "	q.) Quit",0Dh,0Ah,'$'

CODESEG ENDS
END PROGRAM
