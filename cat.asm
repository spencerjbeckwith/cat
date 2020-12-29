    .inesprg 8 ; Using UNROM will have 8 meaning 16 banks... right?
    .ineschr 0 ; Indicates CHR-RAM
    .inesmap 2 ; UNROM? tbh i don't know
    .inesmir 0 ; Horizontal mirroring

; Variables
game_asleep = $00 ; cannot be re-used
current_bank = $01 ; cannot be re-used

pointer_low = $02 ; can be re-used
pointer_high = $03 ; can be re-used

;    Each bank is $2000 bytes (8kb)
; BANK 00 - Tile Data
; BANK 01 - 
; BANK 02 - 
; BANK 03 - 
; BANK 04 - 
; BANK 05 - 
; BANK 06 - 
; BANK 07 - 
; BANK 08 - 
; BANK 09 - 
; BANK 10 - 
; BANK 11 - 
; BANK 12 - 
; BANK 13 - 
; BANK 14 - Global PRG-ROM
; BANK 15 - Global RPG-ROM

    .bank 0
    .org $8000
CHR:
    .include "asset/chr.asm"

; Insert other banks here. Make them included files.

    .bank 14    ; second-to-last bank: $c000-$dfff
    .org $c000  ; Fixed PRG-ROM

; Make macros include file

; Make subroutines include file

; Bankswitch: Y = new bank
Bankswitch:
    sty current_bank
BankswitchNoSave:
    lda Banktable, y
    sta Banktable, y
    rts

; RESET - Separate into include file later
VBlankWait:
    bit $2002
    bpl VBlankWait
    rts

Reset:
    sei
    cld         ; Disable decimal mode
    ldx #$40
    stx $4017   ; Disable APU IRQs
    ldx #$ff    ;
    txs         ; Initialze stack with $FF
    inx         ; X is now 0 for the following:
    stx $2000   ; Disable VBlank
    stx $2001   ; Disable Rendering
    stx $4010   ; Disable DMC IRQs

    jsr VBlankWait ; Wait
.loop:
    lda #$00        ; Wipe all RAM...
    sta $0000, x
    sta $0100, x
    sta $0200, x
    sta $0300, x
    sta $0400, x
    sta $0500, x
    sta $0600, x
    sta $0700, x
    lda #$ff
    sta $0200, x    ; ...Except OAM, put ff in there
    inx
    bne .loop

    jsr VBlankWait ; Wait again

    ; Switch to bank 0, where our tile data is
    ldy #$00
    jsr Bankswitch

    ; Load CHR-RAM
    lda #low(CHR) ; First, set our pointer
    sta pointer_low
    lda #high(CHR)
    sta pointer_high

    ldy #$00 ; Initialize Y to 0
    sty $2001 ; Turn off rendering
    lda $2002 ; Reset latch
    sty $2006 ; Set our ppu address: $0000
    sty $2006
    ldx #$20 ; Copy all 20 pages - both left and right
.loop2:
    lda [pointer_low],y ; Well damn I guess NESASM can't use parenthesis, they HAVE to be brackets...
    sta $2007 ; Feed in one byte
    iny
    bne .loop2

    inc pointer_high ; Move onto the next page
    dex ; Count down remaining pages
    bne .loop2 ; Go back to copy this page

    ; Load palettes
    sta $2002 ; Reset latch
    lda #$3f  ; Set PPU addy for palettes
    sta $2006 ; 3f
    stx $2006 ; 00 (x should be 0 after last loop)
.loop3
    lda Palettes, x
    sta $2007
    inx
    cmp #$20 ; Load 32 bytes
    bne .loop3

    ;Enable VBlank and ppu
    lda #%10000000
    sta $2000
    lda #%00011110
    sta $2001

    ; At this point is where we would initialize stuff, like music or sound or whatever. Or initial values.

WaitForFrame:
    inc game_asleep ; Start waiting for an NMI
.loop:
    lda game_asleep ; NMI should occur during this loop and unset game_asleep
    bne .loop
DoFrame: ; When we get here, we know NMI is done and we can do logic for whatever time is left.

    ; Do all game logic here!

    jsr WaitForFrame

; NMI - Separate into include file later
NMI:
    pha ; Put all our registers onto the stack
    txa
    pha
    tya
    pha

    ; Update our OAM
    ;   Should this be behind a flag?
    lda #$00
    sta $2003
    lda #$02
    sta $4014 ; Does ~500 cycle DMA from OAM

    ; Update PPU stuff
    ;   Make this read a buffer

    ; Update PPU registers
    ;   This should be behind a flag
    ;   Or could it even be buffered as well?

    ; You'll update sounds/music here

    lda #$00
    sta game_asleep ; Go back to sleep

    pla ; Restore registers
    tay
    pla
    tax
    pla
    rti ; NMI done

;...

    .bank 15 ; Last bank: $e000 to $ffff
    .org $e000

Banktable:
    .db $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0a, $0b, $0c, $0d, $0e, $0f

Palettes:
    ; Nametable
    .db $0f, $0f, $30, $09 ;0
    .db $0f, $05, $2b, $0c ;1
    .db $0f, $2b, $0c, $34 ;2
    .db $0f, $05, $2b, $10 ;3

    ; Sprites
    .db $0f, $0f, $30, $09 ;4
    .db $0f, $07, $17, $27 ;5
    .db $0f, $30, $16, $10 ;6
    .db $0f, $00, $10, $20 ;7

    .org $fffa ; Vectors
    .dw NMI
    .dw Reset
    .dw 0 ; No IRQ?
