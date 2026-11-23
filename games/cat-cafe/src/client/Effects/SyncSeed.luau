--!strict
-- #5677, switch syncSeed: effects start after the loading screen, so they miss the join's first ProfileSync and a
-- count read from it stays unknown until the next sync (NetHint never showed on the first approach). This reads the
-- count from the state the UI already holds (UIController.state), required lazily since UIController requires
-- Effects at load. Listening only: it fires no remote, the next ProfileSync still wins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SyncSeed = {}

SyncSeed.FLAG = "syncSeed"

-- stats.catsCaught from a PlayerState shaped table, or nil. Pure.
function SyncSeed.catsCaught(state: unknown): number?
	if type(state) ~= "table" then
		return nil
	end
	local stats = (state :: { [string]: unknown }).stats
	if type(stats) ~= "table" then
		return nil
	end
	local n = (stats :: { [string]: unknown }).catsCaught
	return if type(n) == "number" then n else nil
end

-- The UI's latest state, or nil when the switch is off or the UI has none yet.
function SyncSeed.state(): unknown
	if ReplicatedStorage:GetAttribute("LiveFlag_" .. SyncSeed.FLAG) ~= true then
		return nil
	end
	local controllers = (script.Parent.Parent :: any):FindFirstChild("Controllers")
	local module = if controllers ~= nil then controllers:FindFirstChild("UIController") else nil
	if module == nil then
		return nil
	end
	local ok, ui: any = pcall(require, module)
	if not ok or type(ui) ~= "table" then
		return nil
	end
	return ui.state
end

-- The save's catch count as the UI holds it, behind the switch.
function SyncSeed.seedCaught(): number?
	return SyncSeed.catsCaught(SyncSeed.state())
end

return SyncSeed
