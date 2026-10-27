--!strict
-- Report a bug (docs/playtests/bug-reports.md section 1, QA 2026-10-27, for the friends alpha): a small window
-- opened from the Help row in Settings. The line "What happened, and what were you doing right before?", three
-- chips (Bug, Stuck, Idea), a box of up to 500 bytes with a "123 / 500" counter, a line asking for no passwords
-- or personal info, and Send and Cancel. Send stays grey under 3 characters (Components/BugReportLogic).
--
-- Send calls callbacks.send(text, kind) and waits for the server's toast: result(true) (the "Thanks!" toast)
-- clears the box and closes, result(false) (a warn toast) keeps every word and lights Send again, and so does
-- SEND_TIMEOUT without an answer. Cancel goes back to Settings; it, the X and the backdrop all keep the draft.
--
-- On a phone the on-screen keyboard covers the bottom of the screen, so while it is up the window moves to the
-- top and ends above it (compact): the chips, Cancel and Send share one row over the box, so they stay tappable
-- even when the keyboard is taller than it says. It goes back a moment after the keyboard hides, so the tap that
-- hid it still lands on the button under the finger.
--
-- Roblox terms: a TextBox is an editable text field; MultiLine lets Enter start a new line. UserInputService's
-- OnScreenKeyboardVisible and OnScreenKeyboardSize describe a phone's keyboard, when the device reports them.

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BugReportLogic = require(script.Parent.Parent.Components.BugReportLogic)
local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)

export type Callbacks = {
	send: (text: string, kind: string) -> (),
	back: () -> (), -- Cancel: back to Settings
	close: () -> (),
}

export type BugReport = {
	frame: Frame,
	onOpen: (self: BugReport) -> (),
	onClose: (self: BugReport) -> (),
	result: (self: BugReport, ok: boolean) -> (),
	pending: (self: BugReport) -> boolean,
	destroy: (self: BugReport) -> (),
}

local PROMPT = "What happened, and what were you doing right before?"
local PRIVACY = "Please don't type passwords or personal info"
local NO_ANSWER = "No answer yet. Your words are still here, try Send again"
local PLACEHOLDER = "I was carrying a cat home when..."
local SEND_TIMEOUT = 10 -- seconds without a toast before Send lights again
local KEYBOARD_GUESS = 0.55 -- of the screen's height, when a phone does not say how tall its keyboard is
local UNFOLD_DELAY = 0.4 -- seconds after the keyboard hides before the window moves back

local MAX_SIZE = Vector2.new(520, 420)
local PROMPT_HEIGHT = 24
local CHIP = Vector2.new(112, 44)
local CHIP_COMPACT = 78
local FOOT_HEIGHT = 20
local COUNTER_WIDTH = 80
local BUTTON_HEIGHT = 48
local BUTTON_COMPACT = 100
local GAP = Theme.sizes.gap
local TOP_EDGE = 30 -- compact: room above the window for the panel's ears and badge
local BOTTOM_EDGE = 8 -- compact: room between the window and the keyboard
local COMPACT_MIN = 150 -- compact: the window never gets shorter, keyboard or not

local BugReport = {}
BugReport.__index = BugReport

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.modal.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

function BugReport.new(callbacks: Callbacks): BugReport
	local self = setmetatable({}, BugReport) :: any
	self._callbacks = callbacks
	self._kind = BugReportLogic.KINDS[1].id
	self._pending = false
	self._token = 0 -- one per Send, so a late timeout cannot touch a newer one
	self._open = false
	self._compact = false
	self._fitToken = 0 -- one per keyboard change, so only the last one moves the window back
	self._noAnswer = false
	self._chips = {} :: { [string]: Button.Button }
	self._connections = {} :: { RBXScriptConnection }
	self._alive = true

	local panel = Panel.new({
		name = "BugReport",
		title = "Report a bug",
		subtitle = "Read by the people making the game",
		color = Theme.colors.sky,
		icon = "🐞",
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = MAX_SIZE, Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content

	self._prompt = text({
		Name = "Prompt",
		Size = UDim2.new(1, 0, 0, PROMPT_HEIGHT),
		FontFace = Theme.fonts.display,
		Text = PROMPT,
		Parent = content,
	})

	for _, kind in BugReportLogic.KINDS do
		local id = kind.id
		self._chips[id] = Button.new({
			name = "Chip_" .. kind.label,
			text = kind.label,
			icon = kind.icon,
			style = "ghost",
			size = UDim2.fromOffset(CHIP.X, CHIP.Y),
			parent = content,
			sound = "uiToggle",
			onClick = function()
				self._kind = id
				self:_refresh()
			end,
		})
	end

	local box: TextBox = Create("TextBox", {
		Name = "Box",
		BackgroundColor3 = Theme.colors.cream,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		ClipsDescendants = true,
		MultiLine = true,
		TextWrapped = true,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.modal.text,
		PlaceholderColor3 = Theme.modal.subtext,
		PlaceholderText = PLACEHOLDER,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
		Parent = content,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
	})
	Outline.border(box, Theme.sizes.stroke, Theme.modal.cardStroke)
	self._box = box

	self._note = text({
		Name = "Note",
		Size = UDim2.new(1, -COUNTER_WIDTH, 0, FOOT_HEIGHT),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		Text = PRIVACY,
		Parent = content,
	})
	self._counter = text({
		Name = "Counter",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(COUNTER_WIDTH, FOOT_HEIGHT),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = content,
	})

	self._cancel = Button.new({
		name = "Cancel",
		text = "Cancel",
		style = "ghost",
		parent = content,
		sound = false, -- the modal's open swish for Settings is the sound
		onClick = function()
			callbacks.back()
		end,
	})
	self._send = Button.new({
		name = "Send",
		text = "Send",
		style = "primary",
		parent = content,
		enabled = false,
		onClick = function()
			self:_submit()
		end,
	})

	-- the cap: a paste or a long word past 500 bytes is cut back at once
	table.insert(
		self._connections,
		box:GetPropertyChangedSignal("Text"):Connect(function()
			if #box.Text > BugReportLogic.MAX_BYTES then
				box.Text = BugReportLogic.cut(box.Text, BugReportLogic.MAX_BYTES)
				return -- setting Text fires this again
			end
			self._noAnswer = false
			self:_refresh()
		end)
	)
	local function keyboardMoved()
		self:_fit()
	end
	table.insert(self._connections, box.Focused:Connect(keyboardMoved))
	table.insert(self._connections, box.FocusLost:Connect(keyboardMoved))
	table.insert(
		self._connections,
		UserInputService:GetPropertyChangedSignal("OnScreenKeyboardVisible"):Connect(keyboardMoved)
	)
	table.insert(
		self._connections,
		UserInputService:GetPropertyChangedSignal("OnScreenKeyboardSize"):Connect(keyboardMoved)
	)

	self:_layout(false)
	self:_refresh()
	return self :: BugReport
end

-- Places everything for the normal window, or the compact one above a phone's keyboard.
function BugReport._layout(self: any, compact: boolean)
	self._prompt.Visible = not compact
	self._note.Visible = not compact
	self._counter.Visible = not compact
	local chipWidth = if compact then CHIP_COMPACT else CHIP.X
	local chipTop = if compact then 0 else PROMPT_HEIGHT + GAP
	for index, kind in BugReportLogic.KINDS do
		local chip: Button.Button = self._chips[kind.id]
		chip.instance.Position = UDim2.fromOffset((index - 1) * (chipWidth + GAP), chipTop)
		chip.instance.Size = UDim2.fromOffset(chipWidth, CHIP.Y)
		chip.label.TextSize = if compact then Theme.sizes.textSmall else Theme.sizes.textBody
	end
	local cancel = self._cancel.instance
	local send = self._send.instance
	if compact then
		send.AnchorPoint = Vector2.new(1, 0)
		send.Position = UDim2.fromScale(1, 0)
		send.Size = UDim2.fromOffset(BUTTON_COMPACT, CHIP.Y)
		cancel.AnchorPoint = Vector2.new(1, 0)
		cancel.Position = UDim2.new(1, -(BUTTON_COMPACT + GAP), 0, 0)
		cancel.Size = UDim2.fromOffset(BUTTON_COMPACT, CHIP.Y)
		self._box.Position = UDim2.fromOffset(0, CHIP.Y + GAP)
		self._box.Size = UDim2.new(1, 0, 1, -(CHIP.Y + GAP))
	else
		local below = GAP + FOOT_HEIGHT + GAP + BUTTON_HEIGHT -- the foot line and the buttons under the box
		local top = chipTop + CHIP.Y + GAP
		self._box.Position = UDim2.fromOffset(0, top)
		self._box.Size = UDim2.new(1, 0, 1, -(top + below))
		local foot = UDim2.new(0, 0, 1, -(BUTTON_HEIGHT + GAP + FOOT_HEIGHT))
		self._note.Position = foot
		self._counter.Position = UDim2.new(1, 0, foot.Y.Scale, foot.Y.Offset)
		cancel.AnchorPoint = Vector2.new(0, 1)
		cancel.Position = UDim2.fromScale(0, 1)
		cancel.Size = UDim2.new(0.5, -GAP / 2, 0, BUTTON_HEIGHT)
		send.AnchorPoint = Vector2.new(1, 1)
		send.Position = UDim2.fromScale(1, 1)
		send.Size = UDim2.new(0.5, -GAP / 2, 0, BUTTON_HEIGHT)
	end
end

-- The keyboard's height in screen pixels: what the device says, else a guess.
local function keyboardHeight(): number
	local size = UserInputService.OnScreenKeyboardSize
	if UserInputService.OnScreenKeyboardVisible and size.Y > 0 then
		return size.Y
	end
	local camera = Workspace.CurrentCamera
	return (if camera then camera.ViewportSize.Y else Scale.DESIGN.Y) * KEYBOARD_GUESS
end

function BugReport._typing(self: any): boolean
	return UserInputService.OnScreenKeyboardVisible or (Scale.isTouch() and self._box:IsFocused())
end

-- Compact while a phone's keyboard is up for the box; back to normal a moment after it goes.
function BugReport._fit(self: any)
	self._fitToken += 1
	local token = self._fitToken
	if self._open and self:_typing() then
		self:_place(true)
	elseif self._compact then
		task.delay(UNFOLD_DELAY, function()
			if self._alive and token == self._fitToken and not (self._open and self:_typing()) then
				self:_place(false)
			end
		end)
	end
end

function BugReport._place(self: any, compact: boolean)
	local frame: Frame = self.frame
	local container = frame.Parent
	local gui = frame:FindFirstAncestorWhichIsA("ScreenGui")
	if compact and container and container:IsA("GuiObject") and gui then
		-- in the modal's design pixels: the container sits under the modal's UIScale
		local scale = Scale.get()
		local top = gui.AbsolutePosition.Y + TOP_EDGE * scale
		local bottom = gui.AbsolutePosition.Y
			+ gui.AbsoluteSize.Y
			- keyboardHeight()
			- BOTTOM_EDGE * scale
		local height = math.max(bottom - top, COMPACT_MIN * scale)
		frame.AnchorPoint = Vector2.new(0.5, 0)
		frame.Position = UDim2.new(0.5, 0, 0, (top - container.AbsolutePosition.Y) / scale)
		frame.Size = UDim2.new(1, 0, 0, height / scale)
	else
		compact = false
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.5)
		frame.Size = UDim2.fromScale(1, 1)
	end
	if compact ~= self._compact then
		self._compact = compact
		self:_layout(compact)
	end
end

function BugReport._refresh(self: any)
	local raw: string = self._box.Text
	self._counter.Text = BugReportLogic.counter(raw)
	self._counter.TextColor3 = if #raw >= BugReportLogic.MAX_BYTES
		then Theme.colors.red
		else Theme.modal.subtext
	self._note.Text = if self._noAnswer then NO_ANSWER else PRIVACY
	self._note.TextColor3 = if self._noAnswer then Theme.colors.red else Theme.modal.subtext
	self._box.TextEditable = not self._pending
	self._send:setText(if self._pending then "Sending..." else "Send")
	self._send:setEnabled(not self._pending and BugReportLogic.canSend(raw))
	for id, chip: Button.Button in self._chips do
		chip:setStyle(if id == self._kind then "secondary" else "ghost")
	end
end

function BugReport._submit(self: any)
	local raw: string = self._box.Text
	if self._pending or not BugReportLogic.canSend(raw) then
		return
	end
	self._pending = true
	self._noAnswer = false
	self._token += 1
	local token = self._token
	if self._box:IsFocused() then
		self._box:ReleaseFocus()
	end
	self:_refresh()
	self._callbacks.send(BugReportLogic.trim(raw), BugReportLogic.kindOf(self._kind))
	task.delay(SEND_TIMEOUT, function()
		if self._alive and self._pending and token == self._token then
			self._pending = false
			self._noAnswer = true
			self:_refresh()
		end
	end)
end

-- The server's answer, from its toast: true sent (clear and close), false refused (keep the words).
function BugReport.result(self: any, ok: boolean)
	if not self._pending then
		return
	end
	self._pending = false
	self._token += 1
	if ok then
		self._box.Text = ""
		self._kind = BugReportLogic.KINDS[1].id
		if self._open then
			self._callbacks.close()
		end
	end
	self:_refresh()
end

-- True from Send until the server answers or SEND_TIMEOUT passes.
function BugReport.pending(self: any): boolean
	return self._pending
end

function BugReport.onOpen(self: any)
	self._open = true
	self:_refresh()
	-- a phone's keyboard waits for a tap on the box; on a PC the box is ready to type in
	if not Scale.isTouch() and not self._pending then
		self._box:CaptureFocus()
	end
	self:_fit()
end

function BugReport.onClose(self: any)
	self._open = false
	if self._box:IsFocused() then
		self._box:ReleaseFocus()
	end
	self:_place(false)
end

function BugReport.destroy(self: any)
	self._alive = false
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	for _, chip: Button.Button in self._chips do
		chip:destroy()
	end
	table.clear(self._chips)
	self._cancel:destroy()
	self._send:destroy()
	self._panel:destroy()
end

return BugReport
