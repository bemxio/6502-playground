; defines and macros
.define PPU_CTRL $2000
.define PPU_MASK $2001
.define PPU_STATUS $2002
.define PPU_ADDR $2006
.define PPU_DATA $2007

.define OAM_DMA $4014

.define APU_DMC $4010
.define APU_FRAME_COUNTER $4017

.define JOY1 $4016

.macro wait_for_vblank
    :
        bit PPU_STATUS ; read PPU status register
        bpl :- ; loop until vblank flag is set
.endmacro

; segments
.segment "HEADER"
    .byte "NES", $1a ; identification string
    .byte $02 ; number of PRG-ROM in 16K units
    .byte $01 ; number of CHR-ROM in 8K units
    .byte $00, $00 ; flags
    .byte $00, $00, $00, $00 ; other parameters, unused for now
    .byte $00, $00, $00, $00

.segment "ZEROPAGE"
    controls: .res 1 ; state of controller buttons

.segment "STARTUP"
    ; subroutines
    read_joy1: ; taken from https://www.nesdev.org/wiki/Controller_reading_code#Basic_Example :-)
        lda #1 ; controller port latch bit set to 1
        sta JOY1 ; send value to controller port

        sta controls ; store accumulator ($01) in controls

        lsr ; reset accumulator to 0
        sta JOY1 ; send value to controller port

        read_joy1_loop:
            lda JOY1 ; read value from controller port

            lsr ; shift value right to get next button state
            rol controls ; rotate bits left in controls

            bcc read_joy1_loop ; loop until all button states have been read

        rts ; return from subroutine

    ; interrupt handlers
    reset:
        sei ; disable interrupts
        cld ; clear decimal mode

        ; disable sound IRQs
        ldx #%1000000 ; mode 0 (4-step), IRQ inhibit flag enabled
        stx APU_FRAME_COUNTER ; send value to APU frame counter

        ; disable PCM
        ldx #0 ; IRQ disabled, loop flag disabled, rate index 0
        stx APU_DMC ; send value to APU DMC

        ; initalize stack pointer
        ldx #$ff ; stack address
        txs ; transfer value to stack pointer

        ; clear PPU registers
        ldx #0

        stx PPU_CTRL ; send value to PPU control register
        stx PPU_MASK ; send value to PPU mask register

        wait_for_vblank ; wait for vblank to ensure PPU is ready

        ; clear 2K of internal RAM
        clear_memory:
            ; store value in each page of internal RAM using X as offset
            lda #0

            sta $0000, x ; zero page
            sta $0100, x ; stack page
            sta $0300, x
            sta $0400, x
            sta $0500, x
            sta $0600, x
            sta $0700, x

            lda #$ff
            sta $0200, x ; OAM buffer

            inx ; increment offset

            cpx #0 ; check if offset has wrapped around
            bne clear_memory ; loop if not done

        wait_for_vblank ; wait for vblank to ensure PPU is ready

        ; copy OAM buffer to PPU
        lda #2 ; page number
        sta OAM_DMA ; send value to OAM DMA register

        nop ; wait for DMA to complete

        ; set up palette data
        lda #$3f ; high byte of palette data address in PPU memory
        sta PPU_ADDR ; send value to PPU address register

        lda #$00 ; low byte of address
        sta PPU_ADDR ; send value to PPU address register

        ldx #0 ; offset for palette data

        load_palettes:
            lda palette_data, x ; load byte of palette data
            sta PPU_DATA ; send value to PPU data register

            inx ; increment offset

            cpx #32 ; check if all bytes of palette data have been sent
            bne load_palettes ; loop if not done

        ; set up sprite data
        ldx #0 ; offset for sprite data

        load_sprites:
            lda sprite_data, x ; load byte of sprite data
            sta $0200, x ; store value in OAM buffer

            inx ; increment offset

            cpx #40 ; check if all bytes of sprite data have been sent
            bne load_sprites ; loop if not done

        ; set up NMI
        lda #%10010000 ; enable NMI on vblank, $1000 as background pattern table address
        sta PPU_CTRL ; send value to PPU control register

        ; show sprites and background
        lda #%00011110 ; enable background and sprite rendering, show both in leftmost 8 pixels
        sta PPU_MASK ; send value to PPU mask register

        :
            jmp :- ; infinite loop

    nmi:
        jsr read_joy1 ; read controller state

        ; right button check
        lda controls ; load controller state to accumulator

        and #%00000001 ; check if button is pressed
        beq :+ ; jump if it is not

        ; increment X position of mushroom in OAM buffer
        inc $0203
        inc $0207
        inc $020b
        inc $020f

    :   ; left button check
        lda controls ; load controller state to accumulator

        and #%00000010 ; check if button is pressed
        beq :+ ; jump if it is not

        ; decrement X position of mushroom in OAM buffer
        dec $0203
        dec $0207
        dec $020b
        dec $020f

    :   ; down button check
        lda controls ; load controller state to accumulator

        and #%00000100 ; check if button is pressed
        beq :+ ; jump if it is not

        ; increment Y position of mushroom in OAM buffer
        inc $0200
        inc $0204
        inc $0208
        inc $020c

    :   ; up button check
        lda controls ; load controller state to accumulator

        and #%00001000 ; check if button is pressed
        beq :+ ; jump if it is not

        ; decrement Y position of mushroom in OAM buffer
        dec $0200
        dec $0204
        dec $0208
        dec $020c

    :
        ; copy OAM buffer to PPU
        lda #2 ; page number
        sta OAM_DMA ; send value to OAM DMA register

        rti ; return from interrupt

    ; data
    palette_data:
        ; background
        .byte $00, $00, $00, $00
        .byte $00, $00, $00, $00
        .byte $00, $00, $00, $00
        .byte $00, $00, $00, $00

        ; sprites
        .byte $30, $0f, $16, $30
        .byte $00, $00, $00, $00
        .byte $00, $00, $00, $00
        .byte $00, $00, $00, $00

    sprite_data:
        ; Y, tile index, attributes, X
        .byte $08, $00, $00, $02
	    .byte $08, $01, $00, $0a
	    .byte $10, $10, $00, $02
	    .byte $10, $11, $00, $0a

.segment "VECTORS"
    .word nmi ; NMI handler address
    .word reset ; reset handler address

.segment "CHARS"
    .incbin "rom.chr" ; sprite and background tile data