# v2.5 story stream: the diary pages, the story of the house, alternate endings

Spec: `docs/design/ROADMAP_V2.md` section 3 (Diary pages). Branch `v25/story`. The story itself (who kept the
house, why it wakes at midnight, the Keeper of Hours, who lit Tallow and why, every floor and guardian, what the
endings mean) is the bible in `docs/design/STORY.md`.

## What changed

| Where | What |
|---|---|
| `docs/design/STORY.md` | The story bible: the house's one rule ("anything done every night for long enough starts to do itself"), Martha Fenn the housekeeper, the clockmaker, the Keeper of Hours, the Hour Fiend, Tallow, the household, every area and guardian, the 24 pages, the endings, the voice. |
| `scripts/game/diary.gd` (new, class `Diary`) | The 24 pages in story order (`PAGES`: id, title, text, `from` = where it can turn up), the sources and their odds, the slot's found pages, the floor's seeded plan, the page pickups, the reading card's queue (never in a fight), the ending choice (`ENDINGS`), the results hook. |
| `scripts/ui/page_card.gd` (new, class `PageCard`) | The reading card: the page on torn cream paper (0x72 colours), "Diary page N of 24", the title, the text, "Tap to close / Any key / Any button". Pauses the house while it is open; ignores presses for its first 0.6 s; Back closes it. |
| `scripts/game/pickup.gd` | Pickup kind `page`: a fluttering torn page (unshaded, bobbing), "A torn page / From someone's diary" when Tallow is near, `page_flip` on pick-up. |
| `tools/art_story.py` (new) -> `assets/art/story/` | `page_f0..f3` (12x13, 1 px #222222 outline), `page_icon` (14x17, the Journal), `end_kitchen` (192x96: Martha's corner of the kitchen at night). Palette asserted against the 0x72 sheet. |
| `scripts/ui/journal.gd` | A 7th tab, **Diary** (after Records, so the other tabs keep their numbers): a 6x4 grid of pages in story order, "???" for missing ones (with where they turn up), title + page number + text + "Found on run N"; a found page selected again opens its reading card. Touch, keys and pad like every tab; the tab carries the gold "new" dot. Counts: "Pages n / 24   Endings e / 4". |
| `scripts/ui/ending.gd` | Refactored into card lists per ending (`ending` = true / housekeeper / windows / whole_story) with named moving parts (house, dial, tick, sill, dawn, kitchen, lights_on, lights_lit, lights_off, pages). The true ending plays exactly as before. The credits header names the ending; each ending has its own last line; a "THE HOUSEHOLD" credit once a page is found. All its text now goes through `L.t`. |
| `scripts/autoload/achievements.gd`, `docs/streams/platform.md` | Six achievements (below) and their Steam ids. |
| `scripts/game/diary_tour.gd` (new, class `DiaryTour`) | `--diarycheck`, `--ending=<id>`, `--tour --diary`. |
| Hooks, one line each | `world._start_floor` -> `Diary.on_floor_start`, `world._stock_hollow` -> `on_hollow`, `world.on_enemy_killed` -> `on_kill`, `world._clear_room` -> `on_clear`, `world._victory` -> `win_ending`, `world.on_back` -> `on_back`, `Specials._stock("study")` -> `on_study`, `Tower.true_end` -> `keeper_ending`, `Records.end_run` -> `on_end_run`, `results.gd` -> `on_results`, `autotest.gd` (the three flags). |
| `tools/extract_strings.py`, `lang/en.json` | `Diary.PAGES` (title, text) and `Diary.ENDINGS` (name, line) are data tables of the extractor; every new string is wrapped (`--strict` PASS on diary.gd, page_card.gd, ending.gd, diary_tour.gd has no player text); en.json 450 keys. |

## Where each page turns up

| # | Page | Where |
|---|---|---|
| 1 | My first night | loose (and always a slot's first page) |
| 2 | The Book of Rounds | loose |
| 3 | The house's one rule | loose |
| 4 | Under the stairs | a Cellar guardian's first fall |
| 5 | Cook's one law | a room of the Kitchen (5+ floors), or the Kitchen's guardian's first fall |
| 6 | Down in the crypt | a Crypt guardian's first fall |
| 7 | The merchant | loose |
| 8 | Mr. Pennock | a Chapel guardian's first fall |
| 9 | Silence | a room of the Library (6+ floors), or its guardian's first fall |
| 10 | Miss Tibbet's dress | a room of the Attic (7 floors), or its guardian's first fall |
| 11 | The great bell | a Belfry guardian's first fall |
| 12-18 | Below stairs, The family, The seance, Wilf, The clockmaker, Borrowed time, Between the ticks | loose |
| 19 | The Keeper of Hours | the Clock Tower's first room, by the top of the ladder |
| 20-23 | The hammer, What a candle knows, Good tallow, Every night at twelve | loose |
| 24 | For Tallow (Martha's letter) | the Keeper of Hours' first fall |

**Loose** = a hollow (45% of floors keep one there), the floor's first marked foe snuffed (10%), a house champion
(30%), the Study's desk (60%; a page by the lectern that never crumbles with the other three), or a guardian's
first fall once its area's page is found. Loose pages come roughly in story order: one of the first three missing
ones (seeded), and a slot's very first page is page 1.

Rules (all in `diary.gd`):
- **Seeded:** each floor's plan (which sources keep a page, which room keeps a new area's page) comes from its own
  generator, `hash("<run seed>:diary:<floor>")`, and the choice of a loose page from `"<seed>:diarypick:<floor>"`.
  `world.rng` and the floor RNG are never touched (checked: `--diarycheck`, and `--nightdump` equals the 2.2
  baseline), so pages never change a seed's house or loot. A seed gives the same pages to every slot that has
  found the same pages (it cannot be more: a slot never gets a page it already has).
- **Never twice:** never a page the slot has found, nor one already lying on this floor.
- **Saved at once:** `Game.records["diary"]` (page id -> the run it was found on) is written the moment a page is
  picked up; `"diary_guardians"` remembers which guardians gave their page (a save from before 2.5 starts empty,
  so every guardian gives one on its next fall); `"endings_seen"` counts each ending. The Journal's gold dot is
  `d:<id>`.
- **Never during a fight:** the reading card opens only when the room is cleared, no foe or guardian is alive, no
  Seance is between waves and nothing holds the world, after 0.6 s of calm. A page found as the run ends (the
  last guardian's, the Keeper's: gathered from the room when the night is won) or during a fight that never
  ended shows on the results screen, one card after another. Play-tests close cards after 0.4 s.

## The endings and how to reach them

| Ending | How | Cards |
|---|---|---|
| (results screen only, as before) | win a night with fewer than 12 pages | |
| **The Housekeeper** | win a night (4-6 floors, or 7 when the long night's ending was already seen) with 12+ pages | the house with the kitchen light on; Martha's empty chair; Tallow on her table ("She made one last candle"); the clock still ticking above the bells |
| **A Candle in Every Window** | win a night of seven floors | the clock stops; the windows light one by one; "One for everyone who lived here"; "Tallow kept the small hours" |
| **True ending** (2.0, unchanged) | still the Keeper of Hours with fewer than 24 pages | as before |
| **The Whole Story** | still the Keeper with all 24 pages | the clock stops for good; the windows go dark one by one ("The rounds are done"); 24 pages fly home to the diary by her chair; dawn, the flame goes out ("Martha kept your seat by the fire") |

When a won night earns both The Housekeeper and A Candle in Every Window, the one this slot has not seen yet plays
(else the long night's). Every ending has its own credits header and last line; the results screen names it
("The kitchen light is on. You can finally rest.", "THE WHOLE STORY") and lists tonight's pages.
The roadmap's "First Light" (a ten-floor night won at dawn) waits for Long Night batch 2; STORY.md has its place.

## Achievements (Steam ids in `docs/streams/platform.md`)
`diary_first` Dear Diary, `diary_half` Half the Story (12), `diary_all` Every Last Page (24), `end_housekeeper`
The Housekeeper, `end_windows` A Candle in Every Window (hidden), `end_story` The Whole Story (hidden).
"The Small Hours" (a seven-floor night won) already existed and unlocks at the same win as `end_windows`.

## Old lore lines changed
None. Every guardian's and lodger's line, the candles, the intro, the hollow banner, the chalk and the true
ending already fit the story (STORY.md shows where each one sits). The true ending's and the credits' English
text is unchanged; it now goes through `L.t`.

## Test flags
```
godot --headless --path . -- --autotest --diarycheck                 # 42 checks, exit 1 on a FAIL
godot --headless --path . -- --autotest --ending=<id> [--speed=4] [--shots=/abs/dir]   # true / housekeeper / windows / whole_story
xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 --resolution 1600x720 \
    -- --autotest --tour --diary --fit --shots=/abs/dir                # 24 shots
```
`--diarycheck` plays a seeded 7-floor night on a throwaway profile: the 24 pages and every source listed and proven
(a guardian's first fall on floors 1-6, the Kitchen's and Attic's rooms, a hollow, the Study, a marked foe, a
house champion, the Clock Tower's first room; the Belfry's and the Keeper's asked directly since their fall ends
the night), a fresh slot's first page is page 1, the diary leaves `world.rng` alone and plans the same pages for
the same seed, the reading card waits out foes, a guardian and a Seance between waves and pauses the house while
open, 600 draws from every source give all 24 pages with none twice and nothing after, the endings' rules, and
every ending's cards and scenes.

## Checks (final code)
- `--checkscripts`: clean. `--checkrooms`: 0 problems (69 layouts, 1776 dressed rooms, 657 area rooms).
- `--diarycheck`: 42 checks PASS.
- `--ending=housekeeper / windows / whole_story --speed=4`: each reaches its cards (4) and the results screen with
  the ending named.
- `--tour --diary --fit` at 1600x720 (480x216): 24 shots, no fit warnings; again at 1152x648 (384x216): the
  Diary tab, the cards and the results fit (the only warnings were a run's first hint sitting under a staged
  ending's cards, a tour artefact now hidden).
- One `stdbuf -o0 godot --headless --path . -- --autotest --playtest --speed=4 --runs=1 --god` (fresh profile): WIN on
  floor 4/4 at 12:40 AM, 0 script errors; 7 pages found on the way (page 1 from the Furnace's first fall, a marked
  foe's, the Ogre's, the Study's, the Choir's, another marked foe's, and the Pendulum's gathered at the win), every
  reading card opened in a cleared room (boss rooms after the fall, a normal room, the Study).
- `--nightdump --speed=4`: equal to `docs/streams/v22_night_baseline.txt` (553 lines, no diff): pages never move a
  seed's house, guardians or loot.
- The page pickup and the kitchen looked at zoomed (x7 in game, x8 / x4 contact sheets from `tools/art_story.py --review`).

## Known issues / follow-ups
- A page left lying when Tallow leaves the floor is gone for that run (it can turn up again later). Pages are not
  pulled to Tallow like coins.
- The store copy's achievement count ("54") was already stale; there are 67 now. `facts.md` and the store texts
  could mention the diary and the endings at the next store release.
- The boss-intros stream works where fights start (`world._start_boss`); this stream does not touch it.
- Endings play every time their condition holds (like the true ending); every card after the first can be skipped.
