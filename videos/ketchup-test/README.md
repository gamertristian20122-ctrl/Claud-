# Ketchup test short (10 s, 9:16)

A free test of the "cartoon history short" format: our own characters, drawn as SVG
puppets (separate head, arms, hands, props), animated with GSAP and rendered by HyperFrames.

- Voice: Kokoro `am_michael` (free, runs on this machine). Swap `assets/voice.wav` for a
  cloned voice later, then re-run the transcript step so captions keep their timing.
- Sound effects: made from scratch by `tools/sfx.py` (no samples, no licences).
- Fact: in 1834 Dr John Cook Bennett promoted tomatoes as a cure for indigestion, and
  tomato ketchup was then sold as medicine.

## Rebuild

```
python3 tools/sfx.py            # sound effects -> assets/sfx/
python3 tools/build.py          # scenes -> index.html, compositions/
npx hyperframes@0.9.9 check
npx hyperframes@0.9.9 render -q delivery -o renders/ketchup-test.mp4
ffmpeg -i renders/ketchup-test.mp4 -c:v copy -af loudnorm=I=-14:TP=-1.5:LRA=11 -c:a aac -b:a 192k out.mp4
```

Free voice setup: `python3 -m venv kvenv && kvenv/bin/pip install kokoro-onnx soundfile`, then
`HYPERFRAMES_PYTHON=$PWD/kvenv/bin/python npx hyperframes@0.9.9 tts "<script>" -v am_michael -s 1.12 -o assets/voice.wav`.
