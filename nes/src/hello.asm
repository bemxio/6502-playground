; defines and macros
.define PPU_CTRL $2000
.define PPU_MASK $2001
.define PPU_STATUS $2002
.define PPU_SCROLL $2005
.define PPU_ADDR $2006
.define PPU_DATA $2007

.define OAM_DMA $4014

.define APU_DMC $4010
.define APU_FRAME_COUNTER $4017

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

.segment "STARTUP"
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

        ; set up background data
        lda PPU_STATUS ; reset address latch

        lda #$21 ; high byte of background data address in PPU memory
        sta PPU_ADDR ; send value to PPU address register

        lda #$00 ; low byte of address
        sta PPU_ADDR ; send value to PPU address register

        ldx #0 ; offset for background data

        load_background:
            lda background_data, x ; load byte of background data
            sta PPU_DATA ; send value to PPU data register

            inx ; increment offset

            cpx #107 ; check if all bytes of background data have been sent
            bne load_background ; loop if not done

        ; reset scroll
        lda #0

        sta PPU_SCROLL ; send value to PPU scroll register (horizontal)
        sta PPU_SCROLL ; send value to PPU scroll register (vertical)

        cli ; enable interrupts

        ; set up NMI
        lda #%10010000 ; enable NMI on vblank, $1000 as background pattern table address
        sta PPU_CTRL ; send value to PPU control register

        ; show sprites and background
        lda #%00011110 ; enable background and sprite rendering, show both in leftmost 8 pixels
        sta PPU_MASK ; send value to PPU mask register

        :
            jmp :- ; infinite loop

    nmi:
        ; copy OAM buffer to PPU
        lda #2 ; page number
        sta OAM_DMA ; send value to OAM DMA register

        rti ; return from interrupt

    ; data
    palette_data:
        ; background
        .byte $00, $1f, $00, $00
        .byte $00, $00, $00, $00
        .byte $00, $00, $00, $00
        .byte $00, $00, $00, $00

        ; sprites
        .byte $30, $0f, $16, $30
        .byte $00, $00, $00, $00
        .byte $00, $00, $00, $00
        .byte $00, $00, $00, $00

    background_data:
        .byte $a2, $9f, $a6, $a6, $a9, $90, $b1, $a9, $ac, $a6, $9e ; HELLO WORLD
        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00

        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00

        .byte $ae, $a2, $9f, $90, $ab, $af, $a3, $9d, $a5, $90, $9c, $ac, $a9, $b1, $a8, $90, $a0, $a9, $b2, $00 ; THE QUICK BROWN FOX
        .byte $a4, $af, $a7, $aa, $ad, $90, $a9, $b0, $9f, $ac, $90, $ae, $a2, $9f, $90, $a6, $9b, $b4, $b3, $90, $9e, $a9, $a1 ; JUMPS OVER THE LAZY DOG

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
    .incbin "inkbox.chr" ; sprite and background tile data