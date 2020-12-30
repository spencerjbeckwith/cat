StatePlayingInit:

    ; Initialize stuff here
    jsr PlayerInit

StatePlaying:

    ; Do stuff
    jsr PlayerStep

    jmp WaitForFrame