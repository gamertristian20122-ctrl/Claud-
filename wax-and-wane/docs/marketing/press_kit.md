# Wax & Wane press kit

> **OWNER ONLY: fill these in before you publish (nothing else on this page needs editing)**
> - Developer name: `________` (your name or a studio name)
> - Based in (country): `________`
> - Press contact email: `________`
> - Prices: Steam `________` (recommended $5.99), itch.io `________` (recommended $4.99), Google Play `________` (recommended $2.99)

Host this page on your itch.io site (a second, free itch page called "Wax & Wane press kit" works) and link
it from every email. The downloadable zip is made by `./tools/press_kit.sh` (section "Downloadable assets").
Every number here matches `facts.md`.

---

## Fact sheet

| | |
|---|---|
| Game | Wax & Wane |
| Developer | One developer, working with Claude (an AI assistant) |
| Genre | Twin-stick roguelite, room to room |
| Players | Single-player |
| Platforms | Windows, Linux / SteamOS, Android |
| Release | itch.io: out now (2.0.0). Google Play: after Google's 14-day closed test. Steam: Coming Soon page first |
| Price | One price, no ads, no in-app purchases (prices in the owner block above) |
| Languages | English |
| Engine | Godot 4.7 |
| Controls | Keyboard and mouse, gamepad, touch (two thumbs) |
| Data | Collects nothing; works offline |
| Links | itch.io page, Google Play page and Steam page as each goes live; trailer on YouTube |

---

## Short description (one paragraph, for news posts)

Wax & Wane is a twin-stick roguelite where your health bar is a burning candle. You play Tallow, a small living
candle in a haunted house at midnight. Your wax is your health and your clock: it burns from 12:00 to 2:00 AM,
every hit melts it faster, and kills buy minutes back. Fight room to room through four floors, snuff the
Belfry's guardian before the clock strikes two, and finish by 1:00 AM to find the secret fifth floor.

## Longer description

Tallow is the last candle burning in the cellar of an old house. When the house wakes at midnight, the wax on
Tallow's back is everything. The candle in the corner of the screen counts from 12:00 AM to 2:00 AM, and it's the
same wax that keeps you alive. A full candle lasts eight minutes if nothing touches you. Hits melt more. Kills,
cleared rooms and wax drippings buy time back. As the wax goes, Tallow gets shorter and the circle of light
shrinks with it.

Each run rebuilds four floors from 69 hand-made rooms: the Cellar, the Crypt, the Chapel and the Belfry. 64 relics
stack into builds, three relics from the same Candle Rite unlock a set bonus, and the Smoke Altar sells power for
minutes cut off your candle for the rest of the night. Be done with the Belfry by 1:00 AM and a ladder of light
leads to the Clock Tower, the Keeper of Hours and the true ending. Six candles to play, five special rooms, a
secret Hollow on every floor, a nightly seeded run (Tonight's Candle) and a Journal of everything you've met give
reasons to come back.

---

## Features

- **The candle is the clock.** One bar is your health and your timer, and you can read it from Tallow's height and the size of your light.
- **64 relics** that stack: Twin Wick, Sharp Wick and Ember Heart together fire two piercing flames that set everything alight.
- **6 Candle Rites** (set bonuses), **8 keepsakes** (charged items such as the Hand Bell and the Winding Key) and the **Smoke Altar** (power for minutes).
- **35 kinds of lodger**, marked foes that pay out wax, coins or bombs, and omens that twist each floor.
- **13 guardians** with versus cards (three per floor, picked by the run's seed, plus the secret Keeper of Hours) and **6 house champions**.
- **5 special rooms**: the Seance, the Cracked Mirror, the Music Box, the Study and the Wax Font.
- **6 candles**: Tallow, Tea Light, Party Candle, Altar Pillar, the Black Taper (a short light, but foes in the dark take more damage) and the secret Moonwick.
- **3 save slots, 4 difficulty levels**: every slot keeps its own level (1 Gentle, 2 Midnight, 3 Witching Hour, 4 Two O'Clock), Journal and unlocks.
- **Tonight's Candle**: one seeded house a night, the same for every player. Typed-in seeds too.
- **The Journal** and **67 achievements** (in the game).
- **Save and continue**, keyboard and mouse, gamepad and touch.

---

## History

- **Autumn 2026, 1.0:** made as an Android phone game with touch controls.
- **November 2026, 1.1:** Kindling streaks, Spilled Wax, marked foes, the Smoke Altar and Vigil, keepsakes, Candle Rites, the Candle Box, omens, secret Hollows and Tonight's Candle.
- **2.0.0:** the full version for PC and phones: 64 relics, 35 lodgers, 9 guardians, 6 house champions, 5 special rooms, the Clock Tower and its true ending, the Journal and achievements, decorated and lit rooms, stains and screen feedback, gamepad and keyboard-and-mouse support, save and continue, and Windows and Linux builds.

---

## Team and how it was made

**One developer**: design, direction, testing and every decision.

Wax & Wane was built with Claude, an AI assistant. Under the developer's direction it wrote the game's code and
in-game text, and the small programs that draw the original pixel art (Tallow, the house's own creatures and
guardians, relic icons, rooms and effects). The developer chose the ideas, played every build and checked every
picture, keeping, changing or throwing out each one. The trailer's narrator is an AI voice (Kokoro TTS).
Nothing is generated by AI while you play.

**Third-party assets (all free and public domain, CC0, unless noted):**
- Dungeon tiles, chests, coins, bombs, flasks and about 20 creatures: 0x72, "16x16 DungeonTileset II" (CC0)
- Music: the Ninja Adventure Asset Pack by Pixel-boy and AAA (CC0), 10 tracks
- Sound effects: layered and processed from Kenney's Foley, Impact, Interface, RPG Audio and Retro packs, plus a few Ninja Adventure sounds (all CC0), and original synthesis
- Fonts: Kenney Pixel and Kenney Mini (CC0)
- Engine: Godot Engine (MIT)
- Trailer narration voice: Kokoro TTS, Kokoro-82M by hexgrad (Apache-2.0); not in the game

---

## Videos and streaming

You may stream, record and monetise videos of Wax & Wane on any platform. You don't need to ask.

---

## Quotes

None yet. Add real quotes from press, streamers or players here, each with a link to where it was said.

---

## Downloadable assets

One command makes the zip from the current store art:

```
./tools/press_kit.sh        # -> build/WaxAndWane_presskit_2.0.0.zip
```

| In the zip | Size | From |
|---|---|---|
| `logo/logo_1280x720.png`, `logo/logo_640x360.png` | transparent | `store_assets/press/` |
| `logo/logo_wide_1280x246.png` | transparent | `store_assets/steam/library_logo_1280x246.png` |
| `icon/icon_512.png` | 512 x 512 | `docs/marketing/icons/google_play_512.png` |
| `key_art/key_art_1920x1080.png`, `key_art/key_art_3840x2160.png` | 16:9, no logo | `store_assets/press/` |
| `key_art/key_art_logo_1920x1080.png` | 16:9, with logo | `store_assets/press/` |
| `key_art/key_art_landscape_1232x706.png` | 1232 x 706 | the Steam main capsule |
| `key_art/key_art_portrait_748x896.png` | 748 x 896 | the Steam vertical capsule |
| `screenshots/01_...` to `10_...` | 1920 x 1080 | `store_assets/screenshots/` |
| `screenshots/phone_01_...` to `phone_06_...` | 1920 x 1080 | the touch-screen set (`store_assets/google_play/phone16x9_*`) |
| `gif/loop_fight.gif` | 384 x 216, 6.5 s | `build/videos/` (only if the trailer has been made) |
| `tallow/tallow_states_x6.png` | Tallow in every state, x6 | `--herosheet` render (only if Godot can run on the machine) |
| `press_kit.md`, `facts.md`, `LICENSE.txt` | text | this page, the fact sheet, the game's licence |

The trailer is not in the zip (47 MB): link the YouTube trailer instead, and offer `trailer_60s.mp4` on request.
