# Erzeugt alle Soundeffekte selbst (keine fremden Aufnahmen): python3 make_sounds.py
# Braucht numpy und ffmpeg; schreibt OGG-Dateien nach sounds/.
import os
import subprocess
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sounds")
rng = np.random.default_rng(7)


def t(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def env(n, attack, release, total):
    e = np.ones(n)
    a = int(attack * RATE)
    r = int(release * RATE)
    if a:
        e[:a] = np.linspace(0, 1, a)
    if r:
        e[-r:] *= np.linspace(1, 0, r) ** 2
    return e


def lowpass(x, cutoff):
    # einfacher Ein-Pol-Tiefpass
    a = np.exp(-2 * np.pi * cutoff / RATE)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def bandpass(x, low, high):
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / RATE)
    spectrum[(freqs < low) | (freqs > high)] = 0
    return np.fft.irfft(spectrum, len(x))


def norm(x, peak=0.9):
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def save(name, x):
    os.makedirs(OUT, exist_ok=True)
    wav = os.path.join(OUT, name + ".wav")
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(wav, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(wav)


# Schuss: tiefer Ball-Wumms plus kurzes Klatschen
x = t(0.35)
thump = np.sin(2 * np.pi * (140 * np.exp(-x * 18) + 55) * x) * np.exp(-x * 14)
slap = bandpass(rng.standard_normal(len(x)), 800, 5000) * np.exp(-x * 90)
save("kick", norm(thump + 0.5 * norm(slap)))

# Schiedsrichterpfiff: Trillerpfeife mit Vibrato
def whistle(seconds, trill=28):
    x = t(seconds)
    f = 2900 + 120 * np.sin(2 * np.pi * trill * x)
    tone = np.sin(2 * np.pi * np.cumsum(f) / RATE)
    breath = bandpass(rng.standard_normal(len(x)), 2500, 4000) * 0.15
    am = 0.75 + 0.25 * np.sin(2 * np.pi * trill * x)
    return norm((tone + breath) * am * env(len(x), 0.02, 0.08, seconds), 0.7)

save("whistle", whistle(0.55))
# Abpfiff: drei Pfiffe, der letzte lang
gap = np.zeros(int(0.12 * RATE))
save("whistle_end", np.concatenate([whistle(0.3), gap, whistle(0.3), gap, whistle(1.1)]))

# Stadion-Hupe fuers Tor: verzerrter Akkord
x = t(1.6)
horn = sum(np.sign(np.sin(2 * np.pi * f * x)) * w for f, w in ((233, 1), (293, 0.8), (349, 0.7), (117, 0.6)))
horn = lowpass(horn, 2200) * env(len(x), 0.03, 0.35, 1.6)
save("horn", norm(np.tanh(horn * 1.5), 0.8))


# Publikum: viele "Stimmen" aus gefiltertem Rauschen
def crowd(seconds, swell, roar):
    x = t(seconds)
    base = lowpass(rng.standard_normal(len(x)), 900)
    voices = np.zeros(len(x))
    for _ in range(24):
        f = rng.uniform(250, 900)
        start = rng.uniform(0, seconds * 0.6)
        length = rng.uniform(0.4, seconds)
        seg = (x > start) & (x < start + length)
        vib = np.sin(2 * np.pi * (f + 15 * np.sin(2 * np.pi * rng.uniform(4, 7) * x)) * x)
        voices += vib * seg * rng.uniform(0.2, 0.6) * np.sin(np.pi * np.clip((x - start) / length, 0, 1))
    mix = norm(base) * 0.8 + norm(voices) * roar
    return norm(mix * swell(x))


save("cheer", crowd(3.2, lambda x: np.minimum(1, x * 4) * np.exp(-np.maximum(0, x - 1.6) * 1.5), 0.6))
save("ooh", crowd(1.4, lambda x: np.sin(np.pi * x / 1.4) ** 0.7, 0.9))

# Stadion-Atmosphaere als Schleife (Anfang und Ende ueberblendet)
x = t(8)
amb = lowpass(rng.standard_normal(len(x)), 600) * (0.8 + 0.2 * np.sin(2 * np.pi * x / 8))
fade = int(0.5 * RATE)
amb[:fade] = amb[:fade] * np.linspace(0, 1, fade) + amb[-fade:] * np.linspace(1, 0, fade)
amb = amb[:-fade]
save("crowd", norm(amb, 0.6))

# Ball abgenommen: Wusch
x = t(0.32)
noise = rng.standard_normal(len(x))
sweep = np.zeros(len(x))
for i in range(0, len(x), 512):
    seg = noise[i:i + 1024]
    centre = 600 + 3500 * (i / len(x))
    sweep[i:i + len(seg)] += bandpass(seg, centre * 0.7, centre * 1.3)[: len(sweep[i:i + len(seg)])]
save("steal", norm(sweep * np.sin(np.pi * x / 0.32)))

# Smack: dumpfer Aufprall
x = t(0.5)
body = np.sin(2 * np.pi * (90 * np.exp(-x * 8) + 40) * x) * np.exp(-x * 7)
crack = bandpass(rng.standard_normal(len(x)), 300, 3000) * np.exp(-x * 40)
save("smack", norm(np.tanh((body + 0.8 * norm(crack)) * 2)))

# Countdown-Piep
x = t(0.16)
save("beep", norm(np.sin(2 * np.pi * 880 * x) * env(len(x), 0.005, 0.06, 0.16), 0.6))
print("sounds:", sorted(os.listdir(OUT)))
