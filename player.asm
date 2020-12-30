;   These constants are for bits 0 1 and 2 of the properties byte.
PLAYERSTATE_NONE    = %00000000
PLAYERSTATE_PLAYING = %00000001

;   Reserve four sprites for our 16x16 image
;   The origin of this sprite is between the top two sprites (8,0)
PLAYERSPRITE1_Y = $0204 ; Top-left
PLAYERSPRITE1_T = $0205
PLAYERSPRITE1_A = $0206
PLAYERSPRITE1_X = $0207

PLAYERSPRITE2_Y = $0208 ; Top-right
PLAYERSPRITE2_T = $0209
PLAYERSPRITE2_A = $020a
PLAYERSPRITE2_X = $020b

PLAYERSPRITE3_Y = $020c ; Bottom-left
PLAYERSPRITE3_T = $020d
PLAYERSPRITE3_A = $020e
PLAYERSPRITE3_X = $020f

PLAYERSPRITE4_Y = $0210 ; Bottom-right
PLAYERSPRITE4_T = $0211
PLAYERSPRITE4_A = $0212
PLAYERSPRITE4_X = $0213

; These macros should help player functionality.
    .macro GetXVelocity ; Stores X velocity into A
        lda player_velocity
        and #%00001111  ; Get only the right nybble
    .endm

    .macro SaveXVelocity ; Make sure A is the current X velocity.
        and #%00001111      ; Keep just our current nybble - cuts out any carry
        sta player_scratch  ; Put right nybble into RAM
        lda player_velocity ; Load left nybble
        and #%11110000
        ora player_scratch  ; OR left nybble (in A) with right nybble (in RAM)
        sta player_velocity ; Store
    .endm

    .macro GetYVelocity ; Stores Y velocity into A
        lda player_velocity
        and #%11110000  ; Get only the left nybble
        lsr a
        lsr a
        lsr a
        lsr a           ; Make it the lower four bits
    .endm

    .macro SaveYVelocity ; Make sure A is the current Y velocity.
        and #%00001111      ; Keep just current nybble - cuts out any carry
        asl a
        asl a
        asl a
        asl a               ; Make it our left nybble
        sta player_scratch  ; Put left nybble into RAM
        lda player_velocity ; Load right nybble
        and #%00001111
        ora player_scratch  ; OR right nybble (in A) with left nybble (in RAM)
        sta player_velocity ; Store
    .endm

PlayerInit:
    ; Set initial values
    lda #$7f        ; You'll want X and Y to change later
                    ; Maybe make a create subroutine or macro?
    sta player_x
    lda #$a8
    sta player_y
    lda #$00
    sta player_velocity
    sta player_xcount
    sta player_ycount

    lda #PLAYERSTATE_PLAYING ; Again, this would be different later
    sta player_properties

    rts

PlayerStep:
    ; First, figure out our state
    lda player_properties
    and #%00000111 ; Only last three bits

    cmp #PLAYERSTATE_NONE
    beq .nostate            ; Skip everything

    cmp #PLAYERSTATE_PLAYING
    beq PlayerStepAccelerate

    ; More states will go here

.nostate:
    ; If our sprite isn't off screen, move it there.
    lda PLAYERSPRITE1_Y
    cmp #$ff
    beq .stepdone
        ; If we got here, our sprite is still on screen. Move all four segments off
        lda #$ff
        sta PLAYERSPRITE1_X
        sta PLAYERSPRITE1_Y
        sta PLAYERSPRITE2_X
        sta PLAYERSPRITE2_Y
        sta PLAYERSPRITE3_X
        sta PLAYERSPRITE3_Y
        sta PLAYERSPRITE4_X
        sta PLAYERSPRITE4_Y
.stepdone:
    rts

PlayerStepAccelerate:
    ; xcount and ycount record how many frames before each speed changes.

    lda player_xcount   ; Check x count
    beq .xcount         ; If it isn't zero, decrease it and skip.
        dec player_xcount
        jmp .CheckYCount
.xcount:
    ; If we got here, X count is 0.

    ; If input is left, decrease stage but not past 1000
    button_check input1, #BUTTON_LEFT, .xcount_left
    button_check input1, #BUTTON_RIGHT, .xcount_right
    ;If we got this far, neither button is pressed.

    ; If x stage is 0, skip straight to y count
    GetXVelocity
    cmp #%00000000      ; 0 in right direction
    bne .1              ; We do this to avoid page limit on branches
        jmp .CheckYCount
.1:
    cmp #%00001111      ; 0 in left direction
    bne .2
        jmp .CheckYCount
.2:

    ; If it's negative, increase it. If its positive, decrease it.
    and #%00001000 ; Just our sign bit
    cmp #%00001000 ; Compare our sign bit
    beq .xcount_stageNegative
        ; If we got here, our stage is currently positive. Decrease it.
        GetXVelocity
        sec
        sbc #$01
        SaveXVelocity
        jmp .xcount_set

.xcount_stageNegative:
        ; If we got here, our stage is currently negative. Increase it.
        GetXVelocity
        clc
        adc #$01
        SaveXVelocity
        jmp .xcount_set

.xcount_left:
    ; If we got here, we are going left.
    GetXVelocity
    
    ; Decrease the stage, but not past 1000
    cmp #%00001000
    beq .xcount_set
        ; If we got here, we can decrease.
        sec
        sbc #$01
        SaveXVelocity
    jmp .xcount_set

.xcount_right:
    ; If we got here, we are going right.
    GetXVelocity

    ; Increase the stage, but not past 0111
    cmp #%00000111
    beq .xcount_set
        ; If we got here, we can increase.
        clc
        adc #$01
        SaveXVelocity
    ; Continue straight into setting xcount below...
.xcount_set:
    ; Set our new xcount based on the table and current stage
    GetXVelocity
    tax
    lda XCountTable, x
    sta player_xcount

    ; Continue straight into ycount below...
.CheckYCount:
    lda player_ycount   ; Check y count
    beq .ycount         ; If it isn't zero, decrease it and skip.
        dec player_ycount
        jmp PlayerStepAnimate
.ycount:
    ; If we got here, Y count is 0.


    ; Continue straight into movement below...
PlayerStepMove:

    ; Get X speed delta based on deltatablex
    ; Check for collisions
    ; Change X

    ; Get Y speed delta based on deltatabley
    ; Check for collisions
    ; Change Y

    ; Continue straight into animation below...
PlayerStepAnimate:

    ; Continue straight into update OAM...
PlayerStepUpdate:
    ; Make sure to call this if you want your state to make any change visible on screen!

    ; Set correct position of all four sections
    lda player_x    ; Place sections 2 and 4 at x, 1 and 3 at x - 8
    sta PLAYERSPRITE2_X
    sta PLAYERSPRITE4_X
    sec
    sbc #$08
    sta PLAYERSPRITE1_X
    sta PLAYERSPRITE3_X

    lda player_y    ; Place sections 1 and 2 at y, 3 and 4 at y + 8
    sta PLAYERSPRITE1_Y
    sta PLAYERSPRITE2_Y
    clc
    adc #$08
    sta PLAYERSPRITE3_Y
    sta PLAYERSPRITE4_Y

    ; Set correct tile for all four sections
    ;   Initial tile for first sprite: tile = (4*image) + 1
    lda player_properties
    and #%00111000      ; Get only our image bits        
    lsr a               ; Divide by 2: equivalent to dividing by 8 and multiplying by 4
    clc
    adc #TILE_PLAYER_IDLE_1 ; Add our first tile as an offset

    ; Store tile into all four sprites
    tax
    stx PLAYERSPRITE1_T
    inx 
    stx PLAYERSPRITE2_T
    inx
    stx PLAYERSPRITE3_T
    inx
    stx PLAYERSPRITE4_T

    ; Set correct mirroring/palette for all four sections
    lda #%00000000
    sta PLAYERSPRITE1_A
    sta PLAYERSPRITE2_A
    sta PLAYERSPRITE3_A
    sta PLAYERSPRITE4_A

    rts