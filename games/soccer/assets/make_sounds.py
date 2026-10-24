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


# ---------------------------------------------------------------- Soccer-Jam-Stil, Teil 2
# Stadionsprecher (Sprachausgabe mit flite, als Lautsprecher-Durchsage nachbearbeitet), alle Saetze
# in einer Datei hintereinander; die Startzeiten landen in src/shared/VoiceLines.luau.
import ctypes

FLITE = "/usr/lib/x86_64-linux-gnu/"


def speak(text, voice):
    for lib in ("libflite.so.1", "libflite_usenglish.so.1", "libflite_cmulex.so.1"):
        ctypes.CDLL(FLITE + lib, mode=ctypes.RTLD_GLOBAL)
    flite = ctypes.CDLL(FLITE + "libflite.so.1")
    flite.flite_init()
    module = ctypes.CDLL(FLITE + f"libflite_cmu_us_{voice}.so.1")
    register = getattr(module, f"register_cmu_us_{voice}")
    register.restype = ctypes.c_void_p
    handle = register(None)
    flite.flite_text_to_speech.argtypes = [ctypes.c_char_p, ctypes.c_void_p, ctypes.c_char_p]
    path = os.path.join(OUT, "_tmp_voice.wav")
    flite.flite_text_to_speech(text.encode(), handle, path.encode())
    with wave.open(path, "rb") as f:
        rate = f.getframerate()
        data = np.frombuffer(f.readframes(f.getnframes()), dtype=np.int16).astype(float) / 32768
    os.remove(path)
    # auf 44,1 kHz bringen, etwas tiefer (pitch) fuer eine kraeftige Sprecherstimme
    pitch = 0.9
    n = int(len(data) * RATE / rate / pitch)
    data = np.interp(np.linspace(0, len(data) - 1, n), np.arange(len(data)), data)
    return data


def announcer(x):
    # Stadion-Lautsprecher: Bandpass, leichte Verzerrung, Hall-Echos
    x = bandpass(x, 180, 5500)
    x = np.tanh(norm(x) * 1.8)
    out = np.concatenate([x, np.zeros(int(0.5 * RATE))])
    for delay, gain in ((0.09, 0.35), (0.19, 0.22), (0.31, 0.12)):
        d = int(delay * RATE)
        out[d:d + len(x)] += x * gain
    return norm(out, 0.85)


LINES = [
    ("Prepare", "Prepare for kick off!", "rms", 1.0),
    ("Amazing", "Amazing!", "rms", 1.0),
    ("Perfect", "Perfect!", "rms", 1.0),
    ("Boom", "Boom shaka laka!", "rms", 1.0),
    ("Goal", "Goal!", "rms", 1.0),
    ("Laugh", "Ha ha ha ha ha!", "awb", 1.0),
    ("Returned", "Ball returned!", "rms", 1.0),
    ("Ouch", "Ouch!", "awb", 1.0),
    ("Three", "Three", "kal", 1.0),
    ("Two", "Two", "kal", 1.0),
    ("One", "One", "kal", 1.0),
    ("Go", "Go!", "kal", 1.0),
    ("Halftime", "Half time!", "rms", 1.0),
    ("Winner", "We have a winner!", "rms", 1.0),
]
pack = []
offsets = []
cursor = 0.0
for key, text, voice, gain in LINES:
    clip = announcer(speak(text, voice)) * gain
    offsets.append((key, cursor, len(clip) / RATE))
    pack.append(clip)
    gap = np.zeros(int(0.3 * RATE))
    pack.append(gap)
    cursor += len(clip) / RATE + 0.3
save("announcer", np.concatenate(pack))
lua = ["-- Automatisch erzeugt von assets/make_sounds.py: Start und Laenge jeder Ansage in announcer.ogg (Sekunden)", "return {"]
for key, start, length in offsets:
    lua.append(f"\t{key} = {{ {start:.3f}, {length:.3f} }},")
lua.append("}")
with open(os.path.join(os.path.dirname(OUT), "..", "src", "shared", "VoiceLines.luau"), "w") as f:
    f.write("\n".join(lua) + "\n")

# Tor-Sirene (Alarm wie bei Soccer Jam): auf- und abschwellender Heulton
x = t(2.6)
f = 620 + 380 * (0.5 - 0.5 * np.cos(2 * np.pi * x / 1.3))
siren = np.sign(np.sin(2 * np.pi * np.cumsum(f) / RATE)) * 0.6 + np.sin(2 * np.pi * np.cumsum(f * 2) / RATE) * 0.3
siren = lowpass(siren, 3500) * env(len(x), 0.05, 0.4, 2.6)
save("siren", norm(np.tanh(siren * 1.5), 0.8))

# Ball angenommen: kurzes, helles "Plopp"
x = t(0.18)
save("gotball", norm(np.sin(2 * np.pi * (520 + 500 * np.exp(-x * 30)) * x) * np.exp(-x * 22), 0.7))

# Level-Up / Upgrade gekauft: kleine aufsteigende Fanfare
notes = [523, 659, 784, 1047]
parts = []
for i, freq in enumerate(notes):
    x = t(0.13 if i < 3 else 0.45)
    tone = (np.sign(np.sin(2 * np.pi * freq * x)) * 0.4 + np.sin(2 * np.pi * freq * 2 * x) * 0.3) * env(len(x), 0.005, 0.08 if i < 3 else 0.3, 0)
    parts.append(lowpass(tone, 4000))
save("levelup", norm(np.concatenate(parts), 0.7))

# Alien-Zap: elektrischer Schlag
x = t(0.4)
buzz = np.sign(np.sin(2 * np.pi * (180 + 60 * np.sin(2 * np.pi * 37 * x)) * x)) * np.exp(-x * 6)
crackle = bandpass(rng.standard_normal(len(x)), 2000, 8000) * (rng.random(len(x)) > 0.7) * np.exp(-x * 8)
save("zap", norm(lowpass(buzz, 3000) + crackle * 0.8, 0.8))
print("sounds:", sorted(os.listdir(OUT)))
