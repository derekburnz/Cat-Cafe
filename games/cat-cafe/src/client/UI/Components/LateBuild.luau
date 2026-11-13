--!strict
-- #3722 (client start-up over 15 s on slow phones): a window's rows or cards built after start-up instead of inside
-- UI.init's run. `queue()` marks the build as wanted and runs it `after` seconds later in its own run; `ensure()`
-- runs it at once if it is still wanted (a window opened before the delay). A newer `queue()` or `cancel()` drops an
-- older wait. `done` runs after a delayed build, for the screen to paint itself again.
--   local late = LateBuild.new(8, function() self:_buildRows() end, function() self:_repaint() end)
--   late:queue()   -- in setCatalog
--   late:ensure()  -- at the top of render, while the window is open

local LateBuild = {}
LateBuild.__index = LateBuild

export type LateBuild = {
	wanted: boolean,
	queue: (self: LateBuild) -> (),
	ensure: (self: LateBuild) -> (),
	cancel: (self: LateBuild) -> (),
}

function LateBuild.new(after: number, build: () -> (), done: (() -> ())?): LateBuild
	local self = setmetatable({}, LateBuild) :: any
	self.wanted = false
	self._after = after
	self._build = build
	self._done = done
	self._token = 0
	return self :: LateBuild
end

function LateBuild.queue(self: any)
	self.wanted = true
	self._token += 1
	local token: number = self._token
	task.delay(self._after, function()
		if token ~= self._token or not self.wanted then
			return
		end
		self:ensure()
		local done = self._done
		if done ~= nil then
			done()
		end
	end)
end

function LateBuild.ensure(self: any)
	if self.wanted then
		self.wanted = false
		self._build()
	end
end

function LateBuild.cancel(self: any)
	self.wanted = false
	self._token += 1
end

return LateBuild
