; hardware registers
PPU_CTRL = $2000
PPU_MASK = $2001
PPU_STATUS = $2002
PPU_SCROLL = $2005
PPU_ADDR = $2006
PPU_DATA = $2007

OAM_ADDR = $2003
OAM_DMA = $4014

APU_DMC = $4010
APU_FRAME_COUNTER = $4017

; memory locations
OAM_BUFFER = $0200 ; OAM buffer address in RAM

; segments
.segment "HEADER"
    .byte "NES", $1a ; identification string
    .byte 1 ; size of PRG-ROM in 16K units
    .byte 1 ; size of CHR-ROM in 8K units

    .byte %00000000 ; lower nibble of mapper, mirroring, battery, trainer
    .byte %00000000 ; upper nibble of mapper, VS/Playchoice, NES 2.0

    .byte 0 ; PRG-RAM size
    .byte 0 ; TV system (0 = NTSC, 1 = PAL)
    .byte 0 ; TV system, PRG-RAM presence, bus conflicts

    .res 5 ; padding

.segment "ZEROPAGE"
    temp: .res 2 ; temporary 16-bit variable for addressing

.segment "CODE"
    ; interrupt handlers
    on_reset:
        sei ; disable interrupts
        cld ; disable decimal mode

        ; initalize stack pointer
        ldx #$ff ; stack address
        txs ; transfer value to stack pointer

        ; disable NMI, rendering, and DMC IRQs
        lda #0 ; value to send to appropriate registers

        sta PPU_CTRL ; send value to PPU control register
        sta PPU_MASK ; send value to PPU mask register
        sta APU_DMC ; send value to APU DMC

        ; disable APU IRQs
        lda #%01000000 ; mode 0 (4-step), IRQ inhibit flag enabled
        sta APU_FRAME_COUNTER ; send value to APU frame counter

        bit PPU_STATUS ; clear vblank flag
        jsr wait_for_vblank ; wait for vblank to ensure PPU is ready

        ; clear internal RAM
        ldx #0 ; offset for RAM

        clear_memory:
            lda #0 ; value to clear RAM with

            sta $0000, x ; zero page
            sta $0100, x ; stack page
            ;sta $0200, x
            sta $0300, x
            sta $0400, x
            sta $0500, x
            sta $0600, x
            sta $0700, x

            lda #$ff ; needed to not display garbage
            sta OAM_BUFFER, x ; OAM buffer

            inx ; increment offset
            bne clear_memory ; loop if not done

        jsr wait_for_vblank ; wait for vblank again

        ; copy background data to PPU
        lda PPU_STATUS ; reset address latch

        lda #<background_data ; low byte of background data address
        sta temp ; store value in low byte of temporary variable

        lda #>background_data ; high byte of background data address
        sta temp + 1 ; store value in high byte of temporary variable

        lda #$20 ; high byte of background data address in PPU memory
        sta PPU_ADDR ; send value to PPU address register

        lda #$00 ; low byte of address
        sta PPU_ADDR ; send value to PPU address register

        ldx #4 ; number of pages of background data
        ldy #0 ; offset for background data

        copy_background:
            lda (temp), y ; load byte of background data
            sta PPU_DATA ; send value to PPU data register

            iny ; increment offset
            bne copy_background ; loop if not done

            inc temp + 1 ; increment high byte of background data address

            dex ; decrement number of pages of background data
            bne copy_background ; loop if not done

        ; copy palette data to PPU
        lda PPU_STATUS ; reset address latch

        lda #$3f ; high byte of palette data address in PPU memory
        sta PPU_ADDR ; send value to PPU address register

        lda #$00 ; low byte of address
        sta PPU_ADDR ; send value to PPU address register

        ldx #0 ; offset for palette data

        copy_palettes:
            lda palette_data, x ; load byte of palette data
            sta PPU_DATA ; send value to PPU data register

            inx ; increment offset

            cpx #32 ; check if all bytes of palette data have been sent
            bne copy_palettes ; loop if not done

        ; reset scroll position
        lda #0 ; value for horizontal and vertical scroll

        sta PPU_SCROLL ; send value to PPU scroll register (horizontal)
        sta PPU_SCROLL ; send value to PPU scroll register (vertical)

        cli ; enable interrupts

        ; set up NMI
        lda #%10110000 ; enable NMI on vblank, 8x16 sprite size, $1000 as background pattern table address
        sta PPU_CTRL ; send value to PPU control register

        ; show sprites and background
        lda #%00011110 ; enable background and sprite rendering, show both in leftmost 8 pixels
        sta PPU_MASK ; send value to PPU mask register

        jmp * ; loop forever

    on_vblank:
        pha ; push accumulator onto stack

        ; copy OAM buffer to PPU
        lda #0 ; OAM destination address
        sta OAM_ADDR ; send value to OAM address register

        lda #>OAM_BUFFER ; page number
        sta OAM_DMA ; send value to OAM DMA register

        pla ; pull accumulator from stack
        rti ; return from interrupt

    ; subroutines
    wait_for_vblank:
        bit PPU_STATUS ; read PPU status register
        bpl wait_for_vblank ; loop until vblank flag is set

        rts ; return from subroutine

.segment "RODATA"
    background_data:
        .res 32 ; top overscan line
        .byte "Hello, world!" ; text to display
        .res 1024 - (* - background_data); padding for remaining data

    palette_data:
        ; background
        .byte $00, $30, $00, $00
        .byte $00, $00, $00, $00
        .byte $00, $00, $00, $00
        .byte $00, $00, $00, $00

        ; sprites
        .byte $0f, $00, $00, $00 ; index 0 used as backdrop color
        .byte $00, $00, $00, $00
        .byte $00, $00, $00, $00
        .byte $00, $00, $00, $00

.segment "VECTORS"
    .word on_vblank ; NMI handler address
    .word on_reset ; reset handler address
    .res 2 ; padding for IRQ handler address

.segment "CHARS"
    .incbin "tiles.chr" ; sprite and background tile data