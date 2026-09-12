"""Build embedded game cues from credited field recordings. Run with numpy + ffmpeg."""
from pathlib import Path
import json, subprocess, wave
import numpy as np
from audio_dsp import safe_peak, pcm_import

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'art/source'
OUT = ROOT / 'assets/audio/v2'
OUT.mkdir(parents=True, exist_ok=True)
RATE = 48000
metrics = {}

def read(name):
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(SRC/name), '-f', 'f32le', '-ar', str(RATE), '-ac', '2', '-'])
    return np.frombuffer(raw, np.float32).reshape(-1, 2).copy()

def peak(a, target=.78):
    return a * (target / max(float(np.max(np.abs(a))), 1e-8))

def ramp(a, attack=.004, release=.06):
    a = a.copy()
    i, j = min(len(a), int(attack*RATE)), min(len(a), int(release*RATE))
    if i: a[:i] *= np.linspace(0, 1, i)[:, None]
    if j: a[-j:] *= np.linspace(1, 0, j)[:, None]
    return a

def filter_audio(a, lo=50, hi=14000):
    # Padding keeps an impact's tail from wrapping into its opening transient.
    padded = np.pad(a, ((RATE,RATE),(0,0)))
    freq = np.fft.rfftfreq(len(padded), 1/RATE)
    gain = (1-np.exp(-(freq/lo)**4)) * np.exp(-(freq/hi)**4)
    return np.fft.irfft(np.fft.rfft(padded, axis=0)*gain[:,None], n=len(padded), axis=0)[RATE:-RATE]

def reverb(a, seconds=.7, wet=.13):
    result = np.zeros((len(a)+int(seconds*RATE), 2))
    result[:len(a)] = a
    for delay, gain in [(0.073, .7), (.139, .5), (.221,.34), (.337,.21), (.509,.12)]:
        start = int(delay*RATE)
        result[start:start+len(a)] += a[:,::-1] * gain * wet
    return result

def write(name, a, target=.80):
    # Keep the dry clack fast; edited swells and heavy impacts have gentler boundaries.
    a = peak(ramp(a, .0006 if name.startswith('stone_') else .003, .08), target)
    a = safe_peak(a)
    with wave.open(str(OUT/(name+'.wav')), 'wb') as f:
        f.setparams((2, 2, RATE, 0, 'NONE', 'not compressed'))
        f.writeframes((np.clip(a,-1,1)*32767).astype('<i2').tobytes())
    pcm_import(OUT/(name+'.wav'))
    metrics[name] = {'seconds': round(len(a)/RATE, 4), 'peak_dbfs': round(20*np.log10(np.max(abs(a))), 2), 'rms_dbfs': round(20*np.log10(np.sqrt(np.mean(a*a))), 2), 'stereo': True}

stone = read('komori-go-stone.mp3')
active = np.flatnonzero(np.max(abs(stone),axis=1) > np.max(abs(stone))*.008)
stone = stone[max(0, active[0]-48):min(len(stone),active[-1]+int(.04*RATE))]
for index, cutoff in enumerate([13000, 11500, 14500], 1):
    # Preserve the recorded dry stone attack; only subtle timbral / level variations.
    write(f'stone_{index:02d}', filter_audio(stone, 65, cutoff), [.78,.74,.81][index-1])

rain = read('forest-rain-673951.mp3')
assert len(rain) > 100*RATE, 'Incomplete field recording download'
rain = filter_audio(rain[30*RATE:94*RATE], 65, 10800)
cross = 4*RATE
blend = np.linspace(0,np.pi/2,cross)[:,None]
# The last four seconds cross into the opening, yielding a continuous 60 second loop.
rain[:cross] = rain[-cross:]*np.cos(blend)+rain[:cross]*np.sin(blend)
rain = peak(rain[:-cross], .58)
with wave.open(str(OUT/'rain-intermediate.wav'),'wb') as f:
    f.setparams((2,2,RATE,0,'NONE','not compressed'))
    f.writeframes((rain*32767).astype('<i2').tobytes())
subprocess.run(['ffmpeg','-v','error','-y','-i',str(OUT/'rain-intermediate.wav'),'-c:a','libvorbis','-q:a','6',str(OUT/'rain.ogg')],check=True)
(OUT/'rain-intermediate.wav').unlink()
metrics['rain'] = {'seconds':60,'stereo':True,'loop_crossfade_seconds':4,'boundary_delta':float(np.max(abs(rain[-1]-rain[0])))}

bow = read('bow-release-384915.mp3')
first = np.flatnonzero(np.max(abs(bow),axis=1) > np.max(abs(bow))*.025)[0]
bow = bow[max(0,first-int(.004*RATE)):]
bow = ramp(filter_audio(bow,80,15000), .001, .06)
write('bow_release', reverb(bow, .7,.18), .88)
drum = read('komori-drum.mp3')
drum_finish = read('komori-drum-finish.mp3')
write('impact', reverb(filter_audio(drum,32,7500),.7,.22),.87)
write('victory', reverb(filter_audio(drum_finish,38,9500),.7,.24),.76)

def stretch(a, duration):
    old = np.linspace(0,1,len(a))
    new = np.linspace(0,1,int(duration*RATE))
    return np.column_stack([np.interp(new,old,a[:,ch]) for ch in range(2)])

# Swells are edited air / drum transients, without synthetic note oscillators.
draw = filter_audio(stretch(bow[::-1],1.1), 160, 8500)
write('bow_draw', ramp(draw,.8,.06), .40)
charge = stretch(drum[::-1],2.0)
air = peak(filter_audio(rain[8*RATE:10*RATE],450,7500),.17)
write('charge', ramp(peak(filter_audio(charge,45,7500),.46)+air,.9,.025),.60)
moon = stretch(bow[::-1],1.8)
moon = filter_audio(moon,650,15000)
write('moon_rise', ramp(reverb(moon,.7,.4),.9,.4),.60)
write('moon_impact', reverb(filter_audio(drum,110,12500),1.0,.36),.78)
heavy = stretch(drum,3.0)
write('cosmos_impact', reverb(filter_audio(heavy,25,7500),1.1,.36),.93)
(ROOT/'verification/v2.2').mkdir(parents=True,exist_ok=True)
(ROOT/'verification/v2.2/audio-build.json').write_text(json.dumps(metrics,indent=2))
pcm_import(ROOT/'assets/audio/forest_harmonics.wav')
print(json.dumps(metrics,indent=2))
