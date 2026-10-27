"""Upload Cat Cafe's audio files to Roblox and write their ids into the game.

Run from the repo root on your own PC (never in a shared or cloud machine with your key):

    export ROBLOX_API_KEY=...            # PowerShell: $env:ROBLOX_API_KEY = "..."
    export ROBLOX_CREATOR_USER_ID=...    # or ROBLOX_CREATOR_GROUP_ID when a Group owns the game
    python assets/cat-cafe/audio/upload.py [--dry-run] [--only CatCafe_Sfx_NetSwing,...]

What it does, for every upload-ready .ogg under assets/cat-cafe/audio/{ui,sfx,music,ambience}
that is not in uploaded.json yet, P0 sounds first:
  1. uploads it with the Open Cloud Assets API (asset type Audio, private to the creator),
  2. waits for the asset id and records it in assets/cat-cafe/audio/uploaded.json at once,
  3. at the end writes "rbxassetid://<id>" into the cue's ids in
     games/cat-cafe/src/client/Audio/Cues.luau and the "uploaded id" column of the sources log,
     then runs stylua on Cues.luau if it is on PATH.
A rerun skips what is already uploaded, so it is safe to stop and start again (for example
after hitting the monthly upload limit). Commit the changed files on a branch afterwards.

The API key: Creator Dashboard > Open Cloud > API Keys > Create API Key, add the Assets API with
Read and Write, allow your IP. The key stays in the environment variable, never in a file or chat.
Uploaded audio goes through Roblox moderation; an id can take a few minutes before it plays.
Only the Python standard library is needed.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

AUDIO = Path(__file__).resolve().parent  # assets/cat-cafe/audio
REPO = AUDIO.parents[2]
CUES = REPO / "games" / "cat-cafe" / "src" / "client" / "Audio" / "Cues.luau"
LOG = AUDIO / "README.md"
RECORD = AUDIO / "uploaded.json"
API = "https://apis.roblox.com/assets/v1"
FOLDERS = ("ui", "sfx", "music", "ambience")
CONTENT_TYPES = {".ogg": "audio/ogg", ".mp3": "audio/mpeg", ".wav": "audio/wav", ".flac": "audio/flac"}
# Uploaded first, so a small monthly allowance still covers the playtest essentials (sound list P0).
PRIORITY = (
    "uiClick", "uiError", "netSwing", "circlePerfect", "circleGood", "circleMiss", "catchSparkle",
    "catchMiss", "catHiss", "straySprint", "purrfectChime", "coinPop", "purchase", "checkInBell", "jingleCatFound",
    "ambCafeDay", "ambAlleyNight", "loopCafeDoor", "jingleRankUp", "shuttersUp", "gateOpen", "announce",
    "catchStart", "circleAppear", "ambAlleyDay", "ambCafeNight", "carryPurr", "purr", "signFlip", "strayFlee",
    "shove", "bumpHeld", "holdFill", "zoneArea", "zoneSafe", "travelPoof", "catDrop", "goldReveal", "shimmerRare",
    "giftClaim", "indexReward", "catPlaced", "catRest", "uiSlider", "uiGiftReady", "uiBadge", "wheelTick", "wheelWin",
)


def cue_for(stem: str) -> str:
    """CatCafe_Ui_Click -> uiClick, CatCafe_Amb_CafeDay -> ambCafeDay, CatCafe_Amb_LoopCafeDoor -> loopCafeDoor,
    CatCafe_Sfx_NetSwing -> netSwing."""
    _, bus, name = stem.split("_", 2)
    name = name.replace("_", "")
    if bus == "Ui":
        return "ui" + name
    if bus == "Amb":
        return "loop" + name[4:] if name.startswith("Loop") else "amb" + name
    return name[0].lower() + name[1:]


def files() -> list[Path]:
    found = [p for folder in FOLDERS for p in sorted((AUDIO / folder).glob("CatCafe_*.ogg"))]
    rank = {cue: i for i, cue in enumerate(PRIORITY)}
    return sorted(found, key=lambda p: rank.get(cue_for(p.stem), len(rank)))


def request(method: str, url: str, key: str, body: bytes | None = None, content_type: str | None = None) -> dict:
    headers = {"x-api-key": key}
    if content_type:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(url, data=body, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            return json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")[:400]
        raise RuntimeError(f"HTTP {error.code}: {detail}") from None


def upload(path: Path, key: str, creator: dict) -> tuple[str, str]:
    meta = {
        "assetType": "Audio",
        "displayName": path.stem[:50],
        "description": "Cat Cafe sound effect or ambience, original (made for the game).",
        "creationContext": {"creator": creator},
    }
    boundary = uuid.uuid4().hex
    body = b"".join([
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n"
        f"Content-Type: application/json\r\n\r\n{json.dumps(meta)}\r\n".encode(),
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{path.name}\"\r\n"
        f"Content-Type: {CONTENT_TYPES[path.suffix]}\r\n\r\n".encode(),
        path.read_bytes(),
        f"\r\n--{boundary}--\r\n".encode(),
    ])
    operation = request("POST", f"{API}/assets", key, body, f"multipart/form-data; boundary={boundary}")
    path_id = operation.get("path", "")
    for _ in range(90):  # up to about three minutes
        if operation.get("done"):
            result = operation.get("response", {})
            moderation = (result.get("moderationResult") or {}).get("moderationState", "unknown")
            return str(result["assetId"]), moderation
        time.sleep(2)
        operation = request("GET", f"{API}/{path_id}", key)
    raise RuntimeError(f"no asset id after waiting ({path_id})")


def write_cues(uploaded: dict[str, str]) -> list[str]:
    text = CUES.read_text(encoding="utf-8")
    changed = []
    for file, asset_id in uploaded.items():
        cue = cue_for(Path(file).stem)
        pattern = re.compile(rf"(^\t{re.escape(cue)} = \{{\s*ids = )\{{[^}}]*\}}", re.M)
        text, count = pattern.subn(rf'\g<1>{{ "rbxassetid://{asset_id}" }}', text)
        if count:
            changed.append(cue)
        else:
            print(f"upload: no cue named {cue} in Cues.luau for {file}; add one", file=sys.stderr)
    CUES.write_text(text, encoding="utf-8", newline="\n")
    stylua = shutil.which("stylua")
    if stylua:
        subprocess.run([stylua, str(CUES)], check=False)
    else:
        print("upload: stylua is not on PATH; run it on Cues.luau before committing (cd games/cat-cafe; stylua src)")
    return changed


def write_log(uploaded: dict[str, str]) -> None:
    lines = LOG.read_text(encoding="utf-8").splitlines()
    for i, line in enumerate(lines):
        for file, asset_id in uploaded.items():
            if line.startswith("| ") and f"`{file}`" in line:
                cells = line.split(" | ")
                if len(cells) >= 8:
                    cells[6] = asset_id
                    lines[i] = " | ".join(cells)
    LOG.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true", help="list what would be uploaded, upload nothing")
    parser.add_argument("--only", help="comma list of file names without .ogg")
    args = parser.parse_args()

    uploaded: dict[str, str] = json.loads(RECORD.read_text()) if RECORD.exists() else {}
    todo = [p for p in files() if p.relative_to(AUDIO).as_posix() not in uploaded]
    if args.only:
        wanted = {n.strip() for n in args.only.split(",")}
        todo = [p for p in todo if p.stem in wanted]
    if args.dry_run or not todo:
        for p in todo:
            print(f"would upload  {p.relative_to(AUDIO).as_posix():45}  -> cue {cue_for(p.stem)}")
        print(f"upload: {len(todo)} to upload, {len(uploaded)} already uploaded")
        return 0

    key = os.environ.get("ROBLOX_API_KEY")
    user, group = os.environ.get("ROBLOX_CREATOR_USER_ID"), os.environ.get("ROBLOX_CREATOR_GROUP_ID")
    needed = (("ROBLOX_API_KEY", key), ("ROBLOX_CREATOR_USER_ID", user or group))
    missing = [name for name, value in needed if not value]
    if missing:
        print(f"upload: {' and '.join(missing)} not set in this terminal window (a variable lasts only for the "
              "window it was set in); a group key uses ROBLOX_CREATOR_GROUP_ID instead of the user id", file=sys.stderr)
        return 2
    creator = {"groupId": group} if group else {"userId": user}

    failed = None
    for p in todo:
        name = p.relative_to(AUDIO).as_posix()
        try:
            asset_id, moderation = upload(p, key, creator)
        except RuntimeError as error:
            failed = f"{name}: {error}"
            break  # usually the monthly limit or a key permission; a rerun continues from here
        uploaded[name] = asset_id
        RECORD.write_text(json.dumps(uploaded, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(f"uploaded  {name:45}  rbxassetid://{asset_id}  ({moderation})")

    changed = write_cues(uploaded)
    write_log(uploaded)
    print(f"upload: {len(changed)} cues have ids in Cues.luau; record in {RECORD.relative_to(REPO).as_posix()}")
    if failed:
        print(f"upload: stopped at {failed}", file=sys.stderr)
        if "unauthorized to create" in failed:
            print("upload: the creator id must be the key owner's: your Roblox user id from your profile URL, "
                  "or a group id with ROBLOX_CREATOR_GROUP_ID for a group key", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
