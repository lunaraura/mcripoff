local PlacementPreviewHelper = {}
PlacementPreviewHelper.__index = PlacementPreviewHelper

function PlacementPreviewHelper.new()
	return setmetatable({ part = nil }, PlacementPreviewHelper)
end

function PlacementPreviewHelper:getShape(def)
	local placement = def and def.placement or {}
	local previewSize = placement.previewSize or { x = 4, y = 4, z = 4 }
	local previewShape = placement.previewShape or "block"
	if previewShape == "wedge" then
		return {
			className = "WedgePart",
			size = Vector3.new(previewSize.x or 8, previewSize.y or 5, previewSize.z or 8),
			baseColor = Color3.fromRGB(156, 126, 98),
		}
	end
	return {
		className = "Part",
		size = Vector3.new(previewSize.x or 4, previewSize.y or 4, previewSize.z or 4),
		baseColor = Color3.fromRGB(120, 95, 72),
	}
end

function PlacementPreviewHelper:ensure(def)
	local shape = self:getShape(def)
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

function PlacementPreviewHelper:update(def, cframe, isValid)
	local part, shape = self:ensure(def)
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
