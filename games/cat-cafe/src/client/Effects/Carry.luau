--!strict
-- The cat in each player's arms (Derek 2026-10-28: "hold it in your arms crossed arms and it should be either awake
-- loafing or sitting in your arms"). While a character carries a cat (`CarryingCatId`, set by CatService with the
-- HeldCat) Tackle.luau folds its arms across its chest by `Carry.weight` (Avatar.carryArms).
--
-- The cat itself is the server's (#1964, Gameplay-Engineer's #1968): the HeldCat is welded to the torso already
-- folded into the loaf, so every client draws the same cat with nothing done here. Until then this client drew its
-- own posed copy on the arms and hid the HeldCat, which on live servers showed only a grey block (#1480). Show other
-- cats still hides other players' held cats through WorldController's HiddenLocal. Nothing here replicates or fires
-- a remote.

local Avatar = require(script.Parent.Avatar)
local Presets = require(script.Parent.Presets)

local Carry = {}

local weights: { [Model]: number } = {}

local function alive(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- How far `character`'s arms are folded for a carried cat this frame, 0 to 1, `dt` seconds after the last call;
-- `near` is false beyond the animation radius, where the arms let go.
function Carry.weight(character: Model, _rig: Avatar.Rig, dt: number, near: boolean): number
	local carrying = Avatar.carrying(character:GetAttribute("CarryingCatId"), alive(character))
	local weight =
		Avatar.holdWeight(weights[character] or 0, carrying and near, dt, Presets.carryPose)
	weights[character] = weight
	return weight
end

-- Lets go of a character that left or was rebuilt.
function Carry.forget(character: Model)
	weights[character] = nil
end

function Carry.start() end

return Carry
