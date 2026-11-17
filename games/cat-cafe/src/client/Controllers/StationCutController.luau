--!strict
-- #5112 (Derek 2026-11-17, Design-Agent's station-unlock-cutscene.md; Gameplay-Engineer handed the trigger to
-- Motion-FX): right after a rank up to a tier in shared/StationCut, once per account, the camera cuts to the station
-- it unlocks (Effects/StationUnlockCut). The server has already asked Roblox to stream that station's spot in
-- (CafeService); this waits for the player to be free (not carrying a cat, flying or in another cut or the intro), then
-- up to StationCut.WAIT seconds for the station to arrive. While the cut plays the HUD, toasts, pop-ups and any open
-- window are put away the way a camera cut tip does (UI.tips.clearStage), so the cards that follow wait for it. The
-- key goes into tipsSeen (TipSeen, logged once as tip_shown: skipped "yes" for a skip or a fallback). A station that
-- never arrives, or a camera another script holds, gets an "Unlocked" toast instead. Nothing while `stationCut` is off.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local IntroController = require(script.Parent.IntroController)
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Moments = require(script.Parent.Parent.Moments)
local Net = require(script.Parent.Parent.Net)
local StationCut = require(Shared:WaitForChild("StationCut"))
local StationUnlockCut = require(script.Parent.Parent.Effects.StationUnlockCut)
local UI = require(script.Parent.Parent.UI)
local UIController = require(script.Parent.UIController)

local StationCutController = {}

local POLL = 0.1
local FREE_MOST = 30 -- seconds to wait for the player to be free before giving the toast instead

local started = false
local asked: { [number]: boolean } = {} -- tiers handled this session (the save hears TipSeen a moment later)

local function on(): boolean
	return ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. StationCut.FLAG) == true
end

local function ui(): any
	return UI :: any
end

-- Not mid catch, carry or flight, nor in another cut or the intro.
local function free(): boolean
	local character = Players.LocalPlayer.Character
	if character == nil then
		return false
	end
	if
		character:GetAttribute("CarryingCatId") ~= nil
		or character:GetAttribute("Launching") == true
	then
		return false
	end
	local tips = ui().tips
	return not ui().cutscene.on
		and not (tips ~= nil and tips.staged == true)
		and not IntroController.playing()
		and not StationUnlockCut.playing()
end

local function stationOf(tag: string): Model?
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("Model") and instance:IsDescendantOf(Workspace) then
			return instance :: Model
		end
	end
	return nil
end

-- Waits up to `seconds` for `check`; whether it came true.
local function waitFor(seconds: number, check: () -> boolean): boolean
	local untilAt = os.clock() + seconds
	while not check() do
		if os.clock() >= untilAt then
			return false
		end
		task.wait(POLL)
	end
	return true
end

local function stage(held: boolean)
	local tips = ui().tips
	local clear: any = if tips ~= nil then tips.clearStage else nil
	if type(clear) == "function" then
		(clear :: (boolean) -> ())(held)
	end
end

local function fallback(tier: number)
	local station = StationUnlockCut.stationFor(tier)
	if station ~= nil then
		ui().toast(string.format("%s unlocked! %s", station.name, station.line), "good")
	end
	Net.fire("TipSeen", StationCut.key(tier), true)
end

local function ranked(tier: number)
	local state = UIController.state
	local seen = if state ~= nil then state.tipsSeen else nil
	local tag = StationCut.due(tier, seen, on())
	if tag == nil or asked[tier] then
		return
	end
	asked[tier] = true
	local function arrived(): boolean
		return stationOf(tag :: string) ~= nil
	end
	task.spawn(function()
		if not waitFor(FREE_MOST, free) or not waitFor(StationCut.WAIT, arrived) then
			fallback(tier)
			return
		end
		stage(true)
		local playing = StationUnlockCut.play(tier, function(outcome: string)
			stage(false)
			Net.fire("TipSeen", StationCut.key(tier), outcome == "skipped")
			return
		end)
		if not playing then
			stage(false)
			fallback(tier)
		end
	end)
end

function StationCutController.start()
	if started then
		return
	end
	started = true
	Moments.RankUp:Connect(ranked)
end

return StationCutController
