--!strict
-- Naming cats (data-model section 4, F33, reviewer S30). Pure: the server's RenameCat runs `validate` before it
-- filters and `allHashes` on the filtered text. The save keeps the raw name; other players only ever see a
-- filtered one (server/Services/NameService).

local Config = require(script.Parent.Config)

local CatName = {}

CatName.MAX_BYTES = 200 -- a longer string is refused before any other work (20 characters are 80 bytes at most)

-- Code points a name may not hold beyond the C0 and C1 controls: zero-width marks, bidi overrides and isolates, and
-- the byte order mark, which can hide or reorder text.
local FORMAT_RANGES = {
	{ 0x200B, 0x200F },
	{ 0x202A, 0x202E },
	{ 0x2060, 0x2069 },
	{ 0xFEFF, 0xFEFF },
}

local function forbidden(code: number): boolean
	if code < 0x20 or (code >= 0x7F and code <= 0x9F) or code == 0x3C or code == 0x3E then
		return true -- controls, newlines, < and >
	end
	for _, range in FORMAT_RANGES do
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
		if forbidden(code) then
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
