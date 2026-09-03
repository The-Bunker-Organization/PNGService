local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local PngService = {}
PngService.__index = PngService

local PNG = require(script.PNG)

-- Default configuration
local DEFAULT_CONFIG = {
	MaxScale = 750,        -- Max dimension before downscaling
	PixelSize = 1,         -- Size of each pixel in the gradient (Default mode only)
	MaxKeys = 20,          -- Max pixels per gradient chunk (Default mode)
	MaxSpans = 10,         -- Max color spans per gradient batch (Groovy mode)
	Mode = "Default",      -- Render mode: "Default"|"Gradient"|"Groovy"|"Legacy"|"Text"|"TextLabel"
	Legacy = false,        -- Shorthand to enable Groovy/Legacy mode
	TextChunkRows = 75,    -- Rows of pixels packed into each TextLabel (Text mode)
	TextChar = "█",        -- Full-block character used as a pixel (Text mode)
	TextSize = 8          -- Font size in px; tune to match your canvas resolution (Text mode)
}

-- Resolve which render mode to use from config
local function resolveMode(config)
	if config.Legacy == true then
		return "Groovy"
	end
	local mode = config.Mode or "Default"
	if mode == "Legacy"    then return "Groovy" end
	if mode == "Gradient"  then return "Default" end
	if mode == "TextLabel" then return "Text" end
	return mode -- "Default" | "Groovy" | "Text"
end

-- Quantize color to reduce unique colors
local function quantizeChannel(value)
	return math.floor((value + 8) / 17) * 17
end

local function quantizeColor(px)
	local r = quantizeChannel(px.R * 255)
	local g = quantizeChannel(px.G * 255)
	local b = quantizeChannel(px.B * 255)
	return Color3.fromRGB(r, g, b)
end

-- Compare two Color3 values for equality
local function colorsEqual(c1, c2)
	if not c1 or not c2 then return false end
	return c1.R == c2.R and c1.G == c2.G and c1.B == c2.B
end

-- Main constructor
function PngService:Generate(url, targetPart, surfaceFace, config)
	local self = setmetatable({}, PngService)

	-- Merge config with defaults
	self.config = {}
	for k, v in pairs(DEFAULT_CONFIG) do
		self.config[k] = config and config[k] ~= nil and config[k] or v
	end

	self.url = url
	self.targetPart = targetPart
	self.surfaceFace = surfaceFace or Enum.NormalId.Front
	self.renderMode = resolveMode(self.config)

	-- Start rendering
	self:_render()

	return self
end

function PngService:_render()
	-- Load PNG from URL
	local success, data = pcall(function()
		return HttpService:GetAsync(self.url)
	end)

	if not success then
		error("Failed to load image from URL: " .. tostring(data))
	end

	local img = PNG.new(data)

	-- Calculate dimensions with downscaling
	local scaleFactor = 1
	local MAX_DIM = self.config.MaxScale
	if img.Width > MAX_DIM or img.Height > MAX_DIM then
		scaleFactor = math.min(MAX_DIM / img.Width, MAX_DIM / img.Height)
	end

	self.width = math.floor(img.Width * scaleFactor)
	self.height = math.floor(img.Height * scaleFactor)
	self.scaleFactor = scaleFactor
	self.img = img

	-- Pre-measure glyph dimensions for Text mode so _setupContainer can use them
	if self.renderMode == "Text" then
		local TEXT_SIZE = self.config.TextSize
		local CHAR      = self.config.TextChar
		local measured  = TextService:GetTextSize(
			CHAR, TEXT_SIZE, Enum.Font.Code, Vector2.new(math.huge, math.huge)
		)
		self._textCharW = measured.X
		self._textCharH = measured.Y
	end

	-- Setup container based on target type
	local container = self:_setupContainer()

	-- Build pixel buffer
	local pixelBuffer = self:_buildPixelBuffer()

	-- Render rows using the configured mode
	if self.renderMode == "Groovy" then
		self:_renderRowsGroovy(container, pixelBuffer)
	elseif self.renderMode == "Text" then
		self:_renderRowsText(container, pixelBuffer)
	else
		self:_renderRows(container, pixelBuffer)
	end

	return self
end

function PngService:_setupContainer()
	local targetPart = self.targetPart
	local PIXEL_SIZE = self.config.PixelSize

	-- In Text mode the canvas is measured in actual glyph px, not PixelSize units
	local isTextMode = (self.renderMode == "Text")
	local canvasW = isTextMode and (self.width  * self._textCharW) or (self.width  * PIXEL_SIZE)
	local canvasH = isTextMode and (self.height * self._textCharH) or (self.height * PIXEL_SIZE)

	if targetPart:IsA("LayerCollector") then
		self.container = targetPart
		self.containerFrame = Instance.new("Frame")
		self.containerFrame.Name = tostring(HttpService:GenerateGUID(true))
		self.containerFrame.Size = UDim2.new(1, 0, 1, 0)
		self.containerFrame.BackgroundTransparency = 1
		self.containerFrame.BorderSizePixel = 0
		self.containerFrame.Parent = self.container
		self.isGuiElement = true
		return self.containerFrame

	elseif targetPart:IsA("GuiObject") then
		self.container = targetPart
		self.containerFrame = Instance.new("Frame")
		self.containerFrame.Name = tostring(HttpService:GenerateGUID(true))
		self.containerFrame.Size = UDim2.new(1, 0, 1, 0)
		self.containerFrame.BackgroundTransparency = 1
		self.containerFrame.BorderSizePixel = 0
		self.containerFrame.Parent = self.container
		self.isGuiElement = true
		return self.containerFrame

	elseif targetPart:IsA("BasePart") then
		local surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Name = tostring(HttpService:GenerateGUID(true))
		surfaceGui.Face = self.surfaceFace
		surfaceGui.Adornee = targetPart
		surfaceGui.CanvasSize = Vector2.new(canvasW, canvasH)
		surfaceGui.Parent = targetPart

		self.container = surfaceGui
		self.containerFrame = surfaceGui
		self.isGuiElement = false
		return surfaceGui
	else
		error("Invalid target type. Must be a BasePart, LayerCollector, or GuiObject.")
	end
end

function PngService:_buildPixelBuffer()
	local pixelBuffer = {}
	local img = self.img
	local scaleFactor = self.scaleFactor

	for y = 1, self.height do
		pixelBuffer[y] = {}
		local srcY = math.floor((y - 1) / scaleFactor)
		for x = 1, self.width do
			local srcX = math.floor((x - 1) / scaleFactor)
			local px = img:GetPixel(srcX, srcY)
			pixelBuffer[y][x] = quantizeColor(px)
		end
	end

	return pixelBuffer
end

-- ─────────────────────────────────────────────
-- DEFAULT / GRADIENT RENDER MODE
-- ─────────────────────────────────────────────

function PngService:_renderRows(container, pixelBuffer)
	local WIDTH = self.width
	local HEIGHT = self.height
	local PIXEL_SIZE = self.config.PixelSize
	local MAX_KEYS = self.config.MaxKeys

	local rowsContainer = Instance.new("Folder")
	rowsContainer.Name = "RowsContainer"
	rowsContainer.Parent = container

	local useScale = self.isGuiElement

	local rowChunks = {}
	for y = 0, HEIGHT - 1 do
		rowChunks[y] = {}
		local chunkCount = math.ceil(WIDTH / MAX_KEYS)

		for c = 0, chunkCount - 1 do
			local chunkWidth = math.min(MAX_KEYS, WIDTH - c * MAX_KEYS)
			local chunkFrame = Instance.new("Frame")

			if useScale then
				local widthScale = chunkWidth / WIDTH
				local xScale = (c * MAX_KEYS) / WIDTH
				local heightScale = 1 / HEIGHT
				local yScale = y / HEIGHT

				chunkFrame.Size = UDim2.fromScale(widthScale, heightScale)
				chunkFrame.Position = UDim2.fromScale(xScale, yScale)
			else
				chunkFrame.Size = UDim2.new(0, chunkWidth * PIXEL_SIZE, 0, PIXEL_SIZE)
				chunkFrame.Position = UDim2.fromOffset(c * MAX_KEYS * PIXEL_SIZE, y * PIXEL_SIZE)
			end

			chunkFrame.BorderSizePixel = 0
			chunkFrame.BackgroundColor3 = Color3.new(1, 1, 1)

			local gradient = Instance.new("UIGradient")
			gradient.Parent = chunkFrame

			local keypoints = {}
			if chunkWidth == 1 then
				table.insert(keypoints, ColorSequenceKeypoint.new(0, Color3.new(0, 0, 0)))
				table.insert(keypoints, ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)))
			else
				for k = 1, chunkWidth do
					table.insert(keypoints, ColorSequenceKeypoint.new((k - 1) / (chunkWidth - 1), Color3.new(0, 0, 0)))
				end
			end
			gradient.Color = ColorSequence.new(keypoints)

			chunkFrame.Parent = rowsContainer
			table.insert(rowChunks[y], { gradient = gradient, width = chunkWidth })
		end

		if y % 4 == 0 then
			RunService.Heartbeat:Wait()
		end
	end

	for y = 0, HEIGHT - 1 do
		local chunks = rowChunks[y]
		for cIndex, chunk in ipairs(chunks) do
			local keypoints = {}
			if chunk.width == 1 then
				local x = (cIndex - 1) * MAX_KEYS + 1
				if x <= WIDTH then
					local color = pixelBuffer[y + 1][x]
					table.insert(keypoints, ColorSequenceKeypoint.new(0, color))
					table.insert(keypoints, ColorSequenceKeypoint.new(1, color))
				end
			else
				for k = 1, chunk.width do
					local x = (cIndex - 1) * MAX_KEYS + k
					if x <= WIDTH then
						table.insert(keypoints, ColorSequenceKeypoint.new((k - 1) / (chunk.width - 1), pixelBuffer[y + 1][x]))
					end
				end
			end
			chunk.gradient.Color = ColorSequence.new(keypoints)
		end
	end

	self.rowsContainer = rowsContainer
end

-- ─────────────────────────────────────────────
-- GROOVY / LEGACY RENDER MODE
-- ─────────────────────────────────────────────

-- Build run-length encoded spans from a pixel row
local function buildSpans(row, width)
	local spans = {}
	local i = 1
	while i <= width do
		local color = row[i]
		local len = 1
		while i + len <= width and colorsEqual(row[i + len], color) do
			len += 1
		end
		table.insert(spans, { len = len, color = color })
		i += len
	end
	return spans
end

-- Render a single batch of spans as one Frame + UIGradient
local function renderBatch(parent, spans, totalSpanWidth, yIndex, startXIndex, scaleW, scaleH)
	local f = Instance.new("Frame")
	f.Name = "Span"
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.Position = UDim2.fromScale((startXIndex - 1) * scaleW, (yIndex - 1) * scaleH)
	f.Size = UDim2.fromScale(totalSpanWidth * scaleW, scaleH)

	local gradient = Instance.new("UIGradient")
	local keypoints = {}
	local currentPos = 0

	for i, span in ipairs(spans) do
		local color = span.color
		local spanLen = span.len
		local startRatio = math.clamp(currentPos / totalSpanWidth, 0, 1)
		local endRatio   = math.clamp((currentPos + spanLen) / totalSpanWidth, 0, 1)

		table.insert(keypoints, ColorSequenceKeypoint.new(startRatio, color))

		if i < #spans then
			-- Hard edge: duplicate keypoints with tiny offset so no interpolation leaks
			local nextStart = math.clamp(endRatio + 0.0001, 0, 1)
			table.insert(keypoints, ColorSequenceKeypoint.new(endRatio, color))
			if nextStart < 1 then
				-- nextStart keypoint will be added as startRatio of the next span on the next iteration
			end
		else
			table.insert(keypoints, ColorSequenceKeypoint.new(endRatio, color))
		end

		currentPos += spanLen
	end

	local ok = pcall(function()
		gradient.Color = ColorSequence.new(keypoints)
	end)

	if ok then
		gradient.Parent = f
	else
		-- Fallback: solid color from first span
		f.BackgroundColor3 = spans[1].color
		gradient:Destroy()
	end

	f.Parent = parent
end

function PngService:_renderRowsGroovy(container, pixelBuffer)
	local WIDTH = self.width
	local HEIGHT = self.height
	local MAX_SPANS = self.config.MaxSpans

	local scaleW = 1 / WIDTH
	local scaleH = 1 / HEIGHT

	local rowsContainer = Instance.new("Folder")
	rowsContainer.Name = "RowsContainer"
	rowsContainer.Parent = container

	for y = 1, HEIGHT do
		local row = pixelBuffer[y]

		-- Build run-length spans for this row
		local spans = buildSpans(row, WIDTH)

		-- Batch spans into groups of MAX_SPANS
		local batchSpans = {}
		local batchPixelWidth = 0
		local batchStartX = 1
		local currentX = 1

		for i, span in ipairs(spans) do
			table.insert(batchSpans, span)
			batchPixelWidth += span.len

			if #batchSpans >= MAX_SPANS then
				renderBatch(rowsContainer, batchSpans, batchPixelWidth, y, batchStartX, scaleW, scaleH)
				batchStartX = currentX + span.len
				batchSpans = {}
				batchPixelWidth = 0
			end

			currentX += span.len
		end

		-- Flush remaining spans
		if #batchSpans > 0 then
			renderBatch(rowsContainer, batchSpans, batchPixelWidth, y, batchStartX, scaleW, scaleH)
		end

		-- Yield occasionally to prevent timeout
		if y % 4 == 0 then
			RunService.Heartbeat:Wait()
		end
	end

	self.rowsContainer = rowsContainer
end

-- ─────────────────────────────────────────────
-- TEXT / TEXTLABEL RENDER MODE
-- ─────────────────────────────────────────────

--[[
	Each chunk of TextChunkRows pixel-rows is packed into one TextLabel using
	Roblox RichText <font color="rgb(r,g,b)"> tags.

	Optimisation: the currently-open color tag is carried across newlines, so a
	new tag is only emitted when the color actually changes.  This keeps the
	string as short as possible while being 100% correct.

	Layout:
	  • TextLabel fills the full width of the container (scale 1, 0).
	  • Height in scale = chunkRows / totalHeight, positioned at the matching
	    y-offset so all chunks tile perfectly with no gaps.
	  • Font.Code (monospace) is used so every █ character has equal width and
	    height, giving square "pixels".  Tune TextSize to your canvas resolution.
]]

function PngService:_renderRowsText(container, pixelBuffer)
	local WIDTH     = self.width
	local HEIGHT    = self.height
	local CHAR      = self.config.TextChar
	local TEXT_SIZE = self.config.TextSize

	-- Use the glyph dimensions measured in _render (before container setup)
	local charW = self._textCharW
	local charH = self._textCharH

	-- Roblox caps TextLabel.Text at 200,000 characters.
	-- Worst case per row: every pixel is a different color, so each pixel costs:
	--   <font color="rgb(255,255,255)"> = 30 chars
	--   █                               =  1 char
	--   </font>                         =  7 chars
	-- Plus one \n per row separator.
	-- We use this upper bound to derive the maximum safe rows per chunk,
	-- then clamp the user-configured TextChunkRows to that value.
	local ROBLOX_TEXT_LIMIT  = 199000   -- 1k headroom below the hard 200k cap
	local WORST_CHARS_PER_ROW = WIDTH * (30 + 1 + 7) + 1
	local maxSafeChunkRows   = math.max(1, math.floor(ROBLOX_TEXT_LIMIT / WORST_CHARS_PER_ROW))
	local CHUNK = math.min(self.config.TextChunkRows, maxSafeChunkRows)

	local rowsContainer = Instance.new("Folder")
	rowsContainer.Name = "RowsContainer"
	rowsContainer.Parent = container

	local chunkIndex = 0
	local startRow   = 1

	while startRow <= HEIGHT do
		local endRow    = math.min(startRow + CHUNK - 1, HEIGHT)
		local chunkRows = endRow - startRow + 1

		-- ── Build the RichText string for this chunk ──────────────────────────
		local parts     = {}
		local openColor = nil

		for y = startRow, endRow do
			local row = pixelBuffer[y]
			local x   = 1

			while x <= WIDTH do
				local color  = row[x]
				local runEnd = x
				while runEnd < WIDTH and colorsEqual(row[runEnd + 1], color) do
					runEnd += 1
				end
				local runLen = runEnd - x + 1

				if not openColor or not colorsEqual(openColor, color) then
					if openColor then
						table.insert(parts, "</font>")
					end
					table.insert(parts, string.format(
						'<font color="rgb(%d,%d,%d)">',
						math.round(color.R * 255),
						math.round(color.G * 255),
						math.round(color.B * 255)
						))
					openColor = color
				end

				table.insert(parts, string.rep(CHAR, runLen))
				x = runEnd + 1
			end

			if y < endRow then
				table.insert(parts, "\n")
			end
		end

		if openColor then
			table.insert(parts, "</font>")
		end

		-- ── Create the TextLabel ──────────────────────────────────────────────
		-- Use measured charW/charH so each glyph occupies an exact square region.
		local topPx    = (startRow - 1) * charH   -- y offset in canvas px
		local heightPx = chunkRows      * charH   -- pixel height of this chunk
		local widthPx  = WIDTH          * charW   -- exact text content width

		local label = Instance.new("TextLabel")
		label.Name              = "TextChunk_" .. chunkIndex
		label.RichText          = true
		label.Text              = table.concat(parts)
		label.Font              = Enum.Font.Code
		label.TextSize          = TEXT_SIZE
		label.TextColor3        = Color3.new(1, 1, 1)
		label.TextXAlignment    = Enum.TextXAlignment.Left
		label.TextYAlignment    = Enum.TextYAlignment.Top
		label.BackgroundTransparency = 1
		label.BorderSizePixel   = 0
		label.TextWrapped       = false
		label.ClipsDescendants  = false
		label.AutomaticSize     = Enum.AutomaticSize.None
		-- Absolute sizing: width matches actual glyph columns, height matches glyph rows
		label.Position = UDim2.fromOffset(0, topPx)
		label.Size     = UDim2.new(0, widthPx, 0, heightPx)
		label.Parent   = rowsContainer

		chunkIndex += 1
		startRow    = endRow + 1

		RunService.Heartbeat:Wait()
	end

	self.rowsContainer = rowsContainer
end

-- ─────────────────────────────────────────────
-- PUBLIC API
-- ─────────────────────────────────────────────

function PngService:Destroy()
	if self.container and self.container:IsA("SurfaceGui") then
		self.container:Destroy()
	elseif self.containerFrame then
		self.containerFrame:Destroy()
	end
end

function PngService:GetDimensions()
	return self.width, self.height
end

function PngService:GetMode()
	return self.renderMode
end

return PngService
