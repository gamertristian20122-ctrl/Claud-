# The AI narrator (trailer and shorts)

These seven files are the narration of the trailer and the vertical shorts. **They are an AI voice**, made
on this machine, not a person reading.

| | |
|---|---|
| Model | **Kokoro-82M** (`hexgrad/Kokoro-82M` on Hugging Face), open weights, **Apache-2.0** licence. Words to sounds: **misaki** (Apache-2.0). Licence text: `assets/licenses/Kokoro_TTS_Apache-2.0.txt` |
| Voice | `am_michael` (an American male voice), speed 0.86 (line 2 a little slower: 0.88 of that) |
| Picked from | `bm_george`, `bm_fable` (British male), `am_michael` (American male), `af_heart` (American female). All four read every line right; `am_michael` was the warmest *clear* voice: the deepest pitch, the best clarity score and the most presence (it stays clear over music). `bm_george` sounded very dark/boomy, `bm_fable` had a buzzy top end (9% of its energy above 7 kHz) |
| Files | 24 kHz mono WAV, one per line, silence trimmed, each at **-16 LUFS** with peaks under -1 dB |
| Checked by | a speech recogniser that has never seen the script (**Whisper small.en** via faster-whisper): every line has to come back almost word for word (word error rate 10% or less). The table is in `judge.md` (all 0%) |

The lines, in order (the same as `../script.json`):

1. `01_this_is_tallow.wav` - This is Tallow. Tallow is a candle.
2. `02_midnight.wav` - At midnight, the house wakes up.
3. `03_wax_is_health.wav` - His wax is his health. His wax is also his clock.
4. `04_every_hit.wav` - Every hit melts him faster. Every win buys him time.
5. `05_four_floors.wav` - Four floors. One secret.
6. `06_done_by_two.wav` - Be done by two... or burn out trying.
7. `07_light_the_wick.wav` - Wax and Wane. Light the wick.

## Use your own voice instead

1. Make a folder `docs/marketing/voice/owner/`.
2. Record the seven lines (a phone voice memo is fine: a quiet room, the phone a hand's width from your
   mouth). Save each as its own file with the **same name** as above. `.wav`, `.m4a` or `.mp3` all work,
   e.g. `01_this_is_tallow.m4a`.
3. Check and level them: `./tools/make_trailer.sh voicecheck docs/marketing/voice/owner --fix`
   (it trims the silence, sets each line to -16 LUFS, writes `.wav` files and tells you if a word was unclear).
4. Re-make the videos: `./tools/make_trailer.sh edit`. When all seven files are in `owner/`, the edit uses
   them instead of this folder (to force a folder: `VOICE=docs/marketing/voice/ai_narrator ./tools/make_trailer.sh edit`).

Longer or shorter readings are fine: each shot under a line stretches to fit it.

## Make these files again

`./tools/voice_setup.sh` once (a Python 3.12 venv in `~/.cache/waxandwane/voice_venv`, ~1.5 GB), then
`./tools/make_trailer.sh voice` (or `audition` to hear four voices side by side in `build/voice_audition/`).

## Say it is AI

When you post the videos, say the narration is AI-generated (see `docs/marketing/videos.md`: Steam's AI
content survey, TikTok's "AI-generated content" switch, YouTube's "altered or synthetic content" question).
