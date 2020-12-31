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

You'll probably want to reserve maybe a page or so for a collision map?

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

## Collisions
I'm not quite sure how this would work to begin with. If game tiles will be 16x16, and we use binary to mark collisions, each row of the screen would take two bytes, and since the screen is then 15 tiles tall, we could represent an entire screen in 30 bytes before compression. When the player walks, the screen should scroll rather than actually moving player x and y. Now, the problem I'm thinking of right now is if we represent solids with individual bits, how is that supposed to work? Rotate 30 bytes every time the screen scrolls? I guess it's easier than writing 30 new bytes each time.
When it comes to collision checking, we have player x and y positions on screen. Divide that by 16 to get a position in the table... but how do we translate that into the bits?
```
In RAM somewhere: 30 bytes of current screen collisions
    X ->
  Y 0 0 0 0 0 0 0 0 - 0 0 0 0 0 0 0 0
 \/ 0 0 0 0 0 0 0 0 - 0 0 0 0 0 0 0 0
    0 0 1 0 0 0 0 0 - 0 0 0 0 0 0 0 0
    0 0 1 0 0 0 0 0 - 0 0 0 1 1 1 1 1
    0 0 1 0 0 0 0 0 - 0 0 0 0 0 1 1 1
```
So we can get the coordinates of a bit. Then we need to locate the byte that solid would be located in, and extract just the bit we are interested in by shifting an arbitrary number and comparing. Other things to consider:
- Nametable updating and scrolling. I need to do some research on how exactly this works.
    - Where do the tiles get loaded from? Hopefully I will have compressed data in a bank or something. You can't shift bits in ROM, though, so you'll probably need a small counter that'll track which bit needs to be shifted next. For example, if you're five tiles over, you want to shift in bit 2. So you'll have to roll all 15 rows either 5 or 2 times, or the furthest bit would have to be rolled 8 times. Ouch. So that's another a maximum of 8x15 (120) rolls per tile column that comes on screen in addition to the 30 rolls to move our main bytes.
    - Your screen tracker would also need to be able to scroll backwards as well. Just subtract 30 (right?) from the tracker, if it's located at the right side of the screen.
    - Loading new nametable tiles as well as loading new collision data need to happen together. Otherwise it'll be impossible to tell what and where the new tiles should be, you'd have to rewrite the entire screen. So keep in mind that whenever/however you load the new collisions, you also have to load the tiles.
        - I suppose the loading has to happen when the screen moves because the player has moved. That makes sense, right? We should probably load tiles that are slightly offscreen.
        - But again, how exactly does scrolling work? We probably need to write bytes in the PPU at a certain address plus the scroll amount... that would make sense, right? Still trying to wrap my head around it.
- And when the nametable scrolls, how can you make other game objects like enemies scroll along with it too?
    - Maybe have a list of all objects, and when the player moves, also move those objects along with the view? If you don't, they'll appear to move with you. Hm.
- Speaking of which, how would I then store extra objects in this format?
    - Preliminary idea: stick extra bytes at certain positions, preceeding other bytes. Four bits of this inserted byte contain the tile location (0-8) of the bit to load, and the other four bits contain the index to insert there. But there's a few problems with this:
        - How is the parser supposed to tell an inserted byte from a legit tile byte? This also limits me to only 8 possible objects! No.
    - Better idea: Have a separate list of objects that gets scrolled along with the level. Then when an object's scroll is hit, spawn the object at a certain location.

Would it be easier for the level format to instead store a byte for each tile? That way the byte can put different tiles, because using only bits doesn't leave much room for the parser to insert different tiles and the scenery would all be the same, and boring. I have enough banks I should be able to store multiple compressed levels, I think. And if each tile is a byte, I can reserve some bits in each tile for other objects or things to put at certain positions. Like if bit 7 of a byte is set, then the parser will know it should read the next byte for an object, for example, or something like that. Then in the original byte, bits 0 to 6 can then indicate the tile index.
- This would make it much easier to wrap my head around, because then I'm not doing absurd levels of rolling or shifting bits around in confusing and tricky ways. It'll take more space, of course. And to store one screen in RAM, we would need 240 bytes (almost a page).

## Do next:
- Make Y acceleration/movement for player
- Make macro that'll write to our PPU buffer
- Figure out how collisions will work
- SCROLLING? oowee
- Write subroutines to bankswitch and play sound/music properly
    - Also, implement the necessary initializing code in reset routine
- Add RNG include
- How to make P2 control the player?
    - Also don't forget to do a palette swap for that
- PLAN what you're making you numbnutz
