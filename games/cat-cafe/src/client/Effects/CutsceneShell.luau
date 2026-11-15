--!strict
-- What every full cutscene shares (the Rift Run, the Dragon Keep's stage-up): hiding this player's windows, markers
-- and labels while it holds the screen, and switching the character's controls off and back on. Client only.

local Players = game:GetService("Players")

local CutsceneShell = {}

-- The cutscenes' own ScreenGuis, which stay up while every other window, marker and label hides.
local OURS = {
	EffectsRiftRun = true,
	EffectsBigTraitCut = true,
	EffectsBigTraitScene = true,
	EffectsBigTraitLadder = true,
	EffectsDragonRise = true,
}

-- Hides every ScreenGui and BillboardGui of this player's but the cutscenes' own (and any that turns up meanwhile).
-- Returns the putting back, which is safe to call more than once.
function CutsceneShell.hideWindows(): () -> ()
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return function() end
	end
	-- Review-QA on #4029: the HUD's pointer arrow (a marker drawn over the world) showed through, so billboards in
	-- the PlayerGui hide too, at any depth, and one whose own code switches it back on (the arrow did for its first
	-- second in the realm) is switched off again at once
	local hidden: { LayerCollector } = {}
	local watches: { RBXScriptConnection } = {}
	local function hide(child: Instance)
		if not (child:IsA("ScreenGui") or child:IsA("BillboardGui")) then
			return
		end
		local gui = child :: LayerCollector
		if gui.Enabled and not OURS[gui.Name] then
			gui.Enabled = false
			table.insert(hidden, gui)
			table.insert(
				watches,
				gui:GetPropertyChangedSignal("Enabled"):Connect(function()
					if gui.Enabled then
						gui.Enabled = false
					end
				end)
			)
		end
	end
	for _, child in playerGui:GetDescendants() do
		hide(child)
	end
	local added = playerGui.DescendantAdded:Connect(hide)
	local back = false
	return function()
		if back then
			return
		end
		back = true
		added:Disconnect()
		for _, watch in watches do
			watch:Disconnect()
		end
		for _, gui in hidden do
			if gui.Parent ~= nil then
				gui.Enabled = true
			end
		end
	end
end

-- The PlayerModule's controls, or nil without the default player scripts (as BigTraitCut).
function CutsceneShell.controls(): any?
	local scripts = Players.LocalPlayer:FindFirstChildOfClass("PlayerScripts")
	local module = if scripts ~= nil then scripts:FindFirstChild("PlayerModule") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local requireAny: any = require -- Roblox's own PlayerModule is not in the Rojo tree
	local ok, controlModule = pcall(function(): any
		return requireAny(module):GetControls()
	end)
	return if ok then controlModule else nil
end

function CutsceneShell.setControls(module: any?, on: boolean)
	if module == nil then
		return
	end
	pcall(function()
		if on then
			module:Enable()
		else
			module:Disable()
		end
	end)
end

return CutsceneShell
