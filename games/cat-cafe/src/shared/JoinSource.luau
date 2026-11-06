--!strict
-- Where a join came from (#1888, Derek2 2026-11-06: funnels good enough to test the release once ads run). Pure. An ad
-- links to the game with launch data (`?launchData=ad_<tag>`), which the server reads from Player:GetJoinData() and
-- keeps for the session. The tag goes out as a custom field (session_start, the onboarding funnel's joined step, the
-- Store funnel's first step), so every funnel can be split by ad. Only a short tag of our own shape is kept: anything
-- else a link carries reads "unknown" and never reaches analytics as it came, since a player can paste any link.

local JoinSource = {}

JoinSource.ORGANIC = "organic" -- no launch data: the game page, a search, a friend's join
JoinSource.UNKNOWN = "unknown" -- launch data that is not one of our ad tags
JoinSource.PREFIX = "ad_"
JoinSource.TAG_MAX = 20 -- characters after the prefix

-- The source for `launchData` (GetJoinData's LaunchData, any value): "ad_<tag>" for an ad tag (lower case letters,
-- digits and _ after "ad_", 1 to TAG_MAX of them), ORGANIC for none or an empty string, UNKNOWN for anything else.
function JoinSource.parse(launchData: unknown): string
	if launchData == nil or launchData == "" then
		return JoinSource.ORGANIC
	end
	if type(launchData) ~= "string" then
		return JoinSource.UNKNOWN
	end
	local tag = string.match(launchData, "^ad_([a-z0-9_]+)$")
	if tag == nil or #tag > JoinSource.TAG_MAX then
		return JoinSource.UNKNOWN
	end
	return launchData
end

-- Whether `source` came from an ad.
function JoinSource.isAd(source: string): boolean
	return string.sub(source, 1, #JoinSource.PREFIX) == JoinSource.PREFIX
end

return JoinSource
