--!strict
-- Naming cats (data-model section 4, F33, reviewer S30). Pure: the server's RenameCat runs `validate` before it
-- filters and `allHashes` on the filtered text. The save keeps the raw name; other players only ever see a
-- filtered one (server/Services/NameService).

local Config = require(script.Parent.Config)

local CatName = {}

CatName.MAX_BYTES = 200 -- a longer string is refused before any other work (20 characters are 80 bytes at most)

-- The code points a name may use (reviewer S47): an allow list, because a deny list misses characters that draw
-- nothing, break a line or stack (soft hyphens, fillers, tags, combining marks) and could hide a word from the filter
-- or put a blank or towering name over a cat the whole street sees. ASCII letters, digits, space and ' - . ! ?;
-- Latin letters with accents; Hiragana and Katakana without the combining sound marks; CJK ideographs; Hangul
-- syllables; and single emoji (a joined emoji sequence needs U+200D, which is not allowed).
local ALLOWED_ASCII = "[%w '%-%.!%?]"
local ALLOWED_RANGES = {
	{ 0x00C0, 0x00D6 }, -- Latin-1 letters, without the multiplication sign U+00D7
	{ 0x00D8, 0x00F6 }, -- without the division sign U+00F7
	{ 0x00F8, 0x024F }, -- and Latin Extended-A and B
	{ 0x3041, 0x3096 }, -- Hiragana
	{ 0x309B, 0x30FF }, -- the spacing sound marks, Katakana
	{ 0x4E00, 0x9FFF }, -- CJK ideographs
	{ 0xAC00, 0xD7A3 }, -- Hangul syllables
	{ 0x1F300, 0x1FAFF }, -- emoji
}

local function allowed(code: number): boolean
	if code < 0x80 then
		return string.char(code):match(ALLOWED_ASCII) ~= nil
	end
	for _, range in ALLOWED_RANGES do
		if code >= range[1] and code <= range[2] then
			return true
		end
	end
	return false
end

-- The trimmed name, or nil and the reason in words for the player.
function CatName.validate(raw: unknown): (string?, string?)
	if type(raw) ~= "string" then
		return nil, "Type a name first"
	end
	local text: string = raw
	if #text > CatName.MAX_BYTES or utf8.len(text) == nil then
		return nil, "That name has characters we can't use"
	end
	local name = text:match("^%s*(.-)%s*$") or ""
	local length = utf8.len(name) or 0
	if length == 0 then
		return nil, "Type a name first"
	end
	if length > Config.CatNameMaxLength then
		return nil, string.format("Names can be up to %d characters", Config.CatNameMaxLength)
	end
	for _, code in utf8.codes(name) do
		if not allowed(code) then
			return nil, "That name has characters we can't use"
		end
	end
	return name, nil
end

-- True when the filter left nothing but hashes (or nothing at all), so the name is refused and the old one stays.
function CatName.allHashes(filtered: string): boolean
	return (filtered:gsub("[#%s]", "")) == ""
end

return CatName
