local Composer = require(script.Composer)
local Decoder = require(script.Decoder)

local GIF = {}

GIF.new = Composer.new
GIF.fromRaw = Composer.fromRaw -- build a Composer from an already-decoded raw structure (see Cache.luau)
GIF.Decode = Decoder.Decode --for debugging kek

return GIF
