# Review: friend's queue, 2026-11-03

Reviewer: luau-reviewer (Review-Agent, friend's project). Derek's open PRs while his usage is out until 11-08, plus the Coordinator's #1033.

| PR | Topic | Verdict | Action |
|---|---|---|---|
| #1022 | Cannon flight 4 s, intro cloud dip (Effects) | Pass | Ready; `automerge` label (auto-merge refused: already clean). Must merge before #1002. |
| #1002 | Config cannon beats 4.0 s | Pending | Re-check against main after #1022 merges, then queue. |
| #1031 | Store pictures v2, store-media/analytics prefer `ROBLOX_GROUP_KEY` | Pass | Merged by hand (workflow change; label path cannot). Workflow not run. |
| #1033 | asset-artist names EL4CTEO/blender-skills | Pass | Ready; `automerge` label. |

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
