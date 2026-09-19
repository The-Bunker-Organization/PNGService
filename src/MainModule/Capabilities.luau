--small shoutout to @@native

local AssetService = game:GetService("AssetService")
local Capabilities = {}
local cachedSupport = nil

function Capabilities.SupportsEditableImage()
	if cachedSupport ~= nil then
		return cachedSupport
	end

	local ok = pcall(function()
		local probe = AssetService:CreateEditableImage({ Size = Vector2.new(1, 1) })
		if not probe then
			error("createEditableImage returned nil")
		end

		local pixel = buffer.create(4)
		buffer.writeu8(pixel, 0, 255)
		buffer.writeu8(pixel, 1, 255)
		buffer.writeu8(pixel, 2, 255)
		buffer.writeu8(pixel, 3, 255)
		probe:WritePixelsBuffer(Vector2.new(0, 0), Vector2.new(1, 1), pixel)

		probe:Destroy()
	end)

	cachedSupport = ok
	return cachedSupport
end


function Capabilities.IsDetected()
	return cachedSupport ~= nil
end

return Capabilities
