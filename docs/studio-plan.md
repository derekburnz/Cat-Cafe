# Studio plan: agents, skills and connectors per process (Cat Cafe)

Date: 2026-10-25. Owner: lead. Companion to docs/plan.md (strategy) and CLAUDE.md (rules). This file answers "who does what, with which tools, and where does the output go".

## 1. The pipeline in one picture
```
Derek + friends ---ideas/feedback---> game-designer ---GDD, tuning---> luau-engineer ---code + test notes---> luau-reviewer ---verdict---> qa-playtester ---tickets---> (back to designer/engineer)
                                           |                                  ^
                                           |                                  | assets (.rbxm), UI modules
                                           v                                  |
                                     asset-artist, ui-designer, vfx-animator  <----style guide, mockups----  growth-analyst (store page, analytics plan)
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

The repo https://github.com/derekburnz/Cat-Cafe (created 2026-10-25 as purr-pot, scaffold pushed 2026-10-26, renamed 2026-10-27, public since 2026-10-27 20:59 so GitHub Actions minutes are free) is the source of truth and is saved to this project, so new threads get it. Threads change code on a branch and open a pull request; the project folder `cat-cafe/` stays a mirror for threads that cannot reach GitHub. GitHub Actions runs the check gate and the cloud unit tests on every pull request (`.github/workflows/check.yml`), merges PRs labeled `automerge` once they are green on the latest main (`automerge.yml`), and publishes the place to Roblox through Open Cloud (`publish.yml`); see the `merge-and-publish` skill.

## 3. Processes
| Process | Agent (model) | Skills it reads | Connectors / tools | Input | Output (owned folder) |
|---|---|---|---|---|---|
| **Lead / setup** | main session (Opus; Fable for architecture) | all, especially devlog | Git, GitHub, Studio MCP for the smoke test | Derek's asks, thread results | CLAUDE.md, .claude/, docs/decisions.md, docs/devlog.md, docs/setup-guide.md |
| **Design** | game-designer (Fable via inherit) | gdd-onepager, monetization-policy, remote-security-checklist (for flags) | web search, Google Docs (Game Ideas doc), Three Game Sketches page | ideas, playtest tickets, growth research | docs/design/cat-cafe/gdd.md, tuning.md, features/*.md |
| **Build** | luau-engineer (Opus) | luau-conventions, remote-security-checklist, monetization-policy (PolicyService) | Studio MCP (inspect, execute_luau, playtest, console, screenshots), Rojo, Wally, check gate, Git | GDD, tuning.md, tickets, UI interface notes | games/cat-cafe/src/{server,shared,client/Controllers} |
| **Review** | luau-reviewer (Opus, read-only) | remote-security-checklist, luau-conventions, monetization-policy | git diff, check gate (read-only run) | engineer or ui-designer handoff | docs/reviews/<date>-<topic>.md, verdict |
| **Assets** | asset-artist (Opus) | asset-pipeline, concept-visuals | Blender MCP, Roblox Blender plugin, Studio MCP generation tools and screen_capture, Creator Store (inspected) | style guide, PH_ placeholder list from the engineer | assets/cat-cafe/{blender,exports,rbx}, docs/art/style-guide.md, docs/concepts/cat-cafe/ |
| **UI** | ui-designer (Opus) | concept-visuals, luau-conventions (UI section), monetization-policy (odds UI) | HTML/SVG mockups, Studio MCP device emulator screenshots, check gate | GDD, style guide, controller interfaces | assets/cat-cafe/ui/*.html, games/cat-cafe/src/client/UI/, docs/concepts/cat-cafe/ |
| **Animation and VFX** | vfx-animator (Opus) | animation-vfx, asset-pipeline (pivots, Root part), luau-conventions; third-party roblox-characters-animation, roblox-mobile-playtest, roblox-dev-skill performance-optimization.md, blender-to-roblox (rig export) | Studio MCP (execute_luau to tune emitters and rigs in the dev place, start_stop_play, screen_capture, console), Animation Editor, MicroProfiler, device emulator, check gate; Blender MCP from step 3 of the rig ladder | features.md mechanics, style guide palette and lighting, manifest.json joints and poses, Moments signals from the engineer | games/cat-cafe/src/client/Effects/, assets/cat-cafe/{anim,vfx}/, docs/vfx/cat-cafe/ |
| **QA** | qa-playtester (Sonnet; Opus for hard bugs) | playtest-report | Studio MCP playtest tools (start_stop_play, character_navigation, inputs, console, screenshots, subagent playtest), Google Sheets export of the feedback form | engineer test notes, reviewer test line, friends' form responses | docs/playtests/<date>.md |
| **Growth** | growth-analyst (Opus) | monetization-policy, devlog (metrics section) | web search, Roblox Creator docs, later Roblox analytics dashboard and Creator Rewards page | GDD, playtest results | docs/growth/{comps,analytics-plan,monetization,store-page,launch-plan}.md |
| **Sound and music** (added 2026-10-26) | sound-designer (Opus) | audio-pipeline, roblox-audio, find-resources (Creator Store search, license gate, credits), monetization-policy (purchase sounds) | Studio MCP search_asset (Audio) and playtests, ffmpeg for the audio gate, Creator Dashboard or Open Cloud upload on Derek's PC | GDD, Config timings, style guide mood, moments from the engineer | docs/audio/cat-cafe/sound-list.md, assets/cat-cafe/audio/, games/cat-cafe/src/client/Audio/ |

Third-party skills per role (added 2026-10-26, details in `.claude/skills/THIRD_PARTY.md`): engineer and reviewer read `roblox-dev-skill` (plus `roblox-audio`, `roblox-characters-animation`) and verify APIs with the `roblox_docs` MCP; the asset-artist uses `blender-core`, `blender-asset-qa`, `blender-export-pipelines`, `blender-game-optimization`, `blender-retopology-uv`, `blender-to-roblox` and `find-resources`; QA uses `roblox-mobile-playtest` and `roblox-testing`; growth and the designer use `roblox-publishing-discovery`, `roblox-release-operations` and `roblox-policy-compliance`; the lead runs `/roblox-doctor` for setup checks.

## 4. Connector inventory
| Connector | Type | Runs where | Needed from | Setup | Status 2026-10-25 |
|---|---|---|---|---|---|
| **Roblox Studio MCP server** (built in) | MCP, local | Derek's PC | Phase 0 | setup-guide step 6; `.mcp.json` entry `Roblox_Studio` | to install |
| **Blender MCP** (ahujasid/blender-mcp) | MCP, local | Derek's PC | Phase 1 | setup-guide step 10; `.mcp.json` entry `blender` | to install |
| **Roblox Blender plugin** | Blender add-on | Derek's PC | Phase 1 | setup-guide step 11 | to install |
| **Roblox docs MCP** (n4tivex/mcp-roblox-docs) | MCP, local, no key | Derek's PC (cloud threads if PyPI is reachable) | Phase 0 | `.mcp.json` entry `roblox_docs` (`uvx mcp-roblox-docs`); needs `uv` from setup-guide step 10 | added 2026-10-26 |
| **Third-party skills** (roblox-dev-skill, blender-*, roblox-doctor, blender-to-roblox, find-resources, AshExplained and EL4CTEO checklists) | Markdown + scripts in `.claude/skills/` | PC and cloud (scripts PC only) | Phase 0 | `.claude/skills/THIRD_PARTY.md`; `/roblox-doctor` checks the PC setup | added 2026-10-26 |
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
- engineer -> vfx-animator: the moments fired in `src/client/Moments.luau` and the cat rig (Root, Body, Head, Tail joints); vfx-animator -> engineer: hooks it needs (a moment, a rig change, an attribute), written as requests in `docs/vfx/cat-cafe/effects-list.md`; -> reviewer: same handoff as engineer plus the budget numbers measured on a phone profile; -> artist: palette swatches or separate objects it needs (an arm, an ear).
- reviewer -> QA: verdict and one line of test plan; -> engineer: blockers and should-fixes with file:line.
- QA -> everyone: ranked tickets with owners in `docs/playtests/<date>.md`.
- growth -> designer and engineer: analytics event table, monetization table; -> ui-designer and artist: store page brief.
- lead -> Derek: decisions to confirm, devlog entry, resume bullet.
- designer -> sound-designer: the clock, catch timings and moments that need sound (gdd.md, Config.luau); engineer -> sound-designer: moments fired from `src/client/Moments.luau` (proposed, shared with the vfx-animator).
- sound-designer -> engineer and ui-designer: cue ids per moment (sound-list.md sections 5 and 6), never asset ids; -> reviewer: `src/client/Audio/` Luau, same handoff as the engineer; -> QA: the listening list (sound-list.md section 8); -> Derek: what to listen to and which files to upload.

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
- ~~`studio-mcp-playbook`~~: covered since 2026-10-26 by `roblox-dev-skill` (SKILL.md tool table, `references/mcp-integration.md`, `references/agent-safety.md`).
- `release-checklist`: age questionnaire, store page, maturity label, analytics live, dev vs live DataStore names, Group publishing. The generic half is now `roblox-release-operations` plus `roblox-policy-compliance`; only the Cat Cafe specifics remain to write.
- `analytics-events`: AnalyticsService wrapper and event naming once growth's plan is agreed.
- `cat-breeds`: content pipeline for adding a breed (catalog entry, model, icon, odds row).

## 8. Risks for the pipeline itself
- Two threads writing the same file in the shared folder: mitigated by folder ownership in CLAUDE.md; last write wins, so re-read before editing.
- Model aliases: `fable` may not be accepted in agent frontmatter, so game-designer uses `inherit`; run design passes from a Fable main session.
- Rokit versions pinned from memory; `rokit update` on first install and commit.
- Studio MCP tool names and Rojo optional-path syntax come from the plan doc and Rojo 7.4+ docs; if `rojo serve` rejects `default.project.json`, replace the `{ "optional": true, ... }` objects with plain paths and create empty `Packages/` folders.
- Usage: seven agents in parallel burns the Max pool fast. Opus for building, Sonnet for QA chores, Fable only for the design pass.

## 9. Which threads need Fable and which are fine on Opus (2026-10-26)
Fable burns the shared usage pool fastest, so it goes where a wrong call costs the most downstream work. Everything else runs on Opus, and chores on Sonnet or Haiku. A thread can be switched when it is started or when Derek asks it to switch.

| Thread / role | Model | Why |
|---|---|---|
| Design the cat cafe game (game-designer) | Fable | Loop, economy math and balance decisions steer every other thread; low volume, highest leverage. |
| Review cat cafe code (luau-reviewer) | Fable for the first security review of each feature, Opus for re-checks | A missed exploit or data-loss bug is the costliest mistake; re-reviews after fixes are mechanical. |
| Plan studio agents, skills and connectors (lead / setup) | Opus, Fable only for an architecture decision | Mostly CI, config and docs; syncing files is a Sonnet job. |
| Build cat cafe rough draft (luau-engineer) | Opus | Building against a spec; hand one hard bug to Fable, then switch back. |
| Build cat stats and equip best (luau-engineer) | Opus | Scoped feature from a spec with tests. |
| Design cat cafe UI (ui-designer) | Opus | Layouts and client code; repetitive component tweaks can go to Sonnet. |
| Create cat cafe 3D models (asset-artist) | Opus | Blender Python and style guide; re-exports and renames to Sonnet. |
| Animate cats and add VFX (vfx-animator) | Opus | Client code against a list and a budget; repetitive preset tuning can go to Sonnet. |
| Plan cat cafe playtests (qa-playtester) | Sonnet, Opus for test tooling | Test plans, reports and tickets are structured writing; the WebAssembly test runner was a one-off build. |
| Research cat cafe market and monetization (growth-analyst) | Opus | Web research and summaries; the policy calls are already made. |
| Find Roblox dev skills and tools | Sonnet or Haiku | Search and inventory, no judgment calls. |
| Set up purr-pot repo on desktop (remote control) | Sonnet | Terminal chores on Derek's PC. |
| Coordinator (project chat) | Opus | Routing and summaries; nothing it decides needs Fable. |
| Make cat cafe sound and music (sound-designer) | Opus; Sonnet for logging and renames | Sourcing, cue planning and a small client module; the music direction is already in the sound list, and Derek's ear makes the final call. |

Rule of thumb: one Fable pass writes the decision into a doc (GDD, review, decisions.md), then an Opus thread builds from the doc. On Derek's PC the `.claude/agents/*.md` files already pin these models; `game-designer` uses `inherit`, so start design sessions with `/model fable`.
