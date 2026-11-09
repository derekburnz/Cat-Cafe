--!strict
-- #2791 (retention-ideas.md 5a, Derek2: "we have gift milestones can be improved but don't make this or any other
-- updates take a lot of precious phone screen space"): the gift ladder on the HUD's existing Rewards tile, no new
-- slot. The tile counts down to the next step, and its short list shows the next two steps with what each pays.
-- The server sends PlayerState.giftNext, the next two steps as { id, at, prize } with `at` in seconds of play on the
-- account, and PlayerState.playSeconds, which the client counts on from. Pure, so the cloud specs check it.
--   rows(next, played, dayRate?) -> { Row }   each step still to come: seconds left (never below 0) and its words;
--                                             empty once the ladder is done, or from a server without it
--   words(prize, dayRate?) -> string          "+1 spin", "+5 golden fish", "Swift Potion", "$1.2K, Tip Potion"
--   line(row) -> string                       the list row: "1:45  +1 spin"

local IndexRewards = require(script.Parent.IndexRewards)
local ShortNumber = require(script.Parent.ShortNumber)
local TipJarLogic = require(script.Parent.TipJarLogic)

local GiftLadderLogic = {}

export type Row = { id: string, left: number, words: string }

GiftLadderLogic.SHOWN = 2 -- the list's ladder rows (5a: "the next two steps")
GiftLadderLogic.PARTS = 2 -- the words name at most this many things, so a row stays one line on a phone

-- "swift_potion" -> "Swift Potion"
local function titled(id: string): string
	local words: { string } = {}
	for word in string.gmatch(id, "[^_]+") do
		table.insert(words, string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2))
	end
	return table.concat(words, " ")
end

function GiftLadderLogic.words(prize: any, dayRate: number?): string
	if type(prize) ~= "table" then
		return "A gift"
	end
	local said: { string } = {}
	for _, part in IndexRewards.prizeParts(prize, dayRate) do
		if #said >= GiftLadderLogic.PARTS then
			break
		end
		local amount = part.amount
		local kind = part.kind :: string
		local word: string? = nil
		if kind == "coins" then
			word = "$" .. ShortNumber.format(amount) -- Format.money, which needs Theme
		elseif kind == "fish" then
			word = ("+%d golden fish"):format(amount)
		elseif kind == "spins" then
			word = if amount == 1 then "+1 spin" else ("+%d spins"):format(amount)
		elseif kind == "lure" then
			word = if amount == 1 then "Bait food" else ("%d bait foods"):format(amount)
		elseif kind == "potion" then
			local name = titled(part.id or "potion")
			word = if amount == 1 then name else ("%d %ss"):format(amount, name)
		elseif kind == "crate" then
			word = if amount == 1 then "A crate" else ("%d crates"):format(amount)
		end
		if word ~= nil then
			table.insert(said, word)
		end
	end
	if #said == 0 then
		return "A gift"
	end
	return table.concat(said, ", ")
end

function GiftLadderLogic.rows(steps: unknown, played: number?, dayRate: number?): { Row }
	local rows: { Row } = {}
	if type(steps) ~= "table" or played == nil then
		return rows
	end
	for _, step in steps :: { any } do
		if #rows >= GiftLadderLogic.SHOWN then
			break
		end
		if type(step) == "table" and type(step.id) == "string" and type(step.at) == "number" then
			table.insert(rows, {
				id = step.id,
				left = math.max(0, step.at - played),
				words = GiftLadderLogic.words(step.prize, dayRate),
			})
		end
	end
	return rows
end

function GiftLadderLogic.line(row: Row): string
	return TipJarLogic.clock(row.left) .. "  " .. row.words
end

return GiftLadderLogic
