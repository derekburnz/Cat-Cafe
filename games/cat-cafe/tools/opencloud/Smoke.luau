-- Engine smoke test for Cat Cafe, run by tools/opencloud/run-luau.sh against a Saved version of the place
-- (.github/workflows/publish.yml). A Luau Execution task runs in a real Roblox server, but the place's own
-- scripts do not run and physics is off. So this does by hand what Main.server.luau does first: require every
-- shared and server ModuleScript, then build the placeholders and the world. Services are not started, so no
-- DataStore session opens and no player is needed. Any error fails the task.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local started = os.clock()
local loaded = 0
local failures = {}

local function requireAll(root)
	for _, item in root:GetDescendants() do
		if item:IsA("ModuleScript") then
			local ok, err = pcall(require, item)
			if ok then
				loaded += 1
			else
				table.insert(failures, string.format("%s: %s", item:GetFullName(), tostring(err)))
			end
		end
	end
end

local Shared = ReplicatedStorage:FindFirstChild("Shared")
local Server = ServerScriptService:FindFirstChild("Server")
assert(
	Shared ~= nil and Server ~= nil,
	"the place has no ReplicatedStorage.Shared or ServerScriptService.Server"
)

requireAll(Shared)
requireAll(Server)
if #failures > 0 then
	error(
		string.format(
			"%d of %d modules failed to load:\n%s",
			#failures,
			loaded + #failures,
			table.concat(failures, "\n")
		)
	)
end

local placeholders = require(Server.World.AssetRegistry).ensurePlaceholders()
local world = require(Server.World.WorldBuilder).build()
assert(#world.plots > 0, "WorldBuilder built no plots")

local summary = string.format(
	"[CatCafe] engine smoke ok in %.2fs: %d modules, %d plots, %d placeholder models",
	os.clock() - started,
	loaded,
	#world.plots,
	placeholders
)
print(summary)
return summary
