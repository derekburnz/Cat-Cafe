--!strict
-- The in-reach glow (F93, catch-rework.md section 1: "the client puts a soft glow on the stray its swing would hit
-- right now, so a player sees when to swing"). One Highlight at a time, on the stray NetSwingController names through
-- Moments.NetInReach; nil takes it off. The Highlight is made on this client only, inside the stray's model, so it
-- goes with the model when the stray is caught or leaves.
--   set(model?)   glow on this stray, or none

local Theme = require(script.Parent.Parent.Theme)

local NetGlow = {}

local current: Highlight? = nil
local target: Model? = nil

function NetGlow.set(model: Model?)
	if model == target and (model == nil or (current ~= nil and current.Parent ~= nil)) then
		return
	end
	if current ~= nil then
		current:Destroy()
		current = nil
	end
	target = model
	if model == nil or model.Parent == nil then
		return
	end
	local glow = Instance.new("Highlight")
	glow.Name = "CatCafeNetGlow"
	glow.Adornee = model
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.FillColor = Theme.colors.gold
	glow.FillTransparency = 0.8
	glow.OutlineColor = Theme.colors.white
	glow.OutlineTransparency = 0.15
	glow.Parent = model
	current = glow
end

return NetGlow
