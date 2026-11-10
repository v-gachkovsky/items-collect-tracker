# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project uses [Semantic Versioning](https://semver.org/).

## [0.1.0-beta1] - 2026-11-10

First public version. The addon is in early development: please report anything that looks wrong.

### Added
- **A see-through bar** of the items you collect. It starts empty, with just a faint **+**; each item gets an
  icon with its count from your bags, and the + moves on to the next place. No frame and no background unless
  you want them, and the + can show only under the mouse.
- **Adding an item**: click the + and type a name. Suggestions show as you type, with icons and quality colors:
  items in your bags first, then items you've seen, then every item the game knows. Or shift-click an item,
  drop one from your bags on the +, or type `/ic add Linen Cloth`.
- **A goal for each item**: after adding, the addon asks how many to collect (the stack size to begin with;
  0 just counts). Once you have them, the number changes color and a sound plays: a game sound, a
  LibSharedMedia one, or your own file. A chat line too, if you like.
- **The number** goes above, below or on the icon, with your font, outline, size and colors. It shows the count
  (12), the count with the goal (12/20), or how many are still missing (8).
- **Ctrl + left click** takes an item off the bar; the keys and the mouse button can be changed.
- **Right click** on an item: change its goal, move it left or right, lock the bar, settings.
- **Moving and resizing**: drag any icon or the + to move the bar, its bottom-right corner to make the icons
  bigger or smaller. Items in a row, the space between them, opacity, background, counting the bank, greying
  out what you don't have and hiding in combat are in the settings (`/ic`).
- The items on the bar are kept for each character; the look and the sound are shared.
- English and Ukrainian.
- Works on WoW Forever, Classic Era, TBC Anniversary, Mists of Pandaria Classic and Retail.
