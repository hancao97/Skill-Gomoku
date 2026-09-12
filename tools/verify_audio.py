"""Measure decoded assets and the actual Godot master capture; never normalize QA audio."""
from pathlib import Path
import json
import subprocess
import sys
import numpy as np
from audio_dsp import true_peak

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'verification/v2.2'
OUT.mkdir(parents=True, exist_ok=True)
RATE = 48000
failures = []


def decode(path):
    data = subprocess.check_output([
        'ffmpeg', '-v', 'error', '-i', str(path), '-ar', str(RATE), '-ac', '2',
        '-f', 'f32le', 'pipe:1'])
    return np.frombuffer(data, '<f4').reshape(-1, 2)


def db(value):
    return round(float(20 * np.log10(max(float(value), 1e-12))), 3)


def stats(a):
    return {
        'seconds': round(len(a) / RATE, 4),
        'sample_peak_dbfs': db(np.max(np.abs(a))),
        'true_peak_4x_dbtp': db(true_peak(a)),
        'rms_dbfs': db(np.sqrt(np.mean(a.astype('float64') ** 2))),
        'dc_offset': [round(float(v), 8) for v in np.mean(a, axis=0)],
        'clipped_samples': int(np.sum(np.abs(a) >= 32767/32768)),
    }


report = {'assets': {}, 'failures': failures, 'measurement': '48 kHz decode; 192 kHz sinc reconstruction; no gain changes'}
assets = sorted((ROOT/'assets/audio/v2').glob('*.wav'))
assets += [ROOT/'assets/audio/v2/rain.ogg', ROOT/'assets/audio/forest_harmonics.wav']
for path in assets:
    a = decode(path)
    row = stats(a)
    if path.stem in ('rain', 'forest_harmonics'):
        # A loop seam must be no sharper than ordinary neighboring audio samples.
        row['loop_seam_delta'] = float(np.max(np.abs(a[0]-a[-1])))
        row['normal_delta_p999'] = float(np.quantile(np.abs(np.diff(a,axis=0)),.999))
        if row['loop_seam_delta'] > max(.0001, row['normal_delta_p999']*1.5):
            failures.append(path.name+': discontinuous loop seam')
    else:
        row['endpoint_peak'] = float(np.max(np.abs(a[[0,-1]])))
        if row['endpoint_peak'] > .0001:
            failures.append(path.name+': nonzero cue boundary')
    if row['clipped_samples'] or row['true_peak_4x_dbtp'] > -1.98:
        failures.append(path.name+': insufficient source headroom')
    if max(abs(v) for v in row['dc_offset']) > .002:
        failures.append(path.name+': DC offset')
    report['assets'][path.name] = row

mix_path = OUT/'engine-mix.wav'
if mix_path.exists():
    a = decode(mix_path)
    report['engine_mix'] = stats(a)
    meta = json.loads((OUT/'audio-playback.json').read_text())
    sections = []
    for i, mark in enumerate(meta['markers']):
        end = meta['markers'][i+1]['seconds'] if i+1<len(meta['markers']) else len(a)/RATE
        take = a[int(mark['seconds']*RATE):int(end*RATE)]
        if len(take):sections.append({'label':mark['label'],**stats(take)})
    report['sections'] = sections
    if report['engine_mix']['clipped_samples'] or report['engine_mix']['true_peak_4x_dbtp'] > -1.5:
        failures.append('engine mix: exceeded reconstruction safety ceiling')
    if report['engine_mix']['sample_peak_dbfs'] > -1.98:
        failures.append('engine mix: limiter exceeded its sample ceiling')
    # The stress section must actually exercise the limiter, not merely be silent.
    stress = next(s for s in sections if s['label']=='limiter-stress')
    if stress['sample_peak_dbfs'] < -2.2:
        failures.append('stress mix did not reach the limiter')
    report['final_silence_peak_dbfs'] = db(np.max(np.abs(a[-int(.3*RATE):])))
    if report['final_silence_peak_dbfs'] > -75:
        failures.append('audio did not settle to silence')
else:
    report['engine_mix'] = 'pending runtime capture'

(OUT/'audio-measurements.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps({'assets':len(assets),'engine_mix':report['engine_mix'],'failures':failures},indent=2))
sys.exit(1 if failures else 0)
