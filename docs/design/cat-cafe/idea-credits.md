# "Your name featured if we use your idea" (#1083)

Proposed 2026-11-04 by Design-Agent (friend's project), from Derek's live check the same day: "for feedback put have your name featured if idea is used." Owner: game-designer. Readers: UI-Engineer, Gameplay-Engineer, the lead (Tools-Agent), Model-Agent, QA. Built on the Feedback window in [ui-contract.md](ui-contract.md) ("Feedback tile" and "Report a bug").

## 1. In one paragraph

On the Feedback window's 💡 Idea chip, one line and a tick are added: "Feature my name if you use my idea". The tick is **off by default**, so nothing about a player is shown unless they ask. When the team builds an idea from a ticked report, the player's Roblox **display name** goes on a **Thank You board** in the Town Square, under a short description of the idea that we write ourselves. The board shows only the display name, which Roblox already moderates. It never shows the player's words, username, avatar or anything else, and the player can take their name off at any time from Settings.

## 2. The Feedback window

- Only on the 💡 Idea chip, under the box: a tick row **"Feature my name if you use my idea"**, with a small grey line under it: "Only your display name goes on the Thank You board in town."
- **Off by default**, every time the window opens on a fresh draft. A draft keeps its tick, as it keeps its chip.
- Bug and Stuck reports have no tick. Those are fixes, not ideas.
- The existing line "Please don't type passwords or personal info" stays, and we never ask for anything more: no real name, no age, no contact.
- Why off by default: the audience is young, and showing a name is something a player should choose. "On" would also put names up from players who skimmed the window. An idea is just as welcome without the tick.

## 3. The Thank You board

- **Where.** A wooden board with a cat-paw header, "Thank you for the ideas!", in the Town Square near the Codes Cat (Model-Agent picks the spot, `CatCafe_Street_ThanksBoard`, tag `ThanksBoard`). It is a world SurfaceGui, not a window or a HUD button, so nobody has to open anything.
- **What a row shows.** The idea in our words and the version it shipped in, then "Idea from" and the display name: "Cats nap on lawn benches · v190 · Idea from Mochi_Pie". It shows the newest 12. A small "Older ideas" arrow pages back through the rest on the same board.
- **Display name only.** The server looks up the display name by user id when it builds the board, with `UserService:GetUserInfosByUserIdsAsync`, so a renamed player shows their current name. If the lookup fails, the row reads "Idea from a player" and never shows a username or user id.
- **Nowhere else.** Store pages, patch notes, social posts and Discord say "an idea from a player", never a name. Off-platform posts are outside Roblox's protections, so names stay inside the game.

## 4. Where the credits live, and taking a name off

- **Saved with the report.** `ReportBug` gains an optional fourth argument `featureName: boolean`. The server keeps it as `featureName = true` on the report record only when the kind is `idea` and the value is exactly `true`; anything else is `false`. It is already in `BugReports_v1` with the `userId`.
- **Credits are kept out of the repo.** The repo is public, so it never holds a player's user id or name. Credits go in their own DataStore, `IdeaCredits_v1`, one key per credit: `{ userId, idea, version, addedAt }`, where `idea` is our text, at most 48 characters. The lead adds a manual workflow, `idea-credits.yml`, that takes a report's day and key, the idea text and the version. It checks through Open Cloud that the report's `featureName` is `true`, then writes the credit. A report without the tick can't be credited, even by mistake.
- **The game reads it.** At server start and every 30 minutes, the server reads `IdeaCredits_v1` and builds the board's rows (display names looked up as above).
- **Taking it off.** Settings gets a row, "Show my name on the Thank You board", which is on only for a player who has a credit and has not turned it off. Turning it off saves `profile.hideCredit = true`; the board shows "Idea from a player" for their rows from the next rebuild, and turning it back on restores the name. The workflow can also remove a credit by key, for a request through Roblox support or from a parent.
- **Moderation.** A display name that Roblox later moderates comes back from the lookup already changed. The board never caches names past one rebuild.

## 5. Contracts

- **Remotes:** `ReportBug(text, kind?, clientErrors?, featureName?)`, where `featureName` is kept only for `idea` and only as `true`. New `SetHideCredit(hide: boolean)`, 1 a second, saves `profile.hideCredit`.
- **Profile (next save version):** `hideCredit: boolean?` (nil means shown).
- **DataStore:** `IdeaCredits_v1` (see section 4). The record shape stays out of the repo's data files; only the code knows it.
- **Shared:** `BugReport.FeatureLabel` ("Feature my name if you use my idea") and `BugReport.FeatureHint`, so the window and the specs read one copy.
- **Workflow (lead):** `idea-credits.yml`, with inputs `report_key`, `idea`, `version` and `remove_key`. It uses the Open Cloud DataStore key in the repo's secrets, never prints a user id in the public log (only "credit added"), and refuses unless the report has `featureName = true` and kind `idea`.
- **Who builds:** UI-Engineer (the tick, the Settings row, the board's SurfaceGui), Gameplay-Engineer (the record field, the board's reader and name lookup, `SetHideCredit`), the lead (the workflow), Model-Agent (the board model), QA (section 6).

## 6. QA checks

1. On the Idea chip the tick shows and is off; on Bug and Stuck it does not show. A fresh window starts with it off; a kept draft keeps it.
2. A report sent with the tick saves `featureName = true`. A Bug report with `featureName = true` sent by an exploit saves `false`.
3. The workflow refuses a report without the tick, and its log shows no user id.
4. A credited player's row shows their display name, not their username. After a display name change it shows the new one on the next rebuild.
5. With "Show my name on the Thank You board" off, the row reads "Idea from a player" after the next rebuild; turning it on brings the name back.
6. A failed name lookup shows "Idea from a player", never a user id.
