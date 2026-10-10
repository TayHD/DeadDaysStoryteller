-- Buddies: companions in the Last of Us mould. A buddy is a person with a
-- past, opinions about what you do, and a loyalty arc of their own. In the
-- world they are an A-Life NPC steered to follow the player; when the player
-- drives off they "ride along" and step back in when the player stops.

require "DeadDaysStory/DDS_Core"
require "DeadDaysStory/DDS_State"
require "DeadDaysStory/DDS_ALife"
require "DeadDaysStory/DDS_Names"

DDS.Buddies = DDS.Buddies or {}
local Bd = DDS.Buddies

Bd.FOLLOW_MS = 2000
Bd.LEASH = 70
Bd.lastFollow = {}
Bd.lastBanter = {}

Bd.archetypes = {
    scout = { label = "Scout", likes = { "clever", "mercy", "respect" }, dislikes = { "reckless", "ruthless" },
        skills = { stealth = true, lie = true }, perk = "Spots trouble early", gift = { "Base.HandTorch", "Base.Battery" } },
    medic = { label = "Medic", likes = { "mercy", "honest", "loyal" }, dislikes = { "ruthless", "cold" },
        skills = { medic = true, persuade = true }, perk = "Patches you up", gift = { "Base.Bandage", "Base.Disinfectant", "Base.Pills" } },
    bruiser = { label = "Bruiser", likes = { "defiant", "ruthless", "loyal" }, dislikes = { "greed", "cold" },
        skills = { intimidate = true }, perk = "Scares people into talking", gift = { "Base.Nails", "Base.Plank" } },
    marksman = { label = "Marksman", likes = { "lawful", "pragmatic", "honest" }, dislikes = { "reckless", "greed" },
        skills = { soldier = true }, perk = "Shares ammunition", gift = { "Base.Bullets9mmBox", "Base.ShotgunShellsBox", "Base.308Box" } },
    talker = { label = "Fixer", likes = { "clever", "greed", "pragmatic" }, dislikes = { "honest", "defiant" },
        skills = { persuade = true, lie = true }, perk = "Talks you out of trouble", gift = { "Base.CigarettePack", "Base.Whiskey" } },
}

-- Personalities: how a buddy talks. Banter is spoken (voice pack), so it never
-- names people or places. approve/disapprove are narration, not speech.
Bd.personalities = {
    steady = {
        idle = { "Keep an eye on the tree line.", "We should fill the water jugs while it's quiet.",
            "[sighs] My feet are shot. Don't tell anybody.", "Check that car on the way past. Might be gas in it.",
            "I keep thinking I hear a generator. It's just the wind.", "Slow down. We don't have to run everywhere." },
        night = { "Lights off from here. They see it for miles.", "Let's find somewhere with a door that locks." },
        rain = { "Good for the barrels, anyway.", "Rain'll cover the noise. Theirs too." },
        kill = { "Got it.", "That's one.", "[breathing hard] Okay. Okay, that's done." },
        hurt = { "[concerned] You're bleeding. Let me look at it.", "Sit down a minute. That needs wrapping." },
        approve = { "{buddy.first} nods.", "{buddy.first}: 'That was right.'" },
        disapprove = { "{buddy.first} doesn't say anything for a while.", "{buddy.first}: 'I don't like that.'" },
    },
    grim = {
        idle = { "Quiet's never good.", "Watch the windows.", "Keep moving.", "Don't touch anything you don't need.",
            "Whoever lived here didn't make it.", "We're not staying long." },
        night = { "Nobody's out at night unless they're up to something.", "Don't light anything." },
        rain = { "Wet boots. That's how you lose toes.", "Can't hear a thing in this." },
        kill = { "Down.", "Clear.", "Next one." },
        hurt = { "You're slowing down. Fix it before it gets worse.", "That needs cleaning. Now, not later." },
        approve = { "{buddy.first}: 'Good call.'", "{buddy.first} grunts. It might be approval." },
        disapprove = { "{buddy.first}: 'That'll come back on us.'", "{buddy.first} shakes their head." },
    },
    dry = {
        idle = { "Another empty gas station. My favorite.", "Remember when the worst thing was a flat tire.",
            "I'd kill for a cup of coffee. Not literally. [laughs] Probably.", "You know what I miss? Ice.",
            "Somebody's going to have to explain the bridge to me. Who blocks a bridge with a school bus.",
            "If we find a working shower I'm moving in." },
        night = { "Great. The part of the day where everything's worse.", "Night shift. Same pay." },
        rain = { "Wet and miserable. So, Tuesday.", "If I catch a cold after all this, I'm going to be furious." },
        kill = { "And stay down.", "That one had it coming.", "Ugh. That's going to be in my hair." },
        hurt = { "You're leaking. That seems bad.", "Maybe stop getting hit. Just a thought." },
        approve = { "{buddy.first}: 'Huh. Look at you.'", "{buddy.first} almost smiles." },
        disapprove = { "{buddy.first}: 'Wow. Okay.'", "{buddy.first} looks away." },
    },
    faithful = {
        idle = { "[quietly] Lord, one more day. That's all I ask.", "I said a prayer for the folks in that last house.",
            "My mother would've had a casserole for every one of these people.", "We'll get through this. I believe that.",
            "I keep the Bible for the pages, mostly. Some nights I read it.", "Somebody ought to bury them. Not today, though." },
        night = { "Say one for whoever's out there tonight.", "Stay close. I don't like the dark anymore." },
        rain = { "Well. It's good for the crops, if anybody's still growing any.", "Let it rain." },
        kill = { "[whispers] Forgive me.", "Rest now.", "God help them." },
        hurt = { "Hold still. Let me clean that.", "You're not going anywhere till that's wrapped." },
        approve = { "{buddy.first}: 'Bless you for that.'", "{buddy.first} touches your shoulder." },
        disapprove = { "{buddy.first}: 'That wasn't right. You know it wasn't.'", "{buddy.first} goes quiet." },
    },
    angry = {
        idle = { "I'm sick of hiding.", "Every one of these towns had a plan. Look how that went.",
            "Somebody knew. Somebody always knows before the rest of us.", "Don't tell me to calm down.",
            "We should've taken the truck.", "I'm not dying in some bathroom. I'm just not." },
        night = { "Let them come. I'm not sleeping anyway.", "I hate this part." },
        rain = { "Of course. Of course it's raining.", "Great. Fantastic." },
        kill = { "Yeah. That's right.", "Who's next?", "[shouting] Come on, then." },
        hurt = { "Get up. Come on, get up.", "Wrap it and keep going." },
        approve = { "{buddy.first}: 'Good.'", "{buddy.first} punches your arm." },
        disapprove = { "{buddy.first}: 'That was soft.'", "{buddy.first} kicks a can across the road." },
    },
}
Bd.backstories = { "brother", "debt", "home", "guilt" }

---------------------------------------------------------------------------
-- Storage
---------------------------------------------------------------------------

local function roster(username)
    local ps = DDS.State.player(username)
    ps.buddies = ps.buddies or {}
    return ps.buddies, ps
end

function Bd.get(username, id)
    local list = roster(username)
    return list[id]
end

function Bd.active(username)
    if username == nil then return nil end
    local list, ps = roster(username)
    local b = ps.activeBuddy and list[ps.activeBuddy] or nil
    if b and (b.status == "following" or b.status == "riding" or b.status == "waiting") then return b end
    return nil
end

---------------------------------------------------------------------------
-- Recruiting
---------------------------------------------------------------------------

function Bd.create(username, opts)
    local list, ps = roster(username)
    local rng = DDS.State.rng(DDS.nowMs())
    local p = opts.person or DDS.Names.person(rng, opts.female)
    local archetype = opts.archetype or rng:pick({ "scout", "medic", "bruiser", "marksman", "talker" })
    local b = {
        id = DDS.State.newId("b"),
        name = p.name, first = p.first, last = p.last, female = p.female,
        he = p.he, him = p.him, his = p.his, He = p.He, His = p.His,
        archetype = archetype, archLabel = Bd.archetypes[archetype].label,
        personality = opts.personality or rng:pick({ "steady", "grim", "dry", "faithful", "angry" }),
        factionId = opts.factionId or (DDS.Factions.pickCivilian(rng) or {}).id,
        loyalty = opts.loyalty or 45,
        stage = 0, missions = 0, kills = 0,
        backstory = opts.backstory or rng:pick(Bd.backstories),
        origin = opts.origin or "met",
        status = "idle",
        recruitedDay = DDS.day(),
        skills = Bd.archetypes[archetype].skills,
        bio = opts.bio,
    }
    b.bio = b.bio or DDS.Text.render(rng:pick({
        "Drove a [[tow truck|school bus|delivery van]] in {town} before July. Doesn't talk about who [[they|she|he]] lost.",
        "Was a [[nursing student|line cook|National Guard reservist|youth pastor|bartender]]. Still is, sort of.",
        "Walked out of the Louisville evacuation alone. Nobody knows how.",
        "Grew up on a farm outside {town}. Can field-dress a deer in four minutes.",
    }), { town = DDS.State.world().saga and DDS.State.world().saga.town or "the county" }, rng)
    list[b.id] = b
    ps.buddyOrder = ps.buddyOrder or {}
    ps.buddyOrder[#ps.buddyOrder + 1] = b.id
    return b
end

-- kind: "starter" | "rescued" | "informant" | "officer" | "boss"
function Bd.recruit(username, kind, ctx)
    local s = DDS.State.world().saga
    local opts = { origin = kind }
    if kind == "informant" and s then
        local c = s.cast.informant
        opts.person = c; opts.archetype = "talker"; opts.factionId = s.roles.wildcard.factionId
        opts.backstory = "brother"; opts.loyalty = 35; opts.bio = "Sold secrets to everyone, including you. Says that's over."
    elseif kind == "officer" and s then
        local c = s.cast.officer
        opts.person = c; opts.archetype = "marksman"; opts.factionId = s.roles.military.factionId
        opts.backstory = "guilt"; opts.loyalty = 30; opts.bio = "Used to carry out orders. Now carries yours. Hasn't decided if that's better."
    elseif kind == "starter" and s then
        opts.factionId = s.roles.community.factionId; opts.loyalty = 50
        opts.bio = "{saga.settlement}'s best runner, before you showed up. {contact.first} says you two should stop competing and start covering each other."
        opts.bio = DDS.Effects.render(opts.bio, ctx or {})
    elseif kind == "rescued" and ctx and ctx.quest and ctx.quest.vars and ctx.quest.vars.victim then
        opts.person = ctx.quest.vars.victim; opts.loyalty = 55
        opts.bio = "You cut " .. ctx.quest.vars.victim.first .. " loose at " .. tostring(ctx.quest.site and ctx.quest.site.name or "a hellhole") .. ". They haven't forgotten."
    end
    local b = Bd.create(username, opts)
    local ps = DDS.State.player(username)
    if ps.activeBuddy == nil then ps.activeBuddy = b.id end
    DDS.Server.notify(username, b.first .. " (" .. b.archLabel .. ") will travel with you. Open the Journal > Buddies.", "good")
    DDS.State.chronicle(b.name .. " started riding with " .. username .. ".", "buddy")
    DDS.Server.markDirty(username)
    return b
end

---------------------------------------------------------------------------
-- In the world
---------------------------------------------------------------------------

local function playerPos(player)
    local x, y, z = 0, 0, 0
    pcall(function() x, y, z = player:getX(), player:getY(), player:getZ() end)
    return x, y, z
end

local function inVehicle(player)
    local v
    pcall(function() v = player:getVehicle() end)
    return v ~= nil
end

local function despawn(b)
    if b.uid then DDS.ALife.purge(b.uid, "dds_buddy") end
    b.uid = nil
    b.spawning = nil
end

local function spawn(username, b, player)
    if b.spawning and DDS.nowMs() - b.spawning < 20000 then return end
    if not DDS.ALife.available() then return end
    local x, y = playerPos(player)
    local spot = DDS.Sites.ring(x, y, 12, 18, DDS.rng(DDS.nowMs()))
    b.spawning = DDS.nowMs()
    local sandbox = SandboxVars and SandboxVars.DeadDaysStory or {}
    DDS.ALife.spawn(player, {
        x = spot.x, y = spot.y, z = 0, factionId = b.factionId, count = 1, mode = "patrol",
        hostile = false, stance = "friendly", keepOut = 6, persistent = true,
        invulnerable = sandbox.BuddyMortal ~= true, noFlee = true, supportRole = "backup", radius = 6,
        female = b.female, person = b.name,
    }, function(uids)
        b.spawning = nil
        if #uids > 0 then
            b.uid = uids[1]
            DDS.ALife.follow(b.uid, x, y, 0)
            local mood = Bd.personalities[b.personality] or Bd.personalities.steady
            DDS.ALife.say(b.uid, DDS.Text.render(mood.idle[ZombRand(1, #mood.idle + 1)], { buddy = b }), 20)
        end
    end)
end

function Bd.call(username)
    local list, ps = roster(username)
    local b = ps.activeBuddy and list[ps.activeBuddy] or nil
    if b == nil or b.status == "dead" or b.status == "left" then return false, "no_buddy" end
    b.status = "following"
    local player = DDS.playerByName(username)
    if player and b.uid == nil then spawn(username, b, player) end
    DDS.Server.markDirty(username)
    return true
end

function Bd.select(username, id)
    local list, ps = roster(username)
    local b = list[id]
    if b == nil or b.status == "dead" or b.status == "left" then return false end
    local current = ps.activeBuddy and list[ps.activeBuddy] or nil
    if current and current ~= b then
        despawn(current)
        if current.status ~= "dead" and current.status ~= "left" then current.status = "idle" end
    end
    ps.activeBuddy = id
    return Bd.call(username)
end

function Bd.waitHere(username)
    local b = Bd.active(username)
    if b == nil then return end
    local player = DDS.playerByName(username)
    b.status = "waiting"
    if b.uid and player then
        local x, y, z = playerPos(player)
        DDS.ALife.holdAt(b.uid, x, y, z)
        DDS.ALife.say(b.uid, "[[I'll be here.|Don't take forever.|Holding.]]", 15)
    end
    DDS.Server.markDirty(username)
end

function Bd.dismiss(username)
    local b = Bd.active(username)
    if b == nil then return end
    if b.uid then DDS.ALife.say(b.uid, "[[Heading home. Call if you need me.|See you back at camp.|Don't die without me.]]", 15) end
    despawn(b)
    b.status = "idle"
    DDS.Server.markDirty(username)
end

function Bd.withPlayer(username, radius)
    local b = Bd.active(username)
    if b == nil then return false end
    if b.status == "riding" then return true end
    local player = DDS.playerByName(username)
    if player == nil or b.uid == nil then return not DDS.ALife.available() end
    local pos = DDS.ALife.position(b.uid)
    if pos == nil then return false end
    local x, y = playerPos(player)
    return DDS.dist(x, y, pos.x, pos.y) <= (radius or 15)
end

function Bd.assignForQuest(username, quest, buddyId)
    local list, ps = roster(username)
    if quest.buddyId then
        local b = list[quest.buddyId]
        if b == nil or b.status == "dead" or b.status == "left" then return false, "That partner is gone." end
        if ps.activeBuddy ~= b.id then Bd.select(username, b.id) else Bd.call(username) end
        return true
    end
    if buddyId and list[buddyId] then Bd.select(username, buddyId); return true end
    if Bd.active(username) then
        if Bd.active(username).status ~= "following" then Bd.call(username) end
        return true
    end
    for _, id in ipairs(ps.buddyOrder or {}) do
        local b = list[id]
        if b and b.status == "idle" then Bd.select(username, id); return true end
    end
    return false, "This job needs a partner. Recruit a buddy first (journal > Buddies)."
end

-- voice = { pool, index } for banter lines that exist in the voice pack.
function Bd.say(username, line, b, voice)
    b = b or Bd.active(username)
    if b == nil then return end
    local text = DDS.Text.render(line, { buddy = b })
    if DDS.Dialogue and DDS.Dialogue.stripTags then text = DDS.Dialogue.stripTags(text) end
    if b.uid then DDS.ALife.say(b.uid, text, 25) end
    DDS.Server.notify(username, b.first .. ": " .. text, "buddy")
    if voice and DDS.Dialogue and DDS.Dialogue.hash then
        local key = table.concat({ "buddy", b.personality, voice[1], tostring(voice[2]), b.female and "f" or "m" }, "|")
        local player = DDS.playerByName(username)
        if player then DDS.Net.toPlayer(player, "voice", { id = DDS.Dialogue.hash(key) }) end
    end
end

local function sayFrom(username, b, poolName)
    local mood = Bd.personalities[b.personality] or Bd.personalities.steady
    local pool = mood[poolName] or mood.idle
    local i = ZombRand(1, #pool + 1)
    Bd.say(username, pool[i], b, { poolName, i })
end

function Bd.tick(username, player)
    local b = Bd.active(username)
    if b == nil then return end
    local now = DDS.nowMs()
    if (Bd.lastFollow[username] or 0) + Bd.FOLLOW_MS > now then return end
    Bd.lastFollow[username] = now
    if b.status == "waiting" then return end
    local x, y, z = playerPos(player)

    -- Vehicles: ride along.
    if inVehicle(player) then
        if b.status ~= "riding" then
            despawn(b)
            b.status = "riding"
        end
        return
    elseif b.status == "riding" then
        b.status = "following"
    end

    if b.uid then
        local state = DDS.ALife.actorState(b.uid)
        if state == "dead" then
            b.uid = nil
            local sandbox = SandboxVars and SandboxVars.DeadDaysStory or {}
            if sandbox.BuddyMortal == true then
                b.status = "dead"
                DDS.State.chronicle(b.name .. " died beside " .. username .. ".", "loss")
                DDS.Server.notify(username, b.first .. " is dead.", "loss")
                DDS.Server.markDirty(username)
                return
            end
        elseif state == "gone" then
            b.uid = nil
        end
    end
    if b.uid == nil then
        spawn(username, b, player)
        return
    end
    local pos = DDS.ALife.position(b.uid)
    if pos and DDS.dist(x, y, pos.x, pos.y) > Bd.LEASH then
        -- Fell too far behind: they catch up off-screen.
        despawn(b)
        spawn(username, b, player)
        return
    end
    DDS.ALife.follow(b.uid, x, y, z)

    -- Banter and perks.
    local last = Bd.lastBanter[username] or 0
    if now - last > 240000 and ZombRand(100) < 25 then
        Bd.lastBanter[username] = now
        Bd.banter(username, b, player)
    end
end

function Bd.banter(username, b, player)
    local poolName = "idle"
    local hour = DDS.hourOfDay()
    if hour >= 21 or hour < 5 then poolName = "night" end
    local raining = false
    pcall(function() raining = RainManager.isRaining() == true end)
    if raining and ZombRand(2) == 0 then poolName = "rain" end
    local hurt = false
    pcall(function() hurt = player:getBodyDamage():getOverallBodyHealth() < 60 end)
    if hurt then poolName = "hurt" end
    sayFrom(username, b, poolName)
    -- Perk gifts once the bond is real.
    if b.loyalty >= 60 and ZombRand(100) < 30 then
        local gift = Bd.archetypes[b.archetype].gift
        local item = gift[ZombRand(1, #gift + 1)]
        if DDS.Items.give(player, item, 1) > 0 then
            DDS.Server.notify(username, b.first .. " hands you " .. DDS.Items.displayName(item) .. ".", "buddy")
        end
    end
end

---------------------------------------------------------------------------
-- Opinions and loyalty
---------------------------------------------------------------------------

function Bd.loyalty(username, idOrNil, delta, reason)
    local b = idOrNil and Bd.get(username, idOrNil) or Bd.active(username)
    if b == nil or b.status == "dead" or b.status == "left" then return end
    local before = b.loyalty
    b.loyalty = DDS.clamp(b.loyalty + delta, 0, 100)
    if b.loyalty <= 10 and before > 10 then
        b.status = "left"
        despawn(b)
        DDS.Server.notify(username, b.first .. " has left you.", "loss")
        DDS.State.chronicle(b.name .. " walked away from " .. username .. " and didn't look back.", "loss")
    end
    Bd.checkArc(username, b)
    DDS.Server.markDirty(username)
end

function Bd.react(username, tags, ctx)
    local b = Bd.active(username)
    if b == nil or b.status ~= "following" then return end
    local arch = Bd.archetypes[b.archetype]
    local mood = Bd.personalities[b.personality] or Bd.personalities.steady
    local delta = 0
    for _, tag in ipairs(tags) do
        if DDS.contains(arch.likes, tag) then delta = delta + 4 end
        if DDS.contains(arch.dislikes, tag) then delta = delta - 5 end
    end
    if delta == 0 then return end
    local pool = delta > 0 and mood.approve or mood.disapprove
    DDS.Server.notify(username, DDS.Text.render(pool[ZombRand(1, #pool + 1)], { buddy = b }), delta > 0 and "good" or "bad")
    Bd.loyalty(username, b.id, delta)
end

function Bd.onQuestDone(username, quest, success)
    local b = Bd.active(username)
    if b and b.status ~= "dead" and b.status ~= "left" then
        b.missions = (b.missions or 0) + (success and 1 or 0)
        Bd.loyalty(username, b.id, success and 3 or -2)
    end
    if quest.buddyId and quest.loyaltyStage then
        local lb = Bd.get(username, quest.buddyId)
        if lb and success then
            lb.stage = math.max(lb.stage or 0, quest.loyaltyStage)
            lb.offeredStage = nil
            if lb.stage >= 3 then
                DDS.Server.notify(username, lb.first .. "'s story is resolved. They'll follow you anywhere now.", "good")
            end
        elseif lb then
            lb.offeredStage = nil
        end
    end
end

function Bd.onKill(username, actor)
    local b = Bd.active(username)
    if b == nil or b.status ~= "following" then return end
    b.kills = (b.kills or 0) + 1
    if ZombRand(100) < 20 then
        sayFrom(username, b, "kill")
    end
end

function Bd.setFate(username, id, fate, ctx)
    local b = Bd.get(username, id) or Bd.active(username)
    if b == nil then return end
    if fate == "dead" then
        if b.uid then
            local shell = DDS.ALife.shell(b.uid)
            pcall(function() shell:Kill(nil) end)
        end
        b.status = "dead"
        DDS.State.chronicle(b.name .. " is gone.", "loss")
    elseif fate == "left" then
        despawn(b); b.status = "left"
    elseif fate == "devoted" then
        b.loyalty = 100
    end
    DDS.Server.markDirty(username)
end

-- Offer the next loyalty mission when the bond is strong enough.
function Bd.checkArc(username, b)
    if b.status == "dead" or b.status == "left" or b.offeredStage then return end
    local thresholds = { 40, 60, 80 }
    local nextStage = (b.stage or 0) + 1
    if nextStage > 3 or b.loyalty < thresholds[nextStage] then return end
    local templateId = "loyalty_" .. b.backstory .. "_" .. nextStage
    if DDS.Quests.templates[templateId] == nil then return end
    b.offeredStage = nextStage
    DDS.Quests.offerTemplate(username, templateId, { buddyId = b.id, loyaltyStage = nextStage, requiresBuddy = true, arc = "loyalty" })
end

---------------------------------------------------------------------------
-- View
---------------------------------------------------------------------------

function Bd.view(username)
    local list, ps = roster(username)
    local rows = {}
    for _, id in ipairs(ps.buddyOrder or {}) do
        local b = list[id]
        if b then
            local mood = b.loyalty >= 80 and "Devoted" or b.loyalty >= 60 and "Close" or b.loyalty >= 40 and "Trusting"
                or b.loyalty >= 20 and "Uneasy" or "Losing faith"
            rows[#rows + 1] = {
                id = b.id, name = b.name, role = b.archLabel, personality = DDS.titleCase(b.personality), loyalty = b.loyalty,
                mood = mood, status = b.status, active = ps.activeBuddy == b.id, bio = b.bio,
                perk = Bd.archetypes[b.archetype].perk, stage = b.stage or 0, missions = b.missions or 0, kills = b.kills or 0,
                likes = table.concat(Bd.archetypes[b.archetype].likes, ", "),
                dislikes = table.concat(Bd.archetypes[b.archetype].dislikes, ", "),
            }
        end
    end
    return rows
end

return Bd
