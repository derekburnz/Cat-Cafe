---
name: remote-security-checklist
description: Server-side security rules for Cat Cafe remotes and data: never trust the client, validate types/ranges/ownership, rate-limit, server cooldowns, distance checks, text filtering, DataStore session locking and retries. Use when writing or reviewing any RemoteEvent handler, purchase, catch, serve or save code.
---

# Remote security checklist (Cat Cafe)

Roblox runs one server per game instance and a client on every player's device. The client is the player's own computer, so an exploiter can run any code there: fire any RemoteEvent with any arguments, teleport, read everything in ReplicatedStorage. For Derek: treat every remote like an unauthenticated API endpoint on the public internet. The server is the only trusted party.

## The checklist (apply to every remote handler)
1. **Type check every argument** with a guard before using it. Luau types are compile-time only; a client can send a table where you expect a string.
2. **Range check** numbers (quantities 1 to 99, no NaN, no negative, no `math.huge`). Use `Guard.isInt(n, min, max)`.
3. **Id check** against `Catalog`: unknown item id or breed id means drop the request, no error reply.
4. **Ownership check**: the cat, cafe slot or order must belong to that player on the server's own record.
5. **State check**: can this action happen now (order is pending, cat is still in the alley, slot is empty)?
6. **Distance check** for world interactions: player's HumanoidRootPart within `Config.*.Range` studs of the target, computed on the server.
7. **Rate limit** every remote per player (`RateLimit.new(perSecond)`); drop silently when exceeded; log repeat offenders with `warn`.
8. **Server cooldowns** for gameplay actions (serve, catch) stored on the server, never read from the client.
9. **Never let the client set** coins, inventory, cat ownership, upgrade level or position of anything that matters. The client sends intents, the server computes outcomes.
10. **Reply with facts, not acknowledgements**: after a purchase the server sends the new profile snapshot; the client renders what it receives.
11. **Filter user text** (cafe name, cat names) with `TextService:FilterStringAsync` on the server before storing or showing it to anyone else. Store the raw text only for the owner, and filter again when displaying to others.
12. **Protect the save**: session locking, retries, no overwriting a profile that failed to load.

## Cat Cafe threat table
| Remote | What an exploiter tries | Server rule |
|---|---|---|
| `RequestServe(orderId)` | serve orders that are not theirs, serve 100 times a second, serve from the alley | order owned by player and pending; cooldown `Config.Cafe.ServeCooldown`; player within range of the counter; rate limit |
| `RequestBuy(itemId)` | buy with fake ids, negative prices, buy twice in one frame | id in Catalog; price read from Catalog on the server; `coins >= price` checked and deducted in one step on the server record; rate limit |
| `RequestCatch(catId)` | catch a cat across the map, catch the same cat twice, spoof breed | cat exists in server table; distance check; remove from table before granting; breed from the server record |
| `RequestRename(text)` | profanity, personal info | filter with TextService; length 1 to 20; rate limit 1 per 10 s |
| Any | flood remotes to lag the server | global per-player limiter plus per-remote limiters; kick after N warnings only if clearly abusive |

## Guard module (src/shared/Guard.luau)
```lua
--!strict
-- Guard: runtime type guards for remote arguments. Everything from the client is `unknown` until it passes one.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog"))

local Guard = {}

function Guard.isString(value: unknown, maxLen: number?): boolean
	return type(value) == "string" and #(value :: string) <= (maxLen or 64)
end

function Guard.isInt(value: unknown, min: number, max: number): boolean
	if type(value) ~= "number" then
		return false
	end
	local n = value :: number
	return n == n and n == math.floor(n) and n >= min and n <= max
end

function Guard.isItemId(value: unknown): boolean
	return type(value) == "string" and Catalog.Items[value :: string] ~= nil
end

function Guard.isCatId(value: unknown): boolean
	return type(value) == "string" and #(value :: string) <= 40
end

return Guard
```

## Rate limiter (src/server/Util/RateLimit.luau)
```lua
--!strict
-- RateLimit: token bucket per player. allow(player) returns false when the player is over budget.
local Players = game:GetService("Players")

local RateLimit = {}
RateLimit.__index = RateLimit

export type RateLimit = typeof(setmetatable({} :: { rate: number, burst: number, buckets: { [Player]: { tokens: number, last: number } } }, RateLimit))

function RateLimit.new(perSecond: number, burst: number?): RateLimit
	local self = setmetatable({ rate = perSecond, burst = burst or perSecond, buckets = {} }, RateLimit)
	Players.PlayerRemoving:Connect(function(player)
		self.buckets[player] = nil
	end)
	return self
end

function RateLimit.allow(self: RateLimit, player: Player): boolean
	local now = os.clock()
	local bucket = self.buckets[player]
	if not bucket then
		bucket = { tokens = self.burst, last = now }
		self.buckets[player] = bucket
	end
	bucket.tokens = math.min(self.burst, bucket.tokens + (now - bucket.last) * self.rate)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

return RateLimit
```

## Data saving
DataStoreService is Roblox's key-value store, with request budgets and occasional failures. Rules:
- **Session locking**: a profile may be open on one server at a time. If a player hops servers while the old one still holds the lock, wait or steal only after a timeout. Recommended: vendor **ProfileStore** (loleris, single ModuleScript) into `src/server/Vendor/ProfileStore.luau`; it implements locking, retries and `Reconcile` for new default fields.
- **Load before play**: if the load fails, do not give the player a default profile that will later overwrite their real one. Kick with a friendly message ("Could not load your save, please rejoin") instead.
- **Reconcile, never reset**: new fields get defaults; existing fields are never dropped on a schema change. Keep a `Version` field.
- **Save on leave and on shutdown**: `Players.PlayerRemoving` releases the profile; `game:BindToClose` waits for all saves (ProfileStore handles both).
- **Autosave** every 30 to 60 s for long sessions.
- **Robux purchases** (`ProcessReceipt`) grant only after the profile is loaded and are idempotent on `PurchaseId`; return `Granted` only after the save succeeds.
- **Studio**: DataStores need "Enable Studio access to API services" on the dev place, and the dev place must use a different DataStore name or scope than the live place (`Config.Data.StoreName = "CatCafeDev"` vs `"CatCafe"`).

## Review questions (the luau-reviewer asks these)
- Which line proves the player owns the thing they are acting on?
- Where is the price read from? (Must be the server's Catalog.)
- What happens if this remote is fired 1000 times in a second?
- What does the player see if the save fails?
- Can two remotes racing each other (buy + buy, catch + catch) double-grant? (Deduct or remove before granting.)
