#!/usr/bin/env python3
"""Purr Pot audio gate: measures every audio file and writes a PASS/WARN/FAIL table.

The sound-designer cannot listen, so this reports what can be measured: format, size,
duration, sample rate, channels, integrated loudness, true peak, leading silence and
whether a loop's seam is likely to click. Budgets come from audio-pipeline section 5.

Usage (from the repo root):
    python .claude/skills/audio-pipeline/scripts/audio_gate.py [ROOT] [--out FILE]

ROOT defaults to assets/cat-cafe/audio and the report to ROOT/gates.md. The kind of each
file comes from its folder (music, ambience, sfx, ui). Needs ffmpeg and ffprobe on PATH.
Exit code 1 when any file FAILs, 2 when ffmpeg is missing.
"""

from __future__ import annotations

import argparse
import array
import json
import math
import re
import shutil
import subprocess
import sys
from pathlib import Path

EXTENSIONS = {".ogg", ".mp3", ".wav", ".flac"}
MAX_BYTES = 20 * 1024 * 1024  # Roblox upload limit
MAX_SECONDS = 7 * 60  # Roblox upload limit
MAX_RATE = 48000  # Roblox upload limit
NAME = re.compile(r"^CatCafe_(Music|Amb|Sfx|Ui)_[A-Z][A-Za-z0-9]*(_[A-Za-z0-9]+)*$")
SILENCE = 10 ** (-60 / 20)  # -60 dBFS

# kind: (min s, max s, mono required, loudness target LUFS or None, peak ceiling dBTP, max lead ms, loops)
BUDGETS = {
    "music": (30.0, 240.0, False, -18.0, -1.0, None, True),
    "ambience": (20.0, 120.0, False, -26.0, -3.0, None, True),
    "sfx": (0.05, 4.0, True, None, -1.0, 20, False),
    "ui": (0.02, 1.5, True, None, -1.0, 10, False),
}
LOUDNESS_TOLERANCE = 3.0
FOLDER_KIND = {"music": "music", "ambience": "ambience", "amb": "ambience", "sfx": "sfx", "ui": "ui"}


def run(args: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(args, capture_output=True, check=False)


def probe(path: Path) -> dict:
    out = run(
        [
            "ffprobe", "-v", "error", "-select_streams", "a:0",
            "-show_entries", "stream=sample_rate,channels:format=duration,size",
            "-of", "json", str(path),
        ]
    )
    data = json.loads(out.stdout or b"{}")
    stream = (data.get("streams") or [{}])[0]
    fmt = data.get("format") or {}
    return {
        "rate": int(stream.get("sample_rate") or 0),
        "channels": int(stream.get("channels") or 0),
        "seconds": float(fmt.get("duration") or 0.0),
        "bytes": int(fmt.get("size") or path.stat().st_size),
    }


def loudness(path: Path) -> tuple[float | None, float | None]:
    """Integrated loudness (LUFS) and true peak (dBTP) from ffmpeg's ebur128 filter."""
    out = run(
        ["ffmpeg", "-nostats", "-hide_banner", "-i", str(path),
         "-filter_complex", "ebur128=peak=true", "-f", "null", "-"]
    )
    text = out.stderr.decode("utf-8", "replace")
    summary = text[text.rfind("Summary:"):] if "Summary:" in text else text
    i = re.search(r"I:\s+(-?[\d.]+|-inf) LUFS", summary)
    p = re.search(r"Peak:\s+(-?[\d.]+|-inf) dBFS", summary)

    def num(m: re.Match | None) -> float | None:
        if not m:
            return None
        return -math.inf if m.group(1) == "-inf" else float(m.group(1))

    return num(i), num(p)


def samples(path: Path, extra: list[str]) -> array.array:
    """Mono 48 kHz float samples for a slice of the file (extra = ffmpeg seek/length args)."""
    out = run(
        ["ffmpeg", "-v", "error", *extra, "-i", str(path), "-t", "0.05" if "-sseof" in extra else "1",
         "-ac", "1", "-ar", "48000", "-f", "f32le", "-"]
    )
    buf = array.array("f")
    buf.frombytes(out.stdout[: len(out.stdout) // 4 * 4])
    return buf


def lead_ms(path: Path) -> float:
    head = samples(path, [])
    for index, value in enumerate(head):
        if abs(value) > SILENCE:
            return index / 48.0
    return len(head) / 48.0


def rms_db(buf: array.array) -> float:
    if not buf:
        return -math.inf
    mean = sum(v * v for v in buf) / len(buf)
    return 10 * math.log10(mean) if mean > 0 else -math.inf


def seam(path: Path) -> str | None:
    """None when the loop seam looks clean, else a reason to listen to it."""
    head = samples(path, [])[:2400]  # first 50 ms
    tail = samples(path, ["-sseof", "-0.05"])
    if not head or not tail:
        return "could not read the ends"
    jump = abs(tail[-1] - head[0])
    if jump > 0.1:
        return f"sample jump {jump:.2f} at the seam (likely click)"
    a, b = rms_db(head), rms_db(tail)
    if math.isinf(a) != math.isinf(b) or (not math.isinf(a) and abs(a - b) > 6):
        return f"level changes {a:.0f} -> {b:.0f} dB across the seam (fade or gap)"
    return None


def kind_of(path: Path, root: Path) -> str | None:
    for part in path.relative_to(root).parts[:-1]:
        if part.lower() in FOLDER_KIND:
            return FOLDER_KIND[part.lower()]
    return None


def fmt(value: float | None, digits: int = 1) -> str:
    if value is None:
        return "-"
    if math.isinf(value):
        return "-inf"
    return f"{value:.{digits}f}"


def fmt_lufs(value: float | None) -> str:
    # ebur128 reports -70 (its gate) for files too short or too quiet to measure
    return "-" if value is None or value <= -69.9 else fmt(value)


def check(path: Path, root: Path) -> dict:
    kind = kind_of(path, root)
    info = probe(path)
    fails: list[str] = []
    warns: list[str] = []
    row = {"file": path.relative_to(root).as_posix(), "kind": kind or "?", **info,
           "lufs": None, "peak": None, "lead": None, "seam": "-"}

    if not NAME.match(path.stem):
        fails.append("name is not CatCafe_<Bus>_<Name> (Bus: Music, Amb, Sfx, Ui)")
    if info["bytes"] >= MAX_BYTES:
        fails.append("20 MB or larger")
    if info["seconds"] >= MAX_SECONDS:
        fails.append("7 minutes or longer")
    if info["rate"] > MAX_RATE:
        fails.append(f"sample rate {info['rate']} above 48000")
    if kind is None:
        fails.append("not under music/, ambience/, sfx/ or ui/")
        return {**row, "verdict": "FAIL", "notes": "; ".join(fails)}

    low, high, mono, target, ceiling, max_lead, loops = BUDGETS[kind]
    if not low <= info["seconds"] <= high:
        warns.append(f"{info['seconds']:.2f} s outside {low}-{high} s")
    if mono and info["channels"] != 1:
        fails.append(f"{info['channels']} channels, {kind} must be mono")

    lufs, peak = loudness(path)
    row["lufs"], row["peak"] = lufs, peak
    if peak is not None and peak > ceiling:
        fails.append(f"true peak {peak:.1f} above {ceiling:.0f} dBTP")
    if target is not None and lufs is not None and abs(lufs - target) > LOUDNESS_TOLERANCE:
        warns.append(f"loudness {fmt_lufs(lufs)} LUFS, target {target:.0f} +/- {LOUDNESS_TOLERANCE:.0f}")

    if max_lead is not None:
        row["lead"] = lead_ms(path)
        if row["lead"] > max_lead:
            fails.append(f"{row['lead']:.0f} ms of silence before the sound (max {max_lead})")
    if loops:
        problem = seam(path)
        row["seam"] = "ok" if problem is None else "listen"
        if problem:
            warns.append(problem)

    verdict = "FAIL" if fails else "WARN" if warns else "PASS"
    return {**row, "verdict": verdict, "notes": "; ".join(fails + warns)}


def report(rows: list[dict], root: Path) -> str:
    counts = {v: sum(r["verdict"] == v for r in rows) for v in ("PASS", "WARN", "FAIL")}
    lines = [
        "# Audio gate",
        "",
        f"Written by `.claude/skills/audio-pipeline/scripts/audio_gate.py` for `{root.as_posix()}`. "
        "Do not edit by hand; rerun the script. Budgets: audio-pipeline section 5. "
        "PASS means measured clean, not that it sounds right: Derek or Gavin still listens.",
        "",
        f"{len(rows)} files: {counts['PASS']} PASS, {counts['WARN']} WARN, {counts['FAIL']} FAIL.",
        "",
        "| file | kind | s | ch | Hz | KB | LUFS | peak dBTP | lead ms | seam | verdict | notes |",
        "|---|---|---|---|---|---|---|---|---|---|---|---|",
    ]
    for r in rows:
        lines.append(
            f"| `{r['file']}` | {r['kind']} | {r['seconds']:.2f} | {r['channels']} | {r['rate']} | "
            f"{r['bytes'] // 1024} | {fmt_lufs(r['lufs'])} | {fmt(r['peak'])} | {fmt(r['lead'], 0)} | "
            f"{r['seam']} | {r['verdict']} | {r['notes']} |"
        )
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("root", nargs="?", default="assets/cat-cafe/audio")
    parser.add_argument("--out", help="report path (default ROOT/gates.md)")
    args = parser.parse_args()

    if not (shutil.which("ffmpeg") and shutil.which("ffprobe")):
        print("audio_gate: ffmpeg and ffprobe must be on PATH (Windows: winget install Gyan.FFmpeg)", file=sys.stderr)
        return 2
    root = Path(args.root)
    if not root.is_dir():
        print(f"audio_gate: {root.as_posix()} is not a folder", file=sys.stderr)
        return 2
    files = sorted(p for p in root.rglob("*") if p.suffix.lower() in EXTENSIONS and p.is_file())
    rows = [check(p, root) for p in files]
    out = Path(args.out) if args.out else root / "gates.md"
    out.write_text(report(rows, root), encoding="utf-8")
    for r in rows:
        print(f"{r['verdict']:4}  {r['file']}  {r['notes']}")
    print(f"audio_gate: {len(rows)} files, report in {out.as_posix()}")
    return 1 if any(r["verdict"] == "FAIL" for r in rows) else 0


if __name__ == "__main__":
    sys.exit(main())
