# Setup guide: Derek's Windows PC

Goal: by the end, Claude Code on your PC can edit Cat Cafe's code in Git, sync it into Roblox Studio with Rojo, drive Studio over MCP (spawn parts, run playtests, take screenshots), and later drive Blender. Budget about 2 hours the first time. Steps 1 to 9 are Phase 0; 10 and 11 are Phase 1 (Blender); 12 is the smoke test that closes Phase 0.

Roblox terms you will meet: a **place** is one world file; an **experience** is the published game that groups places; **Studio** is the editor; a **plugin** is a Studio extension; **Rojo** syncs files on disk into the open place; **MCP** (Model Context Protocol) is the standard that lets Claude call tools exposed by Studio and Blender.

## 1. Accounts
- Roblox account (yours). Later: a Roblox Group to own the game once friends and revenue split are agreed (docs/plan.md section 12).
- GitHub account `derekburnz`. Create a **private** repository named `Cat-Cafe` (it was `purr-pot` until 2026-10-27; GitHub redirects the old URL). Do not add a README or .gitignore; the scaffold has them.

## 2. Git and the repo
```powershell
winget install --id Git.Git -e
winget install --id GitHub.cli -e        # optional, gives you `gh`
git config --global user.name "Derek"
git config --global user.email "<your github email>"
cd ~\Documents
git clone https://github.com/derekburnz/Cat-Cafe.git
```
The repo already holds the scaffold and the first rough draft (pushed from the lead thread on 2026-10-26), so there is nothing to copy. Check it landed:
```powershell
cd ~\Documents\Cat-Cafe
git log --oneline          # three commits: scaffold + code + docs, asset exports, concept previews
```
From here on the GitHub repo is the source of truth. Role threads that run in claude.ai open pull requests against it; the project folder `cat-cafe/` is only a mirror for threads that cannot reach GitHub. After each day of work push, and pull before letting agents loose.

## 3. Claude Code
```powershell
irm https://claude.ai/install.ps1 | iex
```
Restart the terminal, run `claude` in the repo root, sign in with your Max plan. Check `/model` lists Fable 5.1 (update Claude Code if not). Run `/agents` to confirm the seven agents loaded from `.claude/agents/`, and type `/` to see the skills (`/luau-conventions` etc.).

PowerShell may block scripts the first time. Allow local scripts once:
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

## 4. Rokit (toolchain manager)
Rokit installs and pins Rojo, Wally, Selene, StyLua and luau-lsp from `rokit.toml` so every machine matches.
1. Download the latest `rokit-*-windows-x86_64.zip` from https://github.com/rojo-rbx/rokit/releases and extract `rokit.exe`.
2. In the folder you extracted to: `.\rokit.exe self-install`, then close and reopen the terminal.
3. In the repo root: `rokit install`. Rokit asks you to trust each tool author the first time (`rokit trust rojo-rbx/rojo` and so on, or run `rokit install --no-trust-check` once you have read the list).
4. `rokit update` to move the pins to current releases, then commit `rokit.toml`.
5. Check: `rojo --version`, `wally --version`, `selene --version`, `stylua --version`, `luau-lsp --version`.

## 5. Roblox Studio and the dev place
1. Install Studio from https://create.roblox.com and sign in.
2. Create a new experience (Baseplate template). File > Publish to Roblox As > name it **Cat Cafe Dev**, keep it **private**. This is the dev copy agents work in; the public experience comes later and is published from the same place.
3. Game Settings > Security > turn on **Enable Studio Access to API Services** (lets DataStores run in Studio playtests). Leave HTTP requests off.
4. Save often (Ctrl+S publishes to the dev place). Agents can break things; Git has the code, Studio's Version History has the place.

## 6. Studio as an MCP server
1. In Studio: Assistant panel > `...` menu > **Manage MCP Servers** > turn on **Enable Studio as MCP server**.
2. Use **Quick connect** for Claude Code. It writes the server into Claude Code's config. The repo's `.mcp.json` also defines it under the name `Roblox_Studio` using `%LOCALAPPDATA%\Roblox\mcp.bat`; if `/mcp` in Claude Code shows two Studio servers, remove the Quick connect one (`claude mcp remove <name>`) so agents see a single `studio_id`.
3. Restart Claude Code in the repo root. `/mcp` should show `Roblox_Studio` connected and Studio shows a green indicator.
4. Keep one Studio window open while agents work. With several open, agents must pass the right `studio_id` (they can call `list_roblox_studios`).
5. Check the whole setup in one go: in Claude Code type `/roblox-doctor`. It runs `.claude/skills/roblox-doctor/scripts/doctor.sh --json` (needs Git Bash, which came with Git) and reports Rokit tools, Rojo project, Studio MCP, Blender MCP and Open Cloud key status with a fix per line. It is read-only unless you agree to `--fix`.

Roblox's warning applies: an MCP client can read and modify the open place. Only your own Claude Code connects, and only to the dev place.

## 7. Rojo (files -> Studio)
```powershell
rojo plugin install                 # installs the Rojo plugin into Studio
cd games\cat-cafe
rojo serve                          # leave this running while you work
```
In Studio: Plugins tab > Rojo > Connect (default address localhost:34872). Rojo then mirrors `src/` into the place live: `src/server` becomes `ServerScriptService.Server`, `src/client` becomes `StarterPlayer.StarterPlayerScripts.Client`, `src/shared` becomes `ReplicatedStorage.Shared`, and `assets/cat-cafe/rbx/*.rbxm` become `ReplicatedStorage.Assets`. Sync is one way (disk to Studio), which is why rule 2 says never edit those scripts inside Studio.

## 8. Wally (packages)
```powershell
cd games\cat-cafe
wally install
rojo sourcemap default.project.json -o sourcemap.json
```
`Packages/` and `ServerPackages/` are gitignored; every machine runs `wally install`. Optional, for typed package requires: `rokit add JohnnyMorganz/wally-package-types` once at the repo root, then `wally-package-types --sourcemap sourcemap.json Packages/` after each install.

## 9. Editor and the check gate
VS Code is optional but makes agent output easier to read. Install extensions: `JohnnyMorganz.luau-lsp`, `JohnnyMorganz.stylua`, `Kampfkarren.selene-vscode`, `evaera.vscode-rojo`. The repo's `games/cat-cafe/.vscode/settings.json` already points luau-lsp at the Rojo project.

The done gate (rule 6):
```powershell
cd games\cat-cafe
.\check.ps1
```
First run downloads Roblox API types for luau-lsp and Selene's Roblox standard library. Green "All checks passed" means type check, lint and format are clean. Agents run this before saying "done".

API lookups without Studio: `.mcp.json` also starts `roblox_docs` (`uvx mcp-roblox-docs`, no key, published on PyPI). Agents use it to check classes, members, enums and deprecations; it needs `uv` from step 10. Optional: the `roblox-dev-skill` can read a local API dump at `~/RobloxDocs`. To create it, clone https://github.com/MSayib/roblox-dev-skill, read `install.ps1`, then run `.\install.ps1 -DocsOnly`. Without it the skill falls back to the web docs and says so.

## 10. Blender and Blender MCP (Phase 1)
1. Install Blender 5.2 LTS from https://www.blender.org/download/. The generator scripts in `assets/cat-cafe/blender/` run on 4.2 or newer and were written against 5.2; the third-party `blender-*` skills require 5.2. blender-mcp's README only promises 3.0 or newer, so test the connection (step 4 below) right after installing.
2. Install `uv` (Python tool runner): `winget install --id astral-sh.uv -e` (or `irm https://astral.sh/uv/install.ps1 | iex`). `uv` also runs the `roblox_docs` MCP server from step 9.
3. Download `addon.py` from https://github.com/ahujasid/blender-mcp. In Blender: Edit > Preferences > Add-ons > Install > pick the file > enable **Interface: Blender MCP**.
4. In the 3D Viewport press N, open the **BlenderMCP** tab, press **Connect to Claude** (this starts the socket server inside Blender). Leave it running while the asset-artist works. Run only one Blender MCP server at a time.
5. The repo's `.mcp.json` already has the `blender` entry (`uvx blender-mcp`) with `DISABLE_TELEMETRY=true`, because blender-mcp sends a minimal anonymous usage record by default. Restart Claude Code; `/mcp` should show the Studio, blender and roblox_docs servers.
6. Optional, for hand edits in the Blender UI: install the free **ACT: Game Asset Creation Toolset** from https://extensions.blender.org/add-ons/act-game-asset-creation-toolset/ (origin alignment, batch rename, UV atlas tools, batch FBX export). The generator already handles pivots and the palette, so this is a convenience, not a requirement.

## 11. Roblox Blender plugin (Blender -> Studio)
Download from https://github.com/Roblox/roblox-blender-plugin (see https://create.roblox.com/docs/art/modeling/roblox-blender-plugin), install as a Blender add-on, log in with your Roblox account in the add-on panel. Select objects and Upload; they appear in the open Studio session. Calibrate scale once with the 4-stud cube test in the asset-pipeline skill and write the number into `docs/art/style-guide.md`.

## 12. Phase 0 smoke test (closes setup)
With Studio open on Cat Cafe Dev, Rojo connected, `rojo serve` running, and Claude Code in the repo root, ask Claude Code:
1. "Using Studio MCP, insert an anchored Part named PH_SmokeTest at 0,5,0 and screenshot it." A grey block appears in the viewport; the screenshot is saved under `docs/concepts/cat-cafe/`.
2. "Create games/cat-cafe/src/server/Main.server.luau that prints 'Hello from Rojo' and run the check gate." Rojo syncs it; `.\check.ps1` passes.
3. "Start a playtest, read the console, stop it." The console shows the print and no errors.
Commit (`git commit -am "chore: phase 0 smoke test"`), delete PH_SmokeTest, and add a line to `docs/devlog.md`. Phase 0 is done.

## 13. Daily loop
1. `git pull`, `rojo serve` in `games/cat-cafe`, open Studio on the dev place, connect Rojo.
2. `claude` in the repo root. `/model` Opus for building; switch to Fable for design or architecture passes.
3. Ask the lead session for a feature; it delegates to agents in the order designer -> engineer -> reviewer -> QA. You can also address one directly: "use the luau-reviewer agent on the current diff".
4. Agents run `.\check.ps1` and a playtest. You read the "how to test it" notes and try it yourself for two minutes.
5. Commit per feature, push at the end of the day, one line in `docs/decisions.md` when something was decided.

## 14. Troubleshooting
- **Studio MCP not listed in `/mcp`:** check `%LOCALAPPDATA%\Roblox\mcp.bat` exists; re-enable the server in Studio; restart Claude Code. `claude mcp list` shows what is configured.
- **Rojo plugin "version mismatch":** run `rojo plugin install` again after any `rokit update`.
- **`check.ps1` cannot run:** execution policy (step 3). If `Invoke-WebRequest` fails behind a proxy, download `globalTypes.None.d.luau` manually from the luau-lsp repo's `scripts/` folder at the tag matching `luau-lsp --version` into `games/cat-cafe/`, and write that version into `games/cat-cafe/.types-version`.
- **Selene says no Roblox std:** run `selene generate-roblox-std` in `games/cat-cafe`.
- **DataStore errors in playtest:** step 5.3 (API access) and make sure the dev place uses the `CatCafeProfiles` store name from `Config.luau` (Studio adds `_dev`).
- **Blender MCP hangs:** only one Connect to Claude session; close extra Blender windows; `uvx blender-mcp` needs internet the first time to fetch the package.
- **Usage running low:** check Settings > Usage; move chores to Sonnet or Haiku with `/model`.

## 15. Publish from GitHub instead of Studio (once, about 3 minutes)
After this, a thread or the Actions tab publishes the game (`.github/workflows/publish.yml`), so nobody clicks Publish in Studio again. Phone browser works for every step.
1. [create.roblox.com/dashboard/credentials](https://create.roblox.com/dashboard/credentials) > **API Keys** > **Create API Key**. Name: `Cat Cafe GitHub`. Make a new key rather than widening the audio upload key: this one has to accept any IP.
2. **Access Permissions**: add **universe-places**, select the **Cat Cafe** experience, operation **Write** (publishing). Add the **Luau Execution** API (the name contains `luau-execution`), the same experience, operation **Write** (the engine smoke test).
3. **Security > Accepted IP Addresses**: `0.0.0.0/0`, because GitHub's runners get a new IP every run. Expiration is optional.
4. **Save & Generate Key**, then copy it. Roblox shows it once.
5. [github.com/derekburnz/Cat-Cafe/settings/secrets/actions/new](https://github.com/derekburnz/Cat-Cafe/settings/secrets/actions/new): Name `ROBLOX_PUBLISH_KEY`, Secret: the key, **Add secret**. Never paste the key into chat or a file.
6. Optional: on the **Variables** tab of the same page, add `AUTO_PUBLISH` with value `true`. Every main commit whose check passed then goes live by itself. Without it, publish runs only when started.
7. Try it: **Actions > publish > Run workflow**, pick `Saved`. The run summary shows the new version number, and the live game is untouched. `Published` makes it live.

The experience and place ids (10773193456 and 119569792798199) are in the workflow; they are not secret. A Rojo-built place replaces everything in the published place, so anything placed by hand in Studio and not in the repo disappears on the next publish. Today the server builds the whole world from code, so nothing is lost.

## 16. Quiet GitHub email (once, about 1 minute)
Threads open, push and merge PRs from Derek's GitHub account, so GitHub mails that account about all of it. Since PR #248 automerge no longer pushes into PR branches; these two settings stop the rest. Everything stays visible on GitHub, and threads report in the project anyway.
1. [github.com/settings/notifications](https://github.com/settings/notifications) > **System** > **Actions**: open the dropdown and untick **Email**. That ends the "Run failed" mails from threads' unfinished pushes.
2. Same page, **Subscriptions** > **Participating, @mentions and custom**: untick **Email**. That ends the merge, push and comment mails on PRs the threads open.

## 17. Let threads upload images and read bug reports (once, about 2 minutes)
After this, threads upload UI and art images (`.github/workflows/upload-image.yml`) and sounds (`.github/workflows/upload-audio.yml`, so the SecretStore key on the laptop is no longer needed for uploads) and read the friends' in-game bug reports (`.github/workflows/bug-reports.yml`) themselves, with the publish key from step 15. Nothing waits on Studio's Asset Manager or a Studio session any more. Phone browser works.
1. [create.roblox.com/dashboard/credentials](https://create.roblox.com/dashboard/credentials) > **API Keys** > the `Cat Cafe GitHub` key (the one saved as `ROBLOX_PUBLISH_KEY`) > **Edit**.
2. **Access Permissions** > **Add API System**: **assets**, operations **Read** and **Write** (uploading images, which belong to your account like the sounds).
3. **Add API System** again: **universe-datastores**, select the **Cat Cafe** experience, operations `universe-datastores.objects:list` and `universe-datastores.objects:read` only (listing and reading the bug reports; nothing that writes or deletes).
4. **Save Changes**. The key stays the same, so the GitHub secret needs no change. Don't press Regenerate, which would.
5. Try it: **Actions > bug-reports > Run workflow**. The run summary lists today's reports, or says there are 0.

The key still accepts any IP (GitHub's runners need that), so whoever holds it could also upload images as you and read the reports. It lives only in the GitHub secret.

## 18. Required checks for auto-merge (once, about 2 minutes)
Done 2026-10-27 22:14: ruleset `main` (id 25996536) is active with both checks. The steps stay here in case it ever needs making again.

GitHub's auto-merge (Settings > General > Allow auto-merge, on since 2026-10-27) waits only for checks that main requires. Without this step there is nothing to wait for, so GitHub refuses to turn auto-merge on and threads fall back to the `automerge` label. Phone browser works.
1. [github.com/derekburnz/Cat-Cafe/settings/rules](https://github.com/derekburnz/Cat-Cafe/settings/rules) > **New ruleset** > **New branch ruleset**.
2. **Ruleset name**: `main`. **Enforcement status**: **Active**. Leave the bypass list empty.
3. **Target branches** > **Add target** > **Include default branch**.
4. **Rules**: keep **Restrict deletions** and **Block force pushes** ticked. Tick **Require status checks to pass**. Leave **Require branches to be up to date before merging** unticked: nothing pushes main into PR branches any more (that was the email noise), and each check run already tests the PR merged with the latest main.
5. **Add checks**: type `Rojo sourcemap` and pick **Rojo sourcemap, luau-lsp, Selene, StyLua**, then type `Luau unit tests` and pick **Luau unit tests and strict type check (WebAssembly Luau)**. Leave the other rules as they are.
6. **Create**.

After that, a thread turns auto-merge on for each reviewed PR and GitHub merges it once both checks pass. Merges by hand still work once the checks are green.

## 19. Let a publish restart the running servers (once, about 1 minute)
A publish reaches new servers only; servers already running keep the old version until they empty. When a publish changes the save version (cat levels F75 did, save version 12), a player saved on a new server who then joins an old one is kicked. Creator Hub's **Restart servers for updates** fixes that by hand; with this step the publish workflow can do it (`restart_servers` input), and `restart-servers.yml` restarts them without publishing. Phone browser works.
1. [create.roblox.com/dashboard/credentials](https://create.roblox.com/dashboard/credentials) > **API Keys** > the `Cat Cafe GitHub` key > **Edit**.
2. **Access Permissions** > **Add API System**: **universe**, select the **Cat Cafe** experience, operation `universe:write`.
3. **Save Changes**. Don't press Regenerate.

`universe:write` also lets the key change some experience settings through the Universes API. The key lives only in the GitHub secret, and no workflow uses it for anything but the restart.
