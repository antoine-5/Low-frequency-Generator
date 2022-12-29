	;Project 'Systèmes à Microprossesseurs'  -- 29/11/2020
	;Louis Saad - Antoine Sfeir - Lynn Tabet

	;the pic18f4520 we are using is operating at an oscillaion frequency Fosc of 20 MHz
	include <p18f4520.inc>
	config wdt = off
	config pbaden = off
	screen equ 0x00				;variable used to detect the page we are in
	counter equ 0x01			;variable used to count the number the next pressed
	select equ 0x02				;variable used to detect the mode selected (sinus/square/triangle)
	highvar equ 0x03			;variable used to manipulate the tmr0H value	
	lowvar equ 0x04				;variable used to manipulate the tmr0L value
	ampl equ 0x05				;variable used to detect the value of the amplitude
	nb_a_afficher equ 0x06		;variable used to store the code ASCII for 1e-1 numbers
	nb_a_afficher2 equ 0x07		;variable used to store the code ASCII for 1e0 numbers (units)
	select_period equ 0x08		;variable used to detect the frequency step used
	ampl_save equ 0x09			;variable used to manipulate the amplitude without affecting ampl
	value equ 0x10				;varible used to manipulate the data based on the amplitude selected
	nb_a_afficher3 equ 0x11		;vairable used to store the code ASCII for 1e-2 numbers
	
	org 0x700
	db 0x7f,0x97,0xaf,0xc5,0xd8,0xe8,0xf4,0xfb,0xfe,0xfb,0xf4,0xe8,0xd8,0xc5,0xaf,0x97,0x7f,0x66,0x4e,0x38,0x25,0x15,0x09,0x02,0x00,0x02,0x09,0x15,0x25,0x38,0x4e,0x66
	org 0x800
	db 0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
	org 0x900
	db 0x7f,0x8e,0x9e,0xae,0xbe,0xce,0xde,0xee,0xfe,0xee,0xde,0xce,0xbe,0xae,0x9e,0x8e,0x7f,0x6f,0x5f,0x4f,0x3f,0x2f,0x1f,0x0f,0x00,0x0f,0x1f,0x2f,0x3f,0x4f,0x5f,0x6f
	
load_timer1 macro
				movlw b'11001000'
				movwf t1con	
				movlw 0xfe
				movwf tmr1h
				movlw 0x0c
				movwf tmr1l
			endm
load_timer1_clear macro
				movlw b'11111000'
				movwf t1con	
				movlw 0xfb
				movwf tmr1h
				movlw 0xff
				movwf tmr1l
			endm
load_timer1_refresh macro
				movlw b'11111000'
				movwf t1con	
				movlw 0x0b
				movwf tmr1h
				movlw 0xd0
				movwf tmr1l
			endm

load_timer0 macro
				movff highvar,tmr0h
				movff lowvar,tmr0l
				endm
			
	org 0x00
	bra init
	org 0x08
	bra HP
	
	org 0x18
	btfss portb,7
	bra next_page
	btfss portb,6
	bra select_button
	btfsc intcon3,int2if		;test if int2 flag is cleared
	bra frequency_button
	btfss portb,4
	bra pas_button
	btfsc intcon3,int1if		;test if int1 flag is cleared
	bra amp
	bcf intcon,rbif
	retfie

HP
	btfss intcon,int0if			;if not int0 it is the timer to get the values
	bra signal
	bcf intcon,int0if			;clear int0 flag
	btfsc select,0				;if set then it is sinus, set tblptrh to 0x07
	call init_sinus
	btfsc select,1				;if set then it is square,set tblptrh to 0x08
	call init_carre
	btfsc select,2				;if set then it is triangle,set tblptrh to 0x09
	call init_triangle
	load_timer0
	bsf t0con,7
	retfie


init_sinus
	movlw 0x07					;sinus values are stored in 0x700 so we put 0x07 in tblptrH
	movwf tblptrh
	return
init_carre
	movlw 0x08					;square values are stored in 0x800 so we put 0x08 in tblptrH
	movwf tblptrh
	return
init_triangle
	movlw 0x09					;triangle values are stored in 0x900 so we put 0x09 in tblptrH
	movwf tblptrh
	return
	

signal
	bcf intcon,tmr0if			;clear timer0 flag
	movlw d'32'
	cpfslt tblptrl				;if lower than 32d continue, if not clear (overflow to the values)
	clrf tblptrl
	tblrd*+
	movff tablat,value
	movff ampl,ampl_save		;save ampl in a variable ampl_save to manipulate it without affecting the initial value
compare
	movlw 0x00
	cpfseq ampl_save
	bra rot
	movff value,latc
	load_timer0
	retfie
rot
	decf ampl_save				;if not then we have chosen a lower amplitude so we rotate (division by 2) value and decrement ampl_save and recompare ampl_save until it will be nul
	rrcf value,f
	bcf value,7
	bra compare

amp								;low-priority
	bcf intcon3,int1if			;clear int1 flag
	incf ampl
	movlw 0x08
	cpfslt ampl
	clrf ampl
	retfie

next_page						;interruption on next page button (RB7)
	incf counter				;increment counter to get how many presses we have done
	movlw 0x01
	cpfseq counter
	bra option2					;if counter = 1, then we are at page 1
option1
	bsf screen,0
	bra fin
option2
	movlw 0x02					;if counter = 2 then we are at page 2, else we are at page 3 and we clear the counter, so the infinite loop will display page 1
	cpfseq counter
	bra option3
	bsf screen,1
	bra fin
option3
	clrf counter
	clrf screen
	
fin
	bcf intcon,rbif
	retfie

select_button					;interruption on select button (RB6)
	movlw 0x00
	cpfseq counter				;test the counter to see what page we are to get the signal selected
	bra option2_2
option1_1
	clrf select
	bsf select,0				;select = 0x01 for sin
	bra fin
option2_2
	movlw 0x01
	cpfseq counter
	bra option3_2
	clrf select
	bsf select,1				;select = 0x02 for square
	bra fin
option3_2
	clrf select
	bsf select,2				;select = 0x04 for triangle
	bra fin

frequency_button				;interruption on higher frequency button (INT2)
	movlw 0x00					;test the step of frequency we have chosen
	cpfsgt select_period
	bra option_f_1
	bra option_f_2
option_f_1						;we have chosen the first frequency step
	call adding1				;function to manipulate timer 0 load (Highvar/Lowvar) based on the step chosen
	movlw d'48'
	cpfsgt nb_a_afficher		;check if zero, then put it at 9 (after we have pushed the button) (after we decrement,line 187, it it will become 9:57)
	call put_58
	decf nb_a_afficher
	movlw d'48'
	cpfsgt nb_a_afficher2		;check if greater then zero to retfie
	call initial				;if zero call initial
	bcf intcon3,int2if
	retfie
option_f_2
	call adding2				;function to manipulate timer 0 load (Highvar/Loawvar) based on the step chosen
	movlw d'48'
	cpfsgt nb_a_afficher3		;check if greater than zero, then decrement it
	call reseting				;if zero call reseting
	decf nb_a_afficher3
	movlw d'48'
	cpfsgt nb_a_afficher2		;check if greater than zero, the return from interrupt
	call initial				;if zero call initial2 
	bcf intcon3,int2if
	retfie

	
initial
	movlw d'48'
	cpfsgt nb_a_afficher
	call var_lower2
	return
var_lower2
	movlw d'48'
	cpfsgt nb_a_afficher3
	call var_lower
	return
	
put_58
	movlw d'58'
	movwf nb_a_afficher
	decf nb_a_afficher2
	movlw d'47'
	cpfsgt nb_a_afficher2
	call var_lower_exp
	return
var_lower						;we reset the period by loading timer0 and display the inital period value
	movlw 0x67
	movwf highvar
	movlw 0x69
	movwf lowvar
	movlw d'48'
	movwf nb_a_afficher
	movlw d'50'
	movwf nb_a_afficher2
	movlw d'48'
	movwf nb_a_afficher3
	clrf select_period
	return
var_lower_exp						;we reset the period by loading timer0 and display the inital period value
	movlw 0x67
	movwf highvar
	movlw 0x69
	movwf lowvar
	movlw d'49'
	movwf nb_a_afficher
	movlw d'50'
	movwf nb_a_afficher2
	movlw d'48'
	movwf nb_a_afficher3
	clrf select_period
	return

reseting
	movlw d'58'
	movwf nb_a_afficher3
	movlw d'48'
	cpfseq nb_a_afficher
	bra normal_001
	decf nb_a_afficher2
	movlw d'57'
	movwf nb_a_afficher
	return
normal_001
	decf nb_a_afficher
	return
	
pas_button
	incf select_period
	movlw 0x02
	cpfslt select_period
	clrf select_period
	bcf intcon,rbif
	retfie

init
	bcf intcon2,rbpu
	movf portb,wreg				; rbif commence a 1 
	bcf intcon2,intedg2			; int on falling edge
	bcf intcon2,intedg1			; int on falling edge
	bcf intcon,rbif				; clear rbif flag
	bcf intcon3,int2if			;clear int2 flag
	bcf intcon3,int1if			;clear int1 flag
	bcf intcon,int0if			;clear int0 flag
	bcf pir1,tmr1if				;clear tmr1 flag
	bcf intcon,tmr0if			;clear tmr0 flag
	bcf intcon2,rbip			;set RB change on low priority
	bcf intcon3,int2ip			;set int2 on low priority
	bcf intcon3,int1ip			;set int1 on low priority
	bsf rcon,ipen				;allow 2 lvl interruption
	bsf intcon,tmr0ie
	bsf intcon3,int2ie
	bsf intcon3,int1ie
	bsf intcon,int0ie
	bsf intcon,rbie
	bsf intcon,peie
	bsf intcon,gie

	movlw b'00000010'			;initialinzing timer0 with no prescaler (PS = 1)
	movwf t0con
	movlw b'11111000'			;intializing timer1
	movwf t1con
	movlw 0x67
	movwf highvar
	movlw 0x69
	movwf lowvar

	bcf trisa,0					;port A0 output
	bcf trisa,1					;port A1 output
	bcf trisa,2
	clrf trisc					;port C output
	clrf trisd					;port D output
	
	movlw d'48'
	movwf nb_a_afficher
	movwf nb_a_afficher3
	movlw d'50'
	movwf nb_a_afficher2
	clrf select_period
	; clearing lcd variables new
	clrf screen
	
	; setting initialisiation lcd
	bcf lata,0					;command
	movlw 0x0c
	movwf latd
	bsf lata,1
	bcf lata,1					;to send the command to LCD
	call delayLCD
	movlw 0x38
	movwf latd
	bsf lata,1
	bcf lata,1					;set LCD in 8-bit mode
	call delayLCD

	clrf counter
	clrf select
	clrf ampl
	
	
; boucle infinie new autre new return retfie en bas
writing_on_lcd
	bsf lata,0					;command on LCD
	btfss screen,0				;if set then we are at page 2 or above, if clear then page 1
	bra page1
	btfss screen,1				;if set then we are at page 3, if clear then page 2
	bra page2
	bra page3

page1
	call display_sin
	btfsc select,0
	call display_selected
	btfsc select,0
	bsf lata,2
	btfss select,0
	bcf lata,2
	call display_block
	bra writing_on_lcd
page2
	call display_car
	btfsc select,1
	call display_selected
	btfsc select,1
	bsf lata,2
	btfss select,1
	bcf lata,2
	call display_block
	bra writing_on_lcd
page3
	call display_tr
	btfsc select,2
	call display_selected
	btfsc select,2
	bsf lata,2
	btfss select,2
	bcf lata,2
	call display_block
	bra writing_on_lcd
	
display_block
	call disp_space
	call disp_space
	call display_periode_option_1
	call goto_scnd_line
	call display_pas
	call goto_thrd_line
	call disp_space
	call disp_space
	call disp_space
	call disp_space
	call display_amp
	call refresh
	call clear_screen
	return

refresh
	load_timer1_refresh			;load timer1 to 100 ms
	bsf t1con,tmr1on			;start timer1
	btfss pir1,tmr1if			;when the flag is up 100 ms have passed
	bra $-2
	bcf pir1,tmr1if				;lower tmr1 flag
	bcf t1con,tmr1on			;stop timer1
	return

clear_screen
	bcf lata,0
	movlw 0x01
	movwf latd
	bsf lata,1
	bcf lata,1
	call delay_for_cmd
	return
delay_for_cmd
	load_timer1_clear			;load timer1 to 1.64 ms
	bsf t1con,tmr1on			;start timer1
	btfss pir1,tmr1if			;when the flag is up 1.64 ms have passed
	bra $-2
	bcf pir1,tmr1if				;lower tmr1 flag
	bcf t1con,tmr1on			;stop timer1
	return
delayLCD 
	load_timer1					;load timer1 to 0.1 ms
	bsf t1con,tmr1on			;start timer1
	btfss pir1,tmr1if			;when the flag is up 0.1 ms have passed
	bra $-2
	bcf pir1,tmr1if				;lower tmr1 flag
	bcf t1con,tmr1on			;stop timer1
	return
display_tr
	movlw d'84'
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'114'
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'105'
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'97'
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'110'
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'103'
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'108'
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'101'
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	return

display_car
	movlw d'67'
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'97'
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'114'
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'114'
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'101'
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	return

display_sin
	movlw d'83'
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'105'
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'110'
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'117'
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'115'
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	return

display_selected				; display # if selected
	movlw d'129'
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'35'
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	return

goto_scnd_line
	bcf lata,0
	movlw 0xc0
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	bsf lata,0
	return
goto_thrd_line
	bcf lata,0
	movlw 0x90
	movwf latd
	bsf lata,1
	bcf lata,1
	call delay_for_cmd
	bsf lata,0
	return
	
display_periode_option_1
	movlw d'84'
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	call disp_space
	movff nb_a_afficher2,latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'46'
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movff nb_a_afficher,latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movff nb_a_afficher3,latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	
	return
disp_space
	movlw d'129'    ; display ' '
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	return

display_pas
	movlw d'80'   
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'97'
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'115'
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	call disp_space
	movlw d'48'   
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'46'   
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'49'   
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	call check_select_pas1
	call disp_space
	movlw d'48'   
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'46'   
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'48'   
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'49'   
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	call check_select_pas2
	return

display_amp
	movlw d'80'   
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'114'   
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'101'   
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'115'   
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'115'   
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	call disp_space
	movlw d'102'   
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'111'   
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'114'   
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	call disp_space
	movlw d'65'   
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'109'   
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'112'   
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'47'   
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	movlw d'50'   
	movwf latd
	bsf lata,1
	bcf lata,1
	call delayLCD
	
	return

adding1
	movlw 0xa1
	addwf lowvar,f
	movlw 0x07
	addwfc highvar
	return
adding2
	movlw 0xc3
	addwf lowvar,f
	movlw 0x00
	addwfc highvar
	return
	
check_select_pas1
	movlw 0x00
	cpfseq select_period
	return
	call display_selected
	return
check_select_pas2
	movlw 0x01
	cpfseq select_period
	return
	call display_selected
	return
	
	end