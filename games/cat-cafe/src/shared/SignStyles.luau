--!strict
-- Cafe sign styles (#1625, #1191, store-skus.md), pure: the styles a cafe's name sign can wear, which a player owns,
-- and their pick. A style is owned two ways: saved in profile.signStyles (the Starter Bundle's Bakery Stripes, granted
-- once with its receipt) or through a pass the player owns (the King Cat Pack's Royal Crest, looked up each session
-- like the pass's cat, so nothing is saved for it). profile.signStyle is the pick, nil for the plain sign; a pick the
-- player no longer owns shows the plain sign. CafeService sets the plot's SIGN_STYLE_ATTRIBUTE and places the
-- style's model (signstyles.py: placed at the plot pivot, with its own SignBoard for the cafe's name).
--   owned(saved, ownsPass) -> { id }          every owned style id, in LIST order
--   shown(saved, pick, ownsPass) -> id?       the pick if it is owned, else nil
--   sanitize(raw) -> { [id]: true }           a saved owned set made whole (known ids only)
--   sanitizePick(raw) -> id?                  a saved pick made whole (a known id or nil)
--   pickFor(raw, saved, ownsPass) -> (ok, id?) what SetSignStyle may save: the plain sign, or an owned style

local Config = require(script.Parent.Config)

local SignStyles = {}

SignStyles.SIGN_STYLE_ATTRIBUTE = "SignStyle"

-- passKey: the Config field holding the pass that gives the style (0 while not made); nil for a saved style
export type Style = { id: string, name: string, model: string, passKey: string? }

SignStyles.LIST = table.freeze({
	table.freeze({
		id = "bakery_stripes",
		name = "Bakery Stripes",
		model = "CatCafe_Plot_SignBakeryStripes",
	}),
	table.freeze({
		id = "royal_crest",
		name = "Royal Crest",
		model = "CatCafe_Plot_SignRoyalCrest",
		passKey = "KingPackPassId",
	}),
}) :: { Style }

local byId: { [string]: Style } = {}
for _, style in SignStyles.LIST do
	byId[style.id] = style
end

function SignStyles.get(id: string): Style?
	return byId[id]
end

-- The pass id that gives `style`, or 0 for a saved style or a pass not made.
function SignStyles.passId(style: Style): number
	if style.passKey == nil then
		return 0
	end
	local id = (Config :: any)[style.passKey :: string]
	return if type(id) == "number" then id else 0
end

-- Every owned style id, in LIST order: a saved style in `saved`, a pass style while `ownsPass` says the player has it.
function SignStyles.owned(
	saved: { [string]: boolean },
	ownsPass: (passId: number) -> boolean
): { string }
	local ids: { string } = {}
	for _, style in SignStyles.LIST do
		local passId = SignStyles.passId(style)
		local has = if style.passKey ~= nil
			then passId ~= 0 and ownsPass(passId)
			else saved[style.id] == true
		if has then
			table.insert(ids, style.id)
		end
	end
	return ids
end

-- The style the sign shows: the pick when the player owns it, else nil (the plain sign).
function SignStyles.shown(
	saved: { [string]: boolean },
	pick: string?,
	ownsPass: (passId: number) -> boolean
): string?
	if pick == nil then
		return nil
	end
	return if table.find(SignStyles.owned(saved, ownsPass), pick) ~= nil then pick else nil
end

-- A saved owned set made whole: known saved styles (not pass ones) set to true, nothing else.
function SignStyles.sanitize(raw: unknown): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if type(raw) == "table" then
		for id, value in raw :: { [any]: any } do
			if type(id) == "string" and value == true then
				local style = byId[id]
				if style ~= nil and style.passKey == nil then
					out[id] = true
				end
			end
		end
	end
	return out
end

-- A saved pick made whole: a known style id, else nil.
function SignStyles.sanitizePick(raw: unknown): string?
	return if type(raw) == "string" and byId[raw] ~= nil then raw else nil
end

-- What SetSignStyle(raw) may save (the remote's whole check): nil, "" or "default" is the plain sign (ok, nil); an
-- owned style id is (ok, id); anything else (a style not owned, an unknown id, a non-string) is refused (false, nil).
function SignStyles.pickFor(
	raw: unknown,
	saved: { [string]: boolean },
	ownsPass: (passId: number) -> boolean
): (boolean, string?)
	if raw == nil or raw == "" or raw == "default" then
		return true, nil
	end
	if type(raw) ~= "string" or byId[raw] == nil then
		return false, nil
	end
	if table.find(SignStyles.owned(saved, ownsPass), raw) == nil then
		return false, nil
	end
	return true, raw
end

return SignStyles
