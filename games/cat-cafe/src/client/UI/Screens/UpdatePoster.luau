--!strict
-- The update poster's face in the Town Square (#4362, Derek 2026-11-15: players are nudged to tap Notify Me for the
-- next update until it starts, "including posters"): "NEXT UPDATE", the update's picture and name ("3 NEW WORLDS"),
-- a countdown counted on this client, and a walk-up prompt "Notify Me" that opens Roblox's own Notify Me prompt for
-- that Event (Components/EventRsvp). It reads Config.UpdateEvents (Components/UpdatePosterLogic), so it moves to the
-- next update by itself when one starts, and reads "More updates soon!" when none is listed. The stand is
-- Model-Agent's CatCafe_Square_UpdatePoster, tagged "UpdatePoster" by WorldBuilder; its Screen part, 8.0 x 4.5 studs,
-- faces front (-Z) on a night-blue face. Nothing is sold or locked here.
--
-- Roblox terms: a SurfaceGui is 2D UI drawn on one face of a part. It lives in PlayerGui with its Adornee set to the
-- stand's Screen; when the stand streams out and back in, the tag fires again and the face is hung on the new copy.
-- A ProximityPrompt is Roblox's own walk-up button (a key, a tap or a gamepad button); this one is made on this
-- client only.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local EventRsvp = require(script.Parent.Parent.Components.EventRsvp)
local Outline = require(script.Parent.Parent.Components.Outline)
local Theme = require(script.Parent.Parent.Theme)
local UpdatePosterLogic = require(script.Parent.Parent.Components.UpdatePosterLogic)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

export type UpdatePoster = {
	destroy: (self: UpdatePoster) -> (),
}

type Face = {
	model: Instance,
	gui: SurfaceGui,
	picture: ImageLabel,
	name: TextLabel,
	countdown: TextLabel,
	hint: TextLabel,
	prompt: ProximityPrompt,
}

local TAG = "UpdatePoster"
local PIXELS_PER_STUD = 100 -- the 8.0 x 4.5 stud Screen is 800 x 450
local MAX_DISTANCE = 140 -- studs; past this the face is not drawn
local PROMPT_DISTANCE = 14
local TICK_SECONDS = 1
local GOLD = Color3.fromRGB(255, 214, 92)

local UpdatePoster = {}
UpdatePoster.__index = UpdatePoster

local function isScreen(child: Instance): boolean
	return child:IsA("BasePart") and (child.Name == "Screen" or child.Name:match("_Screen$") ~= nil)
end

local function screenOf(model: Instance): BasePart?
	for _, child in model:GetDescendants() do
		if isScreen(child) then
			return child :: BasePart
		end
	end
	return nil
end

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.display,
		TextColor3 = Theme.colors.white,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

function UpdatePoster.new(parent: Instance): UpdatePoster
	local self = setmetatable({}, UpdatePoster) :: any
	self._parent = parent
	self._faces = {} :: { [Instance]: Face }
	self._waiting = {} :: { [Instance]: RBXScriptConnection }
	self._connections = {} :: { RBXScriptConnection }
	self._alive = true
	self._eventId = nil :: string?
	self._asking = false
	for _, model in CollectionService:GetTagged(TAG) do
		self:_attach(model)
	end
	table.insert(
		self._connections,
		CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model: Instance)
			self:_attach(model)
		end)
	)
	table.insert(
		self._connections,
		CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model: Instance)
			self:_detach(model)
		end)
	)
	task.spawn(function()
		while self._alive do
			if next(self._faces) ~= nil then
				self:_renderAll()
			end
			task.wait(TICK_SECONDS)
		end
	end)
	return self :: UpdatePoster
end

-- Roblox's own Notify Me prompt for the Event on the poster; one at a time, and it fails quietly where Roblox does
-- not offer it.
function UpdatePoster._ask(self: any)
	local id: string? = self._eventId
	if id == nil or self._asking then
		return
	end
	self._asking = true
	task.spawn(function()
		EventRsvp.prompt(id :: string)
		self._asking = false
	end)
end

function UpdatePoster._attach(self: any, model: Instance)
	if self._faces[model] ~= nil or not model:IsDescendantOf(Workspace) then
		return
	end
	local screen = screenOf(model)
	if screen == nil then
		-- the Screen part can stream in after the tag fires: wait for it, then attach
		if self._waiting[model] == nil then
			self._waiting[model] = model.DescendantAdded:Connect(function(child: Instance)
				if isScreen(child) then
					local waiting = self._waiting[model]
					if waiting then
						waiting:Disconnect()
						self._waiting[model] = nil
					end
					if self._alive then
						self:_attach(model)
					end
				end
			end)
		end
		return
	end
	local gui: SurfaceGui = Create("SurfaceGui", {
		Name = "UpdatePosterFace",
		Adornee = screen,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = PIXELS_PER_STUD,
		MaxDistance = MAX_DISTANCE,
		LightInfluence = 0,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = self._parent,
	})
	local picture: ImageLabel = Create("ImageLabel", {
		Name = "Picture",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Crop,
		Image = "",
		ZIndex = 1,
		Parent = gui,
	})
	-- a dark band under the words, so they read on any picture
	Create("Frame", {
		Name = "TopBand",
		BackgroundColor3 = Color3.fromRGB(20, 14, 40),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 52),
		ZIndex = 2,
		Parent = gui,
	})
	Create("Frame", {
		Name = "BottomBand",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.fromRGB(20, 14, 40),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 112),
		ZIndex = 2,
		Parent = gui,
	})
	local header = text({
		Name = "Header",
		Position = UDim2.fromOffset(20, 4),
		Size = UDim2.new(1, -40, 0, 44),
		TextSize = 36,
		TextColor3 = GOLD,
		Text = "🔔 " .. UpdatePosterLogic.HEADER,
		ZIndex = 3,
		Parent = gui,
	})
	Outline.text(header, 3)
	local name = text({
		Name = "UpdateName",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -50),
		Size = UDim2.new(1, -40, 0, 58),
		TextSize = 56,
		TextScaled = true,
		ZIndex = 3,
		Parent = gui,
	})
	Create("UITextSizeConstraint", { MaxTextSize = 56, MinTextSize = 28, Parent = name })
	Outline.text(name, 4)
	local countdown = text({
		Name = "Countdown",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -8),
		Size = UDim2.new(0.5, -20, 0, 40),
		FontFace = Theme.fonts.bodyBold,
		TextSize = 32,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = gui,
	})
	Outline.text(countdown, 3)
	local hint = text({
		Name = "Hint",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -8),
		Size = UDim2.new(0.5, -20, 0, 40),
		FontFace = Theme.fonts.bodyBold,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = UpdatePosterLogic.HINT,
		ZIndex = 3,
		Parent = gui,
	})
	Outline.text(hint, 3)
	local prompt: ProximityPrompt = Create("ProximityPrompt", {
		Name = "UpdatePosterPrompt",
		ActionText = UpdatePosterLogic.ACTION,
		ObjectText = UpdatePosterLogic.HEADER,
		HoldDuration = 0,
		MaxActivationDistance = PROMPT_DISTANCE,
		RequiresLineOfSight = false,
		Enabled = false,
		Parent = screen,
	})
	prompt.Triggered:Connect(function()
		self:_ask()
	end)
	local face: Face = {
		model = model,
		gui = gui,
		picture = picture,
		name = name,
		countdown = countdown,
		hint = hint,
		prompt = prompt,
	}
	self._faces[model] = face
	self:_paint(face, self:_view())
end

function UpdatePoster._detach(self: any, model: Instance)
	local waiting = self._waiting[model]
	if waiting then
		waiting:Disconnect()
		self._waiting[model] = nil
	end
	local face: Face? = self._faces[model]
	if face then
		face.gui:Destroy()
		face.prompt:Destroy()
		self._faces[model] = nil
	end
end

function UpdatePoster._view(self: any): UpdatePosterLogic.View?
	-- the server's clock, so a device with a wrong clock still counts down to the real start
	local view =
		UpdatePosterLogic.view(Config.UpdateEvents, math.floor(Workspace:GetServerTimeNow()))
	self._eventId = if view then view.id else nil
	return view
end

function UpdatePoster._paint(_self: any, face: Face, view: UpdatePosterLogic.View?)
	if view == nil then
		face.picture.Image = ""
		face.name.Text = UpdatePosterLogic.SOON
		face.countdown.Text = ""
		face.hint.Visible = false
		face.prompt.Enabled = false
		return
	end
	local image = view.poster or ""
	if face.picture.Image ~= image then
		face.picture.Image = image
	end
	face.name.Text = view.name
	face.countdown.Text = view.countdown
	face.hint.Visible = true
	face.prompt.ObjectText = view.name
	face.prompt.Enabled = true
end

function UpdatePoster._renderAll(self: any)
	local view = self:_view()
	for _, face in self._faces do
		self:_paint(face, view)
	end
end

function UpdatePoster.destroy(self: any)
	self._alive = false
	for _, connection in self._connections do
		connection:Disconnect()
	end
	for _, waiting in self._waiting do
		waiting:Disconnect()
	end
	table.clear(self._waiting)
	for model in self._faces do
		self:_detach(model)
	end
end

return UpdatePoster
