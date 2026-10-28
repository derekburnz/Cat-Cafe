---
name: merge-and-publish
description: How a Cat Cafe thread hands a finished PR to GitHub auto-merge (or the automerge label) instead of waiting on CI, and how to publish the game to Roblox from GitHub Actions without Studio. Use when a PR is reviewed and ready, when Derek asks to "send it to Roblox", publish or playtest the live game, when a thread needs an image uploaded to Roblox or wants to read the in-game bug reports, or when an automerge comment or publish run fails.
---

# Merge and publish

GitHub Actions takes the waiting out of the pipeline. The workflows live in the repo, so they work the same from a cloud thread, the laptop or Derek's phone.

## 1. Queue a merge: GitHub auto-merge first, the `automerge` label as fallback

Project rule (Derek, 2026-10-26): a thread merges its own PR once CI is green on a head that includes the latest main and the review findings are addressed. Since 2026-10-27 22:02 Derek wants GitHub's own auto-merge on every PR ("turned on allow auto merge on github so turn on for all future prs"). It waits for main's required checks (the ruleset in docs/setup-guide.md step 18): `Rojo sourcemap, luau-lsp, Selene, StyLua` and `Luau unit tests and strict type check (WebAssembly Luau)`.

1. Queue only a PR you would merge by hand right now apart from CI: the luau-reviewer's findings are addressed (or the PR is docs or assets only), its test plan is written, it targets `main`, it is not a draft.
2. Turn auto-merge on with the GitHub MCP tool `enable_pr_auto_merge`: owner `derekburnz`, repo `Cat-Cafe`, the PR number, `mergeMethod: "MERGE"` (a merge commit, like every merge on main so far; never squash or rebase). From a shell with gh: `gh pr merge <n> --auto --merge`. Turning it on starts a fresh check run against the main of that moment (`auto_merge_enabled` in check.yml), and GitHub merges as soon as both required checks pass on it. The merge counts as Derek's, so the check run on main and `AUTO_PUBLISH` follow as usual.
3. End your turn. A failed check leaves auto-merge on: push the fix and it merges once the new run passes. A push to the branch keeps it on. A merge conflict blocks it; merge main in by hand, resolve and push.
4. When the tool refuses, add the `automerge` label instead (`issue_write` with `method: "update"`, the PR number and `labels: ["automerge"]`, keeping labels already on the PR). That happens when the PR is already green ("clean status", nothing left to wait for). Main has had its required checks since 2026-10-27 22:14 (step 18), so a refusal that says main has none, or any other reason, means a setting changed: label the PR and tell the tools thread. The label runs `.github/scripts/automerge.sh`: CI on the PR merged with the latest main, then a merge commit when it passes; when main moved during the run it checks again with the new main merged in. Nothing is pushed to the branch.
5. Label path only: a failed check leaves the label on, so the next green run merges. A conflict with main, or a merge GitHub refuses, takes the label off with a PR comment, which wakes your PR subscription. Fix it by hand, then add the label again. Labeled, green and still open after a few minutes? Open the newest "Merge if labeled automerge" job log on the PR's checks; its last lines say what it did. Taking the label off and putting it back starts it again.

Every check run tests the PR merged with main (`.github/scripts/merge-main.sh`; the "Merge main in (not pushed)" step names the main commit). Until 2026-10-27 the label script pushed main into the branch instead; each of those pushes emailed Derek. A branch made before that change still updates the old way until main is merged into it.

Both required checks must report on every PR, or auto-merge waits forever. So never put `paths` or `paths-ignore` on check.yml's `pull_request` trigger, and never change the `name:` of the `gate` or `cloudcheck` job (the ruleset matches those names) without changing the ruleset with it. A job skipped by its own `if:` counts as passed, so that is the way to skip work on docs-only PRs.

A PR that changes `.github/workflows/` takes auto-merge like any other. The label path cannot merge it (the workflow token may not), so if auto-merge is refused there, merge it by hand with MCP `merge_pull_request` (`merge_method: "merge"`) once it is green. Report the merge to Derek in one line either way.

## 2. Publish to Roblox without Studio

`.github/workflows/publish.yml` builds `default.project.json` with Rojo (no test scripts), uploads it as a Saved version, runs the engine smoke test (`games/cat-cafe/tools/opencloud/Smoke.luau`: every shared and server module loads and the world builds in a real Roblox server), then publishes it live.

- Start it: GitHub MCP `actions_run_trigger` with `method: "run_workflow"`, `workflow_id: "publish.yml"`, `ref: "main"`, `inputs: {"version_type": "Published"}` (or `"Saved"` to add a version without going live). Derek can press Run workflow on the Actions tab.
- Publishing makes a new version live for players, so start it only when Derek asked for a publish (or he turned on `AUTO_PUBLISH`). Tell him the version number from the run summary.
- It needs the repo secret `ROBLOX_PUBLISH_KEY` (docs/setup-guide.md step 15). A missing secret fails the first step with that message; a 401 or 403 means the key lacks a permission or its IP list blocks GitHub.
- A failing smoke test stops the run before the live publish (the Saved version it tested stays in the place history and never goes live). It first passed on Roblox on 2026-10-27; its log line reads `[CatCafe] engine smoke ok ...` with module, plot and placeholder counts.
- Running servers keep their old version; new servers start on the new one. Roll back from Creator Dashboard > the place > Version History.
- When the publish changes the save version (a PR it carries raises `ProfileSchema.VERSION` in `src/shared/ProfileSchema.luau`), add `"restart_servers": true` to the inputs. After going live the run moves every running server onto the new version (`tools/opencloud/restart-servers.sh`, the same as Creator Hub's Restart servers for updates); otherwise a player saved by a new server who joins an old one is kicked by the newer-save guard. It needs universe Write on the key (docs/setup-guide.md step 19). Without it, or when that step fails, tell Derek to press Creator Hub > the experience > ... > Restart servers for updates right after the publish.
- Open Cloud cannot update unions, SurfaceAppearance, EditableMesh, EditableImage or layered clothing; the place has none today (Parts, WedgeParts, SpecialMeshes). If assets start using them, publish those changes from Studio.

The same scripts run from Git Bash on a PC with the key in the environment: `cd games/cat-cafe && tools/opencloud/publish.sh Published`.

## 3. Upload an image or sounds, read the bug reports

Three more workflows use the same key (`ROBLOX_PUBLISH_KEY`, with the permissions from docs/setup-guide.md step 17). A 401 or 403 means Derek has not added them yet; tell him step 17 instead of retrying.

- **Upload an image** (UI textures, icons, decals): `actions_run_trigger` with `method: "run_workflow"`, `workflow_id: "upload-image.yml"`, `ref: "main"`, `inputs: {"path": "assets/cat-cafe/ui/textures/UI_ButtonTiles.png", "branch": "ui/game-buttons"}` (`branch` only when the file is not on main yet; optional `name`, and `type` `Image` or `Decal`). Read the job log with `get_job_logs`: the line `Uploaded <path> as Image <id>: rbxassetid://<id>` has the id, and the run summary repeats it. `Image` ids go straight into `ImageLabel.Image`, `ImageButton.Image` and textures; `Decal` is only for putting the picture on a part from the Toolbox. Each run makes a new asset on Derek's account, so upload a file once and commit its id next to the code that uses it. Roblox moderates every image; until it is approved it draws blank. Only upload our own art (studio rule 8).
- **Upload sounds** (sound-designer): `workflow_id: "upload-audio.yml"`, `ref: "main"`, `inputs: {"branch": "<your branch>"}` (optional `only`: file names without `.ogg`, comma separated; `"dry_run": true` lists and uploads nothing). It runs main's `assets/cat-cafe/audio/upload.py` on that branch's sounds: every `.ogg` not in `uploaded.json` goes up as Audio on Derek's account. Nothing is pushed; the log has a line `uploaded <path> rbxassetid://<id> (<moderation>)` per file and then the diff to `uploaded.json`, `Cues.luau` and the sources log to commit on the branch (run stylua on `Cues.luau`). Audio counts against Derek's monthly allowance of 100, so dry-run first when unsure, and never run two at once (the workflow queues them).
- **Read the bug reports**: `workflow_id: "bug-reports.yml"`, `ref: "main"`, `inputs: {"day": "20261027", "count": "50"}` (`day` empty means today, UTC; `"studio": true` reads the Studio playtests' reports). The log prints one line per report, as `Debug.bugReports` does in Studio, then every record as JSON. Read only. The reports hold the friends' own words and user names: quote what a ticket needs and keep the rest out of chat.

The image and report scripts (`games/cat-cafe/tools/opencloud/upload-image.sh`, `bug-reports.sh`) also run from Git Bash with the key in the environment; `upload.py` runs anywhere with Python 3.
