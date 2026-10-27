# In-game bug reports (friends alpha)

Owner: qa-playtester (contract and checks). Server: Gameplay-Engineer. Settings row and window: UI-Engineer.
Asked for by Derek on 2026-10-27 ("and bug reports") for the private friends alpha. Nothing here sells anything,
and nothing a tester types is ever shown to another player.

Until this ships, testers send reports to Derek directly with the template in
[friends-alpha-tester-note.md](friends-alpha-tester-note.md).

## 1. What the player sees (UI-Engineer)

- Settings gets a third section, **Help**, with one button row: **Report a bug**.
- It opens a small window: title "Report a bug", the line "What happened, and what were you doing right
  before?", three chips **Bug** (default), **Stuck** and **Idea**, a multi-line text box (500 characters, a
  "123 / 500" counter), the small line "Please don't type passwords or personal info", and **Send** and
  **Cancel**. Send stays off under 3 characters.
- Send fires `ReportBug(text, kind, clientErrors)`, where `clientErrors` is the last 3 client error lines from
  `LogService` since join, each cut to 200 characters. The window closes on the "Thanks" toast and keeps the
  text on a warn toast, so nothing typed is lost.
- Works on the phone: the box sits above the on-screen keyboard, and the chips and buttons stay tappable.

## 2. The remote (Gameplay-Engineer)

`ReportBug(text: string, kind: string?, clientErrors: { string }?)`, client to server.

| Check | Rule |
|---|---|
| `text` | a string; trimmed; 3 to 500 bytes; valid UTF-8 (`utf8.len` not nil); control characters other than newline removed |
| `kind` | `"bug"`, `"stuck"` or `"idea"`; anything else is `"bug"` |
| `clientErrors` | a table of at most 3 strings, each valid UTF-8 and cut to 200 bytes; anything else is dropped, never refused |
| Rate limit | `RateLimiter` 1 call per 20 s per player; at most 10 reports per player per server session; at most 200 per server session |

Refusals answer with one warn toast ("Write a few words about what happened" for a short text, "You just sent
one, try again in a moment" for the limits) and write nothing.

The server adds, never trusting the client for any of it: `userId`, `name`, `placeVersion` (`game.PlaceVersion`),
`jobId`, `at` (`os.time()`), the clock phase, the area (`WorldBuilder.areaAt`, else `"street"`), the rounded
character position, `tier`, `money`, the count of cats owned, whether a cat is carried, the device from the
client's telemetry report, and the last 3 server error lines from `LogService` (each cut to 200 bytes).

It stores the record with `DataStoreService:GetDataStore("BugReports_v1"):SetAsync(key, record)` inside `pcall`,
key `r_<YYYYMMDD UTC>_<os.time()>_<userId>`, so a day's reports list by prefix. In Studio it also prints one
`[BugReport] <json>` line, so a run with API access off still shows the report. Then a good toast "Thanks! Your
report was sent." or, when the write fails, a warn toast "Couldn't send that, try again in a minute".

Debug hook: `Debug.bugReports(count?, day?)` lists the newest `count` (default 20) reports of `day` (UTC
`YYYYMMDD`, default today), one line each, oldest first. Needs API access on in Studio.

## 3. Reading the reports (QA)

- In Studio with API access on: `game.ServerStorage.CatCafeDebug:Invoke("bugReports", 50)`.
- From the threads: Open Cloud "List data store entries" and "Get entry" on universe 10773193456, data store
  `BugReports_v1`, prefix `r_<day>`. That needs an Open Cloud key with the `universe-datastores.objects:list`
  and `universe-datastores.objects:read` scopes on this experience, kept as a secret (never in the repo or
  chat). The publish key lacks them.
- QA turns each report into a ticket in `docs/playtests/<date>.md` with the `playtest-report` format and counts
  repeats.

## 4. Checks (QA, once it ships)

- Plan row: send each kind from PC and phone, a 2-character text, 600 characters, a second report inside 20 s;
  read them back with `Debug.bugReports`.
- Abuse row: `ReportBug` with nil, 5, a table, `""`, `"  "`, 10,000 bytes, invalid UTF-8, a NUL byte, kind
  `"admin"`, `clientErrors` as a string, 50 entries and 10,000-byte entries, then 30 calls in one frame. Nothing
  errors on the server, at most one record per 20 s, every stored field within its limits.
