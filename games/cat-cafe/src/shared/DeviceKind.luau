--!strict
-- Which kind of device the client is, for analytics only (growth analytics-plan: the `device` field on the joined step
-- and on session_end). Pure: the client reads the inputs from UserInputService, GuiService and the camera. A guess,
-- never used for gameplay or UI layout.

local DeviceKind = {}

export type Kind = "phone" | "tablet" | "pc" | "console"

-- Short side of the viewport, in pixels, under which a touch device counts as a phone.
DeviceKind.PHONE_SHORT_SIDE = 600

export type Inputs = {
	touch: boolean, -- UserInputService.TouchEnabled
	keyboard: boolean, -- UserInputService.KeyboardEnabled
	tenFoot: boolean, -- GuiService:IsTenFootInterface(): a console on a TV
	viewport: Vector2, -- Workspace.CurrentCamera.ViewportSize
}

function DeviceKind.classify(inputs: Inputs): Kind
	if inputs.tenFoot then
		return "console"
	end
	if inputs.touch and not inputs.keyboard then
		local shortSide = math.min(inputs.viewport.X, inputs.viewport.Y)
		return if shortSide < DeviceKind.PHONE_SHORT_SIDE then "phone" else "tablet"
	end
	return "pc"
end

return DeviceKind
