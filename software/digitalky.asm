;;======================================================================;;
;;			Digitálky	 					;;
;;======================================================================;;
;;									;;
;; Program:		Digitální hodiny s vyuzitim zjednoduseneho Charlieplexingu	;;
;; Code:		Jindra Ficik					;;
;; Platform:		Microchip PIC16F15323, 2 Mhz			;;
;; Date:		08.03.2022					;;
;; First release:	08.03.2021					;;
;; LastDate:		08.03.2021					;;
;;									;;
;;======================================================================;;

; Processor PIC 16F15323 running at 2MHz internal clock + 32768Hz external timer
;
; Revisions:
;
; 08/03/2022	Start of writing code.

; ----- Definitions

#define		__VERNUM	.1
#define		__SUBVERNUM	.0
#define		__VERDAY	0x08
#define		__VERMONTH	0x03
#define		__VERYEAR	0x22


                list    p=16F15323,r=hex

		errorlevel -302
		;errorlevel -305
		;errorlevel -306

	        INCLUDE "P16F15323.INC"

; CONFIG1
; __config 0xFFEC
 __CONFIG _CONFIG1, _FEXTOSC_OFF & _RSTOSC_HFINT1 & _CLKOUTEN_OFF & _CSWEN_ON & _FCMEN_ON
; CONFIG2
; __config 0xF7FF
 __CONFIG _CONFIG2, _MCLRE_OFF & _PWRTE_OFF & _LPBOREN_OFF & _BOREN_ON & _BORV_LO & _ZCD_OFF & _PPS1WAY_OFF & _STVREN_ON
; CONFIG3
; __config 0xFF9F
 __CONFIG _CONFIG3, _WDTCPS_WDTCPS_31 & _WDTE_OFF & _WDTCWS_WDTCWS_7 & _WDTCCS_SC
; CONFIG4
; __config 0xFFEF
 __CONFIG _CONFIG4, _BBSIZE_BB512 & _BBEN_OFF & _SAFEN_ON & _WRTAPP_OFF & _WRTB_OFF & _WRTC_OFF & _WRTSAF_OFF & _LVP_OFF
; CONFIG5
; __config 0xFFFF
 __CONFIG _CONFIG5, _CP_OFF


; ----- Macros

#define		DNOP		goto	$+1

;#define PCBv2		; uncoment if V2 board is used

#define		RAMINI0		0x020		; 80 bytes
#define		RAMINI1		0x0A0		; 80 bytes
#define		RAMINI2		0x120		; 80 bytes
#define		RAMINT		0x070		; 16 bytes	available in all banks

; ----- Constant values

FXTAL		equ	D'1000000'		; oscillator frequency

;         +---U---+
;    Vdd -|Vdd Vss|- Vss
; Clk in -|RA5 RA0|- Chplx7
;        -|RA4 RA1|- Chplx8
; Key in -|RA3 RA2|-
; Chplx6 -|RC5 RC0|- Chplx1
; Chplx5 -|RC4 RC1|- Chplx2
; Chplx4 -|RC3 RC2|- Chplx3
;         +-------+

; PMD = PERIPHERAL MODULE DISABLE
PMD0_INI	equ	b'01000101'	; CLKRMD CLKR enabled; SYSCMD SYSCLK enabled; FVRMD FVR disabled; IOCMD IOC disabled; NVMMD NVM disabled; 
PMD1_INI	equ	b'10000010'	; TMR0MD TMR0 enabled; TMR1MD TMR1 disabled; TMR2MD TMR2 enabled; NCOMD DDS(NCO) disabled; 
PMD2_INI	equ	b'01100111'	; ZCDMD ZCD disabled; CMP1MD CMP1 disabled; ADCMD ADC disabled; CMP2MD CMP2 disabled; DAC1MD DAC1 disabled; 
PMD3_INI	equ	b'00111111'	; CCP2MD CCP2 disabled; CCP1MD CCP1 disabled; PWM4MD PWM4 disabled; PWM3MD PWM3 disabled; PWM6MD PWM6 disabled; PWM5MD PWM5 disabled; 
PMD4_INI	equ	b'01010001'	; CWG1MD CWG1 disabled; MSSP1MD MSSP1 disabled; UART1MD EUSART disabled; 
PMD5_INI	equ	b'00011110'	; CLC3MD CLC3 disabled; CLC4MD CLC4 disabled; CLC1MD CLC1 disabled; CLC2MD CLC2 disabled; 

; PIN manager
LATA_INI    equ 0x00	    ; all outputs to zero
LATC_INI    equ 0x00	    ; all outputs to zero

TRISA_INI   equ b'00111111' ; RA0,RA1 input - managed by charlieplexing, RA2 Not used, RA3 input - key buttons, RA4 not used, RA5 32768 Hz input
TRISC_INI   equ b'00111111' ; all input - managed by charlieplexing

ANSELA_INI  equ b'00000000' ; all digital
ANSELC_INI  equ b'00000000' ; all digital

WPUA_INI    equ	b'00010100'	; WPU for not used inputs
WPUC_INI    equ	0x00	    ; none

ODCONA_INI  equ	0x00	    ; disable open drain outputs
ODCONA_INI  equ	0x00	    ; disable open drain outputs
   
; oscillator management
OSCCON1_INI equ 0x60	    ; NOSC HFINTOSC; NDIV 1:1; 
;OSCCON2 is read only
OSCCON3_INI equ 0x00	    ; CSWHOLD may proceed; 
OSCEN_INI   equ 0x00	    ; MFOEN disabled; LFOEN disabled; ADOEN disabled; EXTOEN disabled; HFOEN disabled; 
OSCFRQ_INI  equ 0x01	    ; HFFRQ 2_MHz; 
OSCSTAT_INI equ 0x00	    ; MFOR not ready; do not understand, it is read only
;OSCTUNE_INI equ 0x20	    ; HFTUN 32; do not understand why MCC set this?
OSCTUNE_INI equ 0x00	    ; HFTUN 0; default

; Timer2 management			; Timer 2 is used for 1 sec pulses
T2CLKCON_INI	equ 0x00    ; T2CS T2CKIPPS; 32768 Hz crystal used for 1 sec pulses
T2HLT_INI   equ 0x00    ; T2PSYNC Not Synchronized; T2MODE Software control; T2CKPOL Rising Edge; T2CKSYNC Not Synchronized; 
T2RST_INI   equ 0x00	; T2RSEL T2INPPS pin; 
T2PR_INI    equ 0xFF	; T2PR 255 = 1 Hz; 
T2CON_INI   equ b'11110000'	; T2CKPS 1:128; T2OUTPS 1:1; TMR2ON on; 

T2INPPS_INI	equ 0x05	; RA5 is used as T2IN (that is default)

; Timer1 management
;T1GCON_INI	equ 0x00	; T1GE disabled; T1GTM disabled; T1GPOL low; T1GGO done; T1GSPM disabled; 
;T1GATE_INI	equ 0x00	; GSS T1G_pin; 
;T1CLK_INI	equ 0x01	; ClockSelect FOSC/4; 
;;TMR1H = 0x00;    //TMR1H 0; 
;;TMR1L = 0x00;    //TMR1L 0; 
;T1CON_INI	equ 0x14	; CKPS 1:2; nT1SYNC do_not_synchronize; TMR1ON disabled; T1RD16 disabled; 

; Timer0 management
T0CON1_INI	equ b'01010001'	; T0CS Fosc/4; T0CKPS 1:2; T0ASYNC not_synchronised; 
T0CON0_INI	equ b'10000000'	; T0OUTPS 1:1; T0EN enabled; T016BIT 8-bit; 
TMR0H_INI	equ .178		; in 8 bit mode the TMR0H is compared same as PR2 with timer2 --> 500 000 / (2 * 178) = 1404.5 Hz --> 28 segments --> 1404.5 / 28 = 50.16 Hz per screen
;TMR0L = 0x00; TMR0L 0; 

; EUSART management
;BAUD1CON_INI	equ 0x08	; ABDOVF no_overflow; SCKP Non-Inverted; BRG16 16bit_generator; WUE disabled; ABDEN disabled; 
;RC1STA_INI	equ 0x90	; SPEN enabled; RX9 8-bit; CREN enabled; ADDEN disabled; SREN disabled; 
;TX1STA_INI	equ 0x04	; TX9 8-bit; TX9D 0; SENDB sync_break_complete; TXEN disabled; SYNC asynchronous; BRGH hi_speed; CSRC slave; 
;SP1BRGL_INI	equ 0x1D	; SP1BRGL 29; 
;SP1BRGL_INI	equ 0x77	; SP1BRGL 119; 
;SP1BRGH_INI	equ 0x00	; SP1BRGH 0; 

; CLC 1 management
;CLC1CON_INI	equ	b'10000010'	; LC1EN is enabled, LC1INT disabled, LC1MODE is 4 input AND
;CLC1POL_INI	equ	b'00001100'	; LC1G1 not inverted, LC1G2 not inverted, LC1G3 inverted, LC1G4 inverted, LC1POL not invrted
;CLC1SEL0_INI	equ	b'00000000'	; data 0 is CLCIN0PPS
;CLC1SEL1_INI	equ	b'00000100'	; data 1 is Fosc
;CLC1SEL2_INI	equ	b'00000000'	; data 2 is CLCIN0PPS
;CLC1SEL3_INI	equ	b'00000000'	; data 3 is CLCIN0PPS
;CLC1GLS0_INI	equ	b'00000010'	; gate 0 input is data 0 non inverted
;CLC1GLS1_INI	equ	b'00001000'	; gate 0 input is data 1 non inverted
;CLC1GLS2_INI	equ	b'00000000'	; gate 2 input is none
;CLC1GLS3_INI	equ	b'00000000'	; gate 3 input is none

;INTPPS_INI		equ	b'00000010'	; map INT to RA2
;CLCIN0PPS_INI	equ	b'00000010'	; map CLCIN0 to RA2

; Interrupt section
PIE0_INI	equ 0x20	; TMR0 interrupt
PIE1_INI	equ 0x00	; none used
PIE2_INI	equ 0x00	; none used
PIE3_INI	equ 0x00	; none used
PIE4_INI	equ 0x00	; none used
PIE5_INI	equ 0x00	; none used
PIE6_INI	equ 0x00	; none used
PIE7_INI	equ 0x00	; none used

INTC_INI	equ 0xC0	; GIE enable, PIE enable, falling edge of INT


#define		SWIN	PORTA,3			; reed switch pin

; --- EEPROM Section - no EEPROM, it is emulated by SAF
#define		SAF1_INI	0x00780

; ----- Variables

; --- Internal RAM Section
		cblock  RAMINT
NEWTRISA	; new state for TRISA  \
NEWLATA		; new state for LATA   \\
NEWTRISC	; new state for TRISC  -- charlieplexing registers.
NEWLATC		; new state for LATC   _/
PORTTMP		; port input copy - used for read button
FLAGS		; status flags
		endc

#define		SWIN2	PORTTMP,3			; reed switch pin


		cblock  RAMINI0

C_SEC		; counter of seconds
C_MIN		; counter of minutes
C_HOURS		; counter of hours
BIT_CNT		; Counter of bits (pixels)

; 12:34
;    a
;   ---
; f| g |b
;   ---
; e|   |c
;   ---
;    d
; dots between hours and mins are segment f from digit 1

DIG1		; value for digit 1 - value mean lighting segments segment a = bit 0, segment g = bit 6
DIG2		; value for digit 2
DIG3		; value for digit 3
DIG4		; value for digit 4
		
TEMP		; various temps :)
COUNT

BTNS		; button matrix
OLDBTNS		; copy of button matrix used for momentary buttons

       endc

; --- Flags
						; FLAGS
#define		NEXT_STEP	FLAGS,0		; interrupt happened, next step needs to be done
;#define		BTN_USE		FLAGS,1		; Button was in use
;#define		LONG_BTN	FLAGS,2		; Long press happened

#define		BTN_MM	BTNS,0		; Button for Minute Minus
#define		BTN_MP	BTNS,1		; Button for Minute Plus
#define		BTN_HM	BTNS,2		; Button for Hour Minus
#define		BTN_HP	BTNS,3		; Button for Hour Plus
#define		BTN_SS	BTNS,4		; Button for show seconds
#define		BTN_S0	BTNS,5		; Button for set seconds to 0


; ------ Program Section

		org	0x000

PowerUp:
		;clrf	STATUS			; ensure we are at bank 0
		clrf	PCLATH			; ensure page bits before goto !!
		clrf	INTCON			; disable all interrupts
		goto	Start


;
;**********************************************************************************************************************
; ISR (Interrupt Service Routines)
;**********************************************************************************************************************
;
	org	0x004
Interrupt:
	BANKSEL	PIR0		; BNK 2
	bcf	PIR0,TMR0IF	; time to next Charlieplexing step?
	BANKSEL	LATA		; BNK 0
	movf	PORTA,w
	movwf	PORTTMP		; save button input
	clrf	LATA
	clrf	LATC
	movf	NEWTRISA,w
	movwf	TRISA
	movf	NEWTRISC,w
	movwf	TRISC
	movf	NEWLATA,w
	movwf	LATA
	movf	NEWLATC,w
	movwf	LATC
	bsf		NEXT_STEP
	retfie

TrisConvert:
		brw		; Convert position to tris mask
TrisConvert0
		;       RA   RC		port
		;       10543210	port bit
		;       76543210	naming
		retlw b'01111110'	; D1 Sa C0 A7
		retlw b'01111101'	; D1 Sb C1 A7
		retlw b'01111011'	; D1 Sc C2 A7
		retlw b'01110111'	; D1 Sd C3 A7
		retlw b'01101111'	; D1 Se C4 A7
		retlw b'01011111'	; D1 Sf C5 A7 dots
		retlw b'00111111'	; D1 Sg C6 A7
		incf BIT_CNT,f		; segment 8 does not exist, increasing counter
		retlw b'10111110'	; D2 Sa C0 A6
		retlw b'10111101'	; D2 Sb C1 A6
		retlw b'10111011'	; D2 Sc C2 A6
		retlw b'10110111'	; D2 Sd C3 A6
		retlw b'10101111'	; D2 Se C4 A6
		retlw b'10011111'	; D2 Sf C5 A6
		retlw b'00111111'	; D2 Sg C7 A6
		incf BIT_CNT,f		; segment 8 does not exist, increasing counter
		retlw b'11011110'	; D3 Sa C0 A5
		retlw b'11011101'	; D3 Sb C1 A5
		retlw b'11011011'	; D3 Sc C2 A5
		retlw b'11010111'	; D3 Sd C3 A5
		retlw b'11001111'	; D3 Se C4 A5
		retlw b'10011111'	; D3 Sf C6 A5
		retlw b'01011111'	; D3 Sg C7 A5
		incf BIT_CNT,f		; segment 8 does not exist, increasing counter
		retlw b'11101110'	; D4 Sa C0 A4
		retlw b'11101101'	; D4 Sb C1 A4
		retlw b'11101011'	; D4 Sc C2 A4
		retlw b'11100111'	; D4 Sd C3 A4
		retlw b'11001111'	; D4 Se C5 A4
		retlw b'10101111'	; D4 Sf C6 A4
		retlw b'01101111'	; D4 Sg C7 A4
		clrf BIT_CNT		; Over = reset step
		goto TrisConvert0	; return for 0

LatConvert:
		brw		; Convert position to bit mask - anodes are connected per digit
		;       RA   RC		port
		;       10543210	port bit
		;       76543210	naming
		retlw b'10000000'	; D1 A7
		retlw b'01000000'	; D2 A6
		retlw b'00100000'	; D3 A5
		retlw b'00010000'	; D3 A4

BitConvert:
		brw		; to bit position
		retlw b'00000001'	; 0
		retlw b'00000010'	; 1
		retlw b'00000100'	; 2
		retlw b'00001000'	; 3
		retlw b'00010000'	; 4
		retlw b'00100000'	; 5
		retlw b'01000000'	; 6
		retlw b'10000000'	; 7

; 12:34
;    a
;   ---
; f| g |b
;   ---
; e|   |c
;   ---
;    d
; dots between hours and mins are segment f from digit 1

	IFNDEF PCBv2
CharSet:		; 7 segment character set
		brw
		;        baedcgf
		retlw b'01111101'	; 0
		retlw b'01000100'	; 1
		retlw b'01111010'	; 2
		retlw b'01101110'	; 3
		retlw b'01000111'	; 4
		retlw b'00101111'	; 5
		retlw b'00111111'	; 6
		retlw b'01100100'	; 7
		retlw b'01111111'	; 8
		retlw b'01101111'	; 9
		retlw b'01011100'	; J
		retlw b'00110011'	; F
		
#define		CHARJ	b'01011100'		; character J
#define		CHARF	b'00110011'		; character F
#define		DDOT	DIG1,0			; reed switch pin
	ENDIF

	IFDEF PCBv2
CharSet:		; 7 segment character set
		brw
		;        gfedcba
		retlw b'00111111'	; 0
		retlw b'00000110'	; 1
		retlw b'01011011'	; 2
		retlw b'01001111'	; 3
		retlw b'01100110'	; 4
		retlw b'01101101'	; 5
		retlw b'01111101'	; 6
		retlw b'00000111'	; 7
		retlw b'01111111'	; 8
		retlw b'01101111'	; 9
		retlw b'00011110'	; J
		retlw b'01110001'	; F
		
#define		CHARJ	b'00011110'		; character J
#define		CHARF	b'01110001'		; character F
#define		DDOT	DIG1,5			; double dot segment
	ENDIF


Start:
	BANKSEL	PORTA		; BANK 0
	movlw	LATA_INI	; all outputs to zero
	movwf	LATA
	movlw	TRISA_INI	; RA2 is output, RA3 is MCLR
	movwf	TRISA
	movlw	LATC_INI	; all outputs to zero
	movwf	LATC
	movlw	TRISC_INI	; RA2 is output, RA3 is MCLR
	movwf	TRISC

	; PMD = PERIPHERAL MODULE DISABLE
	BANKSEL	PMD0		; BANK 15
	movlw	PMD0_INI	; CLKRMD CLKR enabled; SYSCMD SYSCLK enabled; FVRMD FVR disabled; IOCMD IOC enabled; NVMMD NVM enabled; 
	movwf	PMD0
	movlw	PMD1_INI	; TMR0MD TMR0 enabled; TMR1MD TMR1 enabled; TMR2MD TMR2 enabled; NCOMD DDS(NCO) enabled; 
	movwf	PMD1
	movlw	PMD2_INI	; ZCDMD ZCD disabled; CMP1MD CMP1 enabled; ADCMD ADC disabled; CMP2MD CMP2 disabled; DAC1MD DAC1 disabled; 
	movwf	PMD2
	movlw	PMD3_INI	; CCP2MD CCP2 disabled; CCP1MD CCP1 disabled; PWM4MD PWM4 disabled; PWM3MD PWM3 disabled; PWM6MD PWM6 disabled; PWM5MD PWM5 disabled; 
	movwf	PMD3
	movlw	PMD4_INI	; CWG1MD CWG1 disabled; MSSP1MD MSSP1 disabled; UART1MD EUSART enabled; 
	movwf	PMD4
	movlw	PMD5_INI	; CLC3MD CLC3 disabled; CLC4MD CLC4 disabled; CLC1MD CLC1 disabled; CLC2MD CLC2 disabled; 
	movwf	PMD5

; PIN manager
	BANKSEL	ANSELA		; BANK 62

	movlw	ANSELA_INI	; RA0 and RA1 to analog = comparator inuts
	movwf	ANSELA
	movlw	WPUA_INI	; disable WPU
	movwf	WPUA
	movlw	ODCONA_INI	; disable open drain outputs
	movwf	ODCONA

; oscilator management
	BANKSEL	OSCCON1		; BANK 17
	movlw	OSCCON1_INI	; NOSC HFINTOSC; NDIV 4; 
	movwf	OSCCON1
		;OSCCON2 is read only
	movlw	OSCCON3_INI	; CSWHOLD may proceed; 
	movwf	OSCCON3
	movlw	OSCEN_INI	; MFOEN disabled; LFOEN disabled; ADOEN disabled; EXTOEN disabled; HFOEN disabled; 
	movwf	OSCEN
	movlw	OSCFRQ_INI	; HFFRQ 8_MHz; 
	movwf	OSCFRQ
	movlw	OSCSTAT_INI	; MFOR not ready; do not understand, it is read only
	movwf	OSCSTAT
	movlw	OSCTUNE_INI	; HFTUN 32; do not understand why MCC set this?
	movwf	OSCTUNE

; Timer2 management
	BANKSEL	TMR2		; BANK 5
	movlw	T2CLKCON_INI	; T2CS FOSC/4; 
	movwf	T2CLKCON
	movlw	T2HLT_INI	; T2PSYNC Not Synchronized; T2MODE Software control; T2CKPOL Rising Edge; T2CKSYNC Not Synchronized; 
	movwf	T2HLT
	movlw	T2RST_INI	; T2RSEL T2INPPS pin; 
	movwf	T2RST
	movlw	T2PR_INI	; T2PR 59 (0.3B); 
	movwf	T2PR
;		;T2TMR = 0x00; TMR2 0; 
	movlw	T2CON_INI	; T2CKPS 1:2; T2OUTPS 1:1; TMR2ON on; 
	movwf	T2CON

; Timer0 management
	BANKSEL	T0CON1		; BANK 11
	movlw	T0CON1_INI	; T0CS Fosc/4; T0CKPS 1:2; T0ASYNC not_synchronised; 
	movwf	T0CON1
	movlw	T0CON0_INI	; T0OUTPS 1:1; T0EN enabled; T016BIT 8-bit; 
	movwf	T0CON0
	movlw	TMR0H_INI	; in 8 bit mode the TMR0H is compared same as PR2 with timer2 --> 500 000 / (2 * 178) = 1404.5 Hz --> 28 segments --> 1404.5 / 28 = 50.16 Hz per screen
	movwf	TMR0H


; Interrupts
	BANKSEL	PIE0	; BANK 2
	movlw	PIE0_INI	; Enable TMR0 interrupt set TMR0IE = 1.
	movwf	PIE0
	movlw	PIE1_INI	; none used
	movwf	PIE1
	movlw	PIE2_INI	; Enabling CMP1 interrupt.
	movwf	PIE2
	movlw	PIE3_INI	; enable receive interrupt
	movwf	PIE3
	movlw	PIE4_INI	; Enabling TMR2 interrupt.
	movwf	PIE4
	movlw	PIE5_INI	; none used
	movwf	PIE5
	movlw	PIE6_INI	; none used
	movwf	PIE6
	movlw	PIE7_INI	; none used
	movwf	PIE7

	movlb	0	; BANK 0
	movlw	RAMINI0			; Clear variables bank0
	movwf	FSR0L
	clrf	FSR0H
	clrw
ClearRAM:
	movwi	FSR0++
	;clrf	INDF0
	;incf	FSR0L,f
	btfss	FSR0L,7			; to address 7F
	goto	ClearRAM

	movlw	0x3F
	movwf	NEWTRISA
	movwf	NEWTRISC

	BANKSEL	PIR0		; BNK 14
	bcf	PIR0,TMR0IF	; clear time to next Charlieplexing step
	movlb	0	; BANK 0
	movlw	INTC_INI		; Set interrupts
	movwf	INTCON

	movlw CHARJ	; J
	movwf DIG1
	movlw CHARF	; F
	movwf DIG2

MainLoop:
	BANKSEL	PIR4		; BNK 14
	btfsc	PIR4,TMR2IF	; next second
	call	IncSec		; increase

	btfsc	NEXT_STEP
	call	DoNextLED	; prepare next segment for interrupt
	goto	MainLoop

IncSec:
	bcf		PIR4,TMR2IF	; clear flag
	movlb	0
	incf	C_SEC,f	; plus one sec
	movf	C_SEC,w	; is it 60? then must be set to 00
	xorlw	.60
	btfss	STATUS,Z
	goto	DrawScreen	; some change on digits appear, screen should be re-draw

	clrf	C_SEC		; set 00
	incf	C_MIN,f	; plus one min
	movf	C_MIN,w	; is it 60? then must be set to 00
	xorlw	.60
	btfss	STATUS,Z
	goto	DrawScreen	; some change on digits appear, screen should be re-draw

	clrf	C_MIN		; set 00
	incf	C_HOURS,f	; plus one hour
	movf	C_HOURS,w	; is it 24? then must be set to 00
	xorlw	.24
	btfss	STATUS,Z
	goto	DrawScreen	; some change on digits appear, screen should be re-draw
	clrf	C_HOURS		; set 00

DrawScreen:				; time to refresh screen
	btfsc	BTN_SS		; display second or hours:minutes??
	goto	DrawScreenSS
	movf	C_MIN,w		; get minutes
	call	BinaryToBcd	; convert to BCD
	movwf	TEMP		; save for 2nd digit
	andlw	0x0F		; lower digit only
	call	CharSet		; convert to 7 segments
	movwf	DIG4		; put to screen
	swapf	TEMP,w		; upper digit
	andlw	0x0F		; upper digit only
	call	CharSet		; convert to 7 segments
	movwf	DIG3		; put to screen

	movf	C_HOURS,w	; get hours
	call	BinaryToBcd	; convert to BCD
	movwf	TEMP		; save for 2nd digit
	andlw	0x0F		; lower digit only
	call	CharSet		; convert to 7 segments
	movwf	DIG2		; put to screen
	swapf	TEMP,w		; upper digit
	andlw	0x0F		; upper digit only
	btfss	STATUS,Z	; do not display landing zeroes (have no segment for it)
	call	CharSet		; convert to 7 segments
	movwf	DIG1		; put to screen
	btfss	C_SEC,0		; two dots blinking by seconds
	bsf		DDOT		; set the segment
	return

DrawScreenSS:
	movf	C_SEC,w		; get seconds
	call	BinaryToBcd	; convert to BCD
	movwf	TEMP		; save for 2nd digit
	andlw	0x0F		; lower digit only
	call	CharSet		; convert to 7 segments
	movwf	DIG4		; put to screen
	swapf	TEMP,w		; upper digit
	andlw	0x0F		; upper digit only
	call	CharSet		; convert to 7 segments
	movwf	DIG3		; put to screen

	movlw CHARJ	; J
	movwf DIG1
	movlw CHARF	; F
	movwf DIG2
	btfsc	C_SEC,0		; two dots blinking by seconds
	bsf		DDOT		; set the segment
	return

;******************************** 
;binary_to_bcd - 8-bits
;
;Input
;  8-bit binary number
;   A1*16+A0
;Outputs
; tens_and_ones - the tens and ones digits of the BCD conversion
BinaryToBcd:

	movwf	TEMP
	SWAPF	TEMP, W		; swap the nibbles
	ADDWF	TEMP, W		; so we can add the upper to the lower
	ANDLW	B'00001111'	; lose the upper nibble (W is in BCD from now on)
	BTFSC	STATUS, DC	; if we carried a one (upper + lower > 16)
	 ADDLW	0x16		; add 16 (the place value) (1s + 16 * 10s)
	BTFSC	STATUS, DC	; did that cause a carry from the 1's place?
	 ADDLW	0x06		; if so, add the missing 6 (carry is only worth 10)
	ADDLW	0x06        ; fix max digit value by adding 6
	BTFSS	STATUS, DC	; if was greater than 9, DC will be set
	 ADDLW	-0x06		; if if it wasn't, get rid of that extra 6

	BTFSC	TEMP,4		; 16's place
	 ADDLW	0x16 - 1 + 0x6	; add 16 - 1 and check for digit carry
	BTFSS	STATUS, DC
	 ADDLW	-0x06       ; if nothing carried, get rid of that 6

	BTFSC	TEMP, 5      ; 32nd's place
	 ADDLW	0x30        ; add 32 - 2

	BTFSC	TEMP, 6      ; 64th's place		Time is always < 64 :)
	 ADDLW	0x60        ; add 64 - 4

	BTFSC	TEMP, 7      ; 128th's place	Time is always < 128 :)
	 ADDLW	0x20        ; add 128 - 8 % 100

	RETURN              ; all done!

DoNextLED:	; 1404.5 Hz per led --> 28 segments --> 1404.5 / 28 = 50.16 Hz per screen
	movlb	0
	bcf	NEXT_STEP
; this part handle keyboard status
	decf	BIT_CNT,w	; 000DDSSS DD=digit SSS segment on digit (segment 111 does not exist and is skipped by TrisConvert (interested only to 0-5 for previous round)
	andlw	b'11110000'	; digit 1 and 2 have correct button order
	btfss	STATUS,Z
	goto	SkipButton
	decf	BIT_CNT,w	; 000DDSSS DD=digit SSS segment on digit (segment 111 does not exist and is skipped by TrisConvert
	andlw	b'00000111'	; segment number mean button number
	call	BitConvert
	xorlw	0xFF		; invert bit position
	andwf	BTNS,f		; remove particular bit...
	xorlw	0xFF		; invert bit position again
	btfss	SWIN2		; only if button is pressed
	iorwf	BTNS,f		; set particular bit back

SkipButton:
	incf	BIT_CNT,f	; next step
	movf	BIT_CNT,w	; 000DDSSS DD=digit SSS segment on digit (segment 111 does not exist and is skipped by TrisConvert
	call	TrisConvert	; prepare TRIS (it will automatically skip non-existing segment 111 and roll over for MAX)
	movwf	NEWTRISC	; bits 6 and 7 are for TRISA, rest are for TRISC
	bcf		NEWTRISA,0
	bcf		NEWTRISA,1
	btfsc	NEWTRISC,6	; copy bit TRISC6 to bit TRISA0
	bsf		NEWTRISA,0
	btfsc	NEWTRISC,7	; copy bit TRISC7 to bit TRISA1
	bsf		NEWTRISA,1
	rlf		BIT_CNT,w	; 00DDSSSx DD=digit SSS segment on digit (segment 111 does not exist and is skipped by TrisConvert
	andlw	0x30		; 00DD0000 DD=digit
	movwf	TEMP
	swapf	TEMP,w		; 000000DD DD=digit
	movwf	FSR0L		; save digit for near future
	call	LatConvert	; convert to bit position
	movwf	NEWLATC		; bits 6 and 7 are for LATA, rest are for LATC
; time to check segment lighting
	movlw	DIG1		; first digit
	addwf	FSR0L,f		; add to pointer
	clrf	FSR0H
	movf	BIT_CNT,w	; 000DDSSS DD=digit SSS segment on digit (segment 111 does not exist and is skipped by TrisConvert
	andlw	0x07		; 00000SSS
	call	BitConvert	; bit of segment
	andwf	INDF0,w		; is bit set?
	btfsc	STATUS,Z
	clrf	NEWLATC		; if no, clear LATs
	clrf	NEWLATA		; prepare bits for LATA
	btfsc	NEWLATC,6	; copy bit LATC6 to bit LATA0
	bsf		NEWLATA,0
	btfsc	NEWLATC,7	; copy bit LATC6 to bit LATA0
	bsf		NEWLATA,1
; time to evaluate buttons is every full screen refresh
	movf	BIT_CNT,w
	btfss	STATUS,Z
	return				; not full refresh, then go home

	btfsc	BTN_S0		; set seconds to zero
	clrf	C_SEC		; done	possible future improvement is to clear Timer2
	movf	BTNS,w		; button matrix
	xorwf	OLDBTNS,w	; copy of button matrix used for momentary buttons
	btfsc	STATUS,Z	; check for momentary buttons
	return				; no change
	movwf	TEMP		; save changes

	btfsc	BTN_HM
	btfss	TEMP,2
	goto	SkipBtnHM	; no Hour Minus button pressed
	decf	C_HOURS,f	; minus one hour
	incf	C_HOURS,w	; was it 00? then must be set to 23
	btfss	STATUS,Z
	goto	SkipBtnHM	; no, can continue
	movlw	.23
	movwf	C_HOURS

SkipBtnHM:
	btfsc	BTN_HP
	btfss	TEMP,3
	goto	SkipBtnHP	; no Hour Plus button pressed
	incf	C_HOURS,f	; plus one hour
	movf	C_HOURS,w	; is it 24? then must be set to 00
	xorlw	.24
	btfsc	STATUS,Z
	clrf	C_HOURS		; set 00

SkipBtnHP:
	btfsc	BTN_MM
	btfss	TEMP,0
	goto	SkipBtnMM	; no Minute Minus button pressed
	decf	C_MIN,f	; minus one minute
	incf	C_MIN,w	; was it 00? then must be set to 59
	btfss	STATUS,Z
	goto	SkipBtnMM	; no, can continue
	movlw	.59
	movwf	C_MIN

SkipBtnMM:
	btfsc	BTN_MP
	btfss	TEMP,1
	goto	SkipBtnMP	; no Minute Plus button pressed
	incf	C_MIN,f	; plus one hour
	movf	C_MIN,w	; is it 60? then must be set to 00
	xorlw	.60
	btfsc	STATUS,Z
	clrf	C_MIN		; set 00

SkipBtnMP:
	movf	BTNS,w		; copy buttons to old buttons
	movwf	OLDBTNS
	goto	DrawScreen	; some change on digits appear, screen should be re-draw

; ----------------------------------------------------------------------

; ----------------------------------------------------------------------
	org	SAF1_INI

		dt	"CharliPX"
		dt	" J.Fucik"
		dt	(__VERDAY   >> 4)  +0x30
		dt	(__VERDAY   & 0x0F)+0x30,"/"
		dt	(__VERMONTH >> 4)  +0x30
		dt	(__VERMONTH & 0x0F)+0x30,"/"
		dt	(__VERYEAR  >> 4)  +0x30
		dt	(__VERYEAR  & 0x0F)+0x30

		end