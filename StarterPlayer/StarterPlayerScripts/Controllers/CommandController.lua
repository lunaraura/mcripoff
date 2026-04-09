local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local CommandController = {}
CommandController.__index = CommandController

function CommandController.new(partyController)
	return setmetatable({
		partyController = partyController,
		requestPetCommand = remotes:WaitForChild("RequestPetCommand"),
		requestManualCast = remotes:WaitForChild("RequestManualCast"),
		mouse = nil,
	}, CommandController)
end

function CommandController:bind(mouse)
	self.mouse = mouse
end

function CommandController:sendCommand(command)
	self.requestPetCommand:FireServer({
		slot = self.partyController.selectedSlot,
		command = command,
	})
end

function CommandController:setActiveSlot(slot)
	self.requestPetCommand:FireServer({
		slot = slot,
		command = { type = "setActive" },
	})
end

function CommandController:setControlMode(mode)
	self.requestPetCommand:FireServer({
		slot = self.partyController.selectedSlot,
		command = { type = "setControlMode", mode = mode },
	})
end

function CommandController:cast(abilityKey, targetId)
	self.requestManualCast:FireServer({
		slot = self.partyController.selectedSlot,
		abilityKey = abilityKey,
		targetId = targetId,
	})
end

function CommandController:getTargetIdUnderMouse()
	local function getIdFromInstance(inst)
		if not inst then return nil end
		local attrId = tonumber(inst:GetAttribute("CreatureId"))
		if attrId then return attrId end
		local id = string.match(inst.Name or "", "^C_(%d+)_")
		if id then return tonumber(id) end
		return nil
	end

	local function climbForId(inst)
		local cur = inst
		for _ = 1, 10 do
			if not cur then return nil end
			local id = getIdFromInstance(cur)
			if id then return id end
			local asModel = cur:IsA("Model") and cur or cur:FindFirstAncestorOfClass("Model")
			if asModel then
				local modelId = getIdFromInstance(asModel)
				if modelId then return modelId end
				local modelParent = asModel.Parent
				if modelParent and modelParent:IsA("Model") then
					local parentId = getIdFromInstance(modelParent)
					if parentId then return parentId end
				end
			end
			cur = cur.Parent
		end
		return nil
	end

	local target = self.mouse and self.mouse.Target
	local idFromTarget = climbForId(target)
	if idFromTarget then return idFromTarget end

	local hit = self.mouse and self.mouse.Hit
	if not hit then return nil end
	local modelsFolder = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("CreatureModels")
	if not modelsFolder then return nil end
	local bestId, bestDist = nil, 7.5
	for _, model in ipairs(modelsFolder:GetChildren()) do
		if model:IsA("Model") and model.PrimaryPart then
			local cid = getIdFromInstance(model)
			if cid then
				local d = (model.PrimaryPart.Position - hit.Position).Magnitude
				if d <= bestDist then
					bestDist = d
					bestId = cid
				end
			end
		end
	end
	return bestId
end

return CommandController
