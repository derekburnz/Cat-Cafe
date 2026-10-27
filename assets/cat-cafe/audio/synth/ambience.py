"""Synthesize Purr Pot's ambience beds: the cafes, the Alleyway and the Park, by day and night.

Run from the repo root:  python assets/cat-cafe/audio/synth/ambience.py [--only CafeDay,AlleyNight]
                                                                       [--preview DIR]

Every bed is built from seeded noise, sine partials and pulse trains (no samples), so the files
are original and the same on every run. Everything is made over exactly one loop: filters work in
the frequency domain over the whole loop, every event (a cup clink, a drip, a chirp, a voice)
wraps around the loop end, and every steady tone fits a whole number of cycles. So the end flows
into the start with no seam. Outputs (overwritten):
  assets/cat-cafe/audio/ambience/CatCafe_Amb_<Name>.ogg  (stereo, 48 kHz, about -26 LUFS)
  with --preview: DIR/purr-pot-ambience-preview.mp3, 20 s of each bed with crossfades.

The cafe chatter is a crowd of made-up talkers: pulse-train voices shaped by vowel formants into
syllables, at a distance, so no word is ever heard. Needs numpy and ffmpeg. Check the files with
.claude/skills/audio-pipeline/scripts/audio_gate.py. Cue rows: docs/audio/cat-cafe/sound-list.md 4.
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

from synth import SR, bell, envelope, glide  # same folder

ROOT = Path(__file__).resolve().parents[1]  # assets/cat-cafe/audio
LOOP = 48.0  # seconds; whole seconds so the wall clock ticks and the hums fit the loop exactly
N = int(LOOP * SR)
TARGET_LUFS = -26.0
CEILING_DB = -4.0  # sample peak; the gate's limit is -3 dBTP


# --- building blocks (all circular over one loop) ---------------------------------------------


def rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


def shape(x: np.ndarray, gain) -> np.ndarray:
    """Filter a signal through a gain curve, gain(freqs) -> array, in the frequency domain."""
    spectrum = np.fft.rfft(x)
    return np.fft.irfft(spectrum * gain(np.fft.rfftfreq(len(x), 1 / SR)), len(x))


def band(lo: float | None = None, hi: float | None = None, order: int = 2):
    def gain(f: np.ndarray) -> np.ndarray:
        out = np.ones_like(f)
        if lo:
            out = out / np.sqrt(1 + (lo / np.maximum(f, 1e-3)) ** (2 * order))
        if hi:
            out = out / np.sqrt(1 + (f / hi) ** (2 * order))
        return out

    return gain


def unit(x: np.ndarray) -> np.ndarray:
    return x / (np.sqrt(np.mean(x**2)) + 1e-12)


def pink(seed: int, lo: float | None = None, hi: float | None = None, n: int = N) -> np.ndarray:
    x = rng(seed).standard_normal(n)
    tilt = band(lo, hi)
    return unit(shape(x, lambda f: tilt(f) / np.sqrt(np.maximum(f, 20.0))))


def lfo(seed: int, cycles=(1, 2, 3, 5)) -> np.ndarray:
    """Slow wobble in [-1, 1] made of whole cycles per loop, so it is periodic too."""
    r = rng(seed)
    t = np.arange(N) / SR
    out = sum(r.uniform(0.4, 1.0) * np.sin(2 * np.pi * k * t / LOOP + r.uniform(0, 2 * np.pi)) for k in cycles)
    return out / np.max(np.abs(out))


def put(track: np.ndarray, signal: np.ndarray, start: float) -> None:
    """Add a signal at `start` seconds, wrapping past the loop end. Mono or stereo."""
    index = (np.arange(len(signal)) + int(start * SR)) % len(track)
    track[index] += signal


def pan(x: np.ndarray, position: float) -> np.ndarray:
    """Constant-power pan, -1 left to 1 right."""
    angle = (position + 1) * np.pi / 4
    return np.stack([x * np.cos(angle), x * np.sin(angle)], axis=1)


def stereo() -> np.ndarray:
    return np.zeros((N, 2))


def reverb(x: np.ndarray, seconds: float, seed: int, hi: float = 5000.0, predelay: float = 0.012) -> np.ndarray:
    """Circular convolution with a decaying-noise room, a different one per ear."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    out = np.empty_like(x)
    for channel in (0, 1):
        ir = rng(seed + channel).standard_normal(n) * np.exp(-6.9 * t / seconds)
        ir = shape(ir, band(hi=hi))
        ir[: int(predelay * SR)] = 0
        full = np.zeros(N)
        full[:n] = ir / np.sqrt(np.sum(ir**2))
        out[:, channel] = np.fft.irfft(np.fft.rfft(x[:, channel]) * np.fft.rfft(full), N)
    return out


def room(x: np.ndarray, seconds: float, seed: int, wet: float, hi: float = 5000.0) -> np.ndarray:
    return (1 - wet) * x + wet * reverb(x, seconds, seed, hi)


def events(seed: int, mean_gap: float, jitter: float = 0.6, start: float = 0.0):
    """Start times over one loop with gaps around `mean_gap` seconds."""
    r = rng(seed)
    at = start + r.uniform(0, mean_gap)
    while at < start + LOOP - 0.05:
        yield at, r
        at += mean_gap * r.uniform(1 - jitter, 1 + jitter)


def burst(seed: int, duration: float, lo: float, hi: float, tau: float, attack: float = 0.001) -> np.ndarray:
    x = rng(seed).standard_normal(int(duration * SR))
    return unit(shape(x, band(lo, hi))) * envelope(duration, attack, tau)


# --- voices: a murmuring crowd, never words ----------------------------------------------------

# Vowel formants (F1, F2, F3) for a, e, i, o, u and two in-betweens.
VOWELS = ((730, 1090, 2440), (530, 1840, 2480), (300, 2200, 2950), (570, 840, 2410),
          (330, 900, 2300), (660, 1700, 2400), (500, 1350, 1700))


def formants(vowel, f0: float):
    scale = 1.18 if f0 > 170 else 1.0  # higher voices have higher formants

    def gain(f: np.ndarray) -> np.ndarray:
        out = np.full_like(f, 0.02)
        for k, (centre, amp) in enumerate(zip(vowel, (1.0, 0.6, 0.3))):
            width = 70 + 40 * k
            out += amp / (1 + ((f - centre * scale) / width) ** 2)
        return out * band(hi=3200)(f)

    return gain


def talker(seed: int, f0: float, chatty: float = 1.0, laughs: int = 0) -> np.ndarray:
    """One person talking on and off for the whole loop, as mono syllables."""
    r = rng(seed)
    contour = f0 * 2 ** (lfo(seed + 1, cycles=(4, 9, 13, 21)) * 2.5 / 12)  # intonation, in semitones
    cycles = np.sum(contour) / SR
    contour *= round(cycles) / cycles  # a whole number of glottal cycles per loop: no seam
    phase = np.cumsum(contour) / SR
    source = shape(2 * (phase % 1.0) - 1, band(60, 4000))  # a buzzy voice source

    track = np.zeros(N)
    start = r.uniform(0, LOOP)
    at = start
    while at < start + LOOP - 1.0:
        phrase_end = min(at + r.uniform(1.0, 3.5) * chatty, start + LOOP - 0.6)
        while at < phrase_end:
            length = r.uniform(0.11, 0.26)
            syllable(track, source, at, length, VOWELS[r.integers(len(VOWELS))], f0, r.uniform(0.5, 1.0))
            at += length + r.uniform(0.01, 0.07)
        at += r.uniform(0.7, 3.2) / chatty
    for _ in range(laughs):  # a short "ha-ha-ha", a little higher and falling
        at = r.uniform(0, LOOP)
        for k in range(r.integers(4, 7)):
            syllable(track, source * 1.0, at + k * 0.13, 0.09, VOWELS[0], f0 * 1.3, 0.9 - 0.1 * k, bend=0.97**k)
    return track


def syllable(track, source, at, length, vowel, f0, amp, bend: float = 1.0) -> None:
    n = int((length + 0.08) * SR)
    index = (np.arange(n) + int(at * SR)) % N
    x = source[index]
    if bend != 1.0:  # laugh syllables step down in pitch
        x = np.interp(np.arange(n) * bend, np.arange(n), x)
    k = np.arange(n) / SR
    env = np.where(k < length, np.sin(np.pi * np.clip(k / length, 0, 1)) ** 0.7, 0.0)
    padded = np.zeros(n + int(0.05 * SR))
    padded[:n] = x * env * amp
    track[(np.arange(len(padded)) + int(at * SR)) % N] += shape(padded, formants(vowel, f0))


def crowd(seed: int, people: int, chatty: float, laughs: int) -> np.ndarray:
    r = rng(seed)
    mix = stereo()
    for i in range(people):
        f0 = r.choice((r.uniform(100, 140), r.uniform(185, 235)))
        voice = unit(talker(seed + 10 * i, f0, chatty, laughs if i % 3 == 0 else 0))
        mix += pan(voice * r.uniform(0.5, 1.0), r.uniform(-0.8, 0.8))
    mix = room(mix, 0.9, seed + 99, wet=0.75, hi=3500)
    return shape_stereo(mix, band(120, 2600))


def shape_stereo(x: np.ndarray, gain) -> np.ndarray:
    return np.stack([shape(x[:, 0], gain), shape(x[:, 1], gain)], axis=1)


# --- cafe sounds -------------------------------------------------------------------------------


def clink(seed: int) -> np.ndarray:
    """A cup or saucer touched: porcelain partials over a tiny knock."""
    r = rng(seed)
    f0 = r.uniform(2300, 3500)
    partials = ((1.0, 1.0, r.uniform(0.07, 0.16)), (2.32, 0.5, 0.05), (4.25, 0.25, 0.03), (6.63, 0.12, 0.018))
    knock = burst(seed + 1, 0.03, 500, 1600, 0.006) * 0.2
    x = bell(0.35, f0, partials)
    x[: len(knock)] += knock
    return x


def spoon(seed: int) -> np.ndarray:
    r = rng(seed)
    out = np.zeros(int(0.9 * SR))
    for k in range(r.integers(4, 7)):
        tink = bell(0.12, r.uniform(4200, 5200), ((1.0, 1.0, 0.03), (2.4, 0.3, 0.01)))
        put(out, tink * r.uniform(0.3, 0.5), k * r.uniform(0.11, 0.15))
    return out


def steam(seed: int, duration: float = 3.0) -> np.ndarray:
    """The milk steamer: a hiss that rises and settles, with a little gurgle."""
    t = np.arange(int(duration * SR)) / SR
    env = np.clip(t / 0.4, 0, 1) * np.clip((duration - t) / 0.8, 0, 1)
    hiss = unit(shape(rng(seed).standard_normal(len(t)), band(2000, 7000))) * env
    gurgle = unit(shape(rng(seed + 1).standard_normal(len(t)), band(150, 600))) * env
    gurgle *= 0.5 + 0.5 * np.sin(2 * np.pi * 7 * t)
    return hiss * 0.5 + gurgle * 0.25


def grinder(seed: int, duration: float = 2.2) -> np.ndarray:
    t = np.arange(int(duration * SR)) / SR
    env = np.clip(t / 0.15, 0, 1) * np.clip((duration - t) / 0.25, 0, 1)
    whirr = unit(shape(rng(seed).standard_normal(len(t)), band(300, 2500))) * (1 + 0.5 * np.sin(2 * np.pi * 47 * t))
    return whirr * env * 0.35


def scrape(seed: int) -> np.ndarray:
    d = 0.45
    t = np.arange(int(d * SR)) / SR
    grain = unit(shape(rng(seed).standard_normal(len(t)), band(250, 1200)))
    return grain * np.sin(np.pi * t / d) ** 2 * (1 + 0.6 * np.sin(2 * np.pi * 31 * t)) * 0.3


def cafe(seed: int, people: int, chatty: float, laughs: int, clinks: float, busy: bool) -> np.ndarray:
    mix = crowd(seed, people, chatty, laughs) * 0.9
    mix += pan(pink(seed + 1, 30, 250), 0) * 0.05  # room tone
    things = stereo()
    for at, r in events(seed + 2, clinks):
        roll = r.uniform()
        sound = spoon(r.integers(1 << 30)) if roll < 0.15 else clink(r.integers(1 << 30))
        put(things, pan(sound * r.uniform(0.35, 0.8), r.uniform(-0.9, 0.9)), at)
        if 0.15 <= roll < 0.4:  # the cup goes back on its saucer
            put(things, pan(clink(r.integers(1 << 30)) * 0.4, r.uniform(-0.9, 0.9)), at + r.uniform(0.06, 0.14))
    r = rng(seed + 3)
    if busy:
        put(things, pan(steam(seed + 4), -0.5) * 0.12, r.uniform(0, LOOP))
        put(things, pan(grinder(seed + 5), 0.6) * 0.15, r.uniform(0, LOOP))
    for _ in range(2 if busy else 1):
        put(things, pan(scrape(r.integers(1 << 30)), r.uniform(-0.8, 0.8)), r.uniform(0, LOOP))
    mix += room(things, 0.7, seed + 6, wet=0.35, hi=7000)
    return mix


def cafe_day() -> np.ndarray:
    return cafe(100, people=9, chatty=1.0, laughs=2, clinks=1.6, busy=True)


def wall_clock(seed: int) -> np.ndarray:
    track = np.zeros(N)
    for second in range(int(LOOP)):
        lo, hi = (1800, 3200) if second % 2 == 0 else (1300, 2400)
        put(track, burst(seed + second % 2, 0.02, lo, hi, 0.003), float(second))
    return track


def cafe_night() -> np.ndarray:
    mix = cafe(200, people=3, chatty=0.6, laughs=1, clinks=5.0, busy=False) * 0.8
    mix += pan(wall_clock(210), 0.4) * 0.05
    t = np.arange(N) / SR
    fridge = sum(a * np.sin(2 * np.pi * f * t) for f, a in ((100, 1.0), (200, 0.4), (300, 0.15)))  # whole cycles
    mix += pan(fridge * (0.8 + 0.2 * lfo(211)), -0.3) * 0.006
    return mix


# --- outdoors ----------------------------------------------------------------------------------


def wind(seed: int, strength: float) -> np.ndarray:
    low = pink(seed, 150, 900) * (0.6 + 0.4 * lfo(seed + 1, (1, 2, 3, 4)))
    high = pink(seed + 2, 700, 2600) * np.clip(lfo(seed + 3, (2, 3, 5, 7)), 0, 1) ** 2
    return np.stack([low * 0.9 + high * 0.3, low * 0.8 + high * 0.4], axis=1) * strength


def rumble(seed: int, level: float) -> np.ndarray:
    """A far city: low traffic hum, slowly breathing."""
    left = pink(seed, 25, 160) * (0.8 + 0.2 * lfo(seed + 1))
    right = pink(seed + 2, 25, 160) * (0.8 + 0.2 * lfo(seed + 3))
    return np.stack([left, right], axis=1) * level


def car(seed: int, duration: float = 7.0) -> np.ndarray:
    """A car passing the end of the street, panning across."""
    t = np.arange(int(duration * SR)) / SR
    swell = np.exp(-(((t - duration / 2) / (duration / 5)) ** 2))
    body = unit(shape(rng(seed).standard_normal(len(t)), band(60, 700))) * swell
    side = np.clip((t - duration / 2) / (duration / 2), -1, 1) * (1 if seed % 2 else -1) * 0.8
    angle = (side + 1) * np.pi / 4
    return np.stack([body * np.cos(angle), body * np.sin(angle)], axis=1)


def drip(seed: int) -> np.ndarray:
    r = rng(seed)
    f = r.uniform(1100, 1900)
    d = 0.14
    plink = glide(d, f, f * 1.7, 0.025) * envelope(d, 0.0008, 0.022)
    plop = glide(d, 300, 180, 0.02) * envelope(d, 0.001, 0.01) * 0.3
    return plink + plop


def chirp_train(seed: int, freq: float, pulses: int, gap: float, pulse: float) -> np.ndarray:
    n = int(pulse * SR)
    one = np.sin(2 * np.pi * freq * np.arange(n) / SR) * np.hanning(n)
    out = np.zeros(int((pulses * gap + pulse) * SR))
    r = rng(seed)
    for k in range(pulses):
        put(out, one * r.uniform(0.7, 1.0), k * gap)
    return out


def crickets(seed: int, freq: float, position: float) -> np.ndarray:
    """A cricket that chirps in stretches and rests between them."""
    track = np.zeros(N)
    r = rng(seed)
    at = r.uniform(0, 3)
    while at < LOOP - 0.5:
        stretch = r.uniform(5, 14)
        end = min(at + stretch, LOOP - 0.5)
        while at < end:
            put(track, chirp_train(r.integers(1 << 30), freq * r.uniform(0.995, 1.005), 3, 0.034, 0.016), at)
            at += r.uniform(0.5, 0.62)
        at += r.uniform(1.5, 5)
    return pan(track, position)


def coo(seed: int) -> np.ndarray:
    """A pigeon: three soft hooting notes, throaty and round."""
    r = rng(seed)
    base = r.uniform(300, 380)
    out = np.zeros(int(1.3 * SR))
    for start, length, ratio in ((0.0, 0.22, 1.0), (0.3, 0.42, 1.12), (0.8, 0.28, 0.94)):
        n = int(length * SR)
        t = np.arange(n) / SR
        f = base * ratio * (1 + 0.04 * np.sin(np.pi * t / length))
        ph = 2 * np.pi * np.cumsum(f) / SR
        note = (np.sin(ph) + 0.25 * np.sin(2 * ph)) * (1 - 0.45 * (0.5 + 0.5 * np.sin(2 * np.pi * 19 * t)))
        put(out, note * np.sin(np.pi * t / length) ** 1.5, start)
    return out


def bird(seed: int) -> np.ndarray:
    """A small songbird phrase: quick sweeps and a short trill."""
    r = rng(seed)
    out = np.zeros(int(1.6 * SR))
    at = 0.0
    for _ in range(r.integers(2, 5)):
        d = r.uniform(0.04, 0.09)
        f0, f1 = r.uniform(2800, 4200), r.uniform(3500, 6500)
        if r.uniform() < 0.5:
            f0, f1 = f1, f0
        t = np.arange(int(d * SR)) / SR
        put(out, glide(d, f0, f1, d) * np.sin(np.pi * t / d), at)
        at += d + r.uniform(0.03, 0.09)
    if r.uniform() < 0.6:
        put(out, chirp_train(seed + 1, r.uniform(4000, 5200), int(r.integers(5, 10)), 0.045, 0.03), at)
    return out


def owl(seed: int) -> np.ndarray:
    r = rng(seed)
    out = np.zeros(int(2.2 * SR))
    for start, length in ((0.0, 0.5), (0.95, 0.25), (1.3, 0.55)):
        n = int(length * SR)
        t = np.arange(n) / SR
        f = r.uniform(370, 390) * (1 - 0.06 * t / length)
        ph = 2 * np.pi * np.cumsum(f) / SR
        put(out, (np.sin(ph) + 0.12 * np.sin(2 * ph)) * np.sin(np.pi * t / length) ** 2, start)
    return out


def scatter(seed: int, mean_gap: float, maker, level: float, spread: float = 0.9) -> np.ndarray:
    track = stereo()
    for at, r in events(seed, mean_gap):
        put(track, pan(maker(r.integers(1 << 30)) * level * r.uniform(0.6, 1.0), r.uniform(-spread, spread)), at)
    return track


def alley_day() -> np.ndarray:
    mix = rumble(300, 0.5) + wind(301, 0.12)
    cars = stereo()
    for at, r in events(302, 6.0):
        put(cars, car(r.integers(1 << 30)) * 0.35, at)
    mix += cars
    mix += room(scatter(303, 9.0, coo, 0.25, 0.7), 0.6, 304, wet=0.4)
    mix += room(scatter(305, 11.0, bird, 0.07), 0.5, 306, wet=0.3)
    return mix


def alley_night() -> np.ndarray:
    mix = rumble(400, 0.35) + wind(401, 0.16)
    cars = stereo()
    for at, r in events(402, 18.0, jitter=0.4):
        put(cars, car(r.integers(1 << 30)) * 0.2, at)
    mix += cars
    drips = stereo()
    for at, r in events(403, 1.8, jitter=0.15):  # a steady drip from a gutter
        put(drips, pan(drip(404) * r.uniform(0.8, 1.0), -0.45), at)
    for at, r in events(405, 4.5):  # and a slower, random one
        put(drips, pan(drip(r.integers(1 << 30)) * 0.6, 0.55), at)
    mix += room(drips * 0.22, 1.4, 406, wet=0.55, hi=6000)
    bugs = crickets(407, 4400, -0.6) + crickets(408, 4750, 0.7) * 0.8
    mix += room(bugs * 0.05, 0.8, 409, wet=0.5, hi=8000)
    return mix


def fountain(seed: int) -> np.ndarray:
    splash = pink(seed, 300, 6000)
    fizz = unit(shape(rng(seed + 1).standard_normal(N), band(4, 18)))
    water = splash * (1 + 0.35 * fizz)
    return pan(shape(water, band(hi=3500)), 0.3)


def leaves(seed: int, gusts: np.ndarray) -> np.ndarray:
    rustle = pink(seed, 2000, 9000) * np.clip(gusts, 0, 1) ** 2
    return np.stack([rustle, np.roll(rustle, int(0.3 * SR))], axis=1)


def park_day() -> np.ndarray:
    mix = wind(500, 0.1) + fountain(501) * 0.12
    mix += leaves(502, lfo(503, (2, 3, 5, 8))) * 0.05
    mix += room(scatter(504, 2.6, bird, 0.12), 0.5, 505, wet=0.3)
    mix += room(scatter(506, 14.0, coo, 0.15, 0.8), 0.5, 507, wet=0.4)
    return mix


def park_night() -> np.ndarray:
    mix = wind(600, 0.14) + fountain(601) * 0.06
    mix += leaves(602, lfo(603, (1, 2, 3, 5))) * 0.03
    bugs = crickets(604, 4300, -0.7) + crickets(605, 4650, 0.1) * 0.9 + crickets(606, 4900, 0.8) * 0.7
    mix += room(bugs * 0.06, 0.6, 607, wet=0.4, hi=8000)
    hoots = stereo()
    r = rng(608)
    for at in (r.uniform(4, 10), r.uniform(28, 36)):
        put(hoots, pan(owl(r.integers(1 << 30)) * 0.12, r.uniform(-0.8, 0.8)), at)
    mix += room(hoots, 1.6, 609, wet=0.7, hi=2500)
    return mix


BEDS = {
    "CafeDay": cafe_day,
    "CafeNight": cafe_night,
    "AlleyDay": alley_day,
    "AlleyNight": alley_night,
    "ParkDay": park_day,
    "ParkNight": park_night,
}


# --- level and output --------------------------------------------------------------------------


def write_wav(path: Path, x: np.ndarray) -> None:
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(x.shape[1] if x.ndim == 2 else 1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def lufs(path: Path) -> float:
    out = subprocess.run(["ffmpeg", "-nostats", "-i", str(path), "-af", "ebur128", "-f", "null", "-"],
                         capture_output=True, text=True, check=True).stderr
    return float(re.findall(r"I:\s+(-?[\d.]+) LUFS", out)[-1])


def level(x: np.ndarray, tmp: Path) -> np.ndarray:
    """Set the bed to TARGET_LUFS, then round off the few peaks above the ceiling."""
    x = x / np.max(np.abs(x)) * 0.5
    probe = tmp / "probe.wav"
    write_wav(probe, x)
    x = x * 10 ** ((TARGET_LUFS - lufs(probe)) / 20)
    ceiling = 10 ** (CEILING_DB / 20)
    knee = ceiling * 0.7
    over = np.abs(x) > knee
    x[over] = np.sign(x[over]) * (knee + (ceiling - knee) * np.tanh((np.abs(x[over]) - knee) / (ceiling - knee)))
    return x


def encode(wav: Path, out: Path, codec: list[str]) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-ar", str(SR), *codec,
                    "-fflags", "+bitexact", "-flags:a", "+bitexact", str(out)], check=True)


def preview(rendered: dict[str, np.ndarray], folder: Path, tmp: Path) -> Path:
    length, fade = int(20 * SR), int(2 * SR)
    track = np.zeros((0, 2))
    for x in rendered.values():
        part = x[:length].copy()
        if len(track):
            ramp = np.linspace(0, 1, fade)[:, None]
            track[-fade:] = track[-fade:] * (1 - ramp) + part[:fade] * ramp
            part = part[fade:]
        track = np.concatenate([track, part])
    wav = tmp / "preview.wav"
    write_wav(wav, track * 2.5)  # beds are mastered quiet; louder so they can be heard on a phone
    out = folder / "purr-pot-ambience-preview.mp3"
    encode(wav, out, ["-c:a", "libmp3lame", "-q:a", "2"])
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--only", help="comma list of names, e.g. CafeDay,AlleyNight")
    parser.add_argument("--preview", help="folder for a listening preview mp3")
    args = parser.parse_args()

    names = list(BEDS) if not args.only else [n.strip() for n in args.only.split(",")]
    unknown = [n for n in names if n not in BEDS]
    if unknown:
        print(f"ambience: unknown bed(s) {', '.join(unknown)}; known: {', '.join(BEDS)}", file=sys.stderr)
        return 2

    rendered: dict[str, np.ndarray] = {}
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        for name in names:
            x = level(BEDS[name](), tmp)
            rendered[name] = x
            wav = tmp / f"{name}.wav"
            write_wav(wav, x)
            out = ROOT / "ambience" / f"CatCafe_Amb_{name}.ogg"
            encode(wav, out, ["-c:a", "libvorbis", "-q:a", "5"])
            print(f"ambience: {out.relative_to(ROOT.parents[2]).as_posix()}  {LOOP:.0f} s")
        if args.preview:
            folder = Path(args.preview)
            folder.mkdir(parents=True, exist_ok=True)
            print(f"ambience: preview {preview(rendered, folder, tmp).as_posix()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
