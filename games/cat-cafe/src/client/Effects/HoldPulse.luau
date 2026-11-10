--!strict
-- The first catch's held ring (#2920, #2913): while the ring waits frozen on its target for the press, gold rings
-- swell off it about once a second, so a new player sees where and when to press. Source: the Catch screen's
-- `Moments.CircleHold(ringIndex)` (#2932); the pulse lives as long as that ring shows in CatCafeCatchCircles and
-- stops after Presets.holdPulse.most seconds. Screen only, through ScreenFx; none with Reduce Motion (the prompt
-- label still shows). Listening only: no remotes, no game state.

local Players = game:GetService("Players")

local Context = require(script.Parent.Context)
local Moments = require(script.Parent.Parent.Moments)
local Presets = require(script.Parent.Presets)
local ScreenFx = require(script.Parent.ScreenFx)

local HoldPulse = {}

local started = false
local token = 0

-- The held circle's ring on the catch screen, while it shows.
local function ringOf(index: number): GuiObject?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local screen = if playerGui ~= nil then playerGui:FindFirstChild("CatCafeCatchCircles") else nil
	local holder = if screen ~= nil then screen:FindFirstChild("Circle" .. index, true) else nil
	if holder == nil or not holder:IsA("GuiObject") then
		return nil
	end
	local ring = holder:FindFirstChild("Ring", true)
	local object: GuiObject = if ring ~= nil and ring:IsA("GuiObject")
		then ring :: GuiObject
		else holder :: GuiObject
	if not ScreenFx.shown(object) then
		return nil
	end
	return object
end

local function held(index: number)
	if Context.reducedMotion() then
		return
	end
	token += 1
	local mine = token
	local p = Presets.holdPulse
	task.spawn(function()
		local began = os.clock()
		while mine == token and os.clock() - began < p.most do
			local ring = ringOf(index)
			if ring == nil then
				return -- pressed, or the catch closed
			end
			local gui = ScreenFx.gui("EffectsHoldPulse", p.displayOrder)
			if gui == nil then
				return
			end
			local across = math.max(ring.AbsoluteSize.X, ring.AbsoluteSize.Y)
			ScreenFx.ring(
				gui,
				ScreenFx.centre(gui, ring),
				across * p.from,
				across * p.to,
				Presets.palette.golden,
				p.seconds
			)
			task.wait(p.gap)
		end
	end)
end

function HoldPulse.start()
	if started then
		return
	end
	started = true
	local moment = (Moments :: any).CircleHold
	if moment ~= nil then
		moment:Connect(function(index: unknown)
			if type(index) == "number" then
				held(index)
			end
		end)
	end
end

return HoldPulse
