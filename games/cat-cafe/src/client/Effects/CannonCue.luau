--!strict
-- The phone drop between the bowl cat's tame and Tier 2's rank up (Design-Agent, 2026-11-17,
-- Design-Agent/dropoff-2026-11-17/bowl-tame-to-rankup-phone.md): a bowl-first player tames the bowl cat with 2 cats
-- and needs a third, which means the whole first hand catch: open the Cat Cannon, fly, find a stray, catch it. While
-- Tier 2 is still short of cats (ProfileSync's `rankUpShort` above 0, sent under rankUpRightAway) and the player is
-- in the hometown (their cafe or Town, no World.Zones box but "Cafe"), the HUD's Cannon button (CatCafeHUD.Travel.
-- Cannon) gets one gold glow (RankUpPulse's) every `every` seconds until it is pressed. Once pressed it stops for the
-- session. The waiting stray in the Alleyway already has the tutorial strip's marker (UIController, #5031), so it
-- gets nothing here.
-- Behind its own switch `cannonCue`, read straight (`== true`), so it is off until Gameplay-Engineer lists it in
-- LiveFlags and the store says true, after Growth's Thu Nov 19 per-step read. Reduce Motion: a glow every
-- `calmEvery` seconds. Listening only: no remotes, no game state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LiveFlags = require(ReplicatedStorage.Shared.LiveFlags)

local Net = require(script.Parent.Parent.Net)

local Context = require(script.Parent.Context)
local Presets = require(script.Parent.Presets)
local RankUpPulse = require(script.Parent.RankUpPulse)
local ScreenFx = require(script.Parent.ScreenFx)

local CannonCue = {}

local GUI = "EffectsCannonCue"

local started = false
local short = 0 -- Tier 2's cats still short, from the last ProfileSync
local pressed = false -- the Cannon button was pressed this session
local linked: GuiObject? = nil -- the Cannon button whose presses are watched

-- Whether the Cannon button glows now: the switch is exactly true, Tier 2 is still short of cats, the player is in
-- the hometown (`zone` nil or "Cafe") and has not pressed the Cannon button this session. Pure.
function CannonCue.due(
	switch: unknown,
	catsShort: unknown,
	zone: string?,
	wasPressed: boolean
): boolean
	return switch == true
		and type(catsShort) == "number"
		and (catsShort :: number) > 0
		and (zone == nil or zone == "Cafe")
		and not wasPressed
end

-- The World.Zones box the character stands in, as WorldController reads it; nil in the street.
local function zoneAt(position: Vector3): string?
	local world = Workspace:FindFirstChild("World")
	local zones = if world ~= nil then world:FindFirstChild("Zones") else nil
	if zones == nil then
		return nil
	end
	for _, box in zones:GetChildren() do
		if box:IsA("BasePart") then
			local offset = box.CFrame:PointToObjectSpace(position)
			local half = box.Size / 2
			if
				math.abs(offset.X) <= half.X
				and math.abs(offset.Y) <= half.Y
				and math.abs(offset.Z) <= half.Z
			then
				return box.Name
			end
		end
	end
	return nil
end

local function cannonButton(): GuiObject?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local hud = if playerGui ~= nil then playerGui:FindFirstChild("CatCafeHUD") else nil
	local travel = if hud ~= nil then hud:FindFirstChild("Travel", true) else nil
	local button = if travel ~= nil then travel:FindFirstChild("Cannon") else nil
	return if button ~= nil and button:IsA("GuiObject") then button :: GuiObject else nil
end

-- Watches the button's presses (its own GuiButton or the one inside it): any press ends the cue for the session.
local function link(button: GuiObject)
	if linked == button then
		return
	end
	linked = button
	local targets: { Instance } = { button }
	for _, inner in button:GetDescendants() do
		table.insert(targets, inner)
	end
	for _, target in targets do
		if target:IsA("GuiButton") then
			(target :: GuiButton).Activated:Connect(function()
				pressed = true
			end)
		end
	end
end

local function step()
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local zone = if root ~= nil and root:IsA("BasePart")
		then zoneAt((root :: BasePart).Position)
		else nil
	local switch =
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. Presets.cannonCue.flag)
	if not CannonCue.due(switch, short, zone, pressed) then
		return
	end
	local button = cannonButton()
	if button == nil or not ScreenFx.shown(button) then
		return
	end
	link(button)
	local gui = ScreenFx.gui(GUI, Presets.rankUpPulse.displayOrder)
	if gui ~= nil then
		RankUpPulse.glow(gui, button, Presets.rankUpPulse)
	end
end

function CannonCue.start()
	if started then
		return
	end
	started = true
	Net.on("ProfileSync", function(state: unknown)
		if type(state) ~= "table" then
			return
		end
		local value = (state :: { [string]: unknown }).rankUpShort
		short = if type(value) == "number" then value else 0
	end)
	task.spawn(function()
		while true do
			step()
			local c = Presets.cannonCue
			task.wait(if Context.reducedMotion() then c.calmEvery else c.every)
		end
	end)
end

return CannonCue
