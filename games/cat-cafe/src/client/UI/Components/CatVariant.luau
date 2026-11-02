--!strict
-- Gold cats (Derek, 2026-10-27: "shiny" is now "gold") and rainbow cats (F99, rainbow-coat.md). The server sends
-- variant "gold" or "rainbow", the Gold attribute or a model's Variant, goldCollection and rainbowCollection, and
-- migrates older saves, so one place says what counts as which coat.
--   isGold(variant)              true for "gold"
--   isRainbow(variant)           true for "rainbow"
--   coat(variant)                "rainbow", "gold" or "base"
--   word(variant)                "Rainbow ", "Gold " or "", before a cat's kind ("Rainbow Epic Tabby")
--   multiplier(variant)          what the coat multiplies a cat's money by: x3 rainbow (RainbowMultiplier), the
--                                Config's GoldMultiplier gold, 1 else
--   collection(state)            state.goldCollection, else empty
--   rainbowCollection(state)     state.rainbowCollection, else empty
-- Pure, no Theme, so the cloud spec runner can load it.

local Config = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config")
) :: any

local CatVariant = {}

export type Coat = "base" | "gold" | "rainbow"

function CatVariant.isGold(variant: string?): boolean
	return variant == "gold"
end

function CatVariant.isRainbow(variant: string?): boolean
	return variant == "rainbow"
end

function CatVariant.coat(variant: string?): Coat
	if variant == "rainbow" then
		return "rainbow"
	elseif variant == "gold" then
		return "gold"
	end
	return "base"
end

function CatVariant.word(variant: string?): string
	if variant == "rainbow" then
		return "Rainbow "
	elseif variant == "gold" then
		return "Gold "
	end
	return ""
end

function CatVariant.multiplier(variant: string?): number
	if variant == "rainbow" then
		return tonumber(Config.RainbowMultiplier) or 3
	elseif variant == "gold" then
		return tonumber(Config.GoldMultiplier) or 1.5
	end
	return 1
end

function CatVariant.collection(
	state: { goldCollection: { [string]: number }? }
): { [string]: number }
	return state.goldCollection or {}
end

function CatVariant.rainbowCollection(
	state: { rainbowCollection: { [string]: number }? }
): { [string]: number }
	return state.rainbowCollection or {}
end

return CatVariant
