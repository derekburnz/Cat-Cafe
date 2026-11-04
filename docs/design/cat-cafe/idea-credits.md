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
- **What a row shows.** The idea in our words and the version it shipped in, then "Idea from" and the display name: "Cats nap on lawn benches · v190 · Idea from MochiPie". It shows the newest 12. A small "Older ideas" arrow pages back through the rest on the same board.
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

## 7. "What's new" on the Thank You board (#1216)

The friend, 11-04: show the recent updates on the board "in a clean looking way". Decided by the friend, relayed by the Coordinator; written up by Design-Agent.

### 7a. Layout

- **Two panels in one frame.** The board gets a second panel on its left, `WhatsNewPanel`, the same height as the credits panel and about two thirds of its width, under one shared cat-paw header, "Thank you for the ideas!". The left panel's own small title reads "What's new". Model-Agent widens the frame to hold both. If it can't fit in the board's spot, Model-Agent stacks the panel above the credits instead.
- **3 to 5 rows**, newest at the top. With fewer than 3 updates in the module, the panel shows what it has. It never pads with filler.
- **Each row, left to right:**
  - an icon from the fixed set below (a clean `ShopIcons` picture, about 1 stud square);
  - the update text in bold cocoa;
  - the date on the right in small grey, written "Nov 4" (UTC, month and day, never "2 days ago", so the board never looks stale or rushed).
- **Linked credit.** When an update came from a player's idea, a second smaller line under its text reads "💡 Idea from MochiPie", using the same display-name lookup and hide rule as the credits panel (section 3 and 4). If the name is hidden or the lookup fails, it reads "💡 A player's idea". A thin line of the same berry colour links the row to that credit's row in the credits panel, so the eye can follow it. There is nothing to tap: the board is a world sign.
- **Readable from a few studs away:** the update text at least 0.4 studs tall, the date and credit line at least 0.25, and the Cozy Cream cream board with cocoa text. There are no animations except the night glow every board already has.

### 7b. Copy rules

- At most **28 characters**, in sentence case, with no full stop. Start with what the player gets: "Corner Shop opens in town", "Cleaner buttons", "Faster cannon flights".
- The icon says the kind, so the text doesn't need "New:" or "Fix:".

  | icon kind | picture | for |
  |---|---|---|
  | `new` | sparkle | a new place, shop or feature |
  | `cat` | cat face | new cats or cat behaviour |
  | `look` | paintbrush | art, UI or decor |
  | `faster` | lightning | speed or fewer taps |
  | `fix` | wrench | a bug fix players noticed |

- No hype or pressure: no "HUGE", no "!!!", no "limited", no countdowns and no prices. Never name a Robux item. The board is for what got better, not for selling.
- One line per update, not per PR. A publish that ships three small UI fixes gets one "Cleaner buttons" line.

### 7c. The data module

`shared/WhatsNew.luau` returns a frozen list, newest first:

```lua
return table.freeze({
	{ id = "crate_bundle", date = "2026-11-04", icon = "new", text = "Buy 5 crates at once" },
	{ id = "corner_shop", date = "2026-11-03", icon = "new", text = "Corner Shop opens in town" },
	-- a row from a credited idea adds creditId = "c1" (the id idea-credits.yml returned)
})
```

- `date` is `YYYY-MM-DD` (UTC), `icon` one of the five kinds, `text` at most 28 characters. `creditId` is optional and is the credit's short id in `IdeaCredits_v1` (for example `c3`), never a user id or name, since the repo is public.
- **Adding a line:** whoever opens the publish PR adds one row at the top. The board reads the module at server start, so the next publish shows it, with no change to the board's code or model.
- **A spec test** (`WhatsNew.spec.luau`) fails the gate on a bad date, an unknown icon, text over 28 characters, a duplicate `id` or rows out of date order.
- The board shows only the first 5 rows. Older rows can stay in the module as a history, or be trimmed.

### 7d. Contracts and owners

- **Credit ids:** each `IdeaCredits_v1` credit gets a short `creditId` (`c1`, `c2` and so on) when the workflow writes it, and the workflow's log prints only that id. This adds to section 4: `idea-credits.yml` returns the new `creditId` so a publish PR can link it.
- **UI-Engineer:** `Screens/ThanksBoard.luau` gains the What's new panel (a SurfaceGui on `WhatsNewPanel`'s front face) and the link line. It reads `WhatsNew` directly on the client. The credit names come from the server's board data, as for the credits panel.
- **Model-Agent:** the wider frame with the `WhatsNewPanel` part, or the stacked panel if the spot is tight.
- **Gameplay-Engineer:** the board data includes each linked credit's display line by `creditId`. No new remote: the existing board rebuild carries it.

### 7e. QA checks

1. With 6 rows in `WhatsNew`, the panel shows the newest 5, newest at the top, each with its icon, text and "Nov 4" date.
2. A row with a `creditId` shows "💡 Idea from" and the display name, or "💡 A player's idea" when that player hid their name.
3. The spec test fails on a 29-character text, an unknown icon or a date out of order.
4. From 8 studs away on a phone, the update text is readable.
