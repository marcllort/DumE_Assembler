




LIST P=PIC18F4321	F=INHX32
#include <p18f4321.inc>


; DUBTES
; Com configurar entrades analogiques
; TX i RX diu datasheet configurarlos els dos a 1 (trisa), es correcte?
; Cal activar els pull-ups interns al port B?
; Cal pujar la frequencia a 10MHZ/4mhz i recalcular els 20ms
; Cal un transisitor per cada led rgb
; Si canvies mode 0 mentre graba que passa?

; Configuraci? General

CONFIG  OSC		= HSPLL			; L'oscil.lador
CONFIG  PBADEN		= DIG			; Volem que el PORTB sigui DIGital
CONFIG  WDT		= OFF			; Desactivem el Watch Dog Timer
CONFIG LVP=OFF

    
; Variables

Mode		EQU 0x00			; Indica el mode en el que estem actualment
Vegades		EQU 0x01			; Serveix per contar el nombre de cops que ha grabat reproduit
Angle0		EQU 0x02			; Angle actual del Servo0
Angle1		EQU 0x03			; Angle actual del Servo1
PWMSERVO0	EQU 0x04			; Senyal de PWM que enviem al Servo0
PWMSERVO1	EQU 0x05			; Senyal de PWM que enviem al Servo0
Canvi		EQU 0x06			; Var que indica quan cal canviar de led la sortida
Valor		EQU 0x07			; Var que serveix per comparar amb el Ta1 de cada PWM
Count		EQU 0x08			; Contador per fer un bucle de 100 al LOOP de main
Graba		EQU 0x09			; Var que indica si estem grabant o reproduint en el mode 3 o 4
VarToca		EQU 0xA				; Var que serveix per indicar si cal contar o no per quan cal arribar als 10s
TaulaRGB	EQU 0xB

; Configuraci? Interrupcions

ORG 0x0000
GOTO    MAIN
ORG 0x0008    
GOTO    HIGH_RSI 
ORG 0x0018
RETFIE  FAST		
		

		
		
; ------------------------------------------------------------------------ TAULES -------------------------------------------------------------------------------------------------------------------		
		
;ORG TaulaRGB		
;Segments del 0, segments del 23
;DB 0x00, 0x01
;Segments del 46, segments del 69
;DB 0x02, 0x03
;Segments del 91, segments del 114
;DB 0x04, 0x05
;Segments del 136, segments del 159
;DB 0x06, 0x07
    		
		
		
; ----------------------------------------------------------------------- INITS ---------------------------------------------------------------------------------------------------------------------

		
		
    
INIT_VARS
    ; Farem que al iniciar el programa, ens posi el valor dels Servo a la posicio dels joystick
    MOVLW	.15
    MOVWF	PWMSERVO0,0
    MOVLW	.15
    MOVWF	PWMSERVO1,0

    
    ; Iniciem Variables
    ;MOVLW	.1				;Escullo el mode inicial, aixo es nmomes per proves, cal borrar, ha de funcionar pel switch
    ;MOVWF	Mode,0
    
    
    
    BCF	Mode,0,0
    BTFSC	PORTB,RB4,0			; Si hi ha 0 al port, assignem 0 al bit de menys pes de Mode
    BSF	Mode,0,0			; Sino, assignem un 1
    BCF	Mode,1,0
    BTFSC	PORTB,RB5,0
    BSF	Mode,1,0
    
    CLRF	Vegades,0
    
    ; Agafem Angle0 i 1 quan sapiguem
    CLRF	Canvi,0
    CLRF	Valor,0
    CLRF	Count,0
    SETF	Graba,0

RETURN
    
   
INIT_PORTS
    ; SETF    ADCON1,0	Cal configurar correctament les entrades analogiques
    MOVLW	b'00000001'			; Nose sio cal configurar encara, nomes activo ADON
    MOVWF	ADCON0,0
    MOVLW	b'00001011'			; Activem com entrades analogiques de AN0 a AN3
    MOVWF	ADCON1,0
    

    ; Sortides
    BCF		TRISA,RA4,0			; !CSRam
    BCF		TRISA,RA5,0			; R/!WRAM
    CLRF	TRISC,0				; ServoRGB(0 a 2), pwmServo0(3), pwmServo1(4), LED0(5)				Pot ser que TX i RX estiguin mal configurats
    BCF		TRISE,RE0,0			; NextPos
    BCF		TRISE,RE1,0			; NRPos
    BCF		TRISE,RE2,0			; 20ms
    
    CLRF	TRISD,0				; Inicialment posem BDRam com a sortida per poder-hi escriure

	; Entrades
    BSF		TRISA,AN0,0			; JoystickServo0
    BSF		TRISA,AN1,0			; JoystickServo1
    BSF		TRISA,AN2,0			; AngleServo0
    BSF		TRISA,AN3,0			; AngleServo1
    SETF	TRISB,0				; PWM0+-(0,1), PWM1+-(2,3), Mode(4,5) 
    BSF		TRISE,RE3,0			; MCLR
	BSF		TRISC,6,0			; Posem a entrada TX i RX
	BSF		TRISC,6,0
	
	
    ; Iniciem Sortides
    BSF		LATA,RA4,0			; !CSRam
    BCF		LATA,RA5,0			; R/!WRAM
    BCF		LATE,RE0,0			; NextPos
    BSF		LATE,RE1,0			; NRPos fem reset incial
    BCF		LATE,RE1,0			; NRPos
    CLRF	LATC,0				; LEDRGB(0 a 2)	pwmServo0(3), pwmServo1(4), LED0(5)
    
    
    ; Iniciem ADCON
    MOVLW	b'00001011'			; Deixem voltatges de referencia de 0V a 5V
    MOVWF	ADCON1,0			; Posem els ports analògics del AN0 al AN3
    MOVLW	b'00001001'			; Justifiquem a la esquerra (ADRESH) i temps i clock a alta velocitat
    MOVWF	ADCON2,0
    

    ; Pull-Ups (Nose si cal)
    BCF		INTCON2, RBPU,0
    
RETURN
    
INIT_RSI
    BCF		RCON,IPEN,0			; Desactivem les prioritats
    MOVLW	b'11101000'
    MOVWF	INTCON,0			; Habilitem totes les interrupcions de Timer0 i PortChange
RETURN    
    
    
INIT_TIMER
    MOVLW	b'10010001'			; Configurem el TIMER0
    MOVWF	T0CON,0				; Timer0 Controller
    CALL	CARREGA_TIMER			; Carreguem el TIMER0
RETURN    
    
    
    
    
    
; ---------------------------------------------------------------------- FUNCIONS ------------------------------------------------------------------------------------------------------------------------------------

CARREGA_TIMER
    BCF		INTCON,TMR0IF,0			; Netegem el bit de causa d'interrupci?
    MOVLW	HIGH(.15525)			; 20ms = 0.1us*50000(200000/4 de prescaler) --> 65535-50000= 15525 si anem a 40Mhz
    MOVWF	TMR0H,0
    MOVLW	LOW(.15525)	
    MOVWF	TMR0L,0
RETURN
    
    
DeuSeg
    BTG		Graba,0,0			; Neguem el bit 0 de Graba per indicar que cal fer la accio diferent
    CLRF	Vegades,0
    CLRF	TRISD,0				; Posem BDRam com a sortida per poder-hi escriure
    BCF		LATC,RC5,0			; Apaguem LED0 per indicar que no estem grabant
RETURN    
    
    
RECORD	; Inicialment tindrem BDRam configurat com sortida, R/!W en mode escritura i !CSRam a 1 (desactivat)
	; Primer ens caldra traduir de analogic a digital, i treure aquest valor per BDRam [0..7]
	; Un cop tenim el valor a BDRam, activarem CS per guardar i desactivarem, i despr?s farem un pols de adre?a (NextPos)
	
	
    BSF		LATC,RC5,0			; Encenem LED0 per indicar que estem grabant
    
    
    ; Servo0
    
    MOVLW	b'00001001'			; ADCON0 al canal AN2 i ADON activat
    MOVWF	ADCON0,0
    BSF		ADCON0,1,0
    ESPEREM2					; Esperem a que acabi de convertir el valor
    BTFSC	ADCON0,1,0
    GOTO	ESPEREM2
    
    MOVFF	ADRESH,LATD			; Copiem els 8 bits de més pes a el LATD	
    
    BCF		LATA,RA5,0			; R/!W RAM
    BCF		LATA,RA4,0			; Activem !CSRam
    BSF		LATA,RA4,0			; Desactivem !CSRam
    
    BSF		LATE,RE0,0			; NextPos
    BCF		LATE,RE0,0			; NextPos
    
    ; Servo1
    
    MOVLW	b'00001101'			; ADCON0 al canal AN3 i ADON activat
    MOVWF	ADCON0,0
    BSF		ADCON0,1,0
    ESPEREM3					; Esperem a que acabi de convertir el valor
    BTFSC	ADCON0,1,0
    GOTO	ESPEREM3
    
    MOVFF	ADRESH,LATD			; Copiem els 8 bits de més pes a el LATD	
    
    BCF		LATA,RA5,0			; R/!W RAM
    BCF		LATA,RA4,0			; Activem !CSRam
    BSF		LATA,RA4,0			; Desactivem !CSRam
    
    BSF		LATE,RE0,0			; NextPos
    BCF		LATE,RE0,0			; NextPos

RETURN


PLAY    ; Rebem el valor per BDRam, el passem a PWMSERVOX
    BCF		LATC,RC5,0			; Apaguem LED0 per indicar que estem reprofuint
    SETF	TRISD,0				; Inicialment posem BDRam com a entrada per poder llegir
    BSF		LATA,RA5,0			; R/!WRAM
    BCF		LATA,RA4,0			; !CSRam

    ; Llegim valor i el passem a PWMSERVO0
    MOVFF	LATD,PWMSERVO0
    BSF		LATE,RE0,0			; Activem NextPos
    BCF		LATE,RE0,0			; Desactivem NextPos
    
    ; Llegim valor i el passem a PWMSERVO1
    MOVFF	LATD,PWMSERVO1
    BSF		LATE,RE0,0			; Activem NextPos
    BCF		LATE,RE0,0			; Desactivem NextPos

RETURN
    
NoPWM
    BSF		TRISC,RC6,0			; pwmServo0
    BSF		TRISC,RC7,0			; pwmServo1
    BSF		LATE,RE1,0			; Activem NRPos
    BCF		LATE,RE1,0			; Activem NRPos
RETURN


ResetPos
    BSF		LATE,RE1,0			; Activem NRPos
    BCF		LATE,RE1,0			; Activem NRPos
RETURN


ENVIA_PC


RETURN    
    
; ------------------------------------------------------------------------ RSI -----------------------------------------------------------------------------------------------------------------------------
    
HIGH_RSI
    BTFSC	INTCON,TMR0IF,0
    CALL	TIMER_RSI			; Interrupci? per TIMER0
    BTFSC	INTCON,RBIF,0
    CALL	MODE_RSI			; Interrupci? per canvi de mode als switch
RETFIE FAST
    
    
TIMER_RSI
    CALL	CARREGA_TIMER			; Carrego timer 
    BSF		LATC,RC3,0
    BSF		LATC,RC4,0
        BSF		LATC,RC5,0

    MOVLW	.0
    CPFSLT	Mode,0
    CALL	MODE0				; Moviment per polsadors, 1 grau cada 20ms apretats
    MOVLW	.1
    CPFSLT	Mode,0	    
    CALL	MODE1				; Llegir valors joystick i posar-los directament al PWMSERVOX
    MOVLW	.2
    CPFSLT	Mode,0	    
    CALL	MODE23				; Grabar 10 moviment per joystick/Grabar 10 moviment manual, apagar PWM's
    
    
    CLRF	Valor,0				; Netejem valor, que indica el temps que esta a 1 cada pwm a dins el LOOP del main
    
    BTG		LATE,RE2,0			; Pols de 20ms
RETURN

MODE_RSI
    BCF	Mode,0,0
    BTFSC	PORTB,RB4,0			; Si hi ha 0 al port, assignem 0 al bit de menys pes de Mode
    BSF	Mode,0,0			; Sino, assignem un 1
    BCF	Mode,1,0
    BTFSC	PORTB,RB5,0
    BSF	Mode,1,0

    ;BCF	TRISA,RA6,0			; pwmServo0
    ;BCF	TRISA,RA7,0			; pwmServo1

    ;Btg		LATC,RC4,0			; Apaguem LED0 si esta obert

    ; Cladr? bloquejar que si esta grabant no puguis canviar de mode

;   MOVLW	.3				; Si es mode 3, desactivem PWM's per poder moure servos manualment
;   CPFSLT	Mode,0
;   CALL	NoPWM

;   MOVLW	.2				; Si es mode 2 (a NoPWM/mode 3 fem el mateix) fem un reset del contador per comen?ar a grabar
;   CPFSLT	Mode,0
;   CALL	ResetPos

    BCF		INTCON,RBIF,0			; Netejem flag de interrupci?
RETURN    
    
    
    
; ---------------------------------------------------------------------- MODES -------------------------------------------------------------------------------------------------------------------------
    
MODE0
    ;Caldr? sumar/restar a PWMSERVO0 i 1, el valor de 1 grau si el respectiu pulsador esta apretat i resetejar la variable

    MOVLW	.5				; Valor a sumar/restar per fer un grau, per fer el Ta1--------------------------------------------------------

    BTFSS	PORTB,RB0,0			; Fem polling per saber quin boto esta apretat i aix? saber que cal modificar
    ADDWF	PWMSERVO0,1,0
    ;BSF	LATC,5,0
        
    BTFSS	PORTB,RB1,0
    SUBWF	PWMSERVO0,1,0

    BTFSS	PORTB,RB2,0
    ADDWF	PWMSERVO1,1,0

    BTFSS	PORTB,RB3,0
    SUBWF	PWMSERVO1,1,0

    MOVLW	.255				; Controlem si el Servo es passa de 180 per no for?ar-lo----------------------------------------------------------
    CPFSLT	PWMSERVO0,0
    MOVWF	PWMSERVO0,0

    MOVLW	.0				; Controlem si el Servo es passa per sota de 0 per no for?ar-lo CREC Q NO CALDRA CAP DELS DOS
    CPFSGT	PWMSERVO0,0
    MOVWF	PWMSERVO0,0

RETURN

    
MODE1
    ; Cal treballar en analogic per llegir el valor del joystick, i posarlo directament al servo. Si no estas tocant el joystick anmira a 90 90, cal regular perq no es passi de 180 i no carreguei el servo
    MOVLW	b'00000001'			; ADCON0 al canal AN0 i ADON activat
    MOVWF	ADCON0,0
    BSF		ADCON0,1,0
    ESPEREM					; Esperem a que acabi de convertir el valor
    BTFSC	ADCON0,1,0
    GOTO	ESPEREM
    
    MOVFF	ADRESH,PWMSERVO0		; Copiem els 8 bits de més pes a el PWMSERVO0
    
    
    MOVLW	b'00000101'			; ADCON0 al canal AN1 i ADON activat
    MOVWF	ADCON0,0
    BSF		ADCON0,1,0
    ESPEREM1					; Esperem a que acabi de convertir el valor
    BTFSC	ADCON0,1,0
    GOTO	ESPEREM1
    
    MOVFF	ADRESH,PWMSERVO1		; Copiem els 8 bits de més pes a el PWMSERVO1
    

RETURN    
    
    
MODE23
    BTFSC	VarToca,0,0			; Mirem si toca contar, ja que volem contar un cop si un no perque la var es de 8 bits
    INCF	Vegades,1,0			; Pujem 1 el contador de vegades
    BTG		VarToca,0,0			; Fem que el seguent cop conti o no segons el que ha fet anteriorment

    BTFSC	Graba,0,0			; Si esta a 1, executem GRABA
    CALL	RECORD
    BTFSS	Graba,0,0			; Si esta a 0, executem PLAY
    CALL	PLAY	
    
    MOVLW	.250
    CPFSLT	Vegades,0			; Si ha arribat a 500 voltes executem DeuSeg
    CALL	DeuSeg				; Canvia el estat de grabar/reproduir, neteja variable vegades
    
RETURN    
    
    
    
    
; ----------------------------------------------------------------------- MAIN -------------------------------------------------------------------------------------------------------------------------------

    
MAIN
    CALL INIT_VARS
    CALL INIT_PORTS
    CALL INIT_RSI
    CALL INIT_TIMER
    
LOOP
    ESPERA1					; Bucle que fa 100 voltes i despr?s incrementa en 1 el valor de temps a comparar amb el que ha d'adquirir cada servo
    MOVLW   .217				; CAL AJUSTAR PERQUE FUNCIONI DE 0 A 255, EN COMPTES DE 0 180
    MOVWF   Count,0 
    INCREMENTA              
    INCF    Count,1 
    BTFSS   STATUS,C,0  
    GOTO    INCREMENTA
    INCF    Valor,1				; A la interrupcio caldr? resetejarlo, igual que caldra posar a 1 les sortides dels pwm
    MOVF    Valor,0				; Copio valor a wreg
    CPFSGT  PWMSERVO0,0			; Valor entre el maxim i el minim que accepti el servo
    BCF	    LATC,RC5,0
    CPFSGT  PWMSERVO1,0
    BCF	    LATC,RC4,0	
GOTO LOOP

	



	
	
	
	
	
	
	
	
	
    ; LEGACY-------------------------------- OSC 4MHZ I RGB'S FUNCIONS------------------- CAL FERHO AMB TAULES DB....

    
INIT_OSC
    MOVLW b'01100111'				; Posem el INTIO a 4 MHZ, tInst = 1us
    MOVWF OSCCON,0
RETURN     

SETRGB_180
    BSF LATC0,0
    BSF LATC1,0
    BSF LATC2,0
RETURN
SETRGB_158
    BSF LATC0,0
    BSF LATC1,0
    BCF LATC2,0
RETURN
SETRGB_135
    BSF LATC0,0
    BCF LATC1,0
    BSF LATC2,0
RETURN
SETRGB_113
    BSF LATC0,0
    BCF LATC1,0
    BCF LATC2,0
RETURN
SETRGB_90
    BCF LATC0,0
    BSF LATC1,0
    BSF LATC2,0
RETURN
SETRGB_68
    BCF LATC0,0
    BSF LATC1,0
    BCF LATC2,0
RETURN
SETRGB_45
    BCF LATC0,0
    BCF LATC1,0
    BSF LATC2,0
RETURN
SETRGB_22
    BCF LATC0,0
    BCF LATC1,0
    BCF LATC2,0
RETURN




RGB0
    CLRF Canvi,0

    MOVLW .159
    CPFSLT Angle0,0
    CALL SETRGB_180
    MOVLW .136
    CPFSLT Angle0,0
    CALL SETRGB_158
    MOVLW .114
    CPFSLT Angle0,0
    CALL SETRGB_135
    MOVLW .91
    CPFSLT Angle0,0
    CALL SETRGB_113
    MOVLW .69
    CPFSLT Angle0,0
    CALL SETRGB_90
    MOVLW .46
    CPFSLT Angle0,0
    CALL SETRGB_68
    MOVLW .23
    CPFSLT Angle0,0
    CALL SETRGB_45
    CALL SETRGB_22
RETURN

RGB1
    SETF Canvi,0

    MOVLW .159
    CPFSLT Angle1,0
    CALL SETRGB_180
    MOVLW .136
    CPFSLT Angle1,0
    CALL SETRGB_158
    MOVLW .114
    CPFSLT Angle1,0
    CALL SETRGB_135
    MOVLW .91
    CPFSLT Angle1,0
    CALL SETRGB_113
    MOVLW .69
    CPFSLT Angle1,0
    CALL SETRGB_90
    MOVLW .46
    CPFSLT Angle1,0
    CALL SETRGB_68
    MOVLW .23
    CPFSLT Angle1,0
    CALL SETRGB_45
    CALL SETRGB_22
RETURN
    
    
    
    
    
END