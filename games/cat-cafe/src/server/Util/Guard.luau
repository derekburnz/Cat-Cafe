--!strict
-- Argument validators for remotes. Each returns the cleaned value or nil. Never trust the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Guard = {}

-- A catalog id or instance id: short, lowercase letters, digits and underscores only.
function Guard.id(value: unknown): string?
	if type(value) ~= "string" or #value == 0 or #value > Config.MaxIdLength then
		return nil
	end
	if value:match("^[%l%d_]+$") == nil then
		return nil
	end
	return value
end

function Guard.bool(value: unknown): boolean?
	if type(value) == "boolean" then
		return value
	end
	return nil
end

function Guard.int(value: unknown, min: number, max: number): number?
	if type(value) ~= "number" or value ~= value or value ~= math.floor(value) then
		return nil
	end
	if value < min or value > max then
		return nil
	end
	return value
end

function Guard.oneOf(value: unknown, allowed: { string }): string?
	if type(value) ~= "string" then
		return nil
	end
	for _, option in allowed do
		if option == value then
			return value
		end
	end
	return nil
end

return Guard
