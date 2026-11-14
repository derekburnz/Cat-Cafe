--!strict
-- #4061 Ticket Booth window (Design-Agent/notes/ticket-booth-and-dragon-keep.md 1.4, the station menus picture Derek
-- OK'd 2026-11-14 00:43 UTC): what each prize card shows from PlayerState.ticketBooth. Pure, so the specs check it.
--   card(row, tickets, armed) -> Card     the chip under the name, the price, the button and the bar of tickets saved
--   rushLine(view, now) -> string         "Ticket Rush: x2 for 42 min", or when it comes
--   ticketText(n) -> string               "🎟️ 3,240"
--   CONFIRM_AT, ARM_SECONDS               at this price and over, BUY turns into "Tap again" for ARM_SECONDS first

local TicketBoothLogic = {}

TicketBoothLogic.CONFIRM_AT = 1000 -- shared/TicketBooth.CONFIRM_AT
TicketBoothLogic.ARM_SECONDS = 3
TicketBoothLogic.TICKET = "🎟️"

local SHORT = "Not enough tickets yet" -- shared/TicketBooth.blocker's words for too few tickets

-- "3,240"
function TicketBoothLogic.commas(value: number): string
	local text = tostring(math.floor(value))
	while true do
		local grouped, count = text:gsub("^(%d+)(%d%d%d)", "%1,%2")
		text = grouped
		if count == 0 then
			return text
		end
	end
end

function TicketBoothLogic.ticketText(value: number): string
	return TicketBoothLogic.TICKET .. " " .. TicketBoothLogic.commas(value)
end

export type Row = {
	id: string,
	name: string,
	line: string,
	price: number,
	left: number?,
	per: string?,
	blocker: string?,
}

export type Card = {
	chip: string, -- under the name: the limit left, or why it can't be bought
	button: string,
	style: string, -- a Button style
	enabled: boolean,
	action: string, -- "buy" (send it), "arm" (the first of two taps) or "none"
	progress: number?, -- 0 to 1 while short of the price: the thin bar
	saved: string?, -- "1,240 / 3,000" under the bar
}

-- The limit chip: "4 left today", "1 left this week", "Once".
local function limitChip(row: Row): string
	if row.left == nil then
		return row.line
	end
	local left = row.left :: number
	if row.per == "day" then
		return if left <= 0 then "Back tomorrow" else ("%d left today"):format(left)
	elseif row.per == "week" then
		return if left <= 0 then "Back Monday" else ("%d left this week"):format(left)
	end
	return if left <= 0 then "Yours" else "Once"
end

function TicketBoothLogic.card(row: Row, tickets: number, armed: boolean): Card
	local chip = limitChip(row)
	if row.left ~= nil and (row.left :: number) <= 0 then
		return {
			chip = chip,
			button = if row.per == "once" then "Yours" else "Done",
			style = "ghost",
			enabled = false,
			action = "none",
		}
	end
	if tickets < row.price then
		return {
			chip = chip,
			button = "SAVE UP",
			style = "ghost",
			enabled = false,
			action = "none",
			progress = math.clamp(tickets / math.max(row.price, 1), 0, 1),
			saved = TicketBoothLogic.commas(tickets) .. " / " .. TicketBoothLogic.commas(row.price),
		}
	end
	if row.blocker ~= nil and row.blocker ~= SHORT then
		-- the server's other reasons (a full Trait Token bank): its words on the chip, BUY off
		return {
			chip = row.blocker :: string,
			button = "BUY",
			style = "ghost",
			enabled = false,
			action = "none",
		}
	end
	if row.price >= TicketBoothLogic.CONFIRM_AT and not armed then
		return { chip = chip, button = "BUY", style = "primary", enabled = true, action = "arm" }
	end
	return {
		chip = chip,
		button = if armed then "Tap again" else "BUY",
		style = "primary",
		enabled = true,
		action = "buy",
	}
end

-- The line under the tabs about the day's Ticket Rush hour (x2 tickets).
function TicketBoothLogic.rushLine(rushEndsAt: number?, usedToday: boolean, now: number): string
	if rushEndsAt ~= nil and rushEndsAt > now then
		local minutes = math.max(math.ceil((rushEndsAt - now) / 60), 1)
		return ("Ticket Rush: x2 tickets for %d min"):format(minutes)
	end
	if usedToday then
		return "Ticket Rush is back tomorrow"
	end
	return "Ticket Rush: x2 tickets for an hour from your next catch"
end

return TicketBoothLogic
