; Vernamova sifra na architekture DLX
; Stepan Bakaj xbakaj00

        .data 0x04          ; zacatek data segmentu v pameti
login:  .asciiz "xbakaj00"  ; <-- nahradte vasim loginem
cipher: .space 9 ; sem ukladejte sifrovane znaky (za posledni nezapomente dat 0)

        .align 2            ; dale zarovnavej na ctverice (2^2) bajtu
laddr:  .word login         ; 4B adresa vstupniho textu (pro vypis)
caddr:  .word cipher        ; 4B adresa sifrovaneho retezce (pro vypis)

        .text 0x40          ; adresa zacatku programu v pameti
        .global main        ; 

main:   ; sem doplnte reseni Vernamovy sifry dle specifikace v zadani
	
	addi r24, r24, 96 ; spodek ascii hodnot malych pismen
loop: 
	lb r16, login(r18) ;nacteni
	sgt  r27,r16,r24 ;kontrola konce sifrovaneho textu
	bnez r27, while	
	nop
	j finish
	nop
while:
	;sifrovani
	sgt  r27,r22,r0 ;rozhodovani zda mame lichy nebo sudy znak
	bnez r27, lichy
	nop
;sudy
	addi r24,r24, 27 ; vrchol ascii hodnot malych pismen
	addi r16, r16, 2 ; pricteni za b
	sgt  r27,r24,r16 ; kontrola preteceni
	bnez r27, ok
	nop 	
	subi r16,r16, 26 ;osetreni preteceni
ok:
	subi r24, r24, 27 ; vraceni hodnoty zpatky
	j zapis
	addi r22, r22, 1
lichy:
	subi r16, r16, 1 ; odecteni za a
	sgt  r27,r16,r24 ; kontrola podteceni
	bnez r27, oki
	nop 	
	addi r16,r16, 26
oki:
	subi r22, r22, 1
zapis:	
	sb cipher(r18), r16 ;zapsani do pameti	
	j loop
	addi r18, r18, 1
finish: 
	sb cipher(r18), r0 ;pridani nuly na konec
end:    addi r14, r0, caddr ; <-- pro vypis sifry nahradte laddr adresou caddr
        trap 5  ; vypis textoveho retezce (jeho adresa se ocekava v r14)
        trap 0  ; ukonceni simulace
