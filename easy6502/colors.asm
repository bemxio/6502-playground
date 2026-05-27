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

    ; wait for user to press any key
    wait_for_key:
        cpy $ff ; check if key has been pressed
        beq wait_for_key ; keep waiting if not

        sty $ff ; clear last key pressed

    jmp main_loop ; repeat