; constants
define SYS_RAND $fe ; address to random byte generated on each instruction

define DEST_ADDR $00 ; low byte of destination address
define DEST_ADDR_HIGH $01 ; high byte of destination address

; main code
main_loop:
    lda SYS_RAND ; load random value for high byte of address
    and #%00000011 ; use bitmask to get value from 0 to 3
    clc ; clear carry flag
    adc #2 ; add 2 to value to get value from 2 to 5
    sta DEST_ADDR_HIGH ; store value inside variable

    ldy SYS_RAND ; load random value for low byte of address

    lda SYS_RAND ; load random value for color
    and #$0f ; apply bitmask for lower nibble

    sta (DEST_ADDR), y ; store random color inside screen buffer
    jmp main_loop ; loop forever