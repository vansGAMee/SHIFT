#!/usr/bin/env python3
"""Deterministic original electronic score and narrative cues. No samples."""
from pathlib import Path
import subprocess
import wave
import numpy as np

OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
SR = 22050
RNG = np.random.default_rng(140513)

def write(name, data, ogg=False):
    data = np.asarray(data)
    data = data / max(1.0, np.abs(data).max()) * .65
    if data.ndim == 1:
        data = np.stack([data, .95 * data + .05 * np.roll(data, 137)], axis=1)
    path = OUT / (name + '.wav')
    with wave.open(str(path), 'wb') as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes((np.clip(data, -1, 1) * 32767).astype('<i2').tobytes())
    if ogg:
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(path), '-c:a', 'libvorbis', '-q:a', '4', str(path.with_suffix('.ogg'))], check=True)
        path.unlink()

def chime(freq, duration=3):
    t = np.arange(int(SR * duration)) / SR
    envelope = (1 - np.exp(-t * 30)) * np.exp(-t * 1.4)
    return (np.sin(t * freq * 2*np.pi) + .2 * np.sin(t * freq * 4*np.pi + .07)) * envelope

t = np.arange(SR * 64) / SR
score = np.zeros_like(t)
for i, base in enumerate([55, 65.4064, 49, 58.2705]):
    section = np.zeros_like(t)
    local = t - i*16
    window = np.sin(np.clip(local/16, 0, 1)*np.pi)**2
    for partial, gain in [(1,.16), (2,.08), (3,.035), (4.005,.025)]:
        section += gain*np.sin(2*np.pi*base*partial*t + .13*np.sin(t*.19))
    score += section*window
for start, freq in [(8,220),(11,261.6256),(14,196),(40,220),(43,261.6256),(46,196)]:
    note = chime(freq,7)*.19
    a = start*SR
    score[a:a+len(note)] += note
score *= .8+.2*np.cos(t*2*np.pi/64)
write('score', score, ogg=True)
memory=np.zeros(SR*5)
for delay,freq in [(0,440),(.7,523.251), (1.4,392)]:
    note=chime(freq,3)*.35
    a=int(delay*SR)
    memory[a:a+len(note)]+=note
write('memory',memory)
t=np.arange(SR*3)/SR
ring=(np.sin(2*np.pi*440*t)+.6*np.sin(2*np.pi*480*t))*.23
ring*=((t%.8)<.35)*np.minimum(t*20,1)*np.minimum((3-t)*10,1)
write('ring',ring)
t=np.arange(SR*4)/SR
noise=RNG.normal(0,1,len(t))
low=np.convolve(noise,np.ones(70)/70,'same')
blast=(low*3+np.sin(2*np.pi*(48*t-3*t*t))*.3)*np.exp(-t*1.3)*np.minimum(t*100,1)
write('wall_break',blast)
print('Original score and three cues generated')
