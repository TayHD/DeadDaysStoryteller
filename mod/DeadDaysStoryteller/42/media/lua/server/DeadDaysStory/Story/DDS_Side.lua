-- Procedural side work. Every template rolls its own place, people, faction,
-- shape and complications. Weighted by what the world needs right now.

require "DeadDaysStory/DDS_StoryKit"

local K = DDS.Kit
local B = DDS.Quests.B
local Q = DDS.Quests
local N = DDS.Names

local function person(ctx, female)
    return N.person(ctx.rng, female)
end

local function giverFaction(ctx)
    local f = DDS.Factions.pickFriendly(ctx.rng)
    return f
end

local function enemyFaction(ctx)
    return DDS.Factions.pickEnemy(ctx.rng)
end

local function side(def)
    def.arc = def.arc or "side"
    return Q.define(def)
end

---------------------------------------------------------------------------
-- Rescue
---------------------------------------------------------------------------

side({
    id = "side_rescue",
    weight = function(ctx) return 10 end,
    build = function(ctx)
        local giver = giverFaction(ctx)
        local enemy = enemyFaction(ctx)
        local victim = person(ctx)
        local asker = person(ctx)
        local site = K.site(ctx, { "mall", "school", "hospital", "warehouse", "motel", "church", "gas", "police", "supermarket" }, 250, 1000)
        local twist = ctx.rng:pick({ "none", "none", "spy", "recruit", "dead" })
        local steps = K.shapeRescue(ctx, { site = site, name = victim.first, captorRole = enemy.id,
            captiveFaction = (DDS.Factions.pickCivilian(ctx.rng) or giver).id, guards = 3,
            freeDialogue = "side_rescue:free" })
        steps[#steps + 1] = B.step("report", "Tell " .. asker.first, {
            B.radio("Radio " .. asker.first, "side_rescue:report", asker.name .. " (" .. giver.name .. ")"),
        })
        return {
            title = "[[Taken|Ransom|Gone Missing|No One Left Behind]]: " .. victim.first,
            summary = asker.name .. " of the " .. giver.name .. " says " .. victim.name .. " was taken by the " .. enemy.name
                .. " and is being held at " .. site.name .. ".",
            giver = asker.name, site = site, risk = 3,
            vars = { victim = victim, asker = asker, giverF = giver, enemyF = enemy, site = site, twist = twist },
            steps = steps,
            reward = K.reward(ctx, "medium", giver.id),
            standingReward = { [giver.id] = 12, [enemy.id] = -6 },
            deadlineHours = 72,
            onComplete = { { "chronicle", victim.name .. " was pulled out of " .. site.name .. "." } },
        }
    end,
    dialogues = {
        free = { start = "r", nodes = {
            r = { route = { { cond = { "var", "twist", "spy" }, next = "spy" }, { cond = { "var", "twist", "recruit" }, next = "recruit" },
                { next = "plain" } }, text = "" },
            plain = { speaker = "{victim.name}", role = "victim",
                text = { "You're not one of them. Okay. Okay. Get me out of here.", "I didn't think anyone was coming. Thank you.",
                    "My hands. Can you get my hands? Thank you. Let's go." },
                ["end"] = true },
            spy = { speaker = "{victim.name}", role = "victim",
                text = "Sorry. Really. They said they'd let my family go if I got somebody to walk in here. They're outside.",
                effects = { { "ambush", "{enemyF.id}", 3 }, { "var", "betrayed", true }, { "toast", "It was a setup.", "danger" } },
                ["end"] = true },
            recruit = { speaker = "{victim.name}", role = "victim",
                text = "I can drive and I can shoot a little. I don't have anybody left. If you need someone to watch your back, I'll do it.",
                choices = {
                    { text = "Then come with me.", ["end"] = true, effects = { { "recruit", "rescued" } } },
                    { text = "Go back to your people first. Get your strength back.", ["end"] = true },
                } },
        } },
        report = { radio = true, start = "a", nodes = {
            a = { route = { { cond = { "var", "betrayed", true }, next = "bait" }, { next = "ok" } }, text = "" },
            ok = { speaker = "{asker.name}", role = "asker",
                text = "You got them out? Thank God. We owe you. We won't forget this.",
                ["end"] = true },
            bait = { speaker = "{asker.name}", role = "asker",
                text = "A setup? We vouched for them. I'm sorry. I really am. Take what we promised you. Take a little more.",
                effects = { { "reward", "small" } }, ["end"] = true },
        } },
    },
})

---------------------------------------------------------------------------
-- Supply run
---------------------------------------------------------------------------

side({
    id = "side_supply",
    weight = function(ctx) return 10 end,
    build = function(ctx)
        local giver = giverFaction(ctx)
        local asker = person(ctx)
        local what = ctx.rng:pick({
            { kinds = { "pharmacy", "hospital" }, item = "Base.Bag_DuffelBag", name = "Medical supplies", why = "fever's going through the camp" },
            { kinds = { "supermarket", "restaurant", "gas" }, item = "Base.Bag_DuffelBag", name = "Food cache", why = "the root cellar flooded" },
            { kinds = { "warehouse", "office", "school" }, item = "Base.Toolbox", name = "Generator parts", why = "the generator died" },
            { kinds = { "gunstore", "police" }, item = "Base.Bag_DuffelBag", name = "Ammunition cache", why = "the {antagonist.name} have been probing the fence" },
        })
        local site = K.site(ctx, what.kinds, 200, 800)
        local home = K.site(ctx, { "house", "church", "motel", "warehouse" }, 150, 500)
        local steps, facts = K.shapeSupply(ctx, { site = site, itemType = what.item, itemName = what.name,
            deliverTo = K.point(home, 1), deliverFaction = giver.id, deliverName = asker.name })
        return {
            title = "[[Supply Run|Shopping List|Empty Shelves]]: " .. what.name,
            summary = asker.name .. " of the " .. giver.name .. " needs " .. string.lower(what.name) .. " - " .. what.why .. ". Try " .. site.name .. ".",
            giver = asker.name, site = site, risk = 2, vars = { asker = asker, giverF = giver },
            steps = steps,
            reward = K.reward(ctx, "medium", giver.id),
            standingReward = { [giver.id] = 10 },
            deadlineHours = 96,
        }
    end,
})

---------------------------------------------------------------------------
-- Bounty
---------------------------------------------------------------------------

side({
    id = "side_bounty",
    weight = function(ctx) return 8 end,
    build = function(ctx)
        local enemy = enemyFaction(ctx)
        local giver = giverFaction(ctx)
        local target = person(ctx, false)
        target.moniker = ctx.rng:pick(N.lieutenantMoniker)
        local site = K.site(ctx, { "gas", "motel", "bar", "warehouse", "house" }, 300, 1100)
        local crime = ctx.rng:pick({ "burned the Hensley farm with the family inside", "has been robbing refugees on 31W",
            "shot a medic under a white flag", "sells people to {warlord.moniker}", "poisoned a well on the river road" })
        local steps = K.shapeBounty(ctx, { site = site, role = enemy.id, guards = 3,
            title = "Hunt " .. target.moniker, killText = "Kill " .. target.moniker .. " and the crew",
            bark = "[[It's a bounty hunter!|" .. target.moniker .. " said this would happen!|Get down!]]" })
        steps[#steps + 1] = B.step("proof", "Bring proof", {
            B.search("Take " .. target.moniker .. "'s dog tags", "Search the body", K.point(site, 1),
                { type = "Base.Necklace_DogTag", name = target.moniker .. "'s dog tags" }, { optional = true }),
        })
        return {
            title = "Bounty: " .. target.moniker,
            summary = target.name .. ", called " .. target.moniker .. ", " .. crime .. ". The " .. giver.name .. " want him gone. Last seen near " .. site.name .. ".",
            giver = giver.name, site = site, risk = 4,
            steps = steps,
            reward = K.reward(ctx, "large", giver.id),
            standingReward = { [giver.id] = 10, [enemy.id] = -10 },
            deadlineHours = 120,
            onComplete = { { "chronicle", target.moniker .. " won't " .. crime .. " anymore." } },
        }
    end,
})

---------------------------------------------------------------------------
-- Distress signal (incident, time-limited, hidden outcome)
---------------------------------------------------------------------------

side({
    id = "side_distress",
    arc = "incident",
    weight = function(ctx) return 6 end,
    build = function(ctx)
        local site = K.site(ctx, { "house", "church", "gas", "motel", "school" }, 150, 600)
        local voice = person(ctx)
        local outcome = ctx.rng:pick({ "real", "real", "trap", "late" })
        local steps = { B.step("reach", "Answer the distress call", { B.reach("Get to " .. site.name .. ". Fast.", site, site.radius + 10) }) }
        if outcome == "real" then
            steps[#steps + 1] = B.step("defend", "Hold until they're out", {
                B.allies((DDS.Factions.pickCivilian(ctx.rng) or {}).id, 2, site.inner),
                B.hold("Hold off the dead while " .. voice.first .. "'s family gets out", site, 100, nil, { waves = 3, zombieWave = 9 }),
            })
        elseif outcome == "trap" then
            steps[#steps + 1] = B.step("trap", "It's a trap", {
                B.eliminate("Survive the ambush", DDS.Factions.pickEnemy(ctx.rng).id, K.guards(ctx, 3), site, { mode = "assault" }),
            }, { say = "[[The radio's on a loop. Nobody's here. Then the doors slam.|A tape recorder by the window. The voice keeps begging. Footsteps outside.]]" })
        else
            steps[#steps + 1] = B.step("late", "Too late", {
                B.search("Search the house", "Search the bodies", site.inner,
                    { type = "Base.Journal", name = voice.first .. "'s journal" }, { doneLine = "The last entry is two days old. It ends mid-sentence." }),
            }, { say = "[[The door's open. It's quiet. Too quiet.|You smell it before you see it.]]" })
        end
        return {
            title = "Distress: " .. voice.first,
            summary = "A voice on the emergency band - " .. voice.name .. " - says they're trapped at " .. site.name .. " with family. It sounds real. It always sounds real.",
            giver = voice.name, site = site, risk = 3, offerHours = 4, deadlineHours = 6,
            vars = { voice = voice, outcome = outcome },
            steps = steps,
            reward = K.reward(ctx, outcome == "real" and "medium" or "small"),
            standingReward = outcome == "real" and { community = 5 } or nil,
            onComplete = { { "chronicle", outcome == "real" and (voice.name .. "'s family made it out of " .. site.name .. ".")
                or (outcome == "trap" and ("The distress call from " .. site.name .. " was bait. Whoever set it is dead now."))
                or ("Nobody answered " .. voice.name .. "'s call in time.") } },
        }
    end,
})

---------------------------------------------------------------------------
-- Recon (A-Life outpost if possible)
---------------------------------------------------------------------------

side({
    id = "side_recon",
    weight = function(ctx) return 6 end,
    build = function(ctx)
        local enemy = enemyFaction(ctx)
        local x, y = K.origin(ctx)
        local outpost = K.findOutpost(enemy.id, x, y)
        local site
        if outpost and DDS.dist(x, y, outpost.x, outpost.y) < 1500 then
            site = { x = outpost.x, y = outpost.y, z = 0, radius = 30, inner = { x = outpost.x, y = outpost.y, z = 0 },
                points = { { x = outpost.x, y = outpost.y, z = 0 } }, name = "the " .. enemy.name .. " outpost", label = "outpost",
                key = "outpost:" .. outpost.id }
        else
            site = K.site(ctx, { "warehouse", "gas", "motel", "police" }, 300, 900)
        end
        local giver = DDS.Factions.pickFriendly(ctx.rng)
        return {
            title = "Recon: " .. enemy.name,
            summary = "The " .. giver.name .. " want to know how many guns the " .. enemy.name .. " have at " .. site.name .. ". Look, count, don't touch.",
            giver = giver.name, site = site, risk = 2,
            steps = K.shapeRecon(ctx, { site = site, intelName = enemy.name .. " duty roster" }),
            reward = K.reward(ctx, "small", giver.id),
            standingReward = { [giver.id] = 8 },
            onComplete = { { "power", "antagonist", -2 } },
        }
    end,
})

---------------------------------------------------------------------------
-- Courier (political: read the letter?)
---------------------------------------------------------------------------

side({
    id = "side_courier",
    weight = function(ctx) return 6 end,
    build = function(ctx)
        local from = giverFaction(ctx)
        local to = DDS.Factions.pickFaction(ctx.rng, { "law", "worker", "family", "civilian", "rescue", "military" }, { "neutral", "careful", "friendly" }, { [from.id] = true }) or from
        local sender, receiver = person(ctx), person(ctx)
        local dest = K.site(ctx, { "house", "church", "gas", "bar", "office" }, 300, 900)
        local secret = ctx.rng:pick({
            "an offer to split the {antagonist.name}'s territory once they fall",
            "a confession: " .. sender.first .. " was the one who opened the gate in August",
            "a list of names: who in " .. from.name .. " is sick",
            "a love letter, of all things. Three pages.",
            "a warning that the {military.name} are planning something called {saga.operation}",
        })
        return {
            title = "Courier: Sealed Letter",
            summary = sender.name .. " of the " .. from.name .. " needs a sealed letter carried to " .. receiver.name .. " of the " .. to.name .. " at " .. dest.name .. ". Don't open it.",
            giver = sender.name, site = dest, risk = 1,
            vars = { sender = sender, receiver = receiver, fromF = from, toF = to, secret = secret },
            steps = {
                B.step("carry", "Carry the letter", {
                    B.reach("Reach " .. dest.name, dest, dest.radius + 10),
                    B.radio("[Optional] Read the letter", "side_courier:read", "The letter", { optional = true }),
                }, { onStart = { { "give", "Base.LetterHandwritten", 1, "Sealed letter for " .. receiver.first } } }),
                K.meet("deliver", "Deliver it", to.id, receiver.name, K.point(dest, 1), "side_courier:deliver"),
            },
            reward = K.reward(ctx, "small", to.id),
            standingReward = { [from.id] = 6, [to.id] = 6 },
        }
    end,
    dialogues = {
        read = { radio = true, start = "a", nodes = {
            a = { speaker = "", text = "You thumb the seal. It comes away easier than it should. Inside: {secret}",
                effects = { { "var", "read", true } },
                choices = {
                    { text = "[Reseal it carefully]", ["end"] = true },
                    { text = "[Keep a copy]", ["end"] = true, effects = { { "pflag", "letterCopies" } }, tags = { "clever" } },
                } },
        } },
        deliver = { start = "a", nodes = {
            a = { route = { { cond = { "var", "read", true }, next = "suspicious" }, { next = "plain" } }, text = "" },
            plain = { speaker = "{receiver.name}", role = "receiver",
                text = "Finally. I've been waiting on this for weeks. Here, for your trouble. I'll send my answer back some other way.",
                effects = { { "take", "Base.LetterHandwritten", 1 } }, ["end"] = true },
            suspicious = { speaker = "{receiver.name}", role = "receiver",
                text = "The seal's been opened. Don't lie to me. Did you read it?",
                choices = {
                    { text = "No.", check = { kind = "lie", base = 0.5 }, pass = "fine", fail = "caught" },
                    { text = "Yes. I'm sorry.", next = "honest", tags = { "honest" } },
                } },
            fine = { speaker = "{receiver.name}", role = "receiver", text = "Fine. Here.", effects = { { "take", "Base.LetterHandwritten", 1 } }, ["end"] = true },
            caught = { speaker = "{receiver.name}", role = "receiver", text = "You're lying. Get out. My people will hear about this.",
                effects = { { "take", "Base.LetterHandwritten", 1 }, { "standing", "{toF.id}", -15 } }, ["end"] = true },
            honest = { speaker = "{receiver.name}", role = "receiver", text = "At least you told me. Most people wouldn't. Keep it to yourself.",
                effects = { { "take", "Base.LetterHandwritten", 1 }, { "standing", "{toF.id}", 3 } }, ["end"] = true },
        } },
    },
})

---------------------------------------------------------------------------
-- Missing patrol
---------------------------------------------------------------------------

side({
    id = "side_missing",
    weight = function(ctx)
        local s = ctx.saga
        return (s and s.act >= 2) and 6 or 2
    end,
    build = function(ctx)
        local s = ctx.saga
        local mil = s and K.f("military") or DDS.Factions.pickFaction(ctx.rng, { "military", "law" }).id
        local site = K.site(ctx, { "house", "gas", "school", "warehouse" }, 300, 900)
        local culprit = ctx.rng:pick({ "antagonist", "wildcard", "deserted" })
        local steps = {
            B.step("find", "Find the patrol", { B.reach("Reach their last position: " .. site.name, site, site.radius + 15) }),
            B.step("search", "Search the area", {
                B.search("Search the first body", "Search body", K.point(site, 1), { type = "Base.Necklace_DogTag", name = "Dog tags" }),
                B.search("Search the second body", "Search body", K.point(site, 2), { type = "Base.Necklace_DogTag", name = "Dog tags" }),
                B.search("Look for the radio", "Search for the radio", K.point(site, 3), { type = "Base.WalkieTalkie3", name = "Patrol radio" }, { optional = true }),
            }),
        }
        if culprit == "deserted" then
            steps[#steps + 1] = K.meet("deserter", "Someone's alive", mil, "Private " .. person(ctx).last, K.point(site, 1), "side_missing:deserter")
        else
            steps[#steps + 1] = B.step("report", "Report back", { B.radio("Radio it in", "side_missing:report", "{officer.callsign}") })
        end
        return {
            title = "Missing Patrol",
            summary = "A {military.name} patrol went silent near " .. site.name .. " two days ago. Find out why.",
            giver = "{officer.callsign}", site = site, risk = 3, vars = { culprit = culprit },
            steps = steps,
            reward = K.reward(ctx, "medium", "military"),
            standingReward = { military = 10 },
        }
    end,
    dialogues = {
        report = { radio = true, start = "a", nodes = {
            a = { route = { { cond = { "var", "culprit", "wildcard" }, next = "wild" }, { next = "anta" } }, text = "" },
            anta = { speaker = "{officer.callsign}", role = "officer",
                text = "Road crew shell casings. That's what I figured. Thank you for bringing the tags back. Their families should have something. Out.",
                effects = { { "standing", "military", 3 }, { "power", "military", 2 } }, ["end"] = true },
            wild = { speaker = "{officer.callsign}", role = "officer",
                text = "Those casings don't match the road crew's weapons. It was somebody else. That changes things. Out.",
                effects = { { "flag", "falseFlagKnown" }, { "standing", "wildcard", -10 } }, ["end"] = true },
        } },
        deserter = { start = "a", nodes = {
            a = { speaker = "Private", role = "private",
                text = "Don't shoot. I'm alone. It wasn't an ambush. The sergeant shot them because they refused an order. I ran. Are you taking me back?",
                choices = {
                    { text = "What order?", next = "order" },
                    { text = "You're coming back with me.", next = "back", tags = { "lawful" } },
                    { text = "Go. Get out of the county.", next = "go", tags = { "mercy" } },
                } },
            order = { speaker = "Private", role = "private",
                text = "To take everything from a family on the river road. Food, fuel, their truck. They had kids. Please don't make me say the rest.",
                effects = { { "flag", "deserterTestimony" } }, next = "a2" },
            a2 = { speaker = "Private", role = "private", text = "So what happens to me?",
                choices = {
                    { text = "You're coming back with me.", next = "back", tags = { "lawful" } },
                    { text = "Go. Get out of the county.", next = "go", tags = { "mercy" } },
                    { text = "Go to {saga.settlement}. They'll want to hear this.", next = "settle", tags = { "loyal" } },
                } },
            back = { speaker = "Private", role = "private", text = "Yeah. Okay.", effects = { { "standing", "military", 10 }, { "releaseNpc", nil, "..." } }, ["end"] = true },
            go = { speaker = "Private", role = "private", text = "Thank you.", effects = { { "standing", "military", -5 }, { "releaseNpc", nil, "Thank you." } }, ["end"] = true },
            settle = { speaker = "Private", role = "private", text = "If they'll take me.", effects = { { "standing", "community", 5 }, { "power", "community", 2 }, { "standing", "military", -10 },
                { "releaseNpc", nil, "I'll find it." } }, ["end"] = true },
        } },
    },
})

---------------------------------------------------------------------------
-- Horde nest
---------------------------------------------------------------------------

side({
    id = "side_nest",
    weight = function(ctx) return 6 end,
    build = function(ctx)
        local giver = giverFaction(ctx)
        local site = K.site(ctx, { "school", "hospital", "mall", "supermarket", "church", "warehouse" }, 200, 800)
        local n = ctx.rng:int(25, 45)
        return {
            title = "Nest: " .. site.label,
            summary = "The dead have packed into " .. site.name .. " and every noise draws more. The " .. giver.name .. " can't farm the fields around it until it's cleared.",
            giver = giver.name, site = site, risk = 3,
            steps = {
                B.step("clear", "Clear the nest", {
                    B.reach("Reach " .. site.name, site, site.radius + 30),
                    B.infected("Kill the infected around " .. site.label, n, site, site.radius + 40),
                }),
            },
            reward = K.reward(ctx, "medium", giver.id),
            standingReward = { [giver.id] = 8 },
        }
    end,
})

---------------------------------------------------------------------------
-- Trade run (hand-in)
---------------------------------------------------------------------------

side({
    id = "side_trade",
    weight = function(ctx) return 5 end,
    build = function(ctx)
        local giver = DDS.Factions.pickFaction(ctx.rng, { "worker", "family", "civilian", "rescue", "law", "crime" }, { "neutral", "friendly", "careful" })
        local trader = person(ctx)
        local want = ctx.rng:pick({
            { { type = "Base.Battery", count = 4, label = "batteries" } },
            { { type = "Base.TinnedBeans", count = 6, label = "tins of beans" } },
            { { type = "Base.Bandage", count = 8, label = "bandages" } },
            { { type = "Base.Nails", count = 40, label = "nails" }, { type = "Base.Plank", count = 6, label = "planks" } },
            { { type = "Base.Whiskey", count = 2, label = "bottles of whiskey" }, { type = "Base.CigarettePack", count = 2, label = "packs of smokes" } },
        })
        local list = {}
        for _, w in ipairs(want) do list[#list + 1] = w.count .. " " .. w.label end
        return {
            title = "Trade: " .. giver.name,
            summary = trader.name .. " of the " .. giver.name .. " will trade for " .. table.concat(list, " and ") .. ". Leave it at the drop and they'll pay up.",
            giver = trader.name, risk = 1,
            steps = { B.step("trade", "Make the trade", { B.handin("Hand over " .. table.concat(list, ", "), want, nil, { label = "Leave at the drop" }) }) },
            reward = K.reward(ctx, "medium", giver.id),
            standingReward = { [giver.id] = 10 },
            offerHours = 72,
        }
    end,
})

---------------------------------------------------------------------------
-- Dispute (political)
---------------------------------------------------------------------------

side({
    id = "side_dispute",
    weight = function(ctx) return 5 end,
    build = function(ctx)
        local a = DDS.Factions.pickFaction(ctx.rng, { "family", "civilian", "worker", "rescue" }, { "neutral", "friendly", "careful" })
        local b = DDS.Factions.pickFaction(ctx.rng, { "family", "civilian", "worker", "law", "crime" }, { "neutral", "careful", "friendly" }, { [a.id] = true }) or a
        local repA, repB = person(ctx), person(ctx)
        local prize = ctx.rng:pick({ "the only clean well on Route 9", "a field of winter wheat", "a working diesel generator",
            "the Kessinger silo and what's in it", "a two-way radio tower" })
        local site = K.site(ctx, { "church", "house", "gas", "warehouse" }, 200, 700)
        return {
            title = "Dispute: " .. a.name .. " and " .. b.name,
            summary = "The " .. a.name .. " and the " .. b.name .. " both claim " .. prize .. ". Somebody's going to get shot. Both sides agreed to let an outsider decide. That's you.",
            giver = "Both sides", site = site, risk = 2,
            vars = { aF = a, bF = b, repA = repA, repB = repB, prize = prize },
            steps = {
                K.meet("hearA", "Hear " .. repA.first .. " out", a.id, repA.name, K.point(site, 1), "side_dispute:a"),
                K.meet("hearB", "Hear " .. repB.first .. " out", b.id, repB.name, K.point(site, 2), "side_dispute:b"),
                B.step("decide", "Decide", { B.radio("Give your judgment", "side_dispute:decide", "Both sides, listening") }),
            },
            reward = K.reward(ctx, "small"),
        }
    end,
    dialogues = {
        a = { start = "a", nodes = {
            a = { speaker = "{repA.name}", role = "repA",
                text = "We found it first. We've got twelve people and two of them are babies. They've got more guns than we do and they don't like us. That's the whole story.",
                choices = { { text = "I hear you.", ["end"] = true }, { text = "Would you share it?", next = "share" } } },
            share = { speaker = "{repA.name}", role = "repA",
                text = "With people who shot at us in August? Maybe. If they apologize. They won't.", effects = { { "var", "aShares", true } }, ["end"] = true },
        } },
        b = { start = "a", nodes = {
            a = { speaker = "{repB.name}", role = "repB",
                text = "We held that place all summer. We buried four people defending it. They moved in the week we went out for supplies. That's not finding it. That's taking it.",
                choices = { { text = "I hear you.", ["end"] = true }, { text = "Would you share it?", next = "share" } } },
            share = { speaker = "{repB.name}", role = "repB",
                text = "If they work it alongside us. Not for us. Alongside.", effects = { { "var", "bShares", true } }, ["end"] = true },
        } },
        decide = { radio = true, start = "a", nodes = {
            a = { speaker = "", text = "Both sides are waiting. Whatever you say, one of them is going to remember it for a long time.",
                choices = {
                    { text = "[The {aF.name}] It's theirs.", ["end"] = true, tags = { "mercy" },
                        effects = { { "standing", "{aF.id}", 15 }, { "standing", "{bF.id}", -15 }, { "chronicle", "{prize} went to the {aF.name}." } } },
                    { text = "[The {bF.name}] It's theirs.", ["end"] = true, tags = { "lawful" },
                        effects = { { "standing", "{bF.id}", 15 }, { "standing", "{aF.id}", -15 }, { "chronicle", "{prize} went to the {bF.name}." } } },
                    { text = "[Persuade] Share it. Both of you said you would.", cond = { "all", { "var", "aShares", true }, { "var", "bShares", true } },
                        check = { kind = "persuade", base = 0.55 }, pass = "shared", fail = "noshare", tags = { "mercy", "clever" } },
                    { text = "Neither. I'm taking it.", ["end"] = true, tags = { "greed", "ruthless" },
                        effects = { { "standing", "{aF.id}", -20 }, { "standing", "{bF.id}", -20 }, { "reward", "large" },
                            { "chronicle", "Somebody took {prize} out from under both claimants." } } },
                } },
            shared = { speaker = "{repA.name}", role = "repA", text = "Fine. Fine. But they dig the latrine.", effects = { { "standing", "{aF.id}", 10 }, { "standing", "{bF.id}", 10 },
                { "chronicle", "The {aF.name} and {bF.name} agreed to share {prize}. Nobody died." } }, ["end"] = true },
            noshare = { speaker = "{repB.name}", role = "repB", text = "No. Not with them. Pick one.", next = "a" },
        } },
    },
})

---------------------------------------------------------------------------
-- Vault (lockpicking-focused heist)
---------------------------------------------------------------------------

side({
    id = "side_vault",
    weight = function(ctx) return 4 end,
    build = function(ctx)
        local site = K.site(ctx, { "police", "office", "gunstore", "warehouse" }, 300, 1000)
        local tipster = person(ctx)
        return {
            title = "The Vault at " .. site.label,
            summary = tipster.name .. " swears there's an untouched evidence locker in " .. site.name .. ". Two doors, one key somewhere inside, and a whole lot of noise if you do it wrong.",
            giver = tipster.name, site = site, risk = 3,
            steps = {
                B.step("outer", "Get inside", {
                    B.reach("Reach " .. site.name, site, site.radius + 10),
                    B.lock("Pick or pry the side door", "Side door", K.point(site, 1), { difficulty = 0.35, pryZombies = 8 }),
                }),
                B.step("key", "Find the locker key", {
                    B.search("Search the duty desk", "Search the duty desk", K.point(site, 2),
                        { type = "Base.Key1", name = "Locker key", key = true }, { optional = true }),
                    B.lock("Open the evidence locker", "Evidence locker", K.point(site, 3), { keyQuestItem = true, difficulty = 0.75, pryZombies = 12 }),
                }),
                B.step("loot", "Empty the locker", {
                    B.search("Take what's inside", "Empty the locker", K.point(site, 3), { type = "Base.Bag_DuffelBag", name = "Evidence bag" }),
                }),
            },
            reward = K.reward(ctx, "large"),
        }
    end,
})

---------------------------------------------------------------------------
-- The Long Road (multi-day chain)
---------------------------------------------------------------------------

side({
    id = "long_letters",
    arc = "chain",
    weight = function(ctx) return 3 end,
    build = function(ctx)
        local seeker = person(ctx)
        local missing = person(ctx)
        local sites = {}
        for i = 1, 4 do sites[i] = K.site(ctx, { "house", "church", "gas", "school", "motel", "library" }, 200 + i * 150, 600 + i * 250) end
        local fate = ctx.rng:pick({ "alive", "dead", "turned", "changed" })
        local steps = {}
        for i = 1, 4 do
            steps[#steps + 1] = B.step("p" .. i, "Letter " .. i .. " of 4", {
                B.reach("Follow the trail to " .. sites[i].name, sites[i], sites[i].radius + 10),
                B.search("Find " .. missing.first .. "'s letter", "Search", K.point(sites[i], 1),
                    { type = "Base.LetterHandwritten", name = missing.first .. "'s letter #" .. i },
                    { doneLine = ctx.rng:pick({ "'Still heading north. Feet are bad. Thinking of you.'", "'Met a family. They're kind. I'm not staying.'",
                        "'Something followed me last night. Not dead. Worse.'", "'If you're reading this, I'm close. Don't stop.'" }) }),
            })
            if i < 4 then
                steps[#steps + 1] = B.step("w" .. i, "The trail goes cold for a while", { B.wait("Wait for " .. seeker.first .. " to decode the next clue", 6 + i * 4) })
            end
        end
        steps[#steps + 1] = B.step("end", "The end of the road", {
            B.radio("Tell " .. seeker.first, "long_letters:end", seeker.name),
        })
        return {
            title = "The Long Road: " .. missing.first,
            summary = seeker.name .. " has been following letters left by " .. missing.name .. " since July. Four drop points. Days apart. " .. seeker.first .. " can't walk anymore. You can.",
            giver = seeker.name, risk = 2, vars = { seeker = seeker, missing = missing, fate = fate, last = sites[4] },
            steps = steps,
            reward = K.reward(ctx, "large"),
            offerHours = 96,
        }
    end,
    dialogues = {
        ["end"] = { radio = true, start = "a", nodes = {
            a = { route = { { cond = { "var", "fate", "alive" }, next = "alive" }, { cond = { "var", "fate", "dead" }, next = "dead" },
                { cond = { "var", "fate", "turned" }, next = "turned" }, { next = "changed" } }, text = "" },
            alive = { speaker = "{seeker.name}", role = "seeker",
                text = "Alive? You're sure? You saw them? Okay. Okay. I'm going. I don't care about my legs. Tell me exactly where.",
                effects = { { "chronicle", "{seeker.name} found {missing.name} alive." } }, ["end"] = true },
            dead = { speaker = "{seeker.name}", role = "seeker",
                text = "A grave. With the name scratched on the cross. Okay. At least I know. At least somebody buried them. Thank you for going.",
                ["end"] = true },
            turned = { speaker = "{seeker.name}", role = "seeker",
                text = "You saw them? Walking around? Did you... did you put them down? Please tell me you did.",
                choices = { { text = "I did.", ["end"] = true }, { text = "I couldn't.", ["end"] = true, effects = { { "pflag", "couldntEndIt" } } } } },
            changed = { speaker = "{seeker.name}", role = "seeker",
                text = "Alive, and doesn't want to come back. Running with one of those crews now. Huh. I spent all summer walking toward someone who walked away.",
                ["end"] = true },
        } },
    },
})

---------------------------------------------------------------------------
-- Settlement project (long-running build-up)
---------------------------------------------------------------------------

side({
    id = "long_project",
    arc = "chain",
    weight = function(ctx)
        local s = ctx.saga
        if s == nil then return 0 end
        return (s.flags.projectDone and 0) or 3
    end,
    build = function(ctx)
        local s = ctx.saga
        local project = ctx.rng:pick({
            { name = "Seeds for Spring", stages = {
                { { type = "Base.Rope", count = 2, label = "rope" }, { type = "Base.Hammer", count = 1, label = "hammer" } },
                { { type = "Base.Plank", count = 10, label = "planks" }, { type = "Base.Nails", count = 30, label = "nails" } },
                { { type = "Base.WaterBottle", count = 6, label = "water bottles" }, { type = "Base.TinnedBeans", count = 6, label = "tins of beans" } } },
              done = "{saga.settlement}'s fields are planted. Something green is coming up." },
            { name = "The Watchtower", stages = {
                { { type = "Base.Plank", count = 12, label = "planks" } },
                { { type = "Base.Nails", count = 50, label = "nails" }, { type = "Base.Hammer", count = 1, label = "hammer" } },
                { { type = "Base.WalkieTalkie3", count = 1, label = "walkie-talkie" }, { type = "Base.Battery", count = 4, label = "batteries" } } },
              done = "{saga.settlement} has a watchtower. Nobody sneaks up on them anymore." },
            { name = "The Clinic", stages = {
                { { type = "Base.Bandage", count = 10, label = "bandages" } },
                { { type = "Base.Disinfectant", count = 3, label = "disinfectant" }, { type = "Base.SutureNeedle", count = 3, label = "suture needles" } },
                { { type = "Base.Antibiotics", count = 2, label = "antibiotics" }, { type = "Base.Pills", count = 3, label = "painkillers" } } },
              done = "{saga.settlement} has a real clinic. Fewer graves this winter." },
        })
        local at = K.point(s.home, 3)
        local steps = {}
        for i, stage in ipairs(project.stages) do
            steps[#steps + 1] = B.step("s" .. i, project.name .. ": stage " .. i .. " of " .. #project.stages, {
                B.npc(K.f("community"), "Builder", at),
                B.handin("Bring materials", stage, at, { label = "Hand over materials" }),
            })
            if i < #project.stages then
                steps[#steps + 1] = B.step("b" .. i, "They're building", { B.wait("Give them time to build", 12) })
            end
        end
        return {
            title = "Project: " .. project.name,
            summary = "{leader.name} wants to build something that'll outlast this winter: " .. string.lower(project.name) .. ". It'll take days and a lot of hauling.",
            giver = "{leader.name}", risk = 1, steps = steps,
            reward = K.reward(ctx, "large", "community"),
            standingReward = { community = 20 },
            offerHours = 24 * 7,
            onComplete = { { "power", "community", 12 }, { "flag", "projectDone" }, { "chronicle", project.done } },
        }
    end,
})

---------------------------------------------------------------------------
-- Daily ops
---------------------------------------------------------------------------

local function daily(def)
    def.arc = "daily"
    return Q.define(def)
end

daily({
    id = "daily_infected",
    build = function(ctx)
        local n = ctx.rng:int(15, 35)
        return {
            title = "Daily: Thin the Herd", summary = "Every dead one you drop today is one fewer at somebody's fence.",
            giver = "{leader.name}", risk = 1, offerHours = 24, deadlineHours = 30,
            steps = { B.step("kill", "Kill infected", { B.infected("Kill infected anywhere", n) }) },
            reward = K.reward(ctx, "small", "community"), standingReward = { community = 3 },
        }
    end,
})

daily({
    id = "daily_scavenge",
    build = function(ctx)
        local want = ctx.rng:pick({
            { type = "Base.TinnedBeans", count = 3, label = "tins of beans" }, { type = "Base.Bandage", count = 4, label = "bandages" },
            { type = "Base.WaterBottle", count = 3, label = "water bottles" }, { type = "Base.Battery", count = 2, label = "batteries" },
            { type = "Base.Nails", count = 25, label = "nails" }, { type = "Base.Plank", count = 4, label = "planks" },
        })
        return {
            title = "Daily: " .. DDS.titleCase(want.label), summary = "{saga.settlement} is short on " .. want.label .. ". Leave " .. want.count .. " at the drop.",
            giver = "{leader.name}", risk = 1, offerHours = 24, deadlineHours = 30,
            steps = { B.step("bring", "Bring supplies", { B.handin("Leave " .. want.count .. " " .. want.label .. " at the drop", { want }, nil, { label = "Leave at the drop" }) }) },
            reward = K.reward(ctx, "small", "community"), standingReward = { community = 4 },
        }
    end,
})

daily({
    id = "daily_patrol",
    build = function(ctx)
        local x, y = K.origin(ctx)
        local a = DDS.Sites.ring(x, y, 120, 260, ctx.rng)
        local b = DDS.Sites.ring(x, y, 120, 260, ctx.rng)
        return {
            title = "Daily: Patrol", summary = "Walk the perimeter. Two points. Eyes open.",
            giver = "{leader.name}", risk = 1, offerHours = 24, deadlineHours = 30,
            steps = { B.step("walk", "Walk the patrol", { B.reach("Patrol point near " .. a.town, a, 10), B.reach("Patrol point near " .. b.town, b, 10) }) },
            reward = K.reward(ctx, "small", "community"), standingReward = { community = 3 },
        }
    end,
})

daily({
    id = "daily_hunt",
    build = function(ctx)
        local enemy = DDS.Factions.pickEnemy(ctx.rng)
        local n = ctx.rng:int(2, 4)
        return {
            title = "Daily: Pressure", summary = "Keep the " .. enemy.name .. " honest. Put " .. n .. " of them down today.",
            giver = "{leader.name}", risk = 2, offerHours = 24, deadlineHours = 30,
            steps = { B.step("hunt", "Hunt", { B.kills("Kill " .. enemy.name, enemy.id, n) }) },
            reward = K.reward(ctx, "medium", "community"), standingReward = { community = 4 },
        }
    end,
})

daily({
    id = "daily_check",
    build = function(ctx)
        local site = K.site(ctx, { "house" }, 100, 350)
        local who = person(ctx)
        return {
            title = "Daily: Check on the " .. who.last .. "s", summary = "Nobody's heard from the " .. who.last .. " place at " .. site.name .. " in days. Go look.",
            giver = "{leader.name}", site = site, risk = 1, offerHours = 24, deadlineHours = 30,
            steps = { B.step("check", "Check the house", {
                B.reach("Reach " .. site.name, site, site.radius + 5),
                B.search("Look around", "Search the house", site.inner, { type = "Base.Notebook", name = "The " .. who.last .. "s' diary" }),
            }) },
            reward = K.reward(ctx, "small", "community"), standingReward = { community = 3 },
        }
    end,
})

return true
