--!strict
-- A cat alive in a card's picture (Derek 2026-11-03 01:10, on the Bellhop Cat's card at the free-cat stand: "the bell
-- hop cat animation of moving left and right is kind of laggy and slow maybe make it a walking animation or sitting or
-- sleeping etc"). UI-Engineer's CatPortrait turned its whole model side to side in the ViewportFrame; this keeps the
-- model still at the portrait's own view and moves the cat the way it moves in the world, through Pose: it breathes,
-- blinks, flicks its ears, swishes its tail and looks about (Logic.portrait), and the Bellhop Cat rings its bell and
-- tips its cap every `every` seconds (Presets.portrait). CatPortrait calls Portrait.play on the model once it has
-- placed it and keeps the stop function; nil back means this model cannot be posed piece by piece (a placeholder or
-- a Motor6D rig) and the portrait keeps its own motion. Nothing here touches the world or fires a remote.

local RunService = game:GetService("RunService")

local Logic = require(script.Parent.Logic)
local Pose = require(script.Parent.Pose)

local Portrait = {}

-- Poses `model`, the cat `catId` (already in `frame`'s ViewportFrame, where the portrait put it), every frame while
-- `frame` shows, and returns the function that stops it and puts the model back as it was; nil when the model cannot
-- be posed.
function Portrait.play(model: Model, frame: GuiObject, catId: string?): (() -> ())?
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			(descendant :: BasePart).Anchored = true -- Pose binds an unanchored body only to its Motor6Ds
		end
	end
	local rig = Pose.bind(model)
	if rig == nil or rig.usesMotors then
		return nil
	end
	local bound = rig :: Pose.Rig
	local floor = Pose.floor(bound)
	local attribute = model:GetAttribute("CatId")
	local id = catId or (if type(attribute) == "string" then attribute else nil)
	local started = os.clock()
	local function draw(): boolean
		local ok = pcall(function()
			if Pose.read(bound) then
				Pose.hold(bound, floor)
				Pose.draw(bound, Logic.portrait(id, os.clock() - started, bound.kind), -1)
			end
		end)
		return ok
	end
	if not draw() then
		pcall(Pose.release, bound)
		return nil -- the engine would not move these parts here: the portrait keeps its own motion
	end
	local connection: RBXScriptConnection? = nil
	local function stop()
		if connection ~= nil then
			connection:Disconnect()
			connection = nil
			pcall(Pose.release, bound)
		end
	end
	connection = RunService.Heartbeat:Connect(function()
		-- a frame that left the game, or a model taken out of it (the card swapped or closed it), ends the loop
		if
			not frame:IsDescendantOf(game)
			or not model:IsDescendantOf(frame)
			or (frame.Visible and not draw())
		then
			stop()
		end
	end)
	return stop
end

return Portrait
