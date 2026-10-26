---
name: luau-conventions
description: How Purr Pot Luau is written and laid out: strict mode, naming, server/client/shared folders, one Service or Controller per ModuleScript, the typed Remotes module, UI-in-code helper and comment style. Use before writing or reviewing any Luau in games/cat-cafe/src.
---

# Luau conventions for Purr Pot

Luau is Roblox's typed Lua dialect. Files end in `.luau`. Rojo (`games/cat-cafe/default.project.json`) maps folders on disk to the Roblox instance tree, so a file's location decides where and how it runs.

## 1. File types and where they go
| Disk | Becomes | Runs on |
|---|---|---|
| `src/server/Main.server.luau` | Script in `ServerScriptService.Server` | server only |
| `src/server/Services/*.luau` | ModuleScripts | server (required by Main) |
| `src/client/Main.client.luau` | LocalScript in `StarterPlayerScripts.Client` | each player's device |
| `src/client/Controllers/*.luau`, `src/client/UI/*.luau` | ModuleScripts | client |
| `src/shared/*.luau` | ModuleScripts in `ReplicatedStorage.Shared` | both (never trust the client here) |

One system per ModuleScript. A **Service** (server) or **Controller** (client) is a table with `Init()` and `Start()`. `Init` wires dependencies and creates state; `Start` connects events and begins loops. Main calls every `Init` before any `Start`, so services can require each other in `Init` without ordering bugs.

## 2. Every file starts the same way
```lua
--!strict
-- CafeService: customers arrive, cats serve them, coins are paid. Server authoritative.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
```
Order: strict directive, one-line purpose comment, `game:GetService` calls, shared requires, sibling requires, constants, module table. StyLua's `sort_requires` keeps requires alphabetical within a block.

## 3. Naming
- Files and ModuleScripts: `PascalCase` (`CatService.luau`). Folders: `PascalCase` too (`Services`, `UI`, `Components`).
- Variables and functions: `camelCase`. Module tables and types: `PascalCase`. Constants: `UPPER_SNAKE`.
- Private helpers: local functions above the module table; no leading underscore needed.
- Instances created in code: `PascalCase` names (`CatSpawnPoints`, `PH_Counter` for placeholders).
- Remote names are verbs from the client's point of view (`RequestCatch`) or past-tense facts from the server (`CatCaught`).

## 4. Service template (server)
```lua
--!strict
-- CatService: spawns stray cats in the alley, validates catch attempts, grants cats to profiles.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local Guard = require(Shared:WaitForChild("Guard"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local RateLimit = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("RateLimit"))

local CatService = {}

local DataService -- set in Init
local activeCats: { [string]: Types.StrayCat } = {}
local catchLimiter = RateLimit.new(Config.Cats.CatchRemotesPerSecond)

local function tryCatch(player: Player, catId: unknown)
	if not catchLimiter:allow(player) then
		return
	end
	if not Guard.isCatId(catId) then
		return
	end
	local cat = activeCats[catId :: string]
	if not cat then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - cat.Position).Magnitude > Config.Cats.CatchRange then
		return
	end
	activeCats[catId :: string] = nil
	DataService.AddCat(player, cat.BreedId)
	Remotes.get("CatCaught"):FireClient(player, catId, cat.BreedId)
end

function CatService.Init(services: { [string]: any })
	DataService = services.DataService
end

function CatService.Start()
	Remotes.get("RequestCatch").OnServerEvent:Connect(tryCatch)
	task.spawn(function()
		while true do
			task.wait(Config.Cats.SpawnIntervalSeconds)
			-- spawn logic here
		end
	end)
end

return CatService
```

## 5. Main bootstrap (server)
```lua
--!strict
-- Main: loads every Service, runs Init on all, then Start on all.
local servicesFolder = script.Parent:WaitForChild("Services")
local services: { [string]: any } = {}

for _, module in servicesFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		services[module.Name] = require(module)
	end
end
for name, service in services do
	if service.Init then
		service.Init(services)
	end
	print(`[Server] {name} initialised`)
end
for _, service in services do
	if service.Start then
		task.spawn(service.Start)
	end
end
```
The client `Main.client.luau` does the same for `Controllers` and then `UI`.

## 6. Remotes: one shared list, typed
`src/shared/Remotes.luau` is the only place RemoteEvents are created. Server creates the folder; client waits for it.
```lua
--!strict
-- Remotes: single source of truth for client <-> server messages.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type RemoteName =
	"RequestServe" | "RequestBuy" | "RequestCatch" -- client -> server
	| "ProfileChanged" | "CatSpawned" | "CatCaught" | "OrderUpdated" -- server -> client

local NAMES: { RemoteName } = {
	"RequestServe", "RequestBuy", "RequestCatch",
	"ProfileChanged", "CatSpawned", "CatCaught", "OrderUpdated",
}

local Remotes = {}
local folder: Folder

if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.get(name: RemoteName): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
```
Argument contracts live in a comment above each name and in `Guard.luau` as type guards (see remote-security-checklist). Prefer RemoteEvents; use a RemoteFunction only when the client needs a reply right now (shop purchase result) and always wrap the client call in `pcall`.

## 7. Shared data modules
- `Config.luau`: tuning numbers grouped by system (`Config.Cafe.CoinsPerServe`). Numbers come from `docs/design/cat-cafe/tuning.md`; keep the doc and the file in sync.
- `Catalog.luau`: every purchasable item and cat breed with a stable string id (`"upgrade_table_2"`, `"cat_tabby"`). Ids never change once a profile has saved them.
- `Types.luau`: `export type` for profiles, cats, orders. Client receives trimmed copies (`ClientProfile`), never the server record.

## 8. Client controllers and UI
- Controllers hold client state and expose `Signal`s (`InventoryController.Changed`) and getters. UI modules subscribe; UI never fires remotes directly.
- UI is built in code with a small helper:
```lua
local function create<T>(className: string, props: { [string]: any }, children: { Instance }?): T
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	return instance :: any
end
```
- Layouts via `UIListLayout` / `UIGridLayout`, sizes in `UDim2.fromScale` with `UIAspectRatioConstraint` or `UISizeConstraint`, never pixel offsets alone.

## 9. Style and comments
- StyLua formats; do not argue with it. Tabs, 100 columns, double quotes.
- Comment the why, not the what. A one-line header per file; a short comment above any validation branch explaining the exploit it blocks.
- No globals, no `wait()` (use `task.wait()`), no `spawn()` (use `task.spawn`/`task.defer`), no `Instance.new` with a parent argument.
- Connections you create you disconnect: store in a table per player and clear on `PlayerRemoving`.
- Errors: `warn` for recoverable, `error` only for programmer mistakes. Never silently swallow a DataStore failure.

## 10. Done gate
`cd games/cat-cafe` then `./check.ps1` (or `./check.sh`). It runs `rojo sourcemap`, `luau-lsp analyze`, `selene`, `stylua --check`. All four must pass, then a Studio playtest with no new console errors.
