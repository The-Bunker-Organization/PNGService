local Composer = require(script.Composer)
local Decoder = require(script.Decoder)
local Player = require(script.Player)

local GIF = {}

GIF.new = Composer.new
GIF.Decode = Decoder.Decode -- raw parse for debbuging kek
GIF.Player = Player

return GIF
