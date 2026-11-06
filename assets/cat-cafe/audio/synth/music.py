"""Synthesize Cat Cafe's music beds: three quiet, cozy loops that take turns with the day and night.

Run from the repo root:  python assets/cat-cafe/audio/synth/music.py [--only DayA,NightA] [--preview DIR]

Derek (2026-10-27): the ambience beds are not needed; play a couple of cozy songs that rotate, quietly.
The Audio module already rotates beds with the clock (sound list section 3): DayA for the first half of
the day, DayB for the second, NightA through the short night, then DayA again at sunrise.

  DayA  "Open for Business"  F major, 88 BPM, swung: electric piano, upright bass, brushes, vibraphone tune
  DayB  "Second Cup"         G major, 84 BPM, bossa: nylon guitar, flute tune, shaker and rim clicks
  NightA "After Hours"       C major, 72 BPM, waltz: harp, soft strings, music box tune

Every note is synthesized (sine partials, plucked strings, filtered noise) with fixed seeds, so the music is
original and the same on every run. Each song is exactly 32 bars and every note, tail and echo wraps around
the end, so the loop is seamless. Outputs (overwritten): assets/cat-cafe/audio/music/CatCafe_Music_<Name>.ogg
(DayC, DayD and NightB go to sheet-parts/music/ instead, joined into sheets/CatCafe_Sheet_Music.ogg, see SHEET)
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

    def __init__(self, bpm: float, meter: int, seed: int, swing: float = 0.0, bars: int = BARS):
        self.beat = 60.0 / bpm
        self.meter = meter
        self.swing = swing  # how late an off-beat eighth lands, in beats
        self.n = round(bars * meter * self.beat * SR)
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


MARIMBA = ((1.0, 1.0, 0.42), (3.93, 0.22, 0.06), (9.3, 0.05, 0.025))


def marimba(f: float, velocity: float = 1.0) -> np.ndarray:
    """A wooden bar: a round fundamental and a quick bright overtone, plus a soft mallet tick."""
    t = seconds(1.0)
    tick = lowpass(np.random.default_rng(int(f * 7)).standard_normal(len(t)), 2500) * np.exp(-t / 0.004) * 0.15
    return (bell(1.0, f, MARIMBA, attack=0.0015) + tick) * velocity


def clap(seed: int) -> np.ndarray:
    """A soft clap: two quick bursts of band-limited noise and a short tail."""
    x = np.zeros(int(0.25 * SR))
    for k, at in enumerate((0.0, 0.009, 0.019)):
        burst = noise_hit(seed + k, 0.2, 900, 4200, 0.0006, 0.008 if k < 2 else 0.05)
        start = int(at * SR)
        end = min(len(x), start + len(burst))
        x[start:end] += burst[: end - start] * (0.7 if k < 2 else 1.0)
    return x


def day_c(tmp: Path) -> np.ndarray:
    """Paw Prints: playful, padding about. Pizzicato strings bounce on the chords; the tune on a marimba; a flute
    takes it an octave up; the marimba again with a glockenspiel on top."""
    s = Song(104, 4, seed=41)
    bars = [  # bass root, bass fifth, the chord the strings bounce on
        ("D2", "A2", "F#4 A4 D5"), ("B1", "F#2", "F#4 B4 D5"), ("G1", "D2", "G4 B4 D5"), ("A1", "E2", "E4 A4 C#5"),
        ("D2", "A2", "F#4 A4 D5"), ("F#2", "C#3", "F#4 A4 C#5"), ("G1", "D2", "G4 B4 D5"), ("A1", "E2", "E4 G4 C#5"),
    ]
    tune = melody("0 0 0.5 A4; 0 0.5 0.5 F#4; 0 1 1 A4; 0 2 1 D5; 0 3 1 F#5;"
                  "1 0 1.5 E5; 1 1.5 0.5 D5; 1 2 2 B4;"
                  "2 0 0.5 B4; 2 0.5 0.5 D5; 2 1 1 G5; 2 2 1 F#5; 2 3 1 E5;"
                  "3 0 2 E5; 3 2 1 C#5; 3 3 1 A4;"
                  "4 0 0.5 A4; 4 0.5 0.5 F#4; 4 1 1 A4; 4 2 1 D5; 4 3 1 A5;"
                  "5 0 1.5 F#5; 5 1.5 0.5 E5; 5 2 2 C#5;"
                  "6 0 1 B4; 6 1 1 D5; 6 2 1 G5; 6 3 1 E5;"
                  "7 0 1 E5; 7 1 1 C#5; 7 2 2 A4")
    pizz, bass, lead, kit = s.stem(), s.stem(), s.stem(), s.stem()
    for bar in range(BARS):
        root, fifth, voicing = bars[bar % 8]
        section = bar // 8
        notes = chord(voicing)
        for k, i in enumerate((0, 1, 2, 1, 0, 1, 2, 1)):  # bouncing eighths, the beat a little stronger
            s.put(pizz, pluck(0.18, notes[i], bar * 16 + k, bright=0.55, ring=0.5) * (0.8 if k % 2 == 0 else 0.55),
                  bar, k * 0.5, pan=-0.3 + 0.08 * i, loose=0.004)
        s.put(bass, pluck(0.5, note(root), bar * 3, bright=0.25, ring=0.9), bar, 0.0, pan=-0.05)
        s.put(bass, pluck(0.4, note(fifth), bar * 3 + 1, bright=0.25, ring=0.9) * 0.8, bar, 2.0, pan=-0.05)
        s.put(bass, pluck(0.2, note(root) * 2, bar * 3 + 2, bright=0.25, ring=0.9) * 0.6, bar, 3.5, pan=-0.05)
        for k in range(8):
            s.put(kit, noise_hit(bar * 8 + k, 0.08, 5500, 11000, 0.004, 0.02), bar, k * 0.5, pan=0.4,
                  gain=0.5 if k % 2 == 0 else 0.3)
        soft = 0.6 if section == 0 else 1.0  # the kit plays throughout, softer at first, so the loop's seam is level
        for beat in (1, 3):
            s.put(kit, rim(bar * 4 + beat), bar, beat, pan=-0.3, gain=0.55 * soft)
        if section in (1, 2, 3):
            for b, beat, length, f in tune:
                if b == bar % 8:
                    if section == 2:
                        s.put(lead, flute(length * s.beat * 0.9, f * 2, bar * 10 + int(beat * 2)), bar, beat, pan=0.1)
                    else:
                        s.put(lead, marimba(f, 0.9), bar, beat, pan=0.12)
                        if section == 3:
                            s.put(lead, glock(f * 2) * 0.25, bar, beat, pan=0.3)
        if bar % 8 == 7:  # a little run up into the next phrase
            for k, name in enumerate(("A5", "B5", "C#6")):
                s.put(lead, marimba(note(name), 0.5), bar, 2.5 + 0.5 * k, pan=0.35)
    return blend({"lead": (lead, -20, 0.25), "pizz": (pizz, -23, 0.2), "bass": (bass, -26, 0.05),
                  "kit": (kit, -35, 0.1)}, 401, tmp)


def day_d(tmp: Path) -> np.ndarray:
    """Market Morning: sunny and busy. A bright strummed ukulele, bass and claps; the flute tune; a marimba takes
    it; the flute again with a glockenspiel answer."""
    s = Song(112, 4, seed=51)
    bars = [
        ("A2", "E2", "E4 A4 C#5"), ("C#3", "G#2", "E4 G#4 C#5"), ("D3", "A2", "F#4 A4 D5"), ("E2", "B2", "E4 G#4 B4"),
        ("A2", "E2", "E4 A4 C#5"), ("F#2", "C#3", "F#4 A4 C#5"), ("B2", "F#2", "F#4 B4 D5"), ("E2", "B2", "D4 G#4 B4"),
    ]
    tune = melody("0 0 1 E5; 0 1 0.5 C#5; 0 1.5 0.5 E5; 0 2 1.5 A5; 0 3.5 0.5 G#5;"
                  "1 0 1 G#5; 1 1 1 E5; 1 2 2 C#5;"
                  "2 0 0.5 D5; 2 0.5 0.5 E5; 2 1 1 F#5; 2 2 1 A5; 2 3 1 F#5;"
                  "3 0 3 E5; 3 3 0.5 B4; 3 3.5 0.5 C#5;"
                  "4 0 1 E5; 4 1 0.5 C#5; 4 1.5 0.5 E5; 4 2 1 A5; 4 3 1 B5;"
                  "5 0 1.5 C#6; 5 1.5 0.5 B5; 5 2 1 A5; 5 3 1 F#5;"
                  "6 0 1 D5; 6 1 1 F#5; 6 2 1.5 B5; 6 3.5 0.5 A5;"
                  "7 0 1.5 G#5; 7 1.5 0.5 F#5; 7 2 2 E5")
    strum, bass, lead, kit = s.stem(), s.stem(), s.stem(), s.stem()
    hits = ((0.0, 1.0, True), (1.0, 0.7, True), (1.5, 0.55, False), (2.5, 0.6, False), (3.0, 0.8, True),
            (3.5, 0.55, False))
    for bar in range(BARS):
        root, fifth, voicing = bars[bar % 8]
        section = bar // 8
        notes = chord(voicing)
        for h, (beat, accent, down) in enumerate(hits):  # down strums low to high, up strums high to low
            order = notes if down else list(reversed(notes))
            for i, f in enumerate(order):
                s.put(strum, pluck(0.35, f, bar * 60 + h * 5 + i, bright=0.7, ring=0.7) * accent, bar,
                      beat + 0.01 * i / s.beat, pan=-0.3, loose=0.003)
        s.put(bass, upright(0.9, note(root), 1.0), bar, 0.0)
        s.put(bass, upright(0.4, note(root), 0.7), bar, 1.5)
        s.put(bass, upright(0.9, note(fifth), 0.85), bar, 2.0)
        for k in range(8):
            s.put(kit, noise_hit(bar * 8 + k, 0.1, 5000, 11000, 0.008, 0.025), bar, k * 0.5, pan=0.45,
                  gain=0.55 if k % 2 == 0 else 0.4)
        soft = 0.6 if section == 0 else 1.0  # the kit plays throughout, softer at first, so the loop's seam is level
        for beat in (1, 3):
            s.put(kit, clap(bar * 4 + beat), bar, beat, pan=0.05, gain=0.5 * soft)
        if section in (1, 2, 3):
            for b, beat, length, f in tune:
                if b == bar % 8:
                    if section == 2:
                        s.put(lead, marimba(f, 0.9), bar, beat, pan=0.12)
                    else:
                        s.put(lead, flute(length * s.beat * 0.9, f, bar * 10 + int(beat * 2)), bar, beat, pan=0.1)
            if section == 3 and bar % 2 == 1:  # the glockenspiel answers each second bar
                for k, f in enumerate(notes[::-1]):
                    s.put(lead, glock(f * 2) * 0.22, bar, 3.0 + 0.25 * k, pan=0.3)
    return blend({"lead": (lead, -20, 0.25), "strum": (strum, -23, 0.15), "bass": (bass, -26, 0.05),
                  "kit": (kit, -35, 0.1)}, 501, tmp)


def night_b(tmp: Path) -> np.ndarray:
    """Night Owls: late and cozy, a little dreamy. A soft electric piano on major seventh chords, upright bass and
    brushes; the music box tune; the vibraphone dreams it an octave down; the music box again."""
    s = Song(76, 4, seed=61, swing=0.07)
    bars = [
        ("F2", "C3", "A3 C4 E4 G4"), ("D3", "A2", "F3 A3 C4 E4"), ("Bb2", "F2", "A3 D4 F4"), ("C3", "G2", "Bb3 E4 G4"),
        ("A2", "E2", "G3 C4 E4"), ("D3", "A2", "F3 A3 C4 E4"), ("G2", "D3", "F3 A3 Bb3 D4"), ("C3", "G2", "Bb3 D4 E4 G4"),
    ]
    tune = melody("0 0 1.5 C5; 0 1.5 0.5 A4; 0 2 2 E5;"
                  "1 0 1 D5; 1 1 1 C5; 1 2 2 A4;"
                  "2 0 1.5 D5; 2 1.5 0.5 C5; 2 2 1 A4; 2 3 1 F4;"
                  "3 0 3 G4; 3 3 1 Bb4;"
                  "4 0 1.5 C5; 4 1.5 0.5 E5; 4 2 2 G5;"
                  "5 0 1 F5; 5 1 1 E5; 5 2 2 C5;"
                  "6 0 1 D5; 6 1 1 Bb4; 6 2 1 A4; 6 3 1 F4;"
                  "7 0 3 G4; 7 3 1 A4")
    keys, bass, lead, kit, pad = s.stem(), s.stem(), s.stem(), s.stem(), s.stem()
    for bar in range(BARS):
        root, fifth, voicing = bars[bar % 8]
        section = bar // 8
        notes = chord(voicing)
        for i, f in enumerate(notes):
            s.put(keys, epiano(2.2, f, 0.55), bar, 0.0 + 0.03 * i, pan=-0.25 + 0.15 * i, loose=0.006)
            s.put(keys, epiano(1.0, f, 0.35), bar, 2.5, pan=-0.25 + 0.15 * i, loose=0.006)
        s.put(bass, upright(1.6, note(root), 0.9), bar, 0.0)
        s.put(bass, upright(1.2, note(fifth), 0.7), bar, 2.0)
        for beat in range(4):
            s.put(kit, noise_hit(bar * 8 + beat, 0.4, 2500, 8000, 0.04, 0.1), bar, beat, pan=0.2, gain=0.4)
            if beat in (1, 3):
                s.put(kit, noise_hit(bar * 8 + beat + 4, 0.2, 1200, 4500, 0.003, 0.05), bar, beat, pan=-0.1,
                      gain=0.5 if section > 0 else 0.3)
        s.put(pad, strings(4 * s.beat, [f / 2 for f in notes[:3]], 600 + bar), bar, 0.0, loose=0)
        if section in (1, 2, 3):
            for b, beat, length, f in tune:
                if b == bar % 8:
                    if section == 2:
                        s.put(lead, vibraphone(length * s.beat, f), bar, beat, pan=0.1)
                    else:
                        s.put(lead, music_box(f * 2) * 0.85, bar, beat, pan=0.2)
        if bar % 4 == 3:  # music box sparkles drifting down at the end of each four bars
            for k, f in enumerate(sorted(notes, reverse=True)[:3]):
                s.put(lead, music_box(f * 4) * 0.25, bar, 2.0 + 0.5 * k, pan=0.35 - 0.1 * k)
    return blend({"lead": (lead, -21, 0.35), "keys": (keys, -23, 0.3), "bass": (bass, -27, 0.05),
                  "kit": (kit, -36, 0.15), "pad": (pad, -30, 0.4)}, 601, tmp)


def tutorial(tmp: Path) -> np.ndarray:
    """Step by Step: the tutorial's own loop (2026-11-05), calm and clear so the helper sounds stand out. 16 bars in C
    at 96 BPM: soft plucked chords and a bass, a rim tick, and a simple marimba tune (a glockenspiel joins it in the second half)."""
    s = Song(96, 4, seed=51, bars=16)
    bars = [
        ("C2", "G2", "E4 G4 C5"), ("A1", "E2", "E4 A4 C5"), ("F1", "C2", "F4 A4 C5"), ("G1", "D2", "D4 G4 B4"),
    ]
    tune = melody("0 0 1 E5; 0 1 1 G5; 0 2 2 C6;"
                  "1 0 1 B5; 1 1 1 A5; 1 2 2 E5;"
                  "2 0 1 F5; 2 1 1 A5; 2 2 2 C6;"
                  "3 0 1 B5; 3 1 1 G5; 3 2 2 D5")
    pluck_s, bass, lead, kit = s.stem(), s.stem(), s.stem(), s.stem()
    for bar in range(16):
        root, fifth, voicing = bars[bar % 4]
        notes = chord(voicing)
        for k, i in enumerate((0, 1, 2, 1)):  # an easy rocking arpeggio on the quarter beats
            s.put(pluck_s, pluck(0.5, notes[i], bar * 8 + k, bright=0.35, ring=1.2) * (0.8 if k == 0 else 0.55),
                  bar, k, pan=-0.2 + 0.1 * i)
        s.put(bass, pluck(0.7, note(root), bar * 3, bright=0.25, ring=1.1), bar, 0.0, pan=-0.05)
        s.put(bass, pluck(0.5, note(fifth), bar * 3 + 1, bright=0.25, ring=1.0) * 0.7, bar, 2.0, pan=-0.05)
        for beat in (1, 3):
            s.put(kit, rim(bar * 4 + beat), bar, beat, pan=-0.3, gain=0.3 if bar < 8 else 0.4)
        for b, beat, length, f in tune:  # the tune runs throughout, a glockenspiel joining it in the second half
            if b == bar % 4:
                s.put(lead, marimba(f, 0.8), bar, beat, pan=0.12)
                if bar >= 8:
                    s.put(lead, glock(f * 2) * 0.2, bar, beat, pan=0.3)
    return blend({"lead": (lead, -20, 0.25), "pluck": (pluck_s, -22, 0.25), "bass": (bass, -26, 0.05),
                  "kit": (kit, -36, 0.1)}, 501, tmp)


# --- the Jukebox Pass songs (#1168 row 2, 2026-11-06) ----------------------------------------------------------
# Four extra cafe songs a pass owner can pick in place of the day and night rotation. Each is 16 bars (a four bar
# round, four times: bare, the tune, a second voice, the tune again) and loops on its own. They share one upload,
# the Jukebox sheet (the month's audio uploads are limited), see JUKEBOX below.


def rain(s: Song, stem: np.ndarray, bars: int, gain: float, seed: int) -> None:
    """Soft rain: a bed of tiny high ticks, random in time and weight, placed with the song's own wrap-around."""
    rng = np.random.default_rng(seed)
    for bar in range(bars):
        for k in range(16):
            if rng.random() < 0.7:
                s.put(stem, noise_hit(seed + bar * 16 + k, 0.05, 3500, 10000, 0.001, 0.012), bar, k * s.meter / 16,
                      pan=float(rng.uniform(-0.8, 0.8)), gain=gain * float(rng.uniform(0.3, 1.0)), loose=0)


def jukebox_rainy_window(tmp: Path) -> np.ndarray:
    """Rainy Window: A minor, 64 BPM. Electric piano and a slow bass under soft rain; a music box tune; a
    vibraphone answers an octave up; the music box again."""
    s = Song(64, 4, seed=71, bars=16)
    bars = [("A1", "E2", "E4 G4 B4 C5"), ("F1", "C2", "A3 C4 E4 G4"), ("C2", "G2", "E4 G4 B4 D5"),
            ("G1", "D2", "B3 D4 E4 G4")]
    tune = melody("0 0 2 E5; 0 2 1 D5; 0 3 1 C5; 1 0 3 A4; 1 3 1 C5; 2 0 2 E5; 2 2 1 G5; 2 3 1 E5; 3 0 4 D5")
    keys, bass, lead, pad, drops = s.stem(), s.stem(), s.stem(), s.stem(), s.stem()
    for bar in range(16):
        root, fifth, voicing = bars[bar % 4]
        section = bar // 4
        notes = chord(voicing)
        for i, f in enumerate(notes):
            s.put(keys, epiano(2.6, f, 0.5), bar, 0.04 * i, pan=-0.3 + 0.2 * i, loose=0.006)
        s.put(keys, epiano(1.2, notes[2], 0.3), bar, 2.5, pan=0.1, loose=0.006)
        s.put(bass, upright(2.0, note(root), 0.8), bar, 0.0)
        s.put(bass, upright(1.2, note(fifth), 0.6), bar, 2.0)
        s.put(pad, strings(4 * s.beat, [f / 2 for f in notes[:3]], 700 + bar), bar, 0.0, loose=0)
        if section in (1, 3):
            for b, beat, length, f in tune:
                if b == bar % 4:
                    s.put(lead, music_box(f * 2) * 0.9, bar, beat, pan=0.2)
        if section == 2:
            for b, beat, length, f in tune:
                if b == bar % 4:
                    s.put(lead, vibraphone(length * s.beat, f * 2), bar, beat, pan=-0.1)
    rain(s, drops, 16, 0.5, 7100)
    return blend({"lead": (lead, -21, 0.35), "keys": (keys, -23, 0.3), "bass": (bass, -27, 0.05),
                  "pad": (pad, -30, 0.4), "drops": (drops, -36, 0.5)}, 701, tmp)


def jukebox_catnap_waltz(tmp: Path) -> np.ndarray:
    """Catnap Waltz: D major, 84 BPM in 3/4. A harp rocks the chord, strings hold it, a celesta sings the tune
    and a flute takes it over for the third round."""
    s = Song(84, 3, seed=72, bars=16)
    bars = [("D2", "A2", "F#4 A4 D5"), ("B1", "F#2", "F#4 B4 D5"), ("G1", "D2", "G4 B4 D5"),
            ("A1", "E2", "E4 A4 C#5")]
    tune = melody("0 0 1.5 A5; 0 1.5 0.5 F#5; 0 2 1 D5; 1 0 2 D5; 1 2 1 F#5; 2 0 1.5 G5; 2 1.5 0.5 F#5; 2 2 1 E5;"
                  "3 0 2 E5; 3 2 1 C#5")
    harp, bass, lead, pad = s.stem(), s.stem(), s.stem(), s.stem()
    for bar in range(16):
        root, fifth, voicing = bars[bar % 4]
        section = bar // 4
        notes = chord(voicing)
        s.put(bass, upright(1.6, note(root), 0.8), bar, 0.0)
        for beat in (1, 2):  # the waltz: bass on one, the chord on two and three
            for i, f in enumerate(notes):
                s.put(harp, pluck(0.9, f, bar * 12 + beat * 3 + i, bright=0.3, ring=1.6), bar, beat + 0.04 * i,
                      pan=-0.3 + 0.3 * i, gain=0.6)
        s.put(pad, strings(3 * s.beat, [f / 2 for f in notes], 720 + bar), bar, 0.0, loose=0)
        for b, beat, length, f in tune:
            if b == bar % 4:
                if section in (1, 3):
                    s.put(lead, music_box(f * 2) * 0.85, bar, beat, pan=0.15)
                elif section == 2:
                    s.put(lead, flute(length * s.beat, f, bar * 5 + int(beat * 2)), bar, beat, pan=0.1)
    return blend({"lead": (lead, -21, 0.35), "harp": (harp, -24, 0.3), "bass": (bass, -27, 0.05),
                  "pad": (pad, -30, 0.4)}, 702, tmp)


def jukebox_bakery_bounce(tmp: Path) -> np.ndarray:
    """Bakery Bounce: G major, 108 BPM, lightly swung. Piano stabs, a walking bass and brushes; a marimba tune
    hops over the top, a guitar joins for the third round."""
    s = Song(108, 4, seed=73, swing=0.07, bars=16)
    bars = [("G2", "D3", "B2", "B3 D4 G4"), ("E2", "B2", "F#2", "B3 E4 G4"), ("C3", "G2", "A2", "C4 E4 G4"),
            ("D3", "A2", "F#2", "A3 D4 F#4")]
    tune = melody("0 0 0.5 G5; 0 0.5 0.5 B5; 0 1 1 D6; 0 2 1 B5; 0 3 1 G5; 1 0 1 E5; 1 1 0.5 G5; 1 1.5 0.5 B5;"
                  "1 2 2 G5; 2 0 0.5 E5; 2 0.5 0.5 G5; 2 1 1 C6; 2 2 1 B5; 2 3 1 G5; 3 0 1 F#5; 3 1 1 A5; 3 2 2 D5")
    keys, bass, lead, guitar, kit = s.stem(), s.stem(), s.stem(), s.stem(), s.stem()
    for bar in range(16):
        root, fifth, lead_in, voicing = bars[bar % 4]
        section = bar // 4
        notes = chord(voicing)
        for beat in (0.0, 1.5, 2.5):  # short stabs on the off beats
            for i, f in enumerate(notes):
                s.put(keys, epiano(0.5, f, 0.6), bar, beat, pan=-0.3 + 0.2 * i, loose=0.004)
        s.put(bass, upright(0.8, note(root), 1.0), bar, 0.0)
        s.put(bass, upright(0.6, note(fifth), 0.7), bar, 1.0)
        s.put(bass, upright(0.8, note(root), 0.9), bar, 2.0)
        s.put(bass, upright(0.4, note(lead_in), 0.6), bar, 3.0)
        for beat in range(4):
            s.put(kit, noise_hit(bar * 8 + beat, 0.3, 2500, 9000, 0.02, 0.07), bar, beat, pan=0.2, gain=0.5)
            if beat in (1, 3):
                s.put(kit, rim(bar * 4 + beat), bar, beat, pan=-0.2, gain=0.5)
        if section > 0:
            s.put(kit, kick(), bar, 0.0, gain=0.7)
            s.put(kit, kick(), bar, 2.0, gain=0.5)
        if section in (1, 3):
            for b, beat, length, f in tune:
                if b == bar % 4:
                    s.put(lead, marimba(f, 0.8), bar, beat, pan=0.12)
        if section == 2:
            for k, i in enumerate((0, 1, 2, 1, 0, 1, 2, 1)):
                s.put(guitar, pluck(0.5, notes[i] * 2, bar * 8 + k, bright=0.4, ring=1.4), bar, k * 0.5,
                      pan=0.4 - 0.1 * (k % 2))
        if bar % 4 == 3:
            for k, name in enumerate(("D6", "G6")):
                s.put(lead, glock(note(name)) * 0.3, bar, 3.0 + 0.5 * k, pan=0.3)
    return blend({"lead": (lead, -20, 0.25), "keys": (keys, -24, 0.25), "bass": (bass, -25, 0.05),
                  "guitar": (guitar, -23, 0.25), "kit": (kit, -33, 0.15)}, 703, tmp)


def jukebox_starlight_purr(tmp: Path) -> np.ndarray:
    """Starlight Purr: F major, 66 BPM. Wide strings, a vibraphone arpeggio, glockenspiel stars and, very low
    down, a cat's purr; a flute sings the tune in the third round."""
    s = Song(66, 4, seed=74, bars=16)
    bars = [("F1", "C2", "A3 C4 E4", "C5 E5 A5 E5"), ("D2", "A2", "C4 F4 A4", "A4 C5 F5 C5"),
            ("Bb1", "F2", "D4 F4 A4", "F4 A4 D5 A4"), ("C2", "G2", "D4 E4 G4", "G4 C5 E5 C5")]
    tune = melody("0 0 3 C5; 0 3 1 D5; 1 0 2 A4; 1 2 2 C5; 2 0 3 D5; 2 3 1 F5; 3 0 4 E5")
    vib, bass, lead, pad, stars, purr = s.stem(), s.stem(), s.stem(), s.stem(), s.stem(), s.stem()
    rng = np.random.default_rng(7400)
    scale = ("C6", "D6", "E6", "F6", "G6", "A6")
    for bar in range(16):
        root, fifth, voicing, arp = bars[bar % 4]
        section = bar // 4
        notes = chord(voicing)
        s.put(pad, strings(4 * s.beat, [f / 2 for f in notes] + [f for f in notes[:1]], 740 + bar), bar, 0.0,
              loose=0)
        s.put(bass, upright(3.0, note(root), 0.7), bar, 0.0)
        for k, name in enumerate(arp.split()):
            s.put(vib, vibraphone(0.9 * s.beat, note(name)), bar, k * 1.0, pan=-0.2 + 0.15 * k, gain=0.7)
        if section in (1, 3):
            for b, beat, length, f in tune:
                if b == bar % 4:
                    s.put(lead, music_box(f * 2) * 0.85, bar, beat, pan=0.2)
        if section == 2:
            for b, beat, length, f in tune:
                if b == bar % 4:
                    s.put(lead, flute(length * s.beat, f, bar * 5 + int(beat * 2)), bar, beat, pan=0.1)
        for k in range(2):  # a star or two twinkles each bar
            if rng.random() < 0.7:
                s.put(stars, glock(note(scale[int(rng.integers(len(scale)))])) * 0.25, bar,
                      float(rng.choice([1.5, 2.5, 3.5])) + 0.5 * k * 0, pan=float(rng.uniform(-0.6, 0.6)))
    length = s.n / SR
    cycles = round(25 * length)  # a whole number of purr cycles, so the loop has no seam
    t = np.arange(s.n) / SR
    rumble = lowpass(np.random.default_rng(7401).standard_normal(s.n), 160)
    purr_wave = rumble * (0.55 + 0.45 * np.sin(2 * np.pi * cycles / length * t))
    purr[:, 0] = purr_wave
    purr[:, 1] = purr_wave
    return blend({"lead": (lead, -21, 0.4), "vib": (vib, -23, 0.4), "bass": (bass, -27, 0.05),
                  "pad": (pad, -28, 0.45), "stars": (stars, -32, 0.5), "purr": (purr, -34, 0.0)}, 704, tmp)


SONGS = {"DayA": day_a, "DayB": day_b, "NightA": night_a, "DayC": day_c, "DayD": day_d, "NightB": night_b,
         "Tutorial": tutorial, "JukeboxRainyWindow": jukebox_rainy_window,
         "JukeboxCatnapWaltz": jukebox_catnap_waltz, "JukeboxBakeryBounce": jukebox_bakery_bounce,
         "JukeboxStarlightPurr": jukebox_starlight_purr}

# The music sheet (#980, 2026-11-03). Audio uploads were used up (100 a month until an account is ID verified), so the
# three songs Derek approved on 2026-11-03 share one upload: each renders on its own to sheet-parts/music/ (gated
# there, never uploaded alone), and sheets/CatCafe_Sheet_Music.ogg is the three in this order with SHEET_GAP seconds
# of silence between. Each song's cue plays its own region of it (`sheet` and `region` in Cues.luau; this script
# prints the regions whenever a song changes). Roblox's limits for one audio file: under 20 MB and 7 minutes.
SHEET = ("DayC", "DayD", "NightB")
# The Jukebox Pass songs (#1168 row 2) share one upload the same way: sheets/CatCafe_Sheet_MusicJukebox.ogg (named Music* so the audio gate treats it as a music sheet).
JUKEBOX = ("JukeboxRainyWindow", "JukeboxCatnapWaltz", "JukeboxBakeryBounce", "JukeboxStarlightPurr")
SHEET_GAP = 0.5


def write_sheet(rendered: dict[str, np.ndarray], tmp: Path, names: tuple[str, ...] = SHEET,
                sheet_name: str = "Music", cue: str = "sheetMusic") -> None:
    """Joins the sheet's songs (building any not rendered in this run) and prints each one's region."""
    gap = np.zeros((int(SHEET_GAP * SR), 2))
    pieces: list[np.ndarray] = []
    at = 0
    print("music: regions for Cues.luau:")
    for name in names:
        x = rendered[name] if name in rendered else SONGS[name](tmp)
        print(f"    music{name} = {{ sheet = \"{cue}\", region = {{ {at / SR:.3f}, {(at + len(x)) / SR:.3f} }}, "
              f"seconds = {len(x) / SR:.3f} }}")
        pieces += [x, gap]
        at += len(x) + len(gap)
    wav = tmp / f"Sheet_{sheet_name}.wav"
    write_wav(wav, np.concatenate(pieces[:-1]))
    out = ROOT / "sheets" / f"CatCafe_Sheet_{sheet_name}.ogg"
    encode(wav, out, ["-c:a", "libvorbis", "-q:a", "5"])
    size = out.stat().st_size / 1e6
    print(f"music: {out.relative_to(ROOT.parents[2]).as_posix()}  {at / SR - SHEET_GAP:.1f} s, {size:.1f} MB")


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
            folder = "sheet-parts/music" if name in SHEET or name in JUKEBOX else "music"
            out = ROOT / folder / f"CatCafe_Music_{name}.ogg"
            encode(wav, out, ["-c:a", "libvorbis", "-q:a", "5"])
            print(f"music: {out.relative_to(ROOT.parents[2]).as_posix()}  {len(x) / SR:.1f} s")
        if any(name in rendered for name in SHEET):
            write_sheet(rendered, tmp)
        if any(name in rendered for name in JUKEBOX):
            write_sheet(rendered, tmp, JUKEBOX, "MusicJukebox", "sheetMusicJukebox")
        if args.preview:
            folder = Path(args.preview)
            folder.mkdir(parents=True, exist_ok=True)
            print(f"music: preview {preview(rendered, folder, tmp).as_posix()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
