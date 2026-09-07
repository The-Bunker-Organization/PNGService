local Decoder = require(script.Parent.Decoder)

local Composer = {}
Composer.__index = Composer

local Frame = {}
Frame.__index = Frame

function Frame:GetPixel(x, y)
	x = math.clamp(math.floor(x), 0, self.Width - 1)
	y = math.clamp(math.floor(y), 0, self.Height - 1)

	local offset = (y * self.Width + x) * 4
	local canvas = self.Canvas

	local r = buffer.readu8(canvas, offset)
	local g = buffer.readu8(canvas, offset + 1)
	local b = buffer.readu8(canvas, offset + 2)
	local a = buffer.readu8(canvas, offset + 3)

	return Color3.fromRGB(r, g, b), a
end

function Frame:Clone()
	local size = buffer.len(self.Canvas)
	local copy = buffer.create(size)
	buffer.copy(copy, 0, self.Canvas, 0, size)

	return setmetatable({
		Width = self.Width,
		Height = self.Height,
		Canvas = copy,
		Index = self.Index,
		Delay = self.Delay,
	}, Frame)
end

local function newCanvas(width, height)

	return buffer.create(math.max(width * height * 4, 1))
end

local function colorAt(colorTable, index)
	local entry = colorTable and colorTable[index]
	if entry then
		return entry[1], entry[2], entry[3]
	end
	return 0, 0, 0
end

local function clearRect(canvas, canvasWidth, canvasHeight, left, top, width, height)
	for y = math.max(top, 0), math.min(top + height, canvasHeight) - 1 do
		local rowOffset = y * canvasWidth
		for x = math.max(left, 0), math.min(left + width, canvasWidth) - 1 do
			local offset = (rowOffset + x) * 4
			buffer.writeu8(canvas, offset, 0)
			buffer.writeu8(canvas, offset + 1, 0)
			buffer.writeu8(canvas, offset + 2, 0)
			buffer.writeu8(canvas, offset + 3, 0)
		end
	end
end

local function drawFrame(canvas, canvasWidth, canvasHeight, frame)
	local indices = frame.Indices
	local colorTable = frame.ColorTable
	local transparentIndex = frame.TransparentIndex
	local fw, fh = frame.Width, frame.Height

	for y = 0, fh - 1 do
		local cy = frame.Top + y
		if cy >= 0 and cy < canvasHeight then
			local srcRow = y * fw
			local rowOffset = cy * canvasWidth

			for x = 0, fw - 1 do
				local cx = frame.Left + x
				if cx >= 0 and cx < canvasWidth then
					local index = buffer.readu8(indices, srcRow + x)

					if index ~= transparentIndex then
						local r, g, b = colorAt(colorTable, index)
						local offset = (rowOffset + cx) * 4
						buffer.writeu8(canvas, offset, r)
						buffer.writeu8(canvas, offset + 1, g)
						buffer.writeu8(canvas, offset + 2, b)
						buffer.writeu8(canvas, offset + 3, 255)
					end
				end
			end
		end
	end
end

local function applyDisposal(canvas, canvasWidth, canvasHeight, frame)
	if frame.Disposal == 2 then
		clearRect(canvas, canvasWidth, canvasHeight, frame.Left, frame.Top, frame.Width, frame.Height)
	elseif frame.Disposal == 3 and frame._snapshot then
		buffer.copy(canvas, 0, frame._snapshot, 0, buffer.len(canvas))
	end

end

function Composer.new(data)
	local raw = Decoder.Decode(data)

	local self = setmetatable({}, Composer)

	self.Width = raw.Width
	self.Height = raw.Height
	self.LoopCount = raw.LoopCount
	self.BackgroundColorIndex = raw.BackgroundColorIndex
	self.GlobalColorTable = raw.GlobalColorTable
	self._frames = raw.Frames

	self._canvas = newCanvas(self.Width, self.Height)
	self._cursor = 0

	return self
end

function Composer:GetFrameCount()
	return #self._frames
end

function Composer:GetFrameDelay(descriptorIndex)
	local frame = self._frames[descriptorIndex]
	return frame and frame.Delay or 0
end

function Composer:GetDuration()
	local total = 0
	for _, frame in ipairs(self._frames) do
		total += frame.Delay
	end
	return total
end

function Composer:GetFPS()
	local count = #self._frames
	local duration = self:GetDuration()
	if duration <= 0 then
		return 0
	end
	return count / duration
end

function Composer:_advance()
	local count = #self._frames
	local absolute = self._cursor + 1
	local descriptorIndex = ((absolute - 1) % count) + 1
	local frame = self._frames[descriptorIndex]

	if self._cursor > 0 then
		local prevDescriptorIndex = ((self._cursor - 1) % count) + 1
		applyDisposal(self._canvas, self.Width, self.Height, self._frames[prevDescriptorIndex])
	end

	if frame.Disposal == 3 then

		if not frame._snapshot then
			frame._snapshot = newCanvas(self.Width, self.Height)
		end
		buffer.copy(frame._snapshot, 0, self._canvas, 0, buffer.len(self._canvas))
	end

	drawFrame(self._canvas, self.Width, self.Height, frame)
	self._cursor = absolute
end

function Composer:GetFrame(absoluteIndex)
	absoluteIndex = math.max(1, math.floor(absoluteIndex))
	local count = #self._frames

	if absoluteIndex < self._cursor then
		self._canvas = newCanvas(self.Width, self.Height)
		self._cursor = 0
	end

	while self._cursor < absoluteIndex do
		self:_advance()
	end

	local descriptorIndex = ((absoluteIndex - 1) % count) + 1
	local frame = self._frames[descriptorIndex]

	return setmetatable({
		Width = self.Width,
		Height = self.Height,
		Canvas = self._canvas,
		Index = descriptorIndex,
		AbsoluteIndex = absoluteIndex,
		Delay = frame.Delay,
	}, Frame)
end

return Composer
