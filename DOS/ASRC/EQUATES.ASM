;; EQUATES

;; Ports
port_pic_cmd					EQU 20h ; PIC Command port
	val_pic_eoi						EQU 20h ; PIC "End of Interrupt" value to acknowledge interrupt
port_pic_data					EQU 21h ; PIC Data port

;; Memory Segments
segment_interrupt_vector_table	EQU 0000h

;; Masks
mask_enable_vertical_retrace	EQU 0DFh ; 1101 1111

;; Interrupts
int_video_10					EQU	10h
	svc_video_set_mode			EQU 00h
		val_mode_80_25_bw		EQU 02h
		val_mode_160_200_co		EQU 08h
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
int_vblank_0D					EQU 0Dh
	int_vblank_0D_offset		EQU int_vblank_0D * 04h
	int_vblank_0D_segment		EQU int_vblank_0D_offset + 02h
