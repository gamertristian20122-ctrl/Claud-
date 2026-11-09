# v2.6 stream `gui`: the GUI overhaul ("candlelit wood and brass")

Branch `v26/gui`. The owner asked: "Can you overhaul the GUI". Every menu and the HUD now share one look built
from the house's own materials: dark mahogany frames with brass corner brackets and wax poured on the top rail,
dark-oak buttons with brass nails, a brass plate for each screen's main action, red sealing wax for the dangerous
one, a gold ring with a little flame for keys and gamepads, and the clock + wax bar as one candle-clock gauge.

Before / after (the same 12 screens at 480x216, the integrator's 2.5.0 sheet on the left):
`docs/streams/img/v26_gui_before_after.png`.

## The kit, and where it lives

| Piece | Where |
|---|---|
| The art (56 PNGs, 0x72 palette, 1 px ink outline, flat fills; the tool checks every pixel against the sheet) | `tools/art_ui2.py` -> `assets/art/ui/kit_*.png`, `hud_*.png`, `ico_*.png`, `boss_frame.png`, `title_books.png` (list + sizes: `DESIGN.md` > UI) |
| The look, in ONE place: a Godot `Theme` built from that art | `UI.theme()` in `scripts/ui/ui.gd` |
| Installed once for every Control in the game | `UI.install()` (first line of `main.gd` `_ready`): folds the Theme into the engine's default theme, so a plain `Button`, `PanelContainer` or scroll bar already wears the kit, under any CanvasLayer |
| What a Theme cannot do (button kinds, focus flame, toggles, slider, headings, drips, motion) | the factories in `scripts/ui/ui.gd` |

`python3 tools/art_ui2.py [--review DIR]` redraws the kit (identical output each run) and writes a 6x contact
sheet and a mock panel with every button state to DIR. Run `godot --headless --path . --import` after it (then
`git checkout -- default_bus_layout.tres`).

### Theme types

| Type (`theme_type_variation`) | Look | Made by |
|---|---|---|
| `Button` | dark oak plank, brass nails; hover: a warm edge; pressed: the face sits 1 px lower (the words too); disabled: grey | `UI.button(text, cb, w)` or any `Button.new()` |
| `PrimaryButton` | a brass plate, ink words (the screen's ONE main action: Light the wick, Resume, Light another, Play / Continue) | `UI.primary(...)` / `UI.button(..., "primary")` |
| `DangerButton` | red sealing wax (Give up, Delete) | `UI.danger(...)` |
| `TabButton` / `TabButtonOn` | dark tab / lit tab with a gold rule (Settings pages, Journal) | `UI.button(..., "tab")`, swap `theme_type_variation` with `UI.KINDS` |
| `SlotButton` | an 18x18 icon socket (relics in the pause menu and on the results) | `Button` + `icon` |
| `PanelContainer` | the framed panel; `UI.panel()` adds the wax drips on a wide one | `UI.panel(min_size)` |
| `CardPanel` / `InsetPanel` / `PlatePanel` / `StripPanel` / `ChipPanel` | slim card / sunken well / brass plate / dark ribbon / HUD counter chip | `UI.panel(min, "card" / "inset" / "plate" / "strip")` |

Focus (keys and gamepads only; touch and mouse never see it): the Theme's `focus` box is an ink + gold ring drawn
2 px outside the button (clear on a TV and a phone), the words turn gold, and `UI.button` lights a 7x10 flame next
to the words of a wide, centred, text button (not on icon buttons or keys narrower than 56 px).

### Helpers (all in `ui.gd`)
- `UI.label(text, 8|16, colour)` as before (8 and 16 px only: Kenney Mini / Kenney Pixel), `UI.outlined(l)`,
  `UI.engraved(l)` (ink letters with a bright edge, for words on a brass plate).
- `UI.heading(text)`: the words between two brass flourishes (every `UI.modal(parent, title)` uses it).
- `UI.icon_button(text, "ui/ico_...", cb, w, kind)`, `UI.toggle(...)` (name left, an ON/OFF switch right; the
  button keeps `meta "on"`), `UI.cycle(...)` (the value in gold on the right), `UI.slider_row(...)` (the real
  slider `UI.KitSlider`: tap / drag / left-right, a notch per step, a flame knob).
- `UI.separator(w)`, `UI.picture("ui/...")`, `UI.focus_box()` (for hand-drawn controls such as the Night slider).
- Motion: `UI.pop_in(fade, mover)` (a panel rises 6 px and fades in, 0.14 s, pixel-snapped, runs while paused;
  every `UI.modal` does it), `UI.wipe_in(screen)` (a cream / gold / ember edge sweeps a full-screen menu in, 0.2 s:
  Slots, Journal), `UI.calm()` = Settings > Game > **Reduce motion** (`Game.settings.reduce_motion`): no pops,
  wipes or slides, the title's opening is skipped and the paper-burn screen change becomes a 0.15 s fade.

### How a new screen uses it
```gdscript
var m := UI.modal(parent, L.t("A NEW THING"))          # framed panel, heading, pop, focus handled
var v: VBoxContainer = m[1]
v.add_child(UI.label(L.t("One line of text."), 8, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
var row := HBoxContainer.new()
row.add_child(UI.primary(L.t("Do it"), func(): ..., 96))   # the one main action: brass, focused first
row.add_child(UI.button(L.t("Back"), func(): m[0].queue_free(), 80))
v.add_child(row)
```
No `add_theme_stylebox_override` is needed for kit pieces; a full-screen menu calls `UI.wipe_in(self)` at the end
of `_ready`. Every new string goes through `L.t(...)`; run `python3 tools/extract_strings.py` to refresh
`lang/en.json`.

## What changed on each screen

- **Title** (`title.gd`): the logo with the game's line under it; Tallow (the chosen candle) centre stage on three
  old books (`title_books.png`), lit, his light pooled on the floor (the room's banded light) and the slot's numbers
  in short lines under him; the **Candle Box** in a panel on the left (arrows + name, the move's icon / name / line,
  the candle's line or its unlock in red, fixed height); the actions on the right: Continue, ONE big brass **Light the
  wick** (32 px, an engraved flame), Tonight's Candle (moon); Journal / Seed / Settings / Credits (/ Quit on desktop)
  as small icon buttons along the bottom; the version small in the top-right corner. `_layout()` places everything
  from the screen's centre, so 384x216, 384x240 and 480x216 share one composition.
- **HUD** (`hud.gd`): the **candle gauge** is the hero: big 8x12 clock digits (2 px strokes, red when the wax is low)
  on a brass-rimmed plate sitting right on the wax bar's holder, "AM" small after them, the spare minutes and the
  Kindling streak beside the plate. The bar keeps its art, notches, flame, red damage trail and the ghost-cost
  preview. Coins and bombs in chips (12x12 icons, 16 px numbers); the floor's name (8 px, wax colour) with a pip per
  floor of the night (behind gold, this one cream, the tower blue); 10x7 minimap cells. **Banners**: the title is
  engraved on a brass plate that drops 3 px into place, its line on a dark ribbon with brass ends; hints and item
  previews use the same ribbon. **Boss bar**: a brass-capped frame, a wine-red fill with a bright cut edge, the
  guardian's name in 16 px cream with an ink outline. The play area, the right-hand round buttons, their sizes,
  positions and hit areas are unchanged.
- **Results** (`results.gd`): a headline card (portrait; DONE BY 1:06 AM / SNUFFED OUT / TRUE ENDING / the ending's
  name; the line under it; the candle and where; a gold medal or a red wax seal), five icon tiles (played, floor,
  foes, Kindling, diary pages or rooms), the relics in sockets with their line, "new in the house" and the
  achievements as two small cards side by side, then Tonight's score / the next candle and level + seed. Light
  another (brass) / Share / Title stay pinned; the column is as wide as the screen allows (320 px on 384, 400 on
  the phone's 480).
- **Pause**: the heading with flourishes, relics in sockets, Resume in brass, Give up in red wax (its confirm too),
  Keep burning focused first in both confirms.
- **Slots** (`slots.gd`): a used slot shows its candle twice the size and lit in a niche, the level as a brass medal
  pinned on it, the level's name, best time, runs and wins and the Journal as a stepped progress ring; Play (or
  Continue) in brass, Delete in red wax. An empty slot: the sleeping candle, big, "A fresh candle waits here." and a
  New candle that is brass while no slot is used yet. The Night slider draws the kit's track and flame knob.
- **Settings**: kit tabs, switches, cycles with their value, real volume sliders, a new **Reduce motion** row; the
  Effects Lite note moved under the grid (the other streams' rows keep their places; any new `UI.toggle` /
  `UI.cycle` row is styled automatically).
- **Journal**: kit tabs (5 px side margins, so its seven tabs fit 384 px), framed panels, the wipe.
- **Boss card**: the guardian's name engraved on a brass plate. **Reading card**: Martha's red wax seal on the
  corner; it rises as it fades in. **Achievement toast**: the kit's card.

## Checks (final code)

| Judge | Result |
|---|---|
| `--checkscripts`, `--checkrooms` | 0 failed; 0 problems (69 layouts, 1776 dressed rooms, 657 area rooms) |
| `--playtest --speed=4 --runs=1 --god` | 1 of 1 reached the end (win), 0 SCRIPT ERRORs |
| `--tour --fit`: main, `--slots`, `--journal`, `--platform`, `--diary`, `--moves`, `--night`, `--gui` at 1600x720 | 0 SCRIPT ERRORs, 0 fit flags; platform `fails=0`, slots `fails=0` |
| main tour, `--gui`, `--platform` at 1280x800 (384x240) and 1920x1080 (384x216) | 0 SCRIPT ERRORs, 0 fit flags, platform `fails=0` |
| `python3 tools/art_ui2.py` | palette check PASS (56 files) |

`--tour --gui` (`scripts/ui/gui_tour.gd`, new) shows every screen the kit dresses in ~40 s: title, seed pad,
Credits, Slots (empty / used), Settings pages, Journal, HUD (start, banner + hint, shop preview with the ghost cost,
low wax + boss bar), pause, reading card, results (a rich win, a death) and Reduce motion. `--device=keyboard` /
`gamepad` shows the focus ring and flame.

## Hooks outside this stream's files (for the merge)
- `main.gd`: `UI.install()` first in `_ready`; `goto()` uses a 0.15 s plain fade when `UI.calm()`.
- `game.gd`: the `reduce_motion` setting (default false).
- `settings_panel.gd`: tab buttons use `"tab"` kinds; the Game page swaps the Lite hint cell for the Reduce motion
  toggle and puts the hint under the grid (the `feel` stream's rows are untouched).
- `tower.gd`: `_insert_after()` puts its results lines next to the line they follow (the headline card nests them).
- `boss_card.gd` (the name plate), `page_card.gd` (pop + seal), `achievements.gd` (the toast's `CardPanel`).
- `slots_tour.gd`: presses "Light it" on v2.2's night picker (the tour had stopped there since v2.2).
- `autotest.gd`: `--tour --gui`.

## Known issues / not done
- The game has no keys, so the HUD counters are coins and bombs (the keepsake keeps its own round button).
- A first win with the tower hint, two diary pages, seven relics and three unlocks still scrolls the results panel
  a little at 216 px tall (the buttons stay pinned and the headline, tiles and relics show without scrolling).
- Text strings that were already in old code stay unwrapped where tower.gd / diary.gd match them by their English
  words ("DONE BY", "The house is quiet"); the new strings go through `L.t`.
- The old `panel_9` / `button_9` / `focus_9` art (art_ui.py) is no longer used by the menus; it is kept for now.
- Reduce motion covers the menus and the screen change only; the boss card's slide, boss intros and gameplay
  juice keep their motion (Screen shake has its own switch).
- Not checked on a real phone yet (the owner's device): sizes were judged on 480x216 screenshots.
