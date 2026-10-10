-- Co-op through Project Zomboid's own player factions. A mission accepted by
-- a faction member belongs to the whole faction: everyone sees it, anyone can
-- advance it, everyone shares the reward and the standing.

require "DeadDaysStory/DDS_Core"

DDS.Party = DDS.Party or {}
local P = DDS.Party

local function factionOf(player)
    if player == nil or Faction == nil then return nil end
    local f
    pcall(function() f = Faction.getPlayerFaction(player) end)
    if f == nil and type(player) ~= "string" then
        local name = DDS.username(player)
        pcall(function() f = Faction.getPlayerFaction(name) end)
    end
    return f
end

-- Faction name for a player object or username, or nil.
function P.of(playerOrName)
    if playerOrName == nil then return nil end
    local player = playerOrName
    if type(playerOrName) == "string" then player = DDS.playerByName(playerOrName) or playerOrName end
    local f = factionOf(player)
    if f == nil then return nil end
    local name
    pcall(function() name = f:getName() end)
    return name
end

-- Every member's username (owner included), online or not.
function P.members(partyName)
    local list = {}
    if partyName == nil or Faction == nil then return list end
    pcall(function()
        local all = Faction.getFactions()
        for i = 0, all:size() - 1 do
            local f = all:get(i)
            if f and f:getName() == partyName then
                local owner = f:getOwner()
                if owner then list[#list + 1] = tostring(owner) end
                local players = f:getPlayers()
                for j = 0, players:size() - 1 do
                    local name = tostring(players:get(j))
                    if name ~= tostring(owner) then list[#list + 1] = name end
                end
            end
        end
    end)
    return list
end

-- Online members (player objects).
function P.online(partyName)
    local list = {}
    if partyName == nil then return list end
    for _, p in ipairs(DDS.onlinePlayers()) do
        if P.of(p) == partyName then list[#list + 1] = p end
    end
    return list
end

-- Same faction?
function P.same(a, b)
    local pa = P.of(a)
    return pa ~= nil and pa == P.of(b)
end

return P
