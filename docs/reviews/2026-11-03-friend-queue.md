# Review: friend's queue, 2026-11-03

Reviewer: luau-reviewer (Review-Agent, friend's project). Derek's open PRs while his usage is out until 11-08, plus the Coordinator's #1033.

| PR | Topic | Verdict | Action |
|---|---|---|---|
| #1022 | Cannon flight 4 s, intro cloud dip (Effects) | Pass | Ready; `automerge` label (auto-merge refused: already clean); merged 0c082b3f, before #1002. |
| #1002 | Config cannon beats 4.0 s | Pass | Re-checked on main with #1022; auto-merge; merged 35b88f83. |
| #1031 | Store pictures v2, store-media/analytics prefer `ROBLOX_GROUP_KEY` | Pass | Merged by hand (workflow change; label path cannot). Workflow not run. |
| #1033 | asset-artist names EL4CTEO/blender-skills | Pass | Ready; `automerge` label; merged. |
| #1035 | Money counter flashes only for lumps (#1026, UI-Engineer) | Pass | Ready; auto-merge; merged. |
| #1037 | HUD right column stays under Roblox's top bar (#1025, UI-Engineer) | Pass | Ready; auto-merge once #1002 had landed. |
| #1036 | `.claude/settings.json` allows `add_repo` and `register_repo_root` | Diff correct, **held** | Not queued: needs a human's own OK (see below). |

## #1022
- Client only, listen only: `Effects/IntroCut.luau` reads `Moments.IntroCut` and `IntroEnd`, and `CannonGlide` reads the server's `CannonHeading` attribute (both on main). No remotes are fired or added, so the security checklist doesn't apply.
- `CannonHeading` is checked with `typeof(...) == "Vector3"`, and a near-zero vector falls back to the barrel's way. `Avatar.flight` returns the extra bank value on every branch.
- `IntroCut.dip` clamps the lead to `[0, cut]` and only shortens the dip around short cuts (`Logic.introDip` clamps both shares to `[0, 1]`). Skip stops the clouds only while a dip may still be on screen.
- Order risk: until #1002 lands, Config still says a 3.0 s flight with the move at 1.9, while the new poses expect 4.0 s. #1002 must follow straight after.
- Open: the Studio test-plan items (QA).

## #1031
- `${{ secrets.ROBLOX_GROUP_KEY || secrets.ROBLOX_PUBLISH_KEY }}` is set in the job env only. It is never echoed and there is no `set -x`, so it stays masked. Both workflows are dispatch or schedule only (no `pull_request`), so fork PRs can't reach either secret. Permissions stay `contents: read`.
- Once the group key exists, the daily analytics run uses it. That's the intent (#945).
- Nit: the "key is set" error message names only `ROBLOX_PUBLISH_KEY`.

## #1033
- One line in `.claude/agents/asset-artist.md`. It agrees with `.claude/skills/THIRD_PARTY.md` (pinned 71d031d, copied folders are never edited in place).

## #1035 (ui-review checklist)
- `UI/Components/MoneyFlash.luau` is pure and has a spec. HUD colours still come from `Theme.hud`, and no remote is fired.
- The client predicts income 5×/s, so each tick is about a fifth of a second's income and stays under the one-second threshold. Sales, tips and rewards still flash. A drop or a sync pull-back doesn't.
- Harmless edge cases: a frame hitch over 1 s, or an upward sync correction bigger than one second of income, gives one flash.
- Open: the in-game check (QA). The "4 old baseline findings gone" in uigate likely comes from main, so a separate PR can update the baseline.

## #1036 (held)
- The JSON is valid and both tool names are right.
- It adds agent tools to `permissions.allow` repo-wide because auto mode refused `add_repo`. Widening the allowlist to get past a refusal needs a person's explicit approval on the PR, not a request relayed between agent sessions. It's left as a draft for Derek or the friend.
- Option: allow only `register_repo_root` and keep `add_repo` behind its prompt.

## #1002
- Config beats CannonLaunchSeconds 4.0, CannonTeleportAtSeconds 2.6, CannonCloudsAt 2.0, CannonTouchdownAt 3.5, and Intro.STAND_AT 2.05. These match #1022's poses (clouds 2.0 to 3.0, touch 3.5, stand by 4.0) and the PR description.
- The new spec checks clouds < teleport < touchdown < launch end. The Config.spec table matches.
- Re-checked on main with #1022 in (0c082b3f): no conflict. Audio already reads CannonCloudsAt and CannonTouchdownAt, and CannonService takes its delays from Config. Merged 35b88f83.

## #1037 (ui-review checklist)
- Removal only: `topbarLift`, `_liftRight`, `_lift`, `TOPBAR_SLACK`, `RIGHT_COLUMN_W`, and the TopbarInset and Scale.changed listeners are gone, along with the `_scaleConnection` disconnect in `destroy`. Nothing is left dangling.
- The column starts at `MARGIN` under the `CoreUISafeInsets` area, so Roblox's top-bar shade can't cover its buttons, and the Roblox menu no longer moves it.
- Trade-off for Derek: the empty band from before 10-27 comes back. If it's too empty, the next step is a shorter clock row.
- Open: the before/after picture and the live check. The cloud UI gate doesn't draw Roblox's top bar, so both need live or Studio on Derek's side.

## Merge order note
Each merge to main restarts any running `automerge` label run (it retests on the new main). #1022 restarted twice, after #1033 and #1035. When an order matters, queue the next PR only after the previous one is on main.
