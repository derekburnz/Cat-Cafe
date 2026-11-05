--!strict
-- The camp stations' red "!" (camp-stations.md section 1; #1133 Picnic Basket, #1154 Yard Sale, #1232 Fish Pond):
-- the HUD's red "!" dot (#1074 / #1117) as a world BillboardGui on each station's `BangAnchor` attachment, 2 studs
-- above its sign. It shows while that extra holds something to claim (open and `held > 0`, the same state the
-- Cat Cannon picker's dot uses) and hides the moment it is claimed or while it refills. Each client only gets its
-- own CampExtrasState, and the billboards live in this player's PlayerGui, so only the owner ever sees theirs.
-- Shows within BANG_RANGE studs (`ReadyBangRange`, 150), bobs 1 stud every 2 s, and holds still with Reduce Motion.
--
-- Roblox terms: a BillboardGui is 2D UI drawn at a point in the 3D world, always facing the camera. Its Adornee is
-- the part or attachment it hangs from, and MaxDistance hides it past that many studs. CollectionService tags let
-- the client find the stations the server placed, including ones that stream in later (Model-Agent's
-- CatCafe_Camp_Park_PicnicStation, CatCafe_Camp_Neighbourhood_YardSaleStall and CatCafe_Camp_Woods_FishingHut,
-- tagged `CampExtra` with an ExtraId attribute).
--
--   ReadyBang.new(parent)   the billboards; :update(state) with every CampExtrasState, :destroy()
-- When each shows is CampExtrasLogic.bangShows (pure, so the cloud specs check it).

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CampExtrasLogic = require(script.Parent.CampExtrasLogic)
local Create = require(script.Parent.Create)
local Outline = require(script.Parent.Outline)
local Theme = require(script.Parent.Parent.Theme)

export type ReadyBang = {
	update: (self: ReadyBang, state: unknown) -> (),
	destroy: (self: ReadyBang) -> (),
}

local ReadyBang = {}
ReadyBang.__index = ReadyBang

ReadyBang.TAG = "CampExtra" -- shared/CampExtras.TAG
ReadyBang.ANCHOR = "BangAnchor"
ReadyBang.BOB_STUDS = 1
ReadyBang.BOB_SECONDS = 2 -- one full bob, up and back down
ReadyBang.LOOK_SECONDS = 2 -- how often a ready "!" with no station in yet looks for it again

type Bang = {
	gui: BillboardGui,
	bob: Tween?,
}

-- The station's BangAnchor attachment, or nil while the station (or that part of it) is streamed out.
local function anchorFor(extraId: string): Attachment?
	for _, instance in CollectionService:GetTagged(ReadyBang.TAG) do
		if
			instance:IsA("Model")
			and instance:GetAttribute("ExtraId") == extraId
			and instance:IsDescendantOf(Workspace)
		then
			local anchor = instance:FindFirstChild(ReadyBang.ANCHOR, true)
			if anchor ~= nil and anchor:IsA("Attachment") then
				return anchor :: Attachment
			end
		end
	end
	return nil
end

local function build(parent: Instance, extraId: string): BillboardGui
	local gui: BillboardGui = Create("BillboardGui", {
		Name = "CatCafeReadyBang_" .. extraId,
		-- studs up close, never smaller than 26 px far away, so it reads from the cannon landing
		Size = UDim2.new(1.6, 26, 1.6, 26),
		LightInfluence = 0,
		AlwaysOnTop = false, -- walls in front hide it, as they hide the station (the Rescue "!" does the same)
		MaxDistance = CampExtrasLogic.BANG_RANGE,
		ResetOnSpawn = false,
		Enabled = false,
		Parent = parent,
	})
	local dot: Frame = Create("Frame", {
		Name = "Dot",
		BackgroundColor3 = Theme.colors.red,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(dot, 2)
	local mark: TextLabel = Create("TextLabel", {
		Name = "Mark",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.8),
		Position = UDim2.fromScale(0, 0.1),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.white,
		Text = "!",
		Parent = dot,
	})
	Outline.text(mark, 2)
	return gui
end

function ReadyBang.new(parent: Instance): ReadyBang
	local self = setmetatable({}, ReadyBang) :: any
	self._bangs = {} :: { [string]: Bang }
	self._state = nil :: unknown
	self._connections = {} :: { RBXScriptConnection }
	for _, extraId in CampExtrasLogic.BANG_EXTRAS do
		self._bangs[extraId] = { gui = build(parent, extraId), bob = nil }
	end
	local function refresh()
		self:_apply()
	end
	-- stations streaming in or out, and the Reduce Motion switch
	table.insert(
		self._connections,
		CollectionService:GetInstanceAddedSignal(ReadyBang.TAG):Connect(refresh)
	)
	table.insert(
		self._connections,
		CollectionService:GetInstanceRemovedSignal(ReadyBang.TAG):Connect(refresh)
	)
	table.insert(
		self._connections,
		GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
			for _, bang: Bang in self._bangs do
				self:_still(bang)
			end
			refresh()
		end)
	)
	-- a station's parts stream in one by one, so a ready "!" whose anchor isn't in yet (or streamed out) looks again
	self._alive = true
	task.spawn(function()
		while self._alive do
			task.wait(ReadyBang.LOOK_SECONDS)
			for extraId, bang: Bang in self._bangs do
				local adornee: Instance? = (bang.gui :: any).Adornee
				local lost = adornee == nil or not (adornee :: Instance):IsDescendantOf(Workspace)
				if self._alive and CampExtrasLogic.bangShows(self._state, extraId) and lost then
					self:_apply()
					break
				end
			end
		end
	end)
	return self :: ReadyBang
end

function ReadyBang._still(_self: any, bang: Bang)
	local bob = bang.bob
	if bob ~= nil then
		bob:Cancel()
		bang.bob = nil
	end
	bang.gui.StudsOffset = Vector3.zero
end

function ReadyBang._apply(self: any)
	for extraId, bang: Bang in self._bangs do
		local ready = CampExtrasLogic.bangShows(self._state, extraId)
		local anchor = if ready then anchorFor(extraId) else nil
		local gui: any = bang.gui
		gui.Adornee = anchor -- nil while hidden, so a streamed-out station isn't held on to
		local on = anchor ~= nil
		bang.gui.Enabled = on
		if not on then
			self:_still(bang)
		elseif bang.bob == nil and not GuiService.ReducedMotionEnabled then
			local info = TweenInfo.new(
				ReadyBang.BOB_SECONDS / 2,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.InOut,
				-1,
				true
			)
			local bob = TweenService:Create(
				bang.gui,
				info,
				{ StudsOffset = Vector3.new(0, ReadyBang.BOB_STUDS, 0) }
			)
			bob:Play()
			bang.bob = bob
		end
	end
end

-- Every CampExtrasState: each station's "!" shows or hides.
function ReadyBang.update(self: any, state: unknown)
	self._state = state
	self:_apply()
end

function ReadyBang.destroy(self: any)
	self._alive = false
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	for _, bang: Bang in self._bangs do
		self:_still(bang)
		bang.gui:Destroy()
	end
	table.clear(self._bangs)
end

return ReadyBang
