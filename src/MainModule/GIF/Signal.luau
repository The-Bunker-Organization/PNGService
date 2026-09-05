--[[
    Signal.luau
	A minimal pure-Luau event emitter (no BindableEvent/Instance involved),
	used for GIFPlayer.FrameChanged / .Completed / .PlayingChanged.
]]

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _connections = {}, _nextId = 1 }, Signal)
end

function Signal:Connect(fn)
	local id = self._nextId
	self._nextId += 1
	self._connections[id] = fn

	local connections = self._connections
	local connection = { Connected = true }

	function connection:Disconnect()
		if self.Connected then
			connections[id] = nil
			self.Connected = false
		end
	end
	connection.Destroy = connection.Disconnect

	return connection
end

function Signal:Fire(...)
	for _, fn in pairs(self._connections) do
		local ok, err = pcall(fn, ...)
	end
end

function Signal:DisconnectAll()
	table.clear(self._connections)
end

return Signal
