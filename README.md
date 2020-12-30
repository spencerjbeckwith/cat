# CAT

Platform game involving two cats named Emily and Jane, fighting an adventure to finally return home, or something. I don't know yet but it's gonna be written in 6502 assembly cause I'm obviously a masochist. Might not turn out well but at least it'll be a *learning experience*.

If you want to keep up to date with me for some reason (I don't know why you ever would lul) you can download the ROM from here, though it'll probably be buggy and incomplete until I'm actually done. You could also build it using `npm run compile` which just uses NESASM. So make sure that's added to your environment variable or add it to your directory.

In this file I'm gonna be writing my plans and technical stuff to kind of organize my thoughts, so don't expect too much from me.

## Planned features:
- Platformer game
- Two player
- Who knows, this is just for fun


## PPU Buffer
This is an amazingly helpful resource: [The frame and NMIs on NESDEV](http://wiki.nesdev.com/w/index.php/The_frame_and_NMIs) and so naturally I'm gonna implement something similar.

My PPU Buffer. Variable ppu_buffer_length refers to where in the buffer to write new data. And since this can only store 0-255, that means we will reserve 256 bytes for this buffer in memory from $0700 to $07ff. Yeah, it's not the zero page, but it's out of the way that it nicely takes up only one page at the end of RAM.

A write to the PPU Buffer:
- **Byte 0**: Data length. 0 means end of buffer.
- **Byte 1**: High byte of target PPU address.
- **Byte 2**: Low byte of target PPU address.
- **Byte 3**: Properties
    - Bit 0: Set if increase address by 32, unset to increase address by 1 on write.
    - Bit 1: Set to write one tile (length) number of times.
- All subsequent bytes are written.

## Game States
We will use a jump table, directly after NMI, to jump to our new state routines. The state routines will do all the game logic. Each state needs two routines:  An init routine which will activate when the state is first switched too, and then the frame state that will happen every frame. The initializing routine may or may not lead directly into the frame routine, BUT no matter, you need to make sure it ends with `jmp WaitForFrame` or else the state will lock up once it gets to the end.

*Also, remember that when you switch states, unset the game_state_initialized variable or else the new one won't initialize!*

Naturally there are some things which will happen every frame, and that should go in the DoFrame routine. Also, I don't see why you shouldn't be able to bankswitch to get to different state routines, but you'll have to do some more thought and figure that out and implement the proper switching code in DoFrame first. That's something to worry about if/when you begin to run out of space.

States you have:
- Playing

States you'll probably need:
- Title?
- Gameover?

## RAM Map
Zero Page: so far, the first row is global things and things used by the game state/PPU.
- Zero page
- $0100-$01ff: Stack
- $0200-$02ff: OAM
- ...
- $0600-$06ff: Famitone2
- $0700-$07ff: PPU Buffer

## The Player
I worked out how this will work when I get around to implementing the player: should have movement on both X and Y axis and should be able to accelerate and deccelerate according to input and location on screen. I'm not sure how collisions are going to work yet, but I've figured out the movement:
- Player will have X and Y in RAM of course, along with one Velocity byte. Both nybbles are signed values, with the left four bits representing vertical movement and the right nybble representing horizontal movement.
- Each value possible in each nybble corresponds to a "stage" of velocity, which will then be referenced into a table of pixel movement values. This also changes depending on the frame count (0-3) so some frames will have more movement if in a different frame index. This simulates fractional movement even though every possible X value has to be a whole number.
- There will be two more bytes, a X counter and Y counter. These are set according to input and the stage of velocity horizontally and vertically, and will count down to 0. When hitting zero, the stage will then change to the next, either up or down, depending on direction and input, etc. This simulates acceleration. The first few stages will take less time to reach than the later stages, representing that moving faster takes longer to get going *and* slow down.

Also, the player reserves sprites 1, 2, 3, and 4. Not sprite 0 in case I want to use a sprite 0 hit later.

Player Properties Byte:
- Bit 0, bit 1, bit 2: determine the players state.
- Bit 3, bit 4, bit 5: determine the player image to show
- More bits...?

## Input
There are six variables in the zero-page that keep track of both gamepad's held, pressed, and released status. To check, use the macro `button_check` with the arguments: input variable, button constant, and the label to jump to if the check passes.
To convert code to check from p1 to p2, simply add 3 to the variable you're checking (or use the other constant)

## Do next:
- Make GetSpeedDelta macro
- Make Y acceleration/movement for player
- Make macro that'll write to our PPU buffer
- Begin player
    - Attribute byte
    - Physics step
    - Movement step
- Write subroutines to bankswitch and play sound/music properly
    - Also, implement the necessary initializing code in reset routine
- Add RNG include
- How to make P2 control the player?
    - Also don't forget to do a palette swap for that
- PLAN what you're making you numbnutz
