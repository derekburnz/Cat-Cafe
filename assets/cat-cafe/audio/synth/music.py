"""Synthesize Cat Cafe's music beds: three quiet, cosy loops that take turns with the day and night.

Run from the repo root:  python assets/cat-cafe/audio/synth/music.py [--only DayA,NightA] [--preview DIR]

Derek (2026-10-27): the ambience beds are not needed; play a couple of cosy songs that rotate, quietly.
The Audio module already rotates beds with the clock (sound list section 3): DayA for the first half of
the day, DayB for the second, NightA through the short night, then DayA again at sunrise.

  DayA  "Open for Business"  F major, 88 BPM, swung: electric piano, upright bass, brushes, vibraphone tune
  DayB  "Second Cup"         G major, 84 BPM, bossa: nylon guitar, flute tune, shaker and rim clicks
  NightA "After Hours"       C major, 72 BPM, waltz: harp, soft strings, music box tune

Every note is synthesized (sine partials, plucked strings, filtered noise) with fixed seeds, so the music is
original and the same on every run. Each song is exactly 32 bars and every note, tail and echo wraps around
the end, so the loop is seamless. Outputs (overwritten): assets/cat-cafe/audio/music/CatCafe_Music_<Name>.ogg
(stereo, 48 kHz, about -18 LUFS); with --preview: DIR/cat-cafe-music-preview.mp3 (40 s of each).
Needs numpy and ffmpeg. Check the files with .claude/skills/audio-pipeline/scripts/audio_gate.py.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

from synth import CELESTA, SR, VIBES, bell, note  # same folder

ROOT = Path(__file__).resolve().parents[1]  # assets/cat-cafe/audio
TARGET_LUFS = -18.0
CEILING_DB = -2.0  # sample peak; the gate's limit is -1 dBTP
BARS = 32


# --- building blocks ---------------------------------------------------------------------------


def seconds(d: float) -> np.ndarray:
    return np.arange(int(d * SR)) / SR


def lowpass(x: np.ndarray, hi: float, order: int = 2) -> np.ndarray:
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(np.fft.rfft(x) / np.sqrt(1 + (f / hi) ** (2 * order)), len(x))


def bandpass(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    f = np.maximum(np.fft.rfftfreq(len(x), 1 / SR), 1e-3)
    gain = 1 / np.sqrt(1 + (lo / f) ** 4) / np.sqrt(1 + (f / hi) ** 4)
    return np.fft.irfft(np.fft.rfft(x) * gain, len(x))


def release(x: np.ndarray, hold: float, tail: float) -> np.ndarray:
    """Let a note ring for `hold` seconds, then fade it out over `tail` seconds (a key or string let go)."""
    t = np.arange(len(x)) / SR
    return x * np.clip(1 - (t - hold) / tail, 0, 1)


class Song:
    """A stereo loop of a whole number of bars. Everything placed on it wraps around the end."""

    def __init__(self, bpm: float, meter: int, seed: int, swing: float = 0.0):
        self.beat = 60.0 / bpm
        self.meter = meter
        self.swing = swing  # how late an off-beat eighth lands, in beats
        self.n = round(BARS * meter * self.beat * SR)
        self.rng = np.random.default_rng(seed)

    def time(self, bar: int, beat: float) -> float:
        if self.swing and abs(beat % 1 - 0.5) < 1e-6:
            beat += self.swing
        return (bar * self.meter + beat) * self.beat

    def stem(self) -> np.ndarray:
        return np.zeros((self.n, 2))

    def put(self, stem: np.ndarray, x: np.ndarray, bar: int, beat: float, pan: float = 0.0, gain: float = 1.0,
            loose: float = 0.006) -> None:
        start = self.time(bar, beat) + (self.rng.normal(0, loose) if loose else 0.0)
        index = (np.arange(len(x)) + int(round(start * SR))) % self.n
        angle = (pan + 1) * np.pi / 4
        stem[index, 0] += x * gain * np.cos(angle)
        stem[index, 1] += x * gain * np.sin(angle)


def reverb(x: np.ndarray, seconds_: float, seed: int, hi: float = 6000.0) -> np.ndarray:
    """A small warm room, circular over the loop so the echo of the last bar lands on the first."""
    n = len(x)
    length = int(seconds_ * SR)
    t = np.arange(length) / SR
    out = np.empty_like(x)
    for channel in (0, 1):
        ir = np.random.default_rng(seed + channel).standard_normal(length) * np.exp(-6.9 * t / seconds_)
        ir = lowpass(ir, hi)
        ir[: int(0.015 * SR)] = 0
        full = np.zeros(n)
        full[:length] = ir / np.sqrt(np.sum(ir**2))
        out[:, channel] = np.fft.irfft(np.fft.rfft(x[:, channel]) * np.fft.rfft(full), n)
    return out


# --- instruments -------------------------------------------------------------------------------


def epiano(hold: float, f: float, velocity: float) -> np.ndarray:
    """A soft electric piano: a sine tine with a little FM bark that fades, and a slow tremolo."""
    t = seconds(hold + 0.5)
    index = 0.25 + 1.1 * velocity * np.exp(-t / 0.3)
    tone = np.sin(2 * np.pi * f * t + index * np.sin(2 * np.pi * f * t))
    tine = 0.12 * np.sin(2 * np.pi * 7 * f * t) * np.exp(-t / 0.05)
    env = np.clip(t / 0.004, 0, 1) * np.exp(-t / 1.8)
    trem = 1 - 0.07 * (0.5 + 0.5 * np.sin(2 * np.pi * 4.2 * t))
    return release((tone + tine) * env * trem * velocity, hold, 0.35)


def pluck(hold: float, f: float, seed: int, bright: float = 0.5, ring: float = 2.5) -> np.ndarray:
    """A nylon string (Karplus-Strong): a burst of noise circulating in a delay line one period long."""
    period = max(2, int(round(SR / f - 0.5)))
    n = int((hold + 0.3) * SR)
    burst = np.random.default_rng(seed).uniform(-1, 1, period)
    burst = lowpass(np.tile(burst, 4), 1500 + 6000 * bright)[:period]
    burst -= burst.mean()
    loss = 10 ** (-3 * period / (SR * ring))
    y = np.zeros(n + period + 1)
    y[1 : period + 1] = burst
    for start in range(period + 1, len(y), period):
        end = min(start + period, len(y))
        y[start:end] = loss * 0.5 * (y[start - period : end - period] + y[start - period - 1 : end - period - 1])
    # The loop sounds at SR / (period + 0.5); resample so the note lands exactly on f.
    played = SR / (period + 0.5)
    x = np.interp(np.arange(n) * f / played, np.arange(len(y) - 1), y[1:])
    return release(x / (np.max(np.abs(x)) + 1e-9), hold, 0.25)


def upright(hold: float, f: float, velocity: float) -> np.ndarray:
    """A plucked upright bass: round low partials, a soft thump at the start."""
    t = seconds(hold + 0.3)
    tone = np.sin(2 * np.pi * f * t) + 0.5 * np.sin(4 * np.pi * f * t) + 0.22 * np.sin(6 * np.pi * f * t)
    env = np.clip(t / 0.008, 0, 1) * np.exp(-t / 0.9)
    thump = lowpass(np.random.default_rng(int(f)).standard_normal(len(t)), 400) * np.exp(-t / 0.02) * 0.4
    return release(tone * env + thump, hold, 0.12) * velocity


def flute(hold: float, f: float, seed: int) -> np.ndarray:
    """A breathy flute: a near sine with a touch of second harmonic, breath noise and a late vibrato."""
    t = seconds(hold + 0.12)
    vib = 1 + 0.005 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.25) / 0.3, 0, 1)
    phase = 2 * np.pi * np.cumsum(f * vib) / SR
    tone = np.sin(phase) + 0.18 * np.sin(2 * phase) + 0.05 * np.sin(3 * phase)
    breath = bandpass(np.random.default_rng(seed).standard_normal(len(t)), f * 1.5, f * 4) * 0.12
    env = np.clip(t / 0.06, 0, 1) * np.clip((hold + 0.1 - t) / 0.1, 0, 1)
    return (tone + breath) * env


def vibraphone(hold: float, f: float) -> np.ndarray:
    t = seconds(hold + 1.0)
    x = bell(hold + 1.0, f, VIBES, attack=0.002) * (1 - 0.2 * (0.5 + 0.5 * np.sin(2 * np.pi * 5.0 * t)))
    return release(x, hold + 0.4, 0.6)


def music_box(f: float) -> np.ndarray:
    return bell(1.6, f, CELESTA, attack=0.0015)


def strings(hold: float, freqs, seed: int) -> np.ndarray:
    """A soft string pad: gently detuned saws through a low lowpass, slow to swell and to let go."""
    t = seconds(hold + 0.9)
    r = np.random.default_rng(seed)
    x = np.zeros_like(t)
    for f in freqs:
        for detune in (-0.0025, 0.0025):
            vib = 1 + 0.002 * np.sin(2 * np.pi * r.uniform(4.5, 5.5) * t + r.uniform(0, 6.3))
            phase = (np.cumsum(f * (1 + detune) * vib) / SR + r.random()) % 1.0
            x += 2 * phase - 1
    x = lowpass(x, 950)
    env = np.clip(t / 0.6, 0, 1) * np.clip((hold + 0.8 - t) / 0.8, 0, 1)
    return x / (np.max(np.abs(x)) + 1e-9) * env


def noise_hit(seed: int, d: float, lo: float, hi: float, attack: float, tau: float) -> np.ndarray:
    t = seconds(d)
    x = bandpass(np.random.default_rng(seed).standard_normal(len(t)), lo, hi)
    return x / (np.max(np.abs(x)) + 1e-9) * np.clip(t / attack, 0, 1) * np.exp(-t / tau)


def kick() -> np.ndarray:
    t = seconds(0.4)
    f = 48 + 40 * np.exp(-t / 0.03)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.12)


def rim(seed: int) -> np.ndarray:
    return noise_hit(seed, 0.08, 1400, 2600, 0.0008, 0.012)


def glock(f: float) -> np.ndarray:
    return bell(1.2, f, ((1.0, 1.0, 0.4), (2.76, 0.3, 0.12), (5.4, 0.1, 0.05)), attack=0.001)


def chord(names: str) -> list[float]:
    return [note(n) for n in names.split()]


def melody(text: str) -> list[tuple[int, float, float, float]]:
    """'bar beat length note; ...' (bar within the 8-bar phrase, beats from 0) -> (bar, beat, beats, hz)."""
    out = []
    for item in text.split(";"):
        bar, beat, length, name = item.split()
        out.append((int(bar), float(beat), float(length), note(name)))
    return out


# --- mixing ------------------------------------------------------------------------------------


def write_wav(path: Path, x: np.ndarray) -> None:
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(x.shape[1] if x.ndim == 2 else 1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def lufs(x: np.ndarray, tmp: Path) -> float:
    probe = tmp / "probe.wav"
    write_wav(probe, x / (np.max(np.abs(x)) + 1e-12) * 0.5)
    out = subprocess.run(["ffmpeg", "-nostats", "-i", str(probe), "-af", "ebur128", "-f", "null", "-"],
                         capture_output=True, text=True, check=True).stderr
    return float(re.findall(r"I:\s+(-?[\d.]+) LUFS", out)[-1]) - 20 * np.log10(0.5 / (np.max(np.abs(x)) + 1e-12))


def blend(stems: dict[str, tuple[np.ndarray, float, float]], seed: int, tmp: Path) -> np.ndarray:
    """Set each stem to its loudness (LU against the tune), add its share of one room, master to TARGET_LUFS."""
    dry = None
    send = None
    for name, (x, loudness, wet) in stems.items():
        x = x * 10 ** ((loudness - lufs(x, tmp)) / 20)
        dry = x if dry is None else dry + x
        send = x * wet if send is None else send + x * wet
    mix = dry + reverb(send, 2.2, seed)
    mix = mix * 10 ** ((TARGET_LUFS - lufs(mix, tmp)) / 20)
    ceiling = 10 ** (CEILING_DB / 20)
    knee = ceiling * 0.7
    over = np.abs(mix) > knee
    mix[over] = np.sign(mix[over]) * (knee + (ceiling - knee) * np.tanh((np.abs(mix[over]) - knee) / (ceiling - knee)))
    return mix


# --- the songs ---------------------------------------------------------------------------------


def day_a(tmp: Path) -> np.ndarray:
    """Open for Business: the cafe is open and content. Four times through eight bars: piano, bass and brushes;
    the vibraphone tune; a nylon guitar takes over; the tune again on a music box."""
    s = Song(88, 4, seed=11, swing=0.08)
    bars = [  # bass root, bass fifth, the note leading to the next root, voicing (then the second-half voicing)
        ("F2", "C3", "E2", "A3 C4 E4 G4", None),
        ("A2", "E3", "A2", "G3 A3 C4 E4", None),
        ("Bb2", "F2", "B2", "A3 Bb3 D4 F4", None),
        ("C3", "G2", "E2", "Bb3 C4 F4 G4", "Bb3 C4 E4 G4"),
        ("F2", "C3", "C#3", "A3 C4 E4 G4", None),
        ("D3", "A2", "F#2", "F3 A3 C4 E4", None),
        ("G2", "D3", "B2", "F3 A3 Bb3 D4", None),
        ("C3", "G2", "E2", "E3 G3 Bb3 D4", None),
    ]
    tune = melody("0 0 1 C5; 0 1 1 A4; 0 2 0.5 G4; 0 2.5 1.5 A4;"
                  "1 0 1.5 E5; 1 1.5 0.5 D5; 1 2 2 C5;"
                  "2 0 1 D5; 2 1 0.5 C5; 2 1.5 0.5 Bb4; 2 2 1 A4; 2 3 1 F4;"
                  "3 0 2 G4; 3 2 1 Bb4; 3 3 0.5 A4; 3 3.5 0.5 G4;"
                  "4 0 1.5 A4; 4 1.5 0.5 C5; 4 2 1 F5; 4 3 1 E5;"
                  "5 0 1.5 D5; 5 1.5 0.5 C5; 5 2 2 A4;"
                  "6 0 1 Bb4; 6 1 0.5 A4; 6 1.5 0.5 G4; 6 2 1.5 D5; 6 3.5 0.5 C5;"
                  "7 0 2 C5; 7 2 0.5 Bb4; 7 2.5 0.5 A4; 7 3 1 G4")
    keys, bass, lead, guitar, kit = s.stem(), s.stem(), s.stem(), s.stem(), s.stem()
    for bar in range(BARS):
        root, fifth, lead_in, voicing, second = bars[bar % 8]
        section = bar // 8
        first = chord(voicing)
        for i, f in enumerate(first):
            s.put(keys, epiano(1.4, f, 0.75), bar, 0.0, pan=-0.3 + 0.2 * i, loose=0.004)
        for i, f in enumerate(chord(second or voicing)):
            s.put(keys, epiano(1.2, f, 0.5), bar, 2.5, pan=-0.3 + 0.2 * i, loose=0.004)
        s.put(bass, upright(1.4, note(root), 1.0), bar, 0.0)
        s.put(bass, upright(1.2, note(fifth), 0.8), bar, 2.0)
        if section > 0 and bar % 2 == 1:
            s.put(bass, upright(0.4, note(lead_in), 0.6), bar, 3.5)
        for beat in range(4):
            s.put(kit, noise_hit(bar * 8 + beat, 0.35, 2500, 9000, 0.03, 0.09), bar, beat, pan=0.2, gain=0.5)
            if beat in (1, 3):
                s.put(kit, noise_hit(bar * 8 + beat + 4, 0.2, 1200, 5000, 0.002, 0.05), bar, beat, pan=-0.1)
            if section > 0:
                s.put(kit, noise_hit(bar * 16 + beat, 0.12, 5000, 11000, 0.006, 0.03), bar, beat + 0.5, pan=0.5,
                      gain=0.35)
        if section > 0:
            s.put(kit, kick(), bar, 0.0, gain=0.8)
        if section == 2:  # the guitar picks the chord in swung eighths
            pattern = [0, 1, 2, 3, 2, 1, 2, 3]
            for k, i in enumerate(pattern):
                f = first[i] * 2
                s.put(guitar, pluck(0.6, f, bar * 8 + k, bright=0.35), bar, k * 0.5, pan=0.4 - 0.1 * (k % 2))
        if section in (1, 3):
            for b, beat, length, f in tune:
                if b == bar % 8:
                    if section == 1:
                        s.put(lead, vibraphone(length * s.beat, f), bar, beat, pan=0.1)
                    else:
                        s.put(lead, music_box(f * 2) * 0.8, bar, beat, pan=0.15)
        if bar % 8 == 7:  # a glockenspiel sparkle closes every phrase
            for k, name in enumerate(("C6", "F6")):
                s.put(lead, glock(note(name)) * 0.35, bar, 3.0 + 0.5 * k, pan=0.3)
    return blend({"lead": (lead, -20, 0.3), "keys": (keys, -23, 0.25), "bass": (bass, -24, 0.05),
                  "guitar": (guitar, -23, 0.25), "kit": (kit, -31, 0.15)}, 101, tmp)


def day_b(tmp: Path) -> np.ndarray:
    """Second Cup: a lazy afternoon bossa. Guitar alone; the flute tune; the vibraphone answers an octave up;
    the flute again."""
    s = Song(84, 4, seed=21)
    bars = [
        ("G2", "D3", "G3 B3 D4 F#4"), ("G2", "D3", "G3 B3 D4 F#4"),
        ("A2", "E3", "G3 A3 C4 E4"), ("D3", "A2", "F#3 A3 C4 E4"),
        ("B2", "F#2", "A3 B3 D4 F#4"), ("E2", "B2", "G#3 B3 D4 F#4"),
        ("A2", "E3", "G3 A3 C4 E4"), ("D3", "A2", "F#3 A3 C4 E4"),
    ]
    tune = melody("0 0 1.5 B4; 0 1.5 0.5 A4; 0 2 1 B4; 0 3 1 D5;"
                  "1 0 2 F#5; 1 2 1 E5; 1 3 1 D5;"
                  "2 0 1.5 C5; 2 1.5 0.5 B4; 2 2 1 A4; 2 3 1 E5;"
                  "3 0 2 D5; 3 2 1 C5; 3 3 1 A4;"
                  "4 0 1 B4; 4 1 1 D5; 4 2 1.5 F#5; 4 3.5 0.5 E5;"
                  "5 0 1.5 D5; 5 1.5 0.5 B4; 5 2 2 G#4;"
                  "6 0 1 A4; 6 1 1 C5; 6 2 1.5 E5; 6 3.5 0.5 D5;"
                  "7 0 1 C5; 7 1 1 A4; 7 2 1 F#4; 7 3 1 A4")
    comp, thumb, lead, kit = s.stem(), s.stem(), s.stem(), s.stem()
    for bar in range(BARS):
        root, fifth, voicing = bars[bar % 8]
        section = bar // 8
        s.put(thumb, pluck(1.6, note(root), bar * 2, bright=0.2, ring=1.6), bar, 0.0, pan=-0.1)
        s.put(thumb, pluck(1.6, note(fifth), bar * 2 + 1, bright=0.2, ring=1.6), bar, 2.0, pan=-0.1)
        hits = (0.0, 1.5, 3.0) if bar % 2 == 0 else (0.5, 2.0, 3.5)
        for h, beat in enumerate(hits):
            for i, f in enumerate(chord(voicing)):  # a soft strum, lowest string first
                s.put(comp, pluck(0.7, f, bar * 40 + h * 5 + i, bright=0.4, ring=1.2) * (0.9 - 0.15 * h), bar,
                      beat + 0.012 * i / s.beat, pan=-0.25, loose=0.003)
        for k in range(8):  # shaker eighths, the beat a little stronger
            s.put(kit, noise_hit(bar * 8 + k, 0.1, 5000, 11000, 0.008, 0.025), bar, k * 0.5, pan=0.45,
                  gain=0.6 if k % 2 == 0 else 0.4)
        clave = (0.0, 1.5, 3.0) if bar % 2 == 0 else (1.0, 2.0)
        if section > 0:
            for beat in clave:
                s.put(kit, rim(bar * 4 + int(beat * 2)), bar, beat, pan=-0.35, gain=0.5)
        if section in (1, 2, 3):
            for b, beat, length, f in tune:
                if b == bar % 8:
                    if section == 2:
                        s.put(lead, vibraphone(length * s.beat, f * 2) * 0.7, bar, beat, pan=0.2)
                    else:
                        s.put(lead, flute(length * s.beat * 0.95, f, bar * 10 + int(beat * 2)), bar, beat, pan=0.1)
    return blend({"lead": (lead, -20, 0.3), "comp": (comp, -23, 0.2), "thumb": (thumb, -24, 0.1),
                  "kit": (kit, -31, 0.1)}, 201, tmp)


def night_a(tmp: Path) -> np.ndarray:
    """After Hours: a lullaby waltz for the short night. Harp and strings; the music box tune; the vibraphone
    an octave down; the music box again."""
    s = Song(72, 3, seed=31)
    bars = [
        ("C3", "C4 E4 G4 B4"), ("A2", "C4 E4 G4 A4"), ("F2", "C4 F4 A4 E5"), ("G2", "C4 D4 F4 G4"),
        ("E2", "B3 D4 E4 G4"), ("A2", "C4 E4 G4 A4"), ("D3", "C4 D4 F4 A4"), ("G2", "B3 D4 F4 G4"),
    ]
    tune = melody("0 0 1 E5; 0 1 1 G5; 0 2 1 E5;"
                  "1 0 2 C5; 1 2 1 A4;"
                  "2 0 1 A4; 2 1 1 C5; 2 2 1 F5;"
                  "3 0 2 D5; 3 2 1 B4;"
                  "4 0 1 B4; 4 1 1 E5; 4 2 1 G5;"
                  "5 0 2 E5; 5 2 1 C5;"
                  "6 0 1 D5; 6 1 1 F5; 6 2 1 C5;"
                  "7 0 2 B4; 7 2 1 G4")
    harp, pad, lead = s.stem(), s.stem(), s.stem()
    for bar in range(BARS):
        root, voicing = bars[bar % 8]
        section = bar // 8
        notes = chord(voicing)
        s.put(harp, pluck(2.0, note(root), bar * 7, bright=0.3, ring=3.0), bar, 0.0, pan=-0.2)
        for k, i in enumerate((0, 1, 2, 3, 2)):  # a rocking arpeggio on the eighths after the bass
            s.put(harp, pluck(1.2, notes[i], bar * 7 + k + 1, bright=0.45, ring=2.5) * 0.7, bar, 0.5 + 0.5 * k,
                  pan=-0.2 + 0.1 * k)
        s.put(pad, strings(3 * s.beat, [f / 2 for f in notes[:3]], bar), bar, 0.0, loose=0)
        if section in (1, 2, 3):
            for b, beat, length, f in tune:
                if b == bar % 8:
                    if section == 2:
                        s.put(lead, vibraphone(length * s.beat, f / 2 * 2), bar, beat, pan=0.15)
                    else:
                        s.put(lead, music_box(f * 2) * 0.9, bar, beat, pan=0.2)
    return blend({"lead": (lead, -20, 0.35), "harp": (harp, -22, 0.3), "pad": (pad, -27, 0.4)}, 301, tmp)


SONGS = {"DayA": day_a, "DayB": day_b, "NightA": night_a}


def encode(wav: Path, out: Path, codec: list[str]) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-ar", str(SR), *codec,
                    "-fflags", "+bitexact", "-flags:a", "+bitexact", str(out)], check=True)


def preview(rendered: dict[str, np.ndarray], folder: Path, tmp: Path) -> Path:
    length, fade = int(40 * SR), int(2 * SR)
    track = np.zeros((0, 2))
    for x in rendered.values():
        part = x[:length].copy()
        part[-fade:] *= np.linspace(1, 0, fade)[:, None]
        track = np.concatenate([track, part, np.zeros((SR, 2))])
    wav = tmp / "preview.wav"
    write_wav(wav, track)
    out = folder / "cat-cafe-music-preview.mp3"
    encode(wav, out, ["-c:a", "libmp3lame", "-q:a", "2"])
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--only", help="comma list of names, e.g. DayA,NightA")
    parser.add_argument("--preview", help="folder for a listening preview mp3")
    args = parser.parse_args()

    names = list(SONGS) if not args.only else [n.strip() for n in args.only.split(",")]
    unknown = [n for n in names if n not in SONGS]
    if unknown:
        print(f"music: unknown song(s) {', '.join(unknown)}; known: {', '.join(SONGS)}", file=sys.stderr)
        return 2

    rendered: dict[str, np.ndarray] = {}
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        for name in names:
            x = SONGS[name](tmp)
            rendered[name] = x
            wav = tmp / f"{name}.wav"
            write_wav(wav, x)
            out = ROOT / "music" / f"CatCafe_Music_{name}.ogg"
            encode(wav, out, ["-c:a", "libvorbis", "-q:a", "5"])
            print(f"music: {out.relative_to(ROOT.parents[2]).as_posix()}  {len(x) / SR:.1f} s")
        if args.preview:
            folder = Path(args.preview)
            folder.mkdir(parents=True, exist_ok=True)
            print(f"music: preview {preview(rendered, folder, tmp).as_posix()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
