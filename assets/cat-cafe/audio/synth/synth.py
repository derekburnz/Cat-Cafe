"""Synthesize Purr Pot's own sound effects: UI, net circles, catch results, coins, the door bell, jingles.

Run from the repo root:  python assets/cat-cafe/audio/synth/synth.py [--only CirclePerfect,CoinPop]
                                                                  [--preview DIR]

Every sound is made from sine partials and filtered noise with fixed seeds, so the files are
original (no samples) and the same on every run. Outputs (overwritten):
  assets/cat-cafe/audio/ui/CatCafe_Ui_<Name>.ogg and sfx/CatCafe_Sfx_<Name>.ogg (mono, 48 kHz),
  music/CatCafe_Music_Jingle<Name>.ogg (the same sound on both channels; the music channel is stereo)
  with --preview: DIR/purr-pot-sfx-preview.mp3, every sound in turn, then a five-circle Perfect
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
    out = folder / "purr-pot-sfx-preview.mp3"
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
