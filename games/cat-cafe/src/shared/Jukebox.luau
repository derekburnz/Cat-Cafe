--!strict
-- The cafe Jukebox (#1168 row 2, made free on #1875 by Derek2 2026-11-06), pure: four extra cafe songs any player
-- may pick to play in place of the day and night rotation. Cosmetic only, and free: there is no pass check.
-- Config.JukeboxPassId stays (the pass is off sale) so earlier buyers see no errors; their saved picks keep working.
-- profile.jukebox is the pick, nil for the normal rotation. Each track's `cue` is the client Audio cue (Audio/Cues);
-- the client plays the pick while the cafe music would play.
--   owned() -> { id }              every track id (all are free)
--   shown(pick) -> id?             the pick if it is a known track or SHUFFLE, else nil (the rotation)
--   pickFor(raw) -> (ok, id?)      what SetJukeboxTrack may save: nil/""/"default", SHUFFLE or a known track
--   sanitizePick(raw) -> id?       a saved pick made whole (a known id, SHUFFLE or nil)
-- #2077 (Derek2): SHUFFLE is a saved pick of its own, "play the Jukebox songs in a random order"; the client picks
-- the order. It is not a track: get(SHUFFLE) is nil and owned() doesn't list it.

local Jukebox = {}

export type Track = { id: string, name: string, cue: string }

Jukebox.DEFAULT = "default" -- the normal day and night rotation; "" and nil mean the same
Jukebox.SHUFFLE = "shuffle" -- #2077: every Jukebox song in a random order

local TRACKS: { Track } = {
	{ id = "jukebox_rainy_window", name = "Rainy Window", cue = "musicJukeboxRainyWindow" },
	{ id = "jukebox_catnap_waltz", name = "Catnap Waltz", cue = "musicJukeboxCatnapWaltz" },
	{ id = "jukebox_bakery_bounce", name = "Bakery Bounce", cue = "musicJukeboxBakeryBounce" },
	{ id = "jukebox_starlight_purr", name = "Starlight Purr", cue = "musicJukeboxStarlightPurr" },
}
for _, track in TRACKS do
	table.freeze(track)
end
table.freeze(TRACKS)
Jukebox.TRACKS = TRACKS

local byId: { [string]: Track } = {}
for _, track in TRACKS do
	byId[track.id] = track
end

function Jukebox.get(id: string): Track?
	return byId[id]
end

function Jukebox.owned(): { string }
	local ids: { string } = {}
	for _, track in TRACKS do
		table.insert(ids, track.id)
	end
	return ids
end

-- A pick that may be saved and shown: a known track or SHUFFLE.
local function known(pick: unknown): boolean
	return type(pick) == "string" and (byId[pick] ~= nil or pick == Jukebox.SHUFFLE)
end

function Jukebox.shown(pick: string?): string?
	if not known(pick) then
		return nil
	end
	return pick
end

function Jukebox.pickFor(raw: unknown): (boolean, string?)
	if raw == nil or raw == "" or raw == Jukebox.DEFAULT then
		return true, nil
	end
	if not known(raw) then
		return false, nil
	end
	return true, raw :: string
end

function Jukebox.sanitizePick(raw: unknown): string?
	return if known(raw) then raw :: string else nil
end

return Jukebox
