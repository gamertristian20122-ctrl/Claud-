---
name: anime-edit
description: Make a beat-synced anime/character edit (AMV, fan edit, "edit of Gojo", phonk/velocity edit, TikTok/Shorts edit) from clips and a song, fully automated - beat and drop detection, shot detection, picking shots of the character, speed ramps, a moving camera with motion blur, zoom/spin/whip/glitch/flash transitions, lyric text that pops in word by word, captions, colour grade, 60 fps, export under 30 MB. Use when the user asks to "make an edit of <character>", "edit these clips to this song", "make an AMV", "cut this to the beat", or shares an edit to match or beat.
---

# Anime edit (automated)

One engine does the work: `scripts/anime_edit.py` (+ `scripts/fx.py` for the effects).
Your job is the part a script can't do: **look at the shots, choose the ones that show the character,
write the plan, and check the result before sending it.**

## 0. Setup and rules

- Needs ffmpeg, numpy, Pillow and OpenCV: `python3 -m pip install --user opencv-python-headless`.
  For lyric timing also `python3 -m pip install --user faster-whisper` (downloads a Whisper model once).
- **Footage**: the user's files (attachments, Google Drive, `edits/`). The owner uses edits for personal
  viewing only. YouTube blocks downloads from the cloud container ("Sign in to confirm you're not a bot"),
  so ask the user to put clips in a Google Drive file/folder shared "Anyone with the link" and download it with
  `curl -L "https://drive.usercontent.google.com/download?id=<FILE_ID>&export=download&confirm=t" -o clip.mp4`.
  "Raw clips / twixtor" dumps (one long video of many shots) work best: one file gives 100+ shots.
- **Song**: the user's file. A shared example edit's audio can be reused: `ffmpeg -i example.mp4 -vn -c:a copy song.m4a`.
- Work in `/home/user/Claud-/edits/<short-name>/` (git-ignored: **never commit footage, songs or renders**).
- Don't ask about settings. Use the defaults and mention them in one line at the end.

| Setting | Default | When to change |
| --- | --- | --- |
| Format | `vertical` 1080x1920 | `wide` for YouTube, `square` if asked |
| Length | 20 s, starting so the drop lands ~35% in | user asks; `--length <song length> --song-start 0` for a whole short song |
| Frame rate | 60 fps for 50+ fps footage (twixtor), else 30 | `--fps` |
| Style | `hype` (velocity ramps, strong camera, fast cuts after the drop) | `smooth` for sad/slow songs |
| Grade | `purple` / `cool` for Gojo, `punchy` otherwise | `warm` (fire, sunsets), `none` |
| Title | the character's name in capitals on the last shot | user wants none, or `title_at: start` |

## 1. Analyse (once per set of clips)

```bash
S=/home/user/Claud-/.agents/skills/anime-edit/scripts
W=/home/user/Claud-/edits/gojo
python3 $S/anime_edit.py analyze --clips <files or folders> --song <song> --work $W --length 20
python3 $S/anime_edit.py song --work $W --song <other song> --length 12 --song-start 0   # new song, no rescan
python3 $S/anime_edit.py lyrics --work $W --language en      # if the song has words: writes $W/lyrics.json
```

`analyze` prints BPM, the part of the song used and the drop, then writes `analysis.json` and
`sheet_01.jpg`... (30 numbered shots per sheet; the blue box is what the vertical crop keeps).
About 2 minutes for a 9-minute dump.

## 2. Choose the shots (look at every sheet) and write `$W/plan.json`

To know how many cuts there are (to write an exact `order`):
`python3 -c "import json,sys; sys.path.insert(0,'$S'); import anime_edit as ae; A=json.load(open('$W/analysis.json')); [print(i+1,s['kind'],round(s['f0']/60,2),round(s['dur'],2)) for i,s in enumerate(ae.build_slots(A['song'],'hype',60))]"`

```json
{
  "order":   [41, 153, 158, 156, 164, 160, 55, 58, 17, 60, 12, 36, 68, 26],
  "focus":   {"158": 0.35, "26": 0.35},
  "lyrics":  [{"text": "MAHORAGA GOT ME A TABLET!", "start": 0.0, "end": 2.0, "times": [0.0, 0.94, 1.16, 1.34, 1.5]}],
  "captions": {"158": "HOLLOW PURPLE"},
  "transitions": {"7": "spin"},
  "accent":  "#a970ff",
  "title":   "GOJO SATORU"
}
```

- `order`: one shot per cut, in order (or `pool` + `hero`/`ramp`/`outro` to let the engine arrange them).
  Cut 1 = calm establishing shot under the lyrics, the `ramp` cut = a build-up shot (played slowing down into the
  drop), the `drop` cut = the strongest moment (for Gojo: Hollow Purple), then the fast 1-beat hits, then 2-beat
  bigger moments, and the outro = an iconic close-up for the title.
- **Keep one colour story** (e.g. blue/purple for Gojo): don't drop a gold or green shot in the middle.
- `focus`: when the blue box misses the face, 0 = left edge, 1 = right edge. Check the review sheet.
- `lyrics`: copy from `lyrics.json`, fix the spelling (Whisper wrote "MAHARAGA"), times are edit seconds.
- `captions`: big text that slams in on a shot (technique names).
- `transitions`: force a transition into cut N: `cut`, `flash`, `zoom`, `spin`, `whip`, `glitch`.
- `exclude`: subtitles, credits, logos, black frames. Every value is validated; a bad plan stops with an error.

## 3. Render, check, send

```bash
python3 $S/anime_edit.py render --work $W --plan $W/plan.json --grade purple --out $W/gojo_edit.mp4
```

About 10 s of work per second of 60 fps edit. Output: the MP4 (H.264 + AAC, shrunk under 30 MB if needed),
`review.jpg` (one frame per cut) and `edit.json` (every cut: frames, shot, speed ramp, camera move, transitions).

1. Look at a 4-fps contact sheet of the whole edit, not just `review.jpg`:
   `ffmpeg -i out.mp4 -vf "fps=4,scale=160:-2,tile=10x5" -frames:v 1 sheet.jpg`. Check: character on every cut,
   faces not cropped off, one colour story, text readable, no black/mirrored edges, ending fades out.
2. Fix the plan and render again if needed, then send the MP4 with SendUserFile straight away.
3. Tell the user in plain words what they can ask for ("slower", "use shot 12 on the drop", "no text").

## What the engine does (and why)

Measured from a strong reference edit (YouTube Short, 117 BPM) and the editing rules in
iart-ai/motion-design-skills (beat-sync-editing, MIT):

- **Arc**: long holds to establish (one bar per shot, lyrics on top), a 2-beat slow-motion ramp into the drop,
  1-beat hits for two bars, then 2-beat cuts, one held bar to end. Every cut lands on a beat, one frame early.
- **Speed ramps (velocity)**: hits play slow on the beat and fast in between (0.45x -> 2.4x -> 0.45x);
  the ramp slows to 0.3x exactly on the drop; fast parts blend frames (natural motion blur).
- **Camera**: every shot moves (push, punch-in, pull-out, tilt, drift), with impact shake on downbeats and a
  light handheld shake after the drop; never shows past the frame edge (auto cover zoom); motion blur on fast moves.
- **Transitions**: the exit of one shot continues into the entry of the next (zoom, spin, whip), glitch on the
  drop, white flashes on hits.
- **Look**: grade (ffmpeg), glow/bloom on bright areas, RGB split on hits, film grain, vignette; lyrics in the
  Anton font (OFL, `assets/fonts/`) with a glow in the accent colour, last word of each line in the accent colour.

## Tests

```bash
python3 /home/user/Claud-/.agents/skills/anime-edit/scripts/test_anime_edit.py   # ~2 min, generated media only
```
