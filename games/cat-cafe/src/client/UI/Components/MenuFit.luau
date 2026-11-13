--!strict
-- #3686: how many tiles a row the HUD's left menu takes when Roblox's chat window sits over it on a computer.
-- The column goes under the chat window (#3033), and when it does not fit there as it is, it takes more tiles a row
-- (so fewer rows) until it does. Pure, so the cloud spec runner checks it.
--   underChat(top, bottom, columns, max, heightOf) -> number?
--     top        where the column would start under the chat window
--     bottom     the lowest it may reach (over the counters)
--     columns    the tiles a row the layout picked without the chat
--     max        the most tiles a row
--     heightOf   the column's height with this many tiles a row
--   The fewest tiles a row, `columns` or more, that fit between top and bottom; nil when none do.

local MenuFit = {}

function MenuFit.underChat(
	top: number,
	bottom: number,
	columns: number,
	max: number,
	heightOf: (columns: number) -> number
): number?
	for count = columns, math.max(columns, max) do
		if top + heightOf(count) <= bottom then
			return count
		end
	end
	return nil
end

return MenuFit
