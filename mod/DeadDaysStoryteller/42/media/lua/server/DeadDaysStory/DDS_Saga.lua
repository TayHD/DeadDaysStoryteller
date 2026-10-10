-- The saga: one shared story per world. Created when the first survivor
-- arrives, anchored near them, with a cast, factions, power balance and
-- twists rolled in secret up front.
--
-- Structure (Days Gone style): each act holds several storylines that run in
-- parallel. A storyline is an ordered run of chapters (story missions). The
-- act's finale chapter unlocks once the threads it depends on are done.
-- Act III forks three ways on the player's choice. When a saga ends, the next
-- one inherits its consequences.

require "DeadDaysStory/DDS_Core"
require "DeadDaysStory/DDS_State"
require "DeadDaysStory/DDS_Names"
require "DeadDaysStory/DDS_Factions"
require "DeadDaysStory/DDS_Sites"

DDS.Saga = DDS.Saga or {}
local S = DDS.Saga

S.acts = {
    { n = 1, title = "Taken",
      blurb = "{saga.settlement} has a fence, a well and about a week of food. {warlord.last}'s crew has started stopping their people on the road and taking what they carry. Last night they took more than supplies." },
    { n = 2, title = "The Guard",
      blurb = "A detachment of the {military.name} is still operating out of {checkpoint.name}. They have fuel, medicine and radios. They want something in return." },
    { n = 3, title = "Orders",
      blurb = "Now you know what the soldiers were sent here to do. Everyone wants your help, and you can't give it to all of them." },
    { n = 4, title = "Winter",
      blurb = "The cold is coming and there isn't enough of anything for everyone. It gets settled at {saga.stronghold}." },
}

S.lines = {
    community = "{saga.settlement}", warlord = "{warlord.last}'s crew", military = "{military.name}",
    lost = "{lost.first}", informant = "Ham operator", finale = "Main story",
}

S.archetypes = {
    contact = { "survivor", "caretaker" },
    doctor = { "idealist", "burnout" },
    officer = { "bythebook", "burnedout" },
    warlord = { "psychotic", "provider" },
    lieutenant = { "psychotic", "follower" },
    informant = { "opportunist", "scared" },
    lost = { "angry", "quiet" },
}

-- Chapter registry (static content). Content files call S.chapter{...}.
S.chapters = S.chapters or {}
S.chapterOrder = S.chapterOrder or {}

function S.chapter(def)
    if S.chapters[def.id] == nil then S.chapterOrder[#S.chapterOrder + 1] = def.id end
    S.chapters[def.id] = def
    return def
end

local function saga() return DDS.State.world().saga end
function S.current() return saga() end

---------------------------------------------------------------------------
-- Creation
---------------------------------------------------------------------------

local function roleEntry(f)
    return { factionId = f.id, name = f.name, heading = f.heading, blurb = f.blurb, bloc = f.bloc }
end

function S.create(anchorX, anchorY, carry)
    local w = DDS.State.world()
    local rng = DDS.State.rng(anchorX + anchorY)
    local N = DDS.Names
    local F = DDS.Factions
    local used = {}

    local antagonist = F.pickFaction(rng, F.roleBlocs.antagonist, { "hostile" }, used); used[antagonist.id] = true
    local military = F.pickFaction(rng, F.roleBlocs.military, { "careful", "neutral" }, used); used[military.id] = true
    local community = F.pickFaction(rng, F.roleBlocs.community, { "friendly", "neutral", "allied", "careful" }, used); used[community.id] = true
    local wildcard = F.pickFaction(rng, F.roleBlocs.wildcard, nil, used); used[wildcard.id] = true

    local n = #(w.sagaHistory or {}) + 1
    local s = {
        n = n, seed = rng.state, act = 1, startedDay = DDS.day(), actStartedDay = DDS.day(),
        anchor = { x = math.floor(anchorX), y = math.floor(anchorY) },
        operation = "the pull-out",
        roles = { antagonist = roleEntry(antagonist), military = roleEntry(military),
            community = roleEntry(community), wildcard = roleEntry(wildcard) },
        power = { antagonist = 60, military = 55, community = 40, wildcard = 45 },
        cast = {}, twists = {}, flags = {}, choices = {}, vars = {},
        chapters = {},
        ended = false,
    }

    -- Cast ------------------------------------------------------------------
    -- Everyone's sex is drawn from what their faction can field in A-Life,
    -- so their body in the world matches their name and voice.
    local function fits(roleFaction, female)
        local avail = DDS.ALife.sexesIn(roleFaction.id)
        if avail == nil then return female end
        if female and not avail.f and avail.m then return false end
        if not female and not avail.m and avail.f then return true end
        return female
    end
    local function member(roleFaction, female)
        if female == nil then female = rng:chance(0.5) end
        return N.person(rng, fits(roleFaction, female))
    end
    local contact = member(community); contact.role = "contact"; contact.faction = "community"
    contact.status = "alive"; contact.trust = 55
    contact.past = rng:pick({ "ran the feed store on Main", "taught eighth-grade science", "drove a school bus for twenty years",
        "managed the hardware store", "was a dispatcher at the sheriff's office", "ran the church food pantry" })
    -- Son or daughter only: keeps spoken lines to a small, recordable set.
    local kin = rng:pick({ N.kin[1], N.kin[2] })
    if fits(community, kin.female) ~= kin.female then kin = kin.female and N.kin[2] or N.kin[1] end
    local lost = N.person(rng, kin.female); lost.last = contact.last; lost.name = lost.first .. " " .. lost.last
    lost.role = "lost"; lost.kin = kin.word; lost.status = "free"; lost.faction = "community"
    lost.age = (kin.word == "daughter" or kin.word == "son") and rng:pick({ "sixteen", "seventeen", "nineteen" }) or "grown"
    local doctor = member(community); doctor.role = "doctor"; doctor.faction = "community"; doctor.status = "alive"; doctor.trust = 50
    doctor.past = rng:pick({ "a veterinary nurse in Brandenburg", "an ER nurse in Louisville",
        "an Army medic in the Gulf", "the school nurse at Muldraugh Elementary" })
    local officer = member(military); officer.role = "officer"; officer.faction = "military"; officer.status = "alive"
    officer.rank = rng:pick(N.rank); officer.callsign = rng:pick(N.callsign)
    officer.full = officer.rank .. " " .. officer.name
    local warlord = member(antagonist); warlord.role = "warlord"; warlord.faction = "antagonist"; warlord.status = "alive"
    warlord.moniker = warlord.last
    warlord.past = rng:pick({ "ran a towing outfit on the bypass", "drove for the gravel company",
        "did six years at Eddyville for armed robbery", "ran a used car lot", "was a guard at the county jail" })
    local lieutenant = N.person(rng, false); lieutenant.role = "lieutenant"; lieutenant.faction = "antagonist"
    lieutenant.status = "alive"; lieutenant.moniker = rng:pick(N.lieutenantMoniker)
    local informant = member(wildcard); informant.role = "informant"; informant.faction = "wildcard"; informant.status = "alive"
    informant.alias = N.hamCallsign(rng); informant.trust = 40
    informant.sibling = N.person(rng)
    s.cast = { contact = contact, lost = lost, doctor = doctor, officer = officer, warlord = warlord,
        lieutenant = lieutenant, informant = informant }

    -- Archetypes: the same story beat plays differently depending on who
    -- these people turned out to be. Each archetype has its own voice.
    for key, options in pairs(S.archetypes) do
        if s.cast[key] then s.cast[key].arch = rng:pick(options) end
    end

    -- Twists (secret) ------------------------------------------------------
    if rng:chance(0.6) then
        local who = rng:chance(0.6) and "informant" or "doctor"
        s.twists.mole = { who = who, revealed = false }
        s.betrayal = "mole"
        s.vars.mole = s.cast[who]
        s.flags["moleIs_" .. who] = true
    else
        s.twists.bargain = { who = "contact", revealed = false }
        s.betrayal = "bargain"
    end
    if rng:chance(0.5) then
        s.twists.firebreak = { revealed = false }
        s.militaryTwist = "firebreak"
    else
        s.twists.lab = { revealed = false }
        s.militaryTwist = "lab"
    end
    if (kin.word == "daughter" or kin.word == "son") and rng:chance(0.4) then
        s.twists.blood = { revealed = false }
        s.vars.bloodWord = warlord.female and "mother" or "father"
    end

    -- Carryover from the last saga ------------------------------------------
    if carry then
        s.carry = carry
        if carry.sparedName then s.vars.revenant = { name = carry.sparedName, moniker = carry.sparedMoniker } end
    end

    -- Places -----------------------------------------------------------------
    local avoid = {}
    s.home = DDS.Sites.pick(anchorX, anchorY, { "church", "school", "motel", "warehouse" }, 120, 450, rng, avoid)
    avoid[s.home.key] = true
    s.strongholdSite = DDS.Sites.pick(anchorX, anchorY, { "warehouse", "gas", "motel", "bar", "police" }, 500, 1400, rng, avoid)
    avoid[s.strongholdSite.key] = true
    s.checkpoint = DDS.Sites.pick(anchorX, anchorY, { "police", "school", "military", "hospital" }, 400, 1200, rng, avoid)
    avoid[s.checkpoint.key] = true
    s.lostHome = DDS.Sites.pick(anchorX, anchorY, { "house" }, 200, 700, rng, avoid)
    s.vars.home = s.home
    s.vars.hold = s.strongholdSite
    s.vars.checkpoint = s.checkpoint
    s.vars.lostHome = s.lostHome
    s.town = s.home.town
    -- People name places after what they are.
    s.settlement = N.placeName(rng, s.home, contact.last)
    s.stronghold = N.placeName(rng, s.strongholdSite, warlord.last)
    if s.stronghold == s.settlement then s.stronghold = "the " .. warlord.last .. " place" end

    -- Which optional chapters this playthrough gets.
    for _, id in ipairs(S.chapterOrder) do
        local def = S.chapters[id]
        if def.optional and not rng:chance(def.optional) then
            s.chapters[id] = { state = "skipped" }
        end
    end

    local titles = {
        "Fall, 1993", "What We Owe", "The Long Winter", "Nobody's Coming", "After the Cordon",
        "The Last Trucks Out", "{town}, Before the Snow", "The Ones Who Stayed",
    }
    s.title = DDS.Text.render(rng:pick(titles), { settlement = s.settlement, town = s.town }, rng)
    w.saga = s
    DDS.State.chronicle("A new story begins: " .. s.title .. ".", "saga")
    DDS.log("saga " .. n .. " created: " .. s.title .. " antagonist=" .. antagonist.id .. " military=" .. military.id
        .. " community=" .. community.id .. " betrayal=" .. s.betrayal .. " militaryTwist=" .. s.militaryTwist)
    return s
end

function S.ensure(player)
    local s = saga()
    if s and not s.ended then return s end
    if s and s.ended and (s.nextSagaHours or 0) > DDS.nowHours() then return s end
    local x, y = 10600, 9300
    if player then pcall(function() x, y = player:getX(), player:getY() end) end
    local carry = s and s.carryOut or nil
    if s then
        local w = DDS.State.world()
        DDS.push(w.sagaHistory, { n = s.n, title = s.title, ending = s.ending, endedDay = s.endedDay }, 20)
    end
    return S.create(x, y, carry)
end

---------------------------------------------------------------------------
-- Player onboarding
---------------------------------------------------------------------------

-- The opening plays by itself: a few seconds after the player is in the world
-- the radio crackles, the first chapter starts, and the contact's call opens.
-- Schedules live in memory; the flag is only set once the call actually plays,
-- so a restart or a quick disconnect just replays the schedule.
S.introQueue = S.introQueue or {}
S.INTRO_DELAY_MS = 10000
S.INTRO_RING_MS = 2500

function S.onboard(username, delayMs)
    local s = saga()
    if s == nil or s.ended then return end
    local ps = DDS.State.player(username)
    if ps.flags["sagaIntro" .. s.n] or S.introQueue[username] then return end
    S.introQueue[username] = { at = DDS.nowMs() + (delayMs or 3000), stage = "ring" }
end

local function firstChapterQuest(username, s)
    local ps = DDS.State.player(username)
    for _, id in ipairs(S.chapterOrder) do
        local prefix = "offered_" .. s.n .. "_" .. id .. "_"
        for key, questId in pairs(ps.flags) do
            if type(questId) == "string" and string.sub(key, 1, #prefix) == prefix then
                local q = ps.quests[questId]
                if q and q.status == "offered" then return q end
            end
        end
    end
    return nil
end

function S.tickIntro()
    local now = DDS.nowMs()
    for username, entry in pairs(S.introQueue) do
        local s = saga()
        local player = DDS.playerByName(username)
        if s == nil or s.ended or player == nil then
            S.introQueue[username] = nil
        elseif now >= entry.at then
            local busy = DDS.Dialogue.sessions[username] ~= nil
            local dead = false
            pcall(function() dead = player:isDead() end)
            if busy or dead then
                entry.at = now + 3000
            elseif entry.stage == "ring" then
                -- Start the first chapter, then let the radio ring before the voice.
                S.unlock()
                S.offerChapters(username)
                local q = firstChapterQuest(username, s)
                if q then DDS.Quests.accept(username, q.id, nil, true) end
                DDS.Server.notify(username, "Incoming radio: " .. s.cast.contact.name .. " (" .. s.settlement .. ")", "radio")
                DDS.Server.markDirty(username)
                entry.stage = "talk"
                entry.at = now + S.INTRO_RING_MS
            else
                S.introQueue[username] = nil
                DDS.State.player(username).flags["sagaIntro" .. s.n] = true
                DDS.Dialogue.start(username, "spine:intro", {})
                DDS.Server.markDirty(username)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Twists
---------------------------------------------------------------------------

function S.reveal(twistId, ctx)
    local s = saga()
    if s == nil or s.twists[twistId] == nil or s.twists[twistId].revealed then return end
    s.twists[twistId].revealed = true
    s.twists[twistId].revealedDay = DDS.day()
    local lines = {
        mole = "{mole.name} had been passing information to {warlord.last}'s crew: patrol times, who was sick, where the supplies were kept.",
        bargain = "{contact.name} traded {warlord.last} the location of the Guard's fuel cache to get {lost.first} back. Two soldiers died in the raid that followed.",
        firebreak = "The {military.name} have orders to take civilian fuel, vehicles and medicine for the pull-out, and to turn back anyone who tries to follow them out of the county.",
        lab = "There are only so many seats on the last trucks out. The {military.name}'s list has {doctor.name} on it. Nobody else from {saga.settlement} is.",
        blood = "{warlord.name} is {lost.first}'s {bloodWord}. {lost.first} got in that truck on {lost.his} own.",
    }
    local text = lines[twistId]
    if text then
        local rendered = DDS.Effects.render(text, ctx or {})
        DDS.State.chronicle(rendered, "twist")
        for _, p in ipairs(DDS.onlinePlayers()) do
            DDS.Server.notify(DDS.username(p), "The story turns: " .. rendered, "twist")
        end
    end
end

---------------------------------------------------------------------------
-- Chapters
---------------------------------------------------------------------------

local function chapterState(s, id)
    s.chapters = s.chapters or {}
    local c = s.chapters[id]
    if c == nil then
        c = { state = "locked" }
        s.chapters[id] = c
    end
    return c
end

-- A skipped chapter (optional, not rolled for this playthrough) counts as done
-- for anything that depends on it.
local function satisfied(s, id)
    local c = chapterState(s, id)
    return c.state == "done" or c.state == "skipped"
end

local function requirementsMet(s, def)
    for _, req in ipairs(def.requires or {}) do
        if not satisfied(s, req) then return false end
    end
    if def.requiresAny then
        local any = false
        for _, req in ipairs(def.requiresAny) do
            if satisfied(s, req) then any = true end
        end
        if not any then return false end
    end
    local c = chapterState(s, def.id)
    if c.retryAfterHours and c.retryAfterHours > DDS.nowHours() then return false end
    if def.cond and not def.cond(s) then return false end
    if def.minDayInAct and DDS.day() - (s.actStartedDay or 0) < def.minDayInAct then return false end
    return true
end

-- Unlock what can be unlocked; returns true if anything changed.
function S.unlock()
    local s = saga()
    if s == nil or s.ended then return false end
    local changed = false
    for _, id in ipairs(S.chapterOrder) do
        local def = S.chapters[id]
        if def.act == s.act then
            local c = chapterState(s, id)
            if c.state == "locked" and requirementsMet(s, def) then
                c.state = "available"
                c.since = DDS.nowHours()
                changed = true
            end
        end
    end
    return changed
end

function S.offerChapters(username)
    local s = saga()
    if s == nil or s.ended then return end
    local ps = DDS.State.player(username)
    for _, id in ipairs(S.chapterOrder) do
        local def = S.chapters[id]
        local c = s.chapters and s.chapters[id]
        if def.act == s.act and c and c.state == "available" then
            local key = "offered_" .. s.n .. "_" .. id .. "_" .. tostring(c.failures or 0)
            if not ps.flags[key] then
                local quest = DDS.Quests.offerTemplate(username, id, { world = true, arc = "spine" })
                if quest then
                    ps.flags[key] = quest.id
                end
            end
        end
    end
end

function S.chapterFor(quest)
    local s = saga()
    if s == nil or quest == nil then return nil end
    return S.chapters[quest.templateId] and chapterState(s, quest.templateId) or nil
end

local function forEachCopy(templateId, fn)
    for name, ps in pairs(DDS.State.world().players) do
        for _, q in pairs(ps.quests) do
            if q.world and q.templateId == templateId then fn(name, q) end
        end
        DDS.Server.markDirty(name)
    end
end

-- Kept under the old names: the quest engine calls these for any world quest.
function S.claimKeystone(username, quest)
    local c = S.chapterFor(quest)
    if c == nil then return end
    c.state = "claimed"
    c.owner = username
    c.questId = quest.id
    c.claimedHours = DDS.nowHours()
    forEachCopy(quest.templateId, function(name, q)
        if name ~= username and q.status == "offered" then q.status = "taken"; q.takenBy = username end
    end)
end

function S.releaseKeystone(quest)
    local c = S.chapterFor(quest)
    if c == nil then return end
    c.state = "available"
    c.owner = nil
    c.questId = nil
    forEachCopy(quest.templateId, function(name, q)
        if q.status == "taken" then q.status = "offered" end
    end)
end

function S.onKeystoneDone(username, quest)
    local s = saga()
    local c = S.chapterFor(quest)
    if s == nil or c == nil then return end
    c.state = "done"
    c.doneDay = DDS.day()
    c.by = username
    forEachCopy(quest.templateId, function(name, q)
        if q.status == "taken" or q.status == "offered" then q.status = "closed" end
    end)
    local def = S.chapters[quest.templateId]
    DDS.State.chronicle("Chapter complete: " .. quest.title .. ".", "chapter")
    if def and def.finale then
        S.advance({ username = username, player = DDS.playerByName(username) })
    elseif S.unlock() then
        for _, p in ipairs(DDS.onlinePlayers()) do S.offerChapters(DDS.username(p)) end
    end
end

function S.onKeystoneFailed(username, quest, reason)
    local s = saga()
    local c = S.chapterFor(quest)
    if s == nil or c == nil then return end
    -- Failure is a story beat, not a dead end: consequences land and the
    -- chapter returns later in a harder form.
    c.failures = (c.failures or 0) + 1
    c.state = "locked"
    c.owner = nil
    c.retryAfterHours = DDS.nowHours() + 12
    DDS.Factions.shiftPower("antagonist", 6)
    DDS.Factions.shiftPower("community", -4)
    s.flags["failed_" .. quest.templateId] = c.failures
    forEachCopy(quest.templateId, function(name, q)
        if q.status == "taken" or q.status == "offered" then q.status = "closed" end
    end)
    DDS.State.chronicle("'" .. quest.title .. "' went wrong. " .. s.roles.antagonist.name .. " grow bolder.", "setback")
end

function S.advance(ctx)
    local s = saga()
    if s == nil or s.ended then return end
    if s.act >= #S.acts then return S.finish(ctx) end
    s.act = s.act + 1
    s.actStartedDay = DDS.day()
    local info = S.acts[s.act]
    DDS.State.chronicle("Act " .. s.act .. ": " .. info.title, "act")
    for _, p in ipairs(DDS.onlinePlayers()) do
        DDS.Server.notify(DDS.username(p), "ACT " .. s.act .. " - " .. string.upper(info.title), "act")
    end
    S.unlock()
    for _, p in ipairs(DDS.onlinePlayers()) do S.offerChapters(DDS.username(p)) end
end

---------------------------------------------------------------------------
-- Ending
---------------------------------------------------------------------------

S.endings = {
    liberator = "{warlord.last}'s crew is gone. {saga.settlement} goes into winter with its fence intact and enough to eat, if they're careful.",
    soldier = "The {military.name} pulled out with what they came for. {saga.settlement} got a few crates of supplies and a promise nobody expects them to keep.",
    warlord = "{warlord.last} runs the roads now, and you run them with {warlord.him}. People pay to pass. Most of them pay.",
    ashes = "Nobody won. {saga.settlement} scattered, the soldiers are gone, and the roads around {saga.town} belong to the dead.",
}

function S.finish(ctx)
    local s = saga()
    if s == nil or s.ended then return end
    local side = s.choices and s.choices.side or "community"
    local ending = s.flags.ending
    if ending == nil then
        if side == "warlord" then ending = "warlord"
        elseif side == "military" then ending = (s.flags.settlementBurned and "ashes") or "soldier"
        else ending = (s.power.community <= 10) and "ashes" or "liberator" end
    end
    s.ending = ending
    s.ended = true
    s.endedDay = DDS.day()
    s.nextSagaHours = DDS.nowHours() + 48
    local epilogue = DDS.Effects.render(S.endings[ending] or S.endings.ashes, ctx or {})
    s.epilogue = epilogue
    DDS.State.chronicle("THE END OF '" .. s.title .. "'. " .. epilogue, "ending")
    s.carryOut = {
        ending = ending,
        sparedName = s.flags.bossSpared and s.flags.bossName or nil,
        sparedMoniker = s.flags.bossSpared and s.flags.bossMoniker or nil,
        winner = side,
    }
    for _, p in ipairs(DDS.onlinePlayers()) do
        DDS.Server.notify(DDS.username(p), "Saga complete: " .. s.title .. ". A new story begins in two days.", "act")
    end
end

---------------------------------------------------------------------------
-- Hourly heartbeat
---------------------------------------------------------------------------

function S.hourly()
    local s = saga()
    if s == nil then return end
    if s.ended then
        if (s.nextSagaHours or 0) <= DDS.nowHours() then
            local players = DDS.onlinePlayers()
            if #players > 0 then
                S.ensure(players[1])
                for _, p in ipairs(players) do S.onboard(DDS.username(p)) end
            end
        end
        return
    end
    -- Unlock what's ready (failed chapters wait out their retry cooldown).
    S.unlock()
    -- A claimed chapter whose owner vanished for two days goes back on the table.
    for id, c in pairs(s.chapters or {}) do
        if c.state == "claimed" and c.owner and DDS.playerByName(c.owner) == nil
                and DDS.nowHours() - (c.claimedHours or 0) > 48 then
            local ps = DDS.State.player(c.owner)
            local q = ps.quests[c.questId or ""]
            if q then q.status = "closed" end
            c.state = "available"
            c.owner = nil
            c.failures = (c.failures or 0) + 1
        end
    end
    for _, p in ipairs(DDS.onlinePlayers()) do S.offerChapters(DDS.username(p)) end
    -- Power drifts toward the strong: the world moves without you.
    if DDS.hourOfDay() == 6 then
        local rng = DDS.State.rng(DDS.day())
        s.power.antagonist = DDS.clamp(s.power.antagonist + rng:int(-1, 3), 0, 100)
        s.power.community = DDS.clamp(s.power.community + rng:int(-3, 1), 0, 100)
        s.power.military = DDS.clamp(s.power.military + rng:int(-2, 2), 0, 100)
    end
end

function S.noteSideDone()
    local s = saga()
    if s and not s.ended then s.sideDoneThisAct = (s.sideDoneThisAct or 0) + 1 end
end

---------------------------------------------------------------------------
-- View
---------------------------------------------------------------------------

function S.view(username)
    local s = saga()
    if s == nil then return nil end
    local ps = DDS.State.player(username)
    local ctx = { username = username, player = DDS.playerByName(username) }
    local info = S.acts[s.act] or S.acts[#S.acts]
    local cast = {}
    local order = { "contact", "lost", "doctor", "officer", "informant", "warlord", "lieutenant" }
    local roleLine = {
        contact = "Runs {saga.settlement}", lost = "{contact.first}'s {lost.kin}", doctor = "Medic at {saga.settlement}",
        officer = "{officer.rank}, {military.name} ({officer.callsign})", informant = "Ham radio operator, {informant.alias}",
        warlord = "Runs the {antagonist.name}", lieutenant = "'{lieutenant.moniker}', {warlord.last}'s right hand",
    }
    for _, key in ipairs(order) do
        local c = s.cast[key]
        if c and (ps.met[key] or key == "contact" or key == "warlord") then
            cast[#cast + 1] = { key = key, name = c.name, role = DDS.Effects.render(roleLine[key], ctx),
                status = c.status, met = ps.met[key] == true, trust = c.trust }
        end
    end
    -- Storyline progress for the current act.
    local lines, totals = {}, { done = 0, all = 0 }
    for _, id in ipairs(S.chapterOrder) do
        local def = S.chapters[id]
        local c = s.chapters and s.chapters[id]
        local skipped = c ~= nil and c.state == "skipped"
        local applies = not skipped and (def.cond == nil or def.cond(s) or (c ~= nil and c.state ~= "locked"))
        if applies then
            totals.all = totals.all + 1
            if c and c.state == "done" then totals.done = totals.done + 1 end
        end
        if def.act == s.act and applies then
            lines[#lines + 1] = {
                id = id, line = DDS.Effects.render(S.lines[def.line] or def.line or "", ctx),
                title = DDS.Effects.render(def.title or id, ctx), state = c and c.state or "locked",
                owner = c and c.owner or nil, finale = def.finale == true,
            }
        end
    end
    local chronicle = {}
    local w = DDS.State.world()
    for i = #w.chronicle, math.max(1, #w.chronicle - 14), -1 do
        local e = w.chronicle[i]
        chronicle[#chronicle + 1] = { day = e.day, text = e.text, kind = e.kind }
    end
    return {
        title = s.title, n = s.n, act = s.act, actTitle = info.title,
        actBlurb = DDS.Effects.render(info.blurb, ctx), day = DDS.day(), startedDay = s.startedDay,
        settlement = s.settlement, town = s.town, cast = cast, chronicle = chronicle,
        chapters = lines, progress = totals, ended = s.ended, epilogue = s.epilogue,
        power = { antagonist = s.power.antagonist, military = s.power.military, community = s.power.community,
            wildcard = s.power.wildcard },
        roles = { antagonist = s.roles.antagonist.name, military = s.roles.military.name,
            community = s.roles.community.name, wildcard = s.roles.wildcard.name },
        home = s.home and { x = s.home.x, y = s.home.y, name = s.home.name } or nil,
    }
end

return S
