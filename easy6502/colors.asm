ldx #0 ; initalize counter to 0

main_loop:
    ; generate random color
    randomize_color:
        lda $fe ; retrieve random byte
        and #$0f ; get low nibble out of byte

        cmp $200 ; compare with first pixel of screen
        beq randomize_color ; if color is same as first pixel, generate a new one

    ; fill screen with random color
    fill_screen:
        sta $200, x ; store random value into first quarter of screen memory
        sta $300, x ; store random value into second quarter of screen memory
        sta $400, x ; store random value into third quarter of screen memory
        sta $500, x ; store random value into fourth quarter of screen memory

        inx ; increment counter

        cpx #0 ; check if counter has reached 255
        bne fill_screen ; loop if not

    ; wait for user to press enter
    wait_for_enter:
        ldy $ff ; read last key pressed

        cpy #$0d ; check if enter was pressed
        bne wait_for_enter ; keep waiting if not

    ldy #0 ; reset keyboard state
    sty $ff ; clear last key pressed

    jmp main_loop ; repeat