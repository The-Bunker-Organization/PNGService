# PNGService

> [!IMPORTANT]
> **PNGService is currently in Beta!**
> Please report bugs or issues on our [Discord Server](https://canary.discord.com/invite/MvVBbftUYm).
>
> For urgent questions, contact us at **[thebunkerproject@waifu.club](mailto:thebunkerproject@waifu.club)**.

## About

**PNGService** is a runtime **PNG loader** that allows you to load PNGS files directly inside a Roblox environment without publishing.

### Features

* Runtime image loading without publishing
* Works through a Roblox env by default
* Parse any PNG type file
* Render a specific frame of a GIF
* Currently in **Beta**

## Building

The project uses a `Rojo` format that can be built as a RBXM or RBXMX,Check [Releases](https://github.com/The-Bunker-Organization/PNGService/releases) for the RBXM without building yourself.

## Using RBXM
Just path it to your instance or GUI for using it,it will generate a GUI for it using the PNG binary parsed
```
local PngService = require(path.to.MainModule) --you can also upload it and use as a module id like require(670000)

local renderer = PngService:Generate(
	"https://example.com/image.png",
	workspace.Part, --or any instance
	Enum.NormalId.Front --side you wanna
)
```

### GIF support

`Generate()` also accepts GIFs, but it renders a single still frame rather than playing the animation
```
local PngService = require(path.to.MainModule)

local renderer = PngService:Generate(
	"https://example.com/image.gif",
	workspace.Part,
	Enum.NormalId.Front,
	{
		Frame = 5
	}
)
```

* `Frame` is **1-based** - the first frame of the GIF is `Frame = 1`.
* If `Frame` is omitted, it defaults to `1`.
* `Frame` must be a whole number between `1` and the GIF's total frame count; anything else (`0`, negative, non-integer, or past the last frame) makes `Generate()` error instead of silently wrapping around.
* Static PNGs ignore `Frame` entirely, since a PNG only ever has one frame.
* `GenerateGIF()` has been removed. Use `Generate()` for both PNGs and GIFs going forward.

## Status

| Feature         | Status            |
| --------------- | ----------------- |
| Rojo loader / RBXM Module      | 🟢 Available      |
| Argon build     | 🟡 Working onto it |

## Contributing

Found a bug or have an improvement?

* Open an issue on the repository.
* For urgent questions, email **[thebunkerproject@waifu.club](mailto:thebunkerproject@waifu.club)**.

## License

PNGService is free and open-source software licensed under the **GNU General Public License v3.0 (GPL-3.0)**.
You are free to use, modify, and redistribute the software under the terms of the license.

See the [LICENSE](LICENSE) file for the full license text.
