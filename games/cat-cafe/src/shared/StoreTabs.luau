--!strict
-- The Store's tabs and their "New" dots (#1842, the server part of store v2 #1823), pure. Each tab has a version,
-- bumped here whenever that tab gains an item. profile.storeSeen = { [tab]: version } holds the version the player last
-- opened; a tab shows its dot while that is below the current version. Saved, so a cleared dot stays cleared across
-- sessions (a dot back every session would nag; rule 10). The UI's StoreLogic.TABS uses the same ids.
--   isTab(id) -> boolean                 a known tab id
--   sanitize(raw) -> Seen                a saved storeSeen made whole: known tabs, whole numbers 1..current
--   markSeen(seen, tab) -> boolean       notes the tab's current version; false for an unknown tab or no change
--   unseen(seen) -> { [tab]: true }      the tabs whose dot shows

local StoreTabs = {}

export type Seen = { [string]: number }

-- Bump a tab's number when it gains an item (a pass, cat, potion pack, season or code card).
local VERSIONS: { [string]: number } = {
	featured = 1,
	passes = 1,
	cats = 1,
	potions = 1,
	cafePass = 1,
	codes = 1,
}
table.freeze(VERSIONS)
StoreTabs.VERSIONS = VERSIONS

function StoreTabs.isTab(id: unknown): boolean
	return type(id) == "string" and VERSIONS[id] ~= nil
end

function StoreTabs.sanitize(raw: unknown): Seen
	local out: Seen = {}
	if type(raw) ~= "table" then
		return out
	end
	for tab, version in raw :: { [any]: any } do
		local current = if type(tab) == "string" then VERSIONS[tab] else nil
		if current ~= nil and type(version) == "number" and version == version then
			local whole = math.floor(version)
			if whole >= 1 then
				out[tab] = math.min(whole, current)
			end
		end
	end
	return out
end

function StoreTabs.markSeen(seen: Seen, tab: unknown): boolean
	if not StoreTabs.isTab(tab) then
		return false
	end
	local id = tab :: string
	if seen[id] == VERSIONS[id] then
		return false
	end
	seen[id] = VERSIONS[id]
	return true
end

function StoreTabs.unseen(seen: Seen): { [string]: true }
	local out: { [string]: true } = {}
	for tab, version in VERSIONS do
		if (seen[tab] or 0) < version then
			out[tab] = true
		end
	end
	return out
end

return StoreTabs
