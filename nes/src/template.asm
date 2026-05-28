; defines and macros
.macro wait_for_vblank
    :
        bit $2002 ; read PPU status register
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
    reset:
        sei ; disable interrupts
        cld ; clear decimal mode

        ; disable sound IRQs
        ldx #%1000000 ; mode 0 (4-step), IRQ inhibit flag disabled 
        stx $4017 ; send value to APU frame counter

        ; disable PCM
        ldx #0 ; IRQ disabled, loop flag disabled, rate index 0
        stx $4010 ; send value to APU DMC

        ; initalize stack pointer
        ldx #$ff ; stack address
        txs ; transfer value to stack pointer

        ; clear PPU registers
        ldx #0

        stx $2000 ; send value to PPU control register
        stx $2001 ; send value to PPU mask register

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
        sta $4014 ; send value to OAM DMA register

        nop ; wait for DMA to complete

        ; set up palette data
        lda #$3f ; high byte of palette data address in PPU memory
        sta $2006 ; send value to PPU address register

        lda #0 ; low byte of address
        sta $2006 ; send value to PPU address register

        ldx #0 ; offset for palette data

        load_palettes:
            lda palette_data, x ; load byte of palette data
            sta $2007 ; send value to PPU data register

            inx ; increment offset

            cpx #32 ; check if all 32 bytes of palette data have been sent
            bne load_palettes ; loop if not done

        ; set up sprite data
        ldx #0 ; offset for sprite data

        load_sprites:
            lda sprite_data, x ; load byte of sprite data
            sta $0200, x ; store value in OAM buffer

            inx ; increment offset

            cpx #16 ; check if all 16 bytes of sprite data have been sent
            bne load_sprites ; loop if not done

        cli ; enable interrupts

        ; set up NMI
        lda #%10010000 ; enable NMI on vblank, $1000 as background pattern table address
        sta $2000 ; send value to PPU control register

        ; show sprites and background
        lda #%00011110 ; enable background and sprite rendering, show both in leftmost 8 pixels
        sta $2001 ; send value to PPU mask register

        :
            jmp :- ; infinite loop

    nmi:
        ; copy OAM buffer to PPU
        lda #2 ; page number
        sta $4014 ; send value to OAM DMA register
    
        rti ; return from interrupt

    palette_data:
        .byte $00, $0F, $00, $10,   $00, $0A, $15, $01,     $00, $29, $28, $27,     $00, $34, $24, $14 	; background
        .byte $31, $0F, $15, $30,   $00, $0F, $11, $30,     $00, $0F, $30, $27,     $00, $3C, $2C, $1C 	; sprite

    sprite_data:
        ; Y, tile index, attributes, X
        .byte $40, $00, $00, $40
        .byte $40, $01, $00, $48
        .byte $48, $10, $00, $40
        .byte $48, $11, $00, $48

.segment "VECTORS"
    .word nmi ; non-maskable interrupt
    .word reset ; reset interrupt

.segment "CHARS"
    .incbin "rom.chr" ; sprite and background tile data