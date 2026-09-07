--[[

	GIF/LZW.luau

	Decompresses GIF's variable-width LZW-compressed image data.

	This is NOT the same algorithm as PNG/Deflate.luau (DEFLATE is
	Huffman-coded LZ77; GIF uses a variant of LZW), but it reuses the same
	*bit-packing convention* PNG/Deflate.luau's bitstream already relies on:
	codes are packed into bytes starting from the least-significant bit,
	continuing across byte boundaries. That means the same
	"accumulate into a buffer, peel bits off the bottom" reader shape works
	here too, just sized for GIF's 2-12 bit variable code width.

	Reference: GIF89a Specification, Appendix F (LZW Compression / Variable-
	Length-Code / Clear Code handling).
	i vibecoded ts because i was tired kek (thx to qwen 3.8 27B)
]]

local LZW = {}

local lshift = bit32.lshift
local rshift = bit32.rshift
local band = bit32.band

-- LSB-first bit reader over a BinaryReader (see PNG/BinaryReader.luau).
local function createBitStream(reader)
	local buf = 0
	local bitsLeft = 0

	local stream = {}

	function stream:Read(count)
		while bitsLeft < count do
			local byte = reader:ReadByte()

			if not byte then
				-- Ran out of input. Only an error if the caller still
				-- needed more bits than we have buffered.
				if bitsLeft == 0 then
					return nil
				end
				break
			end

			buf = buf + lshift(byte, bitsLeft)
			bitsLeft = bitsLeft + 8
		end

		if bitsLeft < count then
			return nil
		end

		local bits = band(buf, lshift(1, count) - 1)
		buf = rshift(buf, count)
		bitsLeft = bitsLeft - count

		return bits
	end

	return stream
end

local MAX_CODE_SIZE = 12
local MAX_DICT_SIZE = lshift(1, MAX_CODE_SIZE)

--[[
	Decode(reader, minCodeSize, output, expected)

	reader        - BinaryReader positioned at the start of the GIF image
	                data's already-concatenated sub-blocks (i.e. the block
	                size bytes have already been stripped out; see
	                Decoder.luau's readSubBlocks).
	minCodeSize   - the "LZW Minimum Code Size" byte from the image data
	                block (2-8).
	output        - a pre-sized `buffer` to write decoded palette indices
	                into, one byte per pixel.
	expected      - number of index bytes expected (Width * Height of the
	                frame). Decoding stops once this many bytes have been
	                written, or the stream runs out / hits its End code,
	                whichever comes first.

	Returns the number of bytes actually written. Malformed/truncated
	streams are tolerated (decoding just stops early) rather than raising,
	since corrupt-but-mostly-fine GIFs exist in the wild and a partially
	decoded frame is more useful than a hard failure.
]]
function LZW.Decode(reader, minCodeSize, output, expected)
	if expected <= 0 then
		return 0
	end

	local clearCode = lshift(1, minCodeSize)
	local endCode = clearCode + 1

	local dict = {}
	local codeSize, nextCode, prevCode

	local function resetDict()
		table.clear(dict)
		for i = 0, clearCode - 1 do
			dict[i] = string.char(i)
		end
		nextCode = endCode + 1
		codeSize = minCodeSize + 1
		prevCode = nil
	end

	resetDict()

	local bitStream = createBitStream(reader)
	local written = 0

	local function emit(str)
		local len = #str
		if written + len > expected then
			len = expected - written
			if len <= 0 then
				return
			end
			str = str:sub(1, len)
		end

		buffer.writestring(output, written, str)
		written += len
	end

	while written < expected do
		local code = bitStream:Read(codeSize)

		if code == nil or code == endCode then
			break
		end

		if code == clearCode then
			resetDict()

			code = bitStream:Read(codeSize)
			if code == nil or code == endCode then
				break
			end

			local entry = dict[code]
			if not entry then
				break -- corrupt stream: first code after Clear must be a literal
			end

			emit(entry)
			prevCode = code
		else
			local entry

			if dict[code] then
				entry = dict[code]
			elseif code == nextCode and prevCode ~= nil then
				-- The classic LZW "KwKwK" special case: the code being
				-- read is the one about to be *defined*.
				local prevEntry = dict[prevCode]
				entry = prevEntry .. prevEntry:sub(1, 1)
			else
				break -- corrupt/unexpected code
			end

			emit(entry)

			if nextCode < MAX_DICT_SIZE and prevCode ~= nil then
				dict[nextCode] = dict[prevCode] .. entry:sub(1, 1)
				nextCode += 1

				if nextCode >= lshift(1, codeSize) and codeSize < MAX_CODE_SIZE then
					codeSize += 1
				end
			end
			-- If the dictionary is full (4096 entries) and the encoder
			-- doesn't send an explicit Clear, we just stop growing it and
			-- keep decoding at 12 bits/code, per common decoder practice.

			prevCode = code
		end
	end

	return written
end

return LZW
