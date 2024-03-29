LIST P=PIC18F4321 F=INHX32
    #include <p18f4321.inc>



; DUBTES
    ; Bloquejar numeros de 255 o 0, que no sigui ciclic
    ; Programa Java correctament funcionant
    ; Que fer si canvio de mode durant una grabacio
    ; Adaptar valor de joystick per fer servir tot el rang de 0 a 255
    ; Llegir servos el seu valor
    
    
    
    
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
Lock		EQU 0xB				; Var per bloquejar els PWMSERVO perque no siguin ciclics (255 a 0 i al reves)
Var0Toca	EQU 0xC				; Flag per saber si toca fer el Mode0, serveix per relentizar-lo, i aixi no sumi gaires graus
TOCA0		EQU 0XD
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
    
    CLRF	Lock,0
    SETF	Var0Toca,0
    CLRF	TOCA0,0
    
    RETURN
    
   
INIT_PORTS  
    
    ; Sortides
    BCF		TRISA,RA4,0			; !CSRam
    BCF		TRISA,RA5,0			; R/!WRAM
    CLRF	TRISC,0				; ServoRGB(0 a 2), pwmServo0(3), pwmServo1(4), LED0(5)
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
    BSF		TRISC,6,0			; TX
    BSF		TRISC,7,0			; RX
	
	
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
    MOVWF	ADCON1,0			; Posem els ports analogics del AN0 al AN3
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
    
    
INIT_PCCON
    MOVLW b'00100000'				; Activem TXEN
    MOVWF TXSTA,0

    MOVLW b'10010000'				; Activem SPEN i CREN
    MOVWF RCSTA,0

    BCF BAUDCON, BRG16, 0			; Desactivem BRG16 perquè funcioni a 8 bits
	
    MOVLW .64					; Posem el valor calculat perquè el baudrate sigui de 9600
    MOVWF SPBRG,0
    
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
    BSF		LATA,RA4,0			; !CSRam
    BSF		LATE,RE1,0			; Activem NRPos
    NOP
    NOP
    BCF		LATE,RE1,0			; Activem NRPos
    
    RETURN    
    
MODE3SERVO
    ;MOVFF	ADRESH,WREG
    MOVLW b'00001000'
    ADDWF ADRESH,0,0
    MOVFF	WREG,LATD
    
    RETURN
    
    
    
RECORD	; Inicialment tindrem BDRam configurat com sortida, R/!W en mode escritura i !CSRam a 1 (desactivat)
	; Primer ens caldra traduir de analogic a digital, i treure aquest valor per BDRam [0..7]
	; Un cop tenim el valor a BDRam, activarem CS per guardar i desactivarem, i despr?s farem un pols de adre?a (NextPos)
	
    CLRF	TRISD,0				; Inicialment posem BDRam com a SORTIDA per poder llegir	
    BSF		LATC,RC5,0			; Encenem LED0 per indicar que estem grabant
    
    BTFSC	Mode,0,0
    CALL	DesactivaSortida    

    ; Servo0
    ;Segons el mode, haurem de convertir el valor analogic de el joystick o el servo

    BTFSS	Mode,0,0
    MOVLW	b'00000001'			; ADCON0 al canal AN0 i ADON activat
    BTFSC	Mode,0,0
    MOVLW	b'00001101'			; ADCON0 al canal AN3 i ADON activat
    
    MOVWF	ADCON0,0
    BSF		ADCON0,1,0
	ESPEREM2				; Esperem a que acabi de convertir el valor
    BTFSC	ADCON0,1,0
    GOTO	ESPEREM2
    
    
    MOVFF	ADRESH,LATD			; Copiem els 8 bits de mes pes a el LATD
    BTFSC	Mode,0,0
    CALL	MODE3SERVO
    
    BCF		LATA,RA5,0			; R/!W RAM mode escritura
    BCF		LATA,RA4,0			; Activem !CSRam
    NOP
    NOP
    BSF		LATA,RA4,0			; Desactivem !CSRam
    
    BSF		LATE,RE0,0			; NextPos
    NOP
    NOP
    BCF		LATE,RE0,0			; NextPos
    
    
    ; Servo1
    ;Segons el mode, haurem de convertir el valor analogic de el joystick o el servo
    
    BTFSS	Mode,0,0
    MOVLW	b'00000101'			; ADCON0 al canal AN1 i ADON activat
    BTFSC	Mode,0,0
    MOVLW	b'00001001'			; ADCON0 al canal AN2 i ADON activat
    
    
    
    MOVWF	ADCON0,0
    BSF		ADCON0,1,0
	ESPEREM3				; Esperem a que acabi de convertir el valor
    BTFSC	ADCON0,1,0
    GOTO	ESPEREM3
    

    MOVFF	ADRESH,LATD			; Copiem els 8 bits de mes pes a el LATD
    BTFSC	Mode,0,0
    CALL	MODE3SERVO
    
    BCF		LATA,RA5,0			; R/!W RAM mode escritura
    BCF		LATA,RA4,0			; Activem !CSRam
    NOP
    NOP
    BSF		LATA,RA4,0			; Desactivem !CSRam

    
    BSF		LATE,RE0,0			; NextPos
    NOP
    NOP
    BCF		LATE,RE0,0			; NextPos

    RETURN


PLAY    
    ; Rebem el valor per BDRam, el passem a PWMSERVOX
    BCF		TRISC,RC3,0			; pwmServo0 posem com sortida
    BCF		TRISC,RC4,0			; pwmServo1 posem com sortida
    
    BCF		LATC,RC5,0			; Apaguem LED0 per indicar que estem reproduint
    SETF	TRISD,0				; Inicialment posem BDRam com a entrada per poder llegir
    BCF		LATA,RA4,0			; !CSRam activat per poder llegir
    BSF		LATA,RA5,0			; R/!WRAM mode lectura
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
    BSF		TRISC,RC3,0			; pwmServo0 posem com entrada perque no funcioni el servo
    BSF		TRISC,RC4,0			; pwmServo1 posem com entrada perque no funcioni el servo
    BSF		LATE,RE1,0			; Activem NRPos per començar a grabar desde inici RAM
    NOP
    NOP
    BCF		LATE,RE1,0			; Activem NRPos
    
    RETURN

DesactivaSortida
    BSF		TRISC,RC3,0			; pwmServo0 posem com entrada perque no funcioni el servo
    BSF		TRISC,RC4,0			; pwmServo1 posem com entrada perque no funcioni el servo
    
    RETURN

ResetPos
    CLRF	Vegades,0			; Netejo variable de nombre de cops contats per arribar a 10s
    SETF	Graba,0				; Poso a 1, perque grabi al entrar al mode
    BSF		LATE,RE1,0			; Activem NRPos
    NOP
    NOP
    BCF		LATE,RE1,0			; Activem NRPos
    
    RETURN


    
REBRE_PC
    
    BTFSS	TOCA0,0,0
    MOVFF	RCREG, PWMSERVO0		; Copiem valor rebut de PC a PWMSERVO0
    BTFSC	TOCA0,0,0
    MOVFF	RCREG, PWMSERVO1
    BTG		TOCA0,0,0
    
RETURN     
    
    
    
LEDSRGB0					; Mirem 3 bits de mes pes de PWMSERVO0, per saber a quin "grau" es troba
        
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
    
    
LEDSRGB1					; Mirem 3 bits de mes pes de PWMSERVO1, per saber a quin "grau" es troba
        
    BCF LATC,0,0
    BTFSC PWMSERVO1,7,0
    BSF LATC,0,0
    BCF LATC,1,0
    BTFSC PWMSERVO1,6,0
    BSF LATC,1,0
    BCF LATC,2,0
    BTFSC PWMSERVO1,5,0
    BSF LATC,2,0
    
    RETURN  

PRESERV0ADD  
    ; Si la operacio esta bloquejada, no la fem

    BTFSS	    Lock,0,0
    CALL	    SERV0ADD
    
    RETURN
    
    
SERV0ADD
    ; Controlem si el Servo es passa de 180 per no forcar-lo

    MOVLW	    .1
    ADDWF	    PWMSERVO0,1,0
    BCF		    Lock,1,0			; Desbloquejo la resta
    MOVLW	    .255
    SUBWF	    PWMSERVO0,0
    BTFSC	    STATUS,Z,0
    BSF		    Lock,0,0
    
    RETURN
    
PRESERV0SUB    
    ; Si la operacio esta bloquejada, no la fem

    
    BTFSS	    Lock,1,0
    CALL	    SERV0SUB
    
    RETURN    
    
SERV0SUB
    ; Controlem si el Servo es passa de 180 per no forcar-lo
    
    MOVLW	    .1
    SUBWF	    PWMSERVO0,1,0
    BCF		    Lock,0,0			; Desbloquejo la suma
    MOVLW	    .0
    SUBWF	    PWMSERVO0,0
    BTFSC	    STATUS,Z,0
    BSF		    Lock,1,0
    
    
    RETURN
    
    
PRESERV1ADD    
    ; Si la operacio esta bloquejada, no la fem

    BTFSS	    Lock,2,0
    CALL	    SERV1ADD
    
    RETURN    
    
    
SERV1ADD
    ; Controlem si el Servo es passa de 180 per no forcar-lo
    
    MOVLW	    .1
    ADDWF	    PWMSERVO1,1,0
    BCF		    Lock,3,0			; Desbloquejo la resta
    MOVLW	    .255
    SUBWF	    PWMSERVO1,0,0
    BTFSC	    STATUS,Z,0
    BSF		    Lock,2,0
    
    RETURN
    
    
PRESERV1SUB    
    ; Si la operacio esta bloquejada, no la fem
    
    BTFSS	    Lock,3,0
    CALL	    SERV1SUB
    
    RETURN     
    
SERV1SUB
    ; Controlem si el Servo es passa de 180 per no forcar-lo
    
    MOVLW	    .1
    SUBWF	    PWMSERVO1,1,0
    BCF		    Lock,2,0			; Desbloquejo la suma
    MOVLW	    .0
    SUBWF	    PWMSERVO1,0,0
    BTFSC	    STATUS,Z,0
    BSF		    Lock,3,0
    
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
    
    BTFSC	PORTE,RE2,0			; Segons si 20ms (pin Sortida) es a 0 o 1, posem valor de PWMSERVO 0 o 1
    CALL	LEDSRGB0
    BTFSS	PORTE,RE2,0			; Els transistors faran que es vegi correctament
    CALL	LEDSRGB1
    
    
    MOVLW	.0
    CPFSGT	Mode,0
    CALL	MODE0toca			; Moviment per polsadors, 1 grau cada 20ms apretats
   
    
    MOVLW	.2
    CPFSLT	Mode,0	    
    CALL	MODE23				; Grabar 10 moviment per joystick/Grabar 10 moviment manual, apagar PWM's
    
    CLRF	Valor,0				; Netejem valor, que indica el temps que esta a 1 cada pwm a dins el LOOP del main
    
    
    ESPERA1					; Bucle que fa 100 voltes i despres incrementa en 1 el valor de temps a comparar amb el que ha d'adquirir cada servo
    MOVLW	.235				
    MOVWF	Count,0 
	INCREMENTA              
    INCF	Count,1 
    BTFSS	STATUS,C,0  
    GOTO	INCREMENTA
    INCF	Valor,1				; A la interrupcio cal resetejarlo, igual que caldra posar a 1 les sortides dels pwm
    MOVF	Valor,0				; Copio valor a wreg
    CPFSGT	PWMSERVO0,0			; Valor entre el maxim i el minim que accepti el servo
    BCF		LATC,RC3,0
    CPFSGT	PWMSERVO1,0
    BCF		LATC,RC4,0
    BTFSS	LATC,RC3,0
    BTFSC	LATC,RC4,0
    GOTO ESPERA1
    
    
    WAITenvia0
    BTFSS TXSTA, TRMT, 0			; Esperem a que s?hagi acabat d?enviar el anterior
    GOTO WAITenvia0	
    ENVIA0
    MOVFF PWMSERVO0, TXREG			; Enviem PWMSERVO0
    WAITenvia1
    BTFSS TXSTA, TRMT, 0			; Esperem a que s?hagi acabat d?enviar el anterior
    GOTO WAITenvia1	
    ENVIA1
    MOVFF PWMSERVO1, TXREG			; Enviem PWMSERVO1
    
    RETURN

    
MODE_RSI
    BCF		Mode,0,0
    BTFSC	PORTB,RB4,0			; Si hi ha 0 al port, assignem 0 al bit de menys pes de Mode
    BSF		Mode,0,0			; Sino, assignem un 1
    BCF		Mode,1,0
    BTFSC	PORTB,RB5,0
    BSF		Mode,1,0
    
    BCF		TRISC,RC3,0			; pwmServo0 posem com sortida
    BCF		TRISC,RC4,0			; pwmServo1 posem com sortida


    MOVLW	.3				; Si es mode 3, desactivem PWM's per poder moure servos manualment
    CPFSLT	Mode,0
    CALL	NoPWM

    MOVLW	.2				; Si es mode 2 (a NoPWM/mode 3 fem el mateix) fem un reset del contador per comencar a grabar, NOSE SI FUNCIONA ////////////////////////////////////////////
    CPFSLT	Mode,0
    CALL	ResetPos

    BCF		INTCON,RBIF,0			; Netejem flag de interrupcio
    
    RETURN 
    
    
    
; ---------------------------------------------------------------------- MODES -------------------------------------------------------------------------------------------------------------------------

MODE0toca					; Funcio que ens serveix per fer més precís el mode0, ja que sino es molt rapid
    BTG		Var0Toca,0,0
    BTFSC	Var0Toca,0,0
    CALL	MODE0
    
    RETURN
    
    
MODE0
    BCF		LATC,RC5,0			; Apago led0 si estava obert
    
    
    BTFSS	PORTB,RB0,0			; Fem polling per saber quin boto esta apretat i aix? saber que cal modificar
    CALL	PRESERV0ADD
    
    BTFSS	PORTB,RB1,0
    CALL	PRESERV0SUB
    
    BTFSS	PORTB,RB2,0
    CALL	PRESERV1ADD
    
    BTFSS	PORTB,RB3,0
    CALL	PRESERV1SUB


    RETURN

    
MODE0PC
    ; Serveix perque en el LOOP, si esta al mode 0, mirar si hem rebut algun valor del pc, i en cas afirmatiu posarlo als servos
    BTFSC	PIR1, RCIF,0
    CALL	REBRE_PC
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
    
 
    MOVLW	b'00000101'			; ADCON0 al canal AN1 i ADON activat
    MOVWF	ADCON0,0
    BSF		ADCON0,1,0
	ESPEREM1				; Esperem a que acabi de convertir el valor
    BTFSC	ADCON0,1,0
    GOTO	ESPEREM1
    
    MOVFF	ADRESH,PWMSERVO1		; Copiem els 8 bits de m?s pes a el PWMSERVO1
    

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
    CALL	INIT_PCCON
LOOP
    
    MOVLW	.0				; Si esta al mode 0, mirem si ha rebut valors de el PC a la funcio MODE0PC
    SUBWF	Mode,0
    BTFSC	STATUS,Z,0
    CALL	MODE0PC
    
    
    MOVLW	.1				; Si esta al mode 1, cridem la funcio que passa els valors del joystick als servos
    SUBWF	Mode,0
    BTFSC	STATUS,Z,0
    CALL	MODE1
    
    
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

	

END
