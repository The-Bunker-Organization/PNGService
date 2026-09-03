# RBXMXService

> [!IMPORTANT]
> **RBXMXService is currently in Beta!**
> Please report bugs or issues on our [Discord Server](https://canary.discord.com/invite/MvVBbftUYm).
>
> For urgent questions, contact us at **[thebunkerproject@waifu.club](mailto:thebunkerproject@waifu.club)**.

## About

**RBXMXService** is a runtime **RBXMX loader** that allows you to load `.rbxmx` files directly inside a Roblox environment.

It is designed to work with a `loadstring`/compiler environment,allowing RBXMX content to be loaded without manually converting the file beforehand.

### Features

* Runtime image loading without publishing
* Works through a Roblox env by default
* Parse any PNG type file
* Currently in **Beta**

## Building

The project uses a `Rojo` format that can be built as a RBXM or RBXMX,Check [Releases](https://github.com/The-Bunker-Organization/RBXMXService/releases) for the RBXM without building yourself.

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

RBXMXService is free and open-source software licensed under the **GNU General Public License v3.0 (GPL-3.0)**.
You are free to use, modify, and redistribute the software under the terms of the license.

See the [LICENSE](LICENSE) file for the full license text.
