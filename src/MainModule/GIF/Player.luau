local RunService = game:GetService("RunService")

local Composer = require(script.Parent.Composer)
local Signal = require(script.Parent.Signal)

local GIFPlayer = {}
GIFPlayer.__index = GIFPlayer

local wawa = 1 / 60

function GIFPlayer.new(gifData)
	local self = setmetatable({}, GIFPlayer)

	self._gif = Composer.new(gifData)

	self._speed = 1

	self._looping = self._gif.LoopCount ~= nil

	self._absoluteFrame = 1
	self._frameIndex = 1
	self._accumulated = 0
	self._playing = false
	self._destroyed = false
	self._connection = nil

	self.FrameChanged = Signal.new()
	self.Completed = Signal.new()
	self.PlayingChanged = Signal.new()

	return self
end

function GIFPlayer:GetFrameCount()
	return self._gif:GetFrameCount()
end

function GIFPlayer:GetFPS()
	return self._gif:GetFPS()
end

function GIFPlayer:GetDuration()
	return self._gif:GetDuration()
end

function GIFPlayer:GetDimensions()
	return self._gif.Width, self._gif.Height
end

function GIFPlayer:GetCurrentFrameIndex()
	return self._frameIndex
end

function GIFPlayer:IsPlaying()
	return self._playing
end

function GIFPlayer:SetSpeed(speed)
	assert(type(speed) == "number" and speed > 0, "GIFPlayer:SetSpeed expects a positive number")
	self._speed = speed
end

function GIFPlayer:SetLooping(looping)
	self._looping = looping and true or false
end

function GIFPlayer:_setPlaying(playing)
	if self._playing ~= playing then
		self._playing = playing
		self.PlayingChanged:Fire(playing)
	end
end

function GIFPlayer:_showFrame(absoluteIndex)
	local frame = self._gif:GetFrame(absoluteIndex)
	self._absoluteFrame = absoluteIndex
	self._frameIndex = frame.Index
	self.FrameChanged:Fire(frame.Index, frame)
	return frame
end

function GIFPlayer:_step(dt)
	if self._destroyed or not self._playing then
		return
	end

	local count = self._gif:GetFrameCount()
	self._accumulated += dt * self._speed

	local delay = math.max(self._gif:GetFrameDelay(self._frameIndex), wawa)

	while self._accumulated >= delay do
		self._accumulated -= delay

		if self._frameIndex >= count and not self._looping then
			self:_setPlaying(false)
			self.Completed:Fire()
			return
		end

		self:_showFrame(self._absoluteFrame + 1)
		delay = math.max(self._gif:GetFrameDelay(self._frameIndex), wawa)
	end
end

function GIFPlayer:Play()
	if self._destroyed or self._playing then
		return
	end

	self._accumulated = 0

	if not self._connection then
		self._connection = RunService.Heartbeat:Connect(function(dt)
			self:_step(dt)
		end)
	end

	self:_setPlaying(true)
	self:_showFrame(self._absoluteFrame)
end

function GIFPlayer:Pause()
	self:_setPlaying(false)
end

function GIFPlayer:Resume()
	if self._destroyed then
		return
	end
	self:_setPlaying(true)
end

function GIFPlayer:Stop()
	self:_setPlaying(false)
	self._absoluteFrame = 1
	self._frameIndex = 1
	self._accumulated = 0
end

function GIFPlayer:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self:_setPlaying(false)

	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end

	self.FrameChanged:DisconnectAll()
	self.Completed:DisconnectAll()
	self.PlayingChanged:DisconnectAll()
end

return GIFPlayer
