# ItemsCollectTracker

A small, see-through bar for World of Warcraft (made for **WoW Forever**) that counts the items you're
collecting and tells you when you have enough.

- Starts empty: just a faint **+**. Click it and type a name (suggestions show as you type, from your bags,
  items you've seen and every item the client knows), shift-click an item, or drop one from your bags.
- Then set how many to collect (0 = no goal, just count).
- Each item shows its count in big numbers: above, below or on the icon. Font, outline, size and colors are
  yours to pick; the number changes color once the goal is reached, and a sound plays (a game sound, a
  LibSharedMedia one, or your own file).
- **Ctrl + left click** takes an item off the bar (the keys and the button can be changed).
- Right click on an item: change its goal, move it left or right, lock the bar, settings.
- Drag any icon (or the +) to move the bar, its bottom-right corner to resize it. No frame and no background
  unless you want one; the + can show only under the mouse.
- English and Ukrainian.

The items on the bar are kept per character; the look and the sound are shared by all characters.

## Commands

| Command | |
|---|---|
| `/ic` | settings |
| `/ic add [item]` | add an item (name, ID or link) |
| `/ic lock`, `/ic unlock` | lock or unlock the bar |
| `/ic show`, `/ic hide` | show or hide the bar |
| `/ic reset` | put the bar back in the middle of the screen |

## Your own sounds

Put `.ogg` or `.mp3` files in `World of Warcraft/_forever_/Interface/ItemsCollectTrackerSounds/`, restart the
game, then type the file name in the settings (Goal reached → Your sound file).

## Development

```sh
# link into the Forever client
ln -s "$PWD/ItemsCollectTracker" "/Applications/World of Warcraft/_forever_/Interface/AddOns/ItemsCollectTracker"

# tests (plain Lua, no game needed)
lua tests/run.lua    # text matching, parsing, click combinations
lua tests/load.lua   # loads the addon against a pretend game API and plays a session
```
