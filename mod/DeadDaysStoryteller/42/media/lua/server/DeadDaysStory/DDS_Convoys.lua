-- Roving convoys. Faction convoys travel town to town on a schedule,
-- simulated off-screen, and stop to rest. A player who gets close to a
-- resting convoy finds real vehicles and an armed escort. Kill the escort and
-- the trucks (and what's in them) are yours, and the faction feels it.
-- A moving convoy nearby is heard, not seen: the engine can't drive NPCs.

require "DeadDaysStory/DDS_Core"
require "DeadDaysStory/DDS_State"
require "DeadDaysStory/DDS_ALife"
require "DeadDaysStory/DDS_Items"

DDS.Convoys = DDS.Convoys or { lastMs = 0, heard = {}, live = {} }
local Cv = DDS.Convoys

Cv.SPEED = 260          -- tiles per in-game hour
Cv.MATERIALIZE = 110    -- tiles: resting convoys appear inside this range
Cv.KEEP_OUT = 45        -- ...but never closer than this (no popping in view)
Cv.UNLOAD = 170

local function sandbox() return (SandboxVars and SandboxVars.DeadDaysStory) or {} end

local function townCenter(t)
    return { x = math.floor((t.minX + t.maxX) / 2), y = math.floor((t.minY + t.maxY) / 2), label = t.label }
end

local kinds = {
    { kind = "military", role = "military", label = "{military.name} supply convoy", cars = 2, escort = 4, loot = "ammo" },
    { kind = "raider", role = "antagonist", label = "{antagonist.name} war party", cars = 2, escort = 4, loot = "weapons" },
    { kind = "trader", role = "community", label = "trade caravan", cars = 1, escort = 2, loot = "food" },
}

function Cv.state()
    local w = DDS.State.world()
    w.convoys = w.convoys or { list = {}, seq = 0 }
    return w.convoys
end

function Cv.create(kindDef)
    local st = Cv.state()
    st.seq = st.seq + 1
    local rng = DDS.rng(DDS.freshSeed())
    local towns = DDS.ALife.towns
    local route = {}
    local order = {}
    for i = 1, #towns do order[i] = i end
    rng:shuffle(order)
    for i = 1, 4 do route[i] = townCenter(towns[order[i]]) end
    local factionId = DDS.Factions.resolve(kindDef.role)
    if factionId == kindDef.role then
        local f = kindDef.kind == "military" and DDS.Factions.pickFaction(rng, { "military" })
            or (kindDef.kind == "raider" and DDS.Factions.pickEnemy(rng) or DDS.Factions.pickFriendly(rng))
        factionId = f and f.id or nil
    end
    local c = {
        id = "convoy" .. st.seq, kind = kindDef.kind, label = DDS.Effects.render(kindDef.label, {}), factionId = factionId,
        route = route, leg = 1, progress = 0, state = "resting", restUntil = DDS.nowHours() + rng:int(1, 4),
        cars = kindDef.cars, escort = kindDef.escort, loot = kindDef.loot,
        pos = { x = route[1].x, y = route[1].y },
    }
    st.list[#st.list + 1] = c
    return c
end

local function legTarget(c)
    return c.route[(c.leg % #c.route) + 1]
end

function Cv.advance(c, hours)
    if c.state == "resting" then
        if DDS.nowHours() >= (c.restUntil or 0) and Cv.live[c.id] == nil then c.state = "moving" end
        return
    end
    local a, b = c.route[c.leg], legTarget(c)
    local legLen = math.max(1, DDS.dist(a.x, a.y, b.x, b.y))
    c.progress = c.progress + (Cv.SPEED * hours) / legLen
    if c.progress >= 1 then
        c.leg = (c.leg % #c.route) + 1
        c.progress = 0
        c.state = "resting"
        c.restUntil = DDS.nowHours() + 2 + ZombRand(0, 4)
        c.pos = { x = b.x + ZombRand(-60, 61), y = b.y + ZombRand(-60, 61) }
        c.stopName = b.label
    else
        c.pos = { x = a.x + (b.x - a.x) * c.progress, y = a.y + (b.y - a.y) * c.progress }
    end
end

---------------------------------------------------------------------------
-- In the world
---------------------------------------------------------------------------

local function nearestPlayer(x, y)
    local best, bestD
    for _, p in ipairs(DDS.onlinePlayers()) do
        local d = DDS.dist(p:getX(), p:getY(), x, y)
        if bestD == nil or d < bestD then best, bestD = p, d end
    end
    return best, bestD or 1e9
end

function Cv.materialize(c, player)
    if Cv.live[c.id] or not DDS.ALife.available() then return end
    if not DDS.Sites.squareLoaded(c.pos.x, c.pos.y, 0) then return end
    local pool = DDS.ALife.convoyCars[c.kind] or DDS.ALife.convoyCars.trader
    local cars = {}
    for i = 1, c.cars do
        local car = DDS.ALife.parkVehicle(c.pos.x + (i - 1) * 5, c.pos.y, pool[ZombRand(1, #pool + 1)], "N")
        if car then cars[#cars + 1] = car end
    end
    if #cars == 0 then return end
    Cv.live[c.id] = { cars = cars, uids = {}, born = DDS.nowMs() }
    local lootPool = DDS.Items.pools[c.loot] or DDS.Items.pools.food
    for _ = 1, 3 do DDS.Items.place(c.pos.x, c.pos.y + 3, 0, lootPool[ZombRand(1, #lootPool + 1)], nil, nil, 2) end
    if c.factionId then
        DDS.ALife.spawn(player, {
            x = c.pos.x, y = c.pos.y, z = 0, factionId = c.factionId, count = c.escort, mode = "guard", radius = 14,
            keepOut = 25, persistent = true, hostile = c.kind == "raider" and true or nil,
        }, function(uids)
            if Cv.live[c.id] then for _, uid in ipairs(uids) do Cv.live[c.id].uids[#Cv.live[c.id].uids + 1] = uid end end
            c.escortUids = DDS.copy(uids)
        end)
    end
    DDS.Server.notify(DDS.username(player), "You see vehicles parked ahead: the " .. c.label .. ".", "info")
end

function Cv.unload(c, keepCars)
    if Cv.live[c.id] == nil then return end
    for _, uid in ipairs(Cv.live[c.id].uids) do DDS.ALife.purge(uid, "dds_convoy") end
    if not keepCars then for _, car in ipairs(Cv.live[c.id].cars) do DDS.ALife.removeVehicle(car) end end
    Cv.live[c.id] = nil
    c.escortUids = nil
end

function Cv.checkLive(c)
    if Cv.live[c.id] == nil or #Cv.live[c.id].uids == 0 then return end
    for _, uid in ipairs(Cv.live[c.id].uids) do
        if DDS.ALife.actorState(uid) == "alive" then return end
    end
    -- Escort wiped out: the convoy is broken.
    c.destroyed = true
    DDS.State.chronicle("The " .. c.label .. " was hit near " .. (c.stopName or "the highway") .. ". Nobody from the escort walked away.", "convoy")
    local role = DDS.Factions.roleOf(c.factionId)
    if role then DDS.Factions.shiftPower(role, -6) end
    Cv.live[c.id].uids = {}
    Cv.unload(c, true)
end

---------------------------------------------------------------------------
-- Heartbeat
---------------------------------------------------------------------------

function Cv.tick()
    if sandbox().ConvoysEnabled == false then return end
    local now = DDS.nowMs()
    if now - Cv.lastMs < 5000 then return end
    local hoursNow = DDS.nowHours()
    local st = Cv.state()
    if not Cv.booted then
        -- Escorts left over from before a restart.
        Cv.booted = true
        for _, c in ipairs(st.list) do
            for _, uid in ipairs(c.escortUids or {}) do DDS.ALife.purge(uid, "dds_convoy_restart") end
            c.escortUids = nil
        end
    end
    local dt = math.max(0, hoursNow - (st.lastHours or hoursNow))
    st.lastHours = hoursNow
    Cv.lastMs = now
    if #DDS.onlinePlayers() == 0 then return end

    -- Keep one convoy of each kind alive.
    local have = {}
    local keep = {}
    for _, c in ipairs(st.list) do
        if not c.destroyed then keep[#keep + 1] = c; have[c.kind] = true
        elseif Cv.live[c.id] then keep[#keep + 1] = c end
    end
    st.list = keep
    for _, k in ipairs(kinds) do if not have[k.kind] then Cv.create(k) end end

    for _, c in ipairs(st.list) do
        if not c.destroyed then
            Cv.advance(c, dt)
            local player, d = nearestPlayer(c.pos.x, c.pos.y)
            if c.state == "resting" then
                if Cv.live[c.id] == nil and player and d < Cv.MATERIALIZE and d > Cv.KEEP_OUT then
                    Cv.materialize(c, player)
                elseif Cv.live[c.id] and d > Cv.UNLOAD then
                    Cv.unload(c, false)
                end
                Cv.checkLive(c)
            elseif player and d < 150 then
                local key = c.id .. ":" .. DDS.username(player)
                if (Cv.heard[key] or 0) + 600000 < now then
                    Cv.heard[key] = now
                    local dir = DDS.compass(c.pos.x - player:getX(), c.pos.y - player:getY())
                    DDS.Server.notify(DDS.username(player), "Engines to the " .. dir .. ". Several vehicles, moving. Sounds like the " .. c.label .. ".", "info")
                    pcall(function() addSound(nil, math.floor(c.pos.x), math.floor(c.pos.y), 0, 80, 60) end)
                end
            end
        elseif Cv.live[c.id] then
            local _, d = nearestPlayer(c.pos.x, c.pos.y)
            if d > Cv.UNLOAD then Cv.live[c.id] = nil end -- wreck stays, bookkeeping goes
        end
    end
end

-- Where are they? (for missions and rumors)
function Cv.find(kind)
    for _, c in ipairs(Cv.state().list) do
        if c.kind == kind and not c.destroyed then return c end
    end
    return nil
end

return Cv
