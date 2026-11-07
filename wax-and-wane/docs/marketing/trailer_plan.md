# Trailer and short-video plan: Wax & Wane

Everything here uses real gameplay only. No fake UI, no scenes the game can't produce, no review quotes until real ones exist.

---

## 0. How to capture clean footage

1. The game draws at 384 x 216. Run the desktop build in a **1920 x 1080** window: that's exactly 5x, so every pixel stays sharp.
2. Record with OBS at 1920 x 1080, 60 fps. Turn off any scaling filter in OBS (use "Point" / nearest).
3. Play the clutch moments yourself. The `--playtest` bot is fine for B-roll of rooms and floors, but it ignores telegraphs and doesn't look clever.
4. Keep the wax bar and clock visible in nearly every shot. It's the hook, so viewers have to see it working.
5. For vertical videos, record a second pass at **1536 x 864** (exactly 4x). The 272 x 192 room becomes 1088 x 768, which crops to 1080 wide with almost nothing lost. If the clock bar falls outside the crop, paste a 2x copy of it above the room.
6. Steam often starts the trailer muted, so text cards must carry the story without sound.

---

## 1. Main trailer: 58 seconds (Steam, itch, Play promo video, YouTube)

Music: one track from the game's own soundtrack, the boss or Belfry theme [CHECK which tracks v2.0 ships]. Cut on its beats. Cue points below assume a steady tempo; shift shots to the nearest downbeat.

| Time | Shot (real gameplay) | Text card / overlay | Music + sound cue |
|---|---|---|---|
| 0:00 to 0:02 | **Hook.** Tight on Tallow, very short, in a dark room. The clock reads 1:58 AM and the light circle is tiny. Three fast kills: the Kindling streak fires and the light swells back out. | "Your health bar is a candle." | Silence, then one bell toll at 0:00. Ember pop SFX on each kill |
| 0:02 to 0:05 | The flame lights the WAX & WANE logo in black. | (logo only) | First downbeat of the track at 0:02 |
| 0:05 to 0:13 | A Cellar fight from the doorway: enemies close in, a hit, Tallow shrinks, the spilled wax splashes, Tallow grabs it back and grows. | "Every hit melts you." then at 0:09 "Every kill buys time back." | Drums in at 0:05. Hit-melt sound right on a beat |
| 0:13 to 0:19 | Room clears: candelabras light, doors open. Then four 1.5 s cuts, one room from each floor: Cellar, Crypt, Chapel, Belfry. | "Four floors. Midnight to 2 AM." | One cut per beat |
| 0:19 to 0:29 | Builds. Relic pop-ups (Twin Wick, Will-o'-Wisp, Hot Drip), a Rite banner, then a room filling with seeking, piercing fire. | "Stack relics into builds that shouldn't work" | Build-up from 0:19; melody enters at 0:24 |
| 0:29 to 0:35 | Smoke Altar: Tallow takes the deal, the top of the wax bar is cut off, then the next room gets wiped. | "Trade minutes off your candle for power" | Low drone under the altar choice; hit at 0:33 |
| 0:35 to 0:46 | Bosses: two versus cards slam in (Old Rot, one v2.0 boss), then the Hour Fiend's clock hands sweeping the room while Tallow weaves through. | "8 bosses" [CHECK] | Biggest hit of the track on the first versus card at 0:35. Bell toll SFX at 0:41 |
| 0:46 to 0:51 | Clutch. The candle is Guttering at one minute, the boss has a sliver of health; last shot lands. | (none) | **Music cuts out at 0:46.** Only the flame and footsteps. Final hit at 0:49 brings the whole track back |
| 0:51 to 0:58 | End card: logo over a lit room. | "Wishlist on Steam" + "Steam, itch.io, Google Play" + release window [NEED] | Track ends on a held note; one clock tick at 0:57 |

Rules for the edit:
- No shot longer than 3 seconds before 0:35.
- Text cards: one line, Kenney Pixel font, white on a dark band, each up for at least 1.5 s.
- Export 1920 x 1080, 60 fps, H.264, high bitrate. Upload the same file to Steam, YouTube and itch.

---

## 2. Three vertical shorts (15 to 25 s, 1080 x 1920, for TikTok / YouTube Shorts / Reels)

Layout for all three: top 400 px for the hook text, gameplay crop in the middle, bottom 300 px clear for the app's own buttons and captions.

### Short A: "The candle is the timer" (18 s)
- **Hook text (0 to 2 s):** "My health bar is also the clock"
- **0 to 2 s:** Tallow full height, clock at 12:00, bright room.
- **2 to 10 s:** Sped-up fight (2x speed) as the clock races and Tallow shrinks. Small caption on each hit with the real loss (an early hit melts about 5 or 6 minutes, e.g. "-6 min").
- **10 to 15 s:** Back to normal speed at 1:57. A Kindling streak: caption "+1 min", "+2 min".
- **15 to 18 s:** The light swells. Cut straight back to the first frame so it loops.
- **On-screen end text:** "Wax & Wane. Link in bio."
- **Caption:** "Every hit melts the candle and the candle is the timer #indiegame #roguelite #pixelart"

### Short B: "Every fire relic on one candle" (22 s)
- **Hook text (0 to 2 s):** "I stacked every fire relic on a candle"
- **0 to 3 s:** Tallow alone, one weak flame, in a full room. Caption: "Relic 0".
- **3 to 15 s:** Quick cuts of each pickup with a counter: "1: Twin Wick", "2: Sharp Wick", "3: Ember Heart", "4: Hot Drip", "5: Will-o'-Wisp" [CHECK that these stack this way in the final build].
- **15 to 22 s:** One full-length room where the build melts everything in about 3 seconds.
- **On-screen end text:** "Which relic should I add next?"
- **Why it works:** a counter gives people a reason to watch to the end, and the closing question gets comments.

### Short C: "One minute left" (15 s)
- **Hook text (0 to 2 s):** "1 minute of wax. Boss at half health."
- **0 to 11 s:** The clutch fight, real time, no music, sound effects loud.
- **11 to 13 s:** Freeze on the frame before the result.
- **13 to 15 s:** The result (win or snuffed). Post the loss too; losses get as many comments.
- **On-screen end text:** "Would you have taken the Smoke Altar deal?"

Posting notes: post the same file to all three apps. Use 3 to 5 hashtags, not 20. Reply to every comment in the first hour.

---

## 3. Twenty more short-video ideas

1. **"A candle that is also a timer"**: a 10 s explainer with the clock in the corner and nothing else.
2. **Devlog: how the candle shrinks**: side by side, full wax and one minute left.
3. **Before/after juice**: the same room in v1.1 and v2.0 [CHECK v2.0 footage].
4. **Tonight's Candle challenge**: "Today's house. Beat my time" with the date on screen. Post daily for a week.
5. **Near-death clutch compilation**: three Guttering saves in 20 s.
6. **"Rate this build 1 to 10"**: one ridiculous end-of-run build.
7. **Boss intro only**: just the versus card and the first attack pattern, 8 s.
8. **"Don't take the Smoke Altar deal"**: a run that took it and burned out at 1:52.
9. **"Always take the Smoke Altar deal"**: the next day, a run where it won.
10. **Secret Hollow**: "There's a room behind this wall", then the bomb.
11. **The mimic chest**: open a chest; it bites.
12. **Each candle in 5 seconds**: Tea Light, Party Candle, Altar Pillar, Black Taper.
13. **Black Taper hard mode attempt**: day 1, day 2, day 3 progress.
14. **Pixel art process**: Tallow's sprite drawn pixel by pixel, sped up (r/pixelart crossover).
15. **"Making a game with almost no coding experience"**: an honest devlog about working with an AI coding assistant. Expect strong opinions in the comments; answer them calmly.
16. **Sound design**: mute the game, then add each sound layer one by one.
17. **Omen of the day**: Cold Draught vs Smoky Halls, which would you take?
18. **Bell toll moment**: the 1:45 bell lands mid-boss and the music swells.
19. **Kindling streak record**: chase x8 for the Party Candle unlock.
20. **"Your phone vs a PC"**: the same run on Android touch controls and on a gamepad.

---

## Sources
- Pixel scaling numbers come from the game's own geometry (`DESIGN.md`: 384 x 216 viewport, 272 x 192 rooms).
- Mechanic numbers (Kindling, Guttering, 9.5-minute candle) come from `README.md` and `scripts/game/world.gd`.
