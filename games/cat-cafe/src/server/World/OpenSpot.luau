--!strict
-- #5038 follow-up (Sync's PC run of #5049): a waiting Park stray sat wedged against the gate's low wall and a pillar,
-- where a player on foot could not net it. OpenSpot.clear tells whether nothing solid stands near a point: no
-- collidable part whose top is more than STEP studs over the floor within `radius`, other than a cat's (a model
-- with a CatId) or anything in `exclude`.
--   OpenSpot.clear(at, floorY, radius, exclude) -> boolean

local Workspace = game:GetService("Workspace")

local OpenSpot = {}

OpenSpot.STEP = 1.5 -- studs over the floor a part may stand and still be ground (a kerb, a root)

local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true

function OpenSpot.clear(at: Vector3, floorY: number, radius: number, exclude: { Instance }): boolean
	params.FilterDescendantsInstances = exclude
	for _, part in Workspace:GetPartBoundsInRadius(at, radius, params) do
		if part.Position.Y + part.Size.Y / 2 > floorY + OpenSpot.STEP then
			local model = part:FindFirstAncestorWhichIsA("Model")
			if model == nil or model:GetAttribute("CatId") == nil then
				return false
			end
		end
	end
	return true
end

return OpenSpot
