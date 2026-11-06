--!strict
-- A working cat stands at its station in its role's outfit (features.md F25, data-model section 5; Derek 2026-10-27:
-- outfits by role; 2026-11-02: the standing worker S). CafeService clones the worker (AssetRegistry.cloneCat with
-- "work", Pose "work"; the seated body B while a worker is missing) with its pivot on the station point, and the
-- dressing poses its front legs and keeps the role's held thing (CatDress.workPose); resting cats at the odd nap
-- spots sit on B, with nothing on. The dressing
-- itself is shared (shared/CatDress), so the intro's seated waiter wears the same pieces; here the pieces come from
-- AssetRegistry.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetRegistry = require(script.Parent.AssetRegistry)
local CatDress = require(ReplicatedStorage.Shared.CatDress)

local CatPose = {}

function CatPose.scaleOf(model: Model): number
	return CatDress.scaleOf(model)
end

local function cloneAsset(assetName: string): Model?
	return if AssetRegistry.has(assetName) then AssetRegistry.clone(assetName) else nil
end

-- Puts `role`'s outfit on a working cat (CatDress.dress, which poses a worker too), each piece AssetRegistry's model
-- while it has one, and (#1624) the cafe's Looks accessory `accessoryId` where it fits. Returns how many pieces went
-- on.
function CatPose.dress(model: Model, role: string, accessoryId: string?): number
	return CatDress.dress(model, role, cloneAsset, accessoryId)
end

-- #1624: swaps a dressed working cat's accessory for `accessoryId` (nil: none) in place (CatDress.setAccessory).
function CatPose.setAccessory(model: Model, role: string, accessoryId: string?)
	CatDress.setAccessory(model, role, accessoryId, cloneAsset)
end

-- #1624: recolours a dressed working cat's outfit in the Looks uniform `uniformId` (nil: Classic, as built). The cat
-- keeps the id in its UniformStyle attribute, which client copies of it (CafeWalk's walkers) read.
function CatPose.wearUniform(model: Model, uniformId: string?)
	CatDress.wearUniform(model, uniformId)
end

return CatPose
