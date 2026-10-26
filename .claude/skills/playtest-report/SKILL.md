---
name: playtest-report
description: How Purr Pot playtests are run and written up: the feedback form fields, the automated Studio smoke test, summary format, ticket format and severity scale. Use after any feature lands, after any friend playtest, and when turning raw feedback into tickets in docs/playtests/.
---

# Playtest report

## 1. Feedback form (Google Form -> Sheet, or a Discord template)
Fields, in order. Keep it under 3 minutes to fill in.
1. Name or nickname (text)
2. Device (phone / tablet / PC / console)
3. How long did you play? (under 5 min / 5 to 15 / 15 to 30 / over 30)
4. Did you understand what to do in the first minute? (yes / mostly / no) + what confused you (text)
5. What was the most fun moment? (text)
6. What was boring or annoying? (text)
7. Did anything break? Describe what you did right before. (text)
8. Fun score 1 to 5, and would you play again tomorrow? (yes / maybe / no)
9. One thing you would add (text)
10. Screenshot or clip link (optional)

The growth-analyst and QA share the Sheet. The QA agent reads the export (CSV) and writes the report.

## 2. Automated smoke test (Studio MCP, run before every friend playtest)
1. Start play (`start_stop_play`), confirm no errors in `get_console_output` within 10 s.
2. Walk to the counter (`character_navigation`), wait for a customer, tap a cat to serve, confirm coins increased on the HUD (`screen_capture`).
3. Open the shop, buy the cheapest upgrade, confirm it appears in the cafe and coins decreased.
4. Walk to the alley, catch one cat, confirm it appears in the cafe and the cat book.
5. Stop play, start again, confirm coins, upgrade and cat persisted.
6. Abuse pass: spam interact 50 times, buy with 0 coins, catch a cat from across the map (teleport the test character with `execute_luau`). Anything the server accepted is a **blocker** and goes to luau-reviewer.
Record: pass/fail per step, console errors (full text), screenshot paths.

## 3. Report format (docs/playtests/YYYY-MM-DD.md)
```markdown
# Playtest YYYY-MM-DD: <build or branch>
Testers: N (devices). Session lengths: ... Fun score: avg x/5, "play again": y yes / z maybe / w no.
Automated smoke test: pass | fail (link to section)

## Summary (5 lines max)
What worked, what did not, the one thing to fix first.

## Bugs
## Balance
## Confusion
## Requests
(one ticket each, format below, ranked by impact on the core loop)

## Quotes
One sentence per tester that captures their experience.
```

## 4. Ticket format
```
### [SEV] Short title  (raised by N of M testers)
Owner: engineer | ui-designer | asset-artist | designer
Repro: 1. ... 2. ... 3. ...
Expected: ...
Actual: ...
Evidence: docs/playtests/evidence/YYYY-MM-DD-<n>.png, console line
Notes: hypothesis if you have one; never a fix.
```

## 5. Severity scale
| Level | Meaning | Example |
|---|---|---|
| **blocker** | core loop cannot be completed, data loss, or exploit works | coins reset on rejoin; catch works from 200 studs |
| **major** | loop completes but a system is broken or clearly unfair | shop charges but upgrade never appears |
| **minor** | annoying, wrong, but playable | customer walks through a table |
| **cosmetic** | visual or copy only | PH_ placeholder still visible (expected in rough draft) |
Balance tickets use the same scale by effect on fun: "every tester quit at the second upgrade price" is major.

## 6. Counting rules
- A point raised by one tester is noted; by two or more it is a ticket; by half or more it goes to the top of its section.
- Separate "I did not understand X" (confusion, usually a UI or onboarding fix) from "X is boring" (balance or design).
- Quote testers, do not paraphrase into agreement with your own hypothesis.
