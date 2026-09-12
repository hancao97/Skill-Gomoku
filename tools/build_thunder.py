"""Edit Taira Komori field recordings into two short, stereo placement thunder cues."""
from pathlib import Path
import json, subprocess, wave
import numpy as np
from audio_dsp import safe_peak, pcm_import

ROOT = Path(__file__).resolve().parents[1]
RATE = 48000
OUT = ROOT/'assets/audio/v2'

def read(name):
    raw = subprocess.check_output(['ffmpeg','-v','error','-i',str(ROOT/'art/source'/name),'-f','f32le','-ar',str(RATE),'-ac','2','-'])
    return np.frombuffer(raw,np.float32).reshape(-1,2).copy()

def band(a, low, high):
    # Zero padding prevents the opening attack wrapping around to the tail.
    padded = np.pad(a, ((RATE,RATE),(0,0)))
    hz = np.fft.rfftfreq(len(padded),1/RATE)
    transfer = (1-np.exp(-(hz/low)**4))*np.exp(-(hz/high)**4)
    return np.fft.irfft(np.fft.rfft(padded,axis=0)*transfer[:,None],n=len(padded),axis=0)[RATE:-RATE]

def normalize(a, peak):
    return a*peak/max(np.max(abs(a)),1e-8)

tail = band(read('komori-thunder.mp3')[4*RATE:8*RATE],35,750)
report = []
for i in (1,2):
    recording = read(f'komori-lightning{i}.mp3')
    blocks = recording[:len(recording)//480*480].reshape(-1,480,2)
    rms = np.sqrt(np.mean(blocks**2,axis=(1,2)))
    onset = max(0,int(np.flatnonzero(rms>rms.max()*.2)[0]*480)-int(.006*RATE))
    clip = band(recording[onset:onset+int(3.25*RATE)],45,10500)
    clip = normalize(clip,.8)
    rumble = normalize(tail[:len(clip)],.13)
    t = np.arange(len(clip))/RATE
    clip += rumble*np.minimum(t/.16,1)[:,None]*np.exp(-t*.6)[:,None]
    envelope = np.minimum(t/.0025,1) * np.clip((3.25-t)/.85,0,1)
    clip = safe_peak(normalize(clip*envelope[:,None],.82))
    filename = f'thunder_{i:02d}.wav'
    with wave.open(str(OUT/filename),'wb') as f:
        f.setparams((2,2,RATE,0,'NONE','not compressed'))
        f.writeframes((clip*32767).astype('<i2').tobytes())
    pcm_import(OUT/filename)
    report.append({'file':filename,'source_start_seconds':onset/RATE,'seconds':len(clip)/RATE,'rate':RATE,'channels':2,'peak_dbfs':float(20*np.log10(np.max(abs(clip)))),'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(clip*clip))))})
(ROOT/'verification/v2.2').mkdir(parents=True,exist_ok=True)
(ROOT/'verification/v2.2/thunder-build.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
