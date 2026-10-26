# Purr Pot friend playtest: feedback form

Owner: qa-playtester. Paste the questions into a Google Form (responses to a Sheet shared with QA and growth) or
use the Discord template at the bottom. Target: under 3 minutes to fill in, one form per tester per session.
Field order and CSV column names match the `playtest-report` skill so the QA agent can summarise the export.

## Questions (Google Form)

| # | CSV column | Question | Type | Options |
|---|---|---|---|---|
| 1 | nickname | Name or nickname | short text | |
| 2 | device | What did you play on? | single choice | Phone, Tablet, PC, Console |
| 3 | playtime | How long did you play? | single choice | Under 5 min, 5 to 15, 15 to 30, Over 30 |
| 4 | understood_first_minute | Did you understand what to do in the first minute? | single choice | Yes, Mostly, No |
| 4b | confusion | What confused you, if anything? | long text | |
| 5 | fun_moment | What was the most fun moment? | long text | |
| 6 | boring | What was boring or annoying? | long text | |
| 7 | broke | Did anything break? What did you do right before it happened? | long text | |
| 8 | fun_score | Fun score | linear scale 1 to 5 | 1 = would not play again, 5 = loved it |
| 8b | play_again | Would you play again tomorrow? | single choice | Yes, Maybe, No |
| 9 | add_one_thing | One thing you would add | short text | |
| 10 | evidence_link | Screenshot or clip link (optional) | short text | |

### Slice specific questions (add after question 7)

| # | CSV column | Question | Type | Options |
|---|---|---|---|---|
| 7a | catch_clear | Was it clear how to catch a cat (hold, release in the band)? | single choice | Yes, Took a few tries, No |
| 7b | spots_clear | Did you work out why some spots earn more? | single choice | Yes, Sort of, No, Did not notice |
| 7c | bought | What did you buy first, and why? | short text | |
| 7d | cats_caught | How many cats did you catch? | number | |
| 7e | offline_popup | Did you see the "while you were away" popup on rejoin? Did the amount feel right? | single choice | Did not rejoin, Saw it and it felt right, Saw it and it felt wrong, Did not see it |

Form settings: do not collect email addresses (friends may be under 18), do not require sign in, allow one
response per person per session (ask them to add the date in the nickname if they test twice).

## Discord template (for people who will not open a form)

```
**Purr Pot playtest** (date: ____)
Device: phone / tablet / PC / console
Played for: <5 / 5-15 / 15-30 / 30+ min
Knew what to do in minute one? yes / mostly / no. Confusing bit: ____
Most fun: ____
Boring or annoying: ____
Anything break? What were you doing: ____
Catching clear? yes / few tries / no. Spots earning more clear? yes / sort of / no
First purchase and why: ____. Cats caught: __
Fun 1-5: __  Play again tomorrow? yes / maybe / no
One thing to add: ____
Clip or screenshot: ____
```

## What QA does with the answers

1. Export the Sheet to CSV into `docs/playtests/raw/YYYY-MM-DD.csv` (never commit names other than nicknames).
2. Write `docs/playtests/YYYY-MM-DD.md` in the `playtest-report` format: bugs, balance, confusion, requests, each
   ticket with how many of N testers raised it, one quote per point.
3. `understood_first_minute` and `catch_clear` feed the onboarding funnel; `fun_score` and `play_again` are the
   headline numbers tracked across rounds; `offline_popup` checks F12 in the wild.
