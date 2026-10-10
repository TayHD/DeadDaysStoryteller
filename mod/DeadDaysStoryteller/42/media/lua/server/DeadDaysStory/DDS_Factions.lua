-- Factions, standing and politics.
-- Standing is per player, per A-Life faction, -100..100. It is the story's
-- number; A-Life's stance (hostile/careful/neutral/friendly) is derived from
-- it and written back so NPC behaviour follows the story.

require "DeadDaysStory/DDS_Core"
require "DeadDaysStory/DDS_State"
require "DeadDaysStory/DDS_ALife"

DDS.Factions = DDS.Factions or {}
local F = DDS.Factions

F.roleBlocs = {
    antagonist = { "raider", "gang", "club", "crime" },
    military = { "military", "elite" },
    community = { "family", "civilian", "rescue", "worker" },
    wildcard = { "law", "crime", "worker", "prison", "club" },
}

-- Which saga roles care about each other. +1 allies, -1 enemies.
F.politics = {
    antagonist = { community = -1, military = -1, wildcard = 0 },
    military = { antagonist = -1, community = 0, wildcard = -1 },
    community = { antagonist = -1, military = 0, wildcard = 0 },
    wildcard = { antagonist = 0, military = -1, community = 0 },
}

F.voice = {
    raider = { want = "everything you own", creed = "Take it before someone else does.", fear = "a stronger crew" },
    gang = { want = "territory", creed = "Blocks are blocks, even when the dead walk them.", fear = "looking weak" },
    club = { want = "the roads", creed = "Brothers first. Everyone else pays the toll.", fear = "a brother turning" },
    crime = { want = "leverage", creed = "Everything is a deal. Even this.", fear = "witnesses" },
    military = { want = "order", creed = "The mission continues until relieved.", fear = "the chain of command being a lie" },
    elite = { want = "the objective", creed = "Need-to-know. You don't.", fear = "nothing they'd admit to" },
    law = { want = "control", creed = "Somebody has to keep the peace.", fear = "being the only ones left who care" },
    family = { want = "to keep their people alive", creed = "Blood looks after blood.", fear = "losing another one" },
    civilian = { want = "a tomorrow", creed = "We help who we can.", fear = "running out of food before winter" },
    rescue = { want = "to save who's left", creed = "Nobody gets left behind.", fear = "not getting there in time" },
    worker = { want = "fair trade", creed = "You pull your weight, you eat.", fear = "the generators failing" },
    prison = { want = "to never go back", creed = "No more cages.", fear = "the uniforms" },
}

function F.baseline(stance)
    stance = string.lower(tostring(stance or "neutral"))
    if stance == "hostile" then return -40 end
    if stance == "careful" or stance == "suspicious" then return -10 end
    if stance == "friendly" then return 25 end
    if stance == "allied" then return 45 end
    return 0
end

function F.label(value)
    value = tonumber(value) or 0
    if value <= -60 then return "Kill on sight" end
    if value <= -25 then return "Hostile" end
    if value < -5 then return "Wary" end
    if value < 20 then return "Neutral" end
    if value < 50 then return "Trusted" end
    return "Allied"
end

function F.alifeStatus(value)
    value = tonumber(value) or 0
    if value <= -25 then return "hostile" end
    if value < -5 then return "careful" end
    if value < 20 then return "neutral" end
    return "friendly"
end

function F.get(ps, factionId)
    if ps == nil or factionId == nil then return 0 end
    local value = ps.standing[factionId]
    if value == nil then
        local info = DDS.ALife.factionInfo(factionId)
        value = F.baseline(info and info.player)
        ps.standing[factionId] = value
    end
    return value
end

-- Role ("antagonist") or faction id -> faction id, using the current saga.
function F.resolve(roleOrId)
    if roleOrId == nil then return nil end
    local saga = DDS.State.world().saga
    if saga and saga.roles and saga.roles[roleOrId] then return saga.roles[roleOrId].factionId end
    return roleOrId
end

function F.roleOf(factionId)
    local saga = DDS.State.world().saga
    if saga == nil or saga.roles == nil then return nil end
    for role, r in pairs(saga.roles) do
        if r.factionId == factionId then return role end
    end
    return nil
end

function F.applyStance(username, factionId)
    local player = DDS.playerByName(username)
    if player == nil then return end
    local ps = DDS.State.player(username)
    DDS.ALife.setStance(player, factionId, F.alifeStatus(F.get(ps, factionId)))
end

-- Change standing. Ripples to saga-linked factions at 30%.
function F.change(username, roleOrId, delta, reason, noRipple)
    local factionId = F.resolve(roleOrId)
    if factionId == nil or delta == nil or delta == 0 then return 0 end
    local ps = DDS.State.player(username)
    local before = F.get(ps, factionId)
    local after = DDS.clamp(before + delta, -100, 100)
    ps.standing[factionId] = after
    ps.standingLog = ps.standingLog or {}
    DDS.push(ps.standingLog, { day = DDS.day(), factionId = factionId, delta = delta, reason = reason }, 30)
    F.applyStance(username, factionId)
    if F.label(before) ~= F.label(after) then
        DDS.Server.notify(username, DDS.ALife.factionName(factionId) .. " now see you as: " .. F.label(after),
            delta > 0 and "good" or "bad")
    end
    if not noRipple then
        local role = F.roleOf(factionId)
        local links = role and F.politics[role] or nil
        if links then
            for otherRole, sign in pairs(links) do
                if sign ~= 0 then
                    local raw = delta * 0.3 * sign
                    local ripple = raw >= 0 and math.floor(raw + 0.5) or -math.floor(-raw + 0.5)
                    if ripple ~= 0 then F.change(username, otherRole, ripple, "ripple", true) end
                end
            end
        end
    end
    DDS.Server.markDirty(username)
    return after
end

function F.syncAll(username)
    local ps = DDS.State.player(username)
    for factionId in pairs(ps.standing) do F.applyStance(username, factionId) end
end

-- Faction power: how strong a saga role is in the world. Drives the director.
function F.power(role)
    local saga = DDS.State.world().saga
    if saga == nil or saga.power == nil then return 50 end
    return saga.power[role] or 50
end

function F.shiftPower(role, delta, why)
    local saga = DDS.State.world().saga
    if saga == nil or saga.power == nil or saga.power[role] == nil then return end
    local before = saga.power[role]
    saga.power[role] = DDS.clamp(before + delta, 0, 100)
    if before >= 20 and saga.power[role] < 20 and why then
        DDS.State.chronicle(saga.roles[role].name .. " are breaking apart. " .. why, "power")
    end
end

-- Pick a faction for a role from the live catalog, preferring the given
-- player stances. Used at saga creation and for side missions.
function F.pickFaction(rng, blocs, stances, exclude)
    exclude = exclude or {}
    local pool = {}
    for _, f in ipairs(DDS.ALife.catalog()) do
        if not exclude[f.id] and DDS.contains(blocs, f.bloc) then
            if stances == nil or DDS.contains(stances, f.player) then pool[#pool + 1] = f end
        end
    end
    if #pool == 0 and stances ~= nil then return F.pickFaction(rng, blocs, nil, exclude) end
    if #pool == 0 then
        for _, f in ipairs(DDS.ALife.catalog()) do
            if not exclude[f.id] then pool[#pool + 1] = f end
        end
    end
    return rng:pick(pool)
end

-- Any hostile faction (for side-mission enemies), weighted toward the saga antagonist.
function F.pickEnemy(rng, preferRole)
    local saga = DDS.State.world().saga
    if saga and saga.roles and rng:chance(0.55) then
        local role = saga.roles[preferRole or "antagonist"]
        if role then return DDS.ALife.factionInfo(role.factionId) or role end
    end
    return F.pickFaction(rng, { "raider", "gang", "club", "crime", "prison" }, { "hostile" })
end

function F.pickFriendly(rng)
    local saga = DDS.State.world().saga
    if saga and saga.roles and saga.roles.community and rng:chance(0.5) then
        return DDS.ALife.factionInfo(saga.roles.community.factionId) or saga.roles.community
    end
    return F.pickFaction(rng, { "family", "civilian", "rescue", "worker" }, { "friendly", "neutral", "allied" })
end

-- A lone survivor-type faction to stand in for a captive or a stranger.
function F.pickCivilian(rng)
    local ids = { "alife_lone_nurse", "alife_lost_teen", "alife_lone_student", "alife_lone_hiker", "alife_lost_tourist",
        "alife_lone_courier", "alife_refugee_walkers", "alife_office_workers", "alife_lone_commuter", "alife_lone_farmhand" }
    rng:shuffle(ids)
    for _, id in ipairs(ids) do
        local info = DDS.ALife.factionInfo(id)
        if info then return info end
    end
    return F.pickFaction(rng, { "civilian", "family" }, nil)
end

function F.view(ps)
    local rows = {}
    local saga = DDS.State.world().saga
    local shown = {}
    if saga and saga.roles then
        for _, role in ipairs({ "community", "military", "antagonist", "wildcard" }) do
            local r = saga.roles[role]
            if r then
                shown[r.factionId] = true
                local v = F.get(ps, r.factionId)
                rows[#rows + 1] = { id = r.factionId, name = r.name, role = role, value = v, label = F.label(v),
                    heading = r.heading, power = saga.power and saga.power[role] or 50, blurb = r.blurb }
            end
        end
    end
    for factionId, v in pairs(ps.standing) do
        if not shown[factionId] and v ~= F.baseline((DDS.ALife.factionInfo(factionId) or {}).player) then
            local info = DDS.ALife.factionInfo(factionId) or {}
            rows[#rows + 1] = { id = factionId, name = info.name or factionId, value = v, label = F.label(v),
                heading = info.heading, blurb = info.blurb }
        end
    end
    return rows
end

return F
