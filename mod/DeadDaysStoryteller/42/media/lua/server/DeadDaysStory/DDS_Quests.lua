-- Mission engine. A quest is plain data: steps of objectives, each objective
-- a kind the engine knows how to watch. Templates (content files) build the
-- data; this file runs it.
--
-- Objective kinds:
--   reach     reach a point                      eliminate  kill a spawned A-Life squad
--   captive   free a spawned prisoner            interact   timed action at a point
--   lock      pick / pry / key a story lock      search     find an item at a point
--   retrieve  pick up a placed item              handin     hand items over (point or radio drop)
--   hold      survive waves at a point           talk       conversation (in person or radio)
--   kills     kill N of a faction anywhere       infected   kill N zombies (optionally near a point)
--   wait      let time pass (long-running arcs)  sabotage   cut an A-Life outpost's radio
--   npc       a friendly NPC stands at a point (scenery for talk objectives)

require "DeadDaysStory/DDS_Core"
require "DeadDaysStory/DDS_State"
require "DeadDaysStory/DDS_ALife"
require "DeadDaysStory/DDS_Sites"
require "DeadDaysStory/DDS_Effects"
require "DeadDaysStory/DDS_Dialogue"
require "DeadDaysStory/DDS_Items"

DDS.Quests = DDS.Quests or { templates = {}, order = {} }
local Q = DDS.Quests

Q.SPAWN_TRIGGER = 85      -- tiles: spawn a site's people when the owner gets this close
Q.INTERACT_RANGE = 3.5
Q.MAX_SIDE = 4            -- offered + active side work per player

---------------------------------------------------------------------------
-- Templates
---------------------------------------------------------------------------

function Q.define(template)
    if Q.templates[template.id] == nil then Q.order[#Q.order + 1] = template.id end
    Q.templates[template.id] = template
    return template
end

-- Authoring helpers --------------------------------------------------------

Q.B = {}
local B = Q.B

local function pt(at)
    if at == nil then return nil end
    return { x = math.floor(at.x), y = math.floor(at.y), z = math.floor(at.z or 0) }
end

function B.reach(text, at, radius, extra)
    local o = { kind = "reach", text = text, at = pt(at), radius = radius or 10 }
    for k, v in pairs(extra or {}) do o[k] = v end
    return o
end
function B.eliminate(text, factionId, count, at, extra)
    local o = { kind = "eliminate", text = text, at = pt(at), factionId = factionId, count = count or 3,
        mode = "guard", state = "pending" }
    for k, v in pairs(extra or {}) do o[k] = v end
    return o
end
function B.captive(text, factionId, name, at, extra)
    local o = { kind = "captive", text = text, at = pt(at), factionId = factionId, name = name, state = "pending",
        label = "Free " .. tostring(name) }
    for k, v in pairs(extra or {}) do o[k] = v end
    return o
end
function B.interact(text, label, at, extra)
    local o = { kind = "interact", text = text, label = label, at = pt(at), duration = 120 }
    for k, v in pairs(extra or {}) do o[k] = v end
    return o
end
function B.lock(text, label, at, extra)
    local o = { kind = "lock", text = text, label = label or "Locked door", at = pt(at), difficulty = 0.4 }
    for k, v in pairs(extra or {}) do o[k] = v end
    return o
end
function B.search(text, label, at, item, extra)
    local o = { kind = "search", text = text, label = label, at = pt(at), item = item, duration = 90 }
    for k, v in pairs(extra or {}) do o[k] = v end
    return o
end
function B.retrieve(text, at, itemType, itemName, extra)
    local o = { kind = "retrieve", text = text, at = pt(at), itemType = itemType, itemName = itemName, state = "pending" }
    for k, v in pairs(extra or {}) do o[k] = v end
    return o
end
-- items: { { type = "Base.Bandage", count = 4 } } or { { quest = true } }
function B.handin(text, items, at, extra)
    local o = { kind = "handin", text = text, items = items, at = pt(at), label = "Hand over" }
    for k, v in pairs(extra or {}) do o[k] = v end
    return o
end
function B.hold(text, at, seconds, factionId, extra)
    local o = { kind = "hold", text = text, at = pt(at), seconds = seconds or 120, factionId = factionId,
        radius = 22, waves = 2, state = "pending" }
    for k, v in pairs(extra or {}) do o[k] = v end
    return o
end
function B.talk(text, tree, at, extra)
    local o = { kind = "talk", text = text, tree = tree, at = pt(at), label = "Talk" }
    for k, v in pairs(extra or {}) do o[k] = v end
    return o
end
function B.radio(text, tree, from, extra)
    local o = { kind = "talk", text = text, tree = tree, radio = true, from = from }
    for k, v in pairs(extra or {}) do o[k] = v end
    return o
end
function B.kills(text, factionId, count, extra)
    local o = { kind = "kills", text = text, factionId = factionId, count = count or 3, progress = 0 }
    for k, v in pairs(extra or {}) do o[k] = v end
    return o
end
function B.infected(text, count, at, radius, extra)
    local o = { kind = "infected", text = text, count = count or 20, at = pt(at), radius = radius, progress = 0 }
    for k, v in pairs(extra or {}) do o[k] = v end
    return o
end
function B.wait(text, hours, extra)
    local o = { kind = "wait", text = text, hours = hours or 12 }
    for k, v in pairs(extra or {}) do o[k] = v end
    return o
end
function B.sabotage(text, outpost, extra)
    local radio = outpost.radio or { x = outpost.x, y = outpost.y, z = 0 }
    local o = { kind = "sabotage", text = text, at = pt(radio), siteId = outpost.id, label = "Cut the radio",
        duration = 160 }
    for k, v in pairs(extra or {}) do o[k] = v end
    return o
end
function B.npc(factionId, name, at, extra)
    local o = { kind = "npc", text = "", optional = true, hidden = true, factionId = factionId, name = name,
        at = pt(at), state = "pending" }
    for k, v in pairs(extra or {}) do o[k] = v end
    return o
end
-- A friendly squad that fights alongside the player (scenery, never blocks).
function B.allies(factionId, count, at, extra)
    local o = { kind = "allies", text = "", optional = true, hidden = true, factionId = factionId, count = count or 3,
        at = pt(at), friendly = true, mode = "guard", state = "pending" }
    for k, v in pairs(extra or {}) do o[k] = v end
    return o
end
function B.step(id, title, objectives, extra)
    local s = { id = id, title = title, objectives = objectives or {} }
    for k, v in pairs(extra or {}) do s[k] = v end
    return s
end

---------------------------------------------------------------------------
-- Lookup
---------------------------------------------------------------------------

-- Quest ids are unique world-wide, so a faction-mate's shared mission is
-- found too. Lifecycle code always works on the owner's record.
function Q.get(username, id)
    local ps = DDS.State.player(username)
    if ps.quests[id] then return ps.quests[id] end
    for _, other in pairs(DDS.State.world().players) do
        if other.quests and other.quests[id] then return other.quests[id] end
    end
    return nil
end

local function ownerOf(quest, username)
    return (quest and quest.owner) or username
end
Q.ownerOf = ownerOf

-- Shared missions: the faction's online members (owner included if online).
function Q.partyPlayers(quest)
    local list, seen = {}, {}
    local owner = quest and quest.owner and DDS.playerByName(quest.owner) or nil
    if owner then list[1] = owner; seen[quest.owner] = true end
    if quest and quest.party and DDS.Party then
        for _, p in ipairs(DDS.Party.online(quest.party)) do
            local n = DDS.username(p)
            if not seen[n] then seen[n] = true; list[#list + 1] = p end
        end
    end
    return list
end

-- Who to measure an objective against: the member closest to it.
function Q.actorFor(quest, obj, fallback)
    local players = Q.partyPlayers(quest)
    if #players == 0 then return fallback end
    if obj == nil or obj.at == nil or #players == 1 then return fallback or players[1] end
    local best, bestD
    for _, p in ipairs(players) do
        local d = DDS.dist(p:getX(), p:getY(), obj.at.x, obj.at.y)
        if bestD == nil or d < bestD then best, bestD = p, d end
    end
    return best
end

function Q.notifyParty(quest, text, tone)
    local sent = {}
    if quest.owner then DDS.Server.notify(quest.owner, text, tone); sent[quest.owner] = true end
    if quest.party and DDS.Party then
        for _, name in ipairs(DDS.Party.members(quest.party)) do
            if not sent[name] then sent[name] = true; DDS.Server.notify(name, text, tone) end
        end
    end
end

function Q.list(username, filter)
    local ps = DDS.State.player(username)
    local result = {}
    for _, id in ipairs(ps.order) do
        local q = ps.quests[id]
        if q and (filter == nil or filter(q)) then result[#result + 1] = q end
    end
    return result
end

function Q.countLive(username, arc)
    local n = 0
    for _, q in ipairs(Q.list(username)) do
        if (q.status == "offered" or q.status == "active") and (arc == nil or q.arc == arc) then n = n + 1 end
    end
    return n
end

function Q.usedBuildings()
    local used = {}
    for _, ps in pairs(DDS.State.world().players) do
        for _, q in pairs(ps.quests) do
            if (q.status == "offered" or q.status == "active") and q.site and q.site.key then used[q.site.key] = true end
        end
    end
    return used
end

local function ctxFor(username, quest)
    return { username = username, player = DDS.playerByName(username), quest = quest,
        rng = DDS.rng((quest and quest.seed or 1) + DDS.day()) }
end

local function playerXY(player)
    local x, y, z = 0, 0, 0
    pcall(function() x, y, z = player:getX(), player:getY(), player:getZ() end)
    return x, y, z
end

---------------------------------------------------------------------------
-- Creating quests from templates
---------------------------------------------------------------------------

function Q.build(username, templateId, overrides)
    local template = Q.templates[templateId]
    if template == nil then return nil, "unknown_template" end
    local player = DDS.playerByName(username)
    local ps = DDS.State.player(username)
    local x, y = 0, 0
    if player then x, y = playerXY(player) end
    local seed = DDS.freshSeed()
    local ctx = {
        username = username, player = player, ps = ps, rng = DDS.rng(seed),
        saga = DDS.State.world().saga, x = x, y = y, avoid = Q.usedBuildings(), overrides = overrides or {},
    }
    local ok, built = pcall(template.build, ctx)
    if not ok then
        DDS.log("template " .. templateId .. " failed: " .. tostring(built))
        return nil, "build_failed"
    end
    if built == nil then return nil, "not_applicable" end
    local quest = {
        id = DDS.State.newId("q"),
        templateId = templateId,
        arc = built.arc or template.arc or "side",
        title = built.title or "Untitled",
        summary = built.summary or "",
        giver = built.giver,
        giverRole = built.giverRole,
        vars = built.vars or {},
        site = built.site,
        steps = {},
        stepOrder = {},
        current = nil,
        reward = built.reward,
        rewardText = built.reward and DDS.Items.describe(built.reward) or {},
        standingReward = built.standingReward,
        risk = built.risk or 2,
        requiresBuddy = built.requiresBuddy == true,
        buddyId = built.buddyId,
        world = built.world == true,
        status = "offered",
        createdHours = DDS.nowHours(),
        offerExpiresHours = DDS.nowHours() + (built.offerHours or 36),
        deadlineHours = nil,
        deadlineIn = built.deadlineHours,
        seed = seed,
        log = {},
        spawned = {},
        onComplete = built.onComplete,
        onFail = built.onFail,
        onAbandon = built.onAbandon,
        debrief = built.debrief,
        hookCall = built.hookCall,
        tags = built.tags,
    }
    for k, v in pairs(overrides or {}) do
        if k ~= "vars" then quest[k] = v end
    end
    for _, step in ipairs(built.steps or {}) do
        quest.steps[step.id] = step
        quest.stepOrder[#quest.stepOrder + 1] = step.id
        for i, obj in ipairs(step.objectives) do
            obj.index = i
            obj.done = false
            obj.text = DDS.Effects.render(obj.text or "", { username = username, player = player, quest = quest, rng = ctx.rng })
            if obj.label then
                obj.label = DDS.Effects.render(obj.label, { username = username, player = player, quest = quest, rng = ctx.rng })
            end
        end
        if step.title then
            step.title = DDS.Effects.render(step.title, { username = username, player = player, quest = quest, rng = ctx.rng })
        end
    end
    local rctx = { username = username, player = player, quest = quest, rng = ctx.rng }
    quest.title = DDS.Effects.render(quest.title, rctx)
    quest.summary = DDS.Effects.render(quest.summary, rctx)
    if quest.giver then quest.giver = DDS.Effects.render(quest.giver, rctx) end
    return quest
end

function Q.store(username, quest)
    quest.owner = quest.owner or username
    local ps = DDS.State.player(username)
    ps.quests[quest.id] = quest
    ps.order[#ps.order + 1] = quest.id
    ps.history = ps.history or {}
    DDS.push(ps.history, quest.templateId, 12)
    DDS.Server.markDirty(username)
end

function Q.offerTemplate(username, templateId, overrides, autoAccept)
    local quest, why = Q.build(username, templateId, overrides)
    if quest == nil then return nil, why end
    Q.store(username, quest)
    if quest.hookCall then
        DDS.Dialogue.queueCall(username, quest.hookCall.tree, quest.hookCall.from, quest.id, nil, quest.hookCall.delay)
    else
        DDS.Server.notify(username, "New lead: " .. quest.title, "lead")
    end
    if autoAccept then Q.accept(username, quest.id, nil, true) end
    return quest
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function Q.logLine(quest, text)
    DDS.push(quest.log, { day = DDS.day(), text = text }, 30)
end

local function startStep(username, quest, stepId)
    username = ownerOf(quest, username)
    local step = quest.steps[stepId]
    if step == nil then return Q.complete(username, quest) end
    quest.current = stepId
    step.startedHours = DDS.nowHours()
    step.startedMs = DDS.nowMs()
    if step.title then Q.logLine(quest, step.title) end
    local ctx = ctxFor(username, quest)
    if step.onStart then
        local r = DDS.Effects.run(step.onStart, ctx)
        if r.branch then return startStep(username, quest, r.branch) end
    end
    for _, obj in ipairs(step.objectives) do
        if obj.kind == "wait" then
            local hours = obj.hours or 1
            if obj.atHour then hours = (obj.atHour - DDS.hourOfDay()) % 24 end
            obj.untilHours = DDS.nowHours() + math.max(0.25, hours)
        end
        if obj.kind == "talk" and obj.radio and not obj.called then
            obj.called = true
            DDS.Dialogue.queueCall(username, obj.tree, obj.from, quest.id, { objIndex = obj.index, stepId = stepId })
        end
        if obj.kind == "kills" or obj.kind == "infected" then obj.progress = 0 end
    end
    if step.say then Q.notifyParty(quest, DDS.Effects.render(step.say, ctx), "story") end
    DDS.Server.markDirty(username)
end
Q.startStep = startStep

function Q.accept(username, id, buddyId, silent)
    local quest = Q.get(username, id)
    if quest == nil or quest.status ~= "offered" then return false, "not_offered" end
    if quest.requiresBuddy and DDS.Buddies then
        local ok, why = DDS.Buddies.assignForQuest(username, quest, buddyId)
        if not ok then
            DDS.Server.notify(username, why or "This job needs a partner. Recruit or call a buddy first.", "bad")
            return false, "needs_buddy"
        end
    end
    quest.status = "active"
    quest.acceptedHours = DDS.nowHours()
    if quest.deadlineIn then quest.deadlineHours = DDS.nowHours() + quest.deadlineIn end
    local ps = DDS.State.player(username)
    ps.tracked = quest.id
    -- Faction co-op: the mission becomes the faction's.
    if DDS.Party and quest.arc ~= "daily" and quest.arc ~= "loyalty" then
        quest.party = DDS.Party.of(username)
    end
    if quest.world and DDS.Saga then DDS.Saga.claimKeystone(username, quest) end
    if not silent then DDS.Server.notify(username, "Mission accepted: " .. quest.title, "good") end
    if quest.party then
        for _, name in ipairs(DDS.Party.members(quest.party)) do
            if name ~= username then
                DDS.Server.notify(name, username .. " started a shared mission for " .. quest.party .. ": " .. quest.title, "lead")
            end
        end
    end
    startStep(username, quest, quest.stepOrder[1])
    return true
end

function Q.decline(username, id)
    local quest = Q.get(username, id)
    if quest == nil or quest.status ~= "offered" then return end
    if quest.arc == "spine" then
        DDS.Server.notify(username, "This one won't go away by ignoring it.", "bad")
        return
    end
    Q.retire(username, quest, "declined")
end

function Q.abandon(username, id)
    local quest = Q.get(username, id)
    if quest == nil or quest.status ~= "active" then return end
    if quest.owner and quest.owner ~= username then
        DDS.Server.notify(username, "Only " .. quest.owner .. " can drop this shared mission.", "bad")
        return
    end
    if quest.onAbandon then DDS.Effects.run(quest.onAbandon, ctxFor(username, quest)) end
    if quest.arc == "spine" then
        -- The spine cannot be abandoned; it is released for someone else and comes back.
        quest.status = "offered"
        quest.current = nil
        Q.cleanupSpawns(quest)
        if DDS.Saga then DDS.Saga.releaseKeystone(quest) end
        DDS.Server.notify(username, "You step back. The story doesn't.", "bad")
        DDS.Server.markDirty(username)
        return
    end
    Q.fail(username, quest, "abandoned")
end

function Q.retire(username, quest, status)
    username = ownerOf(quest, username)
    quest.status = status
    quest.closedHours = DDS.nowHours()
    Q.cleanupSpawns(quest)
    local ps = DDS.State.player(username)
    if ps.tracked == quest.id then ps.tracked = nil end
    -- Keep the last 40 closed quests for the journal; drop older ones.
    local closed = {}
    for _, qid in ipairs(ps.order) do
        local q = ps.quests[qid]
        if q and q.status ~= "offered" and q.status ~= "active" then closed[#closed + 1] = qid end
    end
    while #closed > 40 do
        local victim = table.remove(closed, 1)
        ps.quests[victim] = nil
        for i, qid in ipairs(ps.order) do if qid == victim then table.remove(ps.order, i); break end end
    end
    DDS.Server.markDirty(username)
end

function Q.complete(username, quest)
    if quest.status ~= "active" then return end
    username = ownerOf(quest, username)
    local ctx = ctxFor(username, quest)
    local ps = DDS.State.player(username)
    if quest.onComplete then DDS.Effects.run(quest.onComplete, ctx) end
    -- Rewards: every online member of the faction, plus anyone standing with
    -- whoever finished it.
    local party = Q.partyPlayers(quest)
    local paid = {}
    for _, p in ipairs(party) do paid[DDS.username(p)] = p end
    local anchor = ctx.player or party[1]
    if anchor then
        local ox, oy = playerXY(anchor)
        for _, p in ipairs(DDS.onlinePlayers()) do
            local px, py = playerXY(p)
            if DDS.dist(ox, oy, px, py) < 40 then paid[DDS.username(p)] = p end
        end
    end
    if quest.reward then
        for name, p in pairs(paid) do
            DDS.Items.grant(p, quest.reward)
            DDS.Server.notify(name, "Reward: " .. table.concat(quest.rewardText or {}, ", "), "good")
        end
    end
    -- Standing moves for the whole faction (offline members too).
    local members = { username }
    if quest.party then members = DDS.Party.members(quest.party) end
    if quest.standingReward then
        for _, name in ipairs(members) do
            for roleOrId, delta in pairs(quest.standingReward) do DDS.Factions.change(name, roleOrId, delta, quest.title) end
        end
    end
    for name in pairs(paid) do
        if name ~= username then
            local mps = DDS.State.player(name)
            mps.stats.completed = (mps.stats.completed or 0) + 1
            DDS.Server.markDirty(name)
        end
    end
    ps.stats.completed = (ps.stats.completed or 0) + 1
    ps.done[quest.templateId] = (ps.done[quest.templateId] or 0) + 1
    ps.tension = DDS.clamp((ps.tension or 0) - 15, 0, 100)
    if quest.arc == "daily" then ps.dailyDoneToday = (ps.dailyDoneToday or 0) + 1 end
    if DDS.Buddies then DDS.Buddies.onQuestDone(username, quest, true) end
    Q.retire(username, quest, "done")
    Q.notifyParty(quest, "Mission complete: " .. quest.title, "complete")
    if DDS.Director then DDS.Director.onQuestClosed(username, quest, true) end
    if quest.world and DDS.Saga then DDS.Saga.onKeystoneDone(username, quest) end
end

function Q.fail(username, quest, reason)
    if quest.status ~= "active" and quest.status ~= "offered" then return end
    username = ownerOf(quest, username)
    local ctx = ctxFor(username, quest)
    if quest.onFail then DDS.Effects.run(quest.onFail, ctx) end
    local ps = DDS.State.player(username)
    ps.stats.failed = (ps.stats.failed or 0) + 1
    if DDS.Buddies then DDS.Buddies.onQuestDone(username, quest, false) end
    if quest.arc == "spine" and DDS.Saga then
        DDS.Saga.onKeystoneFailed(username, quest, reason)
    end
    Q.retire(username, quest, "failed")
    Q.notifyParty(quest, "Mission failed: " .. quest.title .. (reason and (" (" .. reason .. ")") or ""), "bad")
    if DDS.Director then DDS.Director.onQuestClosed(username, quest, false) end
end

-- Spawned actors linger until no player is nearby, then are removed so the
-- world doesn't fill with leftover quest NPCs.
function Q.cleanupSpawns(quest)
    local w = DDS.State.world()
    w.cleanup = w.cleanup or {}
    for _, uid in ipairs(quest.spawned or {}) do
        w.cleanup[#w.cleanup + 1] = { uid = uid, sinceHours = DDS.nowHours() }
    end
    quest.spawned = {}
end

function Q.sweepCleanup()
    local w = DDS.State.world()
    if w.cleanup == nil or #w.cleanup == 0 then return end
    local keep = {}
    local players = DDS.onlinePlayers()
    for _, entry in ipairs(w.cleanup) do
        local state = DDS.ALife.actorState(entry.uid)
        if state == "alive" then
            local pos = DDS.ALife.position(entry.uid)
            local near = false
            if pos then
                for _, p in ipairs(players) do
                    local px, py = playerXY(p)
                    if DDS.dist(px, py, pos.x, pos.y) < 50 then near = true; break end
                end
            end
            if near and DDS.nowHours() - (entry.sinceHours or 0) < 24 then
                keep[#keep + 1] = entry
            else
                DDS.ALife.purge(entry.uid, "dds_cleanup")
            end
        end
    end
    w.cleanup = keep
end

---------------------------------------------------------------------------
-- Spawning helpers
---------------------------------------------------------------------------

local function track(quest, uids)
    for _, uid in ipairs(uids or {}) do quest.spawned[#quest.spawned + 1] = uid end
end

-- Fallback when A-Life is missing: infected stand in for armed people.
local function spawnZombies(at, count, tag)
    local made = 0
    pcall(function()
        local list = addZombiesInOutfit(at.x, at.y, at.z or 0, count, nil, 50)
        if list then
            for i = 0, list:size() - 1 do
                local z = list:get(i)
                if z then z:getModData().DDSTag = tag; made = made + 1 end
            end
        end
    end)
    return made
end

local function trySpawnSquad(username, quest, obj, owner)
    obj.attempts = (obj.attempts or 0) + 1
    obj.nextTryMs = DDS.nowMs() + 15000
    local at = obj.at
    if not DDS.ALife.available() then
        local tag = quest.id .. ":" .. tostring(quest.current) .. ":" .. obj.index
        obj.zombieTag = tag
        obj.zombieTotal = spawnZombies(at, obj.count or 3, tag)
        obj.zombieKilled = 0
        obj.state = "active"
        obj.fallback = true
        return
    end
    obj.state = "spawning"
    local requestId, why = DDS.ALife.spawn(owner, {
        x = at.x, y = at.y, z = at.z, factionId = obj.factionId, count = obj.count or 3,
        mode = obj.mode or "guard", hostile = obj.friendly and false or true,
        stance = obj.friendly and "friendly" or "hostile",
        keepOut = obj.keepOut or 14, radius = obj.patrolRadius or 16, persistent = true,
        holdPost = obj.holdPost, noFlee = obj.noFlee,
        scriptedId = quest.id,
    }, function(uids, outcome)
        if #uids == 0 then
            obj.state = "pending"
            DDS.log("squad spawn settled empty for " .. quest.id .. " reason=" .. tostring(outcome and outcome.reason))
            return
        end
        obj.uids = uids
        obj.total = #uids
        obj.state = "active"
        track(quest, uids)
        if obj.bark then DDS.ALife.say(uids[1], DDS.Effects.render(obj.bark, ctxFor(username, quest)), 30) end
        DDS.Server.markDirty(username)
    end)
    if requestId == nil then
        obj.state = "pending"
        DDS.log("squad spawn rejected for " .. quest.id .. ": " .. tostring(why))
        if obj.attempts >= 4 and obj.friendly then
            obj.state = "skipped"
        elseif obj.attempts >= 4 then
            -- Never soft-lock a story on a spawn failure.
            obj.state = "active"
            obj.fallback = true
            obj.zombieTag = quest.id .. ":" .. tostring(quest.current) .. ":" .. obj.index
            obj.zombieTotal = spawnZombies(at, obj.count or 3, obj.zombieTag)
            obj.zombieKilled = 0
        end
    end
end

-- Is this named person a woman? true/false, or nil when we can't tell (then
-- A-Life picks freely). Checked in order of how sure we are.
function Q.personFemale(quest, obj)
    if obj.female ~= nil then return obj.female == true end
    local s = DDS.State.world().saga
    local cast = s and s.cast or {}
    if obj.castKey and cast[obj.castKey] then return cast[obj.castKey].female == true end
    if obj.role and type(cast[obj.role]) == "table" and cast[obj.role].female ~= nil then
        return cast[obj.role].female == true
    end
    local vr = obj.role and DDS.Dialogue.voiceRoles[obj.role] or nil
    if vr and vr.g then return vr.g == "f" end
    if vr and vr.var then
        local p = quest.vars and quest.vars[vr.var]
        if type(p) == "table" and p.female ~= nil then return p.female == true end
    end
    local name = obj.name and tostring(obj.name) or nil
    if name then
        for _, c in pairs(cast) do
            if type(c) == "table" and c.name == name and c.female ~= nil then return c.female == true end
        end
        for _, p in pairs(quest.vars or {}) do
            if type(p) == "table" and p.name == name and p.female ~= nil then return p.female == true end
        end
        local first = string.match(name, "^(%a+)")
        if first then
            if DDS.contains(DDS.Names.female, first) then return true end
            if DDS.contains(DDS.Names.male, first) then return false end
        end
    end
    return nil
end

local function trySpawnPerson(username, quest, obj, owner, captive)
    obj.attempts = (obj.attempts or 0) + 1
    obj.nextTryMs = DDS.nowMs() + 15000
    if not DDS.ALife.available() then
        obj.state = "active"
        obj.fallback = true
        return
    end
    -- Someone who already lives at the settlement: use them, don't clone them.
    local St = DDS.Settlement
    if not captive and obj.castKey and St then
        if obj.mortal then
            St.release(obj.castKey)
        else
            local uid = St.residentUid(obj.castKey)
            if uid then
                obj.uid, obj.state, obj.adopted = uid, "active", true
                obj.waitingSinceMs = nil
                return
            end
            -- The settlement spawns this person itself; wait for them instead of
            -- making a twin. If they still haven't appeared after a minute, take
            -- them over from the settlement and spawn them here.
            if St.handles(obj.castKey) then
                obj.waitingSinceMs = obj.waitingSinceMs or DDS.nowMs()
                if DDS.nowMs() - obj.waitingSinceMs < 60000 then
                    obj.state = "pending"
                    obj.nextTryMs = DDS.nowMs() + 3000
                    return
                end
                St.release(obj.castKey)
            end
        end
    end
    obj.state = "spawning"
    -- Captives stay put. Everyone else is leashed to their post and free to
    -- fight: when the player is close they move up and help (see evaluate.npc).
    local requestId = DDS.ALife.spawn(owner, {
        x = obj.at.x, y = obj.at.y, z = obj.at.z, factionId = obj.factionId, count = 1,
        mode = "guard", hostile = false, stance = "friendly", keepOut = 8, persistent = true,
        stationary = captive == true, leash = (not captive) and (obj.leash or 18) or nil,
        invulnerable = not obj.mortal, noFlee = true, scriptedId = quest.id, radius = 8,
        female = Q.personFemale(quest, obj), person = obj.name,
    }, function(uids)
        if #uids == 0 then obj.state = "pending"; return end
        obj.uid = uids[1]
        obj.state = "active"
        track(quest, uids)
        if captive and obj.cry then DDS.ALife.say(obj.uid, DDS.Effects.render(obj.cry, ctxFor(username, quest)), 35) end
        DDS.Server.markDirty(username)
    end)
    if requestId == nil then
        obj.state = "pending"
        -- Captives fall back to a point after a few tries; the people you talk
        -- to keep being retried, because the conversation needs a person.
        if captive and obj.attempts >= 4 then obj.state = "active"; obj.fallback = true end
    end
end

-- Hostiles that come for the player (ambushes, counterattacks, consequences).
function Q.ambush(username, roleOrId, count, quest)
    local player = DDS.playerByName(username)
    if player == nil then return false end
    local factionId = DDS.Factions.resolve(roleOrId)
    local x, y, z = playerXY(player)
    local rng = DDS.rng(DDS.freshSeed())
    local spot = DDS.Sites.ring(x, y, 32, 48, rng)
    if not DDS.ALife.available() then
        spawnZombies(spot, (count or 3) * 2, "ambush")
        return true
    end
    DDS.ALife.spawn(player, {
        x = spot.x, y = spot.y, z = 0, factionId = factionId, count = count or 3, mode = "assault",
        hostile = true, stance = "hostile", keepOut = 26, persistent = false, targetUsername = username,
        noFlee = true,
    }, function(uids)
        if quest then track(quest, uids) end
    end)
    return true
end

---------------------------------------------------------------------------
-- Objective evaluation
---------------------------------------------------------------------------

local function near(player, at, radius)
    if at == nil then return false end
    local x, y = playerXY(player)
    return DDS.dist(x, y, at.x, at.y) <= (radius or 10)
end

local function squadState(obj)
    if obj.fallback then
        return (obj.zombieKilled or 0) >= (obj.zombieTotal or 0), (obj.zombieKilled or 0), (obj.zombieTotal or 0)
    end
    if obj.state ~= "active" or obj.uids == nil then return false, 0, obj.count or 0 end
    local dead = 0
    for _, uid in ipairs(obj.uids) do
        local s = DDS.ALife.actorState(uid)
        if s ~= "alive" then dead = dead + 1 end
    end
    return dead >= #obj.uids, dead, #obj.uids
end

local evaluate = {}

evaluate.reach = function(username, quest, obj, owner)
    if near(owner, obj.at, obj.radius) then
        if quest.requiresBuddy and DDS.Buddies and not DDS.Buddies.withPlayer(username, 18) then
            obj.waitingForBuddy = true
            return false
        end
        obj.waitingForBuddy = nil
        return true
    end
    return false
end

evaluate.eliminate = function(username, quest, obj, owner)
    if obj.state == "pending" then
        if (obj.nextTryMs or 0) <= DDS.nowMs() and near(owner, obj.at, obj.trigger or Q.SPAWN_TRIGGER)
                and DDS.Sites.squareLoaded(obj.at.x, obj.at.y, obj.at.z) then
            trySpawnSquad(username, quest, obj, owner)
        end
        return false
    end
    local done, dead, total = squadState(obj)
    obj.progress, obj.total = dead, total
    return done
end

evaluate.captive = function(username, quest, obj, owner)
    if obj.state == "pending" and (obj.nextTryMs or 0) <= DDS.nowMs()
            and near(owner, obj.at, Q.SPAWN_TRIGGER) and DDS.Sites.squareLoaded(obj.at.x, obj.at.y, obj.at.z) then
        trySpawnPerson(username, quest, obj, owner, true)
    end
    if obj.uid and obj.state == "active" and not obj.freed then
        local pos = DDS.ALife.position(obj.uid)
        if pos then obj.live = { x = math.floor(pos.x), y = math.floor(pos.y), z = math.floor(pos.z or 0) } end
        local now = DDS.nowMs()
        if obj.cry and near(owner, obj.live or obj.at, 30) and (obj.lastCryMs or 0) + 25000 < now then
            obj.lastCryMs = now
            DDS.ALife.say(obj.uid, DDS.Effects.render(obj.cries and obj.cries[ZombRand(1, #obj.cries + 1)] or obj.cry,
                ctxFor(username, quest)), 30)
        end
    end
    return obj.freed == true
end

evaluate.npc = function(username, quest, obj, owner)
    if obj.state == "pending" and (obj.nextTryMs or 0) <= DDS.nowMs()
            and near(owner, obj.at, Q.SPAWN_TRIGGER) and DDS.Sites.squareLoaded(obj.at.x, obj.at.y, obj.at.z) then
        trySpawnPerson(username, quest, obj, owner, false)
    end
    -- Someone the story needs alive must always be there: if their body was
    -- removed (settlement unloaded, server restart) or somehow died, bring
    -- them back. Only story-mortal people (obj.mortal) can stay dead.
    if obj.uid and not obj.mortal and DDS.ALife.actorState(obj.uid) ~= "alive" then
        obj.uid, obj.adopted, obj.live = nil, nil, nil
        obj.state = "pending"
        obj.nextTryMs = 0
        obj.attempts = 0
    end
    -- Once per person: a body that doesn't match who they are (spawned before
    -- profiles were matched) is replaced. Settlement residents are fixed by
    -- the settlement itself, which respawns them on every restart.
    if obj.uid and not obj.bodyChecked and not obj.adopted then
        obj.bodyChecked = true
        local want = Q.personFemale(quest, obj)
        local have = DDS.ALife.actorFemale(obj.uid)
        if want ~= nil and have ~= nil and want ~= have then
            DDS.ALife.purge(obj.uid, "dds_wrong_body")
            obj.uid, obj.live = nil, nil
            obj.state = "pending"
            obj.nextTryMs = 0
            obj.attempts = 0
        end
    end
    if obj.uid then
        local pos = DDS.ALife.position(obj.uid)
        if pos then obj.live = { x = math.floor(pos.x), y = math.floor(pos.y), z = math.floor(pos.z or 0) } end
        -- Quest givers fight beside a player who comes close, then go back to their post.
        if not obj.noAssist then
            DDS.ALife.assist(obj.uid, obj.at, near(owner, obj.at, obj.assistRange or 22) and owner or nil, obj.assistRange or 22)
        end
    end
    -- Scenery: optional, never "done", so it keeps spawning/tracking while the step runs.
    return false
end

evaluate.allies = function(username, quest, obj, owner)
    if obj.state == "pending" and (obj.nextTryMs or 0) <= DDS.nowMs() and (obj.attempts or 0) < 4
            and near(owner, obj.at, Q.SPAWN_TRIGGER) and DDS.Sites.squareLoaded(obj.at.x, obj.at.y, obj.at.z) then
        if DDS.ALife.available() then trySpawnSquad(username, quest, obj, owner) else obj.state = "skipped" end
    end
    return false
end

evaluate.retrieve = function(username, quest, obj, owner)
    if obj.state == "pending" and near(owner, obj.at, 60) and DDS.Sites.squareLoaded(obj.at.x, obj.at.y, obj.at.z) then
        local ok, where = DDS.Items.place(obj.at.x, obj.at.y, obj.at.z, obj.itemType, obj.itemName, quest.id, 3)
        if ok then
            obj.state = "placed"
            obj.where = where
        end
    end
    for _, p in ipairs(Q.partyPlayers(quest)) do
        if DDS.Items.questItem(p, quest.id) ~= nil then return true end
    end
    return owner ~= nil and DDS.Items.questItem(owner, quest.id) ~= nil
end

evaluate.hold = function(username, quest, obj, owner)
    local now = DDS.nowMs()
    if obj.state == "pending" then
        if near(owner, obj.at, obj.radius) then
            obj.state = "holding"
            obj.startMs = now
            obj.wavesSent = 0
            Q.notifyParty(quest, DDS.Effects.render(obj.startLine or "Here they come. Hold the line.", ctxFor(username, quest)), "danger")
        end
        return false
    end
    if obj.state == "holding" then
        local elapsed = (now - obj.startMs) / 1000
        obj.remaining = math.max(0, math.floor((obj.seconds or 120) - elapsed))
        local waveEvery = (obj.seconds or 120) / math.max(1, obj.waves or 2)
        if obj.wavesSent < (obj.waves or 2) and elapsed >= obj.wavesSent * waveEvery then
            obj.wavesSent = obj.wavesSent + 1
            if obj.factionId then
                Q.ambush(DDS.username(owner) or username, obj.factionId, obj.waveSize or 3, quest)
            end
            if obj.zombies ~= false then
                local rng = DDS.rng(now)
                local spot = DDS.Sites.ring(obj.at.x, obj.at.y, 28, 40, rng)
                spawnZombies(spot, obj.zombieWave or 6, "hold")
            end
        end
        if not near(owner, obj.at, (obj.radius or 22) * 2.5) then
            obj.awaySince = obj.awaySince or now
            if now - obj.awaySince > 45000 then
                obj.state = "pending"
                obj.awaySince = nil
                Q.notifyParty(quest, "The position was abandoned.", "bad")
                if obj.failOnLeave then Q.fail(username, quest, "position lost") end
            end
        else
            obj.awaySince = nil
        end
        return elapsed >= (obj.seconds or 120)
    end
    return false
end

evaluate.kills = function(username, quest, obj, owner)
    return (obj.progress or 0) >= (obj.count or 1)
end

evaluate.infected = evaluate.kills

evaluate.wait = function(username, quest, obj, owner)
    return DDS.nowHours() >= (obj.untilHours or 0)
end

-- Interaction-driven kinds complete through Q.interact.
evaluate.interact = function() return false end
evaluate.lock = function() return false end
evaluate.search = function() return false end
evaluate.sabotage = function() return false end
evaluate.handin = function() return false end
evaluate.talk = function(username, quest, obj, owner)
    if obj.npcIndex then
        local step = quest.steps[quest.current]
        local npc = step and step.objectives[obj.npcIndex]
        if npc then
            if npc.live then obj.live = npc.live end
            obj.uid = npc.uid
            -- Shot the person you were meant to talk to: the story notices.
            -- (Only possible for story-mortal people; everyone else is
            -- invulnerable and respawned by evaluate.npc.)
            if npc.mortal and npc.uid and DDS.ALife.actorState(npc.uid) == "dead" then
                quest.vars.npcKilled = true
                if obj.onKilled then
                    local r = DDS.Effects.run(obj.onKilled, ctxFor(username, quest))
                    if r.branch then startStep(username, quest, r.branch); return false end
                end
                return true
            end
            Q.approach(quest, obj, owner)
        end
    end
    return false
end

-- The person you're meant to talk to notices you: inside APPROACH_RANGE they
-- walk over, and once they're at your side the conversation opens. If it's
-- closed without finishing, they wait a while before trying again.
Q.APPROACH_RANGE = 30
Q.TALK_RANGE = 4.5  -- A-Life stops a following actor about 3 tiles short
Q.TALK_RETRY_MS = 90000

function Q.approach(quest, obj, owner)
    if obj.uid == nil or owner == nil or obj.done then return end
    local pos = DDS.ALife.position(obj.uid)
    if pos == nil then return end
    local px, py, pz
    pcall(function() px, py, pz = owner:getX(), owner:getY(), owner:getZ() end)
    if px == nil then return end
    local d = DDS.dist(px, py, pos.x, pos.y)
    if d > Q.APPROACH_RANGE then return end
    local talker = DDS.username(owner)
    if d > Q.TALK_RANGE then
        DDS.ALife.follow(obj.uid, px, py, pz)
        return
    end
    local now = DDS.nowMs()
    if DDS.Dialogue.sessions[talker] or (obj.autoTalkAfterMs or 0) > now then return end
    local dead = false
    pcall(function() dead = owner:isDead() end)
    if dead then return end
    obj.autoTalkAfterMs = now + Q.TALK_RETRY_MS
    local step = quest.steps[quest.current]
    DDS.Dialogue.start(talker, obj.tree, { questId = quest.id, vars = { objIndex = obj.index, stepId = step and step.id } })
end

local function stepDone(step)
    for _, obj in ipairs(step.objectives) do
        if not obj.optional and not obj.done then return false end
    end
    return true
end

local function advance(username, quest, branch)
    username = ownerOf(quest, username)
    local step = quest.steps[quest.current]
    local ctx = ctxFor(username, quest)
    local nextId = branch or (step and step.next)
    if step and step.onComplete then
        local r = DDS.Effects.run(step.onComplete, ctx)
        if r.fail then return Q.fail(username, quest, r.fail) end
        if r.complete then return Q.complete(username, quest) end
        nextId = r.branch or nextId
    end
    if step and step.dialogue and not step.dialogueDone then
        step.dialogueDone = true
        quest.pendingNext = nextId
        -- The debrief goes to whoever was there; the owner if nobody was.
        local talker = (quest.lastActor and DDS.playerByName(quest.lastActor)) and quest.lastActor or username
        DDS.Dialogue.start(talker, step.dialogue, { questId = quest.id, onEnd = true })
        quest.awaitingDialogue = true
        return
    end
    if nextId == "complete" or nextId == nil then
        if nextId == nil and step then
            -- Default: the next step in authored order.
            for i, sid in ipairs(quest.stepOrder) do
                if sid == step.id then nextId = quest.stepOrder[i + 1]; break end
            end
        end
        if nextId == nil or nextId == "complete" then return Q.complete(username, quest) end
    end
    if nextId == "fail" then return Q.fail(username, quest, "the story turned") end
    startStep(username, quest, nextId)
end
Q.advance = advance

function Q.tickQuest(username, quest, owner)
    if quest.status ~= "active" or quest.awaitingDialogue then return end
    username = ownerOf(quest, username)
    if quest.deadlineHours and DDS.nowHours() > quest.deadlineHours then
        return Q.fail(username, quest, "out of time")
    end
    local step = quest.steps[quest.current]
    if step == nil then return end
    if step.limitHours and DDS.nowHours() - (step.startedHours or 0) > step.limitHours then
        if step.onTimeout then
            local r = DDS.Effects.run(step.onTimeout, ctxFor(username, quest))
            if r.branch then return startStep(username, quest, r.branch) end
            if r.fail then return Q.fail(username, quest, r.fail) end
        end
        return Q.fail(username, quest, "out of time")
    end
    local changed = false
    for _, obj in ipairs(step.objectives) do
        if not obj.done then
            local fn = evaluate[obj.kind]
            -- Shared missions: measure against the faction member closest to it.
            local actor = Q.actorFor(quest, obj, owner)
            if fn and actor then
                quest.lastActor = DDS.username(actor)
                local ok, result = pcall(fn, username, quest, obj, actor)
                if not ok then
                    DDS.log("objective " .. obj.kind .. " error: " .. tostring(result))
                elseif result then
                    obj.done = true
                    changed = true
                    if obj.onDone then
                        local r = DDS.Effects.run(obj.onDone, ctxFor(username, quest))
                        if r.branch then return startStep(username, quest, r.branch) end
                    end
                    if obj.doneLine then DDS.Server.notify(username, DDS.Effects.render(obj.doneLine, ctxFor(username, quest)), "story") end
                end
            end
        end
    end
    if changed then DDS.Server.markDirty(username) end
    if stepDone(step) then advance(username, quest) end
end

function Q.tickPlayer(username, player)
    local ps = DDS.State.player(username)
    for _, id in ipairs(ps.order) do
        local quest = ps.quests[id]
        if quest then
            if quest.status == "active" then
                Q.tickQuest(username, quest, player)
            elseif quest.status == "offered" and quest.arc ~= "spine"
                    and (quest.offerExpiresHours or 1e9) < DDS.nowHours() then
                Q.retire(username, quest, "expired")
            end
        end
    end
end

-- Shared missions whose owner is offline keep going while any faction
-- member is online.
function Q.tickShared(online)
    if DDS.Party == nil then return end
    for owner, ps in pairs(DDS.State.world().players) do
        if not online[owner] then
            for _, id in ipairs(ps.order or {}) do
                local quest = ps.quests[id]
                if quest and quest.status == "active" and quest.party and #DDS.Party.online(quest.party) > 0 then
                    Q.tickQuest(owner, quest, nil)
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Interactions (from client context menu / timed actions)
---------------------------------------------------------------------------

local function findObjective(username, questId, index)
    local quest = Q.get(username, questId)
    if quest == nil or quest.status ~= "active" then return nil end
    -- Your own mission, or one your faction shares.
    local mine = quest.owner == nil or quest.owner == username
    if not mine and not (quest.party and DDS.Party and DDS.Party.of(username) == quest.party) then return nil end
    local step = quest.steps[quest.current]
    if step == nil then return nil end
    local obj = step.objectives[tonumber(index) or 0]
    if obj == nil or obj.done then return nil end
    return quest, step, obj
end

local function finishObjective(username, quest, obj, line)
    obj.done = true
    quest.lastActor = username
    local ctx = ctxFor(username, quest)
    if obj.onDone then
        local r = DDS.Effects.run(obj.onDone, ctx)
        if r.branch then return startStep(username, quest, r.branch) end
        if r.fail then return Q.fail(username, quest, r.fail) end
    end
    if line then
        local text = DDS.Effects.render(line, ctx)
        DDS.Server.notify(username, text, "story")
        if quest.party and quest.owner ~= username then Q.notifyParty(quest, username .. ": " .. text, "story") end
    end
    DDS.Server.markDirty(username)
    local step = quest.steps[quest.current]
    if step and stepDone(step) then advance(username, quest) end
end

local function noise(player, radius, zombies, at)
    pcall(function()
        local x, y, z = playerXY(player)
        addSound(player, math.floor(x), math.floor(y), math.floor(z), radius, radius)
    end)
    if zombies and zombies > 0 and at then
        local spot = DDS.Sites.ring(at.x, at.y, 22, 34, DDS.rng(DDS.nowMs()))
        spawnZombies(spot, zombies, "noise")
    end
end

function Q.interact(player, args)
    local username = DDS.username(player)
    local quest, step, obj = findObjective(username, args.questId, args.index)
    if quest == nil then return end
    local target = obj.live or obj.at
    if target and not near(player, target, Q.INTERACT_RANGE + 1.5) then
        DDS.Server.notify(username, "Get closer.", "bad")
        return
    end
    local ctx = ctxFor(username, quest)
    local kind = obj.kind
    if kind == "interact" then
        if obj.requires and DDS.Items.count(player, obj.requires) < 1 then
            DDS.Server.notify(username, "You need: " .. DDS.Items.displayName(obj.requires), "bad")
            return
        end
        if obj.noise then noise(player, obj.noise, obj.noiseZombies, obj.at) end
        return finishObjective(username, quest, obj, obj.doneLine)
    elseif kind == "captive" then
        if obj.uid == nil and not obj.fallback then return end
        obj.freed = true
        if obj.uid then
            DDS.ALife.say(obj.uid, DDS.Effects.render(obj.thanks or "[[Oh God. Thank you.|You came. You actually came.|Get me out of here. Please.]]", ctx), 25)
            quest.vars.captiveUid = obj.uid
        end
        return finishObjective(username, quest, obj, obj.doneLine or ("You cut " .. tostring(obj.name) .. " loose."))
    elseif kind == "lock" then
        local method = args.method or "pick"
        if method == "key" then
            if not (obj.keyQuestItem and DDS.Items.count(player, function(item)
                    local d = item:getModData(); return d and d.DDSKey == quest.id end) > 0) then
                DDS.Server.notify(username, "You don't have the key.", "bad")
                return
            end
            return finishObjective(username, quest, obj, "The key turns. You're in.")
        elseif method == "pry" then
            if DDS.Items.count(player, "Base.Crowbar") < 1 then
                DDS.Server.notify(username, "You need a crowbar.", "bad")
                return
            end
            noise(player, 45, obj.pryZombies or 6, obj.at)
            obj.loud = true
            if obj.onLoud then DDS.Effects.run(obj.onLoud, ctx) end
            return finishObjective(username, quest, obj, "Metal shrieks. That will have been heard.")
        else
            local tool = (DDS.Items.count(player, "Base.Screwdriver") > 0 and "Base.Screwdriver")
                or (DDS.Items.count(player, "Base.Paperclip") > 0 and "Base.Paperclip") or nil
            if tool == nil then
                DDS.Server.notify(username, "You need a screwdriver or a paperclip to pick this.", "bad")
                return
            end
            local chance = 0.25 + DDS.Effects.perkLevel(player, "Nimble") * 0.07
                + DDS.Effects.perkLevel(player, "Mechanics") * 0.03 + (1 - (obj.difficulty or 0.4)) * 0.3
            if DDS.Effects.check({ "profession", { "burglar" } }, ctx) then chance = chance + 0.3 end
            chance = DDS.clamp(chance, 0.08, 0.92)
            if ZombRandFloat(0, 1) < chance then
                DDS.Items.xp(player, "Nimble", 15)
                return finishObjective(username, quest, obj, "A soft click. The lock gives.")
            end
            obj.pickFails = (obj.pickFails or 0) + 1
            if tool == "Base.Paperclip" then DDS.Items.take(player, "Base.Paperclip", 1) end
            noise(player, 8, obj.pickFails >= 3 and 3 or 0, obj.at)
            DDS.Server.notify(username, string.format("The pick slips. (%d%% chance)", math.floor(chance * 100)), "bad")
            return
        end
    elseif kind == "search" then
        if obj.item then
            DDS.Items.give(player, obj.item.type, 1, obj.item.name and DDS.Effects.render(obj.item.name, ctx) or nil,
                obj.item.questItem and quest.id or nil, obj.item.key and { DDSKey = quest.id } or nil)
        end
        return finishObjective(username, quest, obj, obj.doneLine)
    elseif kind == "sabotage" then
        if obj.siteId then DDS.ALife.disableComms(obj.siteId) end
        return finishObjective(username, quest, obj, obj.doneLine or "Wires cut. Their radio is dead.")
    elseif kind == "handin" then
        return Q.handIn(player, quest, obj)
    elseif kind == "talk" then
        if obj.uid == nil and obj.npcIndex then
            local npc = step.objectives[obj.npcIndex]
            if npc and npc.uid then obj.uid = npc.uid end
        end
        DDS.Dialogue.start(username, obj.tree, { questId = quest.id, vars = { objIndex = obj.index, stepId = step.id } })
    end
end

function Q.handIn(player, quest, obj)
    local username = DDS.username(player)
    -- Check everything first, then take.
    for _, want in ipairs(obj.items or {}) do
        if want.quest then
            if DDS.Items.questItem(player, quest.id) == nil then
                DDS.Server.notify(username, "You don't have it.", "bad"); return
            end
        else
            local have = DDS.Items.count(player, want.type or want.match)
            if have < (want.count or 1) then
                DDS.Server.notify(username, string.format("Need %d x %s (have %d).", want.count or 1,
                    want.label or DDS.Items.displayName(want.type), have), "bad")
                return
            end
        end
    end
    for _, want in ipairs(obj.items or {}) do
        if want.quest then DDS.Items.takeQuestItem(player, quest.id)
        else DDS.Items.take(player, want.type or want.match, want.count or 1) end
    end
    finishObjective(username, quest, obj, obj.doneLine or "Handed over.")
end

-- Journal button: hand-ins without a point ("leave it at the drop").
function Q.handInRemote(player, args)
    local username = DDS.username(player)
    local quest, step, obj = findObjective(username, args.questId, args.index)
    if quest == nil or obj.kind ~= "handin" or obj.at ~= nil then return end
    Q.handIn(player, quest, obj)
end

function Q.onDialogueEnd(username, session, outcome)
    if session.questId == nil then return end
    local quest = Q.get(username, session.questId)
    if quest == nil then return end
    if quest.status == "offered" then
        if outcome.accept then Q.accept(username, quest.id) end
        if outcome.decline then Q.retire(username, quest, "declined") end
        return
    end
    if quest.status ~= "active" then return end
    if outcome.fail then return Q.fail(username, quest, outcome.fail) end
    if outcome.complete then return Q.complete(username, quest) end
    if quest.awaitingDialogue then
        quest.awaitingDialogue = nil
        local nextId = outcome.branch or quest.pendingNext
        quest.pendingNext = nil
        if nextId == nil or nextId == "complete" then
            local step = quest.steps[quest.current]
            if nextId == nil and step then
                for i, sid in ipairs(quest.stepOrder) do
                    if sid == step.id then nextId = quest.stepOrder[i + 1]; break end
                end
            end
            if nextId == nil or nextId == "complete" then return Q.complete(username, quest) end
        end
        return startStep(username, quest, nextId)
    end
    -- A talk objective's conversation ended.
    local step = quest.steps[quest.current]
    local idx = session.vars and session.vars.objIndex
    local sameStep = session.vars == nil or session.vars.stepId == nil or session.vars.stepId == quest.current
    if step and idx and sameStep and step.objectives[idx] and not outcome.walkedAway then
        local obj = step.objectives[idx]
        obj.done = true
        if outcome.branch then return startStep(username, quest, outcome.branch) end
        if obj.onDone then
            local r = DDS.Effects.run(obj.onDone, ctxFor(username, quest))
            if r.branch then return startStep(username, quest, r.branch) end
        end
        DDS.Server.markDirty(username)
        if stepDone(step) then advance(username, quest) end
    elseif outcome.branch and step then
        startStep(username, quest, outcome.branch)
    end
end

---------------------------------------------------------------------------
-- Kill feeds
---------------------------------------------------------------------------

function Q.onActorKilled(playerOrKey, actor)
    local username = type(playerOrKey) == "string" and playerOrKey or DDS.username(playerOrKey)
    if username == nil or DDS.State.world().players[username] == nil then return end
    local ps = DDS.State.player(username)
    ps.stats.kills = (ps.stats.kills or 0) + 1
    local factionId = actor.factionId
    -- Story standing follows the trigger finger.
    local info = DDS.ALife.factionInfo(factionId)
    if info and info.player ~= "hostile" then DDS.Factions.change(username, factionId, -6, "killed a member")
    else DDS.Factions.change(username, factionId, -2, "killed a member") end
    -- The killer's own missions plus any their faction shares.
    local quests = Q.list(username, function(q) return q.status == "active" end)
    local party = DDS.Party and DDS.Party.of(username) or nil
    if party then
        for owner, ops in pairs(DDS.State.world().players) do
            if owner ~= username then
                for _, q in pairs(ops.quests or {}) do
                    if q.status == "active" and q.party == party then quests[#quests + 1] = q end
                end
            end
        end
    end
    for _, quest in ipairs(quests) do
        local step = quest.steps[quest.current]
        for _, obj in ipairs(step and step.objectives or {}) do
            if obj.kind == "kills" and not obj.done then
                local want = DDS.Factions.resolve(obj.factionId)
                if want == nil or want == factionId or (obj.anyHostile and info and info.player == "hostile") then
                    obj.progress = (obj.progress or 0) + 1
                end
            end
        end
    end
    if DDS.Buddies then DDS.Buddies.onKill(username, actor) end
    DDS.Server.markDirty(username)
end

function Q.onZombieDead(zombie)
    if DDS.ALife.uidOf(zombie) ~= nil then return end
    local tag
    pcall(function() tag = zombie:getModData().DDSTag end)
    local killer
    pcall(function() killer = zombie:getAttackedBy() end)
    local zx, zy = 0, 0
    pcall(function() zx, zy = zombie:getX(), zombie:getY() end)
    local killerName = killer and DDS.username(killer) or nil
    local killerParty = (killerName and DDS.Party) and DDS.Party.of(killer) or nil
    for username, ps in pairs(DDS.State.world().players) do
        for _, id in ipairs(ps.order) do
            local quest = ps.quests[id]
            if quest and quest.status == "active" then
                local step = quest.steps[quest.current]
                for _, obj in ipairs(step and step.objectives or {}) do
                    if not obj.done then
                        if tag and obj.zombieTag == tag then
                            obj.zombieKilled = (obj.zombieKilled or 0) + 1
                        elseif obj.kind == "infected" and killerName
                                and (killerName == username or (quest.party ~= nil and quest.party == killerParty)) then
                            if obj.at == nil or DDS.dist(zx, zy, obj.at.x, obj.at.y) <= (obj.radius or 60) then
                                obj.progress = (obj.progress or 0) + 1
                            end
                        end
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Views for the client
---------------------------------------------------------------------------

local function objectiveView(quest, obj, player)
    local v = { text = obj.text, done = obj.done, optional = obj.optional, kind = obj.kind, index = obj.index }
    if obj.hidden then return nil end
    local at = obj.live or obj.at
    if obj.kind == "eliminate" then
        if obj.state == "active" then
            v.text = v.text .. string.format(" (%d/%d)", obj.progress or obj.zombieKilled or 0, obj.total or obj.zombieTotal or obj.count or 0)
        end
    elseif obj.kind == "kills" or obj.kind == "infected" then
        v.text = v.text .. string.format(" (%d/%d)", math.min(obj.progress or 0, obj.count or 0), obj.count or 0)
    elseif obj.kind == "hold" and obj.state == "holding" then
        v.text = v.text .. string.format(" (%ds)", obj.remaining or 0)
    elseif obj.kind == "wait" and obj.untilHours then
        local left = obj.untilHours - DDS.nowHours()
        if left > 0 then v.text = v.text .. string.format(" (%dh)", math.ceil(left)) end
    elseif obj.kind == "reach" and obj.waitingForBuddy then
        v.text = v.text .. " (waiting for your partner)"
    end
    if at and not obj.done then
        v.x, v.y, v.z = at.x, at.y, at.z
        v.radius = obj.radius
    end
    local interactive = { interact = true, lock = true, search = true, sabotage = true, captive = true, talk = true, handin = true }
    if interactive[obj.kind] and not obj.done then
        if obj.kind == "talk" and not obj.radio and obj.uid then
            v.uid = obj.uid  -- the client outlines and labels this person
        end
        if obj.kind == "talk" and obj.radio then
            v.radio = true
        elseif obj.kind == "handin" and obj.at == nil then
            v.remoteHandIn = true
        elseif at and (obj.kind ~= "captive" or obj.uid or obj.fallback) then
            v.interact = { label = obj.label or "Interact", duration = obj.duration or 60, x = at.x, y = at.y, z = at.z or 0 }
            if obj.kind == "lock" then
                v.interact.methods = { "pick", "pry" }
                if obj.keyQuestItem then v.interact.methods[#v.interact.methods + 1] = "key" end
            end
        end
    end
    return v
end

function Q.view(quest, player)
    local step = quest.steps[quest.current]
    local objectives = {}
    if step then
        for _, obj in ipairs(step.objectives) do
            local ov = objectiveView(quest, obj, player)
            if ov then objectives[#objectives + 1] = ov end
        end
    end
    local hoursLeft
    if quest.deadlineHours then hoursLeft = math.max(0, math.floor(quest.deadlineHours - DDS.nowHours())) end
    local offerLeft
    if quest.status == "offered" and quest.offerExpiresHours then
        offerLeft = math.max(0, math.floor(quest.offerExpiresHours - DDS.nowHours()))
    end
    local log = {}
    for i = math.max(1, #quest.log - 5), #quest.log do log[#log + 1] = quest.log[i].text end
    return {
        id = quest.id, title = quest.title, summary = quest.summary, arc = quest.arc, status = quest.status,
        giver = quest.giver, risk = quest.risk, stepTitle = step and step.title or nil, objectives = objectives,
        rewards = quest.rewardText, hoursLeft = hoursLeft, offerLeft = offerLeft, requiresBuddy = quest.requiresBuddy,
        site = quest.site and { name = quest.site.name, x = quest.site.x, y = quest.site.y } or nil,
        world = quest.world, log = log, awaitingDialogue = quest.awaitingDialogue,
        party = quest.party, owner = quest.owner,
    }
end

return Q
