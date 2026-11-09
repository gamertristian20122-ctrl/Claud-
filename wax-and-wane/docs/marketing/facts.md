# Wax & Wane: fact sheet

The one list every store text, the press kit and the trailer cards are checked against. The first part
is written by `python3 tools/make_facts.py` from the game's own code (do not edit it by hand: re-run the
script after any content change; `--check` tells you if it is out of date). Game version in the code:
**2.3.0** (the store release is 2.0.0).

## From the code

| Fact | Value | Read from |
|---|---|---|
| The candle | 120 wax = 12:00 AM to 2:00 AM; one minute of wax is one minute on the clock | `world.gd`, `candles.gd` |
| A full candle lasts | **8 minutes** of real time if you are never hit | `world.DRAIN_PER_SEC` = 120 / (8 x 60) |
| Floors | **4**: The Cellar, The Crypt, The Chapel, The Belfry, plus a secret fifth floor, **The Clock Tower** | `world.FLOORS` |
| The secret floor opens | if the Belfry's guardian falls by **1:00 AM** (you arrive with +5 minutes of wax) | `Tower.UNLOCK_CLOCK`, `ARRIVAL_WAX` |
| Kindling | kills less than 2.2 s apart chain; x3 gives +1 min, x5 gives +2 min | `world._kindle` |
| Spilled Wax | 30% of the wax a hit melts splashes out as warm drops that cool after 2.5 s | `world.gd`, `pickup.gd` |
| Rooms per floor | 8 / 10 / 12 / 14 (with the start, shop, treasure and boss rooms), plus a hidden Hollow and any special rooms | `floor_gen.gd` |
| Hand-made room layouts | **69** | `RoomTemplates.NORMAL` |
| Lodgers (creatures) | **42**: 20 from 0x72's DungeonTileset II, 22 made for this game (2 of them only in the Clock Tower, 7 only in the Long Night's new areas) | `Enemy.DEFS` |
| Guardians (bosses) | **16**: 12 on the four floors (three per floor, picked by the run seed), 3 in the Long Night's new areas (The Stockpot, The Head Librarian, The Dressmaker's Form) + a secret one, The Keeper of Hours. 3 use 0x72 sprites, 13 were made for this game | `Enemy.DEFS`, `world.FLOORS`, `Areas.LIST` |
| House champions (mini-bosses) | **6**: The Great Sootling, The Bone Landlord, The Kitchen Devil, The Rafter King, The Deathwatch Queen, The Icebox Giant | `Specials.MINIS` |
| Relics | **64** in 5 quality tiers; 18 of them move into the house as you earn achievements | `Items.RELICS`, `Unlocks.TABLE` |
| Candle Rites (set bonuses) | **6**: Hearth, Clock, Moth, Many Wicks, Household, Seance | `Items.RITES` |
| Keepsakes (charged items) | **8**: Hand Bell, Flare Match, Winding Key, Smoke Jar, Censer, Oil Jug, Music Box, Hand Mirror (2 unlock with achievements) | `Items.KEEPSAKES` |
| Tonics | 8 unlabelled flasks | `Items.TONICS` |
| Candles (playable) | **6** (5 to unlock) | `Candles.LIST` |
| Special moves | **6**, one per candle (its own button): Flare Up (Tallow), Skip (Tea Light), Sparkler (Party Candle), Slam (Altar Pillar), Snuff (Black Taper), Blink (Moonwick) | `Moves.LIST`, `Candles.LIST` |
| Night length | **4 to 7 floors**, picked before a run and kept per save slot (Tonight's Candle is always 4). Each floor past four adds half an hour: a 7-floor night ends at 3:30 AM | `Areas`, `Game.night_minutes` |
| Special rooms | **5**: The Seance, The Cracked Mirror, The Music Box, The Study, The Wax Font | `Specials.INFO` |
| Omens (floor twists) | **4**: Cold Draught, Tallow Moon, Long Night, Smoky Halls | `world.OMENS` |
| Achievements | **61** (13 hidden), shown in the game | `Achievements.LIST` |
| Save slots | **3**, each with its own difficulty level, records, Journal, unlocks, achievements and saved run; settings are shared | `Game.SLOTS` |
| Difficulty levels | **4**: 1 Gentle (melt x0.75, foe damage x0.5, foe health x0.85, drip wax x1.25); 2 Midnight (the game as it was made); 3 Witching Hour (melt x1.1, foe damage x1.2, foe health x1.15, marked foes x1.5); 4 Two O'Clock (melt x1.15, foe damage x1.35, foe health x1.3, marked foes x2, drip wax x0.85). Tonight's Candle always plays level 2 | `world.LEVELS` |
| Music | 13 tracks + 2 original jingles | `assets/licenses/CREDITS_music.txt` |
| Sound effect files | 74 | `assets/audio/sfx/` |
| Builds | Android, Windows Desktop, Linux, Android Play | `export_presets.cfg` |
| Android | package `com.tallow.waxandwane`, min SDK 24, target SDK 36, permissions: vibrate; Auto Backup on | `export_presets.cfg` |
| PC save folder | `%APPDATA%\WaxAndWane` (Windows), `~/.local/share/WaxAndWane` (Linux) | `project.godot` |

### The candles

| Candle | Lit at | Lasts unhurt | Unlock | In the game's words |
|---|---|---|---|---|
| Tallow | 12:00 AM | 8.0 min | from the start | The last candle in the cellar. |
| Tea Light | 12:40 AM | 6.7 min | Reach the Crypt | Lit at 12:40 AM. Small, quick and quick-firing. |
| Party Candle | 12:20 AM | 6.1 min | Reach a x8 Kindling streak | Two flames, thin wax. Starts with a Flare Match. |
| Altar Pillar | 11:45 PM | 7.8 min | Snuff the Chapel's guardian | Starts with 15 spare minutes. Slow, sturdy, hits hard. |
| Black Taper | 12:00 AM | 8.0 min | Win a run | A short, dark light. Foes out in the dark take 50% more damage. |
| Moonwick | 12:12 AM | 7.2 min | Be done by one, then climb | Lit by the moon. Quick and thin; its sparks pass through. |

### The guardians

| Floor | Guardians |
|---|---|
| The Cellar | Old Rot (0x72 sprite), The Wax Mother or The Coal Furnace |
| The Crypt | The Gaoler (0x72 sprite), The Sexton or The Ossuary |
| The Chapel | The Hollow Warden, The Melted Choir or The Organist |
| The Belfry | The Great Pendulum, The Hour Fiend (0x72 sprite) or The Weathercock |
| The Clock Tower | The Keeper of Hours |

### The lodgers

- Made for this game (22): Rose Melt, Melt Drop, Lamp Moth, Iron Snuffer, Grave Light, Sootling, Waxwork Bride, Cinder Rat, Restless Psalter, Clapper Bat, Deathwatch Beetle, Grave Hand, Cog Sentry, Minute-Hand Wraith, Gutterspout, Pot-Lid Crab, Flour Ghost, Bookworm, Inkblot, Ink Drop, Lantern-Shy Mannequin, Snapping Trunk
- From 0x72, renamed and given their own lore (20): Coal-Bin Shambler, Larder Thief, Damp Slug, Cistern Slug, Puddle Lump, Drain Hopper, Flue Imp, Bone Lodger, Harvest Head, Hearth Devil, Rafter Leaper, Green Chanter, Masked Porter, Hooded Mourner, Tincture Doctor, Icebox Corpse, Hungry Chest, Gilt Cherub, Belfry Brute, Potted Sleeper

### Music slots

title: 22 - Dream, floor_1: 40 - Crypt, floor_2: 21 - Dungeon, floor_3: 12 - Temple, floor_4: 24 - Final Area, shop: 39 - Boat, boss: 17 - Fight, final_boss: 28 - Tension, floor_5: 19 - Ascension, ending: 15 - Credit Theme, area_kitchen: 14 - Curse, area_library: 30 - Ruins, area_attic: 16 - Melancholia.

## Checked by hand (not in the code)

| Fact | Value | How it was checked |
|---|---|---|
| Run length | About 6 to 16 minutes: a lost run usually ends in 6 to 11 minutes, a true-ending win takes about 16 | `--playtest` bot, fresh saves (release review, seeds 9101-9104: losses at 5.7, 6.7 and 10.7 min, true-ending win at 16.4 min). People who dodge do better than the bot. Re-measure after balance changes |
| Win rate (bot, fresh save) | About half of the bot's runs win (7 of 12 at the last balance pass) | `--playtest --speed=4`, 12 runs per setting (CLAUDE.md > Balance). Re-measure after balance changes |
| Art made for this game | Tallow and the other 5 candles, the house's own lodgers and guardians (counts above), relics and keepsake icons, costumes, effects, rooms and decor, special rooms, the Clock Tower, chalk drawings, UI, logo, icons | Drawn by Python scripts written with Claude (an AI assistant), `tools/art_*.py`, on the 0x72 palette; every sheet was looked at and kept or redrawn by the developer |
| Art from 0x72 (CC0) | The dungeon tiles, chests, coins, bombs, flasks and the 0x72 lodgers and guardians (counts above) | `assets/0x72/frames/`, `assets/licenses/0x72_DungeonTilesetII_CC0.txt` |
| Music | 10 tracks from the Ninja Adventure Asset Pack by Pixel-boy and AAA (CC0). Not AI | `assets/licenses/CREDITS_music.txt` |
| Jingles | 2 (victory, death): original, synthesized by `tools/make_audio.py` (a script written with Claude) | same file |
| Sound effects | Layered and processed from Kenney packs (CC0), a few Ninja Adventure sounds (CC0), plus original synthesis | `assets/licenses/CREDITS_audio.txt` |
| Fonts | Kenney Pixel and Kenney Mini (CC0) | `assets/licenses/Kenney_Fonts_CC0.txt` |
| Code | Written with Claude (AI coding assistant), directed, played and checked by the developer | git history |
| Trailer narration | AI voice: Kokoro TTS (Kokoro-82M, Apache-2.0, voice am_michael). Only in the trailer and shorts, never in the game | `docs/marketing/voice/` |
| AI while playing | None. Nothing is generated while you play | the game has no network access and no AI model |
| Data collected | None. No ads, analytics, accounts or network access | `PRIVACY.md`; the Android build's only permission is listed above |
| Blood | Cartoon only: creatures burst into small chunks that fade and leave flat coloured splats on the floor; some splats are red (`#9f294e`, `#62232f`, `#da4e38`) | `scripts/game/fx_gibs.gd`, `stains.gd`, `Enemy.DEFS` stain colours |
| Random rewards | Chests, the Music Box (3 in-game coins a crank) and the Wax Font use in-game coins or wax only. No real money anywhere | `scripts/game/specials.gd` |
| Steam features at launch | No Steam achievements or Steam overlay calls yet (GodotSteam is not in the build); the 61 achievements are in-game. Steam Cloud works without code (Auto-Cloud) | `scripts/autoload/achievements.gd` (Steam bridge waits for GodotSteam) |
| Demo | None. There is no demo build; do not promise one | |
| Languages | English only | |

