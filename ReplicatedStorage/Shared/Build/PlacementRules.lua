local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local BuildableConfig = require(Config:WaitForChild("BuildableConfig"))

local PlacementRules = {}

PlacementRules.Reason = {
	OK = "BUILD_OK",
	UNKNOWN_BUILD_KEY = "BUILD_UNKNOWN_KEY",
	NO_CHARACTER = "BUILD_NO_CHARACTER",
	TOO_FAR = "BUILD_TOO_FAR",
	MISSING_CELL = "BUILD_MISSING_CELL",
	BLOCKED_TERRAIN = "BUILD_BLOCKED_TERRAIN",
	INVALID_TERRAIN = "BUILD_INVALID_TERRAIN",
	OVERLAP_BUILD = "BUILD_OVERLAP_BUILD",
	OVERLAP_OBSTACLE = "BUILD_OVERLAP_OBSTACLE",
	OVERLAP_CREATURE = "BUILD_OVERLAP_CREATURE",
	MISSING_MATERIALS = "BUILD_MISSING_MATERIALS",
	NOT_READY = "BUILD_NOT_READY",
	NOT_FOUND = "BUILD_NOT_FOUND",
	INVALID_ACTION = "BUILD_INVALID_ACTION",
}

function PlacementRules.getBuildDef(buildKey)
	return BuildableConfig[buildKey]
end

function PlacementRules.getPlacement(buildKey)
	local def = PlacementRules.getBuildDef(buildKey)
	if not def then return nil end
	local p = def.placement or {}
	local footprint = p.footprintSize or p.previewSize or { x = 4, y = 4, z = 4 }
	return {
		previewShape = p.previewShape or "block",
		previewSize = p.previewSize or footprint,
		footprintSize = footprint,
		collisionRadius = p.collisionRadius or math.max(footprint.x or 4, footprint.z or 4) * 0.5,
		placementRange = p.placementRange or 18,
		allowedTerrain = p.allowedTerrain or { "ground" },
		allowRotation = p.allowRotation ~= false,
		grid = p.grid or 4,
	}
end

function PlacementRules.getHarvest(def)
	local harvest = def.harvesting or {}
	return {
		interval = harvest.interval or def.harvestTime or 1,
		provides = harvest.provides or def.provides or {},
	}
end

function PlacementRules.classifyTerrain(material)
	if material == Enum.Material.Water then return "water" end
	if material == Enum.Material.Rock or material == Enum.Material.Slate then return "rock" end
	return "ground"
end

function PlacementRules.isTerrainAllowed(terrainClass, placement)
	for _, allowed in ipairs(placement.allowedTerrain or {}) do
		if allowed == terrainClass then return true end
	end
	return false
end

function PlacementRules.snapPosition(point, grid, y)
	local g = grid or 4
	return Vector3.new(
		math.floor(point.X / g + 0.5) * g,
		y or point.Y,
		math.floor(point.Z / g + 0.5) * g
	)
end

return PlacementRules
