"""Cut a listening reel from the real engine mix without changing playback gain."""
from pathlib import Path
import argparse
import json
import re
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
version = re.search(r'^config/version="(\d+\.\d+)\.',(ROOT/'project.godot').read_text(),re.M).group(1)
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output-dir',type=Path,default=ROOT/'verification'/('v'+version))
out = parser.parse_args().output_dir.resolve()
meta = json.loads((out/'audio-playback.json').read_text())
marks = {m['label']:m['seconds'] for m in meta['markers']}
with wave.open(str(out/'engine-mix.wav'),'rb') as f:
    params = f.getparams()
    assert params.sampwidth==2 and params.nchannels==2
    rate = params.framerate
    recording = np.frombuffer(f.readframes(f.getnframes()),'<i2').reshape(-1,2)


def write(name, data):
    with wave.open(str(out/(name+'.wav')),'wb') as f:
        f.setparams(params)
        f.writeframes(data.astype('<i2').tobytes())


reel = []
manifest = []
offset = 0.0
tracks=[('bow','moon','会挽雕弓如满月'),('moon','cosmos','遥遥领先'),
    ('cosmos','divine-hand' if 'divine-hand' in marks else 'victory-and-next-round','天地大同')]
if 'divine-hand' in marks:tracks.append(('divine-hand','victory-and-next-round','神之一手'))
for key, end, title in tracks:
    start = marks[key+'-performance']
    stop = marks[end]
    part = recording[round(start*rate):round(stop*rate)].astype('float64')
    # Only soften edit boundaries; preserve the engine's gain and inner dynamics.
    fade = min(round(.015*rate),len(part)//2)
    part[:fade] *= np.linspace(0,1,fade)[:,None]
    part[-fade:] *= np.linspace(1,0,fade)[:,None]
    part = np.rint(part).astype('<i2')
    write(key+'-preview',part)
    manifest.append({'title':title,'offset_seconds':round(offset,3),'duration':len(part)/rate,
        'engine_start':start,'engine_end':stop,'file':key+'-preview.wav'})
    reel.extend((part,np.zeros((round(.7*rate),2),dtype='<i2')))
    offset += len(part)/rate+.7
write('skills-preview',np.concatenate(reel[:-1]))
(out/'skills-preview.json').write_text(json.dumps({'source':'engine-mix.wav','gain_changed':False,
    'edit_fades_ms':15,'tracks':manifest},ensure_ascii=False,indent=2)+'\n')
print(json.dumps(manifest,ensure_ascii=False,indent=2))
