    .inesprg 8 ; Using UNROM will have 8 meaning 16 banks... right?
    .ineschr 0 ; Indicates CHR-RAM
    .inesmap 2 ; UNROM? tbh i don't know
    .inesmir 0 ; Horizontal mirroring

; Constants
STATE_PLAYING = $00
;   Add more states here

; Variables
;   These addresses cannot be re-used for more than one purpose.
game_asleep         = $00
current_bank        = $01
ppu_buffer_length   = $02
ppu_buffer_scratch  = $03 ; *could* be re-used, outside of NMI
game_state          = $04
game_state_initialized  = $05
FT_TEMP             = $06 ; Reserves 06, 07, and 08 for FamiTone
input               = $09
; More here - saving up to $1f for now

;   These addresses could, hypothetically, be re-used.
pointer_low     = $20 ; can be re-used
pointer_high    = $21 ; can be re-used
; More here - saving up to $3f for now

; Put player RAM here - will be (at least) 6 bytes at $40
player_x            = $40
player_y            = $41
player_velocity     = $42
player_properties   = $43
player_xcount       = $44
player_ycount       = $45

;   Reserved addresses outside of zero-page
bcdNum      = $0300 ; Reserves 0300 and 0301 for BCD
bcdResult   = $0302 ; Reserves 0302, 0303, 0304, 0305, and 0306 for BCD
bcdCurDigit = $0307 ; BCD scratch
bcdB        = $0308 ; BCD scratch

FT_BASE_ADR     = $0600 ; Page in RAM for FamiTone
FT_DPCM_OFF     = $f000 ; For Famitone DPCM

;    Each bank is $2000 bytes (8kb)
; BANK 00 - Tile Data
; BANK 01 - Famitone2, music, and sound
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

    .bank 1
    .org $8000
    .include "include/famitone2.asm"
    ; You'll put sounds and music here

; Insert other banks here. Make them included files.

    .bank 14    ; second-to-last bank: $c000-$dfff
    .org $c000  ; Fixed PRG-ROM

; Make macros include file

; PPU Buffer write macro

; Make subroutines include file

; Bankswitch: Y = new bank
Bankswitch:
    sty current_bank
BankswitchNoSave:
    lda Banktable, y
    sta Banktable, y
    rts

; Sound subroutines here

; RNG subroutine here

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

    bit $2002 ; Reset latch
    ldy #$00 ; Initialize Y to 0
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

    ; Load controller state here
    
    ; When your state is done, do: jmp WaitForFrame

    ; First, see if our state needs to be initialized.
    lda game_state_initialized
    bne .state_ready
        ; If we got here, our state hasn't been initialized yet
        lda #$01
        sta game_state_initialized

        ; Use our jump table to jump straight to our initializing routine
        ldx game_state
        lda StateInitJumpTable+1, x ; High byte first
        pha
        lda StateInitJumpTable, x   ; Then low byte
        sec
        sbc #$01    ; Subtract 1 from low byte
        pha
        rts

.state_ready:
    ; Find our state in the jumptable and jump to that routine
    ldx game_state
    lda StateJumpTable+1, x   ; Push high byte first
    pha
    lda StateJumpTable, x ; Push low byte
    sec
    sbc #$01 ; Subtract 1 from it first tho
    pha
    rts

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

    ; Update PPU Memory
    lda $0700  ; Start of our buffer
    beq .nmi1 ; Skip our buffer read if we have no data.

    ; If we got here, it means we have data to read from the buffer.
    ldx #$00
    jsr PPU_Parse_Buffer

.nmi1:
    ; Update PPU registers
    ;   This should be behind a flag
    ;   Or could it even be buffered as well?

    ; You'll update sounds/music here

    lda #$00
    sta game_asleep ; Go back to sleep

    ; Unwrite our buffer
    ldx #$00
    stx ppu_buffer_length ; Unset current buffer length, so next frame begins at the start
.loop:
    sta $0700, x
    inx
    bne .loop

    ; Restore our registers
    pla
    tay
    pla
    tax
    pla
    rti ; NMI done

PPU_Parse_Buffer:
    ; PPU Buffer is $0700 to $07ff. X tracks position within that distance
    ; Be sure to enter with x at 0. Beware of X looping!
    ; Note that X increments in this starting portion as well as the loop itself.

    ; read the length
    lda $0700, x            ; A is the length of this chunk
    tay                     ; Put it into Y in case we use loop 2 below.
    stx ppu_buffer_scratch  ; X is whatever index we are at now in the page
    clc
    adc ppu_buffer_scratch  ; A is current index + length of the chunk <- but what happens if this wraps?
    clc
    adc #$04                ; Add 4 more to account for our buffer data
    sta ppu_buffer_scratch  ; This will be our comparison in the loop below

    ; Write our address
    bit $2002   ; Reset our address latch
    inx
    lda $0700, x ; High byte of the PPU Address
    sta $2006
    inx
    lda $0700, x ; Low byte of the PPU Address
    sta $2006
    inx

    ; Set our registers/properties
    lda $0700, x    ; Properties byte
    asl a
    asl a           ; Make bit 0 bit 3
    and #%00000100  ; For now, keep only bit 3
    ora #%10000000  ; Add in the other bit to keep for PPUCTRL
    sta $2000       ; Store it
    
    ; Read more bits here. Just don't add too much or you'll run out of vblank time.

    inx
    lda $06ff, x    ; Properties byte again (we read 6ff to undo our last increment)
    and #%00000010  ; Keep only bit 1
    beq .loop      ; If we need to do one byte repeated, use different loop type. Otherwise continue.
        ; If we got here, we are using loop type 2. Prepare it here.
        lda $0700, x    ; Read the byte we'll be writing repeatedly.
        jmp .loop2
.loop:
    lda $0700, x ; Load next buffer byte
    sta $2007   ; Write to the PPU
    inx         ; Increment
    cpx ppu_buffer_scratch  ; Compare to end value
    bne .loop               ; If we aren't there, loop again

    ; Check next length
    lda $0700, x
    bne PPU_Parse_Buffer ; If next value is 0, we're done.
    rts

.loop2:
    sta $2007   ; Write our repeated byte
    dey         ; Decrement Y
    bne .loop2  ; If we aren't at 0 reps left, loop again.

    ; Check next length
    inx         ; We didn't increment X in our loop so we have to do it only once now.
    lda $700, x
    bne PPU_Parse_Buffer ; If next value is 0, we're done.

    rts

;...

    .include "states/playing.asm"
    ; More states here?

    .include "player.asm"

;...

    .bank 15 ; Last bank: $e000 to $ffff
    .org $e000

Banktable:
    .db $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0a, $0b, $0c, $0d, $0e, $0f

; For these jumptables: store addresses little-endian because it's consistent.
; I guess it really doesn't matter though.
StateInitJumpTable:
    .db low(StatePlayingInit), high(StatePlayingInit)

StateJumpTable:
    .db low(StatePlaying), high(StatePlaying)

    .org $f000 ; If you change this, don't forget to change at the start of the file
DPCM:
    ; DPCM bin data goes here?
    ; I'm not totally certain on this.

Palettes:
    ; Nametable
    .db $0f, $0f, $37, $07 ;0
    .db $0f, $05, $2b, $0c ;1
    .db $0f, $2b, $0c, $34 ;2
    .db $0f, $05, $2b, $10 ;3

    ; Sprites
    .db $0f, $0f, $39, $09 ;4
    .db $0f, $07, $17, $27 ;5
    .db $0f, $30, $16, $10 ;6
    .db $0f, $00, $10, $20 ;7

    .org $fffa ; Vectors
    .dw NMI
    .dw Reset
    .dw 0 ; No IRQ?
