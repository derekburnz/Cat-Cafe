--!strict
-- A working cat sits at its station in its role's outfit (features.md F25, data-model section 5; Derek 2026-10-27:
-- outfits by role, A walks and B sits). CafeService clones the seated body (AssetRegistry.cloneCat with sitting) with
-- its pivot on the station point; resting cats at the odd nap spots sit on it too, with nothing on. The dressing
-- itself is shared (shared/CatDress), so the intro's seated waiter wears the same pieces; here the pieces come from
-- AssetRegistry.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetRegistry = require(script.Parent.AssetRegistry)
local CatDress = require(ReplicatedStorage.Shared.CatDress)

local CatPose = {}

function CatPose.scaleOf(model: Model): number
	return CatDress.scaleOf(model)
end

-- Puts `role`'s outfit on a seated cat (CatDress.dress), each piece AssetRegistry's model while it has one.
-- Returns how many pieces went on.
function CatPose.dress(model: Model, role: string): number
	return CatDress.dress(model, role, function(assetName: string): Model?
		return if AssetRegistry.has(assetName) then AssetRegistry.clone(assetName) else nil
	end)
end

return CatPose
