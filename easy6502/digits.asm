ldx #<digit_6 ; load low byte of digit address
ldy #>digit_6 ; load high byte of digit address
jsr render_digit ; call subroutine to render digit

lda #6 ; set pixel offset for next digit

ldx #<digit_7 ; load low byte of digit address
ldy #>digit_7 ; load high byte of digit address
jsr render_digit ; call subroutine to render digit

loop_forever:
    jmp loop_forever ; infinite loop to keep program running

render_digit:
    stx $1 ; store low byte of address
    sty $2 ; store high byte of address

    tax ; transfer pixel offset to address offset
    ldy #0 ; reset row counter

    render_digit_row:
        lda ($1), y ; load byte for current row of digit

        sty $0 ; store row counter for later use
        ldy #0 ; reset bit counter

        render_digit_row_pixel:
            pha ; save accumulator to stack

            and #1 ; get least significant bit
            sta $200, x ; store bit in screen memory

            pla ; restore accumulator from stack

            lsr ; shift bits to the right
            inx ; increment offset
            iny ; increment bit counter

            cpy #8 ; check if byte has been fully processed
            bne render_digit_row_pixel ; loop if not

        txa ; transfer offset to accumulator

        clc ; clear carry for addition
        adc #24 ; move to next row of screen memory

        tax ; transfer back to offset

        ldy $0 ; restore row counter
        iny ; increment row counter

        cpy #8 ; check if we have processed all 8 rows of the digit
        bne render_digit_row ; loop if not

    rts ; return from subroutine

digit_6:
    dcb $1C, $06, $03, $1F, $33, $33, $1E, $00

digit_7:
    dcb $3F, $33, $30, $18, $0C, $0C, $0C, $00