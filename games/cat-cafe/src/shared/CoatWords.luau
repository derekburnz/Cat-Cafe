--!strict
-- #3692 (Derek, 2026-11-12: "make the text either rainbow for the rainbow word or gold for where it says gold"): the
-- coat word of a rare cat line drawn in its own colours, pure. One place, so the chat lines (GlobalCatch.chatLine,
-- RareCatsTab.line) and anything later colour the word the same way: "Rainbow" a colour a letter in the rainbow
-- coat's bands (Theme.rainbow's stops), "Gold" in the gold of the UI (Theme.colors.gold). Only the coat word
-- changes; the player's name and the cat's name are never touched, so the word is looked for only where the lines
-- put it:
--   "Sam caught a rainbow Legendary Tabby!"          the coat right before a rarity word (Catching.shoutOut)
--   "A gold Mythical cat appeared in the Woods!"     the same (Catching.waveShoutOut)
--   "Sam caught a gold SECRET cat: Nebula!"          the same, a Secret's wording
--   "A Rainbow Tabby is out in the Woods!"           the line's own start (Catching.rainbowSpawnText)
--   find(text) -> (first, last, coat)?   where the coat word sits in `text`, and "gold" or "rainbow"
--   paint(word, coat) -> string          the word as rich text, bold in its colours; `word` must hold no rich text
--   rich(text, escape) -> string         `text` as rich text: escape(before) .. paint(word) .. escape(after)
-- Rich text is still: nothing here moves, so chat and Reduce Motion need no care.

local Catalog = require(script.Parent.Catalog)

local CoatWords = {}

CoatWords.GOLD = "#FFC94D"
CoatWords.RAINBOW = { "#FF5A5F", "#FF9F43", "#FFD93D", "#4CD38A", "#4AA8FF", "#B46CFF" }

export type Coat = "gold" | "rainbow"

local COATS: { Coat } = { "gold", "rainbow" }
-- Catching.rainbowSpawnText and CatVariant.spawnLine
local SPAWN_STARTS = { "A Rainbow ", "🌈 A Rainbow " }

-- The words a coat stands right before: every rarity's name, and a Secret's "SECRET".
local function afterWords(): { string }
	local words = { "SECRET" }
	for rarity in Catalog.rarityRank do
		table.insert(words, rarity)
	end
	return words
end

function CoatWords.find(text: string): (number?, number?, Coat?)
	for _, start in SPAWN_STARTS do
		if string.sub(text, 1, #start) == start then
			local last = #start - 1 -- the space after the word is not part of it
			return last - #"Rainbow" + 1, last, "rainbow"
		end
	end
	-- the rightmost one: the player's name comes first in a line, the coat after it
	local first: number?, last: number?, found: Coat? = nil, nil, nil
	local words = afterWords()
	for _, coat in COATS do
		for _, word in words do
			local needle = " " .. coat .. " " .. word
			local from = 1
			while true do
				local at = string.find(text, needle, from, true)
				if at == nil then
					break
				end
				if first == nil or at + 1 > first then
					first, last, found = at + 1, at + #coat, coat
				end
				from = at + 1
			end
		end
	end
	return first, last, found
end

function CoatWords.paint(word: string, coat: Coat): string
	if coat == "gold" then
		return string.format('<b><font color="%s">%s</font></b>', CoatWords.GOLD, word)
	end
	local parts = { "<b>" }
	local index = 0
	for _, code in utf8.codes(word) do
		index += 1
		local color = CoatWords.RAINBOW[(index - 1) % #CoatWords.RAINBOW + 1]
		local letter = utf8.char(code)
		table.insert(parts, string.format('<font color="%s">%s</font>', color, letter))
	end
	table.insert(parts, "</b>")
	return table.concat(parts)
end

function CoatWords.rich(text: string, escape: (string) -> string): string
	local first, last, coat = CoatWords.find(text)
	if first == nil or last == nil or coat == nil then
		return escape(text)
	end
	return escape(string.sub(text, 1, first - 1))
		.. CoatWords.paint(string.sub(text, first, last), coat)
		.. escape(string.sub(text, last + 1))
end

return CoatWords
