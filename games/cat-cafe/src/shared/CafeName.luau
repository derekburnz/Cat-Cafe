--!strict
-- The name on a cafe's sign (world-and-feel section 3; Derek 2026-10-27: "cap the name length shown if too long
-- then just show that amount then Cafe"). A display name runs to 20 characters, which the SignBoard only fits in a
-- tiny font next to the headshot, so the sign shows its first MaxChars characters, then "'s Cafe".

local CafeName = {}

CafeName.MaxChars = 12

-- The owner's name as the sign shows it: at most MaxChars characters (never a split character), trailing spaces
-- off. A string that is not UTF-8 is cut by bytes.
function CafeName.shown(displayName: string): string
	local name = displayName
	local length = utf8.len(name)
	if length == nil then
		name = name:sub(1, CafeName.MaxChars)
	elseif length > CafeName.MaxChars then
		name = name:sub(1, (utf8.offset(name, CafeName.MaxChars + 1) :: number) - 1)
	end
	return (name:gsub("%s+$", ""))
end

-- "Derek's Cafe", with the name capped.
function CafeName.title(displayName: string): string
	return CafeName.shown(displayName) .. "'s Cafe"
end

return CafeName
