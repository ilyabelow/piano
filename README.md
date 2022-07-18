# Cool and New Piano Tiles

So remember a mobile game called Piano Tiles? I think it was a pretty cool game, but it had a problem (which made it somewhat lame) - it only supported chosen songs.
This game (or rather a prototype) works by loading any MIDI into it!!!

Of course, the original game did not support custom MIDIs for a reason - not every MIDI plays great. But nice playthrough can be achieved, my version does the simplest thing

## Installation

To build and run the app, you will need to install Processing [here](https://processing.org/)

Note: in `data/info.json` manually change default path to a MIDI file by hand. My bad not fixing it

## Controls

`ASDF` - click on tiles

`numbers` - choose track of MIDI. MIDIs have several parallel tracks, you can choose which one is best to play (todo: analyse tracks and merge them somehow). 
Usually the 0th (the default) track contains the most part of the melody

`Enter` - choose MIDI

`Backspace` - return to main menu

`Escape` - exit
