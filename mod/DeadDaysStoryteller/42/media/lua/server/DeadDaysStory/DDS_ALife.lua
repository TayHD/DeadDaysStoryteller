-- Project A-Life adapter. The only file that reaches into A-Life internals.
-- When A-Life updates, this is the file to check. Every call is guarded so a
-- changed A-Life degrades the story (fallbacks) instead of breaking it.

require "DeadDaysStory/DDS_Core"

DDS.ALife = DDS.ALife or { pending = {}, killListeners = {}, wrapped = false }
local AL = DDS.ALife

function AL.available()
    local P = ProjectALife
    return type(P) == "table" and type(P.DebugService) == "table"
        and type(P.DebugService.spawnEncounter) == "function"
        and type(P.Runtime) == "table" and P.Runtime.started == true
end

function AL.present()
    return type(ProjectALife) == "table" and type(ProjectALife.Catalog) == "table"
end

---------------------------------------------------------------------------
-- Factions
---------------------------------------------------------------------------

AL.fallbackFactions = {
    { id = "dds_raiders", name = "Highway Raiders", heading = "Road Gang", bloc = "raider", player = "hostile", peaceable = false,
      blurb = "They own the interstate and charge for it in blood." },
    { id = "dds_guard", name = "Guard Remnant", heading = "Military Holdouts", bloc = "military", player = "careful", peaceable = false,
      blurb = "Uniforms, radios, and orders from nobody they can name." },
    { id = "dds_church", name = "Church Survivors", heading = "Community", bloc = "civilian", player = "friendly", peaceable = true,
      blurb = "Thirty people behind barricaded pews, praying for a plan." },
    { id = "dds_deputies", name = "County Deputies", heading = "Law Remnant", bloc = "law", player = "neutral", peaceable = false,
      blurb = "Badges and shotguns, enforcing a law that ended in July." },
}

function AL.catalog()
    local result = {}
    if AL.present() then
        pcall(function()
            local Catalog = ProjectALife.Catalog
            local current = Catalog.current or Catalog.load()
            for _, faction in ipairs(current and current.factionOrder or {}) do
                local general = faction.general or {}
                local relations = faction.relations or {}
                local spawn = faction.spawn or {}
                local hasMembers = false
                for _, profile in ipairs(current.npcOrder or {}) do
                    if profile.general and profile.general.faction == faction.id then hasMembers = true; break end
                end
                if hasMembers then
                    result[#result + 1] = {
                        id = faction.id,
                        name = general.name or faction.id,
                        heading = general.category or "",
                        blurb = general.description or "",
                        bloc = string.lower(tostring(relations.bloc or "")),
                        player = string.lower(tostring(relations.player or (spawn.peaceable == true and "friendly" or "hostile"))),
                        peaceable = spawn.peaceable == true or spawn.peaceable == "true",
                    }
                end
            end
        end)
    end
    if #result == 0 then return DDS.copy(AL.fallbackFactions) end
    return result
end

function AL.factionInfo(id)
    if id == nil then return nil end
    AL.cache = AL.cache or {}
    if AL.cache[id] then return AL.cache[id] end
    for _, f in ipairs(AL.catalog()) do
        AL.cache[f.id] = f
    end
    return AL.cache[id]
end

function AL.factionName(id)
    local info = AL.factionInfo(id)
    return info and info.name or tostring(id or "Unknown")
end

---------------------------------------------------------------------------
-- Reputation bridge: story standing writes into A-Life's own reputation
-- store, so a faction you have wronged in the story shoots on sight.
---------------------------------------------------------------------------

AL.REP_TAG = "ProjectALife.Reputation.v1"

function AL.setStance(player, factionId, status)
    if not AL.present() or factionId == nil or player == nil then return false end
    local Rep = ProjectALife.Reputation
    if type(Rep) ~= "table" then return false end
    local ok = pcall(function()
        local key = Rep.playerKey(player)
        if key == nil then return end
        local store = ModData.getOrCreate(Rep.TAG or AL.REP_TAG)
        if store.schema == nil then store.schema = 1 end
        store.players = store.players or {}
        local mine = store.players[key] or {}
        store.players[key] = mine
        local baseline = Rep.defaultStatus and Rep.defaultStatus(factionId) or nil
        if status == nil or status == baseline then
            if mine[factionId] and mine[factionId].cause == "story" then mine[factionId] = nil end
        else
            local existing = mine[factionId]
            -- A grudge the player earned by shooting them outranks story goodwill.
            if existing and existing.status == "hostile" and existing.cause ~= "story" and status ~= "hostile" then return end
            mine[factionId] = { status = status, cause = "story", atHours = DDS.nowHours() }
        end
        Rep.dirty = true
        if type(Rep.sync) == "function" then Rep.sync(player) end
    end)
    return ok
end

function AL.stanceFor(player, factionId)
    if not AL.present() then return nil end
    local status
    pcall(function() status = ProjectALife.Reputation.statusFor(player, factionId) end)
    return status
end

---------------------------------------------------------------------------
-- Spawning squads
---------------------------------------------------------------------------

AL.sequence = 0

-- A named story character needs a body that matches them. Pick an A-Life
-- profile from the faction with the right sex; `seedText` (their name) makes
-- the choice stable, so the same person always gets the same face.
local function seedOf(text)
    local h = 5381
    text = tostring(text or "")
    for i = 1, #text do h = (h * 33 + string.byte(text, i)) % 2147483647 end
    return h
end

function AL.pickProfile(factionId, female, seedText)
    if factionId == nil or female == nil or not AL.present() then return nil end
    local pool = {}
    pcall(function()
        local Catalog = ProjectALife.Catalog
        local current = Catalog.current or Catalog.load()
        for _, profile in ipairs(current and current.npcOrder or {}) do
            local g = profile.general
            if g and tostring(g.faction or "") == tostring(factionId) and (g.female == true) == (female == true)
                    and (tonumber(g.spawnWeight) or 1) > 0 and g.deleted ~= true then
                pool[#pool + 1] = profile.id
            end
        end
    end)
    if #pool == 0 then
        DDS.log("no " .. (female and "female" or "male") .. " profile in faction " .. tostring(factionId))
        return nil
    end
    return pool[(seedOf(seedText) % #pool) + 1]
end

-- Which sexes a faction can actually field: { m = bool, f = bool }, or nil
-- if the catalog can't be read (then anything goes).
function AL.sexesIn(factionId)
    if factionId == nil or not AL.present() then return nil end
    local found
    pcall(function()
        local Catalog = ProjectALife.Catalog
        local current = Catalog.current or Catalog.load()
        found = { m = false, f = false }
        for _, profile in ipairs(current and current.npcOrder or {}) do
            local g = profile.general
            if g and tostring(g.faction or "") == tostring(factionId)
                    and (tonumber(g.spawnWeight) or 1) > 0 and g.deleted ~= true then
                if g.female == true then found.f = true else found.m = true end
            end
        end
    end)
    if found and not found.m and not found.f then return nil end
    return found
end

-- The sex of the body an actor was spawned with (nil if unknown).
function AL.actorFemale(uid)
    local actor = AL.actor(uid)
    if actor == nil or actor.profileId == nil then return nil end
    local female
    pcall(function()
        local profile = ProjectALife.Catalog.npc(actor.profileId)
        if profile and profile.general then female = profile.general.female == true end
    end)
    return female
end

-- spec: x,y,z, factionId, count, mode, persistent, invulnerable, stationary,
--   leash, hostile (true/false/nil), stance ("friendly"/"neutral"/"hostile"),
--   keepOut, targetUsername, arrival, profileIds, scriptedId, noFlee,
--   female + person (a named character: body sex matched, face kept stable)
-- onDone(uids, outcome) fires when A-Life settles the group.
function AL.spawn(player, spec, onDone)
    if not AL.available() then return nil, "alife_unavailable" end
    if player == nil then return nil, "player_required" end
    AL.sequence = AL.sequence + 1
    if spec.profileIds == nil and spec.female ~= nil then
        local id = AL.pickProfile(spec.factionId, spec.female, spec.person)
        if id then spec.profileIds = { id } end
    end
    local requestId = "dds:" .. tostring(math.floor(DDS.nowMs())) .. ":" .. tostring(AL.sequence)
    local args = {
        requestId = requestId,
        x = math.floor(spec.x), y = math.floor(spec.y), z = math.floor(spec.z or 0),
        factionId = spec.factionId,
        count = DDS.clamp(math.floor(tonumber(spec.count) or 1), 1, 8),
        mode = spec.mode or "guard",
        radius = spec.radius or 18,
        separation = spec.separation or 2,
        playerKeepOut = spec.keepOut or 18,
        persistent = spec.persistent ~= false,
        invulnerable = spec.invulnerable == true,
        stationary = spec.stationary == true,
        leashRadius = spec.leash,
        hostileOverride = spec.hostile,
        playerStance = spec.stance,
        targetUsername = spec.targetUsername,
        arrival = spec.arrival,
        profileIds = spec.profileIds,
        holdPost = spec.holdPost,
        awareness = spec.awareness,
        scripted = spec.scriptedId and { id = tostring(spec.scriptedId) } or nil,
        supportRole = spec.supportRole,
        moduleOverrides = spec.noFlee and { flee = "off", panic = "off", withdraw = "off" } or nil,
    }
    -- Friendly story people may stand where a player has made camp.
    if spec.hostile == false then
        AL.hookSpawnPolicy()
        AL.addStoryZone(args.x, args.y, (args.radius or 18) + 6)
    end
    local ok, accepted, reason, result = pcall(ProjectALife.DebugService.spawnEncounter, player, args, true)
    if not ok then return nil, "spawn_error:" .. tostring(accepted) end
    if not accepted then return nil, reason or "spawn_rejected" end
    AL.pending[requestId] = { onDone = onDone, atMs = DDS.nowMs() }
    local friendly = spec.hostile == false
    pcall(ProjectALife.DebugService.watchGroup, requestId, function(outcome)
        local entry = AL.pending[requestId]
        AL.pending[requestId] = nil
        -- Anchored like admin-placed NPCs: never culled as expendable, and
        -- re-created in place when a player returns, even inside a base.
        if friendly then
            for _, uid in ipairs(outcome and outcome.actorUids or {}) do
                AL.patchMemory(uid, function(memory) memory.adminAnchor = true end)
            end
        end
        if entry and entry.onDone then
            local uids = {}
            for _, uid in ipairs(outcome and outcome.actorUids or {}) do uids[#uids + 1] = uid end
            pcall(entry.onDone, uids, outcome)
        end
    end)
    return requestId
end

local function registry()
    return ProjectALife and ProjectALife.ActorRegistry or nil
end

function AL.actor(uid)
    local reg = registry()
    if reg == nil or uid == nil then return nil end
    local actor
    pcall(function() actor = reg.read(uid) end)
    return actor
end

-- "alive", "dead", or "gone" (purged / unknown)
function AL.actorState(uid)
    local actor = AL.actor(uid)
    if actor == nil then return "gone" end
    if actor.lifecycle == "dead" then return "dead" end
    return "alive"
end

function AL.shell(uid)
    if uid == nil or not AL.present() then return nil end
    local shell
    pcall(function()
        local binding = ProjectALife.Watchdog and ProjectALife.Watchdog.bindings[uid]
        if binding and binding.shell then shell = binding.shell end
    end)
    return shell
end

function AL.position(uid)
    local shell = AL.shell(uid)
    if shell then
        local x, y, z
        pcall(function() x, y, z = shell:getX(), shell:getY(), shell:getZ() end)
        if x then return { x = x, y = y, z = z } end
    end
    local actor = AL.actor(uid)
    if actor and type(actor.worldPosition) == "table" then return actor.worldPosition end
    return nil
end

function AL.say(uid, text, earshot)
    local shell = AL.shell(uid)
    if shell == nil or text == nil then return false end
    local ok, sent = pcall(function()
        return ProjectALife.Speech.say(shell, text, { earshot = earshot or 25 })
    end)
    return ok and sent
end

function AL.purge(uid, reason)
    local actor = AL.actor(uid)
    if actor == nil then return true end
    local ok = pcall(function() ProjectALife.DebugService.purgeActor(actor, reason or "dds_story") end)
    return ok
end

-- Mutate an actor's memory through A-Life's own registry (revision-checked).
function AL.patchMemory(uid, mutate)
    local reg = registry()
    if reg == nil or type(reg.updateTransient) ~= "function" then return false end
    local actor = AL.actor(uid)
    if actor == nil or actor.lifecycle == "dead" then return false end
    local ok, result = pcall(reg.updateTransient, uid, actor.revision, function(record)
        record.memory = type(record.memory) == "table" and record.memory or {}
        mutate(record.memory)
    end)
    return ok and result ~= nil
end

-- Companion steering. A-Life walks "backup" support actors toward
-- memory.objective whenever they are more than 3 tiles away from it; we keep
-- re-pointing that objective (and their patrol home) at the player.
function AL.follow(uid, x, y, z)
    return AL.patchMemory(uid, function(memory)
        memory.supportRole = "backup"
        memory.objective = { x = x, y = y, z = z or 0, untilMs = DDS.nowMs() + 6000 }
        memory.home = { x = x, y = y, z = z or 0 }
        memory.patrolRadius = 4
    end)
end

function AL.holdAt(uid, x, y, z)
    return AL.patchMemory(uid, function(memory)
        memory.objective = nil
        memory.home = { x = x, y = y, z = z or 0 }
        memory.patrolRadius = 3
    end)
end

-- Friendly story NPCs: when a player comes within `reach` of their post they
-- move up to cover the player (and A-Life's combat AI engages whatever is
-- there); when the player leaves they go back to the post. A leash set at
-- spawn keeps them from chasing too far from home.
AL.assisting = AL.assisting or {}

function AL.assist(uid, post, player, reach)
    if uid == nil or post == nil then return end
    local px, py, pz
    if player then pcall(function() px, py, pz = player:getX(), player:getY(), player:getZ() end) end
    local near = px ~= nil and DDS.dist(px, py, post.x, post.y) <= (reach or 22)
    if near then
        AL.follow(uid, px, py, pz)
        AL.assisting[uid] = true
    elseif AL.assisting[uid] then
        AL.holdAt(uid, post.x, post.y, post.z or 0)
        AL.assisting[uid] = nil
    end
end

function AL.uidOf(zombie)
    local uid
    pcall(function()
        local data = zombie:getModData()
        if data then uid = data.ProjectALifeUID end
    end)
    return uid
end

---------------------------------------------------------------------------
-- Kill attribution: A-Life already resolves who killed one of its actors.
-- We listen in by wrapping Reputation.onPlayerKilledActor once.
---------------------------------------------------------------------------

function AL.onKill(listener)
    AL.killListeners[#AL.killListeners + 1] = listener
end

---------------------------------------------------------------------------
-- Story spawn zones. A-Life refuses to spawn anyone inside a "player base",
-- and it marks any building a player spends ~30 minutes in as their base
-- (BaseHeat). The settlement is exactly where players hang around, so its
-- people stopped spawning. While one of our friendly story spawns is being
-- placed, a small zone around its spawn point is exempt from the base and
-- player-build checks. Everything else keeps A-Life's protection.
---------------------------------------------------------------------------

AL.storyZones = AL.storyZones or {}
AL.STORY_ZONE_MS = 60000

function AL.addStoryZone(x, y, radius)
    AL.storyZones[#AL.storyZones + 1] = { x = x, y = y, r = radius, untilMs = DDS.nowMs() + AL.STORY_ZONE_MS }
end

function AL.inStoryZone(position)
    if type(position) ~= "table" or position.x == nil then return false end
    local now = DDS.nowMs()
    local keep, hit = {}, false
    for _, z in ipairs(AL.storyZones) do
        if z.untilMs > now then
            keep[#keep + 1] = z
            if DDS.dist(position.x, position.y, z.x, z.y) <= z.r then hit = true end
        end
    end
    AL.storyZones = keep
    return hit
end

function AL.hookSpawnPolicy()
    if AL.policyHooked or not AL.present() then return end
    local SP = ProjectALife.SpawnPolicy
    if type(SP) ~= "table" or type(SP.inPlayerBase) ~= "function" then return end
    AL.policyHooked = true
    for _, name in ipairs({ "inPlayerBase", "insidePlayerBuild", "enclosedByPlayerBuild" }) do
        local original = SP[name]
        if type(original) == "function" then
            SP[name] = function(position, ...)
                if AL.inStoryZone(position) then return false end
                return original(position, ...)
            end
        end
    end
    DDS.log("A-Life spawn policy hook installed (story zones)")
end

function AL.installHooks()
    AL.hookSpawnPolicy()
    if AL.wrapped or not AL.present() then return end
    local Rep = ProjectALife.Reputation
    if type(Rep) ~= "table" or type(Rep.onPlayerKilledActor) ~= "function" then return end
    AL.wrapped = true
    local original = Rep.onPlayerKilledActor
    Rep.onPlayerKilledActor = function(player, actorOrFaction)
        local first, second = original(player, actorOrFaction)
        if type(actorOrFaction) == "table" then
            for _, listener in ipairs(AL.killListeners) do
                pcall(listener, player, actorOrFaction)
            end
        end
        return first, second
    end
    DDS.log("A-Life kill hook installed")
end

---------------------------------------------------------------------------
-- Outposts (for sabotage missions)
---------------------------------------------------------------------------

function AL.outposts()
    local result = {}
    if not AL.present() then return result end
    pcall(function()
        for _, site in ipairs(ProjectALife.OutpostRegistry.list()) do
            if site.state ~= "expired" and site.factionId then
                result[#result + 1] = {
                    id = site.id, factionId = site.factionId, x = site.x, y = site.y,
                    radio = site.radio, commsDisabled = site.commsDisabled == true,
                    state = site.state, presetId = site.presetId,
                }
            end
        end
    end)
    return result
end

function AL.disableComms(siteId)
    if not AL.present() then return false end
    local ok, changed = pcall(function()
        local Registry = ProjectALife.OutpostRegistry
        local site = Registry.read(siteId)
        if site == nil then return false end
        return Registry.update(siteId, site.revision, function(s) s.commsDisabled = true end) ~= nil
    end)
    if ok and changed then
        pcall(function() ProjectALife.DebugService.broadcastOutpostRadios() end)
    end
    return ok and changed
end

---------------------------------------------------------------------------
-- Vehicles (convoys). Finds clear outdoor ground and parks a vehicle using
-- A-Life's builder when present, else the vanilla debug spawner.
---------------------------------------------------------------------------

AL.convoyCars = {
    military = { "Base.PickUpTruck_Camo", "Base.PickUpVan_Camo", "Base.StepVan" },
    raider = { "Base.PickUpTruck", "Base.OffRoad", "Base.SUV", "Base.PickUpVan" },
    trader = { "Base.StepVan", "Base.PickUpVan", "Base.CarStationWagon", "Base.PickUpTruck" },
}

function AL.parkVehicle(x, y, script, facing)
    local spot
    pcall(function()
        local cell = getCell()
        for radius = 0, 8 do
            for dx = -radius, radius do
                for dy = -radius, radius do
                    if spot == nil and (math.abs(dx) == radius or math.abs(dy) == radius) then
                        local clear = true
                        for ox = -1, 1 do
                            for oy = -2, 2 do
                                local sq = cell:getGridSquare(math.floor(x) + dx + ox, math.floor(y) + dy + oy, 0)
                                if sq == nil or not sq:isOutside() or sq:isFree(false) ~= true then clear = false end
                            end
                        end
                        if clear then spot = { x = math.floor(x) + dx, y = math.floor(y) + dy } end
                    end
                end
            end
        end
    end)
    if spot == nil then return nil end
    local car
    pcall(function()
        local builder = ProjectALife and ProjectALife.OutpostBuilder
        if builder and type(builder.placeVehicle) == "function" then
            car = builder.placeVehicle(spot.x, spot.y, 0, script, facing or "N", 12)
        end
    end)
    if car == nil then
        pcall(function()
            local sq = getCell():getGridSquare(spot.x, spot.y, 0)
            car = addVehicleDebug(script, IsoDirections.N, nil, sq)
        end)
    end
    return car
end

function AL.removeVehicle(car)
    if car == nil then return end
    pcall(function() car:permanentlyRemove() end)
end

---------------------------------------------------------------------------
-- Towns
---------------------------------------------------------------------------

AL.towns = {
    { id = "brandenburg", label = "Brandenburg", minX = 1064, maxX = 3564, minY = 5003, maxY = 7503 },
    { id = "echo_creek", label = "Echo Creek", minX = 3185, maxX = 5285, minY = 10019, maxY = 12119 },
    { id = "ekron", label = "Ekron", minX = -30, maxX = 2070, minY = 8788, maxY = 10888 },
    { id = "fallas_lake", label = "Fallas Lake", minX = 6298, maxX = 8398, minY = 7321, maxY = 9421 },
    { id = "irvington", label = "Irvington", minX = 1479, maxX = 3979, minY = 12547, maxY = 15047 },
    { id = "louisville", label = "Louisville", minX = 11700, maxX = 14699, minY = 900, maxY = 3899 },
    { id = "march_ridge", label = "March Ridge", minX = 8721, maxX = 11121, minY = 11403, maxY = 13803 },
    { id = "muldraugh", label = "Muldraugh", minX = 9631, maxX = 12731, minY = 8175, maxY = 11275 },
    { id = "riverside", label = "Riverside", minX = 4950, maxX = 7650, minY = 4318, maxY = 7018 },
    { id = "rosewood", label = "Rosewood", minX = 7246, maxX = 9646, minY = 10356, maxY = 12756 },
    { id = "valley_station", label = "Valley Station", minX = 11656, maxX = 14456, minY = 4631, maxY = 7431 },
    { id = "west_point", label = "West Point", minX = 10181, maxX = 12981, minY = 5516, maxY = 8316 },
}

function AL.townAt(x, y)
    local best, bestDist
    for _, d in ipairs(AL.towns) do
        local dx = math.max(d.minX - x, 0, x - d.maxX)
        local dy = math.max(d.minY - y, 0, y - d.maxY)
        local dist = math.sqrt(dx * dx + dy * dy)
        if bestDist == nil or dist < bestDist then best, bestDist = d, dist end
    end
    if best == nil then return "the county", 9999 end
    if bestDist > 600 then return "the backroads outside " .. best.label, bestDist end
    if bestDist > 0 then return "outside " .. best.label, bestDist end
    return best.label, 0
end

return AL
