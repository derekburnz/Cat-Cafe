"""Synthesize the store video's music: "Open for Business" (the DayA theme) as a 28 second upbeat cue.

Run from the repo root:  python assets/cat-cafe/audio/synth/trailer.py OUT_DIR

Animation-Engineer asked on 2026-11-03 for an upbeat, cosy track with no lyrics for Derek's 28 second store page
video (storyboard in the project library, Animation-Engineer/trailer/storyboard.md). It is the game's own day
theme, so the video sounds like the game: the same tune and chords as music.py's DayA, at 120 BPM with a fuller
kit. Nothing here is uploaded to Roblox or played in the game; it is only mixed into the video.

At 120 BPM a bar is exactly 2 seconds, so every section starts on an even second and the edit can cut to it:

  0 to 2 s    intro: piano on the C7 that leads home, shaker and a cymbal swell
  2 to 18 s   the groove: kick, clap, hats, walking bass, the vibraphone tune (glockenspiel joins at 10 s)
  18 to 20 s  a break: two stop hits, then a snare build, room for the check-in sound
  20 to 26 s  the cafe: brushes and the tune on a music box, warm and lighter
  26 to 28 s  the end chord with a glockenspiel sparkle as the logo comes up, ringing out by 28 s

Every note is synthesized with fixed seeds, so the cue is original and the same on every run. Outputs (overwritten):
OUT_DIR/CatCafe_Trailer_Music_28s.wav (stereo, 48 kHz, 16 bit, about -16 LUFS) and a .mp3 preview beside it.
Needs numpy and ffmpeg.
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np

import music  # same folder
from music import (
    chord, epiano, glock, kick, melody, music_box, noise_hit, note, release, seconds, strings, upright,
    vibraphone, write_wav,
)
from synth import SR  # same folder

BPM = 120
BARS = 14  # 28 s
LENGTH = 28.0
PAD = 4.0  # silence after the end so the room's echo never wraps onto the start
TARGET_LUFS = -16.0


class Timeline(music.Song):
    """music.Song with a fixed length plus padding, so nothing placed near the end wraps to the start."""

    def __init__(self, seed: int, swing: float):
        self.beat = 60.0 / BPM
        self.meter = 4
        self.swing = swing
        self.n = int((LENGTH + PAD) * SR)
        self.rng = np.random.default_rng(seed)


# DayA's eight bars: bass root, bass fifth, the note leading to the next root, the voicing
PROGRESSION = [
    ("F2", "C3", "E2", "A3 C4 E4 G4"),
    ("A2", "E3", "A2", "G3 A3 C4 E4"),
    ("Bb2", "F2", "B2", "A3 Bb3 D4 F4"),
    ("C3", "G2", "E2", "Bb3 C4 E4 G4"),
    ("F2", "C3", "C#3", "A3 C4 E4 G4"),
    ("D3", "A2", "F#2", "F3 A3 C4 E4"),
    ("G2", "D3", "B2", "F3 A3 Bb3 D4"),
    ("C3", "G2", "E2", "E3 G3 Bb3 D4"),
]
TUNE = melody("0 0 1 C5; 0 1 1 A4; 0 2 0.5 G4; 0 2.5 1.5 A4;"
              "1 0 1.5 E5; 1 1.5 0.5 D5; 1 2 2 C5;"
              "2 0 1 D5; 2 1 0.5 C5; 2 1.5 0.5 Bb4; 2 2 1 A4; 2 3 1 F4;"
              "3 0 2 G4; 3 2 1 Bb4; 3 3 0.5 A4; 3 3.5 0.5 G4;"
              "4 0 1.5 A4; 4 1.5 0.5 C5; 4 2 1 F5; 4 3 1 E5;"
              "5 0 1.5 D5; 5 1.5 0.5 C5; 5 2 2 A4;"
              "6 0 1 Bb4; 6 1 0.5 A4; 6 1.5 0.5 G4; 6 2 1.5 D5; 6 3.5 0.5 C5;"
              "7 0 2 C5; 7 2 0.5 Bb4; 7 2.5 0.5 A4; 7 3 1 G4")


def clap(seed: int) -> np.ndarray:
    """A soft clap: three quick bursts of band-limited noise and a short tail."""
    x = np.zeros(int(0.25 * SR))
    for k, at in enumerate((0.0, 0.009, 0.019)):
        burst = noise_hit(seed + k, 0.2, 900, 4200, 0.0006, 0.008 if k < 2 else 0.05)
        start = int(at * SR)
        end = min(len(x), start + len(burst))
        x[start:end] += burst[: end - start] * (0.7 if k < 2 else 1.0)
    return x


def swell(d: float, seed: int) -> np.ndarray:
    """A cymbal swell: bright noise rising into the downbeat."""
    t = seconds(d)
    x = noise_hit(seed, d, 4000, 14000, d, 1e9)
    return x * (t / d) ** 2.5


def build(tmp: Path) -> np.ndarray:
    s = Timeline(seed=31, swing=0.05)
    keys, bass, lead, kit, pad = s.stem(), s.stem(), s.stem(), s.stem(), s.stem()

    def comp(bar: int, voicing: str, soft: float = 1.0) -> None:
        for i, f in enumerate(chord(voicing)):
            s.put(keys, epiano(0.9, f, 0.7 * soft), bar, 0.0, pan=-0.3 + 0.2 * i, loose=0.003)
            s.put(keys, epiano(0.4, f, 0.5 * soft), bar, 1.5, pan=-0.3 + 0.2 * i, loose=0.003)
            s.put(keys, epiano(0.9, f, 0.55 * soft), bar, 2.5, pan=-0.3 + 0.2 * i, loose=0.003)

    # 0 to 2 s: the C7 that leads home, a shaker and a swell into the groove
    comp(0, PROGRESSION[7][3], soft=0.8)
    s.put(bass, upright(0.9, note("C3"), 0.8), 0, 0.0)
    s.put(bass, upright(0.4, note("G2"), 0.7), 0, 2.0)
    s.put(bass, upright(0.4, note("E2"), 0.7), 0, 3.5)
    for k in range(8):
        s.put(kit, noise_hit(700 + k, 0.1, 5000, 11000, 0.006, 0.03), 0, k * 0.5, pan=0.4, gain=0.25 + 0.04 * k)
    s.put(kit, swell(2.0, 790), 0, 0.0, pan=-0.2, gain=0.25, loose=0)
    for k, name in enumerate(("G5", "Bb5", "C6")):  # a three-note pickup into the tune
        s.put(lead, glock(note(name)) * 0.4, 0, 2.5 + 0.5 * k, pan=0.3)

    # 2 to 18 s: the groove, the tune on vibraphone; the glockenspiel doubles it for the second half
    for i in range(8):
        bar = 1 + i
        root, fifth, lead_in, voicing = PROGRESSION[i]
        comp(bar, voicing)
        s.put(bass, upright(0.45, note(root), 1.0), bar, 0.0)
        s.put(bass, upright(0.4, note(root), 0.7), bar, 1.0)
        s.put(bass, upright(0.45, note(fifth), 0.9), bar, 2.0)
        s.put(bass, upright(0.35, note(lead_in), 0.75), bar, 3.0)
        s.put(bass, upright(0.2, note(lead_in) * 2, 0.4), bar, 3.5)
        for beat in range(4):
            if beat in (0, 2):
                s.put(kit, kick(), bar, beat, gain=0.9)
            else:
                s.put(kit, clap(bar * 8 + beat), bar, beat, pan=-0.05, gain=0.6)
            for half in (0.0, 0.5):
                gain = 0.4 if half else 0.28
                s.put(kit, noise_hit(bar * 16 + beat * 2 + int(half * 2), 0.09, 6000, 12000, 0.002, 0.025),
                      bar, beat + half, pan=0.35, gain=gain)
        if i == 3 or i == 7:  # a ghost kick pushes into the next phrase
            s.put(kit, kick(), bar, 3.5, gain=0.5)
        for b, beat, length, f in TUNE:
            if b == i:
                s.put(lead, vibraphone(length * s.beat, f), bar, beat, pan=0.1)
                if i >= 4:
                    s.put(lead, glock(f * 2) * 0.22, bar, beat, pan=0.25)

    # 18 to 20 s: the break. Two stop hits on the C7, then a snare build into the cafe.
    stop = PROGRESSION[3][3]
    for beat in (0.0, 1.5):
        for i, f in enumerate(chord(stop)):
            s.put(keys, epiano(0.35, f, 0.8), 9, beat, pan=-0.3 + 0.2 * i, loose=0.002)
        s.put(bass, upright(0.35, note("C3"), 1.0), 9, beat)
        s.put(kit, kick(), 9, beat, gain=0.8)
        s.put(kit, clap(900 + int(beat * 2)), 9, beat, gain=0.45)
    for k in range(8):
        step = 2.0 + k * 0.25
        s.put(kit, noise_hit(950 + k, 0.12, 1200, 5000, 0.002, 0.04), 9, step, pan=-0.1, gain=0.18 + 0.05 * k)
    s.put(kit, swell(1.0, 990), 9, 3.0, pan=0.2, gain=0.3, loose=0)

    # 20 to 26 s: the cafe. Brushes, softer piano, the opening of the tune on a music box over F, Dm, Gm then C.
    cafe = [("F2", "C3", "A3 C4 E4 G4"), ("D3", "A2", "F3 A3 C4 E4"), ("G2", "C3", "F3 A3 Bb3 D4")]
    for i, (root, fifth, voicing) in enumerate(cafe):
        bar = 10 + i
        comp(bar, voicing, soft=0.75)
        s.put(bass, upright(1.4, note(root), 0.85), bar, 0.0)
        s.put(bass, upright(1.2, note(fifth), 0.7), bar, 2.0)
        for beat in range(4):
            s.put(kit, noise_hit(1000 + bar * 8 + beat, 0.35, 2500, 9000, 0.03, 0.09), bar, beat, pan=0.2,
                  gain=0.35)
            if beat in (1, 3):
                s.put(kit, noise_hit(1100 + bar * 8 + beat, 0.2, 1200, 5000, 0.002, 0.05), bar, beat, pan=-0.1,
                      gain=0.6)
        s.put(pad, strings(3.6, chord(voicing), 1200 + i), bar, 0.0)
        for b, beat, length, f in TUNE:
            if b == i:
                s.put(lead, music_box(f * 2) * 0.85, bar, beat, pan=0.15)
    for i, f in enumerate(chord("Bb3 C4 E4 G4")):  # the last bar's second half turns to C7 for the ending
        s.put(keys, epiano(0.8, f, 0.5), 12, 2.5, pan=-0.3 + 0.2 * i, loose=0.003)
    s.put(lead, glock(note("G5")) * 0.3, 12, 3.0, pan=0.3)
    s.put(lead, glock(note("A5")) * 0.3, 12, 3.5, pan=0.3)

    # 26 to 28 s: the end chord with the logo, a glockenspiel sparkle, ringing out by 28 s
    end = chord("F3 A3 C4 E4 G4")
    for i, f in enumerate(end):
        s.put(keys, epiano(1.6, f, 0.85), 13, 0.0, pan=-0.3 + 0.15 * i, loose=0.003)
        s.put(lead, release(vibraphone(1.4, f * 2), 1.5, 0.4) * 0.3, 13, 0.0, pan=0.1, loose=0.003)
    s.put(pad, strings(1.6, end, 1300), 13, 0.0)
    s.put(bass, upright(1.6, note("F2"), 1.0), 13, 0.0)
    s.put(bass, upright(1.6, note("F2") / 2, 0.6), 13, 0.0)
    s.put(kit, kick(), 13, 0.0, gain=0.9)
    s.put(kit, noise_hit(1400, 1.8, 3000, 12000, 0.004, 0.6), 13, 0.0, pan=-0.2, gain=0.35)
    for k, name in enumerate(("C6", "F6", "A6", "C7")):
        s.put(lead, glock(note(name)) * 0.35, 13, 0.5 + 0.25 * k, pan=0.35 - 0.1 * k)

    music.TARGET_LUFS = TARGET_LUFS
    mix = music.blend({"lead": (lead, -20, 0.3), "keys": (keys, -22, 0.2), "bass": (bass, -22, 0.05),
                       "kit": (kit, -24, 0.12), "pad": (pad, -30, 0.3)}, 131, tmp)
    mix = mix[: int(LENGTH * SR)]
    fade = int(0.35 * SR)
    mix[-fade:] *= np.linspace(1, 0, fade)[:, None] ** 2
    return mix


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as folder:
        mix = build(Path(folder))
    wav = out / "CatCafe_Trailer_Music_28s.wav"
    write_wav(wav, mix)
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(wav), "-b:a", "192k",
                    str(wav.with_suffix(".mp3"))], check=True)
    print(f"{wav}  {len(mix) / SR:.2f} s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
