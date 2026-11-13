--!strict
-- #3692 (Derek 2026-11-12: "in text where it says rainbow \"catname\" has a appear or been caught or gold make the
-- text either rainbow for the rainbow word or gold for where it says gold"): the one helper that colours the coat
-- word of an announcement line, for rich text. "Rainbow" takes one band colour per letter (the bands of the rainbow
-- coat, the same as the UI's Theme.rainbow); "Gold" takes the gold of the gold coat's words. Only that one word
-- changes: the rest of the line keeps its colour.
--
-- The word is found as the coat of a cat, that is right after "a" or "an" ("caught a Rainbow Mythical Moonpaw",
-- "A gold Mythical cat appeared", "A Rainbow Tabby is out"), and the last such place in the line is the one
-- coloured, so a player's name at the start of the line that happens to hold the word is left as it is.
-- Static colours: nothing moves. Pure.

local CoatWords = {}

CoatWords.RAINBOW = { "#FF5A5F", "#FF9F43", "#FFD93D", "#4CD38A", "#4AA8FF", "#B46CFF" }
CoatWords.GOLD = "#FFC94D"

local WORDS = { rainbow = "rainbow", gold = "gold" }

-- Where the coat word sits in `text`: its first and last character and its kind ("rainbow" or "gold"); nil when
-- the line names no coat.
function CoatWords.find(text: string): (number?, number?, string?)
	local first: number?, last: number?, kind: string? = nil, nil, nil
	local from = 1
	while true do
		local at, to, word = string.find(text, "%f[%a][Aa]n? (%a+)%f[%A]", from)
		if at == nil or to == nil then
			break
		end
		local found = WORDS[string.lower(word :: string)]
		if found ~= nil then
			first, last, kind = to - #(word :: string) + 1, to, found
		end
		from = at + 1
	end
	return first, last, kind
end

-- `word` in its colours, as rich text, and bold: a Gold cat's line is often gold itself (a Legendary's chat line
-- is #FFC94D), so the weight is what sets the word apart there.
function CoatWords.paint(word: string, kind: string): string
	if kind == "gold" then
		return string.format('<b><font color="%s">%s</font></b>', CoatWords.GOLD, word)
	end
	local out = table.create(#word)
	for index = 1, #word do
		local color = CoatWords.RAINBOW[(index - 1) % #CoatWords.RAINBOW + 1]
		out[index] =
			string.format('<font color="%s">%s</font>', color, string.sub(word, index, index))
	end
	return "<b>" .. table.concat(out) .. "</b>"
end

-- `text` safe inside rich text: the five characters rich text reads are escaped (as GlobalCatch.escape).
function CoatWords.escape(text: string): string
	return (
		text:gsub("&", "&amp;")
			:gsub("<", "&lt;")
			:gsub(">", "&gt;")
			:gsub('"', "&quot;")
			:gsub("'", "&apos;")
	)
end

-- `text` as rich text with its coat word coloured. `escape` makes the rest of the line safe for rich text (the
-- caller's own, GlobalCatch.escape for one); the second result is false when the line names no coat, and then the
-- first is just `escape(text)`.
function CoatWords.rich(text: string, escape: (string) -> string): (string, boolean)
	local first, last, kind = CoatWords.find(text)
	if first == nil or last == nil or kind == nil then
		return escape(text), false
	end
	return escape(string.sub(text, 1, first - 1)) .. CoatWords.paint(
		string.sub(text, first, last),
		kind
	) .. escape(string.sub(text, last + 1)),
		true
end

return CoatWords
