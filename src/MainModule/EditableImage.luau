

local AssetService = game:GetService("AssetService")

local EditableImage = {}

local mdim = 1024

local function computeGeometry(renderer)
	local width, height = renderer.width, renderer.height

	if width > mdim or height > mdim then
		local clampScale = math.min(mdim / width, mdim / height)
		width = math.max(1, math.floor(width * clampScale))
		height = math.max(1, math.floor(height * clampScale))
	end

	local img = renderer.img
	local scaleFactor = math.min(width / img.Width, height / img.Height)

	return width, height, scaleFactor
end

local function buildPixelBuffer(renderer, width, height, scaleFactor)
	local img = renderer.img
	local format = renderer._format

	if format == "GIF" and scaleFactor == 1 and width == img.Width and height == img.Height then
		return img.Canvas
	end

	local baseIndex = (format == "PNG") and 1 or 0
	local pixelData = buffer.create(width * height * 4)
	local offset = 0

	for y = 0, height - 1 do
		local srcY = math.floor(y / scaleFactor) + baseIndex
		for x = 0, width - 1 do
			local srcX = math.floor(x / scaleFactor) + baseIndex
			local color, alpha = img:GetPixel(srcX, srcY)

			buffer.writeu8(pixelData, offset, math.floor(color.R * 255 + 0.5))
			buffer.writeu8(pixelData, offset + 1, math.floor(color.G * 255 + 0.5))
			buffer.writeu8(pixelData, offset + 2, math.floor(color.B * 255 + 0.5))
			buffer.writeu8(pixelData, offset + 3, alpha or 255)

			offset += 4
		end
	end

	return pixelData
end


function EditableImage.Render(renderer, container)
	local width, height, scaleFactor = computeGeometry(renderer)
	local pixelData = buildPixelBuffer(renderer, width, height, scaleFactor)

	if
		renderer._editableImage
		and renderer._editableImageWidth == width
		and renderer._editableImageHeight == height
	then
		renderer._editableImage:WritePixelsBuffer(Vector2.new(0, 0), Vector2.new(width, height), pixelData)
		return
	end

	EditableImage.Destroy(renderer)

	local editableImage = AssetService:CreateEditableImage({ Size = Vector2.new(width, height) })
	editableImage:WritePixelsBuffer(Vector2.new(0, 0), Vector2.new(width, height), pixelData)

	local label = Instance.new("ImageLabel")
	label.Name = "EditableImageDisplay"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.ScaleType = Enum.ScaleType.Stretch
	label.ImageContent = Content.fromObject(editableImage)
	label.Parent = container

	renderer._editableImage = editableImage
	renderer._editableImageLabel = label
	renderer._editableImageWidth = width
	renderer._editableImageHeight = height
end


function EditableImage.Destroy(renderer)
	if renderer._editableImage then
		renderer._editableImage:Destroy()
		renderer._editableImage = nil
	end

	if renderer._editableImageLabel then
		renderer._editableImageLabel:Destroy()
		renderer._editableImageLabel = nil
	end

	renderer._editableImageWidth = nil
	renderer._editableImageHeight = nil
end

return EditableImage
