--!strict
-- The free Bellhop Cat's stand card (F96, starter-cat.md section 2). Walking within StarterCatRangeStuds of the
-- stand opens it and walking a stud past it closes it (StarterCatController calls UI.starterCat.open and close, and
-- update every 0.2 s while open). It shows:
--   * the cat on a disc in its rarity colour, "Rare" under it
--   * "Earns like a Rare from your newest area, always", today's figure ("Today: +$3/s") and its favourite role
--   * a status line: why it cannot be claimed yet when the client can tell ("Finish your first goals to take me
--     home"), the server's refusal after a press ("Join the Cat Cafe group to take me home") or, once claimed,
--     "Already home with you" in green with no buttons
--   * "Take me home", and "Join the group" beside it once the game has a group (view.gate "group")
-- Take me home shows "..." until StarterCatResult answers, or for ANSWER_SECONDS, and stays grey for RESEND_SECONDS
-- after a press, since the server takes one claim per 2 s. A claim that works closes the card (init shows the claim
-- card); a refusal stays on the status line until the next press or the card closes.
--   show(view, def?)      paints the view; cheap when nothing changed (update calls it 5 times a second)
--   result(ok, reason?)   StarterCatResult
--   onOpen(), onClose()   from the modal

local Button = require(script.Parent.Parent.Components.Button)
local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

-- the dark window palette (#1028), in place of Theme.modal
local PAL = Theme.dark

-- What the card shows (StarterCatController's view).
export type View = {
	claimed: boolean,
	gate: "task" | "group",
	line: string?, -- why it cannot be claimed yet, as the client can tell; "Already home with you" once claimed
	rate: number, -- what it earns a second at the player's tier, before its role
}

export type Callbacks = {
	claim: () -> (),
	join: () -> (),
	close: () -> (),
}

export type StarterCat = {
	frame: Frame,
	show: (self: StarterCat, view: View, def: Types.CatDef?) -> (),
	result: (self: StarterCat, ok: boolean, reason: string?) -> (),
	onOpen: (self: StarterCat) -> (),
	onClose: (self: StarterCat) -> (),
	destroy: (self: StarterCat) -> (),
}

local EARNS = "Earns like a Rare from your newest area, always"
local NO_ANSWER = "No answer yet. Try again."
local RARITY = "Rare"

local MAX_SIZE = Vector2.new(460, 300)
local LEFT_WIDTH = 130 -- the cat's disc and rarity
local ART = 108
local RARITY_HEIGHT = 20
local EARNS_HEIGHT = 44 -- two lines
local RATE_HEIGHT = 30
local ROLE_HEIGHT = 22
local STATUS_HEIGHT = 24
local ROW = 50 -- taller on a touch screen (Scale.tapHeight), the card with it
local GAP = Theme.sizes.gap
local ANSWER_SECONDS = 5
local RESEND_SECONDS = 2

local StarterCat = {}
StarterCat.__index = StarterCat

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = PAL.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

function StarterCat.new(callbacks: Callbacks): StarterCat
	local self = setmetatable({}, StarterCat) :: any
	self._callbacks = callbacks
	self._alive = true
	self._pending = false
	self._token = 0 -- one per press, so a late timeout cannot touch a newer one
	self._sentAt = -math.huge -- os.clock() of the last press
	self._joinedAt = -math.huge -- os.clock() of the last Join the group, which rests as long (review N314)
	self._refusal = nil :: string? -- the server's last refusal, kept over the view's line until the next press
	self._view = nil :: View?
	self._key = "" -- the last painted view, so update's calls cost nothing when it has not changed
	self._defId = nil :: string?

	local row = Scale.tapHeight(ROW, Theme.sizes.buttonDepth)
	local height = MAX_SIZE.Y + row - ROW
	local panel = Panel.new({
		dark = true, -- #1028
		name = "StarterCat",
		title = "Bellhop Cat",
		subtitle = "Free cat!",
		color = Theme.colors.red,
		icon = "🛎️",
		size = UDim2.new(1, 0, 0, height),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(MAX_SIZE.X, height), Parent = panel.frame })
	panel.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.frame.Position = UDim2.fromScale(0.5, 0.5)
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content
	local rarityColor = Theme.rarityColor(RARITY)

	-- the cat on its disc
	local disc: Frame = Create("Frame", {
		Name = "Cat",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(LEFT_WIDTH / 2, 0),
		Size = UDim2.fromOffset(ART, ART),
		Parent = content,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(disc, Theme.sizes.outline + 1, rarityColor)
	self._portrait = CatPortrait.new({ parent = disc, size = UDim2.fromScale(1, 1) })
	local pill: TextLabel = text({
		Name = "Rarity",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 0,
		BackgroundColor3 = rarityColor,
		Position = UDim2.fromOffset(LEFT_WIDTH / 2, ART + 4),
		Size = UDim2.fromOffset(72, RARITY_HEIGHT),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.rarityTextColor(RARITY),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = RARITY,
		Parent = content,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pill })

	-- what it earns
	local right = LEFT_WIDTH + GAP
	text({
		Name = "Earns",
		Position = UDim2.fromOffset(right, 0),
		Size = UDim2.new(1, -right, 0, EARNS_HEIGHT),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = EARNS,
		Parent = content,
	})
	self._rate = text({
		Name = "Rate",
		Position = UDim2.fromOffset(right, EARNS_HEIGHT + 4),
		Size = UDim2.new(1, -right, 0, RATE_HEIGHT),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = PAL.good,
		Parent = content,
	})
	self._role = text({
		Name = "Role",
		Position = UDim2.fromOffset(right, EARNS_HEIGHT + 4 + RATE_HEIGHT + 2),
		Size = UDim2.new(1, -right, 0, ROLE_HEIGHT),
		TextSize = Theme.sizes.textSmall + 2,
		RichText = true,
		Parent = content,
	})

	-- the status line and the buttons, across the card
	local statusTop = ART + 4 + RARITY_HEIGHT + GAP
	self._status = text({
		Name = "Status",
		Position = UDim2.fromOffset(0, statusTop),
		Size = UDim2.new(1, 0, 0, STATUS_HEIGHT),
		FontFace = Theme.fonts.display,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = content,
	})
	local rowTop = statusTop + STATUS_HEIGHT + GAP
	self._rowTop = rowTop
	self._join = Button.new({
		name = "JoinGroup",
		text = "Join the group",
		style = "secondary",
		size = UDim2.new(0.5, -GAP / 2, 0, row),
		position = UDim2.fromOffset(0, rowTop),
		parent = content,
		onClick = function()
			self:_pressJoin()
		end,
	})
	self._claim = Button.new({
		name = "TakeMeHome",
		text = "Take me home",
		style = "primary",
		size = UDim2.new(1, 0, 0, row),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, rowTop),
		parent = content,
		enabled = false,
		onClick = function()
			self:_press()
		end,
	})
	-- once claimed the card is the cat and its line: the status sits lower, where the buttons were
	self._claimedTop = rowTop + (row - STATUS_HEIGHT) / 2
	self._row = row
	return self :: StarterCat
end

function StarterCat._resting(self: any): boolean
	return os.clock() - self._sentAt < RESEND_SECONDS
end

function StarterCat._paint(self: any)
	local view: View? = self._view
	if view == nil then
		return
	end
	local claimed = view.claimed
	local group = view.gate == "group" and not claimed
	self._rate.Text = "Today: " .. Format.rate(view.rate)
	local refusal: string? = self._refusal
	local line: string? = if claimed
		then view.line or "Already home with you"
		else refusal or view.line
	self._status.Text = if self._pending then "..." else line or ""
	self._status.TextColor3 = if claimed
		then PAL.good
		elseif refusal ~= nil then PAL.red
		else PAL.warn
	self._status.Position = UDim2.fromOffset(
		0,
		if claimed then self._claimedTop else self._rowTop - STATUS_HEIGHT - GAP
	)
	self._join.instance.Visible = group
	self._claim.instance.Visible = not claimed
	local row = self._row
	self._claim.instance.Size = if group
		then UDim2.new(0.5, -GAP / 2, 0, row)
		else UDim2.new(1, 0, 0, row)
	self._claim:setText(if self._pending then "..." else "Take me home")
	-- a line the client can tell (the first goals) greys the button; the group is the server's to say
	local blocked = not claimed and refusal == nil and view.line ~= nil
	self._claim:setEnabled(
		not claimed and not blocked and not self._pending and not self:_resting()
	)
end

-- The view from the controller. Called 5 times a second while open, so it repaints only on a change.
function StarterCat.show(self: any, view: View, def: Types.CatDef?)
	if def ~= nil and def.id ~= self._defId then
		self._defId = def.id
		self._portrait:set(def)
		local loves: string? = def.favoriteRole
		self._role.Text = if loves then Format.lovesRole(loves, PAL.text) else ""
	end
	local key = ("%s|%s|%s|%.2f"):format(
		tostring(view.claimed),
		view.gate,
		view.line or "",
		view.rate
	)
	self._view = view
	if key == self._key then
		return
	end
	self._key = key
	if view.claimed then
		self._refusal = nil
	end
	self:_paint()
end

-- Join the group opens Roblox's prompt; it rests RESEND_SECONDS too, so two quick taps make one prompt.
function StarterCat._pressJoin(self: any)
	if os.clock() - self._joinedAt < RESEND_SECONDS then
		return
	end
	self._joinedAt = os.clock()
	self._join:setEnabled(false)
	self._callbacks.join()
	task.delay(RESEND_SECONDS, function()
		if self._alive then
			self._join:setEnabled(true)
		end
	end)
end

function StarterCat._press(self: any)
	local view: View? = self._view
	if self._pending or self:_resting() or view == nil or view.claimed then
		return
	end
	self._pending = true
	self._refusal = nil
	self._sentAt = os.clock()
	self._token += 1
	local token = self._token
	self:_paint()
	self._callbacks.claim()
	task.delay(ANSWER_SECONDS, function()
		if self._alive and self._pending and token == self._token then
			self._pending = false
			self._refusal = NO_ANSWER
			self:_paint()
		end
	end)
	-- light the button again once the server would take another press
	task.delay(RESEND_SECONDS, function()
		if self._alive then
			self:_paint()
		end
	end)
end

-- StarterCatResult: ok is init's to celebrate (it closes the card); a refusal shows on the status line.
function StarterCat.result(self: any, ok: boolean, reason: string?)
	self._pending = false
	self._token += 1
	if ok then
		self._refusal = nil
	else
		Sound.play("uiError")
		self._refusal = reason or NO_ANSWER
	end
	self:_paint()
end

function StarterCat.onOpen(self: any)
	self:_paint()
end

-- Walking off forgets a refusal; a press still waiting keeps its "..." for its answer.
function StarterCat.onClose(self: any)
	self._refusal = nil
	self._key = ""
end

function StarterCat.destroy(self: any)
	self._alive = false
	self._token += 1
	self._join:destroy()
	self._claim:destroy()
	self._portrait:destroy()
	self._panel:destroy()
end

return StarterCat
