"""Cut five real Yunzi-on-wood impacts from billhails2's CC0 recording.

Source: https://freesound.org/people/billhails2/sounds/588317/
Requires ffmpeg; source recording is retained in art/source.
Only onset trimming, DC removal, gain and a tail fade are applied.
"""
import array
import io
import math
from pathlib import Path
import shutil
import subprocess
import wave

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/source/go-stones-588317.mp3"
OUTPUT = ROOT / "assets/audio"
ffmpeg = shutil.which("ffmpeg") or "/usr/local/bin/ffmpeg"
decoded = subprocess.run(
    [ffmpeg, "-hide_banner", "-loglevel", "error", "-i", str(SOURCE),
     "-ac", "1", "-ar", "44100", "-f", "wav", "pipe:1"],
    check=True, capture_output=True).stdout
with wave.open(io.BytesIO(decoded), "rb") as recording:
    rate = recording.getframerate()
    samples = array.array("h", recording.readframes(recording.getnframes()))

cuts = []
for index, (start, end) in enumerate([(0,.75), (1.2,2), (2.5,3.4), (4.9,5.65), (6,6.9)],1):
    region = samples[int(start*rate):int(end*rate)]
    peak = max(abs(v) for v in region)
    onset = next(i for i,v in enumerate(region) if abs(v) > peak*.08)
    first = max(0,onset-int(.002*rate))
    take = list(region[first:first+int(.42*rate)])
    dc = sum(take)/len(take)
    gain = .82*32767/max(abs(v-dc) for v in take)
    fade_length = int(.085*rate)
    cut = array.array("h")
    for i,v in enumerate(take):
        tail = min(1.0,(len(take)-1-i)/fade_length)
        head = min(1.0,i/(rate*.0004))
        cut.append(round((v-dc)*gain*tail*head))
    path = OUTPUT / f"stone_{index:02d}.wav"
    with wave.open(str(path),"wb") as wav:
        wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(rate)
        wav.writeframes(cut.tobytes())
    cuts.append(cut)
    import_settings = path.with_suffix(".wav.import")
    if import_settings.exists():
        import_settings.write_text(import_settings.read_text().replace("compress/mode=2","compress/mode=0"))
    print(f"{path.name}: {len(cut)/rate:.3f}s, peak {max(abs(v) for v in cut)/32768:.3f}, impact lead 2ms")

# A short dry audition, excluded from the release export.
with wave.open(str(ROOT / "verification/stone-audition.wav"),"wb") as wav:
    wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(rate)
    for cut in cuts:
        wav.writeframes(cut.tobytes())
        wav.writeframes(bytes(int(rate*.22)*2))
