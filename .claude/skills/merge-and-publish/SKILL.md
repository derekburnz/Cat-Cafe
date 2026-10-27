---
name: merge-and-publish
description: How a Cat Cafe thread hands a finished PR to the automerge label instead of waiting on CI, and how to publish the game to Roblox from GitHub Actions without Studio. Use when a PR is reviewed and ready, when Derek asks to "send it to Roblox", publish or playtest the live game, or when an automerge comment or publish run fails.
---

# Merge and publish

Two GitHub Actions pieces take the waiting out of the pipeline. Both live in the repo, so they work the same from a cloud thread, the laptop or Derek's phone.

## 1. Queue a merge with the `automerge` label

Project rule (Derek, 2026-10-26): a thread merges its own PR once CI is green on a head that includes the latest main and the review findings are addressed. The label lets GitHub do the waiting part.

1. Only label a PR you would merge by hand right now apart from CI: the luau-reviewer's findings are addressed (or the PR is docs or assets only), its test plan is written, it targets `main`, it is not a draft.
2. Add the label with the GitHub MCP tool: `issue_write` with `method: "update"`, the PR number and `labels: ["automerge"]` (this sets the full label list, so include any labels already on the PR).
3. End your turn. `.github/scripts/automerge.sh` then:
   - runs CI on the PR merged with the latest main and, when it passes, merges with a merge commit, so main gets exactly the code that passed;
   - when main moved during the run, runs CI again with the new main merged in, then merges on green. Nothing is pushed to the branch, so there is no update commit to pull before your next push;
   - after a merge, starts the check run on main and, when Derek set `AUTO_PUBLISH`, a publish.
4. A failed check leaves the label on: push the fix and the next green run merges. A conflict with main, or a merge GitHub refuses, takes the label off with a PR comment, which wakes your PR subscription. Fix it by hand, then add the label again.
5. Labeled, green and still open after a few minutes? Open the newest "Merge if labeled automerge" job log on the PR's checks: its last lines say what it did (started CI, saw main move and started CI again, saw a newer head, merged). Taking the label off and putting it back starts it again.

Every check run tests the PR merged with main (`.github/scripts/merge-main.sh`; the "Merge main in (not pushed)" step names the main commit). Until 2026-10-27 the script pushed main into the branch instead; each of those pushes emailed Derek and left a jobless `check` run by github-actions[bot] at "action required" (then "failure"). A branch made before that change still updates the old way until main is merged into it.

Merge by hand instead (MCP `merge_pull_request`) when the PR changes `.github/workflows/`: the workflow token may not merge those. Report the merge to Derek in one line either way.

## 2. Publish to Roblox without Studio

`.github/workflows/publish.yml` builds `default.project.json` with Rojo (no test scripts), uploads it as a Saved version, runs the engine smoke test (`games/cat-cafe/tools/opencloud/Smoke.luau`: every shared and server module loads and the world builds in a real Roblox server), then publishes it live.

- Start it: GitHub MCP `actions_run_trigger` with `method: "run_workflow"`, `workflow_id: "publish.yml"`, `ref: "main"`, `inputs: {"version_type": "Published"}` (or `"Saved"` to add a version without going live). Derek can press Run workflow on the Actions tab.
- Publishing makes a new version live for players, so start it only when Derek asked for a publish (or he turned on `AUTO_PUBLISH`). Tell him the version number from the run summary.
- It needs the repo secret `ROBLOX_PUBLISH_KEY` (docs/setup-guide.md step 15). A missing secret fails the first step with that message; a 401 or 403 means the key lacks a permission or its IP list blocks GitHub.
- A failing smoke test stops the run before the live publish (the Saved version it tested stays in the place history and never goes live). It first passed on Roblox on 2026-10-27; its log line reads `[CatCafe] engine smoke ok ...` with module, plot and placeholder counts.
- Running servers keep their old version; new servers start on the new one. Roll back from Creator Dashboard > the place > Version History.
- Open Cloud cannot update unions, SurfaceAppearance, EditableMesh, EditableImage or layered clothing; the place has none today (Parts, WedgeParts, SpecialMeshes). If assets start using them, publish those changes from Studio.

The same scripts run from Git Bash on a PC with the key in the environment: `cd games/cat-cafe && tools/opencloud/publish.sh Published`.
