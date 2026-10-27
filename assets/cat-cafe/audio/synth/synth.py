"""Synthesize Cat Cafe's own sound effects: UI, net circles, catch results, coins, the door bell, jingles.

Run from the repo root:  python assets/cat-cafe/audio/synth/synth.py [--only CirclePerfect,CoinPop]
                                                                  [--preview DIR]

Every sound is made from sine partials and filtered noise with fixed seeds, so the files are
original (no samples) and the same on every run. Outputs (overwritten):
  assets/cat-cafe/audio/ui/CatCafe_Ui_<Name>.ogg and sfx/CatCafe_Sfx_<Name>.ogg (mono, 48 kHz),
  music/CatCafe_Music_Jingle<Name>.ogg (the same sound on both channels; the music channel is stereo)
  with --preview: DIR/cat-cafe-sfx-preview.mp3, every sound in turn, then a five-circle Perfect
  run and a whole catch, for listening without Studio.

Needs numpy and ffmpeg (with libvorbis and libmp3lame). After a run, check the files with
.claude/skills/audio-pipeline/scripts/audio_gate.py. Cue rows: docs/audio/cat-cafe/sound-list.md.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

SR = 48000
ROOT = Path(__file__).resolve().parents[1]  # assets/cat-cafe/audio

# One bell sample serves all five circles: the Audio module plays circle i at this PlaybackSpeed,
# the major pentatonic from A5, so a run of Perfects is a little tune (sound-list section 5.1).
PENTATONIC = (1.0, 1.125, 1.25, 1.5, 5 / 3)


# --- building blocks --------------------------------------------------------------------------


def seconds(duration: float) -> np.ndarray:
    return np.arange(int(duration * SR)) / SR


def envelope(duration: float, attack: float, tau: float, start: float = 0.0) -> np.ndarray:
    """Linear attack then exponential decay with time constant tau; zero before start."""
    t = seconds(duration) - start
    env = np.where(t < attack, t / max(attack, 1e-6), np.exp(-(t - attack) / tau))
    return np.where(t < 0, 0.0, env)


def glide(duration: float, f0: float, f1: float, time: float) -> np.ndarray:
    """Sine whose pitch moves exponentially from f0 to f1 over `time` seconds, then holds."""
    t = seconds(duration)
    k = np.clip(t / time, 0, 1)
    freq = f0 * (f1 / f0) ** k
    return np.sin(2 * np.pi * np.cumsum(freq) / SR)


def bell(duration: float, f0: float, partials, start: float = 0.0, attack: float = 0.001) -> np.ndarray:
    """Sum of decaying sine partials: (ratio to f0, amplitude, decay seconds)."""
    t = seconds(duration) - start
    out = np.zeros_like(t)
    for ratio, amp, tau in partials:
        out += amp * np.sin(2 * np.pi * f0 * ratio * t) * envelope(duration, attack, tau, start)
    return np.where(t < 0, 0.0, out)


def noise(duration: float, seed: int) -> np.ndarray:
    return np.random.default_rng(seed).standard_normal(int(duration * SR))


def bandpass(x: np.ndarray, centre, q: float) -> np.ndarray:
    """Chamberlin state-variable band-pass; centre is a number or one value per sample."""
    centre = np.broadcast_to(np.asarray(centre, dtype=float), x.shape)
    f = 2 * np.sin(np.pi * np.minimum(centre, SR / 6) / SR)
    damp = 1 / q
    low = band = 0.0
    out = np.empty_like(x)
    for i, sample in enumerate(x):
        low += f[i] * band
        high = sample - low - damp * band
        band += f[i] * high
        out[i] = band
    return out


def sweep(duration: float, f0: float, f1: float) -> np.ndarray:
    k = seconds(duration) / duration
    return f0 * (f1 / f0) ** k


def mix(duration: float, *parts: tuple[np.ndarray, float]) -> np.ndarray:
    """Place (signal, start seconds) pairs on one track of `duration` seconds."""
    out = np.zeros(int(duration * SR))
    for signal, start in parts:
        i = int(start * SR)
        n = min(len(signal), len(out) - i)
        out[i : i + n] += signal[:n]
    return out


def finish(x: np.ndarray, peak_db: float) -> np.ndarray:
    """Peak-normalise and fade the last 5 ms so the end never clicks."""
    x = x / np.max(np.abs(x)) * 10 ** (peak_db / 20)
    fade = min(len(x), int(0.005 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    return x


def speed(x: np.ndarray, factor: float) -> np.ndarray:
    """Resample like Roblox's PlaybackSpeed (pitch and length together), for previews."""
    positions = np.arange(0, len(x) - 1, factor)
    return np.interp(positions, np.arange(len(x)), x)


# --- the sounds (sound-list.md section 5) -----------------------------------------------------

A5 = 880.0
GLOCK = ((1.0, 1.0, 0.35), (2.76, 0.35, 0.12), (5.40, 0.15, 0.06), (8.93, 0.06, 0.03))
MARIMBA = ((1.0, 1.0, 0.12), (3.9, 0.25, 0.04), (9.2, 0.05, 0.015))
COIN = ((1.0, 1.0, 0.045), (1.47, 0.6, 0.03), (2.09, 0.35, 0.02))


def ui_click() -> np.ndarray:
    d = 0.07
    tone = (glide(d, 1100, 700, 0.04) + 0.15 * glide(d, 2200, 1400, 0.04)) * envelope(d, 0.001, 0.015)
    tick = bandpass(noise(d, 1), 3000, 2) * envelope(d, 0.0005, 0.002) * 0.3
    return finish(tone + tick, -6)


def ui_error() -> np.ndarray:
    d = 0.26

    def note(f: float, length: float) -> np.ndarray:
        tone = glide(length, f, f * 0.97, length)
        rounded = tone + 0.3 * glide(length, 2 * f, 2 * f * 0.97, length) + 0.1 * glide(length, 3 * f, 3 * f * 0.97, length)
        return rounded * envelope(length, 0.003, 0.06)

    return finish(mix(d, (note(392.0, 0.11), 0.0), (note(293.7, 0.16), 0.1)), -6)


def net_swing() -> np.ndarray:
    d = 0.28
    t = seconds(d)
    shape = np.where(t < 0.11, np.sin(np.pi / 2 * t / 0.11) ** 2, np.exp(-(t - 0.11) / 0.06))
    air = bandpass(noise(d, 2), sweep(d, 500, 2800), 1.5)
    return finish(air * shape, -3)


def circle_perfect() -> np.ndarray:
    return finish(bell(0.6, A5, GLOCK), -3)


def circle_good() -> np.ndarray:
    return finish(bell(0.35, A5, MARIMBA, attack=0.002), -6)


def circle_miss() -> np.ndarray:
    d = 0.18
    body = glide(d, 260, 140, 0.05) * envelope(d, 0.002, 0.04)
    pat = bandpass(noise(d, 3), 900, 1.2) * envelope(d, 0.001, 0.025) * 0.35
    return finish(body + pat, -8)


def circle_appear() -> np.ndarray:
    d = 0.08
    return finish(glide(d, 1320, 1400, 0.05) * envelope(d, 0.002, 0.02), -10)


def catch_start() -> np.ndarray:
    d = 0.4
    t = seconds(d)
    shape = np.sin(np.pi * np.clip(t / d, 0, 1)) ** 1.5
    air = bandpass(noise(d, 4), sweep(d, 400, 1600), 2.0) * shape
    lift = glide(d, 520, 780, 0.3) * envelope(d, 0.01, 0.12, start=0.05) * 0.25
    return finish(air + lift, -6)


def catch_sparkle() -> np.ndarray:
    d = 0.85
    fwump = bandpass(noise(0.12, 5), sweep(0.12, 600, 200), 0.8) * envelope(0.12, 0.003, 0.03)
    notes = (1760.0, 1980.0, 2200.0, 2640.0, 2933.3, 3520.0, 3960.0)
    tinks = [
        (bell(0.3, f, ((1.0, 1.0, 0.08), (2.76, 0.25, 0.03))) * (1.0 - 0.06 * i), 0.06 + 0.055 * i)
        for i, f in enumerate(notes)
    ]
    return finish(mix(d, (fwump * 1.6, 0.0), *tinks), -3)


def catch_miss() -> np.ndarray:
    d = 0.45
    whiff = bandpass(noise(0.16, 6), sweep(0.16, 2000, 700), 1.5) * envelope(0.16, 0.01, 0.04) * 0.6
    boop_len = 0.3
    boop = (glide(boop_len, 520, 300, 0.25) + 0.2 * glide(boop_len, 1040, 600, 0.25)) * envelope(boop_len, 0.01, 0.09)
    return finish(mix(d, (whiff, 0.0), (boop, 0.12)), -6)


def coin_pop() -> np.ndarray:
    return finish(bell(0.16, 2400.0, COIN, attack=0.0005), -8)


def purchase() -> np.ndarray:
    d = 0.65
    click = bandpass(noise(0.03, 7), 2500, 2) * envelope(0.03, 0.0005, 0.006)
    thunk = glide(0.05, 180, 120, 0.04) * envelope(0.05, 0.001, 0.015) * 0.6
    ching = bell(0.6, 1318.5, GLOCK) + 0.6 * bell(0.6, 2400.0, COIN) + 0.5 * bell(0.6, 3000.0, COIN, start=0.02)
    return finish(mix(d, (click, 0.0), (thunk, 0.0), (ching, 0.06)), -3)


HARP = ((1.0, 1.0, 0.6), (2.0, 0.45, 0.35), (3.0, 0.2, 0.2), (4.0, 0.08, 0.12))
PIANO = ((1.0, 1.0, 0.9), (2.003, 0.5, 0.6), (3.01, 0.25, 0.4), (4.02, 0.12, 0.3), (5.04, 0.06, 0.2))
SHOP_BELL = ((1.0, 1.0, 0.55), (2.32, 0.45, 0.25), (4.1, 0.2, 0.12), (5.4, 0.1, 0.08))


def note(name: str) -> float:
    """Frequency of a note like C6 or F#4 (A4 = 440 Hz)."""
    steps = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}[name[0]]
    steps += name.count("#") - name.count("b")
    return 440.0 * 2 ** ((steps + 12 * (int(name[-1]) - 4)) / 12)


def check_in_bell() -> np.ndarray:
    """The bell over your cafe door, swinging: three strikes, each softer."""
    d = 1.1
    strikes = [(bell(d, 1760.0, SHOP_BELL) * amp, at) for at, amp in ((0.0, 1.0), (0.12, 0.55), (0.27, 0.3))]
    jingle = [(bell(d, 3150.0, ((1.0, 1.0, 0.18), (2.1, 0.3, 0.06))) * 0.25, at) for at in (0.02, 0.14)]
    return finish(mix(d, *strikes, *jingle), -3)


def jingle_cat_found() -> np.ndarray:
    """New friend: a harp sweep up and four rising glockenspiel notes."""
    d = 2.2
    sweep_notes = ("C4", "E4", "G4", "C5", "E5", "G5", "C6")
    harp = [(bell(d, note(n), HARP, attack=0.002) * 0.45, 0.04 * i) for i, n in enumerate(sweep_notes)]
    glock = [(bell(d, note(n), GLOCK) * amp, at) for n, at, amp in
             (("C6", 0.3, 0.8), ("E6", 0.42, 0.8), ("G6", 0.54, 0.85), ("C7", 0.72, 1.0))]
    return finish(mix(d, *harp, *glock), -3)


def jingle_rank_up() -> np.ndarray:
    """The cafe grows: a piano run, a bright chord with glockenspiel on top and a soft horn swell."""
    d = 3.2
    run = [(bell(d, note(n), PIANO, attack=0.003) * 0.6, 0.09 * i) for i, n in enumerate(("G4", "B4", "D5", "G5"))]
    chord = [(bell(d, note(n), PIANO, attack=0.003) * 0.5, 0.45) for n in ("C5", "E5", "G5", "C6")]
    glock = [(bell(d, note(n), GLOCK) * 0.7, 0.45 + 0.1 * i) for i, n in enumerate(("C6", "E6", "G6", "C7"))]
    t = seconds(d)
    swell = np.clip((t - 0.45) / 0.5, 0, 1) * np.clip((d - t) / 1.2, 0, 1)
    horn = sum(np.sin(2 * np.pi * note(n) * k * t) / k for n in ("C4", "G4") for k in (1, 2, 3)) * swell * 0.12
    return finish(mix(d, *run, *chord, *glock) + horn, -3)


def stray_flee() -> np.ndarray:
    """A startled "mrrp!" and quick paws running off."""
    d = 0.55
    length = 0.16
    t = seconds(length)
    pitch = 450 * (650 / 450) ** np.clip(t / 0.1, 0, 1)
    phase = np.cumsum(pitch) / SR
    voice = (2 * (phase % 1.0) - 1) * (0.6 + 0.4 * np.sin(2 * np.pi * 28 * t)) * np.sin(np.pi * t / length) ** 0.6
    spectrum = np.fft.rfft(voice, 2 * len(voice))
    f = np.fft.rfftfreq(2 * len(voice), 1 / SR)
    formant = sum(a / (1 + ((f - c) / w) ** 2) for c, a, w in ((900, 1.0, 120), (1800, 0.6, 160), (3000, 0.25, 200)))
    mrrp = np.fft.irfft(spectrum * formant, 2 * len(voice))
    paws = [(bandpass(noise(0.03, 20 + i), 2200, 1.5) * envelope(0.03, 0.0008, 0.005) * (0.5 - 0.06 * i), 0.18 + 0.055 * i)
            for i in range(6)]
    return finish(mix(d, (mrrp / np.max(np.abs(mrrp)), 0.0), *paws), -3)


def cat_hiss() -> np.ndarray:
    """A Miss ends the catch: a short, cross (never scary) hiss as the cat jumps back."""
    d = 0.5
    t = seconds(d)
    shape = np.clip(t / 0.03, 0, 1) * np.exp(-np.clip(t - 0.12, 0, None) / 0.12)
    breath = bandpass(noise(d, 30), sweep(d, 4200, 3000), 1.2)
    spit = bandpass(noise(d, 31), 6500, 2.0) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 38 * t)))
    return finish((breath + 0.35 * spit) * shape, -4)


def paw_lost() -> np.ndarray:
    """A paw of patience pops off the row: a soft bubble pop, pitched down."""
    d = 0.16
    pop = glide(d, 900, 380, 0.05) * envelope(d, 0.001, 0.03)
    tick = bandpass(noise(0.01, 32), 3000, 2) * envelope(0.01, 0.0005, 0.002) * 0.3
    return finish(mix(d, (pop, 0.0), (tick, 0.0)), -6)


def purrfect_chime() -> np.ndarray:
    """Every circle Perfect: a gold chord that rings out, with a sparkle on top."""
    d = 1.6
    chord = [(bell(d, note(n), GLOCK) * amp, at) for n, at, amp in
             (("E6", 0.0, 0.8), ("G#6", 0.05, 0.75), ("B6", 0.1, 0.75), ("E7", 0.18, 1.0))]
    shimmer = [(bell(0.4, f, ((1.0, 1.0, 0.07), (2.76, 0.2, 0.03))) * 0.35, 0.25 + 0.05 * i)
               for i, f in enumerate((3951.1, 4434.9, 4978.0, 5274.0, 5919.9))]
    return finish(mix(d, *chord, *shimmer), -3)


def gate_dissolve() -> np.ndarray:
    """A gate's barrier melts away the first time it opens: a rising shimmer and a soft whoosh."""
    d = 1.6
    t = seconds(d)
    swell = np.sin(np.pi * np.clip(t / d, 0, 1)) ** 1.5
    air = bandpass(noise(d, 33), sweep(d, 500, 5000), 3.0) * swell * 0.6
    sparkle = [(bell(0.35, f, ((1.0, 1.0, 0.06),)) * (0.25 + 0.04 * i), 0.15 + 0.11 * i)
               for i, f in enumerate((1760.0, 1975.5, 2217.5, 2637.0, 2960.0, 3520.0, 3951.1, 4434.9, 5274.0, 5919.9, 7040.0))]
    return finish(mix(d, (air, 0.0), *sparkle), -3)


def shutters_up() -> np.ndarray:
    """A shop's shutters roll up: slats clattering faster, then a clunk at the top."""
    d = 1.4
    parts = []
    at, gap = 0.0, 0.07
    for i in range(16):
        slat = bandpass(noise(0.03, 40 + i), 1800 + 40 * i, 3.0) * envelope(0.03, 0.0008, 0.008)
        parts.append((slat * (0.5 + 0.02 * i), at))
        at += gap
        gap *= 0.93
    clunk = (glide(0.2, 140, 90, 0.05) * envelope(0.2, 0.002, 0.05)
             + bandpass(noise(0.2, 60), 600, 1.0) * envelope(0.2, 0.001, 0.02) * 0.5)
    rumble = bandpass(noise(at, 61), 250, 0.8) * np.sin(np.pi * seconds(at) / at) * 0.3
    return finish(mix(d, (rumble, 0.0), *parts, (clunk, at + 0.03)), -4)


def sign_flip() -> np.ndarray:
    """The door sign turns between sun and moon: a wooden knock and a little swish."""
    d = 0.4
    swish = bandpass(noise(0.18, 62), sweep(0.18, 800, 2400), 1.5) * np.sin(np.pi * seconds(0.18) / 0.18) * 0.4
    knock = bell(0.15, 420.0, MARIMBA, attack=0.001)
    return finish(mix(d, (swish, 0.0), (knock, 0.16), (knock * 0.5, 0.22)), -6)


def announce() -> np.ndarray:
    """A server shout-out: two bright notes under the banner (played a step higher per rarity)."""
    d = 0.9
    return finish(mix(d, (bell(d, note("G5"), GLOCK) * 0.8, 0.0), (bell(d, note("D6"), GLOCK), 0.12)), -4)


# --- the rest of the UI (sound list 5.8): soft, short and never louder than a click ----------------


def swish(d: float, f0: float, f1: float, seed: int) -> np.ndarray:
    """A soft paper swish whose brightness moves from f0 to f1, for panels opening and closing."""
    centre = sweep(d, f0, f1)
    air = bandpass(bandpass(noise(d, seed), centre, 1.2), centre, 1.2) * envelope(d, 0.004, d / 3)  # twice: soft, not hissy
    tone = glide(d, f0 / 4, f1 / 4, d) * envelope(d, 0.002, d / 4) * 0.25
    return air + tone


def ui_open() -> np.ndarray:
    return finish(swish(0.16, 900, 3200, 80), -8)


def ui_close() -> np.ndarray:
    return finish(swish(0.16, 3200, 900, 81), -8)


def ui_toast() -> np.ndarray:
    """A toast slides in: a small bubble pop with a light chime behind it."""
    d = 0.3
    pop = glide(d, 450, 950, 0.03) * envelope(d, 0.001, 0.02)
    return finish(mix(d, (pop, 0.0), (bell(d, note("E6"), GLOCK) * 0.35, 0.03)), -7)


def ui_tab() -> np.ndarray:
    """A tab or filter chip: one dry tick."""
    d = 0.045
    tick = bandpass(bandpass(noise(d, 82), 3800, 3), 3800, 3) * envelope(d, 0.0003, 0.004)
    return finish(tick + glide(d, 1900, 1700, d) * envelope(d, 0.0005, 0.006) * 0.4, -9)


def ui_toggle() -> np.ndarray:
    """A settings toggle: a little switch, press and release."""
    d = 0.09

    def tick(f: float) -> np.ndarray:
        return bell(0.05, f, MARIMBA) + bandpass(noise(0.05, 83), 3500, 3) * envelope(0.05, 0.0003, 0.003) * 0.5

    return finish(mix(d, (tick(1300), 0.0), (tick(1650) * 0.7, 0.035)), -8)


def ui_hint() -> np.ndarray:
    """A new tutorial prompt: one soft ding."""
    return finish(bell(0.45, note("A5"), GLOCK), -8)


def ui_rank_ready() -> np.ndarray:
    """Every rank up requirement met: a bright chime rising up the scale."""
    d = 0.75
    notes = [(note(n), 0.07 * i) for i, n in enumerate(("C6", "E6", "G6", "C7"))]
    return finish(mix(d, *[(bell(d - at, f, GLOCK), at) for f, at in notes]), -5)


def ui_dealer_open() -> np.ndarray:
    """The dealer's screen: a little music-box run, a bit mysterious (minor, rising then turning back)."""
    d = 0.75
    box = ((1.0, 1.0, 0.3), (3.0, 0.2, 0.08), (5.95, 0.08, 0.04))
    run = ("A5", "C6", "E6", "G6", "E6")
    return finish(mix(d, *[(bell(0.4, note(n), box) * (0.8 if i < 4 else 0.6), 0.065 * i) for i, n in enumerate(run)]), -6)


def ui_rename() -> np.ndarray:
    """A cat's new name is saved: a quick pencil scribble and a ding."""
    d = 0.5
    strokes = 0.5 + 0.5 * np.sin(2 * np.pi * 22 * seconds(0.2)) ** 2
    pencil = bandpass(bandpass(noise(0.2, 84), 2600, 2), 2600, 2) * strokes * envelope(0.2, 0.004, 0.08)
    return finish(mix(d, (pencil * 0.6, 0.0), (bell(0.3, note("D6"), GLOCK), 0.19)), -7)


# --- design v0.5: the chase after a miss and the shove (sound list 5.1 and 5.3) ----------------------


def stray_sprint() -> np.ndarray:
    """A missed cat bolts (F40): a scrabble of claws, then soft paws galloping off, each stride a little fainter."""
    d = 1.0
    scrabble = bandpass(bandpass(noise(0.09, 90), 2600, 1.5), 2600, 1.5) * envelope(0.09, 0.002, 0.03) * 0.3
    parts = [(scrabble, 0.0)]
    for stride in range(5):
        for k, offset in enumerate((0.0, 0.03, 0.085, 0.115)):  # a running cat's four feet, two by two
            centre = 1100 + 250 * (k % 2)
            pad = bandpass(bandpass(noise(0.04, 100 + 4 * stride + k), centre, 1.5), centre, 1.5)  # twice: soft pads
            pad *= envelope(0.04, 0.001, 0.01)
            thump = glide(0.04, 260, 180, 0.02) * envelope(0.04, 0.001, 0.012) * 0.5
            level = 0.9 * 0.82**stride * (1.0 if k % 2 == 0 else 0.75)
            parts.append(((pad + thump) * level, 0.05 + 0.19 * stride + offset))
    return finish(mix(d, *parts), -4)


def shove() -> np.ndarray:
    """A shove (F41) is a playful push, never a hit: a quick whoosh into a soft, bouncy "boop"."""
    d = 0.4
    whoosh = swish(0.14, 600, 2200, 80)
    boop = glide(0.25, 560, 330, 0.06) * envelope(0.25, 0.003, 0.05) * 0.6
    cushion = glide(0.25, 210, 120, 0.08) * envelope(0.25, 0.01, 0.06)
    cloth = bandpass(bandpass(noise(0.12, 81), 900, 1.0), 900, 1.0) * envelope(0.12, 0.004, 0.03) * 0.5
    return finish(mix(d, (whoosh, 0.0), (boop, 0.1), (cushion, 0.1), (cloth, 0.1)), -4)


def bump_held() -> np.ndarray:
    """A shoved carrier holds on ("It held on tight!"): a rubbery double squeeze, then a light mint shimmer."""
    d = 0.6
    parts = []
    for i, (f0, f1) in enumerate(((700.0, 1050.0), (800.0, 1200.0))):
        length = 0.11
        t = seconds(length)
        pitch = sweep(length, f0, f1) * (1 + 0.04 * np.sin(2 * np.pi * 30 * t))
        phase = 2 * np.pi * np.cumsum(pitch) / SR
        squeak = (np.sin(phase) + 0.3 * np.sin(2 * phase)) * np.sin(np.pi * t / length) ** 0.7
        parts.append((squeak * 0.7, 0.13 * i))
    shimmer = [(bell(0.3, f, ((1.0, 1.0, 0.08),)) * 0.25, 0.28 + 0.05 * i) for i, f in enumerate((2637.0, 3136.0, 3951.1))]
    return finish(mix(d, *parts, *shimmer), -5)


# --- 2026-10-27 features: hold to catch, Drop, zones, travel, roles, gifts, Index, gold, the wheel ------------


def cat_voice(length: float, f0: float, f_peak: float, f_end: float, trill: float, seed: int) -> np.ndarray:
    """A small cat voice: a buzzy tone that rises to f_peak and falls to f_end through mouth formants.
    trill (0 to 1) is how much of the rolled "rr" there is; 0 is a plain "mew"."""
    t = seconds(length)
    k = t / length
    pitch = np.where(k < 0.4, f0 * (f_peak / f0) ** (k / 0.4), f_peak * (f_end / f_peak) ** ((k - 0.4) / 0.6))
    pitch = pitch * (1 + 0.01 * np.random.default_rng(seed).standard_normal(len(t)).cumsum() / np.sqrt(len(t)))
    phase = np.cumsum(pitch) / SR
    buzz = (2 * (phase % 1.0) - 1) * (1 - trill * 0.4 + trill * 0.4 * np.sin(2 * np.pi * 28 * t))
    buzz *= np.sin(np.pi * np.clip(k, 0, 1)) ** 0.6
    spectrum = np.fft.rfft(buzz, 2 * len(buzz))
    f = np.fft.rfftfreq(2 * len(buzz), 1 / SR)
    mouth = sum(a / (1 + ((f - c) / w) ** 2) for c, a, w in ((900, 1.0, 130), (1900, 0.6, 170), (3100, 0.25, 220)))
    out = np.fft.irfft(spectrum * mouth, 2 * len(buzz))[: len(buzz)]
    return out / np.max(np.abs(out))


def pad_step(seed: int, centre: float = 1100.0) -> np.ndarray:
    """One soft paw landing: a padded tap with a little low thump."""
    pad = bandpass(bandpass(noise(0.04, seed), centre, 1.5), centre, 1.5) * envelope(0.04, 0.001, 0.01)
    return pad / np.max(np.abs(pad)) + glide(0.04, 240, 170, 0.02) * envelope(0.04, 0.001, 0.012) * 0.6


def hold_fill() -> np.ndarray:
    """Holding E on a stray (F45): a soft rising whirr over the 0.5 s hold that lands on a little pop and tink.
    Audio stretches it to the prompt's HoldDuration and fades it out if the key is let go early."""
    d = 0.62
    rise = 0.48
    t = seconds(rise)
    swell = 0.1 + 0.9 * (t / rise) ** 1.4  # audible at once, so the hold answers the key
    air = bandpass(bandpass(noise(rise, 110), sweep(rise, 500, 2600), 2.0), sweep(rise, 500, 2600), 2.0) * swell
    tone = glide(rise, 330, 660, rise) * (0.8 + 0.2 * np.sin(2 * np.pi * 14 * t)) * swell * 0.35
    pop = glide(0.06, 600, 1250, 0.02) * envelope(0.06, 0.001, 0.015) * 0.8
    tink = bell(0.14, note("E6"), GLOCK) * 0.45
    return finish(mix(d, (air / np.max(np.abs(air)) * 0.6 + tone, 0.0), (pop, rise), (tink, rise + 0.005)), -6)


def cat_drop() -> np.ndarray:
    """Drop (F45, the Drop button or G): the cat hops down with a small "mrrp", lands on soft paws and shakes off."""
    d = 0.6
    mrrp = cat_voice(0.16, 520, 640, 560, 0.8, 111) * 0.7
    land = [(pad_step(112 + i, 1000 + 120 * i) * amp, at) for i, (at, amp) in enumerate(((0.2, 0.9), (0.225, 0.7)))]
    shake = bandpass(bandpass(noise(0.14, 116), 2400, 1.2), 2400, 1.2) * envelope(0.14, 0.01, 0.05)
    shake *= 0.6 + 0.4 * np.sin(2 * np.pi * 18 * seconds(0.14))
    pats = [(pad_step(117 + i, 1300) * 0.35, 0.42 + 0.06 * i) for i in range(2)]
    return finish(mix(d, (mrrp, 0.0), *land, (shake / np.max(np.abs(shake)) * 0.25, 0.27), *pats), -5)


FELT = ((1.0, 1.0, 0.5), (2.0, 0.25, 0.2), (3.0, 0.08, 0.1))


def zone_safe() -> np.ndarray:
    """Back on the safe street (the Safe zone chip): a calm, warm settle; two felt notes falling to a soft chord."""
    d = 0.75
    notes = [(bell(d - at, note(n), FELT, attack=0.012) * amp, at) for n, at, amp in
             (("D5", 0.0, 0.7), ("B4", 0.09, 0.7), ("G4", 0.18, 0.6), ("D5", 0.18, 0.35))]
    air = bandpass(bandpass(noise(0.3, 120), sweep(0.3, 2400, 900), 1.2), sweep(0.3, 2400, 900), 1.2)
    air *= np.sin(np.pi * seconds(0.3) / 0.3) * 0.15
    return finish(mix(d, *notes, (air / np.max(np.abs(air)) * 0.15, 0.0)), -10)


def zone_area() -> np.ndarray:
    """Into a catching area (shoves on): an alert little pluck up a fifth with a paw tap, playful, not a warning."""
    d = 0.5
    plucks = [(bell(d - at, note(n), MARIMBA, attack=0.001) * amp, at) for n, at, amp in
              (("D5", 0.0, 0.8), ("A5", 0.08, 1.0))]
    return finish(mix(d, *plucks, (pad_step(121, 1500) * 0.3, 0.16)), -10)


def travel_poof() -> np.ndarray:
    """Fast travel and the My Cafe button: a whoosh up, a soft poof where you land and a few sparkles."""
    d = 0.95
    up = 0.34
    t = seconds(up)
    whoosh = bandpass(bandpass(noise(up, 130), sweep(up, 400, 3800), 1.6), sweep(up, 400, 3800), 1.6)
    whoosh *= 0.12 + 0.88 * (t / up) ** 1.5  # audible from the first frame: the trip starts on the press
    poof = bandpass(noise(0.2, 131), sweep(0.2, 900, 300), 0.8) * envelope(0.2, 0.004, 0.05)
    thump = glide(0.15, 180, 110, 0.05) * envelope(0.15, 0.002, 0.04) * 0.6
    sparkle = [(bell(0.3, f, ((1.0, 1.0, 0.07), (2.76, 0.2, 0.03))) * 0.3, up + 0.06 + 0.05 * i)
               for i, f in enumerate((3520.0, 3136.0, 2637.0, 3951.1))]
    return finish(mix(d, (whoosh / np.max(np.abs(whoosh)) * 0.7, 0.0), (poof / np.max(np.abs(poof)), up),
                      (thump, up), *sparkle), -4)


def cat_placed() -> np.ndarray:
    """A cat starts a role at its station (Staff tab, Equip Best): a soft hop thump, a happy "mrrp" and 3 sparkles."""
    d = 0.6
    thump = (glide(0.12, 200, 120, 0.05) * envelope(0.12, 0.002, 0.03)
             + bandpass(noise(0.12, 140), 700, 1.0) * envelope(0.12, 0.001, 0.015) * 0.3)
    mrrp = cat_voice(0.17, 560, 760, 700, 0.7, 141) * 0.7
    sparkle = [(bell(0.25, f, ((1.0, 1.0, 0.06),)) * 0.25, 0.3 + 0.05 * i) for i, f in enumerate((2637.0, 3136.0, 3520.0))]
    return finish(mix(d, (thump, 0.0), (mrrp, 0.07), *sparkle), -5)


def cat_rest() -> np.ndarray:
    """A cat leaves its role to rest (Unequip, Unequip All): a sleepy sigh, a small falling "mew" and a soft flop."""
    d = 0.65
    sigh = bandpass(bandpass(noise(0.3, 150), sweep(0.3, 1300, 500), 1.3), sweep(0.3, 1300, 500), 1.3)
    sigh *= np.sin(np.pi * seconds(0.3) / 0.3) ** 1.5
    mew = cat_voice(0.2, 620, 650, 430, 0.0, 151) * 0.55
    flop = glide(0.14, 170, 110, 0.05) * envelope(0.14, 0.004, 0.04) * 0.6
    return finish(mix(d, (sigh / np.max(np.abs(sigh)) * 0.35, 0.0), (mew, 0.12), (flop, 0.4)), -6)


def gift_claim() -> np.ndarray:
    """A Tip Jar gift is claimed (F47): a ribbon tug and paper pop, then coins tumbling into the jar and a chime."""
    d = 1.05
    tug = bandpass(bandpass(noise(0.12, 160), sweep(0.12, 1500, 3000), 1.5), sweep(0.12, 1500, 3000), 1.5)
    tug *= np.sin(np.pi * seconds(0.12) / 0.12)
    pop = glide(0.07, 380, 900, 0.025) * envelope(0.07, 0.001, 0.02)
    coins = [(bell(0.18, 2400.0 * (1 + 0.06 * ((i * 5) % 7 - 3)), COIN, attack=0.0005) * (0.5 - 0.04 * i), 0.2 + 0.055 * i)
             for i in range(7)]
    chime = [(bell(0.6, note(n), GLOCK) * 0.6, at) for n, at in (("C6", 0.3), ("G6", 0.42))]
    return finish(mix(d, (tug / np.max(np.abs(tug)) * 0.4, 0.0), (pop * 0.8, 0.12), *coins, *chime), -4)


def index_reward() -> np.ndarray:
    """An Index reward is claimed (F48): a page turns, a stamp lands on it, and a bright run rises to a sparkle."""
    d = 1.5
    turn = 0.2
    page = bandpass(bandpass(noise(turn, 170), sweep(turn, 900, 3000), 1.2), sweep(turn, 900, 3000), 1.2)
    page *= np.sin(np.pi * seconds(turn) / turn) ** 1.2
    flap = bandpass(noise(0.03, 171), 1800, 1.5) * envelope(0.03, 0.0008, 0.008)
    stamp = (glide(0.18, 160, 95, 0.05) * envelope(0.18, 0.002, 0.04)
             + bandpass(noise(0.18, 172), 1200, 1.0) * envelope(0.18, 0.0008, 0.012) * 0.6)
    run = [(bell(d - at, note(n), GLOCK) * 0.75, at) for n, at in
           (("C6", 0.36), ("E6", 0.45), ("G6", 0.54), ("C7", 0.66))]
    sparkle = [(bell(0.3, f, ((1.0, 1.0, 0.06),)) * 0.22, 0.78 + 0.05 * i) for i, f in enumerate((4186.0, 4698.6, 5274.0))]
    return finish(mix(d, (page / np.max(np.abs(page)) * 0.5, 0.0), (flap * 0.4, turn - 0.02), (stamp, 0.24), *run, *sparkle), -3)


# Metal bar partials: a gold "ting" that is brighter and longer than the glockenspiel
GOLD = ((1.0, 1.0, 0.8), (2.76, 0.5, 0.4), (5.40, 0.3, 0.22), (8.93, 0.15, 0.12), (13.3, 0.06, 0.06))


def gold_reveal() -> np.ndarray:
    """A gold cat (F42): a shimmer rising into a rich gold bell, the sparkle settling around it. Ducks the music."""
    d = 1.8
    rise = 0.55
    t = seconds(rise)
    shimmer = bandpass(bandpass(noise(rise, 180), sweep(rise, 2000, 7000), 4.0), sweep(rise, 2000, 7000), 4.0)
    shimmer *= (t / rise) ** 2
    steps = (1760.0, 2217.5, 2637.0, 3520.0, 4434.9, 5274.0)
    climb = [(bell(0.25, f, ((1.0, 1.0, 0.05),)) * (0.2 + 0.03 * i), 0.07 * i) for i, f in enumerate(steps)]
    chord = [(bell(d - rise, note(n), GOLD, attack=0.002) * amp, rise) for n, amp in (("E6", 0.9), ("B6", 0.6), ("E7", 0.35))]
    settle = [(bell(0.3, f, ((1.0, 1.0, 0.07),)) * 0.18, rise + 0.25 + 0.09 * i)
              for i, f in enumerate((5274.0, 4434.9, 3951.1, 3520.0))]
    return finish(mix(d, (shimmer / np.max(np.abs(shimmer)) * 0.35, 0.0), *climb, *chord, *settle), -3)


def shimmer_rare() -> np.ndarray:
    """Near a gold or Epic-and-up stray: faint twinkles in a seamless 2 s loop, so you can find it in the dark."""
    length = 2.0
    n = int(length * SR)
    track = np.zeros(n)
    rng = np.random.default_rng(190)
    for i in range(7):
        at = int((i + 0.4 * rng.random()) * n / 7)
        f = rng.choice((3520.0, 3951.1, 4434.9, 5274.0, 5919.9))
        tink = bell(0.5, f, ((1.0, 1.0, 0.09), (2.76, 0.2, 0.03))) * (0.5 + 0.5 * rng.random())
        end = at + len(tink)
        track[at:min(end, n)] += tink[: min(end, n) - at]
        if end > n:  # wrap the tail round to the start, so the loop has no seam
            track[: end - n] += tink[n - at :]
    hum = np.fft.rfft(np.random.default_rng(191).standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / SR)
    air = np.fft.irfft(hum * np.exp(-(((f - 7000) / 2500) ** 2)), n)  # circular, so it loops too
    x = track + air / np.max(np.abs(air)) * 0.05
    return x / np.max(np.abs(x)) * 10 ** (-10 / 20)  # no end fade: it is a loop


def spin_start() -> np.ndarray:
    """The Spin Wheel window (F49) starts turning: a wooden ratchet winding up quickly into a whoosh."""
    d = 0.6
    clicks = []
    at, gap = 0.0, 0.065
    for i in range(6):
        knock = bell(0.05, 1200.0 * (1 + 0.04 * i), MARIMBA, attack=0.0005)
        click = bandpass(bandpass(noise(0.05, 205 + i), 3800, 3), 3800, 3) * envelope(0.05, 0.0003, 0.003)
        clicks.append(((knock + click / np.max(np.abs(click)) * 0.4) * (0.6 + 0.06 * i), at))
        at += gap
        gap *= 0.8
    up = 0.36
    whoosh = bandpass(bandpass(noise(up, 211), sweep(up, 500, 2600), 1.6), sweep(up, 500, 2600), 1.6)
    whoosh *= np.sin(np.pi * seconds(up) / up) ** 1.2
    return finish(mix(d, *clicks, (whoosh / np.max(np.abs(whoosh)) * 0.6, 0.2)), -6)


def wheel_tick() -> np.ndarray:
    """The Spin Wheel window: one peg clicking past the pointer. Played once per slice, so it slows with the wheel."""
    d = 0.05
    knock = bell(d, 1800.0, MARIMBA, attack=0.0005)
    click = bandpass(bandpass(noise(d, 200), 4000, 3), 4000, 3) * envelope(d, 0.0003, 0.003)
    return finish(knock + click / np.max(np.abs(click)) * 0.5, -6)


def wheel_win() -> np.ndarray:
    """The Spin Wheel stops on a prize: a quick run up into a bright chord, coins sparkling on top."""
    d = 1.4
    run = [(bell(d - at, note(n), GLOCK) * 0.6, at) for n, at in
           (("C6", 0.0), ("D6", 0.06), ("E6", 0.12), ("G6", 0.18))]
    chord = [(bell(d - 0.28, note(n), PIANO, attack=0.003) * 0.5, 0.28) for n in ("C5", "E5", "G5", "C6")]
    top = [(bell(d - 0.28, note("C7"), GLOCK) * 0.7, 0.28)]
    coins = [(bell(0.18, 2400.0 * (1 + 0.05 * (i % 3)), COIN, attack=0.0005) * 0.35, 0.36 + 0.07 * i) for i in range(5)]
    return finish(mix(d, *run, *chord, *top, *coins), -3)


def ui_slider() -> np.ndarray:
    """A volume slider moves a 5 % step: a tiny soft tick (it plays through the sound channel, so it previews it)."""
    d = 0.035
    tick = bell(d, 1500.0, ((1.0, 1.0, 0.006), (2.4, 0.3, 0.003)), attack=0.0003)
    return finish(tick, -12)


def ui_gift_ready() -> np.ndarray:
    """A Tip Jar gift is ready to claim: a glass jar "ting" and a small two-note chime."""
    d = 0.6
    jar = bell(0.5, 2650.0, ((1.0, 1.0, 0.25), (2.32, 0.4, 0.12), (4.25, 0.2, 0.06)), attack=0.0005)
    chime = [(bell(d - at, note(n), GLOCK) * 0.6, at) for n, at in (("A5", 0.08), ("E6", 0.17))]
    return finish(mix(d, (jar * 0.6, 0.0), *chime), -8)


def ui_badge() -> np.ndarray:
    """A red dot appears on a menu button: a tiny bubble blip."""
    d = 0.11
    blip = glide(d, 700, 1450, 0.03) * envelope(d, 0.001, 0.025)
    return finish(blip, -11)


# --- the short night and the v0.8 features (features.md 2f, F55 to F66) ---------------------------

# A small town bell: hum an octave down, prime, minor third, fifth, nominal and two quick high partials
TOWN_BELL = ((0.5, 0.5, 1.4), (1.0, 1.0, 1.1), (1.19, 0.4, 0.7), (1.5, 0.3, 0.55), (2.0, 0.3, 0.45),
             (2.5, 0.1, 0.25), (3.0, 0.06, 0.18))
VIBES = ((1.0, 1.0, 0.9), (4.0, 0.18, 0.22), (10.0, 0.04, 0.05))
CELESTA = ((1.0, 1.0, 0.5), (2.0, 0.2, 0.2), (4.0, 0.12, 0.08))


def fade_tail(x: np.ndarray, length: float) -> np.ndarray:
    """Fade the last `length` seconds to silence, so a long ring ends softly instead of being cut."""
    n = min(len(x), int(length * SR))
    x = x.copy()
    x[-n:] *= np.linspace(1, 0, n) ** 1.5
    return x


def vibe(d: float, f: float, offset: float = 0.0) -> np.ndarray:
    """One vibraphone note with its slow motor tremolo."""
    t = seconds(d)
    return bell(d, f, VIBES, attack=0.002) * (1 - 0.22 * (0.5 + 0.5 * np.sin(2 * np.pi * 5.5 * t + offset)))


def reed(d: float, f: float) -> np.ndarray:
    """A soft clarinet-like note: odd harmonics, a breathy start and a little vibrato."""
    t = seconds(d)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.0 * t) * np.clip((t - 0.08) / 0.1, 0, 1)
    phase = np.cumsum(f * vib) / SR
    tone = sum(np.sin(2 * np.pi * k * phase) / k ** 1.3 for k in (1, 3, 5, 7))
    breath = bandpass(noise(d, int(f)), f * 3, 2.0) * 0.04
    shape = np.clip(t / 0.025, 0, 1) * np.clip((d - t) / 0.06, 0, 1)
    return (tone + breath) * shape


def choir(d: float, freqs, seed: int) -> np.ndarray:
    """A wordless "ah" pad: slightly detuned buzzes through vowel formants, swelling in and out."""
    t = seconds(d)
    rng = np.random.default_rng(seed)
    buzz = np.zeros_like(t)
    for f in freqs:
        for detune in (-0.004, 0.0, 0.004):
            phase = (f * (1 + detune) * t + rng.random()) % 1.0
            buzz += 2 * phase - 1
    spectrum = np.fft.rfft(buzz, 2 * len(buzz))
    hz = np.fft.rfftfreq(2 * len(buzz), 1 / SR)
    vowel = sum(a / (1 + ((hz - c) / w) ** 2) for c, a, w in ((750, 1.0, 110), (1150, 0.6, 130), (2700, 0.2, 200)))
    out = np.fft.irfft(spectrum * vowel, 2 * len(buzz))[: len(buzz)]
    return out / np.max(np.abs(out)) * np.sin(np.pi * np.clip(t / d, 0, 1)) ** 0.8


def dusk_bell() -> np.ndarray:
    """Night in 15 s (F66): the town clock's bell tolls twice, warm and unhurried, so everyone knows dusk is near."""
    d = 3.4
    tolls = [(bell(d - at, note("A4"), TOWN_BELL, attack=0.002) * amp, at) for at, amp in ((0.0, 1.0), (1.15, 0.8))]
    clapper = [(bandpass(noise(0.02, 300 + i), 2800, 2) * envelope(0.02, 0.0005, 0.004) * 0.25, at)
               for i, at in enumerate((0.0, 1.15))]
    return finish(fade_tail(mix(d, *tolls, *clapper), 0.9), -5)


def sting_dusk() -> np.ndarray:
    """Night falls (F66): a descending vibraphone run, a lamp clicking on and the area gates latching shut till sunrise."""
    d = 3.2
    run = [(vibe(d - at, note(n), at) * 0.7, at) for n, at in (("E6", 0.0), ("C6", 0.14), ("A5", 0.28), ("E5", 0.42))]
    chord = [(vibe(d - 0.62, note(n), i) * 0.4, 0.62) for i, n in enumerate(("A4", "C5", "E5", "G5"))]
    click = bandpass(noise(0.03, 310), 2600, 2.5) * envelope(0.03, 0.0005, 0.005) * 0.35
    latch = mix(0.25, (bell(0.25, 520.0, MARIMBA, attack=0.0008) * 0.5, 0.0),
                (bandpass(noise(0.08, 311), 900, 1.2) * envelope(0.08, 0.0008, 0.012) * 0.45, 0.0))
    return finish(fade_tail(mix(d, *run, *chord, (click, 0.58), (latch, 1.35), (latch * 0.45, 1.42)), 1.0), -4)


def sting_dawn() -> np.ndarray:
    """Sunrise (F66): a rising glockenspiel run into one shop bell and a warm swell as the areas open with fresh cats."""
    d = 3.2
    run = [(bell(d - at, note(n), GLOCK) * 0.7, at) for n, at in
           (("C6", 0.0), ("D6", 0.09), ("E6", 0.18), ("G6", 0.27), ("C7", 0.4))]
    shop = bell(d - 0.4, 1760.0, SHOP_BELL) * 0.55
    t = seconds(d)
    swell = np.clip(t / 0.6, 0, 1) * np.clip((d - t) / 1.6, 0, 1)
    pad = sum(np.sin(2 * np.pi * note(n) * k * t) / k ** 1.5 for n in ("C4", "G4", "E5") for k in (1, 2)) * swell * 0.07
    return finish(fade_tail(mix(d, *run, (shop, 0.4)) + pad, 0.8), -3)


def ui_code_redeem() -> np.ndarray:
    """A code works at the Codes Cat (F65): a key turns in a little lock, then a bright run and a sprinkle of coins."""
    d = 1.25
    key = [(bandpass(noise(0.025, 320 + i), 3200, 3) * envelope(0.025, 0.0003, 0.004) * 0.5, at)
           for i, at in enumerate((0.0, 0.07))]
    turn = bell(0.1, 1400.0, MARIMBA, attack=0.0005) * 0.4
    run = [(bell(d - at, note(n), GLOCK) * amp, at) for n, at, amp in
           (("C6", 0.16, 0.6), ("E6", 0.24, 0.6), ("G6", 0.32, 0.65), ("C7", 0.42, 0.85))]
    coins = [(bell(0.18, 2400.0 * (1 + 0.05 * (i % 3)), COIN, attack=0.0005) * 0.3, 0.5 + 0.06 * i) for i in range(4)]
    return finish(fade_tail(mix(d, *key, (turn, 0.07), *run, *coins), 0.3), -5)


def announce_mythical() -> np.ndarray:
    """A Mythical cat in the sunrise wave (F58): the shout-out's two notes grow into a shimmering gold chord over a
    wordless choir. Ducks the music."""
    d = 2.4
    two = [(bell(d, note("G5"), GLOCK) * 0.6, 0.0), (bell(d, note("D6"), GLOCK) * 0.7, 0.12)]
    rise = 0.45
    tr = seconds(rise)
    shimmer = bandpass(bandpass(noise(rise, 390), sweep(rise, 2000, 7000), 4.0), sweep(rise, 2000, 7000), 4.0)
    shimmer *= (tr / rise) ** 2
    chord = [(bell(d - 0.3 - rise, note(n), GOLD, attack=0.002) * amp, 0.3 + rise)
             for n, amp in (("G5", 0.7), ("B5", 0.5), ("D6", 0.55), ("G6", 0.45))]
    voices = choir(d - 0.4, (note("G3"), note("D4"), note("B4")), 391) * 0.3
    sparkle = [(bell(0.3, f, ((1.0, 1.0, 0.07),)) * 0.18, 0.9 + 0.08 * i)
               for i, f in enumerate((3136.0, 3951.1, 4698.6, 5274.0))]
    return finish(fade_tail(mix(d, *two, (shimmer / np.max(np.abs(shimmer)) * 0.35, 0.3), *chord, (voices, 0.4),
                                *sparkle), 0.7), -3)


def cat_pick_up() -> np.ndarray:
    """A dropped cat is picked up (F56): a soft pop as it hops into your arms and a pleased little "mrrp"."""
    d = 0.42
    pop = glide(0.08, 400, 950, 0.03) * envelope(0.08, 0.001, 0.025)
    rustle = bandpass(noise(0.1, 330), 2500, 1.2) * envelope(0.1, 0.002, 0.03)
    mrrp = cat_voice(0.15, 600, 820, 760, 0.8, 331) * 0.6
    return finish(mix(d, (pop * 0.8, 0.0), (rustle / np.max(np.abs(rustle)) * 0.15, 0.0), (mrrp, 0.09)), -5)


def getaway() -> np.ndarray:
    """A catch pushes the crowd back (F55): a puff of air bursting outward, then quick light paws rushing off."""
    d = 0.85
    burst_len = 0.35
    burst = bandpass(bandpass(noise(burst_len, 340), sweep(burst_len, 2600, 500), 1.4), sweep(burst_len, 2600, 500), 1.4)
    burst *= envelope(burst_len, 0.006, 0.09)
    thump = glide(0.15, 170, 95, 0.05) * envelope(0.15, 0.002, 0.04) * 0.6
    rush_len = 0.3
    rush = bandpass(bandpass(noise(rush_len, 341), sweep(rush_len, 700, 3200), 1.6), sweep(rush_len, 700, 3200), 1.6)
    rush *= np.sin(np.pi * seconds(rush_len) / rush_len) ** 1.2
    paws = [(pad_step(342 + i, 1600) * (0.35 - 0.04 * i), 0.3 + 0.065 * i) for i in range(5)]
    return finish(mix(d, (burst / np.max(np.abs(burst)), 0.0), (thump, 0.0), (rush / np.max(np.abs(rush)) * 0.4, 0.3),
                      *paws), -4)


def tip_pile() -> np.ndarray:
    """Tip piles collected (F61): a short clink of coins scooped off the tables into your pocket."""
    d = 0.5
    scoop = bandpass(noise(0.1, 350), 4000, 1.5) * envelope(0.1, 0.002, 0.03)
    coins = [(bell(0.2, 2400.0 * (1 + 0.05 * ((i * 3) % 5 - 2)), COIN, attack=0.0005) * (0.7 - 0.08 * i),
              0.045 * i + 0.006 * ((i * 7) % 3)) for i in range(5)]
    return finish(mix(d, (scoop / np.max(np.abs(scoop)) * 0.2, 0.0), *coins), -6)


def rich_arrive() -> np.ndarray:
    """A rich customer at your cafe (F31, F61): a posh little "ding-dong" and a coin pile settling on the table."""
    d = 1.1
    dings = [(bell(d - at, note(n), SHOP_BELL) * 0.7, at) for n, at in (("E6", 0.0), ("C6", 0.17))]
    coins = [(bell(0.15, 1900.0 * (1 + 0.05 * ((i * 5) % 7 - 3)), COIN, attack=0.0005) * (0.45 - 0.05 * i),
              0.42 + 0.05 * i + 0.01 * i * i) for i in range(6)]
    return finish(fade_tail(mix(d, *dings, *coins), 0.25), -5)


def rich_tip() -> np.ndarray:
    """A rich tip goes into your till (F31, F61): a big cascade of coins and a bright chime as it lands."""
    d = 1.3
    rng = np.random.default_rng(360)
    coins = []
    at = 0.0
    for i in range(16):
        f = 2200.0 + 600.0 * rng.random()
        coins.append((bell(0.18, f, COIN, attack=0.0005) * (0.35 + 0.25 * np.sin(np.pi * i / 15)), at))
        at += 0.03 + 0.03 * (i / 15) ** 2 + 0.01 * rng.random()
    chime = [(bell(d - 0.55, note(n), GLOCK) * 0.6, 0.55 + 0.08 * j) for j, n in enumerate(("G6", "C7"))]
    return finish(fade_tail(mix(d, *coins, *chime), 0.3), -4)


def visitor_collector() -> np.ndarray:
    """The Cat Collector comes by (F63): a polite, curious little clarinet motif and the glint of a magnifying glass."""
    d = 1.5
    motif = [(reed(0.2, note(n)) * 0.55, at) for n, at in (("D5", 0.0), ("F#5", 0.17), ("A5", 0.34))]
    question = reed(0.5, note("G5")) * 0.55
    glint = bell(0.45, 4200.0, ((1.0, 1.0, 0.09), (2.76, 0.3, 0.04)), attack=0.001) * 0.3
    return finish(fade_tail(mix(d, *motif, (question, 0.52), (glint, 0.95)), 0.3), -7)


def ui_trade() -> np.ndarray:
    """A trade with the Cat Collector (F63): two little runs pass each other, then a bright "deal!" chord and a coin."""
    d = 1.2
    up = [(bell(d - at, note(n), MARIMBA) * 0.6, at) for n, at in (("C5", 0.0), ("E5", 0.07), ("G5", 0.14))]
    down = [(bell(d - at, note(n), MARIMBA) * 0.5, at) for n, at in (("G6", 0.02), ("E6", 0.09), ("C6", 0.16))]
    chord = [(bell(d - 0.3, note(n), GLOCK) * 0.5, 0.3) for n in ("C6", "E6", "G6")]
    coin = bell(0.2, 2600.0, COIN, attack=0.0005) * 0.35
    return finish(fade_tail(mix(d, *up, *down, *chord, (coin, 0.38)), 0.3), -6)


def visitor_mystery() -> np.ndarray:
    """The Mystery Visitor came by (F64): the swish of a cloak and a dreamy whole-tone celesta run, curious, never
    spooky."""
    d = 1.7
    cloak_len = 0.4
    cloak = bandpass(bandpass(noise(cloak_len, 370), sweep(cloak_len, 500, 1500), 1.2), sweep(cloak_len, 500, 1500), 1.2)
    cloak *= np.sin(np.pi * seconds(cloak_len) / cloak_len) ** 0.8
    run = [(bell(d - at, note(n), CELESTA) * 0.45, at) for n, at in
           (("C6", 0.1), ("D6", 0.18), ("E6", 0.26), ("F#6", 0.34), ("G#6", 0.42), ("A#6", 0.5))]
    land = bell(d - 0.68, note("C7"), CELESTA) * 0.55
    return finish(fade_tail(mix(d, (cloak / np.max(np.abs(cloak)) * 0.4, 0.0), *run, (land, 0.68)), 0.5), -6)


def gift_open() -> np.ndarray:
    """A Mystery gift is opened (F64): the ribbon slips, the paper tears, a pop, and a sparkle shows what was inside."""
    d = 1.2
    slip_len = 0.13
    slip = bandpass(bandpass(noise(slip_len, 380), sweep(slip_len, 1800, 3500), 1.5), sweep(slip_len, 1800, 3500), 1.5)
    slip *= np.sin(np.pi * seconds(slip_len) / slip_len)
    tear = []
    for i in range(8):
        crackle = bandpass(bandpass(noise(0.02, 381 + i), 2300 + 120 * (i % 4), 1.5), 2300 + 120 * (i % 4), 1.5)
        crackle *= envelope(0.02, 0.0015, 0.005)
        tear.append((crackle / np.max(np.abs(crackle)) * (0.22 + 0.02 * i), 0.15 + 0.03 * i))
    pop = glide(0.08, 380, 900, 0.03) * envelope(0.08, 0.001, 0.025)
    sparkle = [(bell(0.35, f, ((1.0, 1.0, 0.07), (2.76, 0.2, 0.03))) * 0.3, 0.5 + 0.06 * i)
               for i, f in enumerate((2637.0, 3136.0, 3520.0, 4186.0, 5274.0))]
    return finish(fade_tail(mix(d, (slip / np.max(np.abs(slip)) * 0.4, 0.0), *tear, (pop * 0.8, 0.42), *sparkle), 0.3),
                  -5)


def potion_drink() -> np.ndarray:
    """A potion is drunk (F64): a cork pops, three bubbly gulps, and a shimmer rises as it starts working."""
    d = 1.25
    cork = mix(0.06, (glide(0.06, 500, 1500, 0.02) * envelope(0.06, 0.0005, 0.012), 0.0),
               (bandpass(noise(0.03, 390), 2000, 2) * envelope(0.03, 0.0005, 0.005) * 0.5, 0.0))
    gulps = []
    for i in range(3):
        gulp = glide(0.11, 180, 320, 0.08) * envelope(0.11, 0.005, 0.04)
        bubble = bandpass(noise(0.11, 391 + i), 700, 4) * envelope(0.11, 0.004, 0.03)
        gulps.append(((gulp * 0.7 + bubble / np.max(np.abs(bubble)) * 0.25) * (1 - 0.1 * i), 0.14 + 0.15 * i))
    rise = 0.5
    tr = seconds(rise)
    shimmer = bandpass(bandpass(noise(rise, 395), sweep(rise, 1500, 6000), 4.0), sweep(rise, 1500, 6000), 4.0)
    shimmer *= (tr / rise) ** 1.5 * np.clip((rise - tr) / 0.05, 0, 1)
    sparkle = [(bell(0.3, f, ((1.0, 1.0, 0.06),)) * 0.25, 1.0 + 0.05 * i) for i, f in enumerate((3520.0, 4434.9, 5274.0))]
    return finish(fade_tail(mix(d, (cork, 0.0), *gulps, (shimmer / np.max(np.abs(shimmer)) * 0.35, 0.55), *sparkle), 0.15),
                  -5)


# --- design v0.11 and v0.12: the tackle and cat levels (sound list 5.3 and 5.5) ---------------------


def tackle_lunge() -> np.ndarray:
    """A tackle (F74) is a cartoon dive, never a hit: a rush of air that swells while the body flies and drops as
    it comes down, a cloth flutter on top and a soft rising "fwip" under it. The hit keeps the Shove sound."""
    d = 0.5
    fly = 0.42
    t = seconds(fly)
    rise = np.clip(t / 0.18, 0, 1)
    centre = 400 * (1500 / 400) ** rise * (700 / 1500) ** np.clip((t - 0.18) / 0.24, 0, 1)
    air = bandpass(bandpass(noise(fly, 400), centre, 1.4), centre, 1.4)
    air *= (0.3 + 0.7 * np.sin(np.pi * np.clip(t / 0.15, 0, 1) / 2)) * np.clip((fly - t) / 0.2, 0, 1)  # heard from the press
    flutter = bandpass(noise(fly, 401), 1500, 2.0) * (0.5 + 0.5 * np.sin(2 * np.pi * 38 * t)) * air
    fwip = glide(0.24, 230, 560, 0.16) * envelope(0.24, 0.015, 0.07)
    return finish(mix(d, (air / np.max(np.abs(air)), 0.0), (flutter / np.max(np.abs(flutter)) * 0.25, 0.0),
                      (fwip * 0.22, 0.02)), -5)


def tackle_miss() -> np.ndarray:
    """A tackle that hits nobody (F74): a soft belly flop, a skid along the floor that slows to a stop, and a
    little wooden "bonk bonk" going down, so a miss sounds silly rather than painful."""
    d = 1.0
    flop = (glide(0.25, 170, 85, 0.08) * envelope(0.25, 0.002, 0.06)
            + bandpass(noise(0.25, 410), 320, 1.0) * envelope(0.25, 0.001, 0.02) * 0.8)
    slide = 0.62
    t = seconds(slide)
    slow = t / slide
    grip = 0.55 + 0.45 * np.sin(2 * np.pi * np.cumsum(46 - 30 * slow) / SR)  # stick and slip, slower as it stops
    skid = bandpass(bandpass(noise(slide, 411), 1300 - 750 * slow, 1.6), 1300 - 750 * slow, 1.6) * grip
    skid *= np.clip(t / 0.03, 0, 1) * (1 - slow) ** 1.4
    bonk = [(bell(0.3, note(n), MARIMBA) * 0.3, at) for n, at in (("G4", 0.66), ("D4", 0.78))]
    return finish(fade_tail(mix(d, (flop, 0.0), (skid / np.max(np.abs(skid)) * 0.7, 0.04), *bonk), 0.1), -5)


def cat_level_up() -> np.ndarray:
    """One of your cats reaches a new level (F75): three quick celesta notes up and a small twinkle, short and
    soft, since a cafe full of cats levels up often."""
    d = 0.9
    run = [(bell(d - at, note(n), CELESTA) * 0.6, at) for n, at in (("D6", 0.0), ("F#6", 0.07), ("A6", 0.14))]
    twinkle = [(bell(0.3, f, ((1.0, 1.0, 0.05),)) * 0.18, 0.26 + 0.05 * i) for i, f in enumerate((3520.0, 4698.6))]
    return finish(fade_tail(mix(d, *run, *twinkle), 0.35), -7)


def purr_loop(seed: int, rate: float, out_s: float, in_s: float) -> np.ndarray:
    """A cat's purr over exactly one breath out and one breath in, so it loops. A purr is a fast train of tiny
    clicks (the voice box opening and closing about 25 times a second) heard through the mouth and nose, louder
    breathing out, softer and a little quicker breathing in, with a short pause at each turn and a soft airy
    breath under it. Rebuilt 2026-10-27: the first version was low noise pulsing, and read as a rumble."""
    gap = 0.12
    length = out_s + in_s + 2 * gap
    n = int(length * SR)
    rng = np.random.default_rng(seed)
    t = np.arange(n) / SR
    clicks = np.zeros(n)
    for start, d, hz, loud in ((0.0, out_s, rate, 1.0), (out_s + gap, in_s, rate * 1.08, 0.65)):
        at = start + rng.uniform(0, 0.01)
        while at < start + d:
            k = int(at * SR) % n
            into = (at - start) / d
            clicks[k] += loud * np.sin(np.pi * into) ** 0.5 * rng.uniform(0.75, 1.0)
            at += (1 / hz) * (1 + 0.06 * np.sin(2 * np.pi * 1.3 * at) + rng.normal(0, 0.03))  # a slight waver
    kernel_t = np.arange(int(0.012 * SR)) / SR
    kernel = np.random.default_rng(7).standard_normal(len(kernel_t)) * np.exp(-kernel_t / 0.0018)  # one click
    kernel += 0.3 * np.sin(2 * np.pi * 220 * kernel_t) * np.exp(-kernel_t / 0.004)
    padded = np.zeros(n)
    padded[: len(kernel)] = kernel
    voice = np.fft.irfft(np.fft.rfft(clicks) * np.fft.rfft(padded), n)  # circular, so the loop has no seam
    f = np.fft.rfftfreq(n, 1 / SR)
    nose = sum(a / (1 + ((f - c) / w) ** 2) for c, a, w in ((350, 0.8, 150), (900, 1.0, 300), (1800, 0.5, 400),
                                                            (3000, 0.15, 600)))
    highpass = 1 / np.sqrt(1 + (90 / np.maximum(f, 1)) ** 4)
    voice = np.fft.irfft(np.fft.rfft(voice) * nose * highpass, n)
    turns = np.clip(np.minimum(t, np.abs(t - (out_s + gap))) / 0.05, 0, 1)  # soften each start
    breathing = np.where(t < out_s + gap, np.sin(np.pi * np.clip(t / out_s, 0, 1)),
                         0.6 * np.sin(np.pi * np.clip((t - out_s - gap) / in_s, 0, 1)))
    air = np.fft.irfft(np.fft.rfft(rng.standard_normal(n)) * (1 / (1 + ((f - 1800) / 900) ** 2)), n)
    x = voice / np.max(np.abs(voice)) + 0.08 * air / np.max(np.abs(air)) * breathing
    x *= 0.15 + 0.85 * np.maximum(breathing, 0) ** 0.6 * turns
    return x / np.max(np.abs(x)) * 10 ** (-6 / 20)  # no end fade: it is a loop


def purr() -> np.ndarray:
    return purr_loop(70, 25.0, 1.25, 1.0)


def carry_purr() -> np.ndarray:
    return purr_loop(71, 23.5, 1.35, 1.05)


SOUNDS = {
    # name: (folder, bus, builder)
    "Click": ("ui", "Ui", ui_click),
    "Error": ("ui", "Ui", ui_error),
    "CatchStart": ("sfx", "Sfx", catch_start),
    "CircleAppear": ("sfx", "Sfx", circle_appear),
    "NetSwing": ("sfx", "Sfx", net_swing),
    "CirclePerfect": ("sfx", "Sfx", circle_perfect),
    "CircleGood": ("sfx", "Sfx", circle_good),
    "CircleMiss": ("sfx", "Sfx", circle_miss),
    "CatchSparkle": ("sfx", "Sfx", catch_sparkle),
    "CatchMiss": ("sfx", "Sfx", catch_miss),
    "CoinPop": ("sfx", "Sfx", coin_pop),
    "Purchase": ("sfx", "Sfx", purchase),
    "CheckInBell": ("sfx", "Sfx", check_in_bell),
    "StrayFlee": ("sfx", "Sfx", stray_flee),
    "JingleCatFound": ("music", "Music", jingle_cat_found),
    "JingleRankUp": ("music", "Music", jingle_rank_up),
    "CatHiss": ("sfx", "Sfx", cat_hiss),
    "PawLost": ("sfx", "Sfx", paw_lost),
    "PurrfectChime": ("sfx", "Sfx", purrfect_chime),
    "GateOpen": ("sfx", "Sfx", gate_dissolve),
    "ShuttersUp": ("sfx", "Sfx", shutters_up),
    "SignFlip": ("sfx", "Sfx", sign_flip),
    "Announce": ("sfx", "Sfx", announce),
    "Purr": ("sfx", "Sfx", purr),
    "CarryPurr": ("sfx", "Sfx", carry_purr),
    "Open": ("ui", "Ui", ui_open),
    "Close": ("ui", "Ui", ui_close),
    "Toast": ("ui", "Ui", ui_toast),
    "Tab": ("ui", "Ui", ui_tab),
    "Toggle": ("ui", "Ui", ui_toggle),
    "Hint": ("ui", "Ui", ui_hint),
    "RankReady": ("ui", "Ui", ui_rank_ready),
    "DealerOpen": ("ui", "Ui", ui_dealer_open),
    "Rename": ("ui", "Ui", ui_rename),
    "StraySprint": ("sfx", "Sfx", stray_sprint),
    "Shove": ("sfx", "Sfx", shove),
    "BumpHeld": ("sfx", "Sfx", bump_held),
    "HoldFill": ("sfx", "Sfx", hold_fill),
    "CatDrop": ("sfx", "Sfx", cat_drop),
    "ZoneSafe": ("sfx", "Sfx", zone_safe),
    "ZoneArea": ("sfx", "Sfx", zone_area),
    "TravelPoof": ("sfx", "Sfx", travel_poof),
    "CatPlaced": ("sfx", "Sfx", cat_placed),
    "CatRest": ("sfx", "Sfx", cat_rest),
    "GiftClaim": ("sfx", "Sfx", gift_claim),
    "IndexReward": ("sfx", "Sfx", index_reward),
    "GoldReveal": ("sfx", "Sfx", gold_reveal),
    "ShimmerRare": ("sfx", "Sfx", shimmer_rare),
    "SpinStart": ("ui", "Ui", spin_start),
    "SpinTick": ("ui", "Ui", wheel_tick),
    "SpinWin": ("ui", "Ui", wheel_win),
    "Slider": ("ui", "Ui", ui_slider),
    "GiftReady": ("ui", "Ui", ui_gift_ready),
    "Badge": ("ui", "Ui", ui_badge),
    "DuskBell": ("sfx", "Sfx", dusk_bell),
    "StingDusk": ("music", "Music", sting_dusk),
    "StingDawn": ("music", "Music", sting_dawn),
    "CodeRedeem": ("ui", "Ui", ui_code_redeem),
    "AnnounceMythical": ("sfx", "Sfx", announce_mythical),
    "CatPickUp": ("sfx", "Sfx", cat_pick_up),
    "Getaway": ("sfx", "Sfx", getaway),
    "TipPile": ("sfx", "Sfx", tip_pile),
    "RichArrive": ("sfx", "Sfx", rich_arrive),
    "RichTip": ("sfx", "Sfx", rich_tip),
    "VisitorCollector": ("sfx", "Sfx", visitor_collector),
    "Trade": ("ui", "Ui", ui_trade),
    "VisitorMystery": ("sfx", "Sfx", visitor_mystery),
    "GiftOpen": ("sfx", "Sfx", gift_open),
    "PotionDrink": ("sfx", "Sfx", potion_drink),
    "TackleLunge": ("sfx", "Sfx", tackle_lunge),
    "TackleMiss": ("sfx", "Sfx", tackle_miss),
    "CatLevelUp": ("sfx", "Sfx", cat_level_up),
}


# --- output -----------------------------------------------------------------------------------


def write_wav(path: Path, x: np.ndarray) -> None:
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def encode(wav: Path, out: Path, codec: list[str], channels: int = 1) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-ac", str(channels), "-ar", str(SR), *codec,
         "-fflags", "+bitexact", "-flags:a", "+bitexact", str(out)],  # same bytes every run
        check=True,
    )


def preview(rendered: dict[str, np.ndarray], folder: Path, tmp: Path) -> Path:
    gap = np.zeros(int(0.6 * SR))
    parts: list[np.ndarray] = []
    for x in rendered.values():
        parts += [x, gap]
    if "CirclePerfect" in rendered:
        parts.append(gap)
        for factor in PENTATONIC:  # the Perfect run
            parts += [speed(rendered["CirclePerfect"], factor), np.zeros(int(0.35 * SR))]
    if {"CatchStart", "CircleAppear", "NetSwing", "CirclePerfect", "CircleGood", "CatchSparkle"} <= rendered.keys():
        parts.append(gap)
        catch = [(rendered["CatchStart"], 0.0)]
        for i, grade in enumerate(("CirclePerfect", "CirclePerfect", "CircleGood")):  # an Epic: 3 circles
            at = 0.6 + i * 1.4
            hit = at + 0.95
            catch += [(rendered["CircleAppear"] * 0.8, at), (rendered["NetSwing"], hit - 0.08)]
            catch += [(speed(rendered[grade], PENTATONIC[i]), hit)]
        catch.append((rendered["CatchSparkle"], 0.6 + 2 * 1.4 + 0.95 + 0.6))
        parts.append(mix(6.0, *catch))
    track = np.concatenate(parts)
    wav = tmp / "preview.wav"
    write_wav(wav, track / max(1.0, np.max(np.abs(track))))
    out = folder / "cat-cafe-sfx-preview.mp3"
    encode(wav, out, ["-c:a", "libmp3lame", "-q:a", "2"])
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--only", help="comma list of names, e.g. CirclePerfect,CoinPop")
    parser.add_argument("--preview", help="folder for a listening preview mp3")
    args = parser.parse_args()

    names = list(SOUNDS) if not args.only else [n.strip() for n in args.only.split(",")]
    unknown = [n for n in names if n not in SOUNDS]
    if unknown:
        print(f"synth: unknown sound(s) {', '.join(unknown)}; known: {', '.join(SOUNDS)}", file=sys.stderr)
        return 2

    rendered: dict[str, np.ndarray] = {}
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        for name in names:
            folder, bus, build = SOUNDS[name]
            x = build()
            rendered[name] = x
            wav = tmp / f"{name}.wav"
            write_wav(wav, x)
            out = ROOT / folder / f"CatCafe_{bus}_{name}.ogg"
            encode(wav, out, ["-c:a", "libvorbis", "-q:a", "6"], channels=2 if folder == "music" else 1)
            print(f"synth: {out.relative_to(ROOT.parents[2]).as_posix()}  {len(x) / SR:.2f} s")
        if args.preview:
            folder = Path(args.preview)
            folder.mkdir(parents=True, exist_ok=True)
            print(f"synth: preview {preview(rendered, folder, tmp).as_posix()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
