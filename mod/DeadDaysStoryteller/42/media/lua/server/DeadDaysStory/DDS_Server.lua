-- Server glue: events, ticking, client commands and per-player sync.

require "DeadDaysStory/DDS_Core"
require "DeadDaysStory/DDS_State"
require "DeadDaysStory/DDS_ALife"
require "DeadDaysStory/DDS_Factions"
require "DeadDaysStory/DDS_Effects"
require "DeadDaysStory/DDS_Dialogue"
require "DeadDaysStory/DDS_Party"
require "DeadDaysStory/DDS_Quests"
require "DeadDaysStory/DDS_Saga"
require "DeadDaysStory/DDS_Buddies"
require "DeadDaysStory/DDS_Director"
require "DeadDaysStory/DDS_StoryKit"
require "DeadDaysStory/Story/DDS_Act1"
require "DeadDaysStory/Story/DDS_Act2"
require "DeadDaysStory/Story/DDS_Act3"
require "DeadDaysStory/Story/DDS_Act4"
require "DeadDaysStory/Story/DDS_Side"
require "DeadDaysStory/Story/DDS_Loyalty"
require "DeadDaysStory/DDS_Convoys"
require "DeadDaysStory/DDS_Settlement"
require "DeadDaysStory/DDS_Kits"

DDS.Server = DDS.Server or { dirty = {}, lastFlushMs = 0, lastTickMs = 0, started = false }
local Srv = DDS.Server

-- Extension points for add-on mods (e.g. a server's own features):
--   DDS.Server.addTicker(name, fn)   fn() runs once a second on the server
--   DDS.Server.addAdminOp(op, fn)    fn(player, args) for admin commands
Srv.tickers = Srv.tickers or {}
Srv.adminOps = Srv.adminOps or {}
function Srv.addTicker(name, fn) Srv.tickers[name] = fn end
function Srv.addAdminOp(op, fn) Srv.adminOps[op] = fn end

---------------------------------------------------------------------------
-- Notifications and sync
---------------------------------------------------------------------------

function Srv.notify(username, text, tone)
    if username == nil or text == nil then return end
    text = DDS.Text.render(text, {})
    local ps = DDS.State.player(username)
    ps.feed = ps.feed or {}
    DDS.push(ps.feed, { day = DDS.day(), hour = DDS.hourOfDay(), text = text, tone = tone or "info" }, 40)
    local player = DDS.playerByName(username)
    if player then DDS.Net.toPlayer(player, "toast", { text = text, tone = tone or "info" }) end
end

function Srv.markDirty(username)
    if username == nil then return end
    Srv.dirty[username] = true
    -- Faction mates see shared missions change too.
    local party = DDS.Party and DDS.Party.of(username) or nil
    if party then
        for _, p in ipairs(DDS.Party.online(party)) do Srv.dirty[DDS.username(p)] = true end
    end
end

local function isAdmin(player)
    if DDS.isSP() then return true end
    local level = ""
    pcall(function() level = string.lower(tostring(player:getAccessLevel() or "")) end)
    if level == "admin" then return true end
    local ok, role = pcall(function() return player:getRole() end)
    if ok and role then
        local yes = false
        pcall(function() yes = role:hasCapability(Capability.ManipulateZombie) == true end)
        if yes then return true end
    end
    return false
end
Srv.isAdmin = isAdmin

function Srv.buildView(username)
    local ps = DDS.State.player(username)
    local player = DDS.playerByName(username)
    local active, offered, closed = {}, {}, {}
    for i = #ps.order, 1, -1 do
        local q = ps.quests[ps.order[i]]
        if q then
            if q.status == "active" then active[#active + 1] = DDS.Quests.view(q, player)
            elseif q.status == "offered" then offered[#offered + 1] = DDS.Quests.view(q, player)
            elseif #closed < 15 then
                closed[#closed + 1] = { id = q.id, title = q.title, status = q.status, arc = q.arc, takenBy = q.takenBy }
            end
        end
    end
    -- Missions shared by the player's faction.
    local party = DDS.Party and DDS.Party.of(username) or nil
    if party then
        for owner, ops in pairs(DDS.State.world().players) do
            if owner ~= username then
                for _, q in pairs(ops.quests or {}) do
                    if q.status == "active" and q.party == party then
                        local v = DDS.Quests.view(q, player)
                        v.shared = true
                        active[#active + 1] = v
                    end
                end
            end
        end
    end
    local feed = {}
    for i = #(ps.feed or {}), math.max(1, #(ps.feed or {}) - 12), -1 do feed[#feed + 1] = ps.feed[i] end
    return {
        day = DDS.day(), hour = DDS.hourOfDay(),
        saga = DDS.Saga.view(username),
        active = active, offered = offered, closed = closed,
        tracked = ps.tracked,
        calls = DDS.Dialogue.pendingCalls(username),
        factions = DDS.Factions.view(ps),
        buddies = DDS.Buddies.view(username),
        daily = { streak = ps.streak or 0, done = ps.dailyDoneToday or 0, total = #(ps.daily and ps.daily.ids or {}) },
        stats = ps.stats, feed = feed,
        admin = player and isAdmin(player) or false,
        alife = DDS.ALife.available(),
    }
end

function Srv.flush(force)
    local now = DDS.nowMs()
    if not force and now - Srv.lastFlushMs < 750 then return end
    Srv.lastFlushMs = now
    for username in pairs(Srv.dirty) do
        local player = DDS.playerByName(username)
        if player then
            local ok, view = pcall(Srv.buildView, username)
            if ok then DDS.Net.toPlayer(player, "sync", view)
            else DDS.log("view failed for " .. username .. ": " .. tostring(view)) end
        end
    end
    Srv.dirty = {}
end

---------------------------------------------------------------------------
-- Client commands
---------------------------------------------------------------------------

local On = DDS.Net.onServer
local rate = {}

local function limited(player, ms)
    local key = DDS.username(player)
    local now = DDS.nowMs()
    if rate[key] and now - rate[key] < (ms or 200) then return true end
    rate[key] = now
    return false
end

-- After a reconnect, nothing should be left waiting on a conversation that no
-- longer exists: reopen pending debriefs and re-queue lost radio objectives.
function Srv.recover(username)
    if DDS.Dialogue.sessions[username] then return DDS.Dialogue.resend(username) end
    local ps = DDS.State.player(username)
    for _, q in ipairs(DDS.Quests.list(username, function(q) return q.status == "active" end)) do
        local step = q.steps[q.current]
        if q.awaitingDialogue and step and step.dialogue then
            DDS.Dialogue.start(username, step.dialogue, { questId = q.id, onEnd = true })
            return
        end
        for _, obj in ipairs(step and step.objectives or {}) do
            if obj.kind == "talk" and obj.radio and not obj.done then
                local queued = false
                for _, call in ipairs(ps.calls or {}) do
                    if call.questId == q.id and call.vars and call.vars.objIndex == obj.index then queued = true end
                end
                if not queued then
                    DDS.Dialogue.queueCall(username, obj.tree, obj.from, q.id, { objIndex = obj.index, stepId = step.id })
                end
            end
        end
    end
end

On("hello", function(player, args)
    local username = DDS.username(player)
    DDS.Saga.ensure(player)
    DDS.Saga.onboard(username, DDS.Saga.INTRO_DELAY_MS)
    if DDS.Kits then
        local okK, errK = pcall(DDS.Kits.onHello, player)
        if not okK then DDS.log("starting kit: " .. tostring(errK)) end
    end
    DDS.Saga.unlock()
    DDS.Saga.offerChapters(username)
    DDS.Factions.syncAll(username)
    Srv.recover(username)
    Srv.markDirty(username)
    Srv.flush(true)
end)

On("requestSync", function(player) Srv.markDirty(DDS.username(player)) end)

On("accept", function(player, args)
    if limited(player) then return end
    DDS.Quests.accept(DDS.username(player), args.id, args.buddyId)
end)

On("decline", function(player, args) DDS.Quests.decline(DDS.username(player), args.id) end)
On("abandon", function(player, args) DDS.Quests.abandon(DDS.username(player), args.id) end)

On("track", function(player, args)
    local ps = DDS.State.playerFor(player)
    ps.tracked = args.id
    Srv.markDirty(DDS.username(player))
end)

On("answer", function(player, args)
    if limited(player) then return end
    DDS.Dialogue.answer(DDS.username(player), args.id)
end)

On("choose", function(player, args)
    if limited(player, 150) then return end
    DDS.Dialogue.choose(DDS.username(player), args.sessionId, args.index)
end)

On("dialogueCancel", function(player) DDS.Dialogue.cancel(DDS.username(player)) end)

On("interact", function(player, args)
    if limited(player, 300) then return end
    DDS.Quests.interact(player, args)
end)

On("handin", function(player, args)
    if limited(player, 500) then return end
    DDS.Quests.handInRemote(player, args)
end)

On("buddy", function(player, args)
    if limited(player, 300) then return end
    local username = DDS.username(player)
    local B = DDS.Buddies
    if args.op == "call" then B.call(username)
    elseif args.op == "wait" then B.waitHere(username)
    elseif args.op == "dismiss" then B.dismiss(username)
    elseif args.op == "select" then B.select(username, args.id) end
    Srv.markDirty(username)
end)

On("admin", function(player, args)
    if not isAdmin(player) then return end
    local username = DDS.username(player)
    local op = args.op
    if op == "offer" and args.templateId then
        local q, why = DDS.Quests.offerTemplate(username, args.templateId, args.overrides)
        Srv.notify(username, q and ("Offered " .. q.title) or ("Could not build: " .. tostring(why)), "info")
    elseif op == "newSaga" then
        local w = DDS.State.world()
        if w.saga then w.saga.ended = true; w.saga.nextSagaHours = 0 end
        DDS.Saga.ensure(player)
        for _, p in ipairs(DDS.onlinePlayers()) do
            DDS.State.player(DDS.username(p)).flags = {}
            DDS.Saga.onboard(DDS.username(p))
            Srv.markDirty(DDS.username(p))
        end
        Srv.notify(username, "New saga generated.", "info")
    elseif op == "advance" then
        DDS.Saga.advance({ username = username, player = player })
    elseif op == "unlock" then
        local s = DDS.State.world().saga
        if s then
            for id, def in pairs(DDS.Saga.chapters) do
                if def.act == s.act and (def.cond == nil or def.cond(s))
                        and (s.chapters[id] == nil or s.chapters[id].state == "locked") then
                    s.chapters[id] = { state = "available" }
                end
            end
            DDS.Saga.offerChapters(username)
        end
    elseif op == "lead" then
        local id = DDS.Director.pickSide(username, DDS.State.player(username))
        if id then DDS.Quests.offerTemplate(username, id) end
    elseif op == "buddy" then
        DDS.Buddies.recruit(username, "starter", { username = username, player = player })
    elseif Srv.adminOps[op] then
        local ok, err = pcall(Srv.adminOps[op], player, args)
        if not ok then DDS.log("admin op " .. tostring(op) .. " failed: " .. tostring(err)) end
    elseif op == "exportVoices" then
        local ok, n = DDS.Dialogue.exportVoiceLines()
        Srv.notify(username, ok and ("Exported " .. tostring(n) .. " voice lines to Zomboid/Lua.") or "Voice export failed.", "info")
    elseif op == "secrets" then
        local s = DDS.State.world().saga
        if s then
            local list = {}
            for id in pairs(s.twists) do list[#list + 1] = id end
            Srv.notify(username, "Twists this saga: " .. table.concat(list, ", ") .. ". Antagonist: " .. s.roles.antagonist.name
                .. ". Military: " .. s.roles.military.name .. ". Community: " .. s.roles.community.name, "info")
        end
    end
    Srv.markDirty(username)
end)

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

function Srv.start()
    if Srv.started then return end
    Srv.started = true
    DDS.State.load()
    DDS.ALife.installHooks()
    DDS.ALife.onKill(function(playerOrKey, actor)
        local ok, err = pcall(DDS.Quests.onActorKilled, playerOrKey, actor)
        if not ok then DDS.log("kill hook: " .. tostring(err)) end
    end)
    local templates = 0
    for _ in pairs(DDS.Quests.templates) do templates = templates + 1 end
    local okV, errV = pcall(DDS.Dialogue.exportVoiceLines)
    if not okV then DDS.log("voice export failed: " .. tostring(errV)) end
    DDS.log("started v" .. DDS.VERSION .. " - " .. templates .. " mission templates, " .. #DDS.Saga.chapterOrder
        .. " story chapters, A-Life " .. (DDS.ALife.present() and "present" or "missing"))
end

local function onTick()
    if not Srv.started then return end
    local now = DDS.nowMs()
    if now - Srv.lastTickMs >= 1000 then
        Srv.lastTickMs = now
        if not DDS.ALife.wrapped then DDS.ALife.installHooks() end
        for _, player in ipairs(DDS.onlinePlayers()) do
            local username = DDS.username(player)
            local ok, err = pcall(DDS.Quests.tickPlayer, username, player)
            if not ok then DDS.log("quest tick: " .. tostring(err)) end
            ok, err = pcall(DDS.Buddies.tick, username, player)
            if not ok then DDS.log("buddy tick: " .. tostring(err)) end
        end
        local online = {}
        for _, p in ipairs(DDS.onlinePlayers()) do online[DDS.username(p)] = true end
        local okP, errP = pcall(DDS.Quests.tickShared, online)
        if not okP then DDS.log("shared tick: " .. tostring(errP)) end
        local okI, errI = pcall(DDS.Saga.tickIntro)
        if not okI then DDS.log("intro tick: " .. tostring(errI)) end
        for name, fn in pairs(Srv.tickers) do
            local okT, errT = pcall(fn)
            if not okT then DDS.log("ticker " .. name .. ": " .. tostring(errT)) end
        end
        if DDS.Convoys then pcall(DDS.Convoys.tick) end
        if DDS.Settlement then
            local okS, errS = pcall(DDS.Settlement.tick)
            if not okS then DDS.log("settlement tick: " .. tostring(errS)) end
        end
    end
    Srv.flush(false)
end

if DDS.isAuthority() and not Srv.registered then
    Srv.registered = true
    Events.OnInitGlobalModData.Add(DDS.guard("init", function() DDS.State.load() end))
    Events.OnServerStarted.Add(DDS.guard("start", Srv.start))
    Events.OnGameStart.Add(DDS.guard("start", Srv.start))
    Events.OnTick.Add(DDS.guard("tick", onTick))
    Events.EveryTenMinutes.Add(DDS.guard("director", function()
        if not Srv.started then return end
        DDS.Director.tick()
    end))
    Events.EveryHours.Add(DDS.guard("hourly", function()
        if not Srv.started then return end
        DDS.Saga.hourly()
        for _, p in ipairs(DDS.onlinePlayers()) do Srv.markDirty(DDS.username(p)) end
        -- OnSave doesn't fire on a dedicated server, so mirror the story hourly.
        DDS.State.writeBackup()
    end))
    Events.OnZombieDead.Add(DDS.guard("zombieDead", function(zombie)
        if Srv.started then DDS.Quests.onZombieDead(zombie) end
    end))
    if Events.OnSave then Events.OnSave.Add(DDS.guard("save", DDS.State.writeBackup)) end
end

return Srv
