# Pre-release remote-security sweep (2026-11-07)

Reviewer: Review-Agent (luau-reviewer). Issue #2117. Checked against `remote-security-checklist` on main at 724daa36.
Scope: every client-to-server remote and server entry added or changed since 2026-11-04: badges, the Rescue Rally,
catch scoring, codes, the pity cat, idea credits, camp stations and store prompts.

Every remote goes through `Net.on` (src/server/Services/Net.luau), which applies a global per-player bucket plus a
per-remote bucket before the handler runs, and wraps the handler in xpcall with the log held to once a second. So
"rate limit" below names the per-remote bucket.

## Findings

| # | Severity | Where | Issue |
|---|---|---|---|
| 1 | Medium | PassService.onPurchaseFinished | #2131: a game pass is marked owned for the session on `PromptGamePassPurchaseFinished`'s `purchased` flag alone, with no `UserOwnsGamePassAsync` check. Session-only, not saved. |
| 2 | Low | IdeaCreditsService.onSetHideCredit | #2132: each toggle (1 a second) resends the 60-row Thank You board to every player in the server. Bandwidth only. |

No high-severity findings. Nothing in scope lets a client pick its own reward, grade, price or prize.

## Remotes and server entries checked

| Feature | Entry | Args validated | Rate limit | Ownership, range, replay | Result |
|---|---|---|---|---|---|
| Badges | BadgeAwardService (no remote) | n/a | n/a | Earned badges read from the profile only; owned set looked up first and nothing awarded until a lookup works, so no double award | Pass |
| Rescue Rally | RallyService.score (no remote) | n/a | n/a | Points only from server events (check-in, tame, Team Rescue helper). Step prizes through Payout, laps capped by RallyMaxLaps in the save | Pass |
| Catch scoring | CatchPress(strayId, index) | Guard.id, Guard.int 1..MAX_CIRCLES | default bucket | Stray must be alive and `lockedBy` the caller; the grade is computed on the server from server arrival time minus half the server-measured ping (capped at CatchLatencyCapSeconds). The client's own guess is display only, corrected by CatchJudged | Pass |
| Catch scoring | CheckIn() | no args | default bucket | Needs a server-held carry and the caller within CheckInRangeStuds of their own door or back door | Pass |
| Codes | RedeemCode(text) | type string, at most Codes.MAX_BYTES, trimmed, lowercased, charset and length checked | 1 per 2 s | Wrong-code lock after CodeWrongLimit; group check in pcall with a busy flag; refusal checked again after the yield and the id saved before paying, so one code pays once | Pass (note A) |
| Pity cat | PityService (no remote) | MemoryStore and MessagingService payloads type-checked, own job ignored | n/a | Claim is an UpdateAsync set-if-empty, so the first catch anywhere wins | Pass |
| Idea credits | SetHideCredit(hide) | Guard.bool | 1 a second | Own profile only; no-op when unchanged; DataStore mirror at most once per 30 s | Finding 2 |
| Camp stations | CollectCampExtra(id) | Guard.oneOf CampExtras.COLLECT | 1 a second | Tier gate, server-side reach check (the Golden Pond attribute is set by the server only), settle then collectBlocker, prize rolled on the server | Pass |
| Camp stations | BuyYardSale(crateId) | Guard.id, Catalog.getCrate | 1 a second | Reach check when open; buyBlocker checks open tier, today's stock and the claim timer | Pass |
| Store | MarkStoreSeen(tab) | StoreTabs.isTab | 2 a second | Saves a known version only; syncs only on a change | Pass |
| Store | BuyCornerShop(itemId, window, shownPrice?) | Guard.id, Guard.int | 2 a second | Near the stall; price from the catalog and tier on the server; shownPrice can only make it refuse | Pass |
| Store | FeedCat(foodId, catUid) | Guard.id both | 4 a second | Own cat, food held, level cap | Pass |
| Store | PassClaim(track, level) / PassClaimAll() | Guard.oneOf, Guard.int 1..PassLevels | 4 / 1 a second | claimBlocker: season running, level reached, paid track needs paidSeason (set only from a receipt or owner test), not claimed | Pass |
| Store | ProcessReceipt | PurchaseId type and length, known product | n/a | Receipt id recorded before granting, PurchaseGranted only after the save holds it | Pass |
| Store | PromptGamePassPurchaseFinished (PassService, Telemetry) | pass id is ours | n/a | No ownership check before granting | Finding 1 |
| Store | OwnerGrant(productId) | Products.forProductId | 1 a second | Only Config.OwnerTestUserIds; anyone else is dropped and logged | Pass (note B) |
| Telemetry | TelemetryReport(name, value) store_opened, store_tab, store_buy, store_guard_blocked, session_recap(_close), index_hint_tap, playtime_gift | Guard.oneOf REPORTS, then each value allowlisted or clamped | 40 a minute | Store visits capped by VISITS_MAX, guard blocks by GUARD_BLOCKS_MAX, funnel steps only move forward, recap minutes from the server's join time, once-a-session flags elsewhere | Pass |

## Notes (no issue)

A. The wrong-code lock lives in memory per Player, so rejoining clears it. With 1 try per 2 s and codes that are
announced in public anyway, that is acceptable; a cross-server lock would cost a DataStore write per wrong code.

B. Owner test mode is live in the published game for the owner ids only. Keep `OwnerTestUserIds` to Derek's
accounts; the server check is the only gate, which is correct.

C. Character position is the client's in Roblox, so every reach check (camp stations, Corner Shop, check-in) trusts
a position the client can move. That is the platform's limit, not a bug here; the checks still stop casual misuse,
and nothing in reach is worth more than walking there.
