# Komponiert und erzeugt die komplette Musik und alle neuen Sounds von surf_ski selbst
# (keine fremden Aufnahmen, keine Samples): python3 make_audio.py
# Braucht numpy und ffmpeg; schreibt OGG-Dateien nach sounds/.
# Musik-Schleifen werden zirkulaer gefaltet (Hall, Echo), dadurch laufen sie ohne Knacks im Kreis.
import os
import subprocess
import sys
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sounds")
rng = np.random.default_rng(2026)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def n(name):
    # "A4" -> MIDI-Nummer
    pitch = name[:-1]
    octave = int(name[-1])
    return 12 * (octave + 1) + NOTE[pitch]


def tt(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def adsr(length, a, d, s, r, hold=None):
    # Laengen in Sekunden; hold = Dauer bis zum Loslassen
    count = int(length * RATE)
    x = np.arange(count) / RATE
    hold = length - r if hold is None else hold
    e = np.where(x < a, x / max(a, 1e-4), 1 - (1 - s) * np.clip((x - a) / max(d, 1e-4), 0, 1))
    rel = np.clip((x - hold) / max(r, 1e-4), 0, 1)
    level_at_hold = np.interp(hold, x, e) if count else 0
    e = np.where(x < hold, e, level_at_hold * (1 - rel))
    return e


def additive(freq, length, harmonics, bright=0.0, decay=0.0, odd=False, detune_cents=0.0, vibrato=0.0):
    # Bandbegrenzte Saege/Rechteck aus Obertoenen. bright/decay: hoehere Obertoene klingen schneller ab
    # (wirkt wie ein sich schliessender Tiefpass, ohne Filter)
    x = tt(length)
    f0 = freq * 2 ** (detune_cents / 1200)
    phase_mod = vibrato * np.sin(2 * np.pi * 5.2 * x) if vibrato else 0
    out = np.zeros(len(x))
    k = 1
    count = 0
    while count < harmonics:
        f = f0 * k
        if f > RATE * 0.45:
            break
        amp = 1.0 / k
        if decay:
            amp = amp * np.exp(-x * decay * (k - 1) ** 0.7)
        if bright:
            amp = amp * np.exp(-(k - 1) * bright)
        out += amp * np.sin(2 * np.pi * f * x + k * phase_mod + rng.uniform(0, 2 * np.pi))
        k += 2 if odd else 1
        count += 1
    return out


def fft_filter(x, low=None, high=None):
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / RATE)
    gain = np.ones(len(freqs))
    if high:
        gain *= 1 / np.sqrt(1 + (freqs / high) ** 4)
    if low:
        gain *= 1 / np.sqrt(1 + (low / np.maximum(freqs, 1)) ** 4)
    return np.fft.irfft(spectrum * gain, len(x))


def circular_reverb(x, seconds=1.8, wet=0.25, seed=1, high=6000):
    # Faltung mit abklingendem Rauschen, zirkulaer (Schleife bleibt nahtlos)
    r = np.random.default_rng(seed)
    length = int(seconds * RATE)
    ir = r.standard_normal(length) * np.exp(-np.arange(length) / RATE * 6.9 / seconds)
    ir = fft_filter(ir, low=200, high=high)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    padded = np.zeros(len(x))
    padded[: min(length, len(x))] = ir[: len(x)]
    wet_signal = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(padded), len(x))
    return x + wet * wet_signal / (np.max(np.abs(wet_signal)) + 1e-9) * np.max(np.abs(x))


def circular_delay(x, delay, feedback=0.35, taps=4, mix=0.3):
    out = x.copy()
    shift = int(delay * RATE)
    for i in range(1, taps + 1):
        out += mix * feedback ** (i - 1) * np.roll(x, shift * i)
    return out


def place(track, sound, start):
    # sound zirkulaer ab Sample start einfuegen (Schwanz laeuft an den Anfang der Schleife)
    start = int(start) % len(track)
    end = start + len(sound)
    if end <= len(track):
        track[start:end] += sound
    else:
        first = len(track) - start
        track[start:] += sound[:first]
        rest = sound[first:]
        while len(rest) > 0:
            k = min(len(rest), len(track))
            track[:k] += rest[:k]
            rest = rest[k:]


def master(left, right, peak=0.89):
    stereo = np.stack([left, right])
    stereo = stereo / (np.max(np.abs(stereo)) + 1e-9)
    stereo = np.tanh(stereo * 1.4) / np.tanh(1.4)
    return stereo / (np.max(np.abs(stereo)) + 1e-9) * peak


def save(name, data):
    os.makedirs(OUT, exist_ok=True)
    data = np.atleast_2d(data)
    wav = os.path.join(OUT, name + ".wav")
    pcm = (np.clip(data.T, -1, 1) * 32767).astype(np.int16)
    with wave.open(wav, "wb") as f:
        f.setnchannels(data.shape[0])
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(wav)
    print(name, f"{data.shape[1] / RATE:.1f}s")


def norm(x, peak=0.9):
    return x / (np.max(np.abs(x)) + 1e-9) * peak


# ---------------------------------------------------------------- Instrumente

def kick(length=0.45, punch=1.0):
    x = tt(length)
    f = 48 + 110 * np.exp(-x * 30)
    body = np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-x * 7)
    click = rng.standard_normal(len(x)) * np.exp(-x * 400) * 0.25
    return np.tanh((body + click) * 1.6 * punch)


def snare(length=0.28, tone=190):
    x = tt(length)
    noise = fft_filter(rng.standard_normal(len(x)), low=1200, high=9000) * np.exp(-x * 18)
    body = np.sin(2 * np.pi * tone * x) * np.exp(-x * 30)
    return norm(noise) * 0.8 + body * 0.5


def clap(length=0.3):
    x = tt(length)
    noise = fft_filter(rng.standard_normal(len(x)), low=900, high=6000)
    e = np.zeros(len(x))
    for offset in (0, 0.011, 0.022):
        e += np.where(x >= offset, np.exp(-(x - offset) * 70), 0) * 0.6
    e += np.where(x >= 0.03, np.exp(-(x - 0.03) * 14), 0)
    return norm(noise * e)


def hat(length=0.06, open_hat=False):
    length = 0.22 if open_hat else length
    x = tt(length)
    noise = fft_filter(rng.standard_normal(len(x)), low=7000)
    return norm(noise * np.exp(-x * (14 if open_hat else 70)))


def shaker(length=0.09):
    x = tt(length)
    noise = fft_filter(rng.standard_normal(len(x)), low=5000, high=11000)
    return norm(noise * np.sin(np.pi * np.clip(x / length, 0, 1)) ** 2)


def rhodes(freq, length, velocity=1.0):
    # E-Piano: Sinus mit FM-Glockenanschlag und Tremolo
    x = tt(length + 0.6)
    index = 1.8 * np.exp(-x * 7)
    tone = np.sin(2 * np.pi * freq * x + index * np.sin(2 * np.pi * freq * 14 * x) * 0.15 + index * np.sin(2 * np.pi * freq * x))
    tone += 0.25 * np.sin(2 * np.pi * freq * 2 * x) * np.exp(-x * 3)
    e = adsr(length + 0.6, 0.004, 1.2, 0.35, 0.5, hold=length)
    trem = 1 + 0.12 * np.sin(2 * np.pi * 4.5 * x)
    return tone * e * trem * velocity


def bell(freq, length=1.6, velocity=1.0):
    x = tt(length)
    ratios = ((1, 1.0, 2.2), (2.0, 0.35, 4), (3.01, 0.25, 6), (4.2, 0.12, 9), (5.43, 0.06, 12))
    out = sum(a * np.sin(2 * np.pi * freq * r * x) * np.exp(-x * d) for r, a, d in ratios)
    return out * np.minimum(1, x / 0.002) * velocity


def pluck(freq, length, velocity=1.0, bright=0.0):
    tone = additive(freq, length + 0.3, 30, decay=9 - bright * 6) + 0.6 * additive(freq, length + 0.3, 30, decay=9 - bright * 6, detune_cents=9)
    e = adsr(length + 0.3, 0.002, 0.3, 0.25, 0.25, hold=length)
    return tone * e * velocity


def supersaw(freq, length, voices=5, spread=14, velocity=1.0, attack=0.02, release=0.35, bright=0.07):
    out = sum(additive(freq, length + release, 26, bright=bright, detune_cents=(i - (voices - 1) / 2) * spread / ((voices - 1) / 2)) for i in range(voices))
    return out / voices * adsr(length + release, attack, 0.3, 0.8, release, hold=length) * velocity


def pad(freq, length, velocity=1.0, attack=0.8, release=1.2, bright=0.18):
    out = sum(additive(freq, length + release, 18, bright=bright, detune_cents=c) for c in (-7, 0, 7))
    out += 0.5 * np.sin(2 * np.pi * freq * 0.5 * tt(length + release))
    return out / 3 * adsr(length + release, attack, 0.5, 0.85, release, hold=length) * velocity


def bass(freq, length, velocity=1.0, bright=0.0):
    x = tt(length + 0.08)
    sub = np.sin(2 * np.pi * freq * x)
    grit = additive(freq, length + 0.08, 14, decay=14 - bright * 10) * 0.45
    return (sub + grit) * adsr(length + 0.08, 0.004, 0.2, 0.75, 0.06, hold=length) * velocity


def lead(freq, length, velocity=1.0):
    tone = additive(freq, length + 0.25, 16, odd=True, bright=0.12, vibrato=0.012) + 0.5 * additive(freq * 2, length + 0.25, 8, bright=0.3)
    return tone * adsr(length + 0.25, 0.01, 0.2, 0.7, 0.22, hold=length) * velocity


def sidechain(length_samples, beat_samples, depth=0.55, recover=0.18):
    x = (np.arange(length_samples) % beat_samples) / RATE
    return 1 - depth * np.exp(-x / recover * 3)


class Song:
    def __init__(self, bpm, bars):
        self.bpm = bpm
        self.beat = 60 / bpm
        self.length = int(round(bars * 4 * self.beat * RATE))
        self.stems = {}

    def stem(self, name):
        if name not in self.stems:
            self.stems[name] = np.zeros(self.length)
        return self.stems[name]

    def at(self, bar, beat):
        return (bar * 4 + beat) * self.beat * RATE

    def add(self, name, sound, bar, beat=0.0, gain=1.0):
        place(self.stem(name), sound * gain, self.at(bar, beat))


def chord_notes(root, kind):
    shapes = {
        "maj7": (0, 4, 7, 11), "m7": (0, 3, 7, 10), "m9": (0, 3, 7, 10, 14), "maj9": (0, 4, 7, 11, 14),
        "7": (0, 4, 7, 10), "maj": (0, 4, 7), "min": (0, 3, 7), "sus2": (0, 2, 7), "add9": (0, 4, 7, 14), "m11": (0, 3, 7, 10, 17),
    }
    return [root + i for i in shapes[kind]]


def mix_song(song, gains, pans, reverb, out_name):
    left = np.zeros(song.length)
    right = np.zeros(song.length)
    for name, signal in song.stems.items():
        g = gains.get(name, 1.0)
        p = pans.get(name, 0.0)
        wet = reverb.get(name, 0.0)
        if wet:
            l_sig = circular_reverb(signal, wet=wet, seed=hash(name) % 1000)
            r_sig = circular_reverb(signal, wet=wet, seed=hash(name) % 1000 + 7)
        else:
            l_sig = r_sig = signal
        left += l_sig * g * np.sqrt(0.5 * (1 - p))
        right += r_sig * g * np.sqrt(0.5 * (1 + p))
    save(out_name, master(left, right))


# ---------------------------------------------------------------- Musik 1: "Apres-Ski" (Lobby)
# Gemuetlicher Lo-Fi in F-Dur, 84 BPM: E-Piano, warmer Bass, weiche Drums, Glocken-Melodie, Knistern.

def song_lobby():
    s = Song(84, 16)
    progression = [(n("F3"), "maj9"), (n("A3"), "m7"), (n("D3"), "m9"), (n("Bb2"), "maj9"),
                   (n("G3"), "m7"), (n("C3"), "7"), (n("F3"), "maj7"), (n("C3"), "sus2")]
    for bar in range(16):
        root, kind = progression[bar % 8]
        notes = chord_notes(root, kind)
        # E-Piano: Akkord auf 1, leichte Wiederholung auf 2.5 (wie gespielt, leicht verschleppt)
        for i, note in enumerate(notes):
            s.add("keys", rhodes(midi(note + 12), s.beat * 2.2, 0.32), bar, 0.02 * i)
            s.add("keys", rhodes(midi(note + 12), s.beat * 1.2, 0.18), bar, 2.5 + 0.02 * i)
        # Bass: Grundton, Quinte, Annaeherung
        bass_root = root - 12 if root >= n("C3") else root
        s.add("bass", bass(midi(bass_root), s.beat * 1.4, 0.9), bar, 0)
        s.add("bass", bass(midi(bass_root + 7), s.beat * 1.15, 0.6), bar, 1.5)
        s.add("bass", bass(midi(bass_root), s.beat * 1.2, 0.7), bar, 2.75)
        # Lo-Fi-Drums mit Swing
        s.add("drums", kick(0.5, 0.8), bar, 0)
        s.add("drums", kick(0.5, 0.6), bar, 1.75)
        s.add("drums", kick(0.5, 0.7), bar, 2.5)
        s.add("drums", snare(0.3) * 0.7, bar, 1)
        s.add("drums", snare(0.3) * 0.7, bar, 3)
        for eighth in range(8):
            swing = 0.08 if eighth % 2 else 0
            s.add("hats", hat() * (0.35 if eighth % 2 else 0.5), bar, eighth * 0.5 + swing)
    # Melodie (Glocken), Pentatonik ueber die Akkorde, zweite Haelfte mit Antwort
    melody = [
        (0, 0, "C6", 1), (0, 1.5, "A5", 0.5), (0, 2, "G5", 1), (1, 0, "E5", 1.5), (1, 2, "G5", 1), (1, 3, "A5", 1),
        (2, 0, "F5", 1), (2, 1, "A5", 0.5), (2, 2, "D6", 1.5), (3, 0, "C6", 2), (3, 2.5, "A5", 1),
        (4, 0, "Bb5", 1), (4, 1.5, "A5", 0.5), (4, 2, "G5", 1), (5, 0, "E5", 1), (5, 1, "G5", 1), (5, 2, "Bb5", 1),
        (6, 0, "A5", 1.5), (6, 2, "C6", 1), (6, 3, "F6", 1), (7, 0, "E6", 2), (7, 2.5, "C6", 1),
    ]
    for half in (0, 8):
        for bar, beat, note, length in melody:
            if half and bar >= 6:
                continue
            s.add("bells", bell(midi(n(note)), 1.6, 0.22 if not half else 0.18), bar + half, beat)
    # Schluss der Schleife: Abwaertslauf, der in den Anfang fuehrt
    for i, note in enumerate(("F6", "D6", "C6", "A5", "G5", "F5")):
        s.add("bells", bell(midi(n(note)), 1.4, 0.16), 14 + (i // 4), (i % 4) * 0.5 + 0.5)
    # Vinyl-Knistern
    crackle = np.zeros(s.length)
    pops = rng.integers(0, s.length, 900)
    crackle[pops] = rng.uniform(-1, 1, len(pops))
    crackle = fft_filter(crackle, low=1500, high=8000)
    s.stems["vinyl"] = norm(crackle, 0.15) + fft_filter(rng.standard_normal(s.length), low=3000, high=7000) * 0.004
    s.stems["keys"] = fft_filter(s.stems["keys"], high=5200)
    mix_song(s, {"keys": 0.9, "bass": 0.42, "drums": 0.55, "hats": 0.25, "bells": 0.55, "vinyl": 0.3},
             {"keys": -0.15, "bells": 0.3, "hats": 0.25}, {"keys": 0.35, "bells": 0.5, "drums": 0.08}, "music_lobby")


# ---------------------------------------------------------------- Musik 2: "Powder Rush" (Fahren)
# Treibender Euro-Synth in A-Moll, 128 BPM: Four-on-the-floor, Offbeat-Bass, Arpeggio, Supersaw, Lead.

def song_run():
    s = Song(128, 32)
    progression = [(n("A2"), "min"), (n("F2"), "maj"), (n("C3"), "maj"), (n("G2"), "maj")]
    beat_samples = int(s.beat * RATE)
    for bar in range(32):
        section = bar // 8  # 0 Intro-Groove, 1 Arp, 2 Refrain, 3 Refrain + Lead-Variation
        root, kind = progression[bar % 4]
        notes = chord_notes(root, kind)
        for beat in range(4):
            s.add("kick", kick(0.4, 1.0), bar, beat)
            s.add("hats", hat(open_hat=True) * 0.5, bar, beat + 0.5)
            for sixteenth in (0.25, 0.75):
                s.add("hats", hat() * 0.28, bar, beat + sixteenth)
        s.add("clap", clap(), bar, 1)
        s.add("clap", clap(), bar, 3)
        # Offbeat-Bass (Eurodance)
        for beat in range(4):
            s.add("bass", bass(midi(root), s.beat * 0.42, 0.95, bright=0.6), bar, beat + 0.5)
            if section >= 1:
                s.add("bass", bass(midi(root + 12), s.beat * 0.2, 0.4, bright=0.8), bar, beat + 0.75)
        # Arpeggio in 16teln
        if section >= 1:
            pattern = [0, 1, 2, 1, 2, 3, 2, 1] if len(notes) == 3 else [0, 1, 2, 3]
            arp_notes = notes + [notes[0] + 12]
            for step in range(16):
                note = arp_notes[pattern[step % len(pattern)] % len(arp_notes)] + 24
                s.add("arp", pluck(midi(note), s.beat * 0.22, 0.55 if step % 4 == 0 else 0.38, bright=0.4 + 0.4 * (bar % 8) / 8), bar, step * 0.25)
        # Supersaw-Akkorde im Refrain, Pad sonst
        if section >= 2:
            for note in notes:
                s.add("saw", supersaw(midi(note + 12), s.beat * 3.6, velocity=0.5), bar, 0)
        else:
            for note in notes:
                s.add("pad", pad(midi(note + 12), s.beat * 3.8, velocity=0.4, attack=0.3, release=0.6), bar, 0)
    # Lead-Melodie im Refrain (eigene Komposition)
    hook = [
        (0, 0, "E5", 0.75), (0, 0.75, "E5", 0.75), (0, 1.5, "D5", 0.5), (0, 2, "C5", 1), (0, 3, "D5", 1),
        (1, 0, "C5", 0.75), (1, 0.75, "A4", 0.75), (1, 1.5, "C5", 0.5), (1, 2, "F5", 1.5), (1, 3.5, "E5", 0.5),
        (2, 0, "E5", 0.75), (2, 0.75, "G5", 0.75), (2, 1.5, "E5", 0.5), (2, 2, "C5", 1), (2, 3, "E5", 1),
        (3, 0, "D5", 1.5), (3, 1.5, "B4", 0.5), (3, 2, "D5", 1), (3, 3, "G5", 1),
    ]
    for start in (16, 20, 24, 28):
        for bar, beat, note, length in hook:
            shift = 12 if start == 28 and bar >= 2 else 0
            s.add("lead", lead(midi(n(note) + shift), s.beat * length * 0.92, 0.5), start + bar, beat)
    # Aufbau vor dem Refrain: Snare-Wirbel und Riser
    for i in range(16):
        s.add("clap", snare(0.2) * (0.25 + i / 20), 15, i * 0.25)
    riser_len = int(s.beat * 4 * RATE)
    x = np.arange(riser_len) / RATE
    riser = fft_filter(rng.standard_normal(riser_len), low=800) * (x / x[-1]) ** 2
    place(s.stem("fx"), riser * 0.4, s.at(15, 0))
    # Sidechain: Pads, Saws, Bass ducken unter der Kick
    duck = sidechain(s.length, beat_samples)
    for name in ("pad", "saw", "bass", "arp"):
        if name in s.stems:
            s.stems[name] *= duck
    s.stems["arp"] = circular_delay(s.stems["arp"], s.beat * 0.75, feedback=0.4, mix=0.35)
    s.stems["lead"] = circular_delay(s.stems["lead"], s.beat * 0.5, feedback=0.3, mix=0.25)
    mix_song(s, {"kick": 0.9, "clap": 0.45, "hats": 0.22, "bass": 0.7, "arp": 0.42, "pad": 0.4, "saw": 0.42, "lead": 0.45, "fx": 0.4},
             {"arp": 0.35, "hats": -0.2, "lead": -0.1, "pad": -0.25}, {"clap": 0.2, "arp": 0.25, "pad": 0.4, "saw": 0.3, "lead": 0.3}, "music_run")


# ---------------------------------------------------------------- Musik 3: "Aurora Night" (spaete Stages)
# Ruhiger Synth-Traum in D-Dorisch, 100 BPM: Flaechen, Glocken-Arpeggio, weicher Puls.

def song_night():
    s = Song(100, 24)
    progression = [(n("D3"), "m9"), (n("C3"), "add9"), (n("G2"), "sus2"), (n("Bb2"), "maj9"),
                   (n("D3"), "m11"), (n("F3"), "maj7"), (n("C3"), "add9"), (n("A2"), "m7")]
    for bar in range(24):
        root, kind = progression[bar % 8]
        notes = chord_notes(root, kind)
        for note in notes[:4]:
            s.add("pad", pad(midi(note + 12), s.beat * 3.9, velocity=0.45, attack=1.2, release=1.8, bright=0.25), bar, 0)
        s.add("bass", bass(midi(root - 12 if root > n("E3") else root), s.beat * 3.6, 0.6), bar, 0)
        # Glocken-Arpeggio in Achteln, aufwaerts und abwaerts
        arp = notes + [notes[1] + 12]
        order = [0, 1, 2, 3, 4, 3, 2, 1]
        for eighth in range(8):
            note = arp[order[eighth] % len(arp)] + 24
            s.add("bells", bell(midi(note), 1.2, 0.2 if eighth % 2 == 0 else 0.13), bar, eighth * 0.5)
        if bar >= 4:
            s.add("drums", kick(0.5, 0.65), bar, 0)
            s.add("drums", kick(0.5, 0.5), bar, 2.5)
            s.add("drums", snare(0.4, 160) * 0.35, bar, 2)
            for i in range(8):
                s.add("shaker", shaker() * (0.35 if i % 2 else 0.2), bar, i * 0.5 + 0.25)
    # Lange, singende Melodie
    melody = [(8, 0, "A5", 3), (9, 0, "G5", 2), (9, 2, "E5", 2), (10, 0, "D5", 3), (10, 3, "F5", 1), (11, 0, "E5", 4),
              (12, 0, "A5", 2), (12, 2, "C6", 2), (13, 0, "A5", 3), (13, 3, "G5", 1), (14, 0, "E5", 2), (14, 2, "G5", 2), (15, 0, "D5", 4),
              (16, 0, "F5", 2), (16, 2, "A5", 2), (17, 0, "G5", 4), (18, 0, "D6", 3), (18, 3, "C6", 1), (19, 0, "A5", 4)]
    for bar, beat, note, length in melody:
        s.add("lead", lead(midi(n(note)), s.beat * length * 0.95, 0.32) * 0.8, bar, beat)
    s.stems["bells"] = circular_delay(s.stems["bells"], s.beat * 0.75, feedback=0.45, mix=0.4)
    s.stems["lead"] = fft_filter(s.stems["lead"], high=3500)
    mix_song(s, {"pad": 0.6, "bass": 0.55, "bells": 0.45, "drums": 0.45, "shaker": 0.2, "lead": 0.4},
             {"bells": 0.3, "shaker": -0.3, "lead": -0.15}, {"pad": 0.5, "bells": 0.5, "lead": 0.55, "drums": 0.1}, "music_night")


# ---------------------------------------------------------------- Soundeffekte

def sfx():
    # Ziel einer Stage: kurzes Glocken-Arpeggio nach oben
    track = np.zeros(int(1.6 * RATE))
    for i, note in enumerate(("C6", "E6", "G6", "C7")):
        place(track, bell(midi(n(note)), 1.2, 0.8), i * 0.07 * RATE)
    save("sfx_finish", norm(circular_reverb(np.concatenate([track, np.zeros(int(0.4 * RATE))]), 1.2, 0.3), 0.8))

    # Neue Bestzeit: kleine Fanfare (Supersaw-Akkorde plus Glocken)
    length = 2.6
    track = np.zeros(int(length * RATE))
    for i, chord in enumerate(((n("C5"), "maj"), (n("F5"), "maj"), (n("G5"), "maj"))):
        for note in chord_notes(*chord):
            place(track, supersaw(midi(note), 0.22 if i < 2 else 1.1, velocity=0.6, attack=0.005, release=0.4), i * 0.18 * RATE)
    for i, note in enumerate(("G6", "C7", "E7", "G7")):
        place(track, bell(midi(n(note)), 1.2, 0.35), (0.36 + i * 0.06) * RATE)
    place(track, kick(0.5), 0.36 * RATE)
    save("sfx_pb", norm(circular_reverb(track, 1.4, 0.3), 0.85))

    # Map geschafft: laengere Fanfare
    length = 4.2
    track = np.zeros(int(length * RATE))
    seq = [((n("A4"), "min"), 0, 0.3), ((n("F4"), "maj"), 0.32, 0.3), ((n("G4"), "maj"), 0.64, 0.3), ((n("C5"), "maj"), 0.96, 2.0)]
    for chord, start, hold in seq:
        for note in chord_notes(*chord) + [chord[0] + 12]:
            place(track, supersaw(midi(note), hold, velocity=0.55, attack=0.006, release=0.6), start * RATE)
        place(track, kick(0.5), start * RATE)
    for i in range(10):
        place(track, bell(midi(n("C6") + (0, 4, 7, 12, 16, 19, 24, 19, 16, 12)[i]), 1.0, 0.3), (1.0 + i * 0.08) * RATE)
    save("sfx_mapclear", norm(circular_reverb(track, 1.8, 0.35), 0.85))

    # Medaille: helles Glitzern
    track = np.zeros(int(1.5 * RATE))
    for i in range(6):
        place(track, bell(midi(n("E7") + (0, 3, 7, 12, 7, 12)[i]), 0.9, 0.5), i * 0.05 * RATE)
    save("sfx_medal", norm(circular_reverb(track, 1.0, 0.35), 0.7))

    # Surf-Rauschen (Schleife): Ski schneidet durch Schnee, gefiltertes Rauschen mit leichtem Wabern
    length = 4.0
    count = int(length * RATE)
    x = np.arange(count) / RATE
    noise = rng.standard_normal(count)
    band = fft_filter(noise, low=900, high=5500)
    grain = fft_filter(rng.standard_normal(count), low=150, high=900) * 0.5
    wobble = 0.8 + 0.2 * np.sin(2 * np.pi * x / length * 4)
    loop = (band + grain) * wobble
    save("sfx_carve", norm(loop, 0.6))

    # Landung: dumpfer Schnee-Plumps mit Knirschen
    x = tt(0.45)
    thump = np.sin(2 * np.pi * (70 + 60 * np.exp(-x * 25)) * x) * np.exp(-x * 14)
    crunch = fft_filter(rng.standard_normal(len(x)), low=600, high=4000) * np.exp(-x * 22)
    save("sfx_land", norm(np.tanh(thump * 1.5 + norm(crunch) * 0.6), 0.75))

    # Start: Luftzug-Wusch
    x = tt(0.9)
    noise = rng.standard_normal(len(x))
    sweep = np.zeros(len(x))
    window = 2048
    for i in range(0, len(x), window // 2):
        seg = noise[i:i + window]
        centre = 400 + 4200 * (i / len(x)) ** 1.5
        filtered = fft_filter(seg, low=centre * 0.6, high=centre * 1.4) * np.hanning(len(seg))
        sweep[i:i + len(seg)] += filtered
    save("sfx_whoosh", norm(sweep * np.sin(np.pi * x / 0.9) ** 1.5, 0.7))

    # Feuerwerk: Abschuss-Pfeifen und Knall mit Knistern
    length = 2.6
    track = np.zeros(int(length * RATE))
    x = tt(0.7)
    whistle = np.sin(2 * np.pi * np.cumsum(1200 + 1600 * (x / 0.7)) / RATE) * np.sin(np.pi * x / 0.7) * 0.3
    place(track, whistle, 0)
    boom = kick(1.0, 1.4) + fft_filter(rng.standard_normal(int(RATE)), high=1800) * np.exp(-tt(1.0) * 5) * 0.8
    place(track, boom, 0.7 * RATE)
    for _ in range(60):
        start = rng.uniform(0.8, 2.3)
        pop = rng.standard_normal(300) * np.exp(-np.arange(300) / 40)
        place(track, fft_filter(pop, low=2000) * rng.uniform(0.2, 0.6), start * RATE)
    save("sfx_firework", norm(circular_reverb(track, 1.5, 0.3), 0.8))

    # Lagerfeuer (Schleife): Rauschen und Knacken
    length = 6.0
    count = int(length * RATE)
    roar = fft_filter(rng.standard_normal(count), low=80, high=700) * 0.5
    crack = np.zeros(count)
    for _ in range(110):
        pos = int(rng.uniform(0, count - 800))
        size = int(rng.uniform(80, 700))
        crack[pos:pos + size] += rng.standard_normal(size) * np.exp(-np.arange(size) / (size / 5)) * rng.uniform(0.3, 1.2)
    crack = fft_filter(crack, low=900, high=9000)
    save("sfx_fire", norm(roar + crack, 0.6))

    # ---- Team-Modus (Schneeball- und Eis-Blaster)
    # Wurf: kurzes Luft-Fump
    x = tt(0.25)
    fump = np.sin(2 * np.pi * (220 * np.exp(-x * 20) + 90) * x) * np.exp(-x * 18)
    air = fft_filter(rng.standard_normal(len(x)), low=1500, high=6000) * np.exp(-x * 30) * 0.4
    save("sfx_throw", norm(fump + air, 0.7))

    # Eis-Blaster: glitzernder Laser-Zisch nach unten
    x = tt(0.35)
    f = 2600 * np.exp(-x * 6) + 500
    zap = np.sin(2 * np.pi * np.cumsum(f) / RATE) + 0.4 * np.sin(2 * np.pi * np.cumsum(f * 1.5) / RATE)
    save("sfx_zap", norm(zap * np.exp(-x * 9) * np.minimum(1, x / 0.003), 0.6))

    # Treffer am Gegner: Schnee-Platsch
    x = tt(0.4)
    splat = fft_filter(rng.standard_normal(len(x)), low=300, high=3500) * np.exp(-x * 16)
    thud = np.sin(2 * np.pi * (120 * np.exp(-x * 25) + 60) * x) * np.exp(-x * 20)
    save("sfx_splat", norm(splat + thud, 0.75))

    # Eingefroren: knackendes Eis plus Glockenschimmer
    track = np.zeros(int(1.4 * RATE))
    for _ in range(18):
        start = rng.uniform(0, 0.35)
        size = int(rng.uniform(200, 1500))
        place(track, fft_filter(rng.standard_normal(size) * np.exp(-np.arange(size) / (size / 4)), low=1500) * rng.uniform(0.3, 1), start * RATE)
    for i, note in enumerate(("B6", "F#7", "B7")):
        place(track, bell(midi(n(note)), 1.0, 0.3), (0.15 + i * 0.05) * RATE)
    save("sfx_freeze", norm(circular_reverb(track, 0.9, 0.3), 0.75))

    # Waffe aufgehoben: zwei helle Toene nach oben
    track = np.zeros(int(0.8 * RATE))
    place(track, bell(midi(n("A5")), 0.7, 0.6), 0)
    place(track, bell(midi(n("E6")), 0.7, 0.6), 0.07 * RATE)
    save("sfx_pickup", norm(track, 0.7))

    # Runden-Start: drei Countdown-Toene und ein hoher
    track = np.zeros(int(3.6 * RATE))
    for i in range(4):
        x = tt(0.35 if i < 3 else 0.9)
        tone = additive(880 if i < 3 else 1760, len(x) / RATE, 6, odd=True, bright=0.5) * adsr(len(x) / RATE, 0.005, 0.1, 0.6, 0.1)
        place(track, tone, i * RATE)
    save("sfx_countdown", norm(track, 0.6))


if __name__ == "__main__":
    which = sys.argv[1:] or ["lobby", "run", "night", "sfx"]
    if "lobby" in which:
        song_lobby()
    if "run" in which:
        song_run()
    if "night" in which:
        song_night()
    if "sfx" in which:
        sfx()
