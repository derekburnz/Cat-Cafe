--!strict
-- #1955 (auto-equip.md): the toast after Auto Equip moves cats. One swap names the cat, its job and what it adds,
-- "Auto Equip: Mochi is now your Barista (+$12/s)"; swaps that land within MERGE_SECONDS of the first become one toast,
-- "Auto Equip: 3 cats moved to better jobs". Pure (the money formatter is passed in), so the specs load it.
--   text(swaps, money) -> string?   nil with no swaps

export type Swap = { catName: string?, role: string?, perSecond: number? }

local AutoEquipToast = {}

AutoEquipToast.MERGE_SECONDS = 2

-- The swaps worth naming: a cat name and a job each, at most MAX of them read from one remote.
AutoEquipToast.MAX = 20
function AutoEquipToast.clean(raw: unknown): { Swap }
	local out: { Swap } = {}
	if type(raw) ~= "table" then
		return out
	end
	for _, swap in raw :: { any } do
		if #out >= AutoEquipToast.MAX then
			break
		end
		if
			type(swap) == "table"
			and type(swap.catName) == "string"
			and type(swap.role) == "string"
		then
			local rate = swap.perSecond
			table.insert(out, {
				catName = swap.catName,
				role = swap.role,
				perSecond = if type(rate) == "number"
						and rate == rate
						and rate > 0
					then rate
					else nil,
			})
		end
	end
	return out
end

function AutoEquipToast.text(swaps: { Swap }, money: (number) -> string): string?
	if #swaps == 0 then
		return nil
	end
	if #swaps > 1 then
		return ("Auto Equip: %d cats moved to better jobs"):format(#swaps)
	end
	local swap = swaps[1]
	local line = ("Auto Equip: %s is now your %s"):format(
		swap.catName or "A cat",
		swap.role or "crew"
	)
	if swap.perSecond ~= nil then
		line ..= (" (+%s/s)"):format(money(swap.perSecond))
	end
	return line
end

return AutoEquipToast
