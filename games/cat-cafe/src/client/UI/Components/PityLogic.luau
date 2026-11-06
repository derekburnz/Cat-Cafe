--!strict
-- The Town Square pity sign's words (#1572, luck-and-rare-moments.md 1h), pure. `t` is seconds since
-- Config.ClockEpoch (Workspace:GetServerTimeNow() - Config.ClockEpoch), so every client counts the same as the server.
--   view(t, state) -> View   "Legendary cat in 12:30", "Mythical cat in 1:42:10", and while a pity cat is out
--                            "Now in the Woods!" (its kind in statusKind, for the colour), after a catch "Caught by Sam"
-- `state` is ReplicatedStorage.Pity's attributes (PityService): Kind, Area, State ("out", "caught" or ""), Winner.
--   current() -> State?      those attributes now (nil before the server makes the folder)
--   lines(view) -> {string}  the view as the day clock card's lines (1h: "the same two lines show on the day clock's
--                            card"), the status last when there is one

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Pity = require(Shared:WaitForChild("Pity"))

local PityLogic = {}

PityLogic.TITLE = "PITY CAT"

export type State = {
	kind: string,
	area: string,
	state: string,
	winner: string,
}

export type View = {
	legendary: string,
	mythical: string,
	status: string?,
	statusKind: string?,
}

local function countdown(t: number, kind: Pity.Kind): string
	local at = Pity.nextAt(t, kind)
	return ("%s cat in %s"):format(kind, Pity.countdownText(at - t))
end

function PityLogic.view(t: number, state: State?): View
	local view: View = {
		legendary = countdown(t, "Legendary"),
		mythical = countdown(t, "Mythical"),
	}
	if state ~= nil and state.state == "out" and state.area ~= "" then
		local area = Catalog.getArea(state.area)
		view.status = ("Now in the %s!"):format(if area ~= nil then area.name else state.area)
		view.statusKind = state.kind
	elseif state ~= nil and state.state == "caught" and state.winner ~= "" then
		view.status = "Caught by " .. state.winner
		view.statusKind = state.kind
	end
	return view
end

local function attr(folder: Instance, name: string): string
	local value = folder:GetAttribute(name)
	return if type(value) == "string" then value else ""
end

function PityLogic.current(): State?
	local folder = ReplicatedStorage:FindFirstChild(Pity.FOLDER)
	if folder == nil then
		return nil
	end
	return {
		kind = attr(folder, "Kind"),
		area = attr(folder, "Area"),
		state = attr(folder, "State"),
		winner = attr(folder, "Winner"),
	}
end

function PityLogic.lines(view: View): { string }
	local lines = { view.legendary, view.mythical }
	if view.status then
		table.insert(lines, view.status)
	end
	return lines
end

return PityLogic
