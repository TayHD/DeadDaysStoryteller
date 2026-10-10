-- Hides Project A-Life's Creator and admin spawn menus (sandbox option
-- "Lock the A-Life Creator", on by default). The story system does all
-- creation and spawning. Nothing of A-Life's is copied or modified on disk;
-- we only remove its menu entries at runtime and refuse to open the Creator.

require "DeadDaysStory/DDS_Core"

local function locked()
    local sv = SandboxVars and SandboxVars.DeadDaysStory
    return sv == nil or sv.LockALifeCreator ~= false
end

local function isALifeOption(name)
    name = string.lower(tostring(name or ""))
    return string.find(name, "a-life", 1, true) ~= nil or string.find(name, "alife", 1, true) ~= nil
end

Events.OnFillWorldObjectContextMenu.Add(function(playerNum, context, worldobjects, test)
    if test or not locked() or context == nil or context.options == nil then return end
    local doomed = {}
    for _, option in ipairs(context.options) do
        if option and isALifeOption(option.name) then doomed[#doomed + 1] = option.name end
    end
    for _, name in ipairs(doomed) do
        pcall(function() context:removeOptionByName(name) end)
    end
end)

local function patch()
    if not locked() or type(ProjectALife) ~= "table" then return end
    if ProjectALife.MenuRules then
        ProjectALife.MenuRules.creatorAllowed = function() return false end
    end
    local creator = ProjectALife.CreatorScreen or ProjectALife.Creator
    if type(creator) == "table" then
        creator.adminAllowed = function() return false end
        creator.open = function() return false end
    end
end

Events.OnGameStart.Add(patch)
Events.OnCreatePlayer.Add(patch)
