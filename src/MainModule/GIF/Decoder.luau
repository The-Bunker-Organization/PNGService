local BinaryReader = require(script.Parent.Parent.PNG.BinaryReader)
local LZW = require(script.Parent.LZW)

local Decoder = {}

local band = bit32.band
local rshift = bit32.rshift

local EXTENSION_INTRODUCER = 0x21
local IMAGE_SEPARATOR = 0x2C
local TRAILER = 0x3B

local GRAPHIC_CONTROL_LABEL = 0xF9
local APPLICATION_LABEL = 0xFF
local COMMENT_LABEL = 0xFE
local PLAINTEXT_LABEL = 0x01

local function readUInt16LE(reader)
	local low = reader:ReadByte()
	local high = reader:ReadByte()

	if not low or not high then
		return 0
	end

	return low + high * 256
end

local function readColorTable(reader, sizeField)
	local count = bit32.lshift(1, sizeField + 1)
	local colors = {}

	for i = 0, count - 1 do
		local r, g, b = reader:ReadBytes(3)
		colors[i] = { r or 0, g or 0, b or 0 }
	end

	return colors
end

local function readSubBlocks(reader)
	local parts = {}
	local count = 0

	while true do
		local size = reader:ReadByte()
		if not size or size == 0 then
			break
		end
		count += 1
		parts[count] = reader:ReadString(size)
	end

	return table.concat(parts)
end

local function skipSubBlocks(reader)
	while true do
		local size = reader:ReadByte()
		if not size or size == 0 then
			break
		end
		reader:ReadString(size)
	end
end

local INTERLACE_PASSES = {
	{ start = 0, step = 8 },
	{ start = 4, step = 8 },
	{ start = 2, step = 4 },
	{ start = 1, step = 2 },
}

local function deinterlace(source, width, height)
	local dest = buffer.create(width * height)
	local srcRow = 0

	for _, pass in ipairs(INTERLACE_PASSES) do
		local y = pass.start
		while y < height do
			buffer.copy(dest, y * width, source, srcRow * width, width)
			srcRow += 1
			y += pass.step
		end
	end

	return dest
end

function Decoder.Decode(data)
	local reader = BinaryReader.new(data)

	local magic = reader:ReadString(6)
	if magic ~= "GIF87a" and magic ~= "GIF89a" then
		error("GIF - Input data is not a GIF file.", 2)
	end

	local gif = {
		Version = magic,
		Frames = {},
		LoopCount = nil,
	}

	gif.Width = readUInt16LE(reader)
	gif.Height = readUInt16LE(reader)

	local lsdPacked = reader:ReadByte() or 0
	local hasGCT = band(lsdPacked, 0x80) ~= 0
	local gctSize = band(lsdPacked, 0x07)

	gif.BackgroundColorIndex = reader:ReadByte() or 0
	gif.PixelAspectRatio = reader:ReadByte() or 0

	if hasGCT then
		gif.GlobalColorTable = readColorTable(reader, gctSize)
	end

	local pendingDelay = 0
	local pendingDisposal = 0
	local pendingTransparentIndex = nil
	local pendingUserInput = false

	while true do
		local blockType = reader:ReadByte()

		if not blockType or blockType == TRAILER then
			break
		elseif blockType == EXTENSION_INTRODUCER then
			local label = reader:ReadByte()

			if label == GRAPHIC_CONTROL_LABEL then
				reader:ReadByte()
				local gcePacked = reader:ReadByte() or 0

				pendingDisposal = band(rshift(gcePacked, 2), 0x07)
				pendingUserInput = band(gcePacked, 0x02) ~= 0
				local hasTransparency = band(gcePacked, 0x01) ~= 0

				pendingDelay = readUInt16LE(reader) / 100

				local transparentIndex = reader:ReadByte() or 0
				pendingTransparentIndex = hasTransparency and transparentIndex or nil

				reader:ReadByte()
			elseif label == APPLICATION_LABEL then
				reader:ReadByte()
				local appId = reader:ReadString(11)
				local appData = readSubBlocks(reader)

				if appId == "NETSCAPE2.0" and #appData >= 3 then
					local lo = appData:byte(2)
					local hi = appData:byte(3)
					gif.LoopCount = lo + hi * 256
				end
			elseif label == COMMENT_LABEL then
				skipSubBlocks(reader)
			elseif label == PLAINTEXT_LABEL then
				reader:ReadByte()
				reader:ReadString(12)
				skipSubBlocks(reader)
			else

				skipSubBlocks(reader)
			end
		elseif blockType == IMAGE_SEPARATOR then
			local left = readUInt16LE(reader)
			local top = readUInt16LE(reader)
			local width = readUInt16LE(reader)
			local height = readUInt16LE(reader)

			local idPacked = reader:ReadByte() or 0
			local hasLCT = band(idPacked, 0x80) ~= 0
			local isInterlaced = band(idPacked, 0x40) ~= 0
			local lctSize = band(idPacked, 0x07)

			local localColorTable = nil
			if hasLCT then
				localColorTable = readColorTable(reader, lctSize)
			end

			local minCodeSize = reader:ReadByte() or 2
			local compressed = readSubBlocks(reader)

			local pixelCount = width * height
			local indices = buffer.create(math.max(pixelCount, 1))

			if pixelCount > 0 then
				local subReader = BinaryReader.new(compressed)
				LZW.Decode(subReader, minCodeSize, indices, pixelCount)

				if isInterlaced then
					indices = deinterlace(indices, width, height)
				end
			end

			table.insert(gif.Frames, {
				Left = left,
				Top = top,
				Width = width,
				Height = height,
				Indices = indices,
				ColorTable = localColorTable or gif.GlobalColorTable,

				Delay = pendingDelay > 0 and pendingDelay or 0.1,
				Disposal = pendingDisposal,
				TransparentIndex = pendingTransparentIndex,
				UserInput = pendingUserInput,
			})

			pendingDelay = 0
			pendingDisposal = 0
			pendingTransparentIndex = nil
			pendingUserInput = false
		else

			break
		end
	end
	return gif
end

return Decoder
