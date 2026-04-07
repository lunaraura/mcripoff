local FloraSystem = {}
FloraSystem.__index = FloraSystem
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BiomeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("BiomeConfig"))

local floraFolder = workspace:FindFirstChild("Flora") or Instance.new("Folder")
floraFolder.Name = "Flora"
floraFolder.Parent = workspace

local instancesByChunk = {}

local BIOME_TREES = {
	plains = { base = 8, styles = { "oak", "birch" } },
	forest = { base = 10, styles = { "oak", "birch" } },
	ocean = { base = 5, styles = { "palm" } },
	desert = { base = 3, styles = { "palm" } },
	stormfield = { base = 6, styles = { "pine", "spruce" } },
	volcanic = { base = 4, styles = { "cypress" } },
	tundra = { base = 7, styles = { "pine", "fir" } },
	polar = { base = 5, styles = { "pine", "fir" } },
}

local BERRY_COLORS = {
	berry_red = Color3.fromRGB(200, 40, 40),
	berry_yellow = Color3.fromRGB(240, 200, 60),
	berry_blue = Color3.fromRGB(60, 140, 230),
	revive_berry = Color3.fromRGB(123, 62, 29),
	replenish_berry = Color3.fromRGB(70, 190, 235),
}

local BERRY_NODE_TO_ITEM = {
	berry_bush_red = "berry_red",
	berry_bush_yellow = "berry_yellow",
	berry_bush_blue = "berry_blue",
	revive_berry_bush = "revive_berry",
	replenish_berry_bush = "replenish_berry",
}

local function addRef(chunkKey, inst)
	if not inst then return end
	instancesByChunk[chunkKey] = instancesByChunk[chunkKey] or {}
	table.insert(instancesByChunk[chunkKey], inst)
end

local function mkTrunk(x, y, z, h, rad, color)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide = true, true
	p.Material = Enum.Material.Wood
	p.Color = color
	p.Size = Vector3.new(rad * 2, h, rad * 2)
	p.CFrame = CFrame.new(x, y + h * 0.5, z)
	p.Parent = floraFolder
	return p
end

local function mkBall(x, y, z, r, color, mat)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored, p.CanCollide = true, true
	p.Material = mat or Enum.Material.Grass
	p.Color = color
	p.Size = Vector3.new(r * 2, r * 2, r * 2)
	p.CFrame = CFrame.new(x, y + r, z)
	p.Parent = floraFolder
	return p
end

local function mkBerryBush(x, yTop, z, itemKey)
	local bush = Instance.new("Part")
	bush.Name = "BerryBush_" .. tostring(itemKey)
	bush.Shape = Enum.PartType.Ball
	bush.Anchored, bush.CanCollide = true, false
	bush.Material = Enum.Material.Grass
	bush.Color = BERRY_COLORS[itemKey] or Color3.fromRGB(180, 80, 80)
	bush.Size = Vector3.new(5, 5, 5)
	bush.CFrame = CFrame.new(x, yTop + 2.5, z)
	bush.Parent = floraFolder
	bush:SetAttribute("BerryKind", itemKey)
	bush:SetAttribute("Uses", 3)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick Berry"
	prompt.ObjectText = "Berry Bush"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = bush
	CollectionService:AddTag(bush, "BerryBush")
	return bush
end

local function build_pine(x, yTop, z, r)
	local h = r:NextNumber(14, 22)
	local tr = r:NextNumber(0.6, 1.0)
	return { mkTrunk(x, yTop, z, h, tr, Color3.fromRGB(90, 70, 50)), mkBall(x, yTop + h * 0.8, z, r:NextNumber(3.5, 4.8), Color3.fromRGB(40, 100, 60)) }
end

local function build_oak(x, yTop, z, r)
	local h = r:NextNumber(10, 16)
	local tr = r:NextNumber(0.9, 1.4)
	return { mkTrunk(x, yTop, z, h, tr, Color3.fromRGB(110, 85, 60)), mkBall(x, yTop + h, z, r:NextNumber(4.8, 6.2), Color3.fromRGB(70, 120, 60)) }
end

local function build_birch(x, yTop, z, r)
	local h = r:NextNumber(10, 14)
	local trunk = mkTrunk(x, yTop, z, h, 0.8, Color3.fromRGB(235, 235, 235))
	trunk.Material = Enum.Material.Sand
	return { trunk, mkBall(x, yTop + h, z, r:NextNumber(4.2, 5.4), Color3.fromRGB(90, 160, 90)) }
end

local function build_palm(x, yTop, z, r)
	local h = r:NextNumber(9, 13)
	return { mkTrunk(x, yTop, z, h, 0.7, Color3.fromRGB(140, 110, 80)), mkBall(x, yTop + h, z, r:NextNumber(3.8, 5.0), Color3.fromRGB(60, 110, 80)) }
end

local function build_cypress(x, yTop, z, r)
	local h = r:NextNumber(12, 18)
	return { mkTrunk(x, yTop, z, h, 0.8, Color3.fromRGB(70, 60, 50)), mkBall(x, yTop + h * 0.9, z, r:NextNumber(3.8, 4.8), Color3.fromRGB(50, 90, 60)) }
end

local BUILDERS = {
	pine = build_pine,
	fir = build_pine,
	spruce = build_pine,
	oak = build_oak,
	birch = build_birch,
	palm = build_palm,
	cypress = build_cypress,
	mangrove = build_cypress,
	willow = build_oak,
}

function FloraSystem.scatterChunk(chunk)
	if not chunk or not chunk.cells or #chunk.cells == 0 then return end
	local seed = (chunk.cx * 92821) + (chunk.cz * 52361) + 1335
	local r = Random.new(seed)
	local dominant = chunk.cells[1].dominantBiome or "plains"
	local spec = BIOME_TREES[dominant] or BIOME_TREES.plains
	local trees = spec.base
	local shrubs = math.floor(spec.base * 1.2)
	local bushes = math.max(1, math.floor(spec.base * 0.35))
	local placed = {}
	local function farEnough(x, z, min2)
		for _, p in ipairs(placed) do
			local dx, dz = x - p.x, z - p.z
			if dx * dx + dz * dz < min2 then return false end
		end
		return true
	end
	for _ = 1, trees do
		local cell = chunk.cells[r:NextInteger(1, #chunk.cells)]
		if cell and (not cell.water) and (not cell.blocked) then
			local x = cell.x + r:NextNumber(-3, 3)
			local z = cell.z + r:NextNumber(-3, 3)
			if farEnough(x, z, 9 * 9) then
				local style = spec.styles[r:NextInteger(1, #spec.styles)]
				local builder = BUILDERS[style]
				if builder then
					for _, inst in ipairs(builder(x, cell.yG, z, r)) do
						addRef(chunk.key, inst)
					end
					table.insert(placed, { x = x, z = z })
				end
			end
		end
	end
	for _ = 1, shrubs do
		local cell = chunk.cells[r:NextInteger(1, #chunk.cells)]
		if cell and (not cell.water) and (not cell.blocked) then
			local x = cell.x + r:NextNumber(-3, 3)
			local z = cell.z + r:NextNumber(-3, 3)
			if farEnough(x, z, 5 * 5) then
				addRef(chunk.key, mkBall(x, cell.yG, z, r:NextNumber(0.8, 1.6), Color3.fromRGB(70, 140, 80)))
			end
		end
	end
	local berryNodePool = {}
	for _, cell in ipairs(chunk.cells) do
		local biomeDef = cell and cell.dominantBiome and BiomeConfig[cell.dominantBiome] or nil
		local nodeDefs = biomeDef and biomeDef.nodes or nil
		if nodeDefs then
			for _, n in ipairs(nodeDefs) do
				local itemKey = BERRY_NODE_TO_ITEM[n.key]
				if itemKey then
					for _ = 1, math.max(1, n.weight or 1) do
						table.insert(berryNodePool, itemKey)
					end
				end
			end
		end
	end
	if #berryNodePool <= 0 then
		berryNodePool = { "berry_red", "berry_yellow", "berry_blue" }
	end
	for _ = 1, bushes do
		local cell = chunk.cells[r:NextInteger(1, #chunk.cells)]
		if cell and (not cell.water) and (not cell.blocked) then
			local x = cell.x + r:NextNumber(-3, 3)
			local z = cell.z + r:NextNumber(-3, 3)
			if farEnough(x, z, 5 * 5) then
				local itemKey = berryNodePool[r:NextInteger(1, #berryNodePool)]
				addRef(chunk.key, mkBerryBush(x, cell.yG, z, itemKey))
			end
		end
	end
end

function FloraSystem.unloadChunk(chunkKey)
	local list = instancesByChunk[chunkKey]
	if not list then return end
	for _, inst in ipairs(list) do
		if inst and inst.Parent then
			inst:Destroy()
		end
	end
	instancesByChunk[chunkKey] = nil
end

return FloraSystem
