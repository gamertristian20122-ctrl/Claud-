# Wax & Wane: roadmap after the Long Night (v2.3 to v2.7)

The owner locked this queue on 2026-11-09. It starts as soon as the current work is merged:
v2.1 (3 save slots with difficulty 1-4, the Black Taper sidegrade, 4 new guardians, easier-to-see enemy shots)
and v2.2 batch 1 (the Kitchen, Library and Attic, plus the night-length slider, `LONG_NIGHT.md`).

| Step | Version | What | Streams (at most 2-3 agents at a time) |
|---|---|---|---|
| 1 | 2.3 | Special moves for every candle + an ability button | `moves` (+ `strings` groundwork, see 4a) |
| 2 | 2.4 | Ten Challenge Nights with relic and cosmetic rewards | `challenges`, `rewards-art` |
| 3 | 2.5 | Diary pages, the story of the house, alternate endings | `story` (writing), `diary` (code + art) |
| 4 | 2.6 | Translations: ES, PT-BR, FR, DE, Simplified Chinese | `strings` (4a early), `translate` (4b) |
| 5 | 2.7 | Boss Rush (after 5 wins), timed gauntlet of every guardian | `bossrush` |
| side | 2.4-2.5 | Long Night batch 2: Conservatory, Ballroom, Gallery (slider to 10) | `areas2` (`LONG_NIGHT.md`) |

Rules that hold for every step (CLAUDE.md has the full list): original names and art only, 0x72 palette style,
wax = health = clock stays readable, runs stay deterministic from the seed, every change has an outside judge
(a test, a measurement or a screenshot looked at zoomed), commit after every finished piece, and **no videos**.

---

## 1. Special moves for each candle (v2.3, first)

Goal: every candle plays like a different character, not a different set of numbers.

### The moves
| Candle | Move | What it does | Starting numbers (tune with the bot) |
|---|---|---|---|
| Tea Light | **Skip** | A quick dash in the move direction (aim direction if standing still) with brief invulnerability; leaves a short trail of sparks | 48 px in 0.12 s, invulnerable 0.3 s, cooldown 2.5 s |
| Party Candle | **Sparkler** | A burst of 12 sparks all around: damage, knockback, and it pops enemy shots in its radius | radius 44 px, 2x shot damage per spark, cooldown 8 s |
| Altar Pillar | **Slam** | A short wind-up, then a ground slam: a shockwave ring that damages and **stuns** lodgers nearby (guardians are slowed instead); cracks weak obstacles | wind-up 0.25 s, radius 40 px, stun 1.2 s, cooldown 9 s |
| Moonwick | **Blink** | Teleport a short way in the move/aim direction, through pits, spikes, cobwebs, hearths and one-tile obstacles (never through walls or closed doors); lands on the nearest free spot | 56 px, invulnerable 0.2 s on arrival, cooldown 4 s |
| Tallow | **Flare Up** | Burn 2 minutes of your own wax to blaze for 3 s: a bigger light, shots deal 1.5x and set foes alight, and a ring of heat burns lodgers that touch you. The game's whole idea in one button: spend time for power | costs 2 min of wax, lasts 3 s, cooldown 10 s; refused below 5 min of wax |
| Black Taper | **Snuff** | Put your own flame out for 2 s: lodgers lose track of you (they wander to where you were), you move a little faster, and the first shot after relighting is a black-flame critical hit that pierces | 2 s dark, +15% speed, next shot 3x damage + pierce 3, cooldown 9 s |

### Architecture
- `scripts/game/moves.gd` (class `Moves`): the move table (id, name, one-line text, cooldown, wax cost,
  icon) and `Moves.use(player, world)`; each move is one small function plus its juice. `Candles.LIST`
  gets a `move` key per candle (the Journal's Candles tab and the Candle Box show it).
- `Player`: `move_cd` (seconds left), `move_ready()`, `use_move()`; the cooldown ticks in physics; a move never
  fires during the hold-aloft pose, the boss card, the melt-down or a pause.
- Input: a new `special` action in `Controls` - keyboard **Left Shift** (Shift leaves the keepsake, which keeps
  **Q**), mouse **thumb button / F**, gamepad **LT** (the keepsake keeps **LB**; the bomb keeps **RB/RT**).
  `Controls.glyph("special")`, the hints and the chalk start room learn the new button.
- **Mobile**: a third round button on the right edge, beside bomb and keepsake: the biggest of the three
  (move icon + a stepped cooldown ring + a bright flash when ready), 38 px hit area like the others, laid out so
  the right thumb reaches all three without leaving the aim area for long. Swap sticks mirrors it. Check with
  the `--fit` layout checker at 480x216, 384x240 and 384x216, and measure thumb reach (centre distances).
- Feel (game-feel skill): every move needs its own sound (existing names in `docs/streams/audio.md`: dodge,
  charge_up, thud_heavy, sizzle, burn_whoosh...), a hit-stop or shake in proportion, and a readable shape at 1x.
- Relic hooks for later synergies: `RelicFx.on_move(player, id)`.
- The autotest bot uses each move with a simple rule (dash or blink away from a projectile about to hit,
  slam/sparkler when 3+ lodgers are close, flare/snuff on guardians) so balance runs include the moves.
- Achievements: one per move ("use it 50 times", or a move-specific feat like "Blink over 3 pits in one room").

### Judges
- Bot win rate per candle at difficulty 2, 8 fresh-seed runs each: every candle within +-15% of Tallow.
- Frame timing: the move fires on the next physics frame after the press (as the design pass measured for shots).
- Mobile layout: `--fit` clean, all three right-hand buttons inside the safe area and reachable.

---

## 2. Challenge Nights (v2.4, second)

Ten special runs with twisted rules, unlocked one by one, each paying a reward the first time it is beaten.
They always play at difficulty 2 and 4 floors (fair to compare), and are recorded in the active save slot.

| # | Challenge | Candle | Rule | Unlocks after | Reward |
|---|---|---|---|---|---|
| 1 | **Glass Wick** (the owner's "Paper Lantern"; renamed because Paper Lantern is already a relic) | any | Any hit puts you out. You start with 30 extra minutes | first win | new relic |
| 2 | **Blackout** | any | Your light is tiny and there are no wall lights; lanterns are rare | Glass Wick | cosmetic: moonlit holder |
| 3 | **Bombs Only** | any | You cannot shoot. 10 bombs to start, bombs drop three times as often, blasts are bigger | Blackout | new relic |
| 4 | **Fast Clock** | any | The candle melts twice as fast; wax drops count double | a win before 1:00 AM | cosmetic: brass hourglass dish |
| 5 | **Skipping Stone** | Tea Light | Shots are weak; Skip dashes through lodgers and burns them | Tea Light unlocked | new relic |
| 6 | **Last Dance** | Party Candle | Every normal room is a Seance wave; Sparkler recharges twice as fast | Party Candle unlocked | cosmetic: confetti flame |
| 7 | **Heavy Night** | Altar Pillar | You move slowly, lodgers have 1.5x health, Slam stuns twice as long | Pillar unlocked | new relic |
| 8 | **Between Moons** | Moonwick | Rooms are full of pits and spikes; Blink recharges faster | Moonwick unlocked | cosmetic: silver crescent holder |
| 9 | **The Long Burn** | Tallow | No wax drops at all; only kills, clears and Flare Up's fire keep you going | 3 wins | new relic |
| 10 | **Lights Out** | Black Taper | Lodgers outside your light are invisible; Snuff lasts twice as long | Black Taper unlocked | cosmetic: ember-red flame |

### Architecture
- `scripts/game/challenges.gd` (class `Challenges`): the table above (id, name, candle, rules dictionary,
  unlock rule, reward) and one accessor, `Challenges.mod(world, key, default)`, read at the few decision points
  (melt multiplier, light radius, can_shoot, one-hit rule, drop multipliers, room-type override, move
  cooldown/strength, start kit). No scattered `if challenge == ...` checks.
- `world.challenge` (id or ""), saved by Save & Continue; seeds stay deterministic.
- Menu: a **Challenges** button on the slot screen: a list with lock icons, the rule in one line, the reward,
  and a gold mark when beaten. The results screen says CHALLENGE COMPLETE and shows the reward.
- Rewards: 5 new relics (art in the relic icon style, effects in `relic_fx.gd`, entered in `Unlocks.TABLE`)
  and a small **cosmetics** system (`scripts/game/cosmetics.gd`): holder (dish) styles and flame tints per
  candle, picked in the Candle Box, visual only.
- Achievements: each challenge, all ten.

### Judges
- Every challenge beaten at least once by the bot with a suitable kit (or a scripted test) and lost by a weak
  kit: none is impossible, none is free. No script errors across 3 runs each. Tours of the menu at 3 sizes.

---

## 3. Diary pages (v2.5, third)

Torn diary pages tell the story of the house, of midnight, and of Tallow, and unlock alternate endings.

- **Story first**: a short story bible in `docs/design/STORY.md` (who kept the house, why it wakes at midnight,
  what the Keeper of Hours is, who lit Tallow and why). The owner reads and approves it before the pages are
  written. Original, warm and a little sad, in the game's voice.
- **24 pages** (`scripts/game/diary.gd`: id, title, text, optional 64x48 pixel illustration, where it can turn
  up). Where: hollows (secret rooms), rare drops from marked foes and champions, the Study, guardians' first
  defeats, challenge rewards, and one in each new area. Seeded, so a run's pages are the same for everyone with
  that seed; never a duplicate of a page already found in that slot.
- Pickup kind `page` (a small fluttering sprite + `page_flip` sound), a short reading card when picked up
  (skippable, never during a fight), and a **Diary** tab in the Journal with the pages in story order and "???"
  for missing ones.
- **Alternate endings** (`scripts/ui/ending.gd` gets new scene sets): for example 12 pages -> "The Housekeeper"
  ending after a win; all 24 -> the true story ending after the Keeper; a 10-floor night won at dawn -> "First
  Light". Each ending has its own 3-4 cards and credits.
- Achievements: first page, half the diary, the whole diary, each ending.

### Judges
- Every page reachable (a test that lists where each page can drop and proves each source exists in the game);
  pages never repeat in a slot; reading cards never block combat; endings reachable with test flags.

---

## 4. Localization (v2.6, fourth)

Languages: **Spanish (es)**, **Brazilian Portuguese (pt_BR)**, **French (fr)**, **German (de)**, **Simplified
Chinese (zh_CN)**. English stays the source.

### 4a. Groundwork, done early (alongside step 1)
Every new string added in steps 1-3 should already go through the string system, so the translation step does
not have to dig them out later.
- `scripts/autoload/i18n.gd` (autoload `L`): loads `lang/<code>.json` (flat key -> text, with `{name}` style
  placeholders), registers them with Godot's `TranslationServer` so `tr()` and auto-translated Labels work, and
  offers `L.t(key, args := {})` for formatted text. English source strings are the keys (gettext style), so code
  changes stay small: `UI.label(L.t("Light the wick"))`.
- `tools/extract_strings.py`: scans the scripts and the data tables (relic names and texts, lodger lore,
  guardian titles, special rooms, achievements, candles, challenges, diary) and writes `lang/en.json`; it fails
  if a visible string is not wrapped.

### 4b. Translations
- Five `lang/<code>.json` files, translated with care for tone (the dry, warm, slightly spooky voice), short
  enough for the 384x216 UI. Marked as machine-translated in a header so a native speaker can review them before
  a big launch in that language.
- Fonts: Kenney Pixel has no accents, so add an OFL/CC0 pixel font with Latin Extended (for é ã ç ü ß ñ) and an
  OFL pixel font with Simplified Chinese at a size that stays readable at 384x216 (10-12 px, e.g. Fusion Pixel
  Font or Ark Pixel Font, both OFL; check the licence file). Record both in the credits and `assets/licenses/`.
- Settings: a Language row (auto-detects the phone's/PC's language the first time).
- Layout: a pseudo-locale (every string 35% longer with accents) run through all tours with `--fit`, then every
  real language; German and Chinese are the usual troublemakers.
- Store pages: translated short and long descriptions for Steam and Google Play
  (`docs/marketing/translations/`).

### Judges
- `--fit` clean in all six languages on every tour; `extract_strings.py` finds no unwrapped visible string; a
  native-speaker review list for the owner.

---

## 5. Boss Rush (v2.7, fifth)

- Unlocked per save slot after **5 wins**; a **Boss Rush** button on the slot screen.
- Every floor guardian in order of depth (the four first floors, the new areas, then the Belfry's three), with
  the Keeper of Hours last: 17+ fights. Each fight takes place in its own floor's boss room and theme.
- Between fights, a short quiet room: one wax drip, and every third fight a choice of one of two relics.
- Wax is still health and the candle still melts; a separate **time-trial clock** (real time) shows on the HUD.
  Best times per candle and difficulty are kept in the slot, shown in the Journal's Records tab, and shared by
  the Share button.
- Achievements: finish the Boss Rush, finish it under a target time, finish it with each candle.
- `scripts/game/boss_rush.gd` builds the sequence; `--bossrush` test flag; the bot must be able to finish it
  with god mode and fail it sometimes without.

---

## How the teams move through it
- Two or three streams at a time (usage limits stopped bigger teams), each in its own worktree, committing after
  every finished piece; the integrator merges, runs the release checks in `CLAUDE.md`, builds an APK for the
  owner after each step, and updates `facts.md` and the store texts.
- Step 1 can start the moment v2.1 and the Long Night batch 1 (with the slider) are merged. Long Night batch 2
  runs as a side track during steps 2-3 so 10-floor nights arrive without holding the queue.
