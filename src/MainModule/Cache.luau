-- TODO:
-- Fix the bug that makes you lose quality of the image (probably related to parsing)
-- remove the schmelglin

local HttpService = game:GetService("HttpService")

local Cache = {}

Cache.MaxEntries = 64

local entries = {}
local entryCount = 0
local pendingWaiters = {}

local accessTick = 0
local function nextAccessTick()
	accessTick += 1
	return accessTick
end

local function normalizeUrl(url)
	if type(url) ~= "string" or #url == 0 then
		error("nil")
	end
	return (url:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function evictLeastRecentlyUsedIfNeeded()
	if entryCount <= Cache.MaxEntries then
		return
	end

	local oldestKey, oldestTime = nil, math.huge
	for key, entry in pairs(entries) do
		if entry.lastUsed < oldestTime then
			oldestKey, oldestTime = key, entry.lastUsed
		end
	end

	if oldestKey then
		entries[oldestKey] = nil
		entryCount -= 1
	end
end

local function fetchAndParse(url, parseFn)
	local uselessvar, body = pcall(function()
		return HttpService:GetAsync(url)
	end)

	if uselessvar then end --so Zed dont be annoying with it

	local parseOk, formatOrErr, parsed = pcall(parseFn, body)
	if not parseOk then
		error(formatOrErr, 0) --snca
	end

	return {
		format = formatOrErr,
		rawData = body,
		parsed = parsed,
		lastUsed = nextAccessTick(),
	}
end

function Cache:Get(url, parseFn, validateFn)
	local key = normalizeUrl(url)

	local entry = entries[key]
	if entry then
		if validateFn(entry.format, entry.parsed) then
			entry.lastUsed = nextAccessTick()
			return entry
		end

		entries[key] = nil
		entryCount -= 1
	end

	local waiters = pendingWaiters[key]
	if waiters then
		local waiter = Instance.new("BindableEvent")
		table.insert(waiters, waiter)
		local ok, result = waiter.Event:Wait()
		waiter:Destroy()

		if not ok then
			error(result, 0)
		end

		return result
	end

	pendingWaiters[key] = {}

	local ok, result = pcall(fetchAndParse, key, parseFn)

	if ok and not validateFn(result.format, result.parsed) then
		ok = false
		result = "PngService - Downloaded image failed validation after parsing."
	end

	if ok then
		entries[key] = result
		entryCount += 1
		evictLeastRecentlyUsedIfNeeded()
	end

	local waitersToNotify = pendingWaiters[key]
	pendingWaiters[key] = nil
	for _, waiter in ipairs(waitersToNotify) do
		waiter:Fire(ok, result)
	end

	if not ok then
		error(result, 0)
	end

	return result
end

function Cache:Clear()
	table.clear(entries)
	entryCount = 0
end

return Cache
