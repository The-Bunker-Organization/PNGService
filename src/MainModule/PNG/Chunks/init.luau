local module = {}

module.IDAT = function(file, chunk)
	local crc = chunk.CRC
	local hash = file.Hash or 0

	local data = chunk.Data
	local buffer = data.Buffer

	file.Hash = bit32.bxor(hash, crc)
	file.ZlibStream = file.ZlibStream .. buffer
end

module.IEND = function(file)
	file.Reading = nil
end

module.IHDR = function(file, chunk)
	local data = chunk.Data

	file.Width = data:ReadInt32();
	file.Height = data:ReadInt32();

	file.BitDepth = data:ReadByte();
	file.ColorType = data:ReadByte();

	file.Methods =
	{
		Compression = data:ReadByte();
		Filtering   = data:ReadByte();
		Interlace   = data:ReadByte();
	}
end

module.PLTE = function(file, chunk)
	if not file.Palette then
		file.Palette = {}
	end

	local data = chunk.Data
	local palette = data:ReadAllBytes()

	if #palette % 3 ~= 0 then
		error("PNG - Invalid PLTE chunk.")
	end

	for i = 1, #palette, 3 do
		local r = palette[i]
		local g = palette[i + 1]
		local b = palette[i + 2]

		local color = Color3.fromRGB(r, g, b)
		local index = #file.Palette + 1

		file.Palette[index] = color
	end
end

module.bKGD = function(file, chunk)
	local data = chunk.Data

	local bitDepth = file.BitDepth
	local colorType = file.ColorType

	bitDepth = (2 ^ bitDepth) - 1

	if colorType == 3 then
		local index = data:ReadByte()
		file.BackgroundColor = file.Palette[index]
	elseif colorType == 0 or colorType == 4 then
		local gray = data:ReadUInt16() / bitDepth
		file.BackgroundColor = Color3.fromHSV(0, 0, gray)
	elseif colorType == 2 or colorType == 6 then
		local r = data:ReadUInt16() / bitDepth
		local g = data:ReadUInt16() / bitDepth
		local b = data:ReadUInt16() / bitDepth
		file.BackgroundColor = Color3.new(r, g, b)
	end
end

module.cHRM = require(script.cHRM)
module.gAMA = function(file, chunk)
	local data = chunk.Data
	local value = data:ReadUInt32()
	file.Gamma = value / 10e4
end

module.sRGB = function(file, chunk)
	local data = chunk.Data
	file.RenderIntent = data:ReadByte()
end

module.tEXt = function(file, chunk)
	local data = chunk.Data
	local key, value = "", ""

	for byte in data:IterateBytes() do
		local char = string.char(byte)

		if char == '\0' then
			key = value
			value = ""
		else
			value = value .. char
		end
	end

	file.Metadata[key] = value
end

module.tIME = function(file, chunk)
	local data = chunk.Data

	local timeStamp =
		{
			Year  = data:ReadUInt16();
			Month = data:ReadByte();
			Day   = data:ReadByte();

			Hour   = data:ReadByte();
			Minute = data:ReadByte();
			Second = data:ReadByte();
		}

	file.TimeStamp = timeStamp
end
module.tRNS = function(file, chunk)
	local data = chunk.Data

	local bitDepth = file.BitDepth
	local colorType = file.ColorType

	bitDepth = (2 ^ bitDepth) - 1

	if colorType == 3 then
		local palette = file.Palette
		local alphaMap = {}

		for i = 1, #palette do
			local alpha = data:ReadByte()

			if not alpha then
				alpha = 255
			end

			alphaMap[i] = alpha
		end

		file.AlphaData = alphaMap
	elseif colorType == 0 then
		local grayAlpha = data:ReadUInt16()
		file.Alpha = grayAlpha / bitDepth
	elseif colorType == 2 then
		-- TODO: This seems incorrect...
		local r = data:ReadUInt16() / bitDepth
		local g = data:ReadUInt16() / bitDepth
		local b = data:ReadUInt16() / bitDepth
		file.Alpha = Color3.new(r, g, b)
	else
		error("PNG - Invalid tRNS chunk")
	end
end

return module
