# Videos: the trailer, three shorts and a store loop

Everything here is the real game, played and filmed by the game itself (`scripts/trailer.gd`), cut by
`tools/trailer_edit.py`, with an **AI narrator** (see "Say it is AI" below). The files are made fresh from the
current build with one command (bottom of this page). They are not kept in git (too big): find them in
`build/videos/`.

## The files

| File | What it is | Length | Size | Picture | Sound |
|---|---|---:|---:|---|---|
| `trailer_60s.mp4` | The main trailer, narrated | 55.6 s | 47 MB | 1920x1080, 60 fps, H.264 | AAC 192k, -16 LUFS |
| `short_a_candle_is_the_timer.mp4` | Short A: "My health bar is also the clock", narrated | 17.5 s | 7.6 MB | 1080x1920, 60 fps | AAC, -14 LUFS |
| `short_b_every_fire_relic.mp4` | Short B: seven fire relics on one candle, music only | 18.8 s | 7.4 MB | 1080x1920, 60 fps | AAC, -14 LUFS |
| `short_c_one_minute_left.mp4` | Short C: 1:58 AM, the Hour Fiend still standing, narrated | 15.7 s | 6.0 MB | 1080x1920, 60 fps | AAC, -14 LUFS |
| `loop_fight.gif` | 6.5 s loop: the fire build melts a full room (game size, 384x216) | 6.5 s | 1.1 MB | GIF, 15 fps | none |
| `loop_fight.webm` | The same loop, twice the size (768x432) | 6.5 s | 0.9 MB | VP9, 30 fps | none |
| `trailer_60s.srt`, `short_a_...srt`, `short_c_...srt` | The narration as subtitles, timed to each video | | | | |
| `trailer_60s_play.mp4` (+ `.srt`) | The trailer ending on GET IT ON GOOGLE PLAY, for the Play listing | same | | | |
| `trailer_60s_steam.mp4` (+ `.srt`) | The trailer ending on WISHLIST ON STEAM, only once the Steam page is live | same | | | |

### One trailer, three endings (the `CTA` setting)
The end card's call to action is a setting, so each place gets the right ending from the same footage, with no
re-recording (`tools/trailer_edit.py`, `CTAS`):

| Command (from `wax-and-wane/`) | End card | Files | Post it on |
|---|---|---|---|
| `./tools/make_trailer.sh edit` | OUT NOW ON ITCH.IO (Windows - Linux - Android) | `trailer_60s.mp4`, the shorts, the loop | YouTube, itch.io, TikTok / Shorts / Reels, X, Bluesky, Reddit |
| `CTA=play ./tools/make_trailer.sh edit --only trailer` | GET IT ON GOOGLE PLAY | `trailer_60s_play.mp4` | a second YouTube upload (unlisted is fine) whose link goes in Play's promo video field |
| `CTA=steam ./tools/make_trailer.sh edit --only trailer,short_a,short_b,short_c` | WISHLIST ON STEAM | `trailer_60s_steam.mp4`, `short_*_steam.mp4` | the Steam page, and your socials once the Steam page is live |
| `CTA=none ./tools/make_trailer.sh edit` | no store line | `*_none.mp4` | anywhere a store name doesn't fit |

`edit` needs the recorded footage in `build/trailer_raw/` (made by `./tools/make_trailer.sh all` or `record`).
`COPY_TO` copies only the default (itch.io) cut; the other cuts stay in `build/videos/`.

`tools/make_trailer.sh check` prints this table again for the current files (lengths, sizes, loudness).

### What is in the trailer
1. 0:00 A match lights Tallow's wick in the dark (a sharp 10x close-up). *"This is Tallow. Tallow is a candle."*
2. 0:04 12:00 AM in the Cellar; the doors slam and the lodgers come. *"At midnight, the house wakes up."*
3. 0:08 A hit melts minutes off the candle and the clock. *"His wax is his health. His wax is also his clock."*
4. 0:12 A second hit, the spilled wax grabbed back; then 1:56 AM in a dark Crypt, quick kills pour time back.
   *"Every hit melts him faster. Every win buys him time."*
5. 0:18 Relics held aloft, a fire build melting a full room, the Cracked Mirror, the Wax Font, the Music Box, a
   Seance (cut on the music's beats). 0:29 one room of each floor. *"Four floors."*
6. 0:34 Four versus cards and the Hour Fiend's clock hands. 0:40 A ladder of light, the Clock Tower, the Keeper
   stops time. *"One secret."*
7. 0:45 1:58 AM, no music, the Hour Fiend on a sliver; the last flame lands. *"Be done by two... or burn out trying."*
8. 0:50 The title: the logo flickers on. *"Wax and Wane. Light the wick."* End card: **OUT NOW ON ITCH.IO**
   (or GET IT ON GOOGLE PLAY / WISHLIST ON STEAM in the other cuts, see above).

Steam starts trailers muted, so the short text cards ("YOUR WAX IS YOUR CLOCK", "64 RELICS THAT STACK",
"9 GUARDIANS"...) tell the story without sound.

## Where to post each one

1. **Steam store page** (Steamworks > Store page > Trailers), once the Coming Soon page is ready: upload
   `trailer_60s_steam.mp4`, put it first. In the "About this game" text, add `loop_fight.gif` with "Insert image"
   (it is 1.1 MB, under Steam's limits).
2. **YouTube** (normal video, not a Short): upload `trailer_60s.mp4`.
   - Title: `Wax & Wane - Trailer | a roguelite where your health bar is a candle`
   - Description: `You are Tallow, a little living candle. Your wax is your health and your clock: 12:00 AM full,
     2:00 AM gone. Four floors, one secret. Out now on itch.io:` followed by your itch.io page link, and on its
     own line: `Narration: AI-generated voice (Kokoro TTS).` Add the Google Play and Steam links as each goes live.
   - Subtitles: *Subtitles > Add language > English > Upload file > With timing*: `trailer_60s.srt`.
   - Then paste the YouTube link into the press kit and the itch page. For Google Play, upload
     `trailer_60s_play.mp4` to YouTube as well (unlisted is fine, same title and description) and paste that
     link into Play (Main store listing > Video).
3. **TikTok, YouTube Shorts and Instagram Reels**: post the same file on all three. One short per day is
   plenty (see the weekly plan in `launch_plan.md`). Use 3 to 5 hashtags, not 20.

   | Short | Caption |
   |---|---|
   | A | `Every hit melts the candle, and the candle is the clock. #indiegame #roguelite #pixelart #gamedev` |
   | B | `Seven fire relics on one little candle. Which one should I add next? #indiegame #roguelite #pixelart #gamedev` |
   | C | `1:58 AM and the Hour Fiend is still standing. Would you have made it? #indiegame #roguelite #pixelart #indiedev` |

   Pin a comment with the itch.io link (later the Steam and Play links), or put it in your bio. Reply to
   comments in the first hour.
4. **itch.io page**: embed the YouTube trailer; add `loop_fight.gif` to the screenshots.
5. **X / Bluesky / Reddit / Discord**: `trailer_60s.mp4` or a short as a video post; `loop_fight.webm` (or the
   GIF) for a quick loop. On X and Bluesky use `#indiedev #gamedev #pixelart #madewithgodot` (and
   `#WishlistWednesday` on Wednesdays).

## Say it is AI (the narrator's voice)

The narrator is not a person: it is an AI voice made with **Kokoro TTS** (open model, Apache-2.0 licence).
Being upfront costs nothing, and the stores ask for it.

- **Steam**: Steamworks > Content Survey > *AI Generated Content* > Pre-Generated. Add one sentence to what is
  already there: `The narration in the trailer is an AI-generated voice (Kokoro TTS, an open-weight
  text-to-speech model).`
- **TikTok**: when you post, open *More options* and turn on **AI-generated content**.
- **YouTube** (the trailer and the Shorts): on the Details page, *Altered or synthetic content*: choose **Yes**
  (the narrator is a realistic synthetic voice). Keep the "Narration: AI-generated voice" line in the description.
- **Instagram Reels**: *Advanced settings* > **Add AI label**.
- **itch.io**: the page's AI disclosure already says yes for sound; add "the trailer narration is an AI voice"
  to the description.

To use **your own voice** instead (or a voice clone you made of yourself): record the seven lines, put them in
`docs/marketing/voice/owner/` with the same file names, and run the command below. The steps are in
`docs/marketing/voice/ai_narrator/README.md`. With your real voice, the AI labels for the narration are no
longer needed (a clone of your own voice still counts as AI: keep the labels).

## Make them again (after any change to the game)

From the `wax-and-wane` folder:

```
./tools/make_trailer.sh all
```

1. It records the 15 staged scenes (the game plays itself under Godot's movie writer at 60 fps, each on a fresh,
   private save), cuts the trailer, the shorts and the loop, and then checks them. About 12 minutes on a
   4-core machine. The finished files land in `build/videos/`.
2. `COPY_TO=/some/folder ./tools/make_trailer.sh all` also copies the finished files there.
3. Smaller steps: `record <scene>` (one scene again), `edit` (cut again without recording), `stills` (fast
   contact sheets of every cut in `build/videos/stills/`), `check` (lengths, sizes, loudness, and the narration
   heard back by a speech recogniser from the finished mix).

It needs Godot 4.7.2, `xvfb-run`, `ffmpeg`, and Python 3 with Pillow, numpy and scipy. The narrator tools
(`voice`, `audition`, `voicecheck`, and the narration part of `check`) also need the voice kit, installed once
with `./tools/voice_setup.sh`.

## How it was checked
- **The voice**: a speech recogniser that never saw the script (Whisper small.en) wrote down every line: all
  seven came back word for word (0% word errors; table in `voice/ai_narrator/judge.md`). Each line is -16 LUFS
  with peaks under -1 dB, at 2.0 to 2.9 words a second.
- **The mix**: the same recogniser listened to the finished trailer and the narrated shorts, music and effects
  and all: every line still came through (0 to 10% word errors per line; the soft spots are two small words
  that run together in natural speech: "melts him" can be written "melts in", "win buys" as "whim buys"). The voice sits 13 to 26 dB over the music and
  effects while it speaks: the music ducks 14 dB, the effects 12 dB, and the speech band a further 8 dB.
- **The picture**: the game's own 384x216 frames scaled by whole numbers (x5, x10 for the close-up, x4 in the
  shorts), so every pixel stays square and sharp; the text is the game's own pixel font. No tips, hint lines,
  first-time achievement pop-ups or half-faded banners in any shot.
