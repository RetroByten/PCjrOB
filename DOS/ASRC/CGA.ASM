TITLE PCjrOB Test Program
PAGE 66,80 ; 66 lines per page, 80 characters/line

;; This program will allow the user to send commands to the R.O.B.

;; Changes from Original:
;; Detect PCjr or not (PC)
;; Switch to 320x200
;; Poll 03DAh bit 3 for vertical retrace - PC
;; Swap palettes using bits 3-0 (IRGB) of 03D9h

%OUT Processing EQUATES.ASM
;; General
;bytes_per_word					EQU 02h
;nybble_bit_shift				EQU 04h

;; Modes
;game_mode_waiting_for_game		EQU 00h
;game_mode_waiting_for_vblank	EQU 01h
;game_mode_exit					EQU 02h
;game_mode_menu					EQU 03h
;game_mode_cmd					EQU 04h

;; Ports
;port_pic_cmd					EQU 20h ; PIC Command port
;	val_pic_eoi					EQU 20h ; PIC "End of Interrupt" value to acknowledge interrupt
;port_pic_data					EQU 21h ; PIC Data port
port_cga_color					EQU 3D9h 
port_vga_register				EQU 3DAh
	vga_address_mode_ctrl1		EQU 00h
	vga_address_palette0		EQU 10h

;; Memory Segments
segment_interrupt_vector_table	EQU 0000h
segment_video_memory			EQU 0B800h
segment_bios_rom				EQU 0F000h
	bios_rom_machine_id			EQU 0FFFEh ;
	val_machine_id_pcjr			EQU 0FDh
;; Masks
;mask_enable_vertical_retrace	EQU 0DFh ; 1101 1111
mask_poll_vertical_retrace_bit	EQU 08h ; xxx0 1000, Reg 3DA

;; Colors
color_black						equ 00h
color_green						equ 0Ah
;color_yellow					equ 0Eh

;; Video memory words
;video_memory_size_bytes			EQU 4000h
;video_memory_size_words			EQU video_memory_size_bytes / bytes_per_word

;; Interrupts
int_video_10					EQU	10h
	svc_video_set_mode			EQU 00h
		val_mode_40_25_bw		EQU 00h
		val_mode_80_25_bw		EQU 02h
		val_mode_320_200_co		EQU 04h
		val_mode_160_200_co		EQU 08h
		;val_mode_a				EQU val_mode_40_25_bw
		;val_mode_b				EQU val_mode_160_200_co
		;val_mode_b				EQU val_mode_320_200_co
	svc_video_set_palette		EQU 0Bh
	svc_video_get_mode			EQU 0Fh
	svc_video_write_char_tty	EQU	0Eh
	tty_page					EQU 00h
int_keyboard_16					EQU 16h
	svc_keyboard_read_chr		EQU 00h
	svc_keyboard_input_status	EQU 01h
	val_esc_key					EQU 1Bh
int_dos_21						EQU 21h
	svc_dos_print_str			EQU 09h
	svc_dos_set_interrupt		EQU 25h
	svc_dos_terminate			EQU 4Ch
		val_dos_terminate_0		EQU 00h


CODESEG SEGMENT
	assume CS:CODESEG, DS:CODESEG, SS:CODESEG
ORG 100h
PROGRAM: ; Needed for COM to later terminate the program
jmp	MAIN

%OUT Processing PROCS.ASM

%OUT Processing MAIN
MAIN PROC NEAR
SETUP:
	mov		ax,cs
	mov		ds,ax ; Setup DS
	;; SAVE_VIDEO
	mov		ah,svc_video_get_mode
	int		int_video_10 ; AL=videomode, BH=active page
	mov		[ram_save_video_mode],al
	;mov	[ram_save_video_page],bh ;; TODO - eventually look up if valid on 5150
	;; SAVE_MACHINE_ID - Not strictly necessary but saves us segment switches
	mov		ax,segment_bios_rom
	mov		es,ax
	mov		al,es:[bios_rom_machine_id]
	mov		[ram_machine_id],al
MENU:
	;; Initialize Menu Video
	mov		al,val_mode_320_200_co
	mov		ah,svc_video_set_mode
	int		int_video_10
	;; Print MENU
	mov		dx,offset menu_options
	mov		ah,svc_dos_print_str
	int		int_dos_21
MENU_KEY_LOOP:
	mov		ah,svc_keyboard_read_chr
	int		int_keyboard_16

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
	
	cmp		al,'q' ;; Quit
		je		MENU_DONE ;; BAIL OUT
MENU_I:
	cmp		al,'i' ;; Special case
	jne		MENU_TOO_LOW
		mov		al,10h ; Command [16]
		mov		[ram_command_index],al
		jmp		COMMAND ;; EXECUTE COMMAND
MENU_TOO_LOW:
	cmp		al,'0'
	jb		MENU_KEY_LOOP ;; INVALID
MENU_NUM:
	cmp		al,'9'
	ja		MENU_BELOW_LETTER
		;; Valid number here
		sub		al,'0' ; Result is 0-9
		mov		[ram_command_index],al
		jmp		COMMAND ;; EXECUTE COMMAND
MENU_BELOW_LETTER:
	cmp		al,'a'
	jb		MENU_KEY_LOOP ;; INVALID
MENU_LETTER:
	cmp		al,'f'
	ja		MENU_KEY_LOOP ;; INVALID
		sub		al,'a'
		add		al,0ah ;; Result is A-F
		mov		[ram_command_index],al
		jmp		COMMAND ;; EXECUTE COMMAND
ERROR_IN_LOGIC: ;; SHOULD NOT GET HERE
	jmp		MENU_KEY_LOOP
MENU_DONE:
	jmp		RESTORE_VIDEO
	
COMMAND: ;; Command index is in [ram_command_index]
	;; Initialize CMD Video
	mov		al,val_mode_320_200_co
	mov		ah,svc_video_set_mode
	int		int_video_10
	;; Retrieve intended Command
	xor		bh,bh ; zero bh
	mov		bl,[ram_command_index] ; command index, 00-10h
	shl		bx,1 ; multiply by 2 (because it is indexing a 2-byte word table)
	mov		ax,[command_words][bx] ; retrieve actual command word
	mov		[ram_command_word],ax ; Store command word
	;; Setup bit shift counter
	xor		al,al ; Set current shift count to 0
	mov		[ram_command_count],al ; Will be used to shift left bits 15-0
	
	;; Setup dx
	mov		dx,port_vga_register
COMMAND_WAIT_FOR_NOT_VBLANK: ; Wait until poll_vertical_retrace_bit == 0
	;; Since technically we could've gotten here in the middle
	;; of a VLANK, wait until this one ends
	in		al,dx ;; Read in CRTC display status
	test	al,mask_poll_vertical_retrace_bit ; Set ZF if al && mask = 0, if vtrace inactive, bit = 0
	jz		COMMAND_WAIT_FOR_NOT_VBLANK
PREP_FOR_VBLANK:
	;; Ok set up for the coming VBLANK
	
	;; Check command count
	mov		al,[ram_command_count]
	cmp		al,0Fh ; Commands are 16 bits (0-15), incremented after this point so bail "at" 16
		je		COMMAND_DONE ;; If 16, we're done, go back to the MENU
	inc		al ;; Otherwise, increment AL
	mov		[ram_command_count],al ; Store 
	
	;; Get current frame bit (1 or 0)
	mov		ax,[ram_command_word] ; Grab current command word
	shl		ax,1 ; Grab current MSB
	mov		[ram_command_word],ax ; Store back for next go around
	;; If carry, set green
	jc		SET_GREEN
SET_BLACK:
	mov		al,color_black
	jmp		GOT_COLOR
SET_GREEN:
	mov		al,color_green
GOT_COLOR:
	;; Now that we've got color, we should get the machine id out of RAM
	mov		ah,[ram_machine_id]
	push	ax ;; Save off AX
COMMAND_WAIT_FOR_VBLANK: ;; AH = machineid, AL = color for this frame
	;; Wait until at the top of a new VBLANK
	in		al,dx ;; Read in CRTC display status
	test	al,mask_poll_vertical_retrace_bit ; Unset ZF if al && mask = 1, if vtrace active, bit = 1
	jnz		COMMAND_WAIT_FOR_VBLANK
;; Ok now we're in a fresh VBLANK, GOGOGOGOGOGO!
	pop		ax ; Retrieve our flags
	cmp		ah,val_machine_id_pcjr
	je		PCJR
PCSR: ; We're a PC Senior
	mov		dx,port_cga_color ;; temporarily swap the port
	out		dx,al ; Send the color!
	mov		dx,port_vga_register ;; Put the port back to status port
	jmp		VBLANK_LOOP ;; GO AROUND AGAIN
PCJR: ; We're a PCjr, we've got some work to do
	push	ax
	cli
	in		al,dx ; force VGA register in address mode
	mov		al,vga_address_palette0
	out		dx,al ; Set VGA address register to palette 0, now in value mode
	pop		ax
	out		dx,al ; Put color into palette 0, back in address move
	mov		al,vga_address_mode_ctrl1 ; Put in
	out		dx,al ; Sets address to < 10h
	in		al,dx ; We're done Now
	sti
VBLANK_LOOP:
	;jmp	PREP_FOR_VBLANK
	jmp COMMAND_WAIT_FOR_NOT_VBLANK
	
COMMAND_DONE:
	jmp		MENU ;; Go back to the menu
	
	
	
RESTORE_VIDEO:
	mov		ax,cs
	mov		ds,ax
	mov		al,[ram_save_video_mode]
	mov		ah,svc_video_set_mode
	int		int_video_10
EXIT2DOS:
	mov		ax,(svc_dos_terminate SHL 8) OR val_dos_terminate_0 
	int		int_dos_21 ;; EXIT to DOS
HALT:
	jmp		HALT ; In case DOS somehow doesn't end the program, should never reach
MAIN ENDP

;; RAM Values
ram_save_video_mode db ?
ram_save_video_page db ?
ram_machine_id db ?
ram_game_mode db ?
ram_command_index db ?
ram_command_word dw ?
ram_command_count db ?

ram_old_vblank_offset dw ?
ram_old_vblank_segment dw ?

ram_hw_int_masks db ?

;ram_current_color db ?

screenA db "Screen A$"
screenB db "Screen B$"
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