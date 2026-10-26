---
name: devlog
description: Writes a Purr Pot devlog entry after each milestone: what was built, what the agents did, what broke, metrics, one screenshot, plus a resume bullet draft. Use at the end of a phase, after a friend playtest, or when Derek asks "write up what we did".
---

# Devlog

The devlog (`docs/devlog.md`, newest entry first) is the raw material for Derek's portfolio page and resume bullets, and the memory other threads read to know what happened. Write it plainly; a hiring manager who has never opened Roblox Studio should follow it.

## Entry template
```markdown
## YYYY-MM-DD: <milestone in five words>
**Phase:** 0 to 5 and what the exit criteria said.
**Built:** 3 to 6 bullets of player-visible or pipeline-visible results (not "refactored CatService").
**How the agents did it:** which agent did what, one line each; anything the pipeline caught (reviewer blocker, QA ticket) and how it was fixed.
**What broke:** the honest list, with the fix or the open ticket.
**Metrics:** playtest count, fun score, D1/D7 retention and session length once live; "none yet" is fine.
**Screenshot:** path under docs/concepts/cat-cafe/ with a caption.
**Next:** the next milestone's exit criteria in one line.
**Resume bullet draft:** "Built and launched Purr Pot on Roblox using a multi-agent Claude Code pipeline (7 specialized subagents, Roblox Studio and Blender MCP integrations, automated playtesting); <metric>."
```

## Rules
- Write from evidence: git log for the period, docs/reviews, docs/playtests, docs/decisions.md, screenshots in docs/concepts. Quote ticket ids and commit prefixes rather than memories.
- One entry per milestone, 150 to 300 words. Link, do not paste, the long documents.
- Networking angle for the resume: when a review caught a client-trust bug, say so in those words (remote validation, server authority, rate limiting map onto network security).
- Keep a running "pipeline lessons" list at the bottom of docs/devlog.md: what to tell the next agent so it does not repeat a mistake.
- After writing, propose the resume bullet in chat so Derek can copy it.
