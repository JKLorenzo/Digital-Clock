	list p=pic18f4550
	include "p18f4550.inc"

SS		EQU		0x00
SCK		EQU		0x01
SDI		EQU		0x00
SDO		EQU		0x07
RS  	EQU 	0x04
EN  	EQU 	0x05

	CBLOCK 0x20
		temp_data_0
		temp_data_1

		counter_1
		counter_2
		lcd_data
		lcd_cmd
		lcd_location

		command
		seconds
		minutes
		hours
		date
		month
		day
		year
	ENDC

	ORG 0x00
	GOTO main
	ORG 0x08

init_port
	; SPI pins
	BCF TRISC, SS
	BCF TRISC, SDO
	BCF TRISB, SCK
	BSF TRISB, SDI

	; LCD pins
	BCF TRISC, EN
	BCF TRISC, RS
	CLRF TRISD

	MOVLW 0x07
	MOVWF ADCON1
	RETURN

init_lcd
	; set 25ms delay after the power rises to 4.5V
	MOVLW 0x19
	call ms_delay
	; set DB1 = 0, DB0 = 0
	BCF PORTD, 0
	BCF PORTD, 1
	; function set
	; DB7:DB0 = 001DL NF0
	; RS = 0
	; RW = 0
	; DB7:DB6 = 0
	; DB5 = 1
	; DB4 (DL) = 1 for 8-bit interface, 0 for 4-bit interface
	; DB3 (N) = 1 2 lines, 0 1 lines
	; DB2 (F) = 1 character size is 5x10, 0 character size is 5x7
	; 0x38 = 0011 1000 (DL = 1, N = 1, F = 0)
	MOVLW 0x38
	MOVWF lcd_cmd
	CALL lcd_write_cmd
	; display on/off control
	; DB7:DB0 = 0000 1DCB
	; RS = 0
	; RW = 0
	; DB7:DB4 = 0
	; DB3 = 1
	; DB2 (D) = 1 display is on, 0 display is off
	; DB1 (C) = 1 cursor is on, 0 cursor is off
	; DB0 (B) = 1 cursor blinking is on, 0 cursor blink is off
	; 0x0C = 0000 1100 (D = 1, C = 0, B = 0)
	MOVLW 0x0C
	MOVWF lcd_cmd
	CALL lcd_write_cmd; entry mode
	; DB7:DB0 = 0000 01I/DS
	; RS = 0
	; RW = 0
	; DB7:DB3 = 0
	; DB2 = 1
	; DB1 (I/D) = 1 increment cursor position, 0 decrement cursor position
	; DB0 (S) = 1 shift display enabled, 0 shift display disableD
	; 0x06 = 0000 0110 (I/D = 1, S = 0)
	MOVLW 0x06
	MOVWF lcd_cmd
	CALL lcd_write_cmd
	RETURN

main
	CALL init_port
	CALL init_lcd
	CALL clear_lcd_display

	; SS = 1, disable slave
	BSF PORTC, SS
	
	; SMP <bit7> = 0, sampled at middle of data output time
	; CKE <bit6> = 0, idle to active clock state
	CLRF SSPSTAT
	; WCOL <bit7> = 0, no collision
	; SSPOV <bit6> = 0, no overflow
	; SSPEN <bit5> = 0, disable SPI
	; CKP <bit4> = 0, idle state is low
	; SSPM3:SSPM0 <bit3:0> = 0000, FOSC/4
	CLRF SSPCON1
	BSF SSPCON1, SSPEN

	; clear SSPIF
	BCF PIR1, SSPIF

wait
	CALL get_data
	CALL process_display
	; 1000 ms delay
	MOVLW 0xFF
	CALL ms_delay
	CALL ms_delay
	CALL ms_delay
	GOTO wait

get_data
	; SS = 0, enable slave
	BCF PORTC, SS
	; burst mode
	MOVLW 0xBF
	MOVWF command
	; initial
	CALL send_receive_data
	; seconds
	CALL send_receive_data
	MOVWF seconds
	; minutes
	CALL send_receive_data
	MOVWF minutes
	; hours
	CALL send_receive_data
	MOVWF hours
	; date
	CALL send_receive_data
	MOVWF date
	; month
	CALL send_receive_data
	MOVWF month
	; day
	CALL send_receive_data
	MOVWF day
	; year
	CALL send_receive_data
	MOVWF year
	; SS = 1, disable slave
	BSF PORTC, SS
	; clear command
	MOVLW 0x00
	MOVWF command
	CALL send_receive_data
	RETURN

process_data
	; Store data
	MOVWF temp_data_0
	
	; Get first digit
	MOVLW 0xF0
	ANDWF temp_data_0, W
	MOVWF temp_data_1
	SWAPF temp_data_1
	MOVLW 0x30
	ADDWF temp_data_1, W
	; Print to LCD
	MOVWF lcd_data
	CALL lcd_write_data

	; Get second digit
	MOVLW 0x0F
	ANDWF temp_data_0, W
	MOVWF temp_data_1
	MOVLW 0x30
	ADDWF temp_data_1, W
	; Print to LCD
	MOVWF lcd_data
	CALL lcd_write_data
	RETURN

process_display
	CALL clear_lcd_display
	CALL move_to_row_1

	; day
	CALL process_day
	
	; set the location of the cursor
	MOVLW 0x09
	MOVWF lcd_location
	CALL set_lcd_location

	; month
	CALL process_month
	; seperator
	MOVLW " "
	CALL lcd_write_w
	; date
	MOVF date, W
	CALL process_data
	; seperator
	MOVLW " "
	CALL lcd_write_w
	; year
	MOVLW 0x20
	CALL process_data
	MOVF year, W
	CALL process_data

	CALL move_to_row_2
	
	MOVLW "T"
	CALL lcd_write_w
	MOVLW "I"
	CALL lcd_write_w
	MOVLW "M"
	CALL lcd_write_w
	MOVLW "E"
	CALL lcd_write_w

	; set the location of the cursor
	MOVLW 0x4C
	MOVWF lcd_location
	CALL set_lcd_location

	; hours
	MOVF hours, W
	CALL process_data
	; seperator
	MOVLW 0x3A
	CALL lcd_write_w
	; minutes
	MOVF minutes, W
	CALL process_data
	; seperator
	MOVLW 0x3A
	CALL lcd_write_w
	; seconds
	MOVF seconds, W
	CALL process_data

	RETURN
	

process_month
	MOVLW 0x12
	SUBWF month, W
	BTFSC STATUS, Z
	GOTO month_12
	MOVLW 0x11
	SUBWF month, W
	BTFSC STATUS, Z
	GOTO month_11
	MOVLW 0x10
	SUBWF month, W
	BTFSC STATUS, Z
	GOTO month_10
	MOVLW 0x09
	SUBWF month, W
	BTFSC STATUS, Z
	GOTO month_09
	MOVLW 0x08
	SUBWF month, W
	BTFSC STATUS, Z
	GOTO month_08
	MOVLW 0x07
	SUBWF month, W
	BTFSC STATUS, Z
	GOTO month_07
	MOVLW 0x06
	SUBWF month, W
	BTFSC STATUS, Z
	GOTO month_06
	MOVLW 0x05
	SUBWF month, W
	BTFSC STATUS, Z
	GOTO month_05
	MOVLW 0x04
	SUBWF month, W
	BTFSC STATUS, Z
	GOTO month_04
	MOVLW 0x03
	SUBWF month, W
	BTFSC STATUS, Z
	GOTO month_03
	MOVLW 0x02
	SUBWF month, W
	BTFSC STATUS, Z
	GOTO month_02
	GOTO month_01

month_12
	MOVLW "D"
	CALL lcd_write_w
	MOVLW "E"
	CALL lcd_write_w
	MOVLW "C"
	CALL lcd_write_w
	RETURN
month_11
	MOVLW "N"
	CALL lcd_write_w
	MOVLW "O"
	CALL lcd_write_w
	MOVLW "V"
	CALL lcd_write_w
	RETURN
month_10
	MOVLW "O"
	CALL lcd_write_w
	MOVLW "C"
	CALL lcd_write_w
	MOVLW "T"
	CALL lcd_write_w
	RETURN
month_09
	MOVLW "S"
	CALL lcd_write_w
	MOVLW "E"
	CALL lcd_write_w
	MOVLW "P"
	CALL lcd_write_w
	RETURN
month_08
	MOVLW "A"
	CALL lcd_write_w
	MOVLW "U"
	CALL lcd_write_w
	MOVLW "G"
	CALL lcd_write_w
	RETURN
month_07
	MOVLW "J"
	CALL lcd_write_w
	MOVLW "U"
	CALL lcd_write_w
	MOVLW "L"
	CALL lcd_write_w
	RETURN
month_06
	MOVLW "J"
	CALL lcd_write_w
	MOVLW "U"
	CALL lcd_write_w
	MOVLW "N"
	CALL lcd_write_w
	RETURN
month_05
	MOVLW "M"
	CALL lcd_write_w
	MOVLW "A"
	CALL lcd_write_w
	MOVLW "Y"
	CALL lcd_write_w
	RETURN
month_04
	MOVLW "A"
	CALL lcd_write_w
	MOVLW "P"
	CALL lcd_write_w
	MOVLW "R"
	CALL lcd_write_w
	RETURN
month_03
	MOVLW "M"
	CALL lcd_write_w
	MOVLW "A"
	CALL lcd_write_w
	MOVLW "R"
	CALL lcd_write_w
	RETURN
month_02
	MOVLW "F"
	CALL lcd_write_w
	MOVLW "E"
	CALL lcd_write_w
	MOVLW "B"
	CALL lcd_write_w
	RETURN
month_01
	MOVLW "J"
	CALL lcd_write_w
	MOVLW "A"
	CALL lcd_write_w
	MOVLW "N"
	CALL lcd_write_w
	RETURN

process_day
	MOVLW 0x07
	SUBWF day, W
	BTFSC STATUS, Z
	GOTO day_7
	MOVLW 0x06
	SUBWF day, W
	BTFSC STATUS, Z
	GOTO day_6
	MOVLW 0x05
	SUBWF day, W
	BTFSC STATUS, Z
	GOTO day_5
	MOVLW 0x04
	SUBWF day, W
	BTFSC STATUS, Z
	GOTO day_4
	MOVLW 0x03
	SUBWF day, W
	BTFSC STATUS, Z
	GOTO day_3
	MOVLW 0x02
	SUBWF day, W
	BTFSC STATUS, Z
	GOTO day_2
	GOTO day_1

day_7
	MOVLW "S"
	CALL lcd_write_w
	MOVLW "A"
	CALL lcd_write_w
	MOVLW "T"
	CALL lcd_write_w
	RETURN
day_6
	MOVLW "F"
	CALL lcd_write_w
	MOVLW "R"
	CALL lcd_write_w
	MOVLW "I"
	CALL lcd_write_w
	RETURN
day_5
	MOVLW "T"
	CALL lcd_write_w
	MOVLW "H"
	CALL lcd_write_w
	MOVLW "U"
	CALL lcd_write_w
	RETURN
day_4
	MOVLW "W"
	CALL lcd_write_w
	MOVLW "E"
	CALL lcd_write_w
	MOVLW "D"
	CALL lcd_write_w
	RETURN
day_3
	MOVLW "T"
	CALL lcd_write_w
	MOVLW "U"
	CALL lcd_write_w
	MOVLW "E"
	CALL lcd_write_w
	RETURN
day_2
	MOVLW "M"
	CALL lcd_write_w
	MOVLW "O"
	CALL lcd_write_w
	MOVLW "N"
	CALL lcd_write_w
	RETURN
day_1
	MOVLW "S"
	CALL lcd_write_w
	MOVLW "U"
	CALL lcd_write_w
	MOVLW "N"
	CALL lcd_write_w
	RETURN

send_receive_data
	MOVF command, W
	MOVWF SSPBUF
check
	; check if buffer is empty (data was transmitted)
	BTFSS PIR1, SSPIF
	GOTO check
	; read data from slave
	MOVF SSPBUF, W
	; clear SSPIF flag
	BCF PIR1, SSPIF
	RETURN

clear_lcd_display
	; clear display
	; RS = 0
	; RW = 0
	; DB7:DB1 = 0
	; DB0 = 1
	MOVLW 0x01
	MOVWF lcd_cmd
	CALL lcd_write_cmd
	RETURN

move_to_row_1
	; Set DDRAM Address
	; RS = 0
	; RW = 0
	; DB7 = 1
	; DB6:DB0 = 000 0000
	; Address of Row 1 Col 1 = 0x00
	MOVLW 0x80
	MOVWF lcd_cmd
	CALL lcd_write_cmd
	RETURN

move_to_row_2
	; Set DDRAM Address
	; RS = 0
	; RW = 0
	; DB7 = 1
	; DB6:DB0 = 100 0000
	; Address of Row 2 Col 1 = 0x40
	MOVLW 0xC0
	MOVWF lcd_cmd
	CALL lcd_write_cmd
	RETURN

set_lcd_location
	MOVLW 0x80
	BCF lcd_location, 7
	ADDWF lcd_location, W
	MOVWF lcd_cmd
	CALL lcd_write_cmd
	RETURN
lcd_write_cmd
	; RS = 0 (LCD write command)
	BCF PORTC, RS
	MOVF lcd_cmd, W
	MOVWF PORTD
	; EN = 0 to 1 transition
	BSF PORTC, EN ; EN = 1
	BCF PORTC, EN ; EN = 0
	; LCD command execution: 1us-1.64ms
	MOVLW 0x02
	CALL ms_delay
	RETURN

lcd_write_w
	MOVWF lcd_data
	GOTO lcd_write_data
	RETURN

lcd_write_data
	; RS = 1 (LCD display character)
	BSF PORTC, RS
	MOVF lcd_data, W
	MOVWF PORTD
	; EN = 0 to 1 transition
	BSF PORTC, EN
	BCF PORTC, EN
	; LCD write data execution: 46us
	CALL one_ms_delay
	RETURN

ms_delay
	; counter_1 = x ms
	MOVWF counter_1
loop_1
	CALL one_ms_delay
	DECFSZ counter_1
	GOTO loop_1
	RETURN

one_ms_delay
	; 1ms delay
	MOVLW d'249'
	MOVWF counter_2
loop_2
	NOP
	DECFSZ counter_2
	GOTO loop_2
	RETURN

	END