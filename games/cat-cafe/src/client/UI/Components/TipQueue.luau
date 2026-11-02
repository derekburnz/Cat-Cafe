--!strict
-- The context tips' words and timing (F87, easy-start.md section 3; ids and kinds from shared/Tips). A tip shows once
-- per account, the first time a player meets something: one line on a card (Screens/TipCard) or a camera cut of 3 to
-- 4 seconds with one caption. The rules:
--   * never during a catch, a rescue, a carry, the intro, a cannon flight or with a window or popup up, and never in
--     the dusk warning's last DUSK_QUIET seconds (`free`)
--   * at most one every Config.TipGapSeconds (60); a tip that cannot show yet waits in a queue of three and the
--     oldest drops (the server sends it again next session, since it was never seen)
--   * a card needs no press and goes after CARD_SECONDS or on a tap
-- The lines name the input the player last used: a letter key on a keyboard, "tap" on touch and the button on a
-- gamepad; on touch a line never names a letter key (section 2e). F96's favorite and like asks share the card and its
-- words here (UI.asks.show), staying ASK_SECONDS.
--   device(lastInput, touch) -> Device         "keyboard", "touch" or "gamepad" from the last UserInputType's name
--   line(id, device, cut?, nextArea?) -> string?   a tip's card line, or its camera cut's caption when cut is true
--   icon(id) -> string                         the glyph on the tip's card
--   free(moment) -> boolean                    whether a tip may show now
--   new(gap, size) -> Queue                    :push(id) -> boolean, :take(now) -> string?, :shown(now), :has(id),
--                                              :size(), :clear()
-- Pure, so the cloud spec runner checks it.

local TipQueue = {}

export type Device = "keyboard" | "touch" | "gamepad"

TipQueue.CARD_SECONDS = 5 -- a card goes by itself after this
TipQueue.DUSK_QUIET = 5 -- no tip in the dusk warning's last seconds (section 3)
TipQueue.SIZE = 3 -- tips waiting at most
TipQueue.ASK_SECONDS = 7 -- F96: the favorite and like asks stay a little longer (UI.asks.show)

-- A line per device where the input matters; one string where it does not.
type Line = string | { keyboard: string, touch: string, gamepad: string }

local CARD: { [string]: Line } = {
	bowl = "Put food in your bowl on the back step. A cat comes to eat it!",
	second_cat = {
		keyboard = "Open Cats (C) to give your new cat a job",
		touch = "Tap Cats to give your new cat a job",
		gamepad = "Open Cats to give your new cat a job",
	},
	stuck_cat = {
		keyboard = "A cat is stuck! Hold E by it, then click to free it",
		touch = "A cat is stuck! Tap and hold by it, then tap to free it",
		gamepad = "A cat is stuck! Hold X by it, then press to free it",
	},
	tackle = "Careful: other players can tackle you while you carry a cat",
	dropped = "You dropped it! Grab it again before someone else does",
	night = "Night closes the areas. Your cats keep earning!",
	rank_up = "Rank up to open the %s! Tap your tier to see how",
	golden_fish = "Spend golden fish on crates at the Fish Market",
	potion = {
		keyboard = "Open Potions (P) and drink it for a short boost",
		touch = "Tap Potions and drink it for a short boost",
		gamepad = "Open Potions and drink it for a short boost",
	},
	dealer = "The dealer is out tonight. It sells cats for coins!",
	spin_wheel = "A free spin every day at the Town Square wheel!",
	codes_cat = "New codes come with updates. Tell the Codes Cat!",
	luck = "Luck makes rare cats more likely. Tap the chip to see why",
	offline = "Your cats earned while you were away!",
	like_ask = "Having fun? A thumbs up helps other players find Cat Cafe.",
	favorite_ask = "Favorite Cat Cafe to find it fast next time", -- F96, starter-cat.md section 3
}

-- A camera cut's caption, said while the camera shows the place (section 3's table).
local CUT: { [string]: string } = {
	bowl = "Put food in your bowl. A cat comes to eat it!",
	rank_up = "Rank up to open the %s!",
	golden_fish = "Spend golden fish on crates here",
	dealer = "The dealer sells cats for coins",
	spin_wheel = "A free spin every day!",
}

local ICONS: { [string]: string } = {
	bowl = "🥣",
	second_cat = "🐱",
	stuck_cat = "❗",
	tackle = "💥",
	dropped = "😿",
	night = "🌙",
	rank_up = "⬆️",
	golden_fish = "🐟",
	potion = "🧪",
	dealer = "🛒",
	spin_wheel = "🎡",
	codes_cat = "🎟️",
	luck = "🍀",
	offline = "💤",
	like_ask = "👍",
	favorite_ask = "⭐",
}

function TipQueue.device(lastInput: string, touch: boolean): Device
	local device: Device = if touch then "touch" else "keyboard"
	if lastInput:match("^Gamepad") then
		device = "gamepad"
	elseif lastInput == "Touch" then
		device = "touch"
	elseif lastInput:match("^Mouse") or lastInput == "Keyboard" or lastInput == "TextInput" then
		device = "keyboard"
	end
	return device
end

function TipQueue.line(id: string, device: Device, cut: boolean?, nextArea: string?): string?
	local line: Line? = if cut then CUT[id] else nil
	if line == nil then
		line = CARD[id]
	end
	if line == nil then
		return nil
	end
	local text: string = if type(line) == "string" then line else (line :: any)[device]
	if text:find("%s", 1, true) then
		text = text:format(nextArea or "Park")
	end
	return text
end

function TipQueue.icon(id: string): string
	return ICONS[id] or "💡"
end

-- What is going on right now, as the UI sees it.
export type Moment = {
	catching: boolean?, -- catch circles up
	rescuing: boolean?, -- a rescue bar up
	carrying: boolean?,
	intro: boolean?, -- the intro or another cut playing
	flying: boolean?, -- a cannon flight
	window: boolean?, -- a window or a centre popup open
	hidden: boolean?, -- the HUD is hidden (a photo mode, the intro's bars)
	duskLeft: number?, -- seconds to night while the day is in its dusk warning, else nil
}

function TipQueue.free(moment: Moment): boolean
	if
		moment.catching
		or moment.rescuing
		or moment.carrying
		or moment.intro
		or moment.flying
		or moment.window
		or moment.hidden
	then
		return false
	end
	local dusk = moment.duskLeft
	return dusk == nil or dusk > TipQueue.DUSK_QUIET
end

export type Queue = {
	push: (self: Queue, id: string) -> boolean,
	take: (self: Queue, now: number) -> string?,
	shown: (self: Queue, now: number) -> (),
	has: (self: Queue, id: string) -> boolean,
	size: (self: Queue) -> number,
	clear: (self: Queue) -> (),
}

local Queue = {}
Queue.__index = Queue

function TipQueue.new(gap: number, size: number?): Queue
	local self = setmetatable({}, Queue) :: any
	self._gap = gap
	self._max = size or TipQueue.SIZE
	self._ids = {} :: { string }
	self._last = nil :: number? -- when the last tip showed
	return self :: Queue
end

function Queue.has(self: any, id: string): boolean
	return table.find(self._ids, id) ~= nil
end

function Queue.size(self: any): number
	return #self._ids
end

-- Adds a tip to the back; false when it already waits. Past the size the oldest drops.
function Queue.push(self: any, id: string): boolean
	if table.find(self._ids, id) then
		return false
	end
	table.insert(self._ids, id)
	while #self._ids > self._max do
		table.remove(self._ids, 1)
	end
	return true
end

-- The tip to show now, taken off the queue, or nil while the gap since the last one runs.
function Queue.take(self: any, now: number): string?
	local last: number? = self._last
	if #self._ids == 0 or (last ~= nil and now - last < self._gap) then
		return nil
	end
	return table.remove(self._ids, 1)
end

-- A tip showed at `now`: the next waits the gap from here.
function Queue.shown(self: any, now: number)
	self._last = now
end

function Queue.clear(self: any)
	table.clear(self._ids)
end

return TipQueue
