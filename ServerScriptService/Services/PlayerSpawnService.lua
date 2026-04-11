--!strict
local Players = game:GetService("Players")

export type WorldService = {
	-- Optional: generate chunks around a world position.
	ensureChunksAroundPosition: ((self: any, x: number, z: number, radiusChunks: number) -> ())?,
	generateChunksAroundPosition: ((self: any, x: number, z: number, radiusChunks: number) -> ())?,
	ensureSpawnAreaReady: ((self: any, x: number, z: number, radiusChunks: number) -> ())?,

	-- Required in some form: resolve ground height at x/z.
	resolveCreatureGroundY: ((self: any, x: number, z: number, fallbackY: number) -> number)?,
	resolveGroundY: ((self: any, x: number, z: number, fallbackY: number) -> number)?,
}

type Config = {
	spawnX: number?,
	spawnZ: number?,
	fallbackY: number?,
	spawnHeightOffset: number?,
	chunkRadius: number?,
	maxGroundRetries: number?,
	groundRetryDelay: number?,
	anchorDuringPlacement: boolean?,
}

local PlayerSpawnService = {}
PlayerSpawnService.__index = PlayerSpawnService

function PlayerSpawnService.new(worldService: WorldService, config: Config?)
	config = config or {}

	local self = setmetatable({}, PlayerSpawnService)
	self.worldService = worldService

	self.spawnX = config.spawnX or 0
	self.spawnZ = config.spawnZ or 0
	self.fallbackY = config.fallbackY or 128
	self.spawnHeightOffset = config.spawnHeightOffset or 6
	self.chunkRadius = config.chunkRadius or 2
	self.maxGroundRetries = config.maxGroundRetries or 20
	self.groundRetryDelay = config.groundRetryDelay or 0.1
	self.anchorDuringPlacement = if config.anchorDuringPlacement == nil then true else config.anchorDuringPlacement

	return self
end

function PlayerSpawnService:init()
	Players.CharacterAutoLoads = false

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			self:spawnPlayer(player)
		end)
	end)

	-- Covers Studio test edge cases where players may already exist.
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:spawnPlayer(player)
		end)
	end
end

function PlayerSpawnService:getSpawnXZ(_player: Player): (number, number)
	-- Replace this later if you want per-player spawn logic.
	return self.spawnX, self.spawnZ
end

function PlayerSpawnService:ensureSpawnAreaReady(x: number, z: number)
	local ws = self.worldService

	if ws.ensureSpawnAreaReady then
		ws:ensureSpawnAreaReady(x, z, self.chunkRadius)
		return
	end

	if ws.ensureChunksAroundPosition then
		ws:ensureChunksAroundPosition(x, z, self.chunkRadius)
		return
	end

	if ws.generateChunksAroundPosition then
		ws:generateChunksAroundPosition(x, z, self.chunkRadius)
		return
	end
end

function PlayerSpawnService:resolveGroundY(x: number, z: number): number?
	local ws = self.worldService

	if ws.resolveCreatureGroundY then
		return ws:resolveCreatureGroundY(x, z, self.fallbackY)
	end

	if ws.resolveGroundY then
		return ws:resolveGroundY(x, z, self.fallbackY)
	end

	return nil
end

function PlayerSpawnService:waitForGroundY(x: number, z: number): number
	for _ = 1, self.maxGroundRetries do
		local y = self:resolveGroundY(x, z)
		if typeof(y) == "number" then
			return y
		end
		task.wait(self.groundRetryDelay)
	end

	-- Fail safe: use fallback if terrain service never returned a valid number.
	return self.fallbackY
end

function PlayerSpawnService:placeCharacterOnGround(character: Model, x: number, z: number, groundY: number)
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not humanoidRootPart or not humanoid then
		warn("[PlayerSpawnService] Missing HumanoidRootPart or Humanoid during spawn placement.")
		return
	end

	local targetPosition = Vector3.new(x, groundY + self.spawnHeightOffset, z)

	if self.anchorDuringPlacement then
		humanoidRootPart.Anchored = true
	end

	-- Face forward along Z by default.
	humanoidRootPart.CFrame = CFrame.new(targetPosition)

	-- Small settle delay helps avoid immediate physics weirdness.
	task.wait()

	if self.anchorDuringPlacement then
		humanoidRootPart.Anchored = false
	end
end

function PlayerSpawnService:spawnPlayer(player: Player)
	local spawnX, spawnZ = self:getSpawnXZ(player)

	self:ensureSpawnAreaReady(spawnX, spawnZ)
	local groundY = self:waitForGroundY(spawnX, spawnZ)

	player:LoadCharacter()

	local character = player.Character or player.CharacterAdded:Wait()
	self:placeCharacterOnGround(character, spawnX, spawnZ, groundY)
end

function PlayerSpawnService:respawnPlayer(player: Player)
	task.spawn(function()
		self:spawnPlayer(player)
	end)
end

return PlayerSpawnService
