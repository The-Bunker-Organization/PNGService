local Composer = require(script.Composer)
local Decoder = require(script.Decoder)
local Player = require(script.Player)

local GIF = {}

GIF.new = Composer.new
GIF.Decode = Decoder.Decode --for debugging kek
GIF.Player = Player

return GIF
