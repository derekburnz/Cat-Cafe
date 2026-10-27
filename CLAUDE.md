# Cat Cafe studio rules

Working title: **Cat Cafe** (placeholder until a real name is picked). Game slug used in paths: `cat-cafe`. One game for now; the repo layout leaves room for a second.
Phase as of 2026-10-25: Phase 0 (setup on Derek's PC) running in parallel with an early Phase 2 rough draft.
Repo: https://github.com/derekburnz/purr-pot (private, source of truth). Work on a branch, open a pull request, let CI run the check gate.

## Read first, in this order
1. `docs/plan.md` (the master plan: who, goals, rules, phases).
2. `docs/studio-plan.md` (which agent, skills and connectors each process uses, and which folder each role owns).
3. `docs/design/cat-cafe/gdd.md` (the design; owned by the game-designer).
4. `docs/decisions.md` (what has been decided and why). Append, never rewrite.
5. The skill for your task in `.claude/skills/<name>/SKILL.md`.

## Where things live
| What | Path | Owner |
|---|---|---|
| Luau code (Rojo synced) | `games/cat-cafe/src/{server,client,shared}` | luau-engineer; `src/client/UI/` is the ui-designer's |
| Rojo project, tool configs, check gate | `games/cat-cafe/` | lead |
| Tool versions | `rokit.toml` (repo root) | lead |
| Design docs | `docs/design/cat-cafe/` | game-designer |
| Style guide | `docs/art/style-guide.md` | asset-artist |
| Concept screenshots, HUD mockups | `docs/concepts/cat-cafe/` | asset-artist, ui-designer |
| 3D sources and exports | `assets/cat-cafe/blender/`, `assets/cat-cafe/exports/` | asset-artist |
| Rojo-synced model files (.rbxm/.rbxmx) | `assets/cat-cafe/rbx/` (becomes `ReplicatedStorage.Assets`) | asset-artist, ui-designer |
| UI mockups (HTML/SVG) | `assets/cat-cafe/ui/` | ui-designer |
| Animation and VFX code (client only, carved out of `src/client`) | `games/cat-cafe/src/client/Effects/` | vfx-animator |
| Animation sources (keyframes, later Blender rigs), VFX textures | `assets/cat-cafe/anim/`, `assets/cat-cafe/vfx/` | vfx-animator |
| Effects list, captures, measured VFX budgets | `docs/vfx/cat-cafe/` | vfx-animator |
| Code reviews | `docs/reviews/<date>-<topic>.md` | luau-reviewer |
| Playtest reports and tickets | `docs/playtests/<date>.md` | qa-playtester |
| Research, analytics, store page, launch plan | `docs/growth/` | growth-analyst |
| Decisions, devlog, setup guide | `docs/decisions.md`, `docs/devlog.md`, `docs/setup-guide.md` | lead |
| Sound list, music brief, listening list | `docs/audio/` | sound-designer |
| Audio files, sources and license log, audio gate report | `assets/cat-cafe/audio/` | sound-designer |
| Client audio code (cue table, SoundGroups, playback) | `games/cat-cafe/src/client/Audio/` | sound-designer |

Write only inside the folders your role owns. If you need a change elsewhere, write a note in `docs/decisions.md` under "Proposed" and tell the lead.

## Rules (short form; long form in docs/plan.md section 9)
1. **Back up first.** Commit before any agent session. Agents work in a dev copy of the place, never the published one.
2. **Code lives in files.** Scripts are edited under `src/` and synced by Rojo. Never edit a Rojo-managed script inside Studio through MCP; Rojo overwrites it. Studio MCP is for the world, non-script instances, playtests, console output and screenshots.
3. **Server authority.** The client asks, the server decides. Validate every remote argument. Rate-limit remotes. See `remote-security-checklist`.
4. **Pipeline per feature:** designer spec -> engineer build -> reviewer check -> QA playtest. No agent signs off its own work.
5. **Small steps.** One feature per branch and commit, each with a test plan.
6. **Done means the gate passes:** `cd games/cat-cafe` then `./check.ps1` (Windows) or `./check.sh`. It runs `rojo sourcemap`, `luau-lsp analyze`, `selene` and `stylua --check`. Then a playtest with no new console errors.
7. **Creator Store assets** get inspected for scripts before use.
8. **Original IP only.** Mechanics can be inspired by other games; names, characters, art and audio are ours.
9. **Paid random items** follow `monetization-policy` every time. Cat luring with bait counts if the bait can be bought with Robux.
10. **Young audience by default.** No dark patterns, filter user text, match content to the maturity label we declare.
11. **Usage budget.** Fable for design, architecture and hard bugs; Opus for building; Sonnet or Haiku for chores.
12. **Decisions** go in `docs/decisions.md` with date and reason.
13. **Secrets** (Open Cloud keys, tokens) stay in environment variables, never in the repo or in chat.
14. **Explain Roblox concepts** the first time they come up. Derek knows networking and Linux, not Luau or Studio.

## Luau quick facts (for anyone new to Roblox)
- A **place** is one level/world file; an **experience** is the published game that holds places. We work in a dev copy of the place.
- **Server scripts** run on Roblox's server (`ServerScriptService`), **client scripts** on each player's device (`StarterPlayerScripts`), **ModuleScripts** are libraries either side can `require`. `ReplicatedStorage` is visible to both; `ServerStorage` only to the server.
- **RemoteEvents / RemoteFunctions** are how client and server talk. Exploiters can fire any remote with any arguments, so the server validates everything.
- **Rojo** maps folders on disk to that instance tree using `default.project.json`.

## Naming
Files: `PascalCase.luau`, server entry points end in `.server.luau`, client in `.client.luau`. Instances in Studio: `PascalCase`. Assets: `Cafe_Furniture_CounterA`, `Cat_Tabby_Base`, `Prop_FoodBowl` (see `asset-pipeline`).
