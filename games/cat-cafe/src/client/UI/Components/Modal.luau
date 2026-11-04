--!strict
-- One ScreenGui that hosts every modal screen (Upgrades, Decor, Collection). Only one is open at a time.
-- Only a screen's own X (or its key) closes it: the dim backdrop takes taps without closing, so a tap on an empty
-- part of a window or beside it never shuts it (Derek 2026-10-27). Screens register a frame plus optional
-- onOpen/onClose callbacks.
-- Opening plays uiOpen and closing uiClose, so the buttons that only open or close a screen stay silent.
-- A window shrinks away for 0.16 s as it closes. If another one opens in that time (F, a HUD button or a window's
-- own "open the next one"), the closing one goes at once, so two never stay up together and closing one never shuts
-- both (Derek 2026-10-30: "ui pop ups get stuck on top of eachother").

local Create = require(script.Parent.Create)
local Scale = require(script.Parent.Parent.Scale)
local Signal = require(script.Parent.Signal)
local Sound = require(script.Parent.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Tween)

export type Screen = {
	frame: GuiObject,
	onOpen: (() -> ())?,
	onClose: (() -> ())?,
}

export type Modal = {
	screenGui: ScreenGui,
	container: Frame,
	changed: Signal.Signal, -- fires (name: string?)
	register: (self: Modal, name: string, screen: Screen) -> (),
	open: (self: Modal, name: string) -> (),
	close: (self: Modal) -> (),
	toggle: (self: Modal, name: string) -> (),
	current: (self: Modal) -> string?,
	destroy: (self: Modal) -> (),
}

local Modal = {}
Modal.__index = Modal

function Modal.new(parent: Instance): Modal
	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeModals",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 20,
		Enabled = false,
	})

	-- The dim behind the windows (#1236): its own layer just under them that ignores the top bar inset, so it covers
	-- the whole screen (it stopped short of the top, with a hard line). One backdrop, one darkness, its tweens never
	-- racing (_dim). Active, so a tap on it stops here instead of reaching the world under the window.
	local dimGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeModalDim",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 19,
		Enabled = false,
	})
	local backdrop: Frame = Create("Frame", {
		Name = "Backdrop",
		Active = true,
		BackgroundColor3 = Theme.modal.backdrop,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = dimGui,
	})

	-- Scaled root: screens are built in design pixels inside this.
	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	local uiScale = Scale.bind(root)

	-- Container keeps every screen inside 92% x 86% of the (scaled) viewport.
	local container: Frame = Create("Frame", {
		Name = "Container",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.86),
		Parent = root,
	})

	local self = setmetatable({}, Modal) :: any
	self.screenGui = screenGui
	self._dimGui = dimGui
	self._dimTween = nil :: Tween?
	self.container = container
	self.changed = Signal.new()
	self._backdrop = backdrop
	self._root = root
	self._uiScale = uiScale
	self._screens = {} :: { [string]: Screen }
	self._current = nil :: string?
	self._closing = nil :: GuiObject? -- the frame still shrinking away after close()

	if parent then
		dimGui.Parent = parent
		screenGui.Parent = parent
	end
	return self :: Modal
end

function Modal.register(self: any, name: string, screen: Screen)
	self._screens[name] = screen
	screen.frame.Visible = false
	screen.frame.Parent = self.container
end

function Modal.current(self: any): string?
	return self._current
end

function Modal.open(self: any, name: string)
	local screen: Screen? = self._screens[name]
	if not screen then
		warn(("[CatCafeUI] no modal screen named %q"):format(name))
		return
	end
	assert(screen, "modal screen missing")
	if self._current == name then
		return
	end
	if self._current then
		local previous: Screen = self._screens[self._current]
		previous.frame.Visible = false
		if previous.onClose then
			previous.onClose()
		end
	end
	-- a window still shrinking away goes now, so it never stays up under this one
	local closing: GuiObject? = self._closing
	if closing and closing ~= screen.frame then
		closing.Visible = false
	end
	self._closing = nil
	self._current = name
	self.screenGui.Enabled = true
	self:_dim(Theme.modal.backdropTransparency)
	screen.frame.Visible = true
	-- the night dealer's stall has its own bell (sound list 5.8)
	Sound.play(if name == "Dealer" then "uiDealerOpen" else "uiOpen")
	Tween.popIn(screen.frame)
	if screen.onOpen then
		screen.onOpen()
	end
	self.changed:Fire(name)
end

function Modal.close(self: any)
	local name = self._current
	if not name then
		return
	end
	local screen: Screen = self._screens[name]
	local frame = screen.frame
	self._closing = frame
	self._current = nil
	Sound.play("uiClose")
	self:_dim(1)
	Tween.popOut(frame, function()
		-- reopened while it shrank: it stays (its pop in cancelled this)
		if self._current == name then
			return
		end
		frame.Visible = false
		-- only the last window to close turns the layer off, and only when nothing has opened since
		if self._closing == frame then
			self._closing = nil
			if self._current == nil then
				self.screenGui.Enabled = false
				self._dimGui.Enabled = false
				self._backdrop.BackgroundTransparency = 1
			end
		end
	end)
	if screen.onClose then
		screen.onClose()
	end
	self.changed:Fire(nil)
end

-- The backdrop to one darkness (#1236): the tween before it stops first, so quick opens, closes and switches never
-- leave two tweens fighting over it.
function Modal._dim(self: any, transparency: number)
	local running: Tween? = self._dimTween
	if running then
		running:Cancel()
	end
	if transparency < 1 then
		self._dimGui.Enabled = true
	end
	self._dimTween = Tween.to(self._backdrop, Tween.FAST, { BackgroundTransparency = transparency })
end

function Modal.toggle(self: any, name: string)
	if self._current == name then
		self:close()
	else
		self:open(name)
	end
end

function Modal.destroy(self: any)
	Scale.unbind(self._uiScale)
	self.changed:DisconnectAll()
	self.screenGui:Destroy()
	self._dimGui:Destroy()
end

return Modal
