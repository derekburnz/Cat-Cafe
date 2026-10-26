--!strict
-- Minimal typed signal so shared and server code do not depend on a Wally package.
-- Handlers run in their own thread (task.spawn), so one erroring handler never breaks the others.

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local handlers: { [Connection]: (T...) -> () } = {}
	local self = {} :: any

	function self.Connect(_, handler: (T...) -> ()): Connection
		local connection = {} :: any
		connection.Connected = true
		function connection.Disconnect(conn)
			conn.Connected = false
			handlers[conn] = nil
		end
		handlers[connection] = handler
		return connection
	end

	function self.Once(_, handler: (T...) -> ()): Connection
		local connection: Connection
		connection = self:Connect(function(...)
			connection:Disconnect()
			handler(...)
		end)
		return connection
	end

	function self.Fire(_, ...: T...)
		for _, handler in handlers do
			task.spawn(handler, ...)
		end
	end

	function self.DisconnectAll()
		for connection in handlers do
			connection.Connected = false
		end
		table.clear(handlers)
	end

	return self :: Signal<T...>
end

return Signal
