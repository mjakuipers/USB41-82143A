; Emulating PRINTER-1E (82143A) for USB connection
; ver. TP, includes TRACE/MAN switching (Jun. 5th. 2012)
; Ver. XP, includes BS (Jun. 11th 2012)
; Ver. xx, modifications added by Meindert Kuipers spring 2023 to support graphics mode
;          restored original flag 12 + 13 functions for double wide mode en lower case alpha
;          to work with the updated HP82240 printer emulator in HP82143 mode

; Trying to work on 32MHz, internal oscilator PLL mode. 7/02/2012

; Upgrade to allow 8 pages v9. 22/04/2012

; DATA C detected at h'6D70, status is sent during h'6D71
; BYTE to print detected at h'6E33

	list 	  P = 18f2620	; set processor type 
	list 	  n = 0		; supress page breaks in list file
	#include <p18f2620.inc>	; Processor Include file
	list			; turn listing on

; Configuration constants

	__config 0x300001,0x08	; Enables INTERNAL oscillator mode
	__config 0x300002,0x18	; Prevents Brown out Reset
	__config 0x300003,0x00	; Disables Watch Dog Timer
	__config 0x300005,0x81	; Disables Timer, PORTB is I/O
	__config 0x300006,0x80	; Disables Low Voltage Programming

; Config Signature

#include	"sgnat64h.asm"

; Definitions of I/O lines

#define 	NUTPHI1	PORTB,2 
#define 	NUTPHI2	PORTB,6 
#define 	NUTSYNC	PORTB,5 
#define	NUTISA	PORTB,4
#define	NUTDATA	PORTB,7
#define	NUTPWO	PORTB,0

#define	OUTISA	PORTB,4

; Define where to map each page/bank

		CBLOCK 0x00

		rom0b1map
		rom1b1map
		rom2b1map
		rom3b1map
		rom4b1map
		rom5b1map
		rom6b1map
		rom7b1map
		rom8b1map
		rom9b1map
		romab1map
		rombb1map
		romcb1map
		romdb1map
		romeb1map
		romfb1map
		rom0b2map
		rom1b2map
		rom2b2map
		rom3b2map
		rom4b2map
		rom5b2map
		rom6b2map
		rom7b2map
		rom8b2map
		rom9b2map
		romab2map
		rombb2map
		romcb2map
		romdb2map
		romeb2map
		romfb2map
		rom0b3map
		rom1b3map
		rom2b3map
		rom3b3map
		rom4b3map
		rom5b3map
		rom6b3map
		rom7b3map
		rom8b3map
		rom9b3map
		romab3map
		rombb3map
		romcb3map
		romdb3map
		romeb3map
		romfb3map
		rom0b4map
		rom1b4map
		rom2b4map
		rom3b4map
		rom4b4map
		rom5b4map
		rom6b4map
		rom7b4map
		rom8b4map
		rom9b4map
		romab4map
		rombb4map
		romcb4map
		romdb4map
		romeb4map
		romfb4map

		addru				; upper 8 bits of ISA address
		addrl				; lower 8 bits of ISA address	
		oph2				; high two bits of fetched word
		opl8				; low eight bits of fetched word
		adrhg
		adrlw
		dth2
		dtl8

		enromoff
						; edit by Meindert Kuipers, added explanation of status bits
		statusl			; Set to h'03 for preliminary test
						; bit 7: LCA - Lower Case Alpha
						; bit 6: SCO - Special Column Output
						; bit 5: DWM - Double Wide Mode
						; bit 4: TEO - Type Of EOL (if set: Right Justify)
						; bit 3: EOL - Last EOL (set if last bit was EOLL/EOLR)
						; bit 2: HLD - Hold for Paper (ignored, always zero)
						; bit 1: not used, always 1
						; bit 0: not used, always 1
							
		statush			; Set to h'43 for preliminary test
						; bit 7 (15): SMA - ALL mode (set of TRACE mode), default 0
						; bit 6 (14): SMB - NORM mode, default 1
						; bit 5 (13): PRT, Print Key down, not used, always 0
						; bit 4 (12): ADV, Advance Key down, not used, always 0
						; bit 3 (11): OOP, Out Of Paper, not used, always 0
						; bit 2 (10): LB, Low Battery, not used, always 0
						; bit 1 (09): IDL, Idle condition, always 1
						; bit 0 (08): BE, Buffer Empty, always 1					

		in_byte			; received byte from DATA PHI2 to PHI9
		carry				; bit 0=1 if carry needs to be sent
						; carry is only sent if it's = 1
		stat_out			; bit 0 = 1 if status must be sent (03A)
		byte_in			; bit 0 = 1 if byte must be sent to Tx

		SELP9_L			; h'64
		SELP9_H			; h'02

		SELP9_ON			; bit 0=1 indicates last OPCODE was SELP9

		IS_ON				; h'83, printer SELP9 instruction
		IS_STS			; h'43, printer SELP9 instruction
		IS_BSY			; h'03, printer SELP9 instruction

		ST_OUT			; h'3A, printer SELP9 instruction
		BTY_IN			; h'07, printer SELP9 instruction

		dummy

		ENDC

; *****************************************************************
		
wthi		macro	nutport,nutsignal	; loops until signal is hi
		local	ll
ll		btfss	nutport,nutsignal
		bra	ll
		endm

wtlo		macro	nutport,nutsignal	; loops until signal is lo
		local ll
ll		btfsc	nutport,nutsignal
		bra	ll
		endm

wtre		macro	nutport,nutsignal	; waits for rising edge
		wtlo	nutport,nutsignal
		wthi	nutport,nutsignal
		endm

wtfe		macro	nutport,nutsignal	; waits for falling edge
		wthi	nutport,nutsignal
		wtlo	nutport,nutsignal
		endm

; ********************************************** Code begins here ******************
; Reset vector

rst		org	0x000000
		goto	begin

; Interrupt 0 (high priority) vector

itrrh		org 	0x000008		; Detected PWO falling edge
		bra	start			; Go to SLEEP and waits for PWO rising edge

begin		org	0x000010

		bsf	OSCCON,5		; Sets internal oscillator to 4MHz...
		bsf	OSCCON,4		; ... and then to 8MHz.

		bsf	OSCTUNE,TUN0	; Tune to max frequency (about 35.75MHz)
		bsf	OSCTUNE,TUN1	; Every bit increases about 250KHz.
		bsf	OSCTUNE,TUN2
		bsf	OSCTUNE,TUN3
		bsf	OSCTUNE,6		 ; Enables PLL to run at 32MHz

; Serial port baud rate settings
						; To 128000bps SPBRG = 61 (0x3D) @ 32MHz
						; 35.75MHz gives 68.8 (h'44)

		bsf	BAUDCON,BRG16	; Sets Baud Rate Generator to 16bit
		bsf	TXSTA,BRGH		; Sets Baud rAte Generator to High Speed
		movlw	0x4C			; Sets Baud_Rate_Generator 4C for 115200
		clrf	SPBRGH		; Fosc/[4·(n+1)], calculated valued is h'3D
		movwf	SPBRG			; Value is compensated by 8 (h'44) due to Freq TUN-ing

; Ports initialization

		setf	TRISA
		setf	TRISB
		setf	TRISC

		bsf	RCSTA,SPEN		; Enables serial port
		bsf	TXSTA,TXEN		; Enables serial Tx
		bsf	RCSTA,CREN		; Enables serial Rx

		clrf	PORTA
		clrf	PORTB			; initialize ports
		setf	PORTC

		clrf	TBLPTRU

; clear memory

		clrf	rom0b1map
		clrf	rom1b1map
		clrf	rom2b1map
		clrf	rom3b1map
		clrf	rom4b1map
		clrf	rom5b1map
		clrf	rom6b1map
		clrf	rom7b1map
		clrf	rom8b1map
		clrf	rom9b1map
		clrf	romab1map
		clrf	rombb1map
		clrf	romcb1map
		clrf	romdb1map
		clrf	romeb1map
		clrf	romfb1map
		clrf	rom0b2map
		clrf	rom1b2map
		clrf	rom2b2map
		clrf	rom3b2map
		clrf	rom4b2map
		clrf	rom5b2map
		clrf	rom6b2map
		clrf	rom7b2map
		clrf	rom8b2map
		clrf	rom9b2map
		clrf	romab2map
		clrf	rombb2map
		clrf	romcb2map
		clrf	romdb2map
		clrf	romeb2map
		clrf	romfb2map
		clrf	rom0b3map
		clrf	rom1b3map
		clrf	rom2b3map
		clrf	rom3b3map
		clrf	rom4b3map
		clrf	rom5b3map
		clrf	rom6b3map
		clrf	rom7b3map
		clrf	rom8b3map
		clrf	rom9b3map
		clrf	romab3map
		clrf	rombb3map
		clrf	romcb3map
		clrf	romdb3map
		clrf	romeb3map
		clrf	romfb3map
		clrf	rom0b4map
		clrf	rom1b4map
		clrf	rom2b4map
		clrf	rom3b4map
		clrf	rom4b4map
		clrf	rom5b4map
		clrf	rom6b4map
		clrf	rom7b4map
		clrf	rom8b4map
		clrf	rom9b4map
		clrf	romab4map
		clrf	rombb4map
		clrf	romcb4map
		clrf	romdb4map
		clrf	romeb4map
		clrf	romfb4map

		clrf	addru			; upper 8 bits of ISA address
		clrf	addrl			; lower 8 bits of ISA address	
		clrf	oph2			; high two bits of fetched word
		clrf	opl8			; low eight bits of fetched word
		clrf	enromoff

		

; Constant initialization

		movlw	0x64
		movwf	SELP9_L		; h'64
		movlw	0x06
		movwf	SELP9_H		; h'06, bit 2 indicates it's an OPCODE

		clrf	SELP9_ON		; bit 0=1 indicates last OPCODE was SELP9

		clrf	carry
		clrf	stat_out
		clrf	byte_in
		clrf	dummy


		movlw	0x83
		movwf	IS_ON			; h'83

		movlw	0x43
		movwf	IS_STS		; h'43


		movlw	0x03
		movwf	IS_BSY		; h'03
		movwf	statush		; initialize printer status bits
		movwf	statusl		; initialize printer status bits
;		bsf	statush,7

		movlw	0x3A
		movwf	ST_OUT		; h'3A

		movlw	0x07
		movwf	BTY_IN		; h'07		

; load rom mapping

;#include	"mapping.asm"

		movlw	0x40
		movwf	rom6b1map

#include	"mapping1.asm"
#include	"mapping2.asm"


; end load rom mapping

start
		bsf	INTCON2,6		;+ Activates INT0 on rising edge
		bcf	INTCON,1		;+ Resets INT0 bit
		bsf	INTCON,4		;+ Enables INTO
		bcf	INTCON,GIE  	;+ Globally disables interrupts.
		clrf	enromoff
		sleep				;+ Waits until rising edge on PWO (PORTB,0)
		bcf	INTCON,1		;+ Resets INT0 bit after PWO rises.
		bcf	INTCON2,6		;+ Activates INT0 on falling edge
		bsf	INTCON,GIE
syncseek
		wtfe	NUTSYNC		; wait for SYNC to go low

pulse0					; we are now in pulse 0

		clrf	PORTB			; is this OK? might mess up statush bit 6, but this is not used anyway

		wtre	NUTPHI2		; 1

		bcf	PORTB,7
		btfsc	statush,7
		bsf	PORTB,7		; B7 = DATA
		
		btfsc	NUTSYNC		; test SYNC to avoid false sync. due to old 41's pulses
		bra	syncseek		; restart syncing due to false SYNC detection.

		bsf	PORTB,4		; B4 = ISA

		wtre	NUTPHI2		; 2 (Data valid strobe on phase 2)

		setf	TRISB			; status sent, can tristate B
		btfsc	carry,0		; If carry=1 must be sent (083 or 043)
		bcf	TRISB,4		; Sets ISA = 1 for phase 2

		wtre	NUTPHI1		; 2

		clrf	dtl8			; Clears data low8 for byte_in
		btfsc	NUTDATA
		bsf	dtl8,0

		wtre	NUTPHI2		; 3

		bsf	TRISB,4
		clrf	PORTB
		clrf	carry

		wtre	NUTPHI1		; 3

		btfsc	NUTDATA
		bsf	dtl8,1
		btfsc	opl8,0		; any even OP code exits SELP9
		clrf	SELP9_ON
		rrncf	SELP9_ON		; if previous OP was SELP9 sets bit 0

		wtre	NUTPHI1		; 4

		btfsc	NUTDATA
		bsf	dtl8,2

		wtre	NUTPHI1		; 5

		btfsc	NUTDATA
		bsf	dtl8,3

		wtre	NUTPHI1		; 6

		btfsc	NUTDATA
		bsf	dtl8,4

		wtre	NUTPHI1		; 7

		btfsc	NUTDATA
		bsf	dtl8,5

		wtre	NUTPHI1		; 8

		btfsc	NUTDATA
		bsf	dtl8,6
		clrf	dummy

		wtre	NUTPHI1		; 9

		btfsc	NUTDATA		; Gets last bit (b7) from DATA
		bsf	dtl8,7	
		movf	dtl8,W		; saves Byte to WREG
;		movwf	in_byte		; and in_byte variable
		btfss	byte_in,0		; is it a byte input cycle?
		bra	no_tx			; no, skip Transmit to PRINTER
		movwf	TXREG			; yes, send to PRINTER
;		clrf	byte_in
no_tx
		wtre	NUTPHI1		; 10

;		btfss	PIR1,RCIF
;		bra	NO_MODE
;		movf	RCREG,W
;		movwf	TXREG
;		movlw	0x57
;		movwf	TXREG

; March 2023
; code updated by Meindert Kuipers to support graphics mode
; and exact emulation of printer status bits SCO, DWM and LCA

		btfss	byte_in,0		; is it a byte input cycle?
		bra	NO_MODE1		; no, skip mode detection
		
						; byte is in WREG
		sublw 0xD7			; subtract W from 0xD7, W is now D7 - W
						; W > D7, result is negative, get out of this check
						; W = D7, result = 00
						; W < D7, result > 00
						; W = D0, result = 07
						; W < D0, result > 07

		bn    NO_MODE1		; bn=branch if negative, byte > D7, no check needed

						; W = W - D7 -07
		sublw 0x07			; if word <D0, no further check needed
		bn	NO_MODE1		; bn=branch if negative
		
; from here the word is 00..07, so status bits must be set accordingly
; we cannot test on bits in WREG 
; bit 0 = LCA, Lower Case Alpha      -> status bit 7
; bit 1 = SCO, Special Column Output -> status bit 6
; bit 2 = DWM, Double Wide MODE      -> status bit 5

		bcf	statusl,7		; LCA clear
		btfsc dtl8,0		; test LCA bit, skip if clear
		bsf	statusl,7		; set LCA status bit
		
		bcf	statusl,6		; SCO clear
		btfsc dtl8,1		; test SCO bit, skip if clear
		bsf	statusl,6		; set SCO status bit 

		bcf	statusl,5		; DWM clear
		btfsc dtl8,2		; test DWM bit, skip if clear
		bsf	statusl,5		; set DWM status bit		
		
		
; alternative code, needs redefinition of status bits but is much shorter if needed
;		iorlw	0xF8			; OR the incoming flag status with F8, to prepare for AND. This masks out the 3 relevant status bits
;		andwf	statusl		; AND incoming status in W with the status word, this is now the correct new status
		

; original code below:
;		sublw	0xD1			; yes, check if it's MODE swap
;		bz	MAN_MODE		; h'D1 = back to MAN mode (Flag 13 set)
;		movf	dtl8,W
;		sublw	0xD5		
;		bz	TRC_MODE		; h'D5 = sets TRACE mode (Flags 12 & 13 set)
;		bra	NO_MODE
;MAN_MODE
;		bcf	statush,7
;		bra	NO_MODE
;TRC_MODE
;		bsf	statush,7
; end of original code		
		
; line below had to be moved for checking EOLL and EOLR
;NO_MODE
;		clrf	byte_in		; clears byte input cycle flag.
		
NO_MODE1
		wtre	NUTPHI1		; 11
		
; next part is to check for 0xE0, EOLL or 0xE8, EOLR 
; and set the printer status bits accordingly
		
		btfss	byte_in,0		; is it a byte input cycle?
		bra	NO_MODE2		; no, skip EOL mode detection		
				
						; need to clear both EOL status bits in case it was not an EOL
		bcf	statusl,3		; clear EOL
		bcf	statusl,4		; clear TEO (EOLR seen)
		
		movf	dtl8,W		; byte now in WREG
		sublw	0xE8			; is it 0xE8 for EOLR? WREG = E8 - byte
		bnz	check_E0		; it is not xE8, check for E0
		bsf	statusl,4		; is was E8, set TEO status bit 4 to mark EOLR
		bsf	statusl,3		; and set EOL status bit
		bra	CLR_SCO		; to clear SCO, must be done after EOL
		
; if we get here, then the WREG is E8 - byte, 
; if it was E0 then W is now 08

check_E0	movf	dtl8,W
		sublw	0xE0
		bnz	NO_MODE2
		bsf 	statusl,3
		
CLR_SCO	bcf	statusl,6		; EOL always clears SCO, not sure if this is really needed

NO_MODE2	clrf	byte_in		; clears byte input cycle flag, all done
			
; end of modifications by Meindert Kuipers

;		bcf	RCSTA,CREN
;		bsf	RCSTA,CREN		; Enables serial Rx		

		wtre	NUTPHI1		; 12
						; test if the last opcode fetched was ENBANK1 or ENBANK2
		movf	oph2,W
		andlw	0x07			; bit 2 was set if SYNC was hi, indicating an opcode fetch
		sublw	0x05
		bnz	notenbank
		movf	opl8,W
		bnz	notenbank1
		bcf	enromoff,4		; opcode was 100 -> zero the bank offset
notenbank1	sublw	0x80
		bnz	notenbank		; only one of these two can happen!
		bsf	enromoff,4		; opcode was 180 -> set offset to 0x10
notenbank

		wtre	NUTPHI1		; 13

		wtre	NUTPHI1		; 14

		wtre	NUTPHI1		; 15

		clrf	addru			; Clears address for ISA fetch.
		clrf	addrl

		wtre	NUTPHI1		; 16

		btfsc	NUTISA
		bsf	addrl,0

		wtre	NUTPHI1		; 17

		btfsc	NUTISA
		bsf	addrl,1

		wtre	NUTPHI1		; 18

		btfsc	NUTISA
		bsf	addrl,2

		wtre	NUTPHI1		; 19

		btfsc	NUTISA
		bsf	addrl,3

		wtre	NUTPHI1		; 20

		btfsc	NUTISA
		bsf	addrl,4

		wtre	NUTPHI1		; 21

		btfsc	NUTISA
		bsf	addrl,5

		wtre	NUTPHI1		; 22

		btfsc	NUTISA
		bsf	addrl,6

		wtre	NUTPHI1		; 23

		btfsc	NUTISA
		bsf	addrl,7

		wtre	NUTPHI1		; 24

		btfsc	NUTISA
		bsf	addru,0

		wtre	NUTPHI1		; 25

		btfsc	NUTISA
		bsf	addru,1

		wtre	NUTPHI1		; 26

		btfsc	NUTISA
		bsf	addru,2

		wtre	NUTPHI1		; 27

		btfsc	NUTISA
		bsf	addru,3

		wtre	NUTPHI1		; 28

		btfsc	NUTISA
		bsf	addru,4

		wtre	NUTPHI1		; 29

		btfsc	NUTISA
		bsf	addru,5

		wtre	NUTPHI1		; 30

		btfsc	NUTISA
		bsf	addru,6
		
		wtre	NUTPHI1		; 31

		btfsc	NUTISA
		bsf	addru,7

		wtre	NUTPHI2		; 32

		movf	addru,W		; Testing if it's h'03A (Status out)
		sublw	0x6D			; Status must be sent at h'6D71
		bnz	no_sts
		movf	addrl,W
		sublw	0x71
		bnz	no_sts
		bsf	stat_out,0
no_sts
		
		wtre	NUTPHI2		; 33

		movf	addru,W		; Testing if it's h'007 (BYTE to print)
		sublw	0x6E
		bnz	no_btp
		movf	addrl,W
		sublw	0x33
		bnz	no_btp
		bsf	byte_in,0
no_btp

		wtre	NUTPHI2		; 34

;; The address of the opcode to fetch is in 
;; We compute where in the table to find oph2 and opl8
;; get the upper four bits of the address, and see where
;; it maps in our tables.

		movf	addru,W
		andlw	0xF0			; use the upper four bits ...
		swapf	WREG
		addwf	enromoff,W
		movwf	FSR0L			; as a pointer to the map table
		movf	INDF0,W		; read mapping info
		bnz	ours			; if page is mapped (ours) then go reading it!
		goto	notours		; else eat the next 22 pulses.
		
ours		wtre	NUTPHI2		; 35

		movwf	TBLPTRH
		movf	addru,W
		andlw	0x0f
		iorwf	TBLPTRH,F
		movf	addrl,W
		movwf	TBLPTRL
		tblrd	*
		movff	TABLAT,opl8
	
		wtre	NUTPHI2		; 36

		rrcf	TBLPTRH
		rrcf	TBLPTRL
		rrcf	TBLPTRH
		rrcf	TBLPTRL
		movf	TBLPTRH,W
		andlw	0x3f
		movwf	TBLPTRH
		tblrd	*
		movff	TABLAT,oph2

		wtre	NUTPHI2		; 37

		btfss	addrl,1
		bra	norot4
		swapf	oph2
norot4	btfss	addrl,0
		bra	norot2
		rrcf	oph2
		rrcf	oph2
norot2
		movlw	0x03
		andwf	oph2,F		; good time to mask this
		
		wtre	NUTPHI2		; 38

		movf	opl8,W		; Check if OP is SELP9 
		sublw	0x64
		bnz	no_selp9
		movf	oph2,W
		sublw	0x02
		bnz	no_selp9
		bsf	SELP9_ON,1		; found h'264 SELP9
no_selp9
		wtre	NUTPHI2		; 39

		btfss	SELP9_ON,0
		bra	no_083
		movf	oph2,W
		bnz	no_083
		movf	opl8,W
		sublw	0x83
		bnz	no_083
		bsf	carry,0
no_083
		wtre	NUTPHI2		; 40

		btfss	SELP9_ON,0
		bra	no_043
		movf	oph2,W
		bnz	no_043
		movf	opl8,W
		sublw	0x43
		bnz	no_043
		bsf	carry,0
no_043

		; start output status bits at phase 42
		; if no status output required, PORTB is tri-stated at phae 42
		
		wtre	NUTPHI2		; 41
		
		btfsc	stat_out,0
		bcf	TRISB,7
		clrf	stat_out

		wtre	NUTPHI2		; 42
		
		bcf	PORTB,7		; clear B7 (DATA)
		btfsc	statusl,0		; output statusl 0, status bit 0 (this bit is not used)
		bsf	PORTB,7		; set B7 if needed

		wtre	NUTPHI2		; 43

		bcf	PORTB,7
		btfsc	statusl,1		
		bsf	PORTB,7		; output statusl 0, status bit 1 (this bit is not used)

		wtre	NUTPHI2		; 44

		bcf	PORTB,7
		btfsc	statusl,2
		bsf	PORTB,7		; output statusl 0, status bit 2 = HLD(this bit is not used)

		wtre	NUTPHI2		; 45

		bcf	PORTB,7
		btfsc	statusl,3
		bsf	PORTB,7		; output statusl 0, status bit 3 = EOL

; 		clrf	PORTB			; this was NOT correct, clears DATA immediately

		wtre	NUTPHI2		; 46
		
		clrf	PORTB			; this is correct!		

		bcf	TRISB,4
		btfsc	opl8,0
		bsf	PORTB,4		; output ISA bit 0
		btfsc	statusl,4		
		bsf	PORTB,7		; output statusl 0, status bit 3 = EOL

		wtre	NUTPHI2		; 47
		
		clrf	PORTB
		btfsc	opl8,1
		bsf	PORTB,4		; output ISA bit 1		
		btfsc	statusl,5
		bsf	PORTB,7		; output statusl 5, status bit 3 = TEO

		wtre	NUTPHI2		; 48

		clrf	PORTB
		btfsc	opl8,2
		bsf	PORTB,4
		btfsc	statusl,6
		bsf	PORTB,7

		wtre	NUTPHI2		; 49

		clrf	PORTB
		btfsc	opl8,3
		bsf	PORTB,4
		btfsc	statusl,7
		bsf	PORTB,7

		wtre	NUTPHI2		; 50

		clrf	PORTB
		btfsc	opl8,4
		bsf	PORTB,4
		btfsc	statush,0
		bsf	PORTB,7
		btfsc	NUTSYNC		; are we an opcode fetch?
		bsf	oph2,2		; indicate that.

		wtre	NUTPHI2		; 51

		clrf	PORTB
		btfsc	opl8,5
		bsf	PORTB,4
		btfsc	statush,1
		bsf	PORTB,7

		wtre	NUTPHI2		; 52

		clrf	PORTB
		btfsc	opl8,6
		bsf	PORTB,4
		btfsc	statush,2
		bsf	PORTB,7

		wtre	NUTPHI2		; 53

		clrf	PORTB
		btfsc	opl8,7
		bsf	PORTB,4
		btfsc	statush,3
		bsf	PORTB,7

		wtre	NUTPHI2		; 54

		clrf	PORTB
		btfsc	oph2,0
		bsf	PORTB,4
		btfsc	statush,4
		bsf	PORTB,7


		wtre	NUTPHI2		; 55

		clrf	PORTB
		btfsc	oph2,1
		bsf	PORTB,4
		btfsc	statush,5
		bsf	PORTB,7


		wtre	NUTPHI2		; 0
		
		bsf	TRISB,4
		bcf	PORTB,7
		btfsc	statush,6
		bsf	PORTB,7

		goto	pulse0

;------------- Address is not on USB-41 module		
notours	
		movlw	0x16
keepeating	wtre	NUTPHI2
		decfsz	WREG
		bra	keepeating
		goto	pulse0

#include	"printusb.asm"		; final version
#include	"romimg4.asm"
#include	"romimg5.asm"
#include	"romimg6.asm"
#include	"romimg7.asm"
#include	"romimg8.asm"
#include	"romimg9.asm"
#include	"romimga.asm"
#include	"romimgb.asm"

		END                       ; directive 'end of program'



