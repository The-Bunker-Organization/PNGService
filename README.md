# PNGService

> [!IMPORTANT]
> **PNGService is currently in Beta!**
>
> Please report bugs or issues on our [Discord Server](https://canary.discord.com/invite/MvVBbftUYm).
>
> For urgent questions, contact us at **[thebunkerproject@waifu.club](mailto:thebunkerproject@waifu.club)**.

## About

**PNGService** is a runtime image and animation loader for Roblox.

It can decode supported media directly at runtime without requiring the media to be uploaded as a Roblox asset. PNGService parses the binary data and renders the decoded pixels using Roblox GUI objects.

Currently supported formats include:

* **PNG** - Static images
* **GIF** - Animated images

## Features

* Runtime PNG loading without publishing
* Runtime GIF playback without publishing
* Decode media directly from binary data
* Supports rendering to `BasePart`, `GuiObject`, and `LayerCollector`
* Multiple rendering modes
* Automatic image downscaling for large images
* Animated GIF frame playback
* No Roblox image asset upload required

> PNGService does **not** create Roblox image assets from decoded data. Instead, decoded pixels are rendered through GUI objects and `UIGradient` instances.

## Supported Formats

| Format | Status       |
| ------ | ------------ |
| PNG    | 🟢 Available |
| GIF    | 🟢 Available |
| JPEG   | 🔴 Planned   |
| APNG (does someone even uses this)    | 🔴 Planned   |

## Rendering Modes

PNGService currently supports several rendering modes:

| Mode        | Description                            |
| ----------- | -------------------------------------- |
| `Default`   | Pixel rows rendered using `UIGradient` |
| `Groovy`    | Run-length encoded color spans         |
| `Legacy`    | Alias for `Groovy`                     |
| `Text`      | Renders pixels using colored text      |
| `TextLabel` | Alias for `Text`                       |
| `Gradient`  | Alias for `Default`                    |

## Building

The project uses **Rojo** and can be built as an `RBXM` or `RBXMX`.

You can also download prebuilt releases from the [Releases](https://github.com/The-Bunker-Organization/PNGService/releases) page.

## Installation

Insert the generated `PNGService` module into your experience.

The module should contain its required `PNG` and `GIF` modules:

```text
PNGService
├── MainModule
├── PNG
└── GIF
```

The main module requires both decoding modules internally.

## Using PNGService

Require the module:

```lua
local PngService = require(path.to.MainModule)
```

### Loading a PNG

PNGService accepts a URL for PNG loading:

```lua
local PngService = require(path.to.MainModule)

local renderer = PngService:Generate(
	"https://skidbar.kek/soyjak.png",
	workspace.Part,
	Enum.NormalId.Front
)
```

`Generate()` downloads the PNG using `HttpService`, decodes it, and renders it onto the target.

### Loading a PNG onto a GUI

A GUI object can also be used:

```lua
local renderer = PngService:Generate(
  "https://skidbar.kek/soyjak.png",
	workspace.Part.skidframe
)
```

Supported targets include:

* `BasePart`
* `LayerCollector`
* `GuiObject`

## GIF Playback

GIFs use raw binary data rather than a URL directly.

```lua
local HttpService = game:GetService("HttpService")
local PngService = require(path.to.MainModule) --also supports ID

local data = HttpService:GetAsync(
	"https://skidbar.kek/soyanime.gif",
	false
)

local renderer = PngService:GenerateGIF(
	data,
	workspace.Part,
	Enum.NormalId.Front
)
```

`GenerateGIF()` creates a GIF player, listens for frame changes, renders each frame, and starts playback automatically.

### GIF Configuration

Both PNG and GIF rendering support configuration options:

```lua
local renderer = PngService:GenerateGIF(
	data,
	workspace.Part,
	Enum.NormalId.Front,
	{
		MaxScale = 300,
		Mode = "Groovy",
		MaxSpans = 10,
	}
)
```

Available configuration values include:

```lua
{
	MaxScale = 750,
	PixelSize = 1,
	MaxKeys = 20,
	MaxSpans = 10,

	Mode = "Default",

	TextChunkRows = 75,
	TextChar = "█",
	TextSize = 8,
}
```

## Getting Dimensions

```lua
local width, height = renderer:GetDimensions()

print(width, height)
```

You can also retrieve the active rendering mode:

```lua
print(renderer:GetMode())
```

## Destroying a Renderer

When you're finished with an image or GIF:

```lua
renderer:Destroy()
```

For GIFs, this also destroys the GIF player and its connections.

## HTTP Requests

PNG URL loading and fetching GIF data require Roblox HTTP requests to be enabled.

Go to:

**Game Settings → Security → Allow HTTP Requests**

## Status

| Feature                   | Status             |
| ------------------------- | ------------------ |
| Rojo loader / RBXM Module | 🟢 Available       |
| PNG decoder               | 🟢 Available       |
| GIF decoder/player        | 🟢 Available       |
| Runtime PNG rendering     | 🟢 Available       |
| Runtime GIF rendering     | 🟢 Available       |
| Multiple rendering modes  | 🟢 Available       |
| JPEG support              | 🔴 Planned         |
| Video formats             | 🔴 Not Planned but maybe possible,depends on if it uses a hard decoding method kek         |
| Argon build               | 🟡 Working onto it |

## Contributing

Found a bug or have an improvement?

Open an issue on the repository or contact us through the [Discord Server](https://canary.discord.com/invite/MvVBbftUYm).

For urgent questions, email **[thebunkerproject@waifu.club](mailto:thebunkerproject@waifu.club)**.

## License

PNGService is free and open-source software licensed under the **GNU General Public License v3.0 (GPL-3.0)**.

You are free to use, modify, and redistribute the software under the terms of the license.

See the [LICENSE](LICENSE) file for the full license text.
