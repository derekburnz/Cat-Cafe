# Studio plan: agents, skills and connectors per process (Purr Pot)

Date: 2026-10-25. Owner: lead. Companion to docs/plan.md (strategy) and CLAUDE.md (rules). This file answers "who does what, with which tools, and where does the output go".

## 1. The pipeline in one picture
```
Derek + friends ---ideas/feedback---> game-designer ---GDD, tuning---> luau-engineer ---code + test notes---> luau-reviewer ---verdict---> qa-playtester ---tickets---> (back to designer/engineer)
                                           |                                  ^
                                           |                                  | assets (.rbxm), UI modules
                                           v                                  |
                                     asset-artist, ui-designer  <----style guide, mockups----  growth-analyst (store page, analytics plan)
Lead (Derek's main Claude Code session): breaks work down, delegates, checks the gate, commits, writes decisions and devlog.
Connectors: Roblox Studio MCP (world, playtests, screenshots), Blender MCP (3D), Git/GitHub (history), Google Forms/Sheets (feedback), web search (research).
```

## 2. Where each process runs
| Location | Used for | Why |
|---|---|---|
| **Claude Code on Derek's PC** (repo root) | all building: code, assets, UI, reviews, automated QA, check gate | only place that can reach Studio MCP and Blender MCP (both local) |
| **This claude.ai project** (threads) | design docs, research, plans, pitches, review of docs, writing files into the shared `cat-cafe/` folder | no local tools needed; runs while Derek is away |
| **Roblox Studio** | the dev place, Team Create with friends later, publishing | |
| **GitHub (private repo)** | source of truth, rollback, portfolio evidence | |

The private repo https://github.com/derekburnz/purr-pot (created 2026-10-25, scaffold pushed 2026-10-26) is the source of truth and is saved to this project, so new threads get it. Threads change code on a branch and open a pull request; the project folder `cat-cafe/` stays a mirror for threads that cannot reach GitHub. GitHub Actions runs the check gate and the cloud unit tests on every pull request (`.github/workflows/check.yml`).

## 3. Processes
| Process | Agent (model) | Skills it reads | Connectors / tools | Input | Output (owned folder) |
|---|---|---|---|---|---|
| **Lead / setup** | main session (Opus; Fable for architecture) | all, especially devlog | Git, GitHub, Studio MCP for the smoke test | Derek's asks, thread results | CLAUDE.md, .claude/, docs/decisions.md, docs/devlog.md, docs/setup-guide.md |
| **Design** | game-designer (Fable via inherit) | gdd-onepager, monetization-policy, remote-security-checklist (for flags) | web search, Google Docs (Game Ideas doc), Three Game Sketches page | ideas, playtest tickets, growth research | docs/design/cat-cafe/gdd.md, tuning.md, features/*.md |
| **Build** | luau-engineer (Opus) | luau-conventions, remote-security-checklist, monetization-policy (PolicyService) | Studio MCP (inspect, execute_luau, playtest, console, screenshots), Rojo, Wally, check gate, Git | GDD, tuning.md, tickets, UI interface notes | games/cat-cafe/src/{server,shared,client/Controllers} |
| **Review** | luau-reviewer (Opus, read-only) | remote-security-checklist, luau-conventions, monetization-policy | git diff, check gate (read-only run) | engineer or ui-designer handoff | docs/reviews/<date>-<topic>.md, verdict |
| **Assets** | asset-artist (Opus) | asset-pipeline, concept-visuals | Blender MCP, Roblox Blender plugin, Studio MCP generation tools and screen_capture, Creator Store (inspected) | style guide, PH_ placeholder list from the engineer | assets/cat-cafe/{blender,exports,rbx}, docs/art/style-guide.md, docs/concepts/cat-cafe/ |
| **UI** | ui-designer (Opus) | concept-visuals, luau-conventions (UI section), monetization-policy (odds UI) | HTML/SVG mockups, Studio MCP device emulator screenshots, check gate | GDD, style guide, controller interfaces | assets/cat-cafe/ui/*.html, games/cat-cafe/src/client/UI/, docs/concepts/cat-cafe/ |
| **QA** | qa-playtester (Sonnet; Opus for hard bugs) | playtest-report | Studio MCP playtest tools (start_stop_play, character_navigation, inputs, console, screenshots, subagent playtest), Google Sheets export of the feedback form | engineer test notes, reviewer test line, friends' form responses | docs/playtests/<date>.md |
| **Growth** | growth-analyst (Opus) | monetization-policy, devlog (metrics section) | web search, Roblox Creator docs, later Roblox analytics dashboard and Creator Rewards page | GDD, playtest results | docs/growth/{comps,analytics-plan,monetization,store-page,launch-plan}.md |

## 4. Connector inventory
| Connector | Type | Runs where | Needed from | Setup | Status 2026-10-25 |
|---|---|---|---|---|---|
| **Roblox Studio MCP server** (built in) | MCP, local | Derek's PC | Phase 0 | setup-guide step 6; `.mcp.json` entry `Roblox_Studio` | to install |
| **Blender MCP** (ahujasid/blender-mcp) | MCP, local | Derek's PC | Phase 1 | setup-guide step 10; `.mcp.json` entry `blender` | to install |
| **Roblox Blender plugin** | Blender add-on | Derek's PC | Phase 1 | setup-guide step 11 | to install |
| **Git + GitHub private repo** | VCS | PC and cloud | Phase 0 | setup-guide step 2; repo saved to this project; CI in `.github/workflows/check.yml` | created, scaffold on main |
| **Rojo, Wally, Selene, StyLua, luau-lsp via Rokit** | CLI | Derek's PC | Phase 0 | `rokit install` | configs written |
| **Google Drive / Docs** | connector in this project | claude.ai | now | already connected (plan doc, Game Ideas doc) | connected |
| **Google Forms -> Sheets** (feedback form) | web + connector | claude.ai + friends | Phase 3 | create the form from the playtest-report fields; QA reads the Sheet export | to create |
| **Web search / fetch** | built in | claude.ai and Claude Code | now | none | available |
| **Roblox Group** | Roblox feature | roblox.com | before Phase 4 | create group, set roles for friends, publish from the group | open question (ownership, split) |
| **Roblox Team Create** | Studio feature | Studio | Phase 3 if friends build | Game Settings > Collaborate | later |
| **Roblox Open Cloud API** | REST, key in env var | PC or cloud | optional, Phase 4 | only for automated publishing or asset upload | not needed yet |
| **Discord** | chat | friends | optional | playtest channel with the form template pinned | Derek's call |
| **Roblox Studio Assistant via API key** | | | never | billed outside the Max plan; use Studio MCP instead | avoid |

## 5. Handoff contracts (what each role gives the next)
- designer -> engineer: `gdd.md` with the scope table, `tuning.md` keys matching `Config.luau`, feature specs with acceptance steps.
- engineer -> reviewer: branch name, files changed, how to test (exact Studio steps), known gaps, gate output.
- engineer -> artist: list of `PH_` placeholders with size and pivot; -> ui-designer: controller interface in `src/client/UI/README.md`.
- artist -> engineer: asset names in `assets/cat-cafe/rbx/`, which PH_ each replaces, tri counts, screenshots.
- ui-designer -> engineer: state and methods the UI needs; -> reviewer: same handoff as engineer.
- reviewer -> QA: verdict and one line of test plan; -> engineer: blockers and should-fixes with file:line.
- QA -> everyone: ranked tickets with owners in `docs/playtests/<date>.md`.
- growth -> designer and engineer: analytics event table, monetization table; -> ui-designer and artist: store page brief.
- lead -> Derek: decisions to confirm, devlog entry, resume bullet.

## 6. Threads running now (2026-10-25)
| Thread | Role | First deliverable |
|---|---|---|
| Plan studio agents, skills and connectors (this one) | lead / setup | this scaffold, setup guide, this plan |
| designer | game-designer | gdd.md + tuning.md for the vertical slice |
| engineer | luau-engineer | rough draft: cafe loop with PH_ placeholders, Remotes, DataService stub |
| assets | asset-artist | style guide draft, graybox, first cat model |
| UI | ui-designer | HUD mockup, Hud.luau, Components |
| reviewer | luau-reviewer | first review of the rough draft |
| QA | qa-playtester | smoke test plan, first run once Studio MCP is live |
| growth | growth-analyst | comps.md, analytics-plan.md, monetization.md |
Cloud threads cannot reach Studio or Blender. Anything that needs them is written as files and instructions for Derek's PC session.

## 7. Skills to add later (not yet needed)
- `check-gate`: a `/check` command that runs check.ps1 and summarises failures (the script already exists).
- `studio-mcp-playbook`: recipes for common Studio MCP tasks (place a model, light a scene, run a scripted playtest).
- `release-checklist`: age questionnaire, store page, maturity label, analytics live, dev vs live DataStore names, Group publishing.
- `analytics-events`: AnalyticsService wrapper and event naming once growth's plan is agreed.
- `cat-breeds`: content pipeline for adding a breed (catalog entry, model, icon, odds row).

## 8. Risks for the pipeline itself
- Two threads writing the same file in the shared folder: mitigated by folder ownership in CLAUDE.md; last write wins, so re-read before editing.
- Model aliases: `fable` may not be accepted in agent frontmatter, so game-designer uses `inherit`; run design passes from a Fable main session.
- Rokit versions pinned from memory; `rokit update` on first install and commit.
- Studio MCP tool names and Rojo optional-path syntax come from the plan doc and Rojo 7.4+ docs; if `rojo serve` rejects `default.project.json`, replace the `{ "optional": true, ... }` objects with plain paths and create empty `Packages/` folders.
- Usage: seven agents in parallel burns the Max pool fast. Opus for building, Sonnet for QA chores, Fable only for the design pass.
