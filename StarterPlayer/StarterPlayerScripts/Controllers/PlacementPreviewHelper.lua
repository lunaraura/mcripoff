local PlacementPreviewHelper = {}
PlacementPreviewHelper.__index = PlacementPreviewHelper

function PlacementPreviewHelper.new()
	return setmetatable({ part = nil }, PlacementPreviewHelper)
end

function PlacementPreviewHelper:getShape(buildKey)
	if buildKey == "tent" then
		return {
			className = "WedgePart",
			size = Vector3.new(8, 5, 8),
			baseColor = Color3.fromRGB(156, 126, 98),
		}
	end
	return {
		className = "Part",
		size = Vector3.new(4, 4, 4),
		baseColor = Color3.fromRGB(120, 95, 72),
	}
end

function PlacementPreviewHelper:ensure(buildKey)
	local shape = self:getShape(buildKey)
	if self.part and self.part.Parent and self.part.ClassName == shape.className then
		return self.part, shape
	end
	self:destroy()
	local part = Instance.new(shape.className)
	part.Name = "BuildPreviewGhost"
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.ForceField
	part.Transparency = 0.45
	part.Size = shape.size
	part.Parent = workspace
	self.part = part
	return part, shape
end

function PlacementPreviewHelper:update(buildKey, cframe, isValid)
	local part, shape = self:ensure(buildKey)
	part.Size = shape.size
	part.CFrame = cframe
	part.Color = isValid and Color3.fromRGB(95, 230, 120) or Color3.fromRGB(230, 90, 90)
end

function PlacementPreviewHelper:destroy()
	if self.part then
		self.part:Destroy()
		self.part = nil
	end
end

return PlacementPreviewHelper
