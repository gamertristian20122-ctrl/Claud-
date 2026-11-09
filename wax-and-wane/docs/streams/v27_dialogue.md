# v2.7 stream `dialogue`: the story talks (talking scenes, a story opening, the endings' last words)

A real player (the owner's friend) tried 2.6: fun, but "the story shouldn't be just papers; there should be an
animation of talking before, maybe even after, the fight", and the game is "lacking something". This stream gives the
house its voices: every guardian talks the first time a save slot meets it and says its last words when it falls,
Tallow answers (brave, scared, a little funny), Martha Fenn speaks as a memory, a slot's first run opens with a short
animated story, and the endings close with a few words between Tallow and Martha. Branch `v27/dialogue`. The story is
still `docs/design/STORY.md`; the diary pages stay as the extra lore. **No old line was changed.**

Eight moments at 480x216 (the opening's kitchen and cellar, a meeting, Martha's memory at a fall, the Organist, the
true ending's beat): `docs/streams/img/v27_dialogue.png`.

## What changed

| Where | What |
|---|---|
| `scripts/ui/talk.gd` (new, class `Talk`) | The talk box (below) and the hooks: `Talk.meet`, `Talk.fall`, `Talk.on_back`, `Talk.done_with`, `Talk.ending_lines` / `ending_beat`; the setting (`Talk.mode`), the records (`Talk.talks`, `seen`, `note`). |
| `scripts/ui/talk_portrait.gd` (new, class `TalkPortrait`) | A speaker's portrait in a 56 x 56 brass frame; `TalkPortrait.paint_candle` draws any candle from Tallow's own parts (any face, flame, arms, look, the dish, a wax tear). |
| `scripts/game/talk_lines.gd` (new, class `TalkLines`) | Every line: `SPEAKERS` (voices, portrait crops), `MEET`, `FALL`, `AGAIN` (16 guardians), `OPENING`, `ENDINGS` (+ `ENDING_CARD`, `TALLOW_ONLY`). 161 lines (138 for the guardians, 11 for the opening, 12 for the endings). |
| `scripts/ui/opening.gd` (new, class `Opening`) | The story's opening: four animated panels, 11 lines (a screen, or over the Journal). |
| `scripts/game/talk_tour.gd` (new, class `TalkTour`) | `--talkcheck`, `--tour --talk`, `--tour --talk=all`. |
| `tools/art_talk.py` (new) | 7 new face frames for Tallow (`hero/face_*_talk`, `face_teary*`), Martha's sepia talk portrait (`talk/martha_f0/f1/blink/smile`, 24 x 24), Martha at her kitchen table (`talk/martha_stand/match/light`, 36 x 52), the cellar (`talk/open_cellar`, 192 x 96). 0x72 palette asserted for every file, 1 px outline, reviewed zoomed. |
| Hooks in shared files (small, commented `v2.7`) | `boss_intro.gd` `_finish` (`Talk.meet`, 4 lines re-indented), `world.gd` `_boss_down` (3 lines) and `on_back` (1 line), `main.gd` (`SCREENS["opening"]` + 2 lines in `goto`), `settings_panel.gd` (one row), `journal.gd` (the Watch the beginning button, 9 lines), `ending.gd` (`_next_card`: the beat; the card's fade-out moved into `_card_out`), `game.gd` (the `talk` setting, the `talks` record), `autotest.gd` (two dispatch lines each for `--talkcheck` and `--tour --talk`). |
| `tools/extract_strings.py`, `lang/en.json` | `TalkLines` MEET / FALL / AGAIN / OPENING / ENDINGS are data tables of the extractor (`text`); every new string goes through `L.t` (`--strict` PASS on all five new scripts); en.json 696 keys. |
| `README.md`, `DESIGN.md` | New files, commands, the `talk/` art. |

## The talk box (`Talk`)
- Along the bottom: a framed kit panel (wax on its rail) with two portraits sitting on it, the candle on the left and
  whoever it talks to on the right (Martha's memory takes the right frame for her line). The speaker is lit, blinks and
  talks (a 2-frame mouth while the line types); the listener sits dimmed. The speaker's name is engraved on a brass
  plate over its side of the box ("a memory" beside Martha's). A letterbox bar on top holds how to go on ("Tap to
  continue" / "Click to continue" / "Any key: next   Esc: skip" / "Any button: next   B: skip") and **Skip**.
- The line types out at 40 letters a second, pausing a moment at . ! ? , and ellipses; each speaker has a soft voice:
  a pitched CC0 blip every other letter (`TalkLines.SPEAKERS`: Tallow a high tick, Martha a soft click, Old Rot a low
  step, the Choir ticks in thirds, the Pendulum ticks and tocks, the Keeper a deep tick...). Whispered lines "(...)"
  are quieter. A blinking flame shows when the line is done.
- A tap, click, any key or pad button finishes the line, the next moves on. Skip (tap it), Esc, B and Back end the
  scene. Presses in the first 0.3 s are ignored (the shot that skipped the entrance); a tap that arrives as a touch and
  an emulated click counts once.
- While it plays the house is paused (the clock too), the sticks are let go and the HUD steps aside; the music dips.
  The guardian being met keeps breathing (its idle frames) and Tallow's flame keeps flickering.
- **Reduce motion** (Settings > Game): lines appear whole; no slide or pop.
- `short` (a one-liner): no bar, no Skip; it closes by itself 1.8 s after it has typed out, or at once on a press.

## Where scenes play

| Scene | Where it triggers | What |
|---|---|---|
| A first meeting | `BossIntro._finish` -> `Talk.meet`: right after the guardian's entrance, before its fight | 2-4 lines; the guardian stays held (`intro`, not `active`: harmless, untouchable, its AI waiting) until the scene ends, then it flashes white and the fight starts |
| A later meeting | the same hook | one short line (`AGAIN`, three per guardian, never the same twice running), closes by itself |
| A first fall | `world._boss_down` -> `Talk.fall`: once the fallen guardian has faded; the room's rewards, the trapdoor, the last floor's victory / ladder / true ending all wait for it (`await Talk.done_with`) | 1-2 lines: its last words, then Tallow or a memory of Martha |
| A later fall | | nothing (Story scenes: First time) |
| The opening | `main.goto("game")` on a slot's first run (below) | 4 panels, 11 lines |
| An ending's beat | `ending.gd` `_next_card`, on `ENDING_CARD` (the card before the last) | 3 lines, the candle and Martha's memory |

Rules (all checked by `--talkcheck`):
- **Never during a fight, never with a live foe**: a meeting opens only while the guardian is still held by its entrance
  and nothing else is alive in the room (`Talk._quiet_room`); a fall opens only once every foe is down and the shots are
  cleared. Otherwise no scene (logged).
- **Never in the bot's runs**: under `--autotest` scenes never open unless a test sets `Talk.force` (the bot, the other
  tours and `--diarycheck` behave exactly as before; they log `[talk] meet <kind>: no scene (bot / test)`).
- **Tonight's Candle never takes more than a tap**: a meeting is one line (a first meeting: its first line; later: an
  AGAIN line), a first fall its first line, each closing by itself or on one press. A first meeting in Tonight's Candle
  is not counted, so its whole scene still plays on a normal night.
- **Saves remember**: `Game.records["talks"]` ("meet:<kind>", "fall:<kind>", "end:<id>", "opening" -> times), saved
  when a scene ends (seen or skipped; one cut short by closing the game plays again). A save from before 2.7 has no
  record, so every guardian talks once on its next meeting.

## The setting
Settings > Game > **Story scenes**: **First time** (default: a guardian's whole scene the first time a slot meets it, its
fall words the first time it falls, each ending's beat the first time; later meetings one short line), **Always** (the
whole scenes every time), **Off** (no scenes, no one-liners, nothing recorded; the opening still plays once on a fresh
slot and stays in the Journal). Stored in `Game.settings["talk"]` (shared by the slots, like the other settings).

## The opening (`Opening`)
Four panels at x2, gently animated, with narration typed in a band along the bottom (the band also holds how to go on,
who speaks and Skip, so the art keeps its corners: the moon, the stairs' lit door; Martha and Tallow speak their
lines with their voices), about 37 s when nobody taps (`Opening.length()`; a tap moves on sooner):
1. **The house at midnight** (`tower/end_house`): stars, the chimney smoking, the kitchen window lit, the tower clock
   creeping to twelve, the view easing up. "There is an old house that runs on a great clock." / "Every night at twelve,
   the Keeper of Hours winds it, and the house gets up to do its chores."
2. **The great clock** (`tower/end_dial`): the hands tick to twelve and the bell strikes. "Anything done every night for
   long enough starts to do itself." / "The pot stirs itself. The organ plays itself. Nobody is left to tell them to stop."
3. **Martha's kitchen** (`story/end_kitchen` + `talk/martha_*`): the fire, the kettle, the night in the window; Martha
   by her table, Tallow asleep on it, unlit. She strikes a match, reaches a long match to his wick ("Good evening,
   Tallow."); he lights, cries a drop of wax at the match, then beams. "Martha Fenn kept this house for sixty-one years.
   She wanted it to rest." / "So she made a candle. A candle is the one thing that knows how to end." / "She lit him
   every night for a year, until the house learned to do it for her."
4. **The cellar** (`talk/open_cellar`): dark; the match strikes itself, his light pushes the dark back (banded), he
   wakes in Martha's chalk circle, looks left and right for her ("...Martha?"), cries a little wax, then brave, a hop,
   and he turns to the stairs (the lit door at the top). "Now, at twelve, the match strikes itself, and Tallow wakes
   alone." / "He's scared of the dark. He goes up anyway."

- **When**: the one hook is in `main.goto` (the title / slots flow, clearly commented): `goto("game")` goes to the
  `opening` screen first when `Opening.wanted()` (the slot has no runs yet, has not seen it, and no test is driving the
  game); the opening then goes on to the same run (same params). The onboarding stream's first-run controls primer
  plays inside the run, so it always comes after the opening. A slot with runs that never saw it (an older save) gets
  the Journal's gold dot on the Diary tab instead.
- **Skippable**: Skip, Esc, B, Back. Reduce motion: lines whole, plain cuts, no drift or shake.
- **Replay**: the Journal's Diary tab, "Watch the beginning" (where the page arrows were: the diary is one page), over
  the Journal, which comes back after. The button has a gold dot until it has been watched.

## The endings' closing beat
On the card before the last of each ending (after the card's own lines have shown 1.8 s, they step aside under the box;
the card's scene keeps moving), then the ending goes on:
- **True ending** (the sill, before dawn): "It's so quiet. Is everyone asleep?" / Martha: "Every last one, love. You can
  stop now too." / "In a minute. I'd like to see the morning first." (then dawn, and the little flame goes out)
- **The Housekeeper** (Tallow on her table; Tallow only, it is his own memory): "It was you. Every night at twelve, it
  was you." / "Every night for a year. You cried wax at the match every single time." / "I still do, a bit."
- **A Candle in Every Window** (the sill): "Every window's lit, Martha. Every room in the house." / "Then nobody comes
  home to a dark house tonight. That's all I ever wanted for them." / "There's one in the kitchen for you. There always was."
- **The Whole Story** (the diary by her chair): "Martha? The diary's whole. Every page came home." / "Then the rounds are
  done, love. Sit down a minute. You've earned the good chair." / "Goodnight, Martha." (then dawn)

## Every guardian's scenes (first lines; the whole table is `scripts/game/talk_lines.gd`)

| Guardian | Talks like | First meeting opens with | Its fall |
|---|---|---|---|
| Old Rot | a lodger who never paid rent | "Mmmf. Who's knocking? If it's about the rent, I'm out." | "Wake me at twelve. Or don't." + Martha on the damp |
| The Wax Mother | a doting mother counting drips | "Nine thousand and three, nine thousand and four... and you." | "...you come home to Mother" + Martha: "if she ever cuddles you..." |
| The Coal Furnace | a boiler that is always hungry | "Hrrm. Coal. Coal. Coal... is that wax?" (Tallow: "I'm not fuel! I'm... staff!") | "Somebody fetch... a scuttle..." + Tallow's promise |
| The Gaoler | the rules, keys and lock-up | "Halt. The crypt is locked at twelve, by order of the Book of Rounds." | "Keys... It's nearly lock-up" + Martha: "Because it's Tuesday." |
| The Sexton | an undertaker measuring | "Hold still. Five inches... six with the flame." | "I'll just... dig myself a little lie-down." |
| The Ossuary | a committee of bones | "Order! Order. The stack has discussed you, and the stack has opinions." | "Motion to... lie down... Seconded... Carried..." |
| The Hollow Warden | a night watchman's call | "All's well... All's well... All's... Who goes there?" | "All's... well..." + Martha's candle for it |
| The Melted Choir | a hymn that never ends | "Ooh, a candle! Hold still, dear, we need the light for verse four hundred and twelve." | "A-a-amen... Oh! Was that the end? How lovely." |
| The Organist | a hymn book | "Please rise for hymn number four hundred and six." ("...Which Tuesday?") | "...The congregation... may be seated." + Martha on Mr. Pennock |
| The Great Pendulum | tick and tock | "Tick. That minute was yours. Tock. So was that one." | "Tick... tock..." + "Everyone can keep their own minutes now." |
| The Hour Fiend | an appetite for wasted time | "Ahh. A dawdler. I can smell every minute you've wasted tonight." | "It isn't even two..." + Martha: Cook's cure for worry |
| The Weathercock | a weather report | "Tonight: wind from the north-north-west, scattered candles..." | "And now... the outlook... calm... calm... calm." |
| The Stockpot | a recipe / Cook's orders | "Blub. Blub. Never off the boil. Cook's orders. Blub." ("Do NOT add the candle!") | "Cook will be... livid..." + Martha on Cook's knees |
| The Head Librarian | library rules, whispering | "Shhh. No running in the reading room. No burning. And absolutely no crackling." | "Shh... ...overdue..." + "(Sleep well.)" |
| The Dressmaker's Form | a fitting (the boat sails Friday) | "Arms up. Hold still. The fitting is at eight, and the boat sails on Friday." | "I'll wait... for Friday..." + Martha on Miss Tibbet's dress |
| The Keeper of Hours | its one order, very tired | "You are early. No one has been early in three hundred years." | "Nobody told me... what comes after..." + "Morning comes after." |

## The line table's rules (`TalkLines`)
- A line is `{"who", "face", "text"}`. `who`: "me" (the candle being played: its own name, colours and face; lines are
  written so any candle of the house can say them), "martha" (her memory), or a guardian kind (defaults to the table's
  guardian). `face` of the candle: open, brave, worried, teary (crying wax), happy, tired, shout (`TalkPortrait.FACES`
  maps each to its mouth-shut / mouth-open / blink frames, flame and arms); Martha: open, smile. `{name}` = the candle.
- A first meeting is 2-4 lines, a fall 1-2, a later meeting one line; no line over 120 letters or three box lines on a
  384 px screen (measured with the font by `--talkcheck`); the opening's lines fit two band lines.
- Voice: STORY.md's (short sentences, plain words, one specific funny detail, warm, a little sad, never gothic purple,
  never "darkness / evil / ancient power"). Tallow: brave but scared, polite, a little funny, tender with the tired
  ones. Guardians are never villains: tired, faithful chores that forgot how to stop, each talking like its chore.
  Martha: practical, dry, fond. Everything agrees with the lore lines, the diary and STORY.md.
- A new guardian needs a `SPEAKERS` entry (voice, crop of its first idle frame), `MEET`, `FALL`, `AGAIN`; the check fails
  until it has them. Run `python3 tools/extract_strings.py` after editing lines.

## Judges (final code)

| Judge | Result |
|---|---|
| `godot --headless --path . -- --autotest --talkcheck` | 48 checks, 0 failed (below) |
| `--checkscripts` / `--checkrooms` | clean / 0 problems (69 layouts, 1776 dressed rooms, 657 area rooms) |
| `--diarycheck --speed=4` | 42 checks, 0 failed (unchanged: no scene opens under a test) |
| `stdbuf -o0 godot --headless --path . -- --autotest --playtest --speed=4 --runs=1 --god` (fresh profile) | WIN floor 4/4 (Belfry) at 12:25 AM, 0 SCRIPT ERRORs; every guardian logged `[talk] meet / fall <kind>: no scene (bot / test)` (Furnace, Gaoler, Choir, Pendulum): the bot never waited on a scene |
| `--tour --talk --fit` at 1600x720 (480x216) and 1152x648 (384x216) | 28 shots each, 0 fit flags; the opening measured 37.9 s |
| `--tour --talk=all --fit` at 1600x720 | every guardian's first two lines and every candle's portrait, 0 fit flags |
| `python3 tools/extract_strings.py --strict` on the five new scripts | PASS (en.json 696 keys) |
| `python3 tools/art_talk.py` | palette check PASS (15 files); zoomed review sheets with `--review=DIR` |

`--talkcheck` proves, on a throwaway profile: all 16 guardians have a first meeting (2-4 lines), a fall (1-2) and later
lines, with a portrait crop and a voice; the 138 guardian lines have known speakers and faces, none over 120 letters or three box
lines at 384 px; every face sprite, Martha's portrait and every voice file exists; the opening's lines, art and length
(37.3 s untouched, 20-40); the opening plays on a fresh slot's first run only, never under a test, skips into the same
run (same seed) and is remembered, an older slot gets the gold dot, the Journal replay gives the Journal back; a real
first meeting opens after the entrance with the guardian held, the house paused, no other foe, the HUD hidden; a press
in the first 0.3 s is ignored, a press finishes the line, the next moves on; the fight starts after it (guardian
active, house running, HUD back); a real fall opens with nothing up, before the rewards, which come after; later
meetings get one self-closing line and later falls nothing; Always plays everything again (Esc skips); Off plays and
records nothing; Tonight's Candle gets one line that closes by itself or on one tap and does not count as the first
meeting; a scene never opens while another foe is up; Reduce motion shows lines whole; the bot (no `Talk.force`) gets
no scene, its guardian fights right after its entrance, nothing is recorded; the talks record survives the slot file's
format; all 4 endings have a beat on a card before the last, the true ending's opens on its card and the ending goes on
after it, First time / Always / Off and the Tallow-only Housekeeper beat behave.

Tours: `--tour --talk` = the opening's 8 moments (a fresh slot, the real `goto("game")`), four first meetings (Old Rot
with its fall, Martha's memory and a later one-liner; the Wax Mother; the Organist; the Weathercock), the Story scenes
row, the Journal's Watch the beginning and its replay, the true ending's beat. `--tour --talk=all` = every guardian's
first two lines (portraits and crops) and every candle's talk portrait.

## Hooks outside this stream's files (for the merge)
- `boss_intro.gd` `_finish`: `if not Talk.meet(w, e, _skipped):` around the three lines that start the fight.
- `world.gd` `_boss_down`: `var fallen := str(e.kind)`, `tw.tween_callback(func(): Talk.fall(self, fallen))`, and
  `await Talk.done_with(self)` as the first line of the reward callback; `on_back`: `or Talk.on_back(self)`.
- `main.gd`: `SCREENS["opening"]`; `goto`: `if screen == "game" and Opening.wanted(self, params): screen = "opening"`.
- `settings_panel.gd` Game page: the Story scenes cycle after Pickup magnet (phones now show 7 rows, so the Effects
  Lite hint gives way as it already did on a PC).
- `journal.gd`: `_watch` (Watch the beginning) in the bottom row; `_fill` hides the page arrows on the Diary tab.
- `ending.gd` `_next_card`: `Talk.ending_lines` / `Talk.ending_beat`; the fade-out is `_card_out(t1, t2, tw)`.
- `game.gd`: `settings["talk"]`, `RECORDS["talks"]`. `autotest.gd`: `--talkcheck`, `--tour --talk`.

## Known issues / not done
- Guardians do not blink (their art has no eyelid frames): they breathe with their own idle frames, faster while they
  talk (the Choir and the Organist sing). Tallow and Martha blink and talk with a 2-frame mouth.
- The voices were set by level and pitch numbers (-10 to -16 dB under the Sound volume): nobody has listened to them on
  a phone yet. The same for sizes: judged on 480x216 and 384x216 screenshots, not on the owner's phone.
- In Tonight's Candle a first meeting shows only its first line; the whole scene waits for a normal night.
- The candle's lines suit any candle of the house (its own name and portrait); the opening and the Housekeeper's beat
  are Tallow's own story (the opening always shows Tallow).
- A slot from before 2.7 has runs, so the opening does not play by itself: the Journal's Diary tab offers it with a
  gold dot. Its guardians all talk once on their next meeting (no talks record yet).
- The opening runs about 37 s untouched (a tap moves on sooner); there is no reading-speed setting.
- On a phone the Settings Game page now has seven rows, so the Effects Lite note gives way (as it already did on a PC).
- Guardian names on the plates are the versus card's names, not translated yet (like the card).
- The opening's kitchen is storybook scale: Tallow on the table reaches Martha's shoulder, as in the endings' cards.
