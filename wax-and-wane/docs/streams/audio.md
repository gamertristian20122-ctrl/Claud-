# Audio stream (Wax & Wane 2.0)

Branch `revamp/audio`. Owns `scripts/autoload/audio.gd`, `assets/audio/`, `tools/make_audio.py`,
`tools/import_audio.py`, `default_bus_layout.tres`, new files in `assets/licenses/`, and the new test
`scripts/audio_check.gd`.

## What changed, in short
1. **Music** — every slot now has a real, produced CC0 track (Ninja Adventure pack), picked by measurement,
   loudness-matched to -16 LUFS, made seamless and set to loop on import. A new **shop** theme.
2. **Dynamic music** — the music opens up in fights, softens (gentle low-pass) once a room is clear, goes
   muffled behind the pause menu, dips under big moments, and resumes where it left off after a shop or a boss.
3. **Low wax** — under 15 minutes of wax a heartbeat + fast clock-tick layer fades in, speeds up as the wick
   runs out and pulls the music back a little.
4. **SFX** — 2-4 takes of every frequent sound (picked at random, never the same twice in a row, with pitch and
   level jitter), 24 new sounds for the other streams, voice priorities so the important sounds are never cut.
5. **Space** — each floor has its own acoustics on world sounds: a small dry cellar, long stone crypt vaults,
   the big chapel, an airy timber belfry.
6. **Mix** — a limiter on the master bus (no clipping, ever), UI / pickups / the hurt sound stay dry and clear,
   the room bus gives way for a moment when Tallow is hurt, big sounds duck the music automatically.

## Music: the track per slot (and why)
We can't listen, so all 45 Ninja Adventure tracks (and the Kenney music loops) were measured with
`python3 tools/import_audio.py analyse <files>`: onset density (notes / hits per second), percussive share,
key + minor-vs-major strength, dissonance, register and dynamic range. The darkest fitting track per slot was
chosen and tension ramps floor by floor by onset density (1.96 -> 2.50 -> 2.72 -> 3.72 /s, boss 3.31, final 4.89).

| Slot | Track (Ninja Adventure, CC0) | Why |
|---|---|---|
| `title` | 22 - Dream (96 s) | Darkest of the slow pieces: low (mean pitch MIDI 61), sparse (2.0 onsets/s), eerie (no settled key), opens quietly and swells |
| `floor_1` Cellar | 40 - Crypt (96 s) | Sparsest dark track, clearest minor (C minor), lowest register of all 45, slow breathing swells — calm but heavy |
| `floor_2` Crypt | 21 - Dungeon (60 s) | A step up in density, the most unsettled harmony (dissonance 0.36), still low and slow |
| `floor_3` Chapel | 12 - Temple (53 s) | Sacred-sounding C# minor, highest register of the dark tracks (choir/organ-like), denser again |
| `floor_4` Belfry | 24 - Final Area (63 s) | Most driven floor track (3.72 onsets/s, percussive 0.25), C minor and dissonant |
| `shop` | 39 - Boat (96 s) | D minor but the most consonant minor track, gentle steady lilt — a safe room that still lives in the house |
| `boss` | 17 - Fight (32 s) | D minor, low, dense and dissonant — a hard switch up from floors 1-3 |
| `final_boss` | 28 - Tension (27 s) | Densest usable track (4.89 onsets/s), one of the two most percussive — the peak |
| `victory_jingle` | original (synth) | Kept: 4.3 s fits the victory banner; built from the game's own bells / music box. The pack's jingles are 1-2 s chiptune stings |
| `death_jingle` | original (synth) | Kept: the music box winding down under the snuff-out, 3.3 s |

The name swap (Cellar plays "Crypt", Crypt plays "Dungeon") is deliberate: it is the order that ramps tension.
The original synthesized loops are still in `tools/make_audio.py`; `make_audio.py music title` renders one to
`art_source/music_synth/` (not exported) for comparison.

Processing (`tools/import_audio.py music`): 25 Hz circular high-pass (one candidate carried heavy DC / sub-sonic
rumble), 4 ms equal-power seam cross-fade (the pack ships exact-length loops: a whole number of beats),
EBU R128 to -16 LUFS with a circular look-ahead limiter for <= -1 dBTP true peak, Ogg Vorbis q4 44.1 kHz stereo,
`loop=true` in the `.import`. Measured result: every loop at -16.0 ±0.1 LUFS, true peak -1.3 to -3.4 dBTP,
seam jump below the 99th-percentile sample step of each track.

**Sizes:** music 6.6 MB (budget 12 MB), SFX 0.97 MB, total audio ≈ 7.6 MB.

## API (`Audio` autoload)
Unchanged for existing callers: `Audio.play(name, volume_db := 0.0, pitch_jitter := 0.06, pitch := 1.0)`,
`Audio.music(name, fade := 1.2)`, `Audio.jingle(name)`. Unknown names are skipped silently (only
`--verbose` prints a note), so it is always safe to call a sound that may not exist yet.

New:
| Call | What it does |
|---|---|
| `Audio.enter_room(type, cleared)` | Shop music in a shop, back to the floor track (resumed) elsewhere; full mix in a fight, calm mix in a cleared room |
| `Audio.set_intensity(x)` | 1 = fight (open), 0.5 = cleared (low-pass 4.8 kHz, -2 dB), 0 = muffled (420 Hz, -7 dB); smooth |
| `Audio.set_paused(on)` | Pause menu: strong low-pass + dip; clears itself when the tree unpauses |
| `Audio.duck(db, secs)` | Dip the music by `db` (negative) for `secs`, then recover over 0.5 s; deepest duck wins |
| `Audio.set_low_wax(on, frac)` | Heartbeat + ticks layer; `frac` = wax left / threshold (faster, louder as it falls). Call every frame; it fades out if not refreshed for 1.5 s |
| `Audio.set_space(floor_num)` | Per-floor reverb on world sounds (0 = none; title resets it) |
| `Audio.loop_start(name, follow := null, volume_db := 0.0, pitch := 1.0) -> int` | Start a looping sound (`beam_loop`); stops by itself when `follow` is freed |
| `Audio.loop_stop(id, fade := 0.15)` | Stop it |
| `Audio.has_sound(name) -> bool` | True if the sound exists (for fallbacks) |

Automatic behaviour (no calls needed): boss music starts with `boss_sting`; `boss_roar`, `boss_die`,
`boss_sting`, `explosion`, `bell_toll`, `item_get`, `relic_fanfare`, `achievement`, `door_burst`,
`jar_explode`, `thud_heavy` and `player_hurt` duck the music; `player_hurt` also dips the room bus 4 dB for
0.25 s so it cuts through; the low-wax layer replaces the old `low_wax` one-shot heartbeat while it is on;
music jingles and the title reset the whole mix (intensity, ducks, low wax, resume positions, loops, space).

### Hooks added to `world.gd` (one line each)
- `_start_floor`: `Audio.set_space(n)` after `Audio.music(...)`
- `_on_enter_room`: `Audio.enter_room(d["type"], d["cleared"])` (top of the function)
- `_clear_room`: `Audio.set_intensity(0.5)` after `Audio.play("room_clear")`
- `_clock_events`: `Audio.set_low_wax(player.wax < 15.0 and not player.dead, player.wax / 15.0)`
- `toggle_pause`: `Audio.set_paused(paused)` after `get_tree().paused = paused`

## Sound names
Takes: `shoot` (3), `hit_wall` (3), `hit_enemy` (3), `enemy_die` (3), `step` (4), `coin_pickup` (3), `splash`
(3). Files are `<name>.ogg`, `<name>_2.ogg`, `<name>_3.ogg` ...: just call `Audio.play("<name>")`.

Existing (v1.1): `shoot hit_wall hit_enemy enemy_die enemy_shoot player_hurt wax_pickup coin_pickup bomb_pickup
bomb_place explosion door_open door_close room_clear item_get chest_open urn_break crate_break boss_roar
boss_die bell_toll tick ui_click ui_back ui_open low_wax snuff_out victory shop_buy step charge teleport splash
trapdoor`.

New in 2.0 (for the other streams):
| Name | Length | Use it for |
|---|---|---|
| `boss_sting` | 2.6 s | Boss reveal stab (already automatic when boss music starts) |
| `match_strike` | 0.7 s | Lighting a match / candelabra / the Flare Match keepsake |
| `burn_whoosh` | 0.6 s | A gout of flame, fire attacks, burning relics |
| `splat` | 0.4 s | A wet glob landing (wax, slime, blood-free gore) |
| `gib` | 0.6 s | A creature bursting apart (big kills, champions) |
| `sizzle` | 0.75 s | Hot wax on stone, burning floor, a doused ember |
| `relic_fanfare` | 2.6 s | Picking up a relic (bigger than `item_get`) |
| `achievement` | 1.4 s | Unlocks, journal entries, records |
| `ui_move` | 0.02 s | Menu focus moving (gamepad / keyboard) |
| `door_burst` | 0.9 s | A door forced open, secret walls bursting |
| `fire_crackle` | 1.4 s | Short fire bed (braziers); fades in and out so it can be retriggered |
| `jar_explode` | 0.9 s | Thrown flasks / jars bursting |
| `web` | 0.5 s | Sticky webs (snare, slow) |
| `page_flip` | 0.4 s | Journal / bestiary pages |
| `bell_small` | 1.8 s | A hand bell (Hand Bell keepsake, small bell enemies) |
| `clock_tick_fast` | 0.2 s | Urgent tick-tock (countdowns, Pocket Watch) |
| `moth_flutter` | 0.5 s | Moths, wings, the Moth Friend |
| `wax_bubble` | 0.6 s | Molten wax bubbling (puddles, wax enemies) |
| `thud_heavy` | 0.5 s | Heavy landings (big monsters, falling stone, leapers) |
| `summon` | 1.4 s | Dark summoning (summoners, necromancers, spawns) |
| `beam_loop` | 1.0 s loop | Sustained fire beam — use `Audio.loop_start("beam_loop", self)` / `loop_stop(id)` |
| `charge_up` | 0.95 s | Long wind-up telegraph before a big attack (ends on a click) |
| `dodge` | 0.3 s | Dash / dodge / quick step aside |
| `unlock` | 1.2 s | A lock giving way: chests, doors, candle unlocks |

Internal: `low_wax_loop` (the low-wax layer; loops).

Levels: every file is loudness-matched by `make_audio.py` (phone-weighted max-100 ms RMS targets: UI -19..-22,
steps -21, most SFX -14..-16, big events -10..-12); `audio.gd` `VOLUME` holds the in-game trim per name.

## Buses (`default_bus_layout.tres`)
`Master` (HardLimiter -0.5 dB) <- `Music` (player volume + LowPassFilter, 12 dB/oct) <- `Score` (music players;
intensity + ducks) and `SFX` (player volume; dry sounds + low-wax layer) <- `Room` (world sounds; Reverb per
floor). `Game.apply_settings()` still sets only `Music` and `SFX`, so the player's sliders keep working.

Reverb per floor (room size / damping / wet / pre-delay): Cellar 0.28 / 0.75 / 0.07 / 12 ms, Crypt 0.82 / 0.42 /
0.19 / 34 ms, Chapel 0.90 / 0.28 / 0.22 / 48 ms, Belfry 0.70 / 0.12 / 0.15 / 26 ms (bright, high-passed).

## Tests
- `godot --headless --path . -- --autotest --audiotest` (new, `scripts/audio_check.gd`): every sound name and
  music slot exists, takes counted, loops set on import, unknown names silent, then the live mix through the real
  `world.gd` hooks (start room calm, clear, pause / unpause, low wax on / off via the player's wax, shop and
  resume, boss sting, an SFX burst, the four spaces, every sound once, a loop, the death jingle reset).
  Prints `[audio] PASS/FAIL` lines; exit code 1 on any failure.
- Record it and measure the real output:
  `xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 384x216 --write-movie /abs/mix.avi -- --autotest --audiotest > /abs/run.log`
  then `python3 tools/import_audio.py mixcheck /abs/mix.avi /abs/run.log` — checks clipping, the intensity /
  pause low-pass order, the duck depth, the low-wax layer and the per-floor reverb decay order.

## Credits (for the integrator to merge into README.md)
- Music: **Ninja Adventure Asset Pack** by Pixel-boy and AAA (CC0) — `assets/licenses/Ninja_Adventure_CC0.txt`,
  track per slot in `assets/licenses/CREDITS_music.txt`. Jingles: original, synthesized for this game.
- Sound effects: **Kenney** audio packs (CC0) + a few **Ninja Adventure** sounds (fire, wings, bubbles, CC0) +
  original synthesis — per file in `assets/licenses/CREDITS_audio.txt`.
- The in-game Credits lines in `scripts/ui/title.gd` were updated (2 lines) to match.

## Re-running the pipeline
```
python3 tools/import_audio.py fetch      # download sources once (cache: ~/.cache/wax_and_wane_audio)
python3 tools/import_audio.py music      # build the licensed music slots + CREDITS_music.txt
python3 tools/make_audio.py sfx          # all SFX (+ takes, new sounds, loops) + CREDITS_audio.txt
python3 tools/make_audio.py music        # the two synthesized jingles
python3 tools/import_audio.py report     # loudness / true peak / seam / size of every music file
godot --headless --path . --import
```
Re-encoding gives byte-different but sample-identical Ogg files (new stream serials); only commit files whose
recipe changed.
