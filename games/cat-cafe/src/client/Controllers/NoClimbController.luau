--!strict
-- Climbing only at real ladders (#4073). A character resting against anything the engine reads as a ladder (thin
-- parts stacked 1 to 3 studs apart: a railing, a board on posts, a hedge's bumps) flips between Climbing and standing
-- many times a second. Roblox's default Animate script loads the climb and idle clips afresh on every flip, which ran
-- players into "AnimationTrack limit of 64 tracks exceeded" (212,952 warnings on 2026-11-13) and made avatars jitter
-- there. The models are being smoothed one by one; this stops the cause for every spot, known or not: the Climbing
-- state is off on this player's own character except near one of the game's real ladders.
--
-- The real ladders are the art's `_Climb` parts (rbx_export.py): an invisible TrussPart behind the rungs of each
-- cannon's ladder, the Park slide's and the Great Oak's. Within NEAR studs of one, climbing is on as before; past FAR
-- it goes off again (two numbers so it does not switch back and forth at the edge).
--
-- Roblox terms: a Humanoid is the part of a character that walks, jumps and climbs; each of those is a "state".
-- SetStateEnabled(state, false) keeps the Humanoid from entering that state. A TrussPart is the engine's own ladder
-- block. A player's own character is simulated on their own device, so setting it here is what counts; it sends
-- nothing to the server.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local NoClimbController = {}

local NEAR = 7 -- studs from the character's root to a ladder's truss: climbing goes on
local FAR = 10 -- past this from every truss it goes off again
local CHECK_SECONDS = 0.2

-- Whether climbing should be on, given the nearest ladder's distance and whether it is on now. Pure.
function NoClimbController.wanted(nearest: number?, on: boolean): boolean
	if nearest == nil then
		return false
	end
	return nearest <= NEAR or (on and nearest <= FAR)
end

-- Studs from `at` to the nearest ladder truss within FAR, nil when there is none.
local function nearestLadder(at: Vector3, params: OverlapParams): number?
	local nearest: number? = nil
	for _, part in Workspace:GetPartBoundsInRadius(at, FAR, params) do
		if part:IsA("TrussPart") then
			-- to the truss's box, not its centre: a tall ladder's foot is far from its middle
			local inBox = part.CFrame:PointToObjectSpace(at)
			local half = part.Size / 2
			local out = Vector3.new(
				math.max(math.abs(inBox.X) - half.X, 0),
				math.max(math.abs(inBox.Y) - half.Y, 0),
				math.max(math.abs(inBox.Z) - half.Z, 0)
			)
			if nearest == nil or out.Magnitude < nearest then
				nearest = out.Magnitude
			end
		end
	end
	return nearest
end

local function watch(character: Model)
	local found = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if found == nil or not found:IsA("Humanoid") or root == nil or not root:IsA("BasePart") then
		return
	end
	local humanoid, rootPart = found :: Humanoid, root :: BasePart
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local on = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	while character.Parent ~= nil and humanoid.Health > 0 do
		local want = NoClimbController.wanted(nearestLadder(rootPart.Position, params), on)
		if want ~= on then
			on = want
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, on)
		end
		task.wait(CHECK_SECONDS)
	end
end

function NoClimbController.start()
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(function(character)
		watch(character)
	end)
	local character = player.Character
	if character ~= nil then
		task.spawn(watch, character)
	end
end

return NoClimbController
