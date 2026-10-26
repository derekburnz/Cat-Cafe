---
name: roblox-dev-plan
description: Master context and operating plan for Derek's AI-assisted hobby Roblox studio with friends. Use at the start of any planning, design, coding, art, playtest or growth task for these games, and when setting up agents, skills or MCP connections for them.
---

# Roblox Studio Plan: AI-Assisted Game Dev With Friends

Last updated: 2026-10-25. Companion file: `Game Ideas.docx` (raw ideas from the group).

---

## 0. How to use this file (instructions for Claude)

This file is the source of truth for how this studio works. At the start of a conversation:

1. Read this file and `Game Ideas.docx`.
2. Work out which phase we are in (section 7) and which role is being asked for (section 5). If the request spans roles, say which roles you are acting as.
3. Follow the studio rules in section 9 without being reminded.
4. If a request is cheap to redo, make a reasonable assumption, state it and proceed. If it is expensive to redo or contradicts this plan, ask one focused question first.
5. When a decision is made, propose a one-line entry for `docs/decisions.md` (date, decision, why).

Where work happens:

- **This Project (claude.ai or Claude Desktop):** planning, design docs, pitches, reviews, research, deciding between options.
- **Claude Code on Derek's PC:** building. It connects to Roblox Studio and Blender through MCP and runs the agents and skills defined below.
- Local MCP servers (Studio, Blender) are reachable from Claude Desktop and Claude Code, not from the claude.ai website.

---

## 1. Who and why

**Derek (lead dev / producer):** fourth-year IT (Networking) student who also works as an IT analyst (Linux servers, networking, troubleshooting). Comfortable with terminals, config files, Git basics and debugging. New to Luau, Roblox Studio, 3D art and game design. Explain Roblox-specific concepts the first time they come up; skip general IT basics.

**Friends:** idea contributors and playtesters, possibly builders. Number and roles still to be confirmed (see section 12).

**Goals, in priority order:**

1. Learn a real AI-assisted dev workflow (multi-agent, MCP, skills) that transfers to other work.
2. Produce a portfolio piece for the resume (shipped game, repo, write-up, metrics).
3. Have fun building with friends.
4. Find out whether it can make money. Treat revenue as a bonus signal, not the success criterion.

**Constraints:** side project alongside school and work, so scope must stay small. Claude usage on the Max plan is one shared pool across claude.ai, Claude Desktop and Claude Code.

---

## 2. Models and usage budget

| Model | Use it for | Notes |
|---|---|---|
| **Claude Fable 5.1** | Game design docs, architecture, systems that touch many files, hard bugs, cross-checking an agent's work | On Max, Fable counts toward the plan's usage limits and can use up to 50% of the weekly limit. It burns usage faster than other models, so reserve it for hard thinking. Needs a recent Claude Code version. |
| **Claude Opus 5.5** | Default for day-to-day building: features, assets, playtests, research | Main workhorse. |
| **Claude Sonnet 5.5 / Haiku 5.5** | Chores: lint fixes, renames, summarizing playtest notes, file searches | Keeps the weekly budget for real work. |

Practical habits: start a Fable session for a design or architecture pass, write the result to a doc, then switch to Opus to build from that doc. Check Settings > Usage weekly.

Avoid connecting Roblox Studio's built-in Assistant to Claude through an API key: API usage is billed separately from the Max plan. Drive Studio from Claude Code over MCP instead, which uses the plan.

---

## 3. Money reality check

Facts to keep expectations honest (verify current numbers before relying on them):

- **DevEx (cash out):** standard rate is $0.0038 USD per earned Robux, with a 30,000 earned Robux minimum ($114). Robux earned from verified 18+ US players in certain eligible games converts at $0.0054.
- **Creator Rewards:** Roblox pays 5 Robux per "active spender" who spends at least 10 minutes in your experience that day (with extra conditions), plus Audience Expansion rewards for bringing in new or lapsed users. Rewards are held for 60 days.
- **Purchases:** game passes, developer products and private servers. Roblox takes a marketplace cut before DevEx.
- Most Roblox games earn little or nothing. Retention (players coming back on day 1 and day 7) and session length drive both discovery and Creator Rewards, so those are the metrics to watch.

Conclusion for planning: optimize for a small, polished, replayable core loop and good retention numbers. Those also make the best resume story.

---

## 4. Toolchain and connections

### 4.1 Required (Phase 0)

| Tool | What it does for us | Setup notes |
|---|---|---|
| **Roblox Studio (built-in MCP server)** | Lets Claude Code read and edit the open place, run Luau, generate meshes and materials, start playtests, simulate player input, read console output and take viewport screenshots | In Studio: open Assistant > `...` > Manage MCP Servers > turn on "Enable Studio as MCP server". Use Quick connect for Claude Code (and Claude Desktop if wanted). Green indicator confirms the connection. |
| **Claude Code** | Main build environment; runs subagents, skills and MCP servers | Keep it updated so Fable 5.1 is selectable in `/model`. |
| **Git + private GitHub repo** | Version history, rollback after bad agent edits, portfolio evidence | Commit before every agent session. |
| **Rokit** | Pins tool versions in `rokit.toml` so every friend gets identical tools with `rokit install` | Install first; it installs the rest. |
| **Rojo** | Syncs Luau files on disk into Studio so code lives in Git and agents edit normal files | `rojo serve` + Rojo Studio plugin. |
| **Selene, StyLua, luau-lsp** | Lint, format and type-check Luau; the "done" gate for agent code | Wire into one check script (section 9, rule 6). |
| **Wally** | Package manager for common libraries (promises, signals, data saving) | Add packages only when needed. |

Studio MCP tools the agents will lean on most:

- Code: `script_read`, `script_search`, `script_grep`, `multi_edit`, `execute_luau`
- World and assets: `search_game_tree`, `inspect_instance`, `generate_mesh`, `generate_material`, `generate_procedural_model`, `search_asset`, `insert_asset`
- Testing: `start_stop_play`, `character_navigation`, `user_keyboard_input`, `user_mouse_input`, `get_console_output`, `screen_capture`, plus the built-in `subagent` (explore and playtest types)
- Docs: `http_get` (Roblox Engine API and Creator docs) and `skill`
- Every call takes a `studio_id`; use `list_roblox_studios` when more than one Studio window is open.

Warning from Roblox: MCP clients can read and modify the open place. Only connect clients we trust and work in a dev copy of each place.

### 4.2 Recommended (Phase 1)

| Tool | What it does for us | Setup notes |
|---|---|---|
| **Blender + Blender MCP** (`ahujasid/blender-mcp`) | Lets the asset agent build and edit 3D models in Blender from prompts | Install `uv`, install the `addon.py` add-on in Blender, start its server from the add-on panel, then `claude mcp add blender uvx blender-mcp`. Run only one instance of the server at a time. |
| **Roblox Blender plugin** (official) | Links a Roblox account and sends models from Blender straight into the Studio session | Install from Roblox's GitHub; completes the Blender to Studio path. |
| **Roblox Team Create** | Friends edit the same place together in Studio | Turn on once friends start building. |
| **Roblox Group** | Group owns the games so friends can be collaborators and any earnings can be paid out from one place | Agree on ownership and any revenue split in writing before launch. |
| **Feedback form** (Google Form to Sheet, or a Discord channel) | Structured playtest feedback the QA agent can summarize | Fields in the `playtest-report` skill. |

### 4.3 Optional, later

- Community Studio MCP servers (for example `robloxstudio-mcp`): only if the official server lacks something specific. The official built-in server is Roblox's recommended option.
- Roblox Open Cloud API keys for automated asset uploads or publishing. Store keys in environment variables, never in the repo.
- Anthropic's `skill-creator` skill to draft and test the custom skills in section 6.

---

## 5. Agent roster

The main Claude Code session is the **studio lead**: it breaks work down, hands tasks to subagents and checks results. Subagents live in `.claude/agents/<name>.md`. Each runs in its own context window, so they keep the main session clean.

Notes for building these files:

- Omit the `tools` line to let an agent inherit every tool, including the Studio and Blender MCP tools. List tools explicitly to restrict an agent (read-only reviewers, research-only agents).
- Use model aliases your Claude Code version accepts (check `/model`). If `fable` is not accepted as an alias, use `inherit` and run that work from a Fable main session.

| Agent | Role | Model | Writes code? |
|---|---|---|---|
| `game-designer` | Planning: ideas, core loops, GDDs, economy, change proposals | Fable | No |
| `luau-engineer` | Builds gameplay, UI logic, data saving, remotes | Opus | Yes |
| `luau-reviewer` | Read-only review for exploits, data loss, performance, style | Opus | No |
| `asset-artist` | Models, materials, environments, lighting, visual consistency | Opus | Asset scripts only |
| `qa-playtester` | Automated playtests, test plans, turns friend feedback into tickets | Sonnet (Opus for tricky bugs) | No |
| `growth-analyst` | Player base, comparable games, analytics, monetization, store page, marketing | Opus | No |

### 5.1 game-designer

```markdown
---
name: game-designer
description: Drafts and revises game design docs, core loops, progression, economy and pitches; evaluates friends' suggestions and scope changes. Use for new ideas, "should we add X" and any scope or design question.
tools: Read, Write, Edit, Glob, Grep, WebSearch, WebFetch
model: fable
---
You are the game designer for a small hobby Roblox studio run by a beginner developer and his friends.
For every proposal:
- State the core loop in one sentence (what the player does every 30 seconds, every session, every week).
- List what is in and out of scope for the current milestone.
- Estimate effort as S, M or L and name the riskiest part.
- Propose the smallest testable version first.
- Flag anything touching paid random items, trading, PvP or user-generated text (see the monetization-policy and remote-security-checklist skills).
- Borrow mechanics from reference games freely, but never their characters, names or art.
Write outputs to docs/design/<game>/. Never write game code.
```

### 5.2 luau-engineer

```markdown
---
name: luau-engineer
description: Implements gameplay systems in Luau (server and client), UI logic, RemoteEvents and data saving, and fixes bugs. Use for any feature build or bug fix.
model: opus
---
You build Roblox gameplay in Luau for a Rojo-managed project.
- Edit scripts as files under games/<game>/src/ (Rojo syncs them). Do not edit Rojo-managed scripts inside Studio through MCP; Rojo will overwrite them.
- Use Studio MCP for inspecting the game tree, building non-script instances, starting playtests, reading console output and screenshots.
- Follow the luau-conventions and remote-security-checklist skills.
- Server is authoritative. Validate every RemoteEvent argument on the server.
- Run the check gate (sourcemap, luau-lsp analyze, selene, stylua --check) before saying a task is done.
- End every task with: files changed, how to test it, known gaps.
```

### 5.3 luau-reviewer

```markdown
---
name: luau-reviewer
description: Read-only reviewer that checks Luau changes for exploits, data loss, performance problems and style after luau-engineer finishes. Use proactively after any code change.
tools: Read, Grep, Glob, Bash
model: opus
---
You review code you did not write. Do not edit files.
Check, in order: client trust and remote validation, rate limiting, data saving safety (session locking, retries, no data wipes), memory leaks (unconnected events, loops without exits), performance on mobile, then style.
Report findings as: severity (blocker, should-fix, nit), file and line, what goes wrong for a player or exploiter, suggested fix.
```

### 5.4 asset-artist

```markdown
---
name: asset-artist
description: Creates and cleans up 3D assets, materials, environments and lighting using Blender MCP and Roblox Studio's generation tools, and keeps visuals consistent with the style guide. Use for any visual, prop, environment or rough concept task.
model: opus
---
You own how the games look. Follow docs/art/style-guide.md for the active game.
- Rough drafts: use Studio generate_procedural_model, generate_mesh and generate_material, then screen_capture the result for review.
- Final assets: model in Blender via Blender MCP, keep triangle counts within the style guide budget, clean topology, pivot at the base, consistent scale and naming (Game_Category_Name), then send to Studio with the Roblox Blender plugin.
- Before inserting any Creator Store asset, inspect it for scripts and remove anything unexpected. Prefer our own assets or Roblox-made ones.
- Never recreate copyrighted characters, logos or art from reference games.
- After each visual task, capture 2 to 4 screenshots and save them to docs/concepts/<game>/ with a one-line caption each.
```

### 5.5 qa-playtester

```markdown
---
name: qa-playtester
description: Runs automated playtests in Roblox Studio, executes test plans, captures console errors and screenshots, then turns friends' playtest feedback into prioritized bug and balance tickets. Use after features land and after every friend playtest.
model: sonnet
---
You test, you do not fix.
- Automated: start_stop_play, character_navigation, user_keyboard_input and user_mouse_input to run the test plan; get_console_output for errors; screen_capture for evidence.
- Human feedback: summarize with the playtest-report skill. Separate bugs, balance issues, confusion points and feature requests. Count how many testers raised each point.
- Output tickets to docs/playtests/<date>.md ranked by impact on the core loop.
```

### 5.6 growth-analyst

```markdown
---
name: growth-analyst
description: Researches comparable Roblox games and trends, plans analytics events, designs monetization that follows Roblox policy and drafts store page assets plus launch and update plans. Use for "how do we get players", "how does this make money" and launch prep.
tools: Read, Write, Edit, Glob, Grep, WebSearch, WebFetch
model: opus
---
You care about players finding the game, enjoying it and coming back.
- Research comparable Roblox games before recommending anything; cite sources and dates.
- Define the analytics plan (AnalyticsService funnel, economy and custom events) before launch so retention and session length can be measured.
- Monetization must follow the monetization-policy skill. No pressure tactics aimed at kids: no fake timers, no pay-to-win walls.
- Store page: title, icon and thumbnail concepts, description, tags.
- Update cadence and small, honest marketing (devlog posts, short gameplay clips, friends' social accounts). Track results.
```

---

## 6. Skills to create

Project skills live in `.claude/skills/<name>/SKILL.md` and can be called with `/<name>`. Keep each under 500 lines; put long reference material in extra files inside the skill folder.

| Skill | Used by | Contents |
|---|---|---|
| `luau-conventions` | engineer, reviewer | `--!strict`, naming, folder layout (server, client, shared), one system per ModuleScript, typed RemoteEvent wrappers, comment style |
| `remote-security-checklist` | engineer, reviewer, designer | Never trust the client; validate types, ranges and ownership; rate-limit remotes; server-side cooldowns; filter all user-generated text with Roblox's text filtering before showing it to others; DataStore retries and session locking |
| `asset-pipeline` | asset-artist | Blender export settings, triangle budgets, UVs and textures, naming, pivot and scale, Roblox Blender plugin upload steps, import checks in Studio |
| `gdd-onepager` | designer | Template: hook, core loop, session loop, progression, social, monetization, scope for prototype, risks, open questions |
| `playtest-report` | qa | Feedback form fields, summary format, ticket format, severity scale |
| `monetization-policy` | designer, growth, engineer | Paid random items rules (below), PolicyService checks, Creator Rewards behaviour, no dark patterns |
| `concept-visuals` | asset-artist, designer | The Phase 1 rough-visual process in section 8 |
| `devlog` | lead | After each milestone: what was built, what the agents did, what broke, metrics, one screenshot; written so it can feed a portfolio page and resume bullets |

Key content for `monetization-policy` (from Roblox's paid random items guidelines):

- Any random outcome bought with Robux, directly or through currency bought with Robux (spins, eggs, chests, gacha pulls, re-roll tokens), must show every outcome's odds as percentages summing to 100% before purchase.
- Luck boosts, pity systems and rate-up items must explain their numeric effect before purchase, and displayed odds must update while they are active.
- Use `PolicyService:GetPolicyInfoForPlayerAsync()` and respect `ArePaidRandomItemsRestricted` and `IsPaidItemTradingAllowed` per player (hide, block or replace the feature where restricted).
- Offering a free, earnable path to the same random item is encouraged.

---

## 7. Phases and milestones

| Phase | Rough length | Goal | Exit criteria |
|---|---|---|---|
| **0. Setup** | 1 week | Working pipeline | Studio and Blender MCP connected, repo with Rokit toolchain, CLAUDE.md, 6 agents, first 3 skills, test: an agent spawns a part, a script prints to console, a playtest runs and a screenshot is saved |
| **1. Concepts and rough visuals** | 2 weeks | Pick one game with evidence | One-pager, comps research, graybox screenshots, HUD mockup and score for each idea; friends vote; decision logged |
| **2. Prototype (vertical slice)** | 4 to 6 weeks | Core loop playable end to end | A new player can complete one full loop in under 10 minutes; data saves; no blocker bugs from the reviewer |
| **3. Friends alpha** | 2 to 4 weeks | Is it fun and does it hold attention | 2+ playtest rounds, tickets closed, analytics events firing, style guide applied to everything visible |
| **4. Soft launch** | Ongoing | Real players, real numbers | Public release, store page done, retention and session length measured for 2 weeks |
| **5. Iterate or pivot** | Ongoing | Decide with data | Write-up for the portfolio; either keep updating or start game 2 reusing systems |

---

## 8. First assignment: evaluate the three ideas and draft rough visuals

Ideas from `Game Ideas.docx`:

1. **Wandering merchant** (like The Trail: Frontier): travel on foot between settlements, scavenge, craft and sell goods to players and NPCs, unlock locations, deal with stamina, weather and other obstacles (still to be defined), see other players on the map, PvP looting.
2. **Cat-themed auto battler**: inspired by Cookie Run Kingdom, AFK Arena and Infinite Gacha.
3. **Cat cafe**: cats earn money serving customers; money upgrades the cafe, decorations and tools; catch cats in alleys and the wild by grabbing or luring with food; inspired by Steal an Egg and Spin for a Fisherman.

### 8.1 For each idea, produce

1. A `gdd-onepager` with the core loop stated in one sentence.
2. Answers or proposed options for every open item in the doc (merchant "other obstacles", cat cafe "other stuff", what the auto battler's twist is beyond the theme).
3. Comparable Roblox games (growth-analyst): what is working, how they monetize, what players complain about. Test the claim that nobody has done the merchant concept.
4. Prototype scope: the smallest version that proves the loop is fun, with an S, M or L estimate per system.
5. Risks: technical (netcode, exploits, data), content volume, policy (paid random items, PvP with a young audience, trading).
6. Rough visuals (8.2).
7. A score using the matrix in 8.3.

### 8.2 Rough visual process (`concept-visuals`)

Claude does not generate photos or paintings, so rough visuals come from the real tools we will build with. That also tests the pipeline early.

- **Mood and direction:** 2 or 3 short style options per game in words (palette with hex codes, shape language, camera, lighting mood), each with a name. Friends pick one.
- **Studio graybox:** one hero area per game, built with `generate_procedural_model` and `generate_mesh` plus lighting, captured with `screen_capture` from 3 or 4 angles.
  - Merchant: a road leaving a small town, a market stall, the player's pack or cart, weather.
  - Auto battler: a battle arena with a lineup of 5 cat units and a team-select screen.
  - Cat cafe: cafe interior with counter and tables, an alley outside with a catchable cat.
- **One Blender hero asset per game** (merchant pack or cart, a signature cat, the cafe counter) to set the art style and prove the Blender to Studio path.
- **HUD mockup** as an HTML or SVG page: merchant stamina, weather and inventory; battler lineup, battle speed and pull screen with odds shown; cafe earnings, upgrades and cat collection.
- Save everything to `docs/concepts/<game>/` and assemble a single comparison page for the friend vote.

### 8.3 Scoring matrix (1 to 5, weights in brackets)

| Criterion | Weight |
|---|---|
| Friends' fun vote | 3 |
| Scope fits a beginner and a part-time schedule | 3 |
| Proven demand on Roblox | 2 |
| Hook that stands out | 2 |
| Monetization fit within Roblox policy | 1 |
| How much the agents can carry (code and asset generation) | 1 |
| Portfolio and resume value | 1 |

### 8.4 Starting hypothesis (to test, not a decision)

- **Cat cafe** looks like the smallest scope and sits in well-trodden Roblox territory (tycoon plus collection), which makes it a good first game for learning the pipeline.
- **Merchant** is the most original but the biggest build: open world travel, an economy, crafting and PvP looting all need anti-exploit work and balancing. Strong candidate for game 2, reusing inventory, economy and NPC systems from game 1.
- **Auto battler** is heavy on content and balance, and its gacha layer falls under the paid random items rules.

The game-designer and growth-analyst should confirm or overturn this with the research above before the vote.

---

## 9. Studio rules (copy the short form into CLAUDE.md)

1. **Back up first.** Commit to Git before any agent session, and point agents at a dev copy of each place, never the live published one.
2. **Code lives in files.** Rojo-managed scripts are edited under `src/`. Studio MCP is for the world, non-script instances, playtests, console and screenshots.
3. **Server authority.** The client asks, the server decides. Validate every remote argument. Rate-limit remotes.
4. **Pipeline per feature:** designer spec -> engineer build -> reviewer check -> QA playtest. No agent signs off its own work.
5. **Small steps.** One feature per branch and commit, each with a test plan.
6. **Done means the gate passes:** `rojo sourcemap`, `luau-lsp analyze`, `selene`, `stylua --check`, plus a playtest with no new console errors.
7. **Creator Store assets** get inspected for scripts before use.
8. **Original IP only.** Mechanics can be inspired by other games; characters, names, art and audio must be ours or properly licensed.
9. **Paid random items** follow the `monetization-policy` skill every time.
10. **Young audience by default.** No dark patterns, filter user text, match content to the maturity label we declare to Roblox.
11. **Usage budget.** Fable for design, architecture and hard bugs; Opus for building; Sonnet or Haiku for chores.
12. **Decisions** go in `docs/decisions.md` with the date and reason.
13. **Secrets** (Open Cloud keys, tokens) stay in environment variables, never in the repo or in chat.
14. **Explain Roblox concepts** the first time they come up; Derek knows networking and Linux, not Luau.

---

## 10. Repo layout

```
roblox-studio/
  CLAUDE.md                  short rules (section 9) + pointers to docs
  .mcp.json                  project MCP servers (Roblox_Studio, blender)
  .claude/
    agents/                  the six agent files from section 5
    skills/<name>/SKILL.md   skills from section 6
  docs/
    plan.md                  this file
    ideas/Game Ideas.docx
    design/<game>/gdd.md
    concepts/<game>/         screenshots, HUD mockups, comparison page
    art/style-guide.md
    playtests/<date>.md
    decisions.md
    devlog.md
  games/<game>/
    default.project.json
    rokit.toml  wally.toml  selene.toml  stylua.toml  .luaurc
    src/server/  src/client/  src/shared/
  assets/<game>/
    blender/*.blend
    exports/*.fbx
```

Example `.mcp.json` for Windows (Studio's Quick connect can set up the Studio entry for you instead):

```json
{
  "mcpServers": {
    "Roblox_Studio": {
      "command": "cmd.exe",
      "args": ["/c", "%LOCALAPPDATA%\\Roblox\\mcp.bat"]
    },
    "blender": {
      "command": "cmd",
      "args": ["/c", "uvx", "blender-mcp"]
    }
  }
}
```

---

## 11. Capturing it for the resume

Record as you go so the write-up is easy:

- **Architecture diagram** of the agent pipeline (lead, six subagents, MCP connections to Studio and Blender, Git, check gate).
- **Devlog** entry per milestone with a screenshot.
- **Metrics** after launch: visits, peak concurrent players, day 1 and day 7 retention, average session length.
- **Networking angle:** Roblox's client-server replication, remote validation and exploit prevention map directly onto network security concepts. Worth calling out.
- Resume bullet template: "Built and launched [game] on Roblox using a multi-agent Claude Code pipeline ([n] specialized subagents, Roblox Studio and Blender MCP integrations, automated playtesting); reached [metric]."

---

## 12. Open questions for Derek and friends

1. How many friends are in, and who wants which role (ideas, building, art, testing)?
2. Windows or Mac for each person? (Studio MCP and Blender MCP commands differ.)
3. Realistic hours per week for Derek and for each friend?
4. Which account or Roblox Group owns the games, and how would any earnings be split?
5. Any budget for Roblox ads at launch, or organic only?
6. Target player age band for the first game?

---

## 13. References

- Roblox Studio MCP server: https://create.roblox.com/docs/studio/mcp
- Studio MCP multi-agent update (Aug 2026): https://devforum.roblox.com/t/studio-mcp-multi-agent-improvements-and-connected-ai-clients/4820583
- Blender MCP: https://github.com/ahujasid/blender-mcp
- Roblox Blender plugin: https://create.roblox.com/docs/art/modeling/roblox-blender-plugin
- Claude Code subagents: https://code.claude.com/docs/en/sub-agents
- Claude Code skills: https://code.claude.com/docs/en/skills
- Fable models on your plan: https://support.claude.com/en/articles/15424964-claude-fable-models-on-your-plan
- DevEx: https://create.roblox.com/docs/production/monetization/developer-exchange
- Creator Rewards: https://create.roblox.com/docs/creator-rewards
- Paid random items policy: https://create.roblox.com/docs/production/monetization/paid-random-items
