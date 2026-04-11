-- Assuming this is Lua code for the UIController.lua file

-- Function to reposition UI panels
function repositionUIPanels()
    ActivePetHud.position = {x = 0, y = screenHeight - ActivePetHud.height} -- Bottom-left
    OptionsPanel.position = {x = screenWidth - OptionsPanel.width, y = 0} -- Top-right
    BuildToolPanel.position = {x = screenWidth - BuildToolPanel.width, y = OptionsPanel.position.y + OptionsPanel.height} -- Below Options
    ItemBar.position = {x = (screenWidth - ItemBar.width) / 2, y = screenHeight - ItemBar.height} -- Bottom-center
end

-- Update setUiHidden to hide all panels
function setUiHidden(isHidden)
    for _, panel in ipairs(mainHudFrames) do
        panel.isVisible = not isHidden
    end
    -- Also hide the additional panels
    optionsPanel.isVisible = not isHidden
    managementPanel.isVisible = not isHidden
    commandModeLabel.isVisible = not isHidden
end

-- Register optionsPanel and managementPanel in mainHudFrames
function registerAdditionalPanels()
    table.insert(mainHudFrames, optionsPanel)
    table.insert(mainHudFrames, managementPanel)
end

-- Call the reposition function to adjust the UI initially
repositionUIPanels()
registerAdditionalPanels()