-- The story director. Paces the day for each survivor: a morning report,
-- daily ops, fresh leads when things go quiet, incidents when they go too
-- quiet, and consequences that come due. Reads the world's power balance so
-- a strong warlord means raids and a weak settlement means calls for help.

require "DeadDaysStory/DDS_Core"
require "DeadDaysStory/DDS_State"
require "DeadDaysStory/DDS_Quests"
require "DeadDaysStory/DDS_Saga"

DDS.Director = DDS.Director or {}
local Dir = DDS.Director

Dir.MAX_SIDE = 4
Dir.LEAD_GAP_HOURS = 3
Dir.DAILY_COUNT = 3
Dir.dailyPool = { "daily_infected", "daily_scavenge", "daily_patrol", "daily_hunt", "daily_check" }

local function sandbox()
    return (SandboxVars and SandboxVars.DeadDaysStory) or {}
end

local function recent(ps, templateId, n)
    local h = ps.history or {}
    for i = #h, math.max(1, #h - (n or 4) + 1), -1 do
        if h[i] == templateId then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Morning: report + daily ops
---------------------------------------------------------------------------

function Dir.morning(username, ps)
    local day = DDS.day()
    if (ps.daily.day or 0) == day or DDS.hourOfDay() < 6 then return end
    -- Streak bookkeeping for yesterday.
    if (ps.dailyDoneToday or 0) >= Dir.DAILY_COUNT then ps.streak = (ps.streak or 0) + 1
    elseif ps.daily.day ~= 0 then ps.streak = 0 end
    ps.dailyDoneToday = 0
    -- Retire yesterday's dailies.
    for _, q in ipairs(DDS.Quests.list(username, function(q) return q.arc == "daily" and (q.status == "offered" or q.status == "active") end)) do
        DDS.Quests.retire(username, q, "expired")
    end
    ps.daily = { day = day, ids = {} }
    local rng = DDS.rng(DDS.freshSeed())
    local pool = DDS.copy(Dir.dailyPool)
    rng:shuffle(pool)
    local made = 0
    for _, id in ipairs(pool) do
        if made >= (sandbox().DailyOps or Dir.DAILY_COUNT) then break end
        local q = DDS.Quests.build(username, id)
        if q then
            if (ps.streak or 0) >= 3 and q.reward then
                q.reward.xp = math.floor((q.reward.xp or 0) * 1.5)
                q.rewardText = DDS.Items.describe(q.reward)
            end
            DDS.Quests.store(username, q)
            ps.daily.ids[#ps.daily.ids + 1] = q.id
            made = made + 1
        end
    end
    -- The morning report: a summary of the world, in the voice of the radio.
    local w = DDS.State.world()
    local lines = {}
    for i = #w.chronicle, math.max(1, #w.chronicle - 2), -1 do
        if w.chronicle[i].day >= day - 1 then lines[#lines + 1] = w.chronicle[i].text end
    end
    local s = w.saga
    local header = "Day " .. day .. (s and (" - " .. s.title .. ", Act " .. s.act) or "")
    DDS.Server.notify(username, header .. ". " .. (#lines > 0 and table.concat(lines, " ") or "A quiet night. Don't trust it.")
        .. " Daily ops are posted." .. ((ps.streak or 0) >= 3 and (" Streak: " .. ps.streak .. " days (bonus XP).") or ""), "morning")
end

---------------------------------------------------------------------------
-- Leads
---------------------------------------------------------------------------

function Dir.pickSide(username, ps)
    local ctx = { username = username, saga = DDS.State.world().saga, ps = ps }
    local candidates = {}
    local chains = DDS.Quests.countLive(username, "chain")
    for _, id in ipairs(DDS.Quests.order) do
        local t = DDS.Quests.templates[id]
        local arc = t.arc or "side"
        if (arc == "side" or arc == "chain") and not recent(ps, id, 4) and not (arc == "chain" and chains > 0) then
            local ok, w = pcall(t.weight or function() return 5 end, ctx)
            if ok and (w or 0) > 0 then candidates[#candidates + 1] = { id = id, w = w } end
        end
    end
    local rng = DDS.rng(DDS.freshSeed())
    local pick = rng:weighted(candidates, function(c) return c.w end)
    return pick and pick.id or nil
end

function Dir.leads(username, ps)
    local live = DDS.Quests.countLive(username, "side") + DDS.Quests.countLive(username, "chain")
        + DDS.Quests.countLive(username, "incident")
    if live >= (sandbox().MaxLeads or Dir.MAX_SIDE) then return end
    if DDS.nowHours() - (ps.lastLeadHours or -100) < Dir.LEAD_GAP_HOURS then return end
    for _ = 1, 3 do
        local id = Dir.pickSide(username, ps)
        if id == nil then return end
        local q = DDS.Quests.offerTemplate(username, id)
        if q then
            ps.lastLeadHours = DDS.nowHours()
            return
        end
    end
end

---------------------------------------------------------------------------
-- Incidents and pressure
---------------------------------------------------------------------------

function Dir.incidents(username, ps, player)
    local now = DDS.nowHours()
    ps.tension = DDS.clamp((ps.tension or 10) - 1, 0, 100)
    if now - (ps.lastIncidentHours or -100) < 8 then return end
    local s = DDS.State.world().saga
    local roll = ZombRand(100)
    local rate = sandbox().IncidentRate or 20
    if ps.tension > 60 or roll >= rate then return end
    ps.lastIncidentHours = now
    local raidPower = s and s.power.antagonist or 50
    if s and raidPower >= 70 and ZombRand(100) < 40 and (s.choices.side ~= "warlord") then
        DDS.Server.notify(username, "Engines on the road. " .. s.roles.antagonist.name .. " are hunting this stretch.", "danger")
        DDS.Quests.ambush(username, "antagonist", 3 + math.floor((raidPower - 70) / 10))
        ps.tension = ps.tension + 25
    elseif DDS.Quests.countLive(username, "incident") == 0 then
        DDS.Quests.offerTemplate(username, "side_distress")
    end
end

function Dir.events()
    for _, event in ipairs(DDS.State.dueEvents()) do
        local data = event.data or {}
        local username = data.username
        local player = username and DDS.playerByName(username) or nil
        if event.kind == "revenge" then
            if player then
                DDS.Server.notify(username, "[[Somebody remembers what you did.|They found you.|Revenge has a long memory.]]", "danger")
                DDS.Quests.ambush(username, data.role or "antagonist", data.count or 3)
            else
                DDS.State.schedule(2, event.kind, data)
            end
        elseif event.kind == "offer" and username then
            DDS.Quests.offerTemplate(username, data.templateId, data.overrides)
        elseif event.kind == "chronicle" then
            DDS.State.chronicle(data.text, data.kindTag or "event")
        end
    end
end

-- Delayed radio calls: announce when they come due.
function Dir.calls(username, ps)
    local now = DDS.nowHours()
    for _, call in ipairs(ps.calls or {}) do
        if not call.announced and (call.atHours or 0) <= now then
            call.announced = true
            DDS.Server.notify(username, "Incoming radio: " .. tostring(call.from) .. " (answer it from the Journal)", "radio")
            DDS.Server.markDirty(username)
        end
    end
end

-- Everyone gets a partner once they've found the settlement.
function Dir.starterBuddy(username, ps)
    if ps.flags.starterBuddy then return end
    local s = DDS.State.world().saga
    if s == nil or not ps.met.contact then return end
    local done = s.chapters and s.chapters.a1_voices and s.chapters.a1_voices.state == "done"
    if not done then return end
    ps.flags.starterBuddy = true
    if not DDS.isEmpty(ps.buddies) then return end
    DDS.Buddies.recruit(username, "starter", { username = username, player = DDS.playerByName(username) })
end

---------------------------------------------------------------------------
-- Heartbeats
---------------------------------------------------------------------------

function Dir.tick()
    local players = DDS.onlinePlayers()
    if #players == 0 then return end
    DDS.Saga.ensure(players[1])
    Dir.events()
    for _, player in ipairs(players) do
        local username = DDS.username(player)
        local ps = DDS.State.player(username)
        local ok, err = pcall(function()
            DDS.Saga.onboard(username)
            Dir.morning(username, ps)
            Dir.calls(username, ps)
            Dir.starterBuddy(username, ps)
            Dir.leads(username, ps)
            Dir.incidents(username, ps, player)
        end)
        if not ok then DDS.log("director tick failed for " .. username .. ": " .. tostring(err)) end
    end
    DDS.Quests.sweepCleanup()
end

function Dir.onQuestClosed(username, quest, success)
    local ps = DDS.State.player(username)
    if success and (quest.arc == "side" or quest.arc == "chain" or quest.arc == "incident") then
        DDS.Saga.noteSideDone()
        -- Side work moves the needle on the saga's power balance a little.
        DDS.Factions.shiftPower("community", 1)
    end
    if not success then ps.tension = DDS.clamp((ps.tension or 0) + 10, 0, 100) end
end

return Dir
