# In-game bug reports (friends alpha)

Owner: qa-playtester (contract and checks). Server: Gameplay-Engineer. Settings row and window: UI-Engineer.
Asked for by Derek on 2026-10-27 ("and bug reports") for the private friends alpha. Nothing here sells anything,
and nothing a tester types is ever shown to another player.

Until this ships, testers send reports to Derek directly with the template in
[friends-alpha-tester-note.md](friends-alpha-tester-note.md).

## 1. What the player sees (UI-Engineer, UI PR #267; engineer PR #269 forwards Send to the remote)

- Settings gets a third section, **Help**, with one button row: **Report a bug**.
- It opens a small window: title "Report a bug", the line "What happened, and what were you doing right
  before?", three chips **Bug** (default), **Stuck** and **Idea**, a multi-line text box (500 characters, a
  "123 / 500" counter), the small line "Please don't type passwords or personal info", and **Send** and
  **Cancel**. The box and counter count bytes like the server, so an emoji counts 4 and the box stops at 500.
  Send stays off under 3 bytes once trimmed.
- Send fires `ReportBug(text, kind, clientErrors)`, where `clientErrors` is the last 3 client error lines from
  `LogService` since join, each cut to 200 bytes. The window closes on the "Thanks" toast and keeps the
  text on a warn toast, so nothing typed is lost. With no answer in 10 s it lights Send again with a note.
- Works on the phone: the box sits above the on-screen keyboard, and the chips and buttons stay tappable.

## 2. The remote (Gameplay-Engineer, engineer PR #265; the rules and limits live in `shared/BugReport`)

`ReportBug(text: string, kind: string?, clientErrors: { string }?)`, client to server.

| Check | Rule |
|---|---|
| `text` | a string; only its first 2,000 bytes are read; valid UTF-8 (`utf8.len` not nil); control characters other than newline removed (a tab becomes a space); trimmed; cut to 500 bytes on a character boundary, never refused for length (reviewer N149; the window already stops at 500 bytes, so only a hand-made call is cut); at least 3 bytes left |
| `kind` | `"bug"`, `"stuck"` or `"idea"`; anything else is `"bug"` |
| `clientErrors` | entries 1 to 3 of a table, each read to 800 bytes, valid UTF-8, control characters out (a newline becomes a space), trimmed and cut to 200 bytes; anything else is dropped, never refused |
| Rate limit | `RateLimiter` 1 call per 20 s per player; at most 10 reports per player per server session; at most 200 per server session |

Refusals answer with one warn toast ("Write a few words about what happened" for a short text, "You just sent
one, try again in a moment" for the limits) and write nothing.

The server adds, never trusting the client for any of it: `userId`, `name`, `placeVersion` (`game.PlaceVersion`),
`jobId`, `at` (`os.time()`), the clock phase, the area (`WorldBuilder.areaAt`, else `"street"`), the rounded
character position, `tier`, `money`, the count of cats owned, whether a cat is carried, the device from the
client's telemetry report, and the last 3 server error lines from `LogService` (each cut to 200 bytes).

It stores the record (`v` 1) with `DataStoreService:GetDataStore("BugReports_v1"):SetAsync(key, record, { userId })`
inside `pcall`, key `r_<YYYYMMDD UTC>_<os.time()>_<userId>`, so a day's reports list by prefix. Studio playtests
save under `s_<YYYYMMDD UTC>_...` instead, so test reports never sit in the list of the testers' ones. In Studio it also prints one
`[BugReport] <json>` line, so a run with API access off still shows the report. Then a good toast "Thanks! Your
report was sent." or, when the write fails, a warn toast "Couldn't send that, try again in a minute".

Debug hook: `Debug.bugReports(count?, day?, studio?)` lists the newest `count` (default 20) reports of `day` (UTC
`YYYYMMDD`, default today), one line each, oldest first: the live ones, or with `studio` the Studio playtests'
ones. Needs API access on in Studio.

## 3. Reading the reports (QA)

- In Studio with API access on: `game.ServerStorage.CatCafeDebug:Invoke("bugReports", 50)` for the testers'
  reports, `("bugReports", 50, nil, true)` for Studio's.
- From the threads: Open Cloud "List data store entries" and "Get entry" on universe 10773193456, data store
  `BugReports_v1`, prefix `r_<day>`. That needs an Open Cloud key with the `universe-datastores.objects:list`
  and `universe-datastores.objects:read` scopes on this experience, kept as a secret (never in the repo or
  chat). The publish key lacks them.
- QA turns each report into a ticket in `docs/playtests/<date>.md` with the `playtest-report` format and counts
  repeats.

## 4. Checks (QA)

- Plan row S37 in [test-plan.md](test-plan.md): send each kind from PC and phone, a 2-letter text, 600 characters,
  a second report inside 20 s; read them back with `Debug.bugReports`.
- Abuse row (key R, test plan 4.4): `ReportBug` with nil, 5, a table, `""`, `"  "`, invalid UTF-8, a NUL byte;
  10,000 bytes with kind `"admin"` and 50 client errors, three of them 10,000 bytes; then 30 calls in one frame.
  Nothing errors on the server, at most one record per 20 s, the 10,000-byte text stored as its first 500 bytes,
  every stored field within its limits.
- Unit edges: `BugReport.spec` checks the server's rules against a code point reference over seeded random
  reports, and `BugReportLogic.spec` will check the window lights Send exactly when the server keeps the text (after UI
  PR #270).
