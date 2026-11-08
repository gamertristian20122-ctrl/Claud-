#!/usr/bin/env bash
# Wax & Wane: makes the narrator's Python once (about 1.5 GB in ~/.cache/waxandwane/voice_venv):
# Python 3.12 (Kokoro needs < 3.13), PyTorch for the CPU, Kokoro TTS + misaki (English), faster-whisper (the
# judge), pyloudnorm, soundfile and spaCy's small English model. The model weights (Kokoro-82M, Whisper
# small.en) download from huggingface.co on first use. Needs `uv` (https://docs.astral.sh/uv/).
#
#   ./tools/voice_setup.sh            then:  ./tools/make_trailer.sh voice
set -euo pipefail
V="${VOICE_VENV:-$HOME/.cache/waxandwane/voice_venv}"
PY312="$(command -v python3.12 || true)"
if [ ! -x "$V/bin/python" ]; then
	uv venv --python "${PY312:-3.12}" "$V"
fi
uv pip install --python "$V/bin/python" torch --index-url https://download.pytorch.org/whl/cpu
uv pip install --python "$V/bin/python" "kokoro==0.9.4" "misaki[en]==0.9.4" soundfile faster-whisper pyloudnorm scipy num2words
uv pip install --python "$V/bin/python" \
	"en_core_web_sm@https://github.com/explosion/spacy-models/releases/download/en_core_web_sm-3.8.0/en_core_web_sm-3.8.0-py3-none-any.whl"
"$V/bin/python" -c "import kokoro, faster_whisper, pyloudnorm, soundfile, en_core_web_sm; print('[voice_setup] ok:', '$V')"
