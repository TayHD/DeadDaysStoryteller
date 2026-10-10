-- Story kit: reusable mission shapes. Story chapters and procedural side work
-- both build from these, each with its own random variant, location, scale
-- and complications, so no two runs of the "same" mission play alike.

require "DeadDaysStory/DDS_Core"
require "DeadDaysStory/DDS_Quests"
require "DeadDaysStory/DDS_Saga"
require "DeadDaysStory/DDS_Sites"
require "DeadDaysStory/DDS_Items"

DDS.Kit = DDS.Kit or {}
local K = DDS.Kit
local B = DDS.Quests.B

function K.saga() return DDS.State.world().saga end

function K.f(role)
    return DDS.Factions.resolve(role)
end

function K.origin(ctx)
    if ctx.player then return ctx.x, ctx.y end
    local s = K.saga()
    if s then return s.anchor.x, s.anchor.y end
    return 10600, 9300
end

function K.site(ctx, kinds, minDist, maxDist)
    local x, y = K.origin(ctx)
    local site = DDS.Sites.pick(x, y, kinds, minDist or 250, maxDist or 900, ctx.rng, ctx.avoid)
    ctx.avoid[site.key] = true
    return site
end

-- Open ground a set distance from a point.
function K.ring(ctx, at, minDist, maxDist)
    return DDS.Sites.ring(at.x, at.y, minDist, maxDist, ctx.rng)
end

function K.point(site, i)
    local p = site.points and site.points[i]
    if p then return p end
    return site.inner or site
end

-- Difficulty scales with act, failures and how hot the player's life is.
function K.guards(ctx, base)
    local s = K.saga()
    local n = base + (s and math.floor((s.act - 1) / 2) or 0)
    local c = s and s.chapters and s.chapters[ctx.templateId or ""] or nil
    if c and c.failures then n = n + c.failures end
    n = n + ctx.rng:int(0, 1)
    return DDS.clamp(n, 1, 8)
end

function K.reward(ctx, tier, role)
    local bloc
    if role then
        local info = DDS.ALife.factionInfo(K.f(role))
        bloc = info and info.bloc or nil
    end
    return DDS.Items.rollReward(ctx.rng, tier, bloc)
end

-- Register a story chapter and its quest template in one go.
function K.chapter(def, template)
    template.id = def.id
    template.arc = "spine"
    local build = template.build
    template.build = function(ctx)
        ctx.templateId = def.id
        local q = build(ctx)
        if q then
            q.arc = "spine"
            q.world = true
            q.offerHours = 24 * 30
            q.chapterLine = def.line
        end
        return q
    end
    DDS.Saga.chapter(def)
    DDS.Quests.define(template)
    return template
end

-- A wrapper so content can write cond = K.side("community").
function K.side(name)
    return function(s) return s.choices and s.choices.side == name end
end
function K.twist(name)
    return function(s) return s.twists and s.twists[name] ~= nil end
end
function K.flag(name)
    return function(s) return s.flags and s.flags[name] end
end

---------------------------------------------------------------------------
-- Shapes. Each returns a list of steps plus a small table of facts the
-- caller can weave into text ({vars}).
---------------------------------------------------------------------------

-- Rescue: assault, stealth (lock + keys) or trade (meet, hand over, maybe double-cross).
function K.shapeRescue(ctx, o)
    local site = o.site
    local captor = K.f(o.captorRole or "antagonist")
    local captiveFaction = o.captiveFaction or (DDS.Factions.pickCivilian(ctx.rng) or {}).id
    local variant = o.variant or ctx.rng:pick({ "assault", "stealth", "trade" })
    local guards = K.guards(ctx, o.guards or 3)
    local inner = site.inner or site
    local name = o.name
    local cries = o.cries or {
        "[[Help! Somebody! In here!|Please... is someone out there?|I can hear you! I'm in the back!]]",
        "[[Don't leave me here.|They'll be back soon. Hurry.|I'm tied up, I can't-]]",
    }
    local steps = {}
    steps[#steps + 1] = B.step("approach", o.approachTitle or "Find " .. name, {
        B.reach(o.approachText or ("Get eyes on " .. site.name), site, site.radius + 30),
    }, { say = o.approachSay })
    if variant == "assault" then
        steps[#steps + 1] = B.step("breach", "Go in hard", {
            B.eliminate("Take down the guards", captor, guards, site, { bark = o.bark }),
            B.eliminate("Clear the back rooms", captor, math.max(1, guards - 2), inner, { optional = true }),
        })
        steps[#steps + 1] = B.step("free", "Free " .. name, {
            B.captive("Cut " .. name .. " loose", captiveFaction, name, inner, { cry = cries[1], cries = cries }),
        }, { dialogue = o.freeDialogue })
    elseif variant == "stealth" then
        local keyAt = K.point(site, 2)
        steps[#steps + 1] = B.step("infiltrate", "Get in quiet", {
            B.search("Lift the keys off the guard post", "Search the guard post", keyAt,
                { type = "Base.KeyRing", name = "Ring of keys", key = true }, { optional = true,
                doneLine = "A ring of keys. One of them is newer than the rest." }),
            B.lock("Get through the locked door", "Locked door", inner, { keyQuestItem = true, difficulty = 0.5 }),
            B.eliminate("Guards (avoid or remove)", captor, guards, site, { optional = true, bark = o.bark }),
        })
        steps[#steps + 1] = B.step("free", "Free " .. name, {
            B.captive("Cut " .. name .. " loose", captiveFaction, name, inner, { cry = cries[2], cries = cries }),
        }, { dialogue = o.freeDialogue })
    else
        -- Trade: bring what they asked for to a meet. Maybe they keep their word.
        local meet = K.ring(ctx, site, 25, 45)
        local price = o.price or ctx.rng:pick({
            { type = "Base.Bullets9mmBox", count = 3, label = "boxes of 9mm" },
            { type = "Base.Antibiotics", count = 2, label = "antibiotics" },
            { type = "Base.PetrolCan", count = 1, label = "can of gas" },
            { type = "Base.Whiskey", count = 2, label = "bottles of whiskey" },
        })
        local doubleCross = ctx.rng:chance(o.doubleCross or 0.45)
        steps[#steps + 1] = B.step("trade", "Make the trade", {
            B.npc(captor, "The broker", meet, { role = "broker" }),
            B.handin("Hand over " .. price.count .. " " .. price.label, { price }, meet,
                { label = "Make the trade", doneLine = doubleCross and "They take it. Then they smile." or "They take it. A nod toward the building." }),
        })
        if doubleCross then
            steps[#steps + 1] = B.step("crossed", "It's a setup", {
                B.eliminate("Survive the double-cross", captor, guards, meet, { mode = "assault", trigger = 140 }),
            }, { say = "[[Should've known.|Of course.|Never trust a smile out here.]]" })
        end
        steps[#steps + 1] = B.step("free", "Collect " .. name, {
            B.captive("Cut " .. name .. " loose", captiveFaction, name, inner, { cry = cries[1], cries = cries }),
            B.eliminate("Whoever's left inside", captor, 1, inner, { optional = true }),
        }, { dialogue = o.freeDialogue })
    end
    if o.escape ~= false then
        steps[#steps + 1] = B.step("escape", "Cover the escape", {
            B.hold(o.holdText or ("Hold " .. site.label .. " while " .. name .. " gets clear"), site,
                o.holdSeconds or 90, captor, { waves = 2, waveSize = math.max(2, guards - 1) }),
        })
    end
    return steps, { variant = variant, guards = guards }
end

-- Recon: three vantage points around a site, optional photographs/notes.
function K.shapeRecon(ctx, o)
    local site = o.site
    local pts = {}
    for i = 1, 3 do pts[i] = K.ring(ctx, site, 35, 60) end
    local steps = {
        B.step("watch", o.title or ("Scout " .. site.name), {
            B.reach("First vantage point", pts[1], 6),
            B.reach("Second vantage point", pts[2], 6),
            B.reach("Third vantage point", pts[3], 6),
            B.search("Grab their paperwork (optional)", "Search the lookout's table", K.point(site, 1),
                { type = "Base.Paperwork", name = o.intelName or "Patrol schedule" }, { optional = true }),
        }),
    }
    return steps
end

-- Supply run: get X from a place; complication rolled.
function K.shapeSupply(ctx, o)
    local site = o.site
    local complication = o.complication or ctx.rng:pick({ "none", "occupied", "locked", "horde" })
    local steps = {}
    local objectives = {
        B.retrieve(o.text or "Find the supplies", K.point(site, 1), o.itemType or "Base.Bag_DuffelBag", o.itemName or "Medical supplies"),
    }
    if complication == "occupied" then
        objectives[#objectives + 1] = B.eliminate("Someone got there first", K.f(o.rivalRole or "wildcard"),
            K.guards(ctx, 2), site, { optional = false })
    elseif complication == "locked" then
        table.insert(objectives, 1, B.lock("The storeroom's locked", "Storeroom door", K.point(site, 1), { difficulty = 0.55 }))
    elseif complication == "horde" then
        objectives[#objectives + 1] = B.infected("Clear the infected inside", ctx.rng:int(12, 22), site, site.radius + 20)
    end
    steps[#steps + 1] = B.step("get", o.title or ("Search " .. site.name), objectives)
    if o.deliverTo then
        steps[#steps + 1] = B.step("deliver", "Bring it back", {
            B.npc(o.deliverFaction or K.f("community"), o.deliverName or "Quartermaster", o.deliverTo),
            B.handin("Hand it over", { { quest = true } }, o.deliverTo, { label = "Hand over the supplies" }),
        })
    end
    return steps, { complication = complication }
end

-- Bounty: a named target in a camp or building, with an optional dog-tag proof.
function K.shapeBounty(ctx, o)
    local site = o.site
    local steps = {
        B.step("hunt", o.title or "Find the target", {
            B.reach(o.findText or ("Track them to " .. site.name), site, site.radius + 25),
        }),
        B.step("kill", o.killTitle or "Take them down", {
            B.eliminate(o.killText or "Kill the target and their crew", K.f(o.role or "antagonist"),
                K.guards(ctx, o.guards or 3), site, { mode = o.mode or "guard", bark = o.bark }),
        }),
    }
    return steps
end

-- Sabotage: cut an A-Life outpost radio if one exists for the faction,
-- otherwise a radio rig at a site.
function K.findOutpost(role, nearX, nearY)
    local factionId = K.f(role)
    local best, bestD
    for _, o in ipairs(DDS.ALife.outposts()) do
        if o.factionId == factionId and not o.commsDisabled then
            local d = DDS.dist(nearX, nearY, o.x, o.y)
            if bestD == nil or d < bestD then best, bestD = o, d end
        end
    end
    return best
end

function K.shapeSabotage(ctx, o)
    local x, y = K.origin(ctx)
    local outpost = K.findOutpost(o.role or "military", x, y)
    if outpost and DDS.dist(x, y, outpost.x, outpost.y) < 2500 then
        return {
            B.step("sabotage", o.title or "Cut their comms", {
                B.reach("Reach their outpost", { x = outpost.x, y = outpost.y, z = 0 }, 40),
                B.sabotage("Cut the radio", outpost),
            }),
        }, { outpost = true, x = outpost.x, y = outpost.y }
    end
    local site = o.site or K.site(ctx, { "police", "school", "warehouse", "military" }, 300, 900)
    return {
        B.step("sabotage", o.title or "Cut their comms", {
            B.eliminate("Deal with the radio team", K.f(o.role or "military"), K.guards(ctx, 2), site),
            B.interact("Smash the radio rig", "Smash the radio", K.point(site, 1), { duration = 140, noise = 25 }),
        }),
    }, { outpost = false, site = site }
end

-- Meet someone in person and talk. Returns step.
function K.meet(id, title, factionId, name, at, tree, extra)
    local objectives = {
        B.npc(factionId, name, at, extra and extra.npc or nil),
        B.talk("Talk to " .. name, tree, at, { npcIndex = 1, label = "Talk to " .. name }),
    }
    return B.step(id, title, objectives, extra and extra.step or nil)
end

-- Who speaks for the settlement right now.
function K.leaderKey()
    local s = K.saga()
    local gone = { deposed = true, arrested = true, dead = true, exiled = true }
    if s and not gone[s.cast.contact.status or ""] then return "contact" end
    if s and not gone[s.cast.doctor.status or ""] then return "doctor" end
    return "contact"
end

-- Talk at the settlement with someone from the cast.
function K.homeMeet(ctx, id, title, castKey, tree, extra)
    local s = K.saga()
    local c = s.cast[castKey]
    local at = K.point(s.home, castKey == "contact" and 1 or (castKey == "doctor" and 2 or 3))
    -- Tag the NPC with its cast key so the settlement's resident is reused.
    extra = extra or {}
    extra.npc = extra.npc or {}
    extra.npc.castKey = castKey
    return K.meet(id, title, K.f("community"), c.name, at, tree, extra)
end

return K
