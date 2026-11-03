--!strict
-- A quick cloud dip over each jump between far-apart places in the intro (Derek 2026-11-03 00:50: "In the tutorial
-- video in game make the locations cuts smoother", #958). Gameplay-Engineer's IntroController fires
-- `Moments.IntroCut(at, nextSeconds)` Intro.CUT_LEAD seconds before each such jump, `at` being os.clock() at the jump
-- and `nextSeconds` how long the cut after it lasts (none inside or into the cannon shot, which has its own clouds).
-- The cannon's own clouds (VFX-Agent's Clouds.luau) rush in to cover the screen just before the jump and part just
-- after it (Presets.introCut), so the place changes behind them. Around a short cut (the camp tour's) the dip is
-- shorter on that side (Logic.introDip): the cut after a jump is `nextSeconds`, and the cut before it is the last
-- dip's `nextSeconds` when that cut ends at this jump. Skip (`Moments.IntroEnd`) clears a dip still on screen.
-- This screen only; listening only.

local Workspace = game:GetService("Workspace")

local Moments = require(script.Parent.Parent.Moments)

local Clouds = require(script.Parent.Clouds)
local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)

local IntroCut = {}

local started = false
local showingUntil = 0 -- os.clock() until which a dip may still be on screen
local lastJump: { at: number, after: number }? = nil -- the last dip's jump and the cut after it

-- Plays the dip for a jump at os.clock() `at` into a cut of `after` seconds (nil: long): the plan's `cut` lines up
-- with the jump, however early the hook came.
function IntroCut.dip(at: number, after: number?)
	local p = Presets.introCut
	local last = lastJump
	local before = if last ~= nil and math.abs(last.at + last.after - at) < 0.05
		then last.after
		else nil
	lastJump = if after ~= nil then { at = at, after = after } else nil
	local plan = Logic.introDip(p, before, after)
	local lead = math.clamp(at - os.clock(), 0, p.cut)
	Clouds.play(Workspace:GetServerTimeNow() + lead - p.cut, plan, p.tint)
	showingUntil = os.clock() + lead - p.cut + plan.partTo
end

function IntroCut.start()
	if started then
		return
	end
	started = true
	Moments.IntroCut:Connect(function(at: number, nextSeconds: number)
		IntroCut.dip(at, if nextSeconds > 0 then nextSeconds else nil)
	end)
	Moments.IntroEnd:Connect(function()
		lastJump = nil
		if os.clock() < showingUntil then
			showingUntil = 0
			Clouds.stop()
		end
	end)
end

return IntroCut
