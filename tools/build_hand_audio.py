"""Three silver-white hand cues, composed without changing the existing skills."""
from pathlib import Path
import hashlib
import json
import subprocess
import wave
import numpy as np
from audio_dsp import safe_peak, pcm_import

ROOT = Path(__file__).resolve().parents[1]
RATE = 48000
OUT = ROOT/'assets/audio/v2'
REPORT = ROOT/'verification/v2.7'


def decode(path):
    raw = subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-ar',str(RATE),'-ac','2','-'])
    return np.frombuffer(raw,'<f4').reshape(-1,2).astype('float64')


def process(a, filters):
    raw = subprocess.run(['ffmpeg','-v','error','-f','f32le','-ar',str(RATE),'-ac','2','-i','-',
        '-af',filters,'-f','f32le','-'],input=a.astype('<f4').tobytes(),capture_output=True,check=True).stdout
    return np.frombuffer(raw,'<f4').reshape(-1,2).astype('float64')


def fade(a, attack=.008, release=.13):
    a=a.copy()
    i,j=min(round(attack*RATE),len(a)),min(round(release*RATE),len(a))
    if i:a[:i]*=(np.sin(np.linspace(0,np.pi/2,i))**2)[:,None]
    if j:a[-j:]*=(np.cos(np.linspace(0,np.pi/2,j))**2)[:,None]
    return a


def normal(a, peak=.5):
    return a*peak/max(np.max(abs(a)),1e-9)


def pitch(a, ratio):
    return process(a,f'asetrate={round(RATE*ratio)},aresample={RATE}:filter_size=64')


def add(target, start, a, gain=1.0, pan=0.0):
    first=round(start*RATE)
    count=min(len(a),len(target)-first)
    if count>0:target[first:first+count]+=a[:count]*gain*np.array([np.sqrt(1-pan),np.sqrt(1+pan)])


def tone(frequency, seconds, gain):
    t=np.arange(round(seconds*RATE))/RATE
    a=np.sin(2*np.pi*frequency*t)*np.exp(-t/.55)
    a+=.2*np.sin(2*np.pi*frequency*2.74*t)*np.exp(-t/.19)
    return fade(np.column_stack((a,a))*gain,.004,.2)


stone=decode(OUT/'stone_02.wav')
wind=normal(process(decode(ROOT/'art/source/magic-whoosh-715784.mp3'),'highpass=f=260,lowpass=f=6200'))
ice=normal(process(decode(ROOT/'art/source/icy-cast-691005.mp3'),'highpass=f=360,lowpass=f=6200'))
slam=normal(process(decode(ROOT/'art/source/slam-691626.mp3'),'highpass=f=90,lowpass=f=4200'))
gather=np.zeros((round(1.70*RATE),2))
for i,start in enumerate((.03,.23,.43,.63,.80,.96,1.10,1.23,1.36)):
    tap=fade(pitch(stone,1.12+i*.045),.002,.12)
    add(gather,start,tap,.21+float(i)*.018,np.sin(i*.9)*.55)
add(gather,.05,fade(pitch(wind,.87),.18,.18),.30)
add(gather,.35,fade(ice[::-1][:round(1.3*RATE)],.35,.13),.17)
point=np.zeros((round(1.38*RATE),2))
add(point,0,tone(523.25,1.10,.075))
add(point,.12,fade(pitch(wind,1.32)[:round(.92*RATE)],.20,.14),.43)
add(point,.22,fade(pitch(ice,1.20)[:round(.85*RATE)],.17,.18),.13)
impact=np.zeros((round(2.85*RATE),2))
add(impact,0,stone,.95)
add(impact,.009,pitch(slam,.88),.56)
add(impact,.025,pitch(ice,.86),.42)
add(impact,.033,tone(164.81,1.7,.080))
add(impact,.11,tone(329.63,1.7,.040),1.0,.28)
add(impact,.15,fade(pitch(wind,.83),.04,.40),.19,-.20)
metrics={}
for name,a,peak in [('hand_gather',gather,.49),('hand_point',point,.42),('hand_impact',impact,.67)]:
    a=normal(fade(a),peak)
    a-=a.mean(axis=0)
    a=safe_peak(fade(a,.003,.15),-3.0)
    path=OUT/(name+'.wav')
    with wave.open(str(path),'wb') as f:
        f.setparams((2,2,RATE,0,'NONE','not compressed'))
        f.writeframes(np.rint(a*32767).astype('<i2').tobytes())
    pcm_import(path)
    metrics[name]={'seconds':len(a)/RATE,'peak_dbfs':float(20*np.log10(np.max(abs(a)))),
        'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
REPORT.mkdir(parents=True,exist_ok=True)
(REPORT/'hand-audio-build.json').write_text(json.dumps(metrics,indent=2)+'\n')
print(json.dumps(metrics,indent=2))
