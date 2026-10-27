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
   - runs CI on the head and merges with a merge commit when it passes and the head contains the latest main;
   - when main moved, merges main into the branch and runs CI again, then merges on green;
   - after a merge, starts the check run on main and, when Derek set `AUTO_PUBLISH`, a publish.
4. A failed check leaves the label on: push the fix and the next green run merges. A conflict with main, or a merge GitHub refuses, takes the label off with a PR comment, which wakes your PR subscription. Fix it by hand, then add the label again.
5. Labeled, green and still open after a few minutes? Open the newest "Merge if labeled automerge" job log on the PR's checks: its last lines say what it did (started CI, brought the branch up to date, saw a newer head, merged). Taking the label off and putting it back starts it again.

Ignore the `check` runs started by github-actions[bot] that sit at "action required" (then "failure" once the PR merges) with no jobs: GitHub creates one for each update-branch push and never runs it. The dispatched `check` run on the same commit carries the real checks.

Merge by hand instead (MCP `merge_pull_request`) when the PR changes `.github/workflows/`: the workflow token may not merge those. Report the merge to Derek in one line either way.

## 2. Publish to Roblox without Studio

`.github/workflows/publish.yml` builds `default.project.json` with Rojo (no test scripts), uploads it as a Saved version, runs the engine smoke test (`games/cat-cafe/tools/opencloud/Smoke.luau`: every shared and server module loads and the world builds in a real Roblox server), then publishes it live.

- Start it: GitHub MCP `actions_run_trigger` with `method: "run_workflow"`, `workflow_id: "publish.yml"`, `ref: "main"`, `inputs: {"version_type": "Published"}` (or `"Saved"` to add a version without going live). Derek can press Run workflow on the Actions tab.
- Publishing makes a new version live for players, so start it only when Derek asked for a publish (or he turned on `AUTO_PUBLISH`). Tell him the version number from the run summary.
- It needs the repo secret `ROBLOX_PUBLISH_KEY` (docs/setup-guide.md step 15). A missing secret fails the first step with that message; a 401 or 403 means the key lacks a permission or its IP list blocks GitHub.
- The smoke test is report only (`continue-on-error`) until it has passed once on Roblox. After that first green run, remove `continue-on-error` from the step so a broken build never goes live.
- Running servers keep their old version; new servers start on the new one. Roll back from Creator Dashboard > the place > Version History.
- Open Cloud cannot update unions, SurfaceAppearance, EditableMesh, EditableImage or layered clothing; the place has none today (Parts, WedgeParts, SpecialMeshes). If assets start using them, publish those changes from Studio.

The same scripts run from Git Bash on a PC with the key in the environment: `cd games/cat-cafe && tools/opencloud/publish.sh Published`.
