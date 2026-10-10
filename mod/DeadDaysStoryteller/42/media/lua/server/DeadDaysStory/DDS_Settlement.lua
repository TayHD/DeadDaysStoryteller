-- The settlement is a place, not a menu. When a player comes near the saga's
-- home, its people are there: the leader, the doctor, a couple of guards on
-- the fence. They defend it, and when a player is close they move up and
-- fight alongside them. Quest conversations at the settlement reuse these
-- residents instead of spawning copies.

require "DeadDaysStory/DDS_Core"
require "DeadDaysStory/DDS_State"
require "DeadDaysStory/DDS_ALife"
require "DeadDaysStory/DDS_Sites"

DDS.Settlement = DDS.Settlement or { lastMs = 0, live = {}, pending = {}, booted = false }
local St = DDS.Settlement

St.LOAD = 95       -- spawn residents when a player is this close to home
St.UNLOAD = 170    -- remove them when everyone is further than this
St.ASSIST = 24     -- residents move up to cover a player this close to their post
St.LEASH = 30      -- and never chase further than this from it

local GONE = { dead = true, exiled = true, deposed = true, arrested = true, fled = true,
    with_warlord = true, with_military = true, taken = true, held = true }

local function saga() return DDS.State.world().saga end

-- Who lives here right now. Keys double as cast keys where relevant.
function St.roster(s)
    local list = {}
    local home = s.home
    local function post(i)
        local p = home.points and home.points[i] or home.inner or home
        return { x = p.x, y = p.y, z = p.z or 0 }
    end
    if not GONE[s.cast.contact.status or ""] then
        list[#list + 1] = { key = "contact", name = s.cast.contact.name, female = s.cast.contact.female, post = post(1), protected = true }
    end
    if not GONE[s.cast.doctor.status or ""] then
        list[#list + 1] = { key = "doctor", name = s.cast.doctor.name, female = s.cast.doctor.female, post = post(2), protected = true }
    end
    if s.cast.lost.status == "home" or s.cast.lost.status == "free" then
        list[#list + 1] = { key = "lost", name = s.cast.lost.name, female = s.cast.lost.female, post = post(3), protected = true }
    end
    -- Guards: more when the community is strong, none if it's broken.
    local guards = s.power.community >= 60 and 3 or (s.power.community >= 25 and 2 or (s.power.community >= 10 and 1 or 0))
    if s.flags.settlementBurned then guards = 0 end
    for i = 1, guards do
        list[#list + 1] = { key = "guard" .. i, name = "Fence guard", post = DDS.Sites.ring(home.x, home.y, 8, home.radius + 6, DDS.rng(i * 97 + s.n)), protected = false }
    end
    return list
end

function St.residentUid(key)
    local r = St.live[key]
    if r and r.uid and DDS.ALife.actorState(r.uid) == "alive" then return r.uid end
    return nil
end

-- True when the settlement itself will spawn this person (so a quest should
-- wait for them rather than make a second copy).
function St.handles(key)
    local s = saga()
    if s == nil or s.ended or s.home == nil or not DDS.ALife.available() then return false end
    if St.suppressed and St.suppressed[key] and St.suppressed[key] > DDS.nowMs() then return false end
    for _, r in ipairs(St.roster(s)) do
        if r.key == key then return true end
    end
    return false
end

-- A quest needs this person for something the residents can't do (e.g. a
-- mortal judgment scene): hand them over by removing the resident.
function St.release(key)
    local r = St.live[key]
    if r and r.uid then DDS.ALife.purge(r.uid, "dds_settlement_release") end
    St.live[key] = nil
    St.suppressed = St.suppressed or {}
    St.suppressed[key] = DDS.nowMs() + 30 * 60000
end

local function nearestPlayer(x, y)
    local best, bestD
    for _, p in ipairs(DDS.onlinePlayers()) do
        local d = DDS.dist(p:getX(), p:getY(), x, y)
        if bestD == nil or d < bestD then best, bestD = p, d end
    end
    return best, bestD or 1e9
end

local function spawnResident(s, r, player)
    if St.pending[r.key] and DDS.nowMs() - St.pending[r.key] < 20000 then return end
    St.pending[r.key] = DDS.nowMs()
    DDS.ALife.spawn(player, {
        x = r.post.x, y = r.post.y, z = r.post.z, factionId = s.roles.community.factionId, count = 1,
        mode = "guard", hostile = false, stance = "friendly", keepOut = 10, persistent = true,
        invulnerable = r.protected, noFlee = true, leash = St.LEASH, radius = 10,
        female = r.female, person = r.name,
    }, function(uids)
        St.pending[r.key] = nil
        if #uids == 0 then return end
        St.live[r.key] = { uid = uids[1], post = r.post, name = r.name }
        s.residentUids = s.residentUids or {}
        s.residentUids[r.key] = uids[1]
    end)
end

function St.unloadAll(s)
    for key, r in pairs(St.live) do
        if r.uid then DDS.ALife.purge(r.uid, "dds_settlement_unload") end
    end
    St.live = {}
    if s then s.residentUids = nil end
end

function St.tick()
    local now = DDS.nowMs()
    if now - St.lastMs < 3000 then return end
    St.lastMs = now
    local s = saga()
    if s == nil or s.home == nil or not DDS.ALife.available() then return end
    if not St.booted then
        -- Residents saved before a restart: clear them, they respawn fresh.
        St.booted = true
        for _, uid in pairs(s.residentUids or {}) do DDS.ALife.purge(uid, "dds_settlement_restart") end
        s.residentUids = nil
    end
    if s.ended then return St.unloadAll(s) end
    local player, d = nearestPlayer(s.home.x, s.home.y)
    if player == nil or d > St.UNLOAD then return St.unloadAll(s) end

    local wanted = {}
    for _, r in ipairs(St.roster(s)) do
        wanted[r.key] = r
        local suppressed = St.suppressed and St.suppressed[r.key] and St.suppressed[r.key] > now
        local live = St.live[r.key]
        if live and DDS.ALife.actorState(live.uid) ~= "alive" then
            St.live[r.key] = nil
            live = nil
        end
        if live == nil and not suppressed and d <= St.LOAD and DDS.Sites.squareLoaded(r.post.x, r.post.y, r.post.z) then
            spawnResident(s, r, player)
        end
    end
    -- People who left the story (died, exiled...) leave the settlement too.
    for key, r in pairs(St.live) do
        if wanted[key] == nil then
            DDS.ALife.purge(r.uid, "dds_settlement_gone")
            St.live[key] = nil
        end
    end
    -- Fight alongside whoever is close.
    for _, r in pairs(St.live) do
        local p, pd = nearestPlayer(r.post.x, r.post.y)
        DDS.ALife.assist(r.uid, r.post, pd <= St.ASSIST and p or nil, St.ASSIST)
    end
end

return St
