--!strict
-- Argument validators for remotes. Each returns the cleaned value or nil. Never trust the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Guard = {}

-- A catalog id or instance id: short, ASCII letters, digits, underscores and hyphens only. Cat uids are the
-- first 12 characters of a lowercased GUID ("fa3848f6-e97", CafeService newUid), so the hyphen has to pass or no
-- caught cat can be placed, sold or renamed (laptop Studio run 2026-10-27). Capitals pass too (#4564, Derek
-- 2026-11-15): the Ticket Booth prizes ("goldenCrate"), the Dragon Keep cards ("doubleJump"), the Fish Store keys
-- ("stylishPack"), the late index milestones ("totalAll") and the event decor ("Decor_PartyBunting") are camelCase,
-- and a lowercase-only guard dropped every one of those calls silently. Each caller still looks the id up exactly.
function Guard.id(value: unknown): string?
	if type(value) ~= "string" or #value == 0 or #value > Config.MaxIdLength then
		return nil
	end
	if value:match("^[%w_%-]+$") == nil then
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
