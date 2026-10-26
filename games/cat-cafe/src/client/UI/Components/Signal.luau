--!strict
-- Minimal signal. Enough for UI intents; not a replacement for a full library.

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal = {
	Connect: (self: Signal, handler: (...any) -> ()) -> Connection,
	Once: (self: Signal, handler: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	DisconnectAll: (self: Signal) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new(): Signal
	local self = setmetatable({ _handlers = {} :: { [Connection]: (...any) -> () } }, Signal)
	return (self :: any) :: Signal
end

function Signal.Connect(self: any, handler: (...any) -> ()): Connection
	local connection = {} :: any
	connection.Connected = true
	connection.Disconnect = function(conn: any)
		if conn.Connected then
			conn.Connected = false
			self._handlers[conn] = nil
		end
	end
	self._handlers[connection] = handler
	return connection :: Connection
end

function Signal.Once(self: any, handler: (...any) -> ()): Connection
	local connection: Connection
	connection = Signal.Connect(self, function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal.Fire(self: any, ...: any)
	for _, handler in self._handlers do
		task.spawn(handler, ...)
	end
end

function Signal.DisconnectAll(self: any)
	for connection in self._handlers do
		(connection :: any).Connected = false
	end
	table.clear(self._handlers)
end

return Signal
