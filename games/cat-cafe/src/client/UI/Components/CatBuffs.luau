--!strict
-- What lifts a cat's money per second, as short chips for the Cats screen (F97 section 5; Derek 2026-10-28: "The cat
-- stars don't quite make sense on the menu now so remove that if not necessary and if cats have any specific buffs
-- show that instead"). Charm stars show nowhere now; charm stays in the formula and the detail shows it as a percent.
--   chips(cat)        up to three, in this order: "+50% as Barista" in its favourite role (kind "favourite", the
--                     screen adds a heart) or "Likes: Barista" anywhere else, "Gold +50%" (or "Rainbow x3" on a rainbow
--                     cat, F99 rainbow-coat.md section 2), "Lv 12 +22%" (above level 1)
--   charmText(charm)  "Charm +12%", "Charm -8%", "Charm +0%"
-- The numbers come from Config and shared/CatStats, the server's own formula. Pure, so the cloud spec runner checks it.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CatStats = require(Shared:WaitForChild("CatStats"))
local Config = require(Shared:WaitForChild("Config"))

local CatBuffs = {}

export type Chip = { kind: string, text: string } -- kind: "favourite", "likes", "gold", "rainbow" or "level"

export type Cat = {
	role: string?, -- the favourite role's display name ("Barista"), nil without one
	favourite: boolean, -- working in that role now
	gold: boolean,
	rainbow: boolean?,
	level: number?,
}

-- 1.5 -> "+50%", 0.92 -> "-8%"
local function bonus(multiplier: number): string
	local percent = math.floor((multiplier - 1) * 100 + 0.5)
	return (if percent < 0 then "-" else "+") .. math.abs(percent) .. "%"
end

function CatBuffs.chips(cat: Cat): { Chip }
	local chips: { Chip } = {}
	local role = cat.role
	if role ~= nil and role ~= "" then
		if cat.favourite then
			table.insert(chips, {
				kind = "favourite",
				text = ("%s as %s"):format(bonus(Config.FavoriteMultiplier or 1.5), role),
			})
		else
			table.insert(chips, { kind = "likes", text = "Likes: " .. role })
		end
	end
	if cat.rainbow == true then
		local times = tonumber((Config :: any).RainbowMultiplier) or 3
		table.insert(chips, { kind = "rainbow", text = ("Rainbow x%g"):format(times) })
	elseif cat.gold then
		table.insert(
			chips,
			{ kind = "gold", text = "Gold " .. bonus(CatStats.variantMultiplier("gold")) }
		)
	end
	local level = cat.level
	if level ~= nil and level > 1 then
		table.insert(chips, {
			kind = "level",
			text = ("Lv %d %s"):format(math.floor(level), bonus(CatStats.levelMultiplier(level))),
		})
	end
	return chips
end

function CatBuffs.charmText(charm: number): string
	return "Charm " .. bonus(CatStats.charmMultiplier(charm))
end

return CatBuffs
