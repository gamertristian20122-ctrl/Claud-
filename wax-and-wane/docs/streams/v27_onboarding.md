# v2.7 stream `onboarding`: shown the controls by animation, learn by doing, told once

Branch `v27/onboarding`. A real player (the owner's friend) tried 2.6: the game is fun, but "learning the tutorial is
not great", "there should be an animation or something telling you the controls first", and the teaching is "kind of
redundant". This stream gives a new save slot an animated, learn-by-doing controls primer before the first fight and
takes every other teaching text down to one just-in-time showing per slot.

## The judge (written first, run on 2.6 before any change)

`--autotest --primercheck` (`scripts/primer_check.gd`, `PrimerCheck`) plays a brand-new player's first three minutes
on each device: a fresh slot in memory (it never writes the save), the title's Light the wick -> New candle ->
Midnight -> 4 floors -> the run (seed 2701, so every device and every build sees the same house), the story card
(Begin as soon as it takes a press), the primer with simulated input when there is one (thumbs on the screen, keys, a
gamepad: real input events through the HUD), then the play-test bot to the first room's first kill and on to minute
three (4x after the kill). It polls the HUD, so it works on any build: every hint, every card's teaching lines (one
card = one text), every chalk drawing (once a run) and every primer step is logged with what it teaches; a **repeat**
is a text that teaches nothing new. Run it with its own profile:
`XDG_DATA_HOME=/tmp/x godot --headless --path . -- --autotest --primercheck [--device=touch|keyboard|gamepad]`.

## BEFORE: every teaching moment of the first three minutes (2.6, touch, in order)

| When | Where | What it says | Duplicate of |
|---|---|---|---|
| title | Candle Box (`title.gd`) | "Flare Up - Burn 2 minutes of wax to blaze for 3 seconds." | (the candle picker: kept) |
| 0:03 | story card "12:00 AM" (`world._intro`) | 4 story lines + "Your wax is your life - and your time." + "Every hit melts you. Wax drippings mend you." + "Left thumb moves. Right thumb aims and fires. Bomb: the right button." (keys: "WASD moves. The arrow keys or the mouse fire.", pad: "Left stick moves. ...") | |
| 0:03 | 6 chalk drawings on the start room floor (`chalk.gd`) | WAX = TIME, MOVE, AIM+FIRE, BOMB, KEEPSAKE (Tallow has none yet), SPECIAL | the card (4 of 6) |
| 0:03 | ghost sticks (touch, runs 1-3, `hud._draw_ghosts`) | two faint rings at the thumb spots | the card + chalk (passive) |
| 0:04 | hint, 8 s (`world._intro` Begin) | "Left thumb: move   Right thumb: aim + shoot   Bomb: right button" (keys/pad add "SHIFT: Flare Up" / "LT: Flare Up") | the card AND the chalk |
| 0:05 | hint (every treasure room, every run) | "Choose one relic. The other will crumble." | itself, in the next treasure room |
| 0:11 | hint (once) | "That wall is cracked and seeping wax... a bomb might open it" | |
| 0:11 | hint, 6 s, first fight (`moves.gd`, a candle's first 2 runs) | "Big round button: Flare Up. Burn 2 minutes of wax to blaze for 3 seconds." | the chalk SPECIAL + the title |
| 1:22 | hint (special room, 2 per kind) | "Walk into the box to wind it: 3 coins a turn." | |
| 1:51 | hint (first hit, 2 per slot) | "Your wax spilled! Grab the warm drops before they cool" | itself at 2:19 |
| 1:53 | hint (floor 2, every omen, every time) | "Long Night: A bigger floor with two treasure rooms" | |
| 1:55 | hint (marked foe, 2 per slot) | "A marked foe glows: tougher, but it pays out" | itself (keys run) |
| 2:02 | hint (2 per slot) | "Kill quickly to keep the streak: Kindling pours minutes back in" | itself |
| later | keepsake: banner + "Keepsake: clear rooms to fill its pips, then tap its button" (2 per slot), "<name> is ready" (every charge) | | |
| run 2-3 | floor 1: the controls hint again (7 s) + the chalk again + the move hint again (run 2) | | runs before |

So in the first five seconds the controls are told three times (card, floor, hint) and the special move twice more
before the first fight; most hints show twice per slot and the treasure / omen / keepsake-ready lines every time.

BEFORE numbers (`--primercheck`, seed 2701; game seconds, simulated input, no reading time; reading = words shown
before the first kill at about 200 words a minute):

| Device | Light the wick -> first kill | Words before it (reading) | Teaching texts in 3:00 | Repeats | Re-told lessons |
|---|---|---|---|---|---|
| touch | 18.6 s | 120 (~36 s) | 18 | 8 | 10 |
| keys | 17.3 s | 115 (~35 s) | 16 | 6 | 9 |
| gamepad | 17.4 s | 114 (~35 s) | 17 | 6 | 9 |

## AFTER: the controls primer (`scripts/ui/primer.gd`, `Primer`)

A save slot's first run starts with it, in floor 1's start room, right after the story card and before the first
fight. Five short steps; each is **shown** by an animation of the device in use and **finished by doing it**:

| Step | Shown (touch / keys / gamepad; the mouse aims with its own picture) | Done when |
|---|---|---|
| 1 MOVE "Walk a few steps." | a thumb sliding on the left stick (the HUD's own stick art, where the ghost stick sits) / W A S D keycaps pressing in turn / a gamepad whose left stick (lit gold) tilts round | Tallow walked 26 px |
| 2 AIM + FIRE "Fire at the wax dummy." | the same on the right: the thumb pushing toward the dummy / the arrow key that points at it / the right stick / the mouse's left button held | three embers hit the **wax dummy** (`WaxDummy`: an old wax figure on a post with a target on its chest; it drops in, sways, wobbles and flashes on hits, pops into wax on the third) |
| 3 WAX = TIME "A hit melts minutes. Grab the drips back." | the HUD's clock + wax gauge in a marching gold frame; a staged moment: a wax bolt flies in, Tallow flinches (the real hurt look, hit chevron, red trail on the bar), the clock jumps **12:00 -> 12:04 AM** and two warm drips spill out | both drips picked up (+2 min each: the clock is back at 12:00 AM); drips float over after 6 s if nobody walks to them |
| 4 BOMB "Drop a bomb, then step back." | a thumb tapping the HUD's bomb button / its key (E, or the rebound key) / the pad with RB lit | a bomb dropped and blown (a practice bomb: it comes straight back and its blast cannot hurt Tallow here), or 7 s |
| 5 the candle's move (FLARE UP, its own line) | a thumb tapping the move button / its key (SHIFT) / the pad with LT lit; the move button gets a ring | the move used (its price shows on the gauge), or 7 s |

- The step's name sits on a small brass plate over its picture (kit `PlatePanel`), the line to do on the hint
  ribbon at the bottom (kit `StripPanel`) with five progress pips (the HUD's floor-pip look). A done step chimes,
  its pip turns gold and the next comes 0.3-0.9 s later; at the end the line says "Ready.", **the clock strikes
  twelve** (the bell) and **the doors open**.
- **Skip** is on screen from the start (a kit button under the minimap; "ENTER" under it on keys, "BACK" on a pad);
  a tap, a click, Enter or the pad's Back ends it at once. A player who skips before the sticks gets the one-line
  controls reminder once; one who skips before the wax lesson finds the WAX = TIME chalk on the floor.
- **While it runs the night has not begun**: the wax is held (the clock reads 12:00 AM, practice costs nothing),
  the doors stay shut, the pickup magnet rests, other hints wait (the HUD holds them and shows them after), the
  play time does not count. It uses no seeded RNG and changes nothing in the house: the dummy and the drips are
  pictures, not lodgers or pickups (no kills, no drops, no Kindling, no records).
- **Live device**: every picture is drawn each frame for `Controls.device`, so picking up a pad mid-step switches
  the drawing; rebinds show (the key is `Controls.bound_glyph`). **Swap sticks** mirrors the thumbs (and the plates
  follow the HUD's buttons to the left). **Reduce motion**: nothing glides (the thumb and sticks step between two
  places, the keys press at a slower beat, no drop-in, no bolt flight, half the hand-off pauses, no fades).
- **When**: a slot's first run (`Game.records` "runs" 1) until done or skipped (`Game.records["primer"]`
  "started" / "done" / "skipped"; `"primer_taught"` lists the steps). Never in Tonight's Candle, a typed-in seed, a
  floor past the first, a returning slot or a test run (`--primer` forces it; the play-test bot then plays it via
  `Primer.bot_drive`). A Save & quit in the middle shows it again on Continue (the snapshot is the floor's start).
- Pictures: `python3 tools/art_primer.py [--review DIR]` -> `assets/art/primer/` (thumb, ivory keycap + pressed
  gold keycap nine-patches, a gamepad with stick caps and lit bumper / trigger overlays, a mouse, the dummy's three
  sway frames + hit flash); every pixel checked against the 0x72 sheet, 1 px #21141b outline. Drawing code shared
  with the replay: `scripts/ui/primer_glyphs.gd` (`PrimerGlyphs`).

## Told once: the hint rules, before -> after

| Teaching moment | 2.6 | 2.7 |
|---|---|---|
| Story card (`world._intro`) | story + wax lines + the controls line | the story alone when the primer runs (the rules lines stay for a first run without one: Tonight's Candle or a seed) |
| Controls hint after Begin | 8 s, every first run | only without a primer, and once per slot (`Game.tip("controls")`) |
| Floor-1 controls hint | runs 2 and 3 | once per slot, never over the primer; the primer spends it |
| Chalk drawings | 6 on every floor-1 start room (controls, keepsake, special, wax = time) | **one** (WAX = TIME), only for a player who skipped the primer before its wax lesson (`Primer.chalk_wanted`); a taught player's floor is clean |
| Ghost sticks (touch, runs 1-3) | shown | hidden while the primer draws its thumbs there, then as before (a passive affordance, not a text) |
| Special move hint at the first fight | each candle's first 2 runs | once per candle per slot; the primer spends Tallow's |
| Spill hint ("Your wax spilled!...") | 2 per slot | once; the primer's wax lesson spends it |
| Treasure "Choose one relic..." | every treasure room | once per slot |
| Omen explanation | every omen, every floor | each omen once per slot (the floor banner still names it) |
| "<keepsake> is ready" | every charge | once per slot (then the lit button and the tick) |
| Every other `Game.tip` hint (keepsake, Kindling, marked foe, special rooms, lodgers, the Kitchen / Library / Attic gimmicks, relics) | 2 per slot | 1 per slot (`Game.tip` default) |
| Stove Door / Blowlamp | "Hold the right thumb..." on every device | "Keep firing to stoke it" / "Keep firing: a jet of flame" (right for keys and pads too) |

Rule of thumb for new hints: call `Game.tip("<key>")` (once per slot) and show it when the thing first happens; if the
primer teaches it, spend it in `Primer._finish` (`Primer._spend("<key>")`).

## Replay: How to play (`scripts/ui/primer_reel.gd`, `PrimerReel`)

The pause menu's first row gained **How to play** (Journal | Map | Settings | How to play); the Journal's Records >
How to play keeps the goal line and gets **Show me**. Both open the same modal: a little stage where the candle walks,
fires at the dummy, loses four minutes to a bolt and walks over the two drips (a mini clock + bar: 12:00 -> 12:04 ->
12:00), drops a bomb and steps back, and uses its move; the device's controls drawn beside it exactly as in the primer
(live device, Swap sticks, rebinds), the step's name and line under it (`Primer.texts`, the same words), five pips,
< Close >. It turns its pages every 3.6 s; < > and LB / RB (Q / E) choose; Back / Esc closes it first. A picture, not a
practice room: nothing in a run changes (a practice room would need guards in the world's save and records paths).

## AFTER numbers (`--primercheck`, seed 2701, the same house as BEFORE)

| Device | Light the wick -> first kill | of which the primer | Words before the first kill (reading) | Teaching texts in 3:00 | Repeats |
|---|---|---|---|---|---|
| touch | 36.9 s (was 18.6) | 17.6 s | 98 (~30 s; was 120) | 11 (was 18) | **0** (was 8) |
| keys | 33.8 s (was 17.3) | 13.0 s | 98 (was 115) | 10 (was 16) | **0** (was 6) |
| gamepad | 31.6 s (was 17.4) | 12.9 s | 98 (was 114) | 13 (was 17) | **0** (was 6) |

The simulated player reacts 0.8 s after each step appears and then does it at once, so the primer's seconds are a
quick player's; a first-time player who watches each animation for a couple of seconds and reads its line takes
about 35-45 s. The first kill comes later than in 2.6 because the controls are shown and tried first (that is the
request), while the reading load before it dropped by a fifth and nothing is told twice. Every teaching text of the
first three minutes is in the judge's log with what it teaches (AFTER, touch: the five primer steps, then just in
time: treasure, cracked wall, music box, omen, marked foe, Kindling).

Other judge lines (all PASS): the primer completes with simulated input on touch (fingers through the HUD's own
touch handling), keys and a gamepad (sticks and buttons through `Input`), the doors open and the clock still reads
12:00 AM at its end; Skip by a tap (0 frames), Enter (1 frame) and the pad's Back (1 frame), the doors open, the slot
remembers it, the next run in that slot has none; no primer for a returning slot, Tonight's Candle or a typed-in
seed; Swap sticks draws the move thumb on the right and plays through; Reduce motion plays through faster (15.3 s
against 17.6 s); the play-test bot plays a forced primer through and reaches its first kill (24 game s).
