--!strict
-- Feedback, once Report a bug (docs/playtests/bug-reports.md section 1, QA 2026-10-27, for the friends alpha): a
-- small window opened from the HUD's Feedback tile on the Idea chip (2026-11-01, so players have an easy, visible way
-- to send feedback), the one way in since Settings lost its Report a bug row (Derek 2026-11-01: "merge the feedback
-- and bug report from old settings"). A question that follows the chip ("What happened, and
-- what were you doing right before?" for Bug, "What would make the game more fun?" for Idea), three
-- chips (Bug, Stuck, Idea), a box of up to 500 bytes with a "123 / 500" counter, a line asking for no passwords
-- or personal info, and Send and Cancel. Send stays grey until the server would take the text: 3 bytes once
-- control characters are out and it is trimmed (Components/BugReportLogic, from Shared.BugReport).
--
-- Send calls callbacks.send(text, kind) with the text as the server keeps it and waits for the server's toast:
-- result(true) (its "Thanks!") clears the box and closes, result(false) (one of its refusals) keeps every word and
-- lights Send again, and so does SEND_TIMEOUT without an answer. Cancel (callbacks.back) closes it; it, the X
-- and the backdrop all keep the draft, chip included.
--
-- On a phone the on-screen keyboard covers the bottom of the screen, so while it is up the window moves to the
-- top and ends above it (compact): the chips, Cancel and Send share one row over the box, so they stay tappable
-- even when the keyboard is taller than it says. It goes back a moment after the keyboard hides, so the tap that
-- hid it still lands on the button under the finger.
--
-- F87 (easy-start.md section 4): the window opens on a faces page first (showFaces), "How is Cat Cafe so far?" with
-- three big faces: Love it, It's OK, Not for me. A tap is enough. Then the page asks "What would help most?" with six
-- chips (pick one), "Tell us more" (this report page on its Idea chip) and Done. Components/FeedbackLogic sends one
-- callbacks.feedback(face, chip?) per answer: with the first chip tapped, or the face alone when the window closes,
-- "Tell us more" is pressed or FeedbackLogic.WAIT_SECONDS pass. "Report a bug" under the faces goes to this page on
-- its Bug chip. setKind (a report from somewhere that already knows its kind) opens the report page directly.
--
-- Roblox terms: a TextBox is an editable text field; MultiLine lets Enter start a new line. UserInputService's
-- OnScreenKeyboardVisible and OnScreenKeyboardSize describe a phone's keyboard, when the device reports them.

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BugReportLogic = require(script.Parent.Parent.Components.BugReportLogic)
local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local FeedbackLogic = require(script.Parent.Parent.Components.FeedbackLogic)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)

export type Callbacks = {
	send: (text: string, kind: string) -> (),
	back: () -> (), -- Cancel: closes the window, keeping the draft
	close: () -> (),
	feedback: ((face: string, chip: string?) -> ())?, -- F87: one answer from the faces page; no faces page without it
}

export type BugReport = {
	frame: Frame,
	onOpen: (self: BugReport) -> (),
	onClose: (self: BugReport) -> (),
	result: (self: BugReport, ok: boolean) -> (),
	-- picks a chip ("bug", "stuck", "idea") before opening, unless a draft or a Send is waiting
	setKind: (self: BugReport, id: string) -> (),
	showFaces: (self: BugReport) -> (), -- F87: the next open starts on the faces page
	pending: (self: BugReport) -> boolean,
	destroy: (self: BugReport) -> (),
}

local PRIVACY = "Please don't type passwords or personal info"
local NO_ANSWER = "No answer yet. Your words are still here, try Send again"
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
-- F87 faces page
local FACES_TITLE = "How is Cat Cafe so far?"
local CHIPS_TITLE = "Thanks! What would help most?"
local THANKS_TITLE = "Thanks for telling us!"
local TITLE_HEIGHT = 32
local FACE_HEIGHT = 132
local FACE_GLYPH = 56
local FEEDBACK_CHIP_HEIGHT = 44

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
	self._answer = FeedbackLogic.answer()
	self._page = "report" :: "faces" | "chips" | "report"
	self._facesNext = false -- the next open starts on the faces page
	self._faceButtons = {} :: { [string]: Button.Button }
	self._chipButtons = {} :: { [string]: Button.Button }
	self._waitToken = 0 -- one per face picked, so only the latest one's wait sends it alone
	self._picked = nil :: string? -- the chip sent with this page's face

	local panel = Panel.new({
		name = "BugReport",
		title = "Feedback",
		subtitle = "Read by the people making the game",
		color = Theme.colors.sky,
		icon = Theme.icons.feedback,
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
		Text = BugReportLogic.prompt(self._kind),
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
		PlaceholderText = BugReportLogic.example(self._kind),
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

	if callbacks.feedback then
		self:_buildFaces(content)
	end
	self:_layout(false)
	self:_refresh()
	return self :: BugReport
end

-- F87: the faces page and its chips page, over the report page's place in the window.
function BugReport._buildFaces(self: any, content: Frame)
	local page: Frame = Create("Frame", {
		Name = "Faces",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = content,
	})
	self._facesPage = page
	self._facesTitle = text({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = FACES_TITLE,
		Parent = page,
	})
	local count = #FeedbackLogic.FACES
	for index, face in FeedbackLogic.FACES do
		local id = face.id
		local button = Button.new({
			name = "Face_" .. id,
			text = face.label,
			icon = face.glyph,
			layout = "tile",
			style = "ghost",
			textSize = Theme.sizes.textBody,
			size = UDim2.new(1 / count, -GAP * (count - 1) / count, 0, FACE_HEIGHT),
			position = UDim2.new(
				(index - 1) / count,
				(index - 1) * GAP / count,
				0,
				TITLE_HEIGHT + GAP
			),
			parent = page,
			sound = "uiToggle",
			onClick = function()
				self:_pickFace(id)
			end,
		})
		if button.icon then
			Create("UITextSizeConstraint", { MaxTextSize = FACE_GLYPH, Parent = button.icon })
		end
		self._faceButtons[id] = button
	end
	-- the chips page: two rows of three, tall enough for a finger on a phone
	local chipH = Scale.tapHeight(FEEDBACK_CHIP_HEIGHT, Theme.sizes.buttonDepth)
	self._chipH = chipH
	local columns = 3
	for index, chip in FeedbackLogic.CHIPS do
		local id = chip.id
		local column = (index - 1) % columns
		local row = (index - 1) // columns
		self._chipButtons[id] = Button.new({
			name = "Chip_" .. id,
			text = chip.label,
			icon = chip.glyph,
			style = "ghost",
			textSize = Theme.sizes.textSmall + 2,
			size = UDim2.new(1 / columns, -GAP * (columns - 1) / columns, 0, chipH),
			position = UDim2.new(
				column / columns,
				column * GAP / columns,
				0,
				TITLE_HEIGHT + GAP + row * (chipH + GAP)
			),
			parent = page,
			sound = "uiToggle",
			onClick = function()
				self:_pickChip(id)
			end,
		})
	end
	local footH = Scale.tapHeight(BUTTON_HEIGHT, Theme.sizes.buttonDepth)
	-- under the faces "Report a bug"; under the chips "Tell us more"
	self._facesLeft = Button.new({
		name = "More",
		text = "Report a bug",
		style = "ghost",
		anchorPoint = Vector2.new(0, 1),
		position = UDim2.fromScale(0, 1),
		size = UDim2.new(0.5, -GAP / 2, 0, footH),
		parent = page,
		onClick = function()
			self:_leaveFaces()
		end,
	})
	self._facesDone = Button.new({
		name = "Done",
		text = "Done",
		style = "primary",
		anchorPoint = Vector2.new(1, 1),
		position = UDim2.fromScale(1, 1),
		size = UDim2.new(0.5, -GAP / 2, 0, footH),
		parent = page,
		sound = false, -- the window's close swish
		onClick = function()
			self._callbacks.close()
		end,
	})
end

-- One answer to callbacks.feedback, when there is one to send.
function BugReport._sendAnswer(self: any, face: string?, chip: string?)
	local callbacks: Callbacks = self._callbacks
	local send = callbacks.feedback
	if face == nil or send == nil then
		return
	end
	send(face, chip)
end

-- The face alone, if one waits unsent.
function BugReport._flushFace(self: any)
	self:_sendAnswer(self._answer:flush())
end

function BugReport._pickFace(self: any, face: string)
	if self._answer:face() ~= nil and not self._answer:sent() then
		self:_flushFace() -- a second face on the same open: the first one counts as it was
	end
	self._answer:pick(face, os.clock())
	self._waitToken += 1
	local token = self._waitToken
	task.delay(FeedbackLogic.WAIT_SECONDS, function()
		if self._alive and token == self._waitToken then
			self:_sendAnswer(self._answer:due(os.clock()))
		end
	end)
	self:_showPage("chips")
end

function BugReport._pickChip(self: any, chip: string)
	local face, picked = self._answer:chip(chip)
	if face ~= nil then
		self:_sendAnswer(face, picked)
		self._picked = chip
		self:_refreshFaces()
	end
end

-- "Report a bug" (faces) or "Tell us more" (chips): the report page, on its Bug or Idea chip.
function BugReport._leaveFaces(self: any)
	local fromChips = self._page == "chips"
	self:_flushFace()
	if not self._pending and self._box.Text == "" then
		self._kind = if fromChips then "idea" else "bug"
	end
	self:_showPage("report")
	if not Scale.isTouch() and not self._pending then
		self._box:CaptureFocus()
	end
end

function BugReport._showPage(self: any, page: "faces" | "chips" | "report")
	if self._facesPage == nil then
		page = "report"
	end
	self._page = page
	if page == "faces" then
		self._picked = nil
	end
	local report = page == "report"
	for _, chip: Button.Button in self._chips do
		chip.instance.Visible = report
	end
	self._prompt.Visible = report and not self._compact
	self._note.Visible = report and not self._compact
	self._counter.Visible = report and not self._compact
	self._box.Visible = report
	self._cancel.instance.Visible = report
	self._send.instance.Visible = report
	if self._facesPage then
		self._facesPage.Visible = not report
		self:_refreshFaces()
	end
	self:_refresh()
end

function BugReport._refreshFaces(self: any)
	if self._facesPage == nil then
		return
	end
	local chips = self._page == "chips"
	local picked: string? = self._picked
	for _, button: Button.Button in self._faceButtons do
		button.instance.Visible = not chips
	end
	for id, button: Button.Button in self._chipButtons do
		button.instance.Visible = chips
		button:setStyle(if id == picked then "secondary" else "ghost")
		button:setEnabled(picked == nil or id == picked)
	end
	self._facesTitle.Text = if not chips
		then FACES_TITLE
		elseif picked ~= nil then THANKS_TITLE
		else CHIPS_TITLE
	self._facesLeft:setText(if chips then "Tell us more" else "Report a bug")
	self._facesDone.instance.Visible = chips
	self._facesLeft.instance.Size = if chips
		then UDim2.new(0.5, -GAP / 2, 0, self._facesLeft.instance.Size.Y.Offset)
		else UDim2.new(1, 0, 0, self._facesLeft.instance.Size.Y.Offset)
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
	self._prompt.Text = BugReportLogic.prompt(self._kind)
	self._box.PlaceholderText = BugReportLogic.example(self._kind)
end

function BugReport.setKind(self: any, id: string)
	self._facesNext = false
	if self._open and self._page ~= "report" then
		self:_showPage("report")
	end
	if self._pending or self._box.Text ~= "" or self._chips[id] == nil then
		return
	end
	self._kind = id
	self:_refresh()
end

function BugReport.showFaces(self: any)
	self._facesNext = self._facesPage ~= nil
end

function BugReport._submit(self: any)
	local text = BugReportLogic.text(self._box.Text)
	if self._pending or text == nil then
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
	self._callbacks.send(text, BugReportLogic.kindOf(self._kind))
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
	if self._facesNext then
		self._facesNext = false
		self:_showPage("faces")
	elseif self._page ~= "chips" then
		self:_showPage("report")
	end
	if self._page ~= "report" then
		return
	end
	self:_refresh()
	-- a phone's keyboard waits for a tap on the box; on a PC the box is ready to type in
	if not Scale.isTouch() and not self._pending then
		self._box:CaptureFocus()
	end
	self:_fit()
end

function BugReport.onClose(self: any)
	self._open = false
	self:_flushFace()
	if self._page == "chips" then
		self._page = "faces" -- an answered page does not come back on the next open
	end
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
	for _, button: Button.Button in self._faceButtons do
		button:destroy()
	end
	for _, button: Button.Button in self._chipButtons do
		button:destroy()
	end
	if self._facesLeft then
		self._facesLeft:destroy()
		self._facesDone:destroy()
	end
	self._panel:destroy()
end

return BugReport
