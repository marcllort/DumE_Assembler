LIST P=PIC18F4321 F=INHX32
    #include <p18f4321.inc>



; DUBTES
    ; Les taules del led NO COMPILA
    ; Procediment de grabar/reproduir no funciona
    ; Que fer si canvio de mode durant una grabacio
    
    
    
; Configuracio General

    CONFIG  OSC		= HSPLL			; L'oscil.lador
    CONFIG  PBADEN	= DIG			; Volem que el PORTB sigui DIGital
    CONFIG  WDT		= OFF			; Desactivem el Watch Dog Timer
    CONFIG  LVP		= OFF

    
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
TaulaRGB	EQU 0xC				; Taula de la combinacio de els leds RGB
;TaulaJoystick	EQU 0xE				; Taula de conversio del valor convertit a digital, per ajustar als limits correctes
	

; Configuracio Interrupcions

    ORG	0x0000
    GOTO    MAIN
    ORG	0x0008    
    GOTO    HIGH_RSI 
    ORG	0x0018
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
    ;MOVLW	.15
    ;MOVWF	PWMSERVO0,0
    ;MOVLW	.15
    ;MOVWF	PWMSERVO1,0

    
    ; Iniciem Variables
    
    BCF		Mode,0,0
    BTFSC	PORTB,RB4,0			; Si hi ha 0 al port, assignem 0 al bit de menys pes de Mode
    BSF		Mode,0,0			; Sino, assignem un 1
    BCF		Mode,1,0
    BTFSC	PORTB,RB5,0
    BSF	    	Mode,1,0
    
    CLRF	Vegades,0
    
    ; Agafem Angle0 i 1 quan sapiguem
    CLRF	Canvi,0
    CLRF	Valor,0
    CLRF	Count,0
    SETF	Graba,0

    RETURN
    
   
INIT_PORTS  
    
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
    NOP
    NOP
    BCF		LATE,RE1,0			; NRPos
    CLRF	LATC,0				; LEDRGB(0 a 2)	pwmServo0(3), pwmServo1(4), LED0(5)
    
    
    ; Iniciem ADCON
    MOVLW	b'00001011'			; Deixem voltatges de referencia de 0V a 5V
    MOVWF	ADCON1,0			; Posem els ports anal?gics del AN0 al AN3
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
    MOVLW	HIGH(.15535)			; 20ms = 0.1us*50000(200000/4 de prescaler) --> 65535-50000= 15525 si anem a 40Mhz
    MOVWF	TMR0H,0
    MOVLW	LOW(.15535)	
    MOVWF	TMR0L,0
    
    RETURN
    
    
DeuSeg
    BTG		Graba,0,0			; Neguem el bit 0 de Graba per indicar que cal fer la accio diferent
    CLRF	Vegades,0
    CLRF	TRISD,0				; Posem BDRam com a sortida per poder-hi escriure
    BCF		LATC,RC5,0			; Apaguem LED0 per indicar que no estem grabant
    
    BSF		LATE,RE1,0			; Activem NRPos
    NOP
    NOP
    BCF		LATE,RE1,0			; Activem NRPos
    
    RETURN    
    
    
RECORD	; Inicialment tindrem BDRam configurat com sortida, R/!W en mode escritura i !CSRam a 1 (desactivat)
	; Primer ens caldra traduir de analogic a digital, i treure aquest valor per BDRam [0..7]
	; Un cop tenim el valor a BDRam, activarem CS per guardar i desactivarem, i despr?s farem un pols de adre?a (NextPos)
    CLRF	TRISD,0				; Inicialment posem BDRam com a SORTIDA per poder llegir	
    BSF		LATC,RC5,0			; Encenem LED0 per indicar que estem grabant
    BCF		LATA,RA4,0			; !CSRam
    BCF		LATA,RA5,0			; R/!W RAM

    ; Servo0
    MOVLW	b'00000001';Per provar poso an0 MOVLW	b'00001001'			; ADCON0 al canal AN2 i ADON activat------------------------------------------------------------------------------------
    MOVWF	ADCON0,0
    BSF		ADCON0,1,0
	ESPEREM2				; Esperem a que acabi de convertir el valor
    BTFSC	ADCON0,1,0
    GOTO	ESPEREM2
    
    MOVFF	ADRESH,LATD			; Copiem els 8 bits de m?s pes a el LATD	
    BSF		LATA,RA4,0			; !CSRam

    NOP
    NOP
    NOP
    NOP
    NOP
    NOP    
    
    BSF		LATE,RE0,0			; NextPos
    NOP
    NOP
    BCF		LATE,RE0,0			; NextPos
    
    
    ; Servo1
    MOVLW	b'00000101';Per provar poso an1 MOVLW	b'00001101'			; ADCON0 al canal AN3 i ADON activat-------------------------------------------------------------------------------------
    MOVWF	ADCON0,0
    BSF		ADCON0,1,0
    	ESPEREM3				; Esperem a que acabi de convertir el valor
    BTFSC	ADCON0,1,0
    GOTO	ESPEREM3
    BCF		LATA,RA4,0			; !CSRam

    MOVFF	ADRESH,LATD			; Copiem els 8 bits de m?s pes a el LATD	
    
    BCF		LATA,RA5,0			; R/!W RAM
    BSF		LATA,RA4,0			; !CSRam

    
    BSF		LATE,RE0,0			; NextPos
    NOP
    NOP
    BCF		LATE,RE0,0			; NextPos

    RETURN


PLAY    
    ; Rebem el valor per BDRam, el passem a PWMSERVOX
    BCF		LATC,RC5,0			; Apaguem LED0 per indicar que estem reproduint
    SETF	TRISD,0				; Inicialment posem BDRam com a entrada per poder llegir
    BSF		LATA,RA5,0			; R/!WRAM
    NOP
    NOP
    
    
    
    
    ; Llegim valor i el passem a PWMSERVO0
    MOVFF	PORTD,PWMSERVO0
    BSF		LATE,RE0,0			; Activem NextPos
    NOP
    NOP
    BCF		LATE,RE0,0			; Desactivem NextPos
    NOP
    NOP
    
    
    ; Llegim valor i el passem a PWMSERVO1
    MOVFF	PORTD,PWMSERVO1
    BSF		LATE,RE0,0			; Activem NextPos
    NOP
    NOP
    BCF		LATE,RE0,0			; Desactivem NextPos

    RETURN
    
    
NoPWM
    CLRF	Vegades,0			; Netejo variable de nombre de cops contats per arribar a 10s
    SETF	Graba,0				; Poso a 1, perque grabi al entrar al mode
    BSF		TRISC,RC6,0			; pwmServo0
    BSF		TRISC,RC7,0			; pwmServo1
    BSF		LATE,RE1,0			; Activem NRPos
    NOP
    NOP
    BCF		LATE,RE1,0			; Activem NRPos
    
    RETURN


ResetPos
    CLRF	Vegades,0			; Netejo variable de nombre de cops contats per arribar a 10s
    SETF	Graba,0				; Poso a 1, perque grabi al entrar al mode
    BSF		LATE,RE1,0			; Activem NRPos
    NOP
    NOP
    BCF		LATE,RE1,0			; Activem NRPos
    
    RETURN


ENVIA_PC


    RETURN    
    
    
    LEDSRGB
    
    BCF LATC,0,0
    BTFSC PWMSERVO0,7,0
    BSF LATC,0,0
    BCF LATC,1,0
    BTFSC PWMSERVO0,6,0
    BSF LATC,1,0
    BCF LATC,2,0
    BTFSC PWMSERVO0,5,0
    BSF LATC,2,0
    
    RETURN
; ------------------------------------------------------------------------ RSI -----------------------------------------------------------------------------------------------------------------------------
    
HIGH_RSI
    BTFSC	INTCON,TMR0IF,0
    CALL	TIMER_RSI			; Interrupcio per TIMER0
    BTFSC	INTCON,RBIF,0
    CALL	MODE_RSI			; Interrupcio per canvi de mode als switch
    
    RETFIE FAST
    
    
TIMER_RSI
    CALL	CARREGA_TIMER			; Carrego timer 
    BSF		LATC,RC3,0			; Posem a 1 PWMSERVO0
    BSF		LATC,RC4,0			; Posem a 1 PWMSERVO1
    BTG		LATE,RE2,0			; Pols de 20ms
    
    MOVLW	.0
    CPFSGT	Mode,0
    CALL	MODE0				; Moviment per polsadors, 1 grau cada 20ms apretats
    
    
    MOVLW	.2
    CPFSLT	Mode,0	    
    CALL	MODE23				; Grabar 10 moviment per joystick/Grabar 10 moviment manual, apagar PWM's
    
    CLRF	Valor,0				; Netejem valor, que indica el temps que esta a 1 cada pwm a dins el LOOP del main
    
    
    ESPERA1					; Bucle que fa 100 voltes i despr?s incrementa en 1 el valor de temps a comparar amb el que ha d'adquirir cada servo
    MOVLW	.156				; CAL AJUSTAR PERQUE FUNCIONI DE 0 A 255, EN COMPTES DE 0 180
    MOVWF	Count,0 
	INCREMENTA              
    INCF	Count,1 
    BTFSS	STATUS,C,0  
    GOTO	INCREMENTA
    INCF	Valor,1				; A la interrupcio caldr? resetejarlo, igual que caldra posar a 1 les sortides dels pwm
    MOVF	Valor,0				; Copio valor a wreg
    CPFSGT	PWMSERVO0,0			; Valor entre el maxim i el minim que accepti el servo
    BCF		LATC,RC3,0
    CPFSGT	PWMSERVO1,0
    BCF		LATC,RC4,0
    BTFSS	LATC,RC3,0
    BTFSC	LATC,RC4,0
    GOTO ESPERA1
    
    
    
    RETURN

    
MODE_RSI
    BCF		Mode,0,0
    BTFSC	PORTB,RB4,0			; Si hi ha 0 al port, assignem 0 al bit de menys pes de Mode
    BSF		Mode,0,0			; Sino, assignem un 1
    BCF		Mode,1,0
    BTFSC	PORTB,RB5,0
    BSF		Mode,1,0

    ; Caldra bloquejar que si esta grabant no puguis canviar de mode????-------------------------------------------------------------------------------------------//////////////////////////////////////////

    MOVLW	.3				; Si es mode 3, desactivem PWM's per poder moure servos manualment
    CPFSLT	Mode,0
    CALL	NoPWM

    MOVLW	.2				; Si es mode 2 (a NoPWM/mode 3 fem el mateix) fem un reset del contador per comencar a grabar, NOSE SI FUNCIONA ////////////////////////////////////////////
    CPFSLT	Mode,0
    CALL	ResetPos

    BCF		INTCON,RBIF,0			; Netejem flag de interrupcio
    
    RETURN    
    
    
    
; ---------------------------------------------------------------------- MODES -------------------------------------------------------------------------------------------------------------------------
    
MODE0
    ;Caldra sumar/restar a PWMSERVO0 i 1, el valor de 1 grau si el respectiu pulsador esta apretat i resetejar la variable
    BCF		LATC,RC5,0			; Apago led0 si estava obert
    MOVLW	.2				; Valor a sumar/restar per fer un grau, per fer el Ta1--------------------------------------------------------///////////////////////////////////////

    BTFSS	PORTB,RB0,0			; Fem polling per saber quin boto esta apretat i aix? saber que cal modificar
    ADDWF	PWMSERVO0,1,0
    
        
    BTFSS	PORTB,RB1,0
    SUBWF	PWMSERVO0,1,0

    BTFSS	PORTB,RB2,0
    ADDWF	PWMSERVO1,1,0

    BTFSS	PORTB,RB3,0
    SUBWF	PWMSERVO1,1,0

    ;MOVLW	.255				; Controlem si el Servo es passa de 180 per no for?ar-lo----------------------------------------------------------/////////////////////////////////
    ;CPFSLT	PWMSERVO0,0
    ;MOVWF	PWMSERVO0,0

    ;MOVLW	.0				; Controlem si el Servo es passa per sota de 0 per no for?ar-lo CREC Q NO CALDRA CAP DELS DOS
    ;CPFSGT	PWMSERVO0,0
    ;MOVWF	PWMSERVO0,0

    RETURN

    
MODE1
    ; Cal treballar en analogic per llegir el valor del joystick, i posarlo directament al servo. Si no estas tocant el joystick anmira a 90 90, cal regular perq no es passi de 180 i no carreguei el servo
    BCF		LATC,RC5,0

    MOVLW	b'00000001'			; ADCON0 al canal AN0 i ADON activat
    MOVWF	ADCON0,0
    BSF		ADCON0,1,0
	ESPEREM					; Esperem a que acabi de convertir el valor
    BTFSC	ADCON0,1,0
    GOTO	ESPEREM
    
    MOVFF	ADRESH,PWMSERVO0		; Copiem els 8 bits de m?s pes a el PWMSERVO0
    
    ;MOVLW	.10				; Per intentar balancejar el adresh que posem del jooystick al pwm, no funciona gaire be////////////////////////////////////
    ;SUBWF	ADRESH,0,0
    ;MOVWF	PWMSERVO0,0

    
    MOVLW	b'00000101'			; ADCON0 al canal AN1 i ADON activat							PROVOCA ERROR EN LA GENERACIO DE PWM, CONVERTEIX MOLT LENT/////////////////////////
    MOVWF	ADCON0,0
    BSF		ADCON0,1,0
	ESPEREM1					; Esperem a que acabi de convertir el valor
    BTFSC	ADCON0,1,0
    GOTO	ESPEREM1
    
    MOVFF	ADRESH,PWMSERVO1		; Copiem els 8 bits de m?s pes a el PWMSERVO1
    ;MOVLW	.10
    ;SUBWF	ADRESH,0,0
    ;MOVWF	PWMSERVO1,0

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
    CALL	INIT_VARS
    CALL	INIT_PORTS
    CALL	INIT_RSI
    CALL	INIT_TIMER
    
LOOP
    
    
    MOVLW	.1
    SUBWF	Mode,0
    BTFSC	STATUS,Z,0
    CALL	MODE1
    
    
    
    CALL LEDSRGB
    
    MOVLW	.0				; En el cas de estar a mode diferent de 0 o 1, fer servir el joystick a la "funcio" joystickeame
    CPFSEQ	Mode,0				; Si esta reproduint, la funcio joystickeame tampoc funcionara, desactiva joystick
    MOVLW	.3
    CPFSEQ	Mode,0
    GOTO	Joystickeame
    
    GOTO LOOP
    
    
	

	

Joystickeame
    BTFSC	Graba,0,0			; Si esta reproduint, la funcio joystickeame tampoc funcionara, desactiva joystick
    CALL	MODE1				; Llegir valors joystick i posar-los directament al PWMSERVOX (fer servir joystick)
    
    GOTO LOOP

	
	
	
	
	
	
	
	
	
    ; LEGACY-------------------------------- OSC 4MHZ I RGB'S FUNCIONS------------------- CAL FERHO AMB TAULES DB....

    
INIT_OSC
    MOVLW b'01100111'				; Posem el INTIO a 4 MHZ, tInst = 1us
    MOVWF OSCCON,0
    RETURN     

END
    
    
    
