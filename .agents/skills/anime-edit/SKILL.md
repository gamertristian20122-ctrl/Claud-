---
name: anime-edit
description: Make a beat-synced anime/character edit (AMV, fan edit, "edit of Gojo", phonk edit, TikTok/Shorts edit) from the user's own clips and a song, fully automated - beat and drop detection, shot detection, picking shots of the character, cuts on the beat, flash/zoom/shake/RGB-split on the drop, vertical crop, title, export under 30 MB. Use when the user asks to "make an edit of <character>", "edit these clips to this song", "make an AMV", "cut this to the beat", or similar.
---

# Anime edit (automated)

One script does the work: `scripts/anime_edit.py` (needs only ffmpeg, numpy, Pillow - all in the cloud container).
Your job is the part a script can't do: **look at the shots and choose the ones that show the character**,
then check the result before sending it.

## 0. Rules

- **Footage must come from the user**: files they attach or upload, files already in `edits/`, or a
  Google Drive link (use the Google Drive connector). Never download anime from YouTube, TikTok,
  streaming or torrent/pirate sites, and never use AI-generated footage made to look like the real show.
  If there are no clips, ask for them once: "attach a few clips or episodes you have (each under 30 MB)".
- **Song**: the user's file. If they have none, ask once; offer a free CC0 track or a generated one
  (the Abracadabrax music tool spends their credits, so only with a clear yes).
- Work in `/home/user/Claud-/edits/<short-name>/`. That folder is git-ignored: **never commit footage,
  songs or renders**.
- Don't ask about settings. Use the defaults below and mention them in one line at the end.

| Setting | Default | When to change |
| --- | --- | --- |
| Format | `vertical` 1080x1920 | `wide` for YouTube, `square` if asked |
| Length | 20 s, starts so the drop lands ~35% in | user asks; `--song-start` if they name a part of the song |
| Style | `hype` (fast cuts after the drop) | `smooth` for sad/slow songs |
| Grade | `cool` for blue-themed characters (Gojo), else `punchy` | `warm` for fire/sunset looks, `none` to keep the original colours |
| Title | the character's name in capitals on the last shot | user wants none, or `title_at: start` |

## 1. Analyse

```bash
S=/home/user/Claud-/.agents/skills/anime-edit/scripts
W=/home/user/Claud-/edits/gojo        # one folder per edit
python3 $S/anime_edit.py analyze --clips <files or folders> --song <song file> --work $W --length 20
```

It prints the BPM, the part of the song used and where the drop is, then writes
`$W/analysis.json` and `$W/sheet_01.jpg`, `sheet_02.jpg`, ... (30 numbered shots per sheet; the blue box
is what the vertical crop keeps; `mov` = how much motion the shot has).
An episode takes about a minute to scan.

## 2. Choose the shots (look at every sheet)

Write `$W/plan.json`:

```json
{
  "pool":    [3, 7, 12, 15, 21, 22, 30, 41, 44, 52],
  "hero":    41,
  "ramp":    30,
  "outro":   52,
  "exclude": [9, 10],
  "focus":   {"12": 0.25},
  "title":   "GOJO SATORU"
}
```

- `pool`: every shot where the character is clearly on screen and looks good. Aim for at least as many
  shots as cuts (about 1.3 cuts per second in `hype`). With too few, shots get reused.
- `hero`: the strongest moment. It lands on the drop, with the big flash and shake (for Gojo: Hollow
  Purple, Domain Expansion, the blindfold coming off, the eyes).
- `ramp`: a build-up shot played in slow motion just before the drop.
- `outro`: a clean, iconic pose or close-up for the ending and title.
- `exclude`: burned-in subtitles, credits, logos, censor bars, near-black frames.
- `focus`: when the blue box cuts off the character's face, move the crop: 0 = left edge, 1 = right edge.
- Optional: `order` (exact shot order, one per cut), `title_at` (`"start"` or `"end"`).
- Every number is checked against the analysis; a bad plan stops with a clear error.

If the user wants it with no input at all, skip the plan (or use `auto`, which runs analyse and render
together). It then picks the shots by motion, without knowing who is on screen.

## 3. Render

```bash
python3 $S/anime_edit.py render --work $W --plan $W/plan.json --grade cool --out $W/gojo_edit.mp4
```

About 5-8 s of work per second of edit. Output: the MP4 (H.264 + AAC, faststart), `$W/review.jpg`
(one frame from every cut) and `$W/edit.json` (the timeline: which shot on which frames, speed, crop).
Files over 30 MB are automatically re-encoded to fit.

## 4. Check, then send

1. Look at `review.jpg`: every cut should show the character, with no black frames, subtitles or faces
   cut off by the crop. Fix the plan (`exclude`, `focus`, `hero`) and render again if needed.
2. Send the MP4 with SendUserFile straight away, with a one-line caption (song part, length, style).
3. Tell the user in plain words what they can change ("say 'make it slower' or 'use shot 12 on the drop'").
   Add one short note: fan edits with anime clips and popular songs can be muted or claimed on TikTok/YouTube.

## What the edit does

- **Song**: finds the tempo and beats (weighted towards the kick/808, as edit music is bass-driven), the
  bars, and the drop (the biggest jump in loudness on a bar line).
- **Cuts**: every cut lands on a beat, one frame early so it feels on time. Before the drop: one cut per
  2 beats, then one slow-motion shot that pushes in and brightens. On the drop: white flash, zoom punch,
  shake and RGB split. After it: one cut per beat for two bars, then one per 2 beats, with smaller hits on
  the bar lines. The ending holds a bar, shows the title and fades to black with the music.
- **Shots**: finds hard cuts in the footage (colour-cycling effects are not mistaken for cuts), skips black
  or blank shots, and plays the busiest part of each shot. Never shows frames from the neighbouring shot.
- **Crop**: for vertical output it keeps the part of the frame with the most movement and detail
  (overridable with `focus`).

## Tests

```bash
python3 /home/user/Claud-/.agents/skills/anime-edit/scripts/test_anime_edit.py   # ~1.5 min, generated media only
```
