#!/usr/bin/env python3
"""Original deterministic sound design for SHIFT. Requires numpy/scipy/ffmpeg."""
from pathlib import Path
import argparse
import shutil
import subprocess
import wave
import numpy as np
from scipy.signal import butter, sosfiltfilt

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "audio"
OUT.mkdir(parents=True, exist_ok=True)
SR = 22050
rng = np.random.default_rng(5317)
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--new-only", action="store_true", help="Only rebuild the final report and new pressure-system sounds; preserve the original prologue audio.")
args = parser.parse_args()
UPDATED = {"shot", "pressure_warning", "pressure_release", "power_drop", "pressure_bed"}


def time(seconds):
    return np.arange(round(seconds * SR)) / SR


def noise(seconds, low=20, high=6000):
    x = rng.normal(0, 1, round(seconds * SR))
    sos = butter(3, [low, high], btype="bandpass", fs=SR, output="sos")
    return sosfiltfilt(sos, x)


def soften(x, attack=.012, release=.08):
    x = x.copy()
    a = min(round(attack * SR), len(x))
    b = min(round(release * SR), len(x))
    x[:a] *= np.linspace(0, 1, a) ** 1.5
    x[-b:] *= np.linspace(1, 0, b) ** 1.5
    return x


def reverb(x, wet=.12):
    y = np.pad(x, (0, round(.65 * SR)))
    for delay, gain in [(.059, .8), (.101, .57), (.163, .41), (.271, .29), (.413, .17)]:
        n = round(delay * SR)
        y[n:n+len(x)] += x * gain * wet
    return y


def write(name, x, peak=.75, ogg=False):
    if args.new_only and name not in UPDATED:
        return
    x = np.asarray(x)
    if x.ndim == 1:
        # Subtle natural stereo reflections without a wide, distracting image.
        left = x.copy()
        right = x * .96 + np.roll(x, 61) * .04
        x = np.stack((left, right), axis=1)
    x = x / max(np.max(np.abs(x)), 1e-9) * peak
    dest = OUT / (name + ".wav")
    with wave.open(str(dest), "wb") as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
    if ogg:
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", str(dest), "-c:a", "libvorbis", "-q:a", "4", str(dest.with_suffix(".ogg"))], check=True)
        dest.unlink()


def periodic_air(seconds, seed, hi=1800):
    local_rng = np.random.default_rng(seed)
    n = round(seconds * SR)
    freqs = np.fft.rfftfreq(n, 1 / SR)
    weights = np.exp(-freqs / hi) / np.maximum(freqs, 25) ** .65
    weights[freqs < 28] = 0
    phases = local_rng.uniform(0, np.pi * 2, len(freqs))
    x = np.fft.irfft(weights * np.exp(1j * phases), n)
    return x / np.sqrt(np.mean(x*x))


# The large ambience arrays are strictly periodic: no join/pop every loop.
t = time(32)
wind_l = periodic_air(32, 200, 1250)
wind_r = periodic_air(32, 206, 1400)
swells = .53 + .14 * np.sin(2*np.pi*t/32) + .09 * np.sin(2*np.pi*t*3/32 + .7)
mountain = np.stack((wind_l, wind_r), axis=1) * swells[:, None] * .11
# Small forest calls heard from far below; no repetitive close bird chatter.
for when, length, freq, pan in [(3.9,.43,1570,-.6),(4.65,.23,1840,-.7),(14.1,.6,1380,.45),(24.7,.36,1790,.2),(25.34,.32,1620,.35)]:
    ct = time(length)
    phase = 2*np.pi * (freq*ct + 140*ct*ct + 16*np.sin(ct*19))
    call = soften(np.sin(phase)*np.sin(np.pi*ct/length)**2, .04,.07) * .016
    start = round(when*SR)
    mountain[start:start+len(call),0] += call * (1-pan)*.5
    mountain[start:start+len(call),1] += call * (1+pan)*.5
write("mountain", mountain, .62, ogg=True)

t = time(24)
room_l = periodic_air(24, 333, 350)
room_r = periodic_air(24, 334, 360)
air = np.stack((room_l,room_r),axis=1) * .036
hum = (.020*np.sin(2*np.pi*50*t) + .008*np.sin(2*np.pi*100*t+.6) + .004*np.sin(2*np.pi*150*t))
air += hum[:,None] * (.77 + .13*np.sin(2*np.pi*t/24))[:,None]
for when, pitch, pan in [(4.3,361,-.7),(13.8,289,.7),(20.4,440,-.35)]:
    ct=time(.9)
    ping=soften(np.sin(2*np.pi*pitch*ct)*np.exp(-ct*8),.005,.08)*.012
    start=round(when*SR)
    air[start:start+len(ping),0]+=ping*(1-pan)*.5
    air[start:start+len(ping),1]+=ping*(1+pan)*.5
write("interior",air,.53,ogg=True)

for i in range(4):
    t=time(.24)
    body=np.sin(2*np.pi*(71+i*3)*t)*np.exp(-t*25)*.35
    scuff=noise(.24,250,2900)*np.exp(-t*24)*.23
    click=noise(.24,800,6400)*np.exp(-t*100)*.1
    write(f"step_stone_{i}",reverb(soften(body+scuff+click,.004,.05),.065),.45)
    leaf=noise(.32,450,4700)
    ct=time(.32)
    leaf*=np.exp(-ct*14)*(.4+.6*np.sin(np.pi*np.minimum(ct/.13,1))**2)
    write(f"step_grass_{i}",soften(leaf,.012,.08),.31)

t=time(.2)
write("select",reverb(soften((np.sin(t*2*np.pi*660)+.25*np.sin(t*2*np.pi*990))*np.exp(-t*30),.003,.03),.2),.32)
t=time(1.65)
env=np.sin(np.pi*np.minimum(t/1.5,1))**2*np.exp(-np.maximum(t-1.1,0)*4)
shift=np.zeros_like(t)
for f,a in [(110,.20),(164.81,.18),(220,.08),(329.63,.07),(440,.035)]:
    shift+=a*np.sin(2*np.pi*(f*t + 1.1*np.sin(t*1.8)))*env
shift+=noise(1.65,200,2700)*env*.045
write("shift",reverb(soften(shift,.06,.25),.3),.65)
t=time(.28)
write("error",reverb(soften((np.sin(2*np.pi*178*t)+.35*np.sin(2*np.pi*223*t))*np.exp(-t*12),.012,.08),.1),.24)
t=time(.5)
lever=noise(.5,150,2500)*np.exp(-t*15)*.28
lever+=np.sin(2*np.pi*97*t)*np.exp(-t*22)*.25
lever+=np.sin(2*np.pi*462*t)*np.exp(-t*33)*.04
lever[round(.16*SR):]+=noise(.34,300,3400)*np.exp(-time(.34)*32)*.14
write("lever",reverb(soften(lever,.002,.07),.25),.52)
t=time(2.45)
motor=(noise(2.45,40,500)*.18 + np.sin(2*np.pi*(42*t+3*t*t))*.08)
motor*=np.sin(np.pi*t/2.45)**.55
motor+=noise(2.45,500,2400)*.025*np.sin(np.pi*t/2.45)**2
motor+=np.sin(2*np.pi*74*t)*np.exp(-np.abs(t-2.2)*35)*.28
write("door",reverb(soften(motor,.08,.15),.22),.56)
t=time(.7)
pickup=(np.sin(2*np.pi*440*t)+.4*np.sin(2*np.pi*659.25*t))*np.exp(-t*8)*.2
pickup+=noise(.7,600,4300)*np.exp(-t*35)*.12
write("pickup",reverb(soften(pickup,.008,.15),.25),.42)
t=time(.8)
crack=noise(.8,100,5800)*np.exp(-t*22)*.43
crack+=np.sin(2*np.pi*83*t)*np.exp(-t*15)*.22
crack+=np.sin(2*np.pi*734*t)*np.exp(-t*21)*.08
write("crack",reverb(soften(crack,.002,.15),.27),.63)
t=time(1.6)
shot=noise(1.6,70,5600)*np.exp(-t*39)*.65
shot+=np.sin(2*np.pi*57*t)*np.exp(-t*21)*.35
shot+=noise(1.6,130,1000)*np.exp(-t*5)*.055
# Keep this RNG consumption for reproducible original cues. The outdoor report
# below replaces the former muffled placeholder without changing other assets.
t=time(2.8)
transition=noise(2.8,90,1300)*np.sin(np.pi*t/2.8)**2*.25
transition+=np.sin(2*np.pi*(74*t-7*t*t))*np.sin(np.pi*t/2.8)**2*.06
write("transition",soften(transition,.12,.3),.48)

# Final outdoor report. A separate RNG keeps the original ambience and every
# original chapter cue identical when rebuilding only the added sound design.
report_rng = np.random.default_rng(931712)

def report_noise(seconds, low, high):
    samples = report_rng.normal(0, 1, round(seconds * SR))
    return sosfiltfilt(butter(3, [low, high], btype="bandpass", fs=SR, output="sos"), samples)

def lowpass(samples, cutoff):
    return sosfiltfilt(butter(3, cutoff, btype="lowpass", fs=SR, output="sos"), samples)

t=time(.74)
# Dry, fast broadband snap followed by the low-pressure body of the report.
snap=report_noise(.74,1000,9900)*np.exp(-t*165)*1.12
snap+=report_noise(.74,180,7600)*np.exp(-t*46)*.72
body=np.sin(2*np.pi*(87*t-18*t*t))*np.exp(-t*33)*.40
body+=report_noise(.74,55,430)*np.exp(-t*22)*.50
body+=report_noise(.74,180,3100)*np.exp(-t*12)*.14
dry=soften(snap+body,.0003,.12)
dry=np.tanh(dry*1.1)  # smooth pressure saturation, with headroom after export
total=round(3.85*SR)
outdoor_report=np.zeros((total,2))
outdoor_report[:len(dry),0]+=dry*.98
outdoor_report[:len(dry),1]+=dry
# Individual valley reflections are distant, progressively darker and wider.
for delay,gain,cutoff,pan in [(.31,.34,3100,-.63),(.72,.24,2300,.68),(1.23,.17,1650,-.26),(1.83,.105,1150,.46),(2.51,.055,780,-.5)]:
    echo=lowpass(dry,cutoff)
    echo=np.convolve(echo, np.exp(-np.arange(140)/40)/40, mode="full")
    at=round(delay*SR)
    n=min(len(echo),total-at)
    outdoor_report[at:at+n,0]+=echo[:n]*gain*(1-pan*.55)
    outdoor_report[at:at+n,1]+=echo[:n]*gain*(1+pan*.55)
# Soft diffuse field connects discrete echoes into a convincing mountain tail.
tail_time=time(3.1)
tail=report_noise(3.1,90,1700)*np.exp(-tail_time*1.55)*.028
tail=soften(tail,.065,.45)
at=round(.20*SR)
outdoor_report[at:at+len(tail),0]+=tail
outdoor_report[at:at+len(tail),1]+=np.roll(tail,119)*.96
outdoor_report[-round(.25*SR):]*=np.linspace(1,0,round(.25*SR))[:,None]
write("shot",outdoor_report,.92)

t=time(.74)
stress=(np.sin(2*np.pi*(61*t-4*t*t))*.32+np.sin(2*np.pi*139*t)*.15)*np.sin(np.pi*t/.74)**.6
stress+=report_noise(.74,75,950)*np.exp(-t*5)*.11
stress+=np.sin(2*np.pi*(537*t+22*t*t))*np.exp(-t*7)*.055
write("pressure_warning",reverb(soften(stress,.018,.10),.20),.58)
t=time(1.55)
release=report_noise(1.55,240,7000)*(.7*np.exp(-t*2.7)+.18*np.exp(-t*.7))
release*=1+.15*np.sin(t*29)*np.exp(-t*3)
release+=np.sin(2*np.pi*(96*t-10*t*t))*np.exp(-t*10)*.08
write("pressure_release",reverb(soften(release,.045,.35),.17),.55)
t=time(.43)
drop=(np.sin(2*np.pi*(119*t-91*t*t))*.20+report_noise(.43,90,2800)*.27)*np.exp(-t*10)
drop+=np.sin(2*np.pi*386*t)*np.exp(-t*31)*.12
write("power_drop",reverb(soften(drop,.002,.08),.12),.47)

# Loop used only while the new pressure hazard is active. Quiet level is set
# in Soundscape; increased danger changes weight, never playback frequency.
t=time(12)
pressure_air_l=periodic_air(12,719,650)
pressure_air_r=periodic_air(12,721,650)
pressure=np.stack((pressure_air_l,pressure_air_r),axis=1)*.055
strain=(.045*np.sin(2*np.pi*62*t)+.020*np.sin(2*np.pi*93*t)+.009*np.sin(2*np.pi*186*t))
strain*=.75+.12*np.sin(2*np.pi*t/3)+.08*np.sin(2*np.pi*t/12)
pressure+=strain[:,None]
write("pressure_bed",pressure,.49,ogg=True)

source=Path('/home/ivan/Downloads/11145955-mesa-10550 (1).mp3')
if source.exists() and not args.new_only:
    shutil.copyfile(source, OUT/'music.mp3')
print(f"Generated {len(list(OUT.glob('*')))} sound assets in {OUT}")
