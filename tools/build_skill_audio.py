"""Build distinct, layered skill cues. Leaves stones, rain and thunder untouched."""
from pathlib import Path
import hashlib
import json
import subprocess
import wave
import numpy as np
from audio_dsp import safe_peak, pcm_import

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'art/source'
OUT = ROOT / 'assets/audio/v2'
REPORT = ROOT / 'verification/v2.6'
RATE = 48000
rng = np.random.default_rng(2600912)
metrics = {}
SOURCES = {
    'bow-release-384915.mp3': 'https://freesound.org/people/Ali_6868/sounds/384915/',
    'magic-whoosh-715784.mp3': 'https://freesound.org/people/DustyWind/sounds/715784/',
    'icy-cast-691005.mp3': 'https://freesound.org/people/DustyWind/sounds/691005/',
    'riser-691006.mp3': 'https://freesound.org/people/DustyWind/sounds/691006/',
    'slam-691626.mp3': 'https://freesound.org/people/DustyWind/sounds/691626/',
    'cinematic-impact-814885.mp3': 'https://freesound.org/people/AudioPapkin/sounds/814885/',
}


def read(name):
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(SRC/name),
        '-f', 'f32le', '-ar', str(RATE), '-ac', '2', '-'])
    return np.frombuffer(raw, '<f4').reshape(-1, 2).astype('float64')


def process(a, filters):
    p = subprocess.run(['ffmpeg', '-v', 'error', '-f', 'f32le', '-ar', str(RATE),
        '-ac', '2', '-i', '-', '-af', filters, '-f', 'f32le', '-'],
        input=a.astype('<f4').tobytes(), capture_output=True, check=True)
    return np.frombuffer(p.stdout, '<f4').reshape(-1, 2).astype('float64')


def band(a, low=60, high=8500):
    return process(a, f'highpass=f={low}:poles=2,lowpass=f={high}:poles=2')


def pitch(a, ratio):
    return process(a, f'asetrate={round(RATE*ratio)},aresample={RATE}:filter_size=64')


def fit(a, seconds):
    speed = len(a)/(RATE*seconds)
    factors = []
    while speed > 2: factors.append('atempo=2'); speed /= 2
    while speed < .5: factors.append('atempo=.5'); speed /= .5
    factors.append(f'atempo={speed}')
    b = process(a, ','.join(factors))
    return np.pad(b, ((0,max(0,round(seconds*RATE)-len(b))),(0,0)))[:round(seconds*RATE)]


def envelope(a, attack=.004, release=.10):
    b = a.copy()
    i, j = min(len(b), round(attack*RATE)), min(len(b), round(release*RATE))
    if i: b[:i] *= (np.sin(np.linspace(0,np.pi/2,i))**2)[:,None]
    if j: b[-j:] *= (np.cos(np.linspace(0,np.pi/2,j))**2)[:,None]
    return b


def level(a, peak=.5):
    return a * (peak/max(float(np.max(abs(a))),1e-9))


def trim(a, threshold=.012):
    active = np.flatnonzero(np.max(abs(a),axis=1) > np.max(abs(a))*threshold)
    return a[max(0,active[0]-48):]


def mix(seconds, *layers):
    result = np.zeros((round(seconds*RATE),2))
    for start, sound, gain in layers:
        first = round(start*RATE)
        length = min(len(sound),len(result)-first)
        if length > 0: result[first:first+length] += sound[:length]*gain
    return result


def space(a, wet=.12):
    # Short, decorrelated room reflections; the transient stays dry and centered.
    result = np.pad(a,((0,round(.55*RATE)),(0,0)))
    for delay, gain in ((.041,.5),(.083,.31),(.137,.20),(.223,.12),(.367,.065)):
        first = round(delay*RATE)
        result[first:first+len(a)] += a[:,::-1]*wet*gain
    return result


def resonator(hz, seconds, bright=.18):
    t = np.arange(round(seconds*RATE))/RATE
    mono = np.zeros(len(t))
    for ratio, gain, decay in ((1,1,1.05),(2.01,.45,.6),(2.76,bright,.34),(4.07,bright*.35,.16)):
        mono += gain*np.sin(2*np.pi*hz*ratio*t)*np.exp(-t/decay)
    return envelope(np.column_stack((mono,mono)), .004, .20)


def periodic_texture(seconds, low, high, amount=.5):
    # An exact periodic noise bed permits an arbitrary hold without a restart seam.
    count = round(seconds*RATE)
    f = np.fft.rfftfreq(count,1/RATE)
    spectrum = rng.normal(size=(len(f),2))+1j*rng.normal(size=(len(f),2))
    spectrum *= ((1-np.exp(-(f/low)**4))*np.exp(-(f/high)**4))[:,None]
    b = np.fft.irfft(spectrum,n=count,axis=0)
    b = .78*b.mean(axis=1,keepdims=True)+.22*b
    return level(b,amount)


def sustain(intro, loop, release=.18):
    # Join onto the preceding samples of the loop, then save a separate release
    # beyond loop_end for clean standalone audition. Runtime loops only the bed.
    blend = min(round(.16*RATE),len(intro),len(loop))
    w = (np.sin(np.linspace(0,np.pi/2,blend))**2)[:,None]
    intro = intro.copy()
    intro[-blend:] = intro[-blend:]*(1-w)+loop[-blend:]*w
    tail = loop[:round(release*RATE)].copy()
    tail *= (np.cos(np.linspace(0,np.pi/2,len(tail)))**2)[:,None]
    return np.concatenate((intro,loop,tail)), (len(intro)/RATE,(len(intro)+len(loop))/RATE)


def write(name, a, peak=.67, loop=None):
    a = level(envelope(a,.002,.10),peak)
    a -= np.mean(a,axis=0)
    a = envelope(a,.002,.10)
    a = safe_peak(a,ceiling_db=-3.0)
    OUT.mkdir(parents=True,exist_ok=True)
    p = OUT/(name+'.wav')
    with wave.open(str(p),'wb') as f:
        f.setparams((2,2,RATE,0,'NONE','not compressed'))
        f.writeframes(np.rint(a*32767).astype('<i2').tobytes())
    pcm_import(p)
    metrics[name] = {'seconds':len(a)/RATE,'peak_dbfs':round(float(20*np.log10(np.max(abs(a)))),3),
        'rms_dbfs':round(float(20*np.log10(np.sqrt(np.mean(a*a)))),3),'loop':loop,
        'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}


bow = level(trim(band(read('bow-release-384915.mp3'),100,10000)))
whoosh = level(band(read('magic-whoosh-715784.mp3'),180,7000))
ice = level(trim(band(read('icy-cast-691005.mp3'),230,7800)))
slam = level(trim(band(read('slam-691626.mp3'),70,5800)))
impact = level(trim(band(read('cinematic-impact-814885.mp3'),38,4800)))
riser = level(band(read('riser-691006.mp3'),90,2400))

# Bow: dry string tension, a crisp release and a separate short piercing hit.
bow_loop = periodic_texture(.64,190,820,.18)
t = np.arange(len(bow_loop))/RATE
bow_loop += .035*np.column_stack((np.sin(2*np.pi*187.5*t),np.sin(2*np.pi*187.5*t)))
draw_intro = envelope(fit(band(bow[round(.08*RATE):],180,1800),.50),.12,.04)
draw, loop = sustain(level(draw_intro,.22),bow_loop)
write('bow_draw',draw,.36,loop)
release = mix(.86,(0,bow,.95),(.018,pitch(whoosh,.88),.53),(.016,resonator(117,.4,.045),.048))
write('bow_release',space(release,.07),.68)
pierce = mix(1.20,(0,pitch(slam,.83),1.0),(.012,bow,.15),(.018,resonator(98,1.1,.08),.12))
write('impact',space(pierce,.10),.67)

# White moon: six soft metallic passes gather into one bright, spacious bloom.
orbit = np.zeros((round(2.05*RATE),2))
for i, start in enumerate((.02,.46,.86,1.18,1.43,1.63)):
    pass_sound = level(envelope(fit(whoosh,.42-.028*i),.04,.08),.19+.025*i)
    phase = np.linspace(i*np.pi/2,(i+1)*np.pi/2,len(pass_sound))
    pass_sound *= np.column_stack((np.sqrt(1-.5*np.sin(phase)),np.sqrt(1+.5*np.sin(phase))))
    orbit += mix(2.05,(start,pass_sound,.8))
orbit += mix(2.05,(.30,envelope(fit(ice[::-1],1.72),.6,.10),.38))
write('moon_rise',orbit,.49)
bloom = mix(2.65,(0,ice,.96),(.015,whoosh,.32),(.045,resonator(392,2.2,.10),.085),
    (.14,resonator(588,1.9,.06),.043),(.30,resonator(784,1.7,.035),.025))
write('moon_impact',space(bloom,.14),.67)

# Black cosmos: restrained rising pressure, sustained full charge, then a short
# inhalation and a deliberate gap before the board-contact impact.
charge_loop = periodic_texture(.80,48,460,.23)
t = np.arange(len(charge_loop))/RATE
for hz, gain in ((80,.038),(120,.019),(181.25,.010)):
    charge_loop += gain*np.sin(2*np.pi*hz*t)[:,None]
charge_intro = envelope(fit(riser,1.68),.30,.025)
charge_intro *= np.linspace(.18,.78,len(charge_intro))[:,None]
charge, loop = sustain(charge_intro,charge_loop)
write('charge',charge,.46,loop)
descent = mix(.87,(0,envelope(fit(pitch(whoosh,.58),.74),.25,.055),.8),
    (.10,envelope(fit(band(riser,60,1300),.72),.30,.045),.27))
write('cosmos_descent',descent,.50)
heavy = mix(3.00,(0,pitch(slam,.62),.70),(.008,impact,.90),(.005,bow,.25),
    (.026,resonator(55,2.1,.04),.15),(.12,envelope(pitch(whoosh,.52),.055,.7),.27))
write('cosmos_impact',space(heavy,.08),.69)

# A short closing seal replaces the long drum flourish on a normal victory.
seal = mix(1.65,(0,pitch(slam,.9),.36),(.045,resonator(196,1.5,.12),.12),
    (.21,resonator(294,1.25,.10),.09))
write('victory',space(seal,.12),.48)

REPORT.mkdir(parents=True,exist_ok=True)
report = {'cues':metrics,'sources':{name:{'page':url,'license':'CC0-1.0',
    'sha256':hashlib.sha256((SRC/name).read_bytes()).hexdigest()} for name,url in SOURCES.items()},
    'method':'Edited CC0 recordings/design elements, modal resonances, periodic noise; peak scaling reserves headroom without clipping.'}
(REPORT/'skill-audio-build.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(metrics,indent=2))
