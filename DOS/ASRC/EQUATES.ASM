;; General
bytes_per_word					EQU 02h
nybble_bit_shift				EQU 04h

;; Modes
game_mode_waiting_for_game		EQU 00h
game_mode_waiting_for_vblank	EQU 01h
game_mode_exit					EQU 02h
game_mode_menu					EQU 03h
game_mode_cmd					EQU 04h

;; Ports
port_pic_cmd					EQU 20h ; PIC Command port
	val_pic_eoi					EQU 20h ; PIC "End of Interrupt" value to acknowledge interrupt
port_pic_data					EQU 21h ; PIC Data port
port_vga_register				EQU 3DAh
	vga_address_mode_ctrl1		EQU 00h
	vga_address_palette0		EQU 10h

;; Memory Segments
segment_interrupt_vector_table	EQU 0000h
segment_video_memory			EQU 0B800h

;; Masks
mask_enable_vertical_retrace	EQU 0DFh ; 1101 1111

;; Colors
color_black						equ 00h
color_green						equ 0Ah
;color_yellow					equ 0Eh

;; Video memory words
video_memory_size_bytes			EQU 4000h
video_memory_size_words			EQU video_memory_size_bytes / bytes_per_word

;; Interrupts
int_video_10					EQU	10h
	svc_video_set_mode			EQU 00h
		val_mode_40_25_bw		EQU 00h
		val_mode_80_25_bw		EQU 02h
		val_mode_320_200_co		EQU 04h
		val_mode_160_200_co		EQU 08h
		val_mode_a				EQU val_mode_40_25_bw
		val_mode_b				EQU val_mode_160_200_co
	svc_video_set_page			EQU 05h
		val_set_cpu_page		EQU 81h
		val_set_crt_page		EQU 82h
		val_set_cpucrt_page		EQU 83h
		val_page_0				EQU 07h
		val_page_1				EQU 06h
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
int_vblank_0D					EQU 0Dh
	int_vblank_0D_offset		EQU int_vblank_0D * 04h
	int_vblank_0D_segment		EQU int_vblank_0D_offset + 02h
