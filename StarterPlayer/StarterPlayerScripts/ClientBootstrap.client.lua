local Players = game:GetService("Players")

local PartyController = require(script.Controllers.PartyController)
local CommandController = require(script.Controllers.CommandController)
local BuildController = require(script.Controllers.BuildController)
local UIController = require(script.Controllers.UIController)
local InputController = require(script.Controllers.InputController)

local localPlayer = Players.LocalPlayer
local party = PartyController.new()
local build = BuildController.new()
local command = CommandController.new(party)
local ui = UIController.new()
local input = InputController.new(party, command, build)

local mouse = localPlayer:GetMouse()
command:bind(mouse)
ui:bind()
input:bind()

print("[Pet4 Roblox Slice] Client bootstrapped")
