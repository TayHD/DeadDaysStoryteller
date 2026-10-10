-- Inventory helpers and rewards. All item changes happen on the server and
-- are announced with sendAddItemToContainer / sendRemoveItemFromContainer so
-- they are real for everyone (Build 42 inventories are server-owned).

require "DeadDaysStory/DDS_Core"

DDS.Items = DDS.Items or {}
local Items = DDS.Items

local function eachItem(container, visit, depth)
    if container == nil or (depth or 0) > 3 then return end
    local list = container:getItems()
    for i = list:size() - 1, 0, -1 do
        local item = list:get(i)
        if item ~= nil then
            visit(item, container)
            if instanceof(item, "InventoryContainer") then
                eachItem(item:getInventory(), visit, (depth or 0) + 1)
            end
        end
    end
end

function Items.each(player, visit)
    pcall(function() eachItem(player:getInventory(), visit, 0) end)
end

local function matches(item, want)
    if type(want) == "function" then return want(item) end
    local full = item:getFullType()
    if full == want then return true end
    return item:getType() == want
end

function Items.count(player, want)
    local n = 0
    Items.each(player, function(item)
        local ok, yes = pcall(matches, item, want)
        if ok and yes then n = n + 1 end
    end)
    return n
end

function Items.questItem(player, questId)
    local found
    Items.each(player, function(item)
        if found == nil then
            local data = item:getModData()
            if data and data.DDSQuest == questId then found = item end
        end
    end)
    return found
end

function Items.give(player, fullType, count, name, questId, tags)
    local made = 0
    local inventory = player:getInventory()
    for _ = 1, math.max(1, count or 1) do
        local ok, item = pcall(function() return inventory:AddItem(fullType) end)
        if ok and item then
            if name then pcall(function() item:setName(name); item:setCustomName(true) end) end
            if questId then pcall(function() item:getModData().DDSQuest = questId end) end
            if tags then pcall(function()
                local data = item:getModData()
                for k, v in pairs(tags) do data[k] = v end
            end) end
            if sendAddItemToContainer then pcall(function() sendAddItemToContainer(inventory, item) end) end
            made = made + 1
        end
    end
    return made
end

function Items.take(player, want, count)
    local taken = 0
    count = count or 1
    local victims = {}
    Items.each(player, function(item, container)
        if #victims < count then
            local ok, yes = pcall(matches, item, want)
            if ok and yes then victims[#victims + 1] = { item = item, container = container } end
        end
    end)
    for _, v in ipairs(victims) do
        local ok = pcall(function()
            v.container:DoRemoveItem(v.item)
            if sendRemoveItemFromContainer then sendRemoveItemFromContainer(v.container, v.item) end
        end)
        if ok then taken = taken + 1 end
    end
    return taken
end

function Items.takeQuestItem(player, questId)
    return Items.take(player, function(item)
        local data = item:getModData()
        return data and data.DDSQuest == questId
    end, 1)
end

-- Place an item in the world: in a container near (x,y,z) if one is loaded,
-- otherwise on the floor. Returns a description of where it went.
function Items.place(x, y, z, fullType, name, questId, radius)
    local placed, where
    pcall(function()
        local cell = getCell()
        radius = radius or 4
        local best
        for dx = -radius, radius do
            for dy = -radius, radius do
                local sq = cell:getGridSquare(math.floor(x) + dx, math.floor(y) + dy, math.floor(z or 0))
                if sq then
                    local objects = sq:getObjects()
                    for i = 0, objects:size() - 1 do
                        local obj = objects:get(i)
                        local container = obj and obj:getContainer() or nil
                        if container and best == nil then best = { container = container, obj = obj } end
                    end
                end
            end
        end
        if best then
            local item = best.container:AddItem(fullType)
            if item then
                if name then item:setName(name); item:setCustomName(true) end
                if questId then item:getModData().DDSQuest = questId end
                if sendAddItemToContainer then sendAddItemToContainer(best.container, item) end
                placed = item
                where = "container"
            end
        end
        if placed == nil then
            local sq = cell:getGridSquare(math.floor(x), math.floor(y), math.floor(z or 0))
            if sq then
                local item = instanceItem(fullType)
                if item then
                    if name then item:setName(name); item:setCustomName(true) end
                    if questId then item:getModData().DDSQuest = questId end
                    sq:AddWorldInventoryItem(item, 0.5, 0.5, 0)
                    placed = item
                    where = "floor"
                end
            end
        end
    end)
    return placed ~= nil, where
end

function Items.xp(player, perkName, amount)
    local ok = false
    pcall(function()
        local perk = Perks.FromString(perkName)
        if perk == nil then return end
        if addXpNoMultiplier then
            ok = pcall(function() addXpNoMultiplier(player, perk, amount) end)
        end
        if not ok and addXp then ok = pcall(function() addXp(player, perk, amount) end) end
        if not ok then ok = pcall(function() player:getXp():AddXP(perk, amount) end) end
        if SyncXp then pcall(function() SyncXp(player) end) end
    end)
    return ok
end

---------------------------------------------------------------------------
-- Reward tables
---------------------------------------------------------------------------

Items.pools = {
    food = { "Base.TinnedBeans", "Base.TinnedSoup", "Base.CannedChili", "Base.CannedCorn", "Base.CannedSardines",
        "Base.Chocolate", "Base.WaterBottle", "Base.Coffee2" },
    meds = { "Base.Bandage", "Base.Pills", "Base.Antibiotics", "Base.Disinfectant", "Base.SutureNeedle",
        "Base.AlcoholWipes", "Base.PillsBeta", "Base.Splint" },
    ammo = { "Base.Bullets9mmBox", "Base.ShotgunShellsBox", "Base.Bullets38Box", "Base.Bullets45Box", "Base.308Box",
        "Base.556Box", "Base.Bullets44Box" },
    tools = { "Base.Hammer", "Base.Screwdriver", "Base.Saw", "Base.DuctTape", "Base.NailsBox", "Base.Rope",
        "Base.Battery", "Base.HandTorch", "Base.Matches" },
    weapons = { "Base.Pistol", "Base.Revolver", "Base.Shotgun", "Base.HuntingRifle", "Base.VarmintRifle",
        "Base.Machete", "Base.HandAxe", "Base.Crowbar" },
    trade = { "Base.CigarettePack", "Base.Whiskey", "Base.Lighter", "Base.Battery", "Base.WalkieTalkie3" },
    bags = { "Base.Bag_ALICEpack", "Base.Bag_DuffelBag", "Base.Bag_BigHikingBag", "Base.Bag_Military" },
}

Items.blocPools = {
    military = { "ammo", "ammo", "meds", "food" }, elite = { "ammo", "weapons", "meds" },
    law = { "ammo", "meds", "food" }, family = { "food", "food", "tools", "meds" },
    civilian = { "food", "meds", "tools" }, rescue = { "meds", "meds", "food" }, worker = { "tools", "tools", "food" },
    raider = { "weapons", "ammo", "trade" }, gang = { "trade", "ammo", "weapons" }, club = { "trade", "weapons", "ammo" },
    crime = { "trade", "trade", "ammo" }, prison = { "trade", "tools" },
}

Items.tiers = {
    small = { rolls = 2, xp = 40 },
    medium = { rolls = 3, xp = 90, ammoBonus = 1 },
    large = { rolls = 4, xp = 160, ammoBonus = 1, special = 0.35 },
    spine = { rolls = 5, xp = 300, ammoBonus = 2, special = 1.0 },
}

-- Build a concrete reward list (stored on the quest so the journal can show it).
function Items.rollReward(rng, tier, bloc)
    local spec = Items.tiers[tier] or Items.tiers.small
    local pools = Items.blocPools[bloc or ""] or { "food", "meds", "ammo", "tools" }
    local list = {}
    for _ = 1, spec.rolls do
        local pool = Items.pools[rng:pick(pools)]
        list[#list + 1] = { type = rng:pick(pool), count = 1 }
    end
    for _ = 1, spec.ammoBonus or 0 do list[#list + 1] = { type = rng:pick(Items.pools.ammo), count = 1 } end
    if spec.special and rng:chance(spec.special) then
        local pool = rng:chance(0.5) and Items.pools.weapons or Items.pools.bags
        list[#list + 1] = { type = rng:pick(pool), count = 1 }
    end
    -- Merge duplicates.
    local merged, byType = {}, {}
    for _, r in ipairs(list) do
        if byType[r.type] then byType[r.type].count = byType[r.type].count + r.count
        else byType[r.type] = { type = r.type, count = r.count }; merged[#merged + 1] = byType[r.type] end
    end
    return { items = merged, xp = spec.xp, perk = rng:pick({ "Aiming", "Sneak", "Nimble", "Lightfoot", "Maintenance", "Doctor" }) }
end

function Items.grant(player, reward)
    if player == nil or type(reward) ~= "table" then return {} end
    local given = {}
    for _, r in ipairs(reward.items or {}) do
        local n = Items.give(player, r.type, r.count or 1, r.name)
        if n > 0 then given[#given + 1] = { type = r.type, count = n, name = r.name } end
    end
    if reward.xp and reward.xp > 0 and reward.perk then
        Items.xp(player, reward.perk, reward.xp)
    end
    return given
end

function Items.displayName(fullType)
    local name = fullType
    pcall(function()
        local script = getScriptManager():getItem(fullType)
        if script then name = script:getDisplayName() end
    end)
    return name
end

function Items.describe(reward)
    if type(reward) ~= "table" then return {} end
    local lines = {}
    for _, r in ipairs(reward.items or {}) do
        lines[#lines + 1] = (r.count and r.count > 1 and (r.count .. "x ") or "") .. (r.name or Items.displayName(r.type))
    end
    if reward.xp and reward.perk then lines[#lines + 1] = "+" .. reward.xp .. " " .. reward.perk .. " XP" end
    return lines
end

return Items
