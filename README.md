# PCjrOB
A set of code examples attempting to control the R.O.B. accessory with the PCjr.

WARNING: As with R.O.B.-compatible games on the NES, the screen flashes rapidly for 16 frames (~0.256s) cycling between black and a single solid color (CGA light green in this case) in a pattern that results in a command being sent. This is inherantly how the peripheral works. If you are sensitive to screen flashing do not run this program.

NOTE: These programs require the PCjr/PC to output to a CRT display as the R.O.B. circitry is reliant on the behavior of CRTs. 

Programs:
PCJROB.COM - This is an example program allowing the user to, via a menu, choose individual commands to send to the R.O.B. accessory. It only works on the PCjr as it uses the 40x25 black and white text mode for the menu and 160x200 color graphics mode for the commands. It also uses PCjr-specific palette switching and vertical retrace interrupts.

CGAROB.COM - This is an example program allowing the user to, via a menu, choose individual commands to send to the R.O.B. accessory. It works on the PCjr and *should* work on CGA compatible PCs (e.g. IBM PC 5150 w/ CGA) but I don't have the ability to test it on non-PCjr platforms. It uses 320x200 color graphics mode for the menu and commands.
