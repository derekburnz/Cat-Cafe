# tests/ -> ReplicatedStorage.Tests (only with tests.project.json)

Owner: qa-playtester. Unit tests for pure modules (no Roblox services needed at load time).

| File | What |
|---|---|
| `TestKit.luau` | Small TestEZ-compatible framework: describe / it / expect, hooks, skip and focus. Runs in Studio and in a plain Luau VM. |
| `StudioRunner.luau` | Finds `*.spec` ModuleScripts under a folder, requires them, runs them with TestKit. |
| `specs/*.spec.luau` | One spec file per module under test. `TestKit.spec.luau` is the harness self-test. |

## Writing a spec

```lua
--!strict
return function()
	local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

	describe("Config", function()
		it("customers spawn at a sane rate", function()
			expect(Config.CustomerSpawnSeconds).to.be.a("number")
			expect(Config.CustomerSpawnSeconds >= 1).to.equal(true)
		end)
	end)
end
```

Rules: a spec returns a function. Inside it, `describe`, `it`, `expect`, `beforeEach`, `afterEach`, `beforeAll`, `afterAll`, `itSKIP`, `itFOCUS`, `describeSKIP`, `describeFOCUS` are globals. `expect(x)` supports `to.equal`, `to.be.ok()`, `to.be.near(n, limit)`, `to.be.a("type")`, `to.throw("part of message")`, `never`, plus `to.deepEqual(t)` and `to.contain(item)`.

Only test modules that can load without Roblox services (DataStoreService, Players, RunService...). Anything else is covered by `docs/playtests/test-plan.md` instead.

## Running

**In the cloud or on any machine with Node 20+** (no Studio needed):

```
cd games/cat-cafe/tools/cloudcheck
npm install          # once
npm test             # runs every spec
npm run analyze      # strict type check + lint, a stand-in for luau-lsp analyze
```

**In Roblox Studio** (gives the real Roblox globals): start `rojo serve tests.project.json` instead of the default project, connect the Rojo plugin, then run this in the command bar or via the Studio MCP `execute_luau` tool:

```lua
local run = require(game:GetService("ReplicatedStorage").Tests.StudioRunner)
local s = run(nil, { verbose = true })
return string.format("%d passed, %d failed, %d skipped", s.passed, s.failed, s.skipped)
```

`tests.project.json` is the default project plus the `Tests` folder, so the game itself is unchanged. Never publish a place that has `ReplicatedStorage.Tests` in it.
