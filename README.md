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
* Render any frame of a GIF, and switch frames after the fact with `SetFrame()`
* Automatic image caching - the same URL is only downloaded and parsed once
* Automatic [`EditableImage`](#editableimage-rendering) rendering when your experience supports it, with a betiful fallback when it doesn't
* Currently in **Beta**

## Building

The project uses a `Rojo` format that can be built as a RBXM or RBXMX,Check [Releases](https://github.com/The-Bunker-Organization/PNGService/releases) for the RBXM without building yourself.

## Using RBXM
Just path it to your instance or GUI for using it,it will generate a GUI for it using the PNG binary parsed
```
local PngService = require(path.to.MainModule) --you can also upload it and use as a module id like require(6700000)

local renderer = PngService:Generate(
	"https://example.com/image.png",
	workspace.Part, --or any instance
	Enum.NormalId.Front --side you wanna
)
```

### Image caching

`Generate()` caches downloaded and parsed image data internally, keyed by URL. Calling `Generate()` again with the exact same URL - whether for the same renderer or a brand-new one. reuses that cached data instead of issuing another `HttpService:GetAsync()` request or re-parsing the binary image data:

```
local a = PngService:Generate("https://example.com/image.png", workspace.PartA, Enum.NormalId.Front)
local b = PngService:Generate("https://example.com/image.png", workspace.PartB, Enum.NormalId.Front)
-- Only one HTTP request was made for the two renderers above instead of wasting network onto the same image
```

A few details worth knowing:

* Both static PNGs and GIFs are cached. For GIFs, the expensive part (decoding every frame) is cached and shared, but every renderer still gets its own independent playback state, so `SetFrame()` on one renderer never affects another renderer showing the same cached GIF.
* URLs are matched after trimming surrounding whitespace; otherwise they're compared as-is.
* Cached data is validated before every use. If a cached entry ever turns out to be invalid or corrupted, it's discarded automatically, the image is downloaded and parsed again exactly once, and the cache entry is replaced. If that retry also fails, `Generate()` raises a clear error rather than silently reusing bad data.
* The cache keeps at most 64 distinct images by default, evicting the least-recently-used one once that limit is exceeded, so long-running experiences that load many different images don't grow the cache without bound. Adjust this with `PngService.SetMaxCachedImages(n)`.
* `PngService.ClearCache()` drops every cached image, forcing the next `Generate()` call for each URL to fetch fresh data. This is mostly useful for testing, or when you know a URL's contents changed.

### GIF support

`Generate()` accepts GIFs and renders a single frame at a time, starting from whichever frame you specify (or `1` by default):

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

#### Switching frames with `SetFrame()` and `GetFrames()`

The renderer returned by `Generate()` can change which GIF frame is displayed after the fact, without downloading or re-parsing the GIF:

```
local renderer = PngService:Generate(
	"https://example.com/image.gif",
	workspace.Part,
	Enum.NormalId.Front
)

print(renderer:GetFrames()) --> e.g. 24

renderer:SetFrame(2)
renderer:SetFrame(10)
```

* `renderer:GetFrames()` returns the GIF's total frame count. For a static PNG, it always returns `1`.
* `renderer:SetFrame(n)` switches to frame `n` (1-based), redrawing only the visible image - it never triggers another HTTP request and never re-decodes the GIF.
* Calling `SetFrame()` with an invalid frame number (out of range, `0`, negative, or non-integer) raises a clear error and leaves the renderer showing whatever frame it was already on.
* Calling `SetFrame(1)` on a static PNG renderer is a harmless no-op. Calling it with anything other than `1` raises a clear error, since a PNG only has one frame.

### EditableImage rendering

When the current Roblox environment supports it, PNGService automatically renders through a Roblox [`EditableImage`](https://create.roblox.com/docs/reference/engine/classes/EditableImage) instead of its original per-pixel `Frame`/`UIGradient` approximation. This is a strict quality upgrade: every pixel is drawn at full precision (no color quantization) with real per-pixel transparency, using a single `Instance` instead of potentially hundreds of them.

**You don't need to do anything to benefit from this.** PNGService detects support automatically the first time it's needed, caches that result, and:

* Uses `EditableImage` immediately if the environment supports it.
* Falls back to the original renderer automatically if it doesn't,for example, because `EditableImage`/`EditableMesh` APIs are disabled for a published experience, which [Roblox allows creators to configure](https://create.roblox.com/docs/reference/engine/classes/AssetService#CreateEditableImage). PNGService never fails outright just because `EditableImage` is unavailable.
* Only runs the (cheap, but non-zero) capability check once per session,never once per image.

For GIFs, `SetFrame()` updates the same `EditableImage` in place; it never creates a new one or re-downloads/re-decodes anything.

#### Configuring and inspecting EditableImage behavior

```
local PngService = require(path.to.MainModule)

-- Check whether EditableImage will actually be used, without generating anything:
print(PngService.IsEditableImageSupported()) --> true or false

-- Force EditableImage off globally (always use the legacy renderer):
PngService.Config.UseEditableImage = false

-- Back to automatic (the default):
PngService.Config.UseEditableImage = "Auto"

local renderer = PngService:Generate(
	"https://example.com/image.png",
	workspace.Part,
	Enum.NormalId.Front,
	{
		UseEditableImage = false -- per-call override; takes priority over PngService.Config for this renderer only
	}
)

print(renderer:IsUsingEditableImage()) --> false, because of the override above
```

* `PngService.Config.UseEditableImage` (default `"Auto"`) is a module-wide switch. `"Auto"` and `true` both mean "use `EditableImage` if this environment actually supports it"; `false` always forces the legacy renderer.
* `Generate(url, part, face, { UseEditableImage = ... })` lets you override that decision for a single renderer. Omit the key entirely to inherit `PngService.Config.UseEditableImage`.
* `renderer:IsUsingEditableImage()` tells you which renderer a specific instance ended up using.
* `EditableImage`'s pixel-buffer operations are only reliable up to 1024x1024, so PNGService clamps to that regardless of `MaxScale` - an extremely large `MaxScale` will render at a lower resolution under `EditableImage` than it would request under the legacy renderer, scaled up to fit.

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
