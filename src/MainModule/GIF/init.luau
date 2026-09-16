local Composer = require(script.Composer)
local Decoder = require(script.Decoder)

local GIF = {}

GIF.new = Composer.new
GIF.Decode = Decoder.Decode --for debugging kek

return GIF
