-- Buddy loyalty arcs. Four backstories, three missions each. Unlocked as a
-- buddy's loyalty climbs (40 / 60 / 80). The buddy must come along.

require "DeadDaysStory/DDS_StoryKit"

local K = DDS.Kit
local B = DDS.Quests.B
local Q = DDS.Quests
local N = DDS.Names

local function pal(ctx)
    local b = DDS.Buddies.get(ctx.username, ctx.overrides and ctx.overrides.buddyId)
    if b == nil then return nil end
    return { id = b.id, first = b.first, last = b.last, name = b.name, he = b.he, him = b.him, his = b.his,
        He = b.He, His = b.His, story = b.story or {} }
end

-- Persist per-buddy story facts across the three missions.
local function story(ctx)
    local b = DDS.Buddies.get(ctx.username, ctx.overrides and ctx.overrides.buddyId)
    if b == nil then return {} end
    b.story = b.story or {}
    return b.story
end

local function loyalty(def)
    def.arc = "loyalty"
    return Q.define(def)
end

---------------------------------------------------------------------------
-- THE BROTHER: a sibling who joined the wrong side.
---------------------------------------------------------------------------

loyalty({
    id = "loyalty_brother_1",
    build = function(ctx)
        local p = pal(ctx); if p == nil then return nil end
        local st = story(ctx)
        st.sibling = st.sibling or N.person(ctx.rng, false)
        st.siblingFaction = st.siblingFaction or DDS.Factions.pickEnemy(ctx.rng).id
        local house = K.site(ctx, { "house" }, 200, 600)
        st.oldHouse = { x = house.x, y = house.y, name = house.name }
        return {
            title = p.first .. ": Blood",
            summary = p.first .. " finally told you: " .. p.his .. " brother, " .. st.sibling.first
                .. ", ran off with the " .. DDS.ALife.factionName(st.siblingFaction) .. " in August. " .. p.He .. " wants to know why. The answer might be at their old house.",
            giver = p.name, site = house, risk = 2, vars = { pal = p, sib = st.sibling },
            steps = {
                B.step("house", "Go home with {pal.first}", { B.reach("Reach " .. house.name, house, house.radius + 8) }),
                B.step("search", "Search {sib.first}'s room", {
                    B.search("Search {sib.first}'s room", "Search the room", house.inner, { type = "Base.Notebook", name = "{sib.first}'s notebook" },
                        { doneLine = "Pages of tally marks. Then: 'They feed you. They don't ask questions. That's more than here.'" }),
                }),
                B.step("talk", "Talk to {pal.first}", { B.radio("Talk to {pal.first}", "loyalty_brother_1:talk", "{pal.first}") }),
            },
            reward = K.reward(ctx, "small"),
            onComplete = { { "loyalty", nil, 8 } },
        }
    end,
    dialogues = {
        talk = { radio = true, start = "a", nodes = {
            a = { speaker = "{pal.name}", role = "pal", text = "'They don't ask questions.' That's my brother all over. He never wanted to explain himself. I asked too many questions. Maybe that's why he left.",
                choices = {
                    { text = "This isn't your fault.", next = "b", tags = { "mercy" } },
                    { text = "We'll find {sib.him}. Then you can ask.", next = "c", tags = { "loyal" } },
                } },
            b = { speaker = "{pal.name}", role = "pal", text = "It feels like it is. But thanks. I needed somebody to say that.", ["end"] = true },
            c = { speaker = "{pal.name}", role = "pal", text = "Yeah. We will.", ["end"] = true },
        } },
    },
})

loyalty({
    id = "loyalty_brother_2",
    build = function(ctx)
        local p = pal(ctx); if p == nil then return nil end
        local st = story(ctx)
        if st.sibling == nil then return nil end
        local camp = K.site(ctx, { "gas", "motel", "warehouse", "bar" }, 300, 900)
        return {
            title = p.first .. ": The Camp",
            summary = "Word is " .. st.sibling.first .. " rides with a " .. DDS.ALife.factionName(st.siblingFaction) .. " crew out of " .. camp.name .. ". " .. p.first .. " wants to talk. The crew won't want to.",
            giver = p.name, site = camp, risk = 4, vars = { pal = p, sib = st.sibling },
            steps = {
                B.step("reach", "Find the camp", { B.reach("Reach " .. camp.name, camp, camp.radius + 25) }),
                B.step("crew", "Get to {sib.first}", {
                    B.eliminate("Get past the crew", st.siblingFaction, K.guards(ctx, 3), camp),
                }),
                K.meet("sib", "{sib.first}", st.siblingFaction, st.sibling.name, K.point(camp, 1), "loyalty_brother_2:sib",
                    { npc = { mortal = true } }),
            },
            reward = K.reward(ctx, "medium"),
        }
    end,
    dialogues = {
        sib = { start = "a", nodes = {
            a = { speaker = "{sib.name}", role = "sib", text = "Of course it's you. You shot my friends just to come say hi? That's about right.",
                choices = {
                    { text = "{pal.first} wants you to come home.", next = "home" },
                    { text = "[Persuade] There's nothing for you here but a bullet with your name on it.", check = { kind = "persuade", base = 0.4 },
                        pass = "yes", fail = "no" },
                    { text = "[Let {pal.first} handle it]", next = "pal" },
                } },
            home = { speaker = "{sib.name}", role = "sib", text = "Home is a fence and a prayer meeting. No thanks.", next = "pal" },
            pal = { speaker = "{pal.name}", role = "pal", text = "Please just come. Not for me. For Mom. She'd want us together. You know she would.",
                choices = {
                    { text = "[Persuade] Listen to {pal.him}.", check = { kind = "persuade", base = 0.5 }, pass = "yes", fail = "no" },
                } },
            yes = { speaker = "{sib.name}", role = "sib", text = "God, you two are exhausting. Fine. I'll come. Don't hug me.",
                effects = { { "loyalty", nil, 15 }, { "releaseNpc", nil, "Don't hug me." }, { "pflag", "siblingHome" } }, ["end"] = true },
            no = { speaker = "{sib.name}", role = "sib", text = "No. Go home. Don't come back here. Next time they'll shoot you, and I won't stop them.",
                effects = { { "loyalty", nil, -5 }, { "releaseNpc", nil, "Go home." }, { "pflag", "siblingRefused" } }, ["end"] = true },
        } },
    },
})

loyalty({
    id = "loyalty_brother_3",
    build = function(ctx)
        local p = pal(ctx); if p == nil then return nil end
        local st = story(ctx)
        if st.sibling == nil then return nil end
        local ps = DDS.State.player(ctx.username)
        local came = ps.flags.siblingHome == true
        local site = K.site(ctx, { "church", "house", "gas" }, 200, 700)
        local steps
        if came then
            steps = {
                B.step("raid", "They want {sib.first} back", {
                    B.reach("Meet {pal.first} at " .. site.name, site, site.radius + 10),
                    B.hold("Hold off the crew that came for {sib.first}", site, 120, st.siblingFaction, { waves = 3, waveSize = 3 }),
                }),
                B.step("end", "Afterward", { B.radio("Talk to {pal.first}", "loyalty_brother_3:came", "{pal.first}") }),
            }
        else
            steps = {
                B.step("find", "Find {sib.first}", { B.reach("Follow the smoke to " .. site.name, site, site.radius + 15) }),
                B.step("bodies", "What's left", {
                    B.search("Search the bodies", "Search", site.inner, { type = "Base.Necklace_DogTag", name = "{sib.first}'s necklace" }),
                }),
                B.step("end", "Afterward", { B.radio("Talk to {pal.first}", "loyalty_brother_3:lost", "{pal.first}") }),
            }
        end
        return {
            title = p.first .. ": Kin",
            summary = came and ("The crew wants " .. st.sibling.first .. " back, and they're coming to take " .. st.sibling.him .. ".")
                or ("Smoke over " .. site.name .. ". " .. p.first .. " knows before you get there."),
            giver = p.name, site = site, risk = came and 4 or 2, vars = { pal = p, sib = st.sibling },
            steps = steps,
            reward = K.reward(ctx, "large"),
            onComplete = { { "loyalty", nil, 15 } },
        }
    end,
    dialogues = {
        came = { radio = true, start = "a", nodes = {
            a = { speaker = "{pal.name}", role = "pal", text = "He took a bullet for me back there. Just like when we were kids and he'd take the blame for the broken window. I don't know how to thank you. I'm going to spend a long time trying.",
                ["end"] = true, effects = { { "chronicle", "{pal.name} and {sib.name} are together again." } } },
        } },
        lost = { radio = true, start = "a", nodes = {
            a = { speaker = "{pal.name}", role = "pal", text = "He didn't come because I asked wrong. That's what I'm always going to think. Can you just stay here a while? You don't have to say anything.",
                choices = {
                    { text = "[Stay]", ["end"] = true, effects = { { "loyalty", nil, 10 } }, tags = { "loyal", "mercy" } },
                    { text = "We have to keep moving.", ["end"] = true, effects = { { "loyalty", nil, -5 } }, tags = { "cold" } },
                } },
        } },
    },
})

---------------------------------------------------------------------------
-- THE DEBT: owed to dangerous people.
---------------------------------------------------------------------------

loyalty({
    id = "loyalty_debt_1",
    build = function(ctx)
        local p = pal(ctx); if p == nil then return nil end
        local st = story(ctx)
        st.creditor = st.creditor or N.person(ctx.rng, false)
        st.creditorFaction = st.creditorFaction or (DDS.Factions.pickFaction(ctx.rng, { "crime", "gang", "club" }, nil) or {}).id
        local drop = K.site(ctx, { "bar", "gas", "motel" }, 200, 700)
        local payment = ctx.rng:pick({ { type = "Base.Whiskey", count = 2, label = "bottles of whiskey" },
            { type = "Base.Bullets9mmBox", count = 2, label = "boxes of 9mm" }, { type = "Base.Antibiotics", count = 2, label = "antibiotics" } })
        return {
            title = p.first .. ": The Payment",
            summary = p.first .. " owes " .. st.creditor.name .. " of the " .. DDS.ALife.factionName(st.creditorFaction)
                .. ". Since before July. The payment's due at " .. drop.name .. " and " .. p.he .. " can't make it alone.",
            giver = p.name, site = drop, risk = 2, vars = { pal = p, cred = st.creditor },
            steps = {
                K.meet("pay", "Meet {cred.first}", st.creditorFaction, st.creditor.name, K.point(drop, 1), "loyalty_debt_1:meet"),
                B.step("hand", "Pay", { B.handin("Pay " .. payment.count .. " " .. payment.label, { payment }, K.point(drop, 1)) }),
            },
            reward = K.reward(ctx, "small"),
            onComplete = { { "loyalty", nil, 8 } },
        }
    end,
    dialogues = {
        meet = { start = "a", nodes = {
            a = { speaker = "{cred.name}", role = "cred", text = "Brought a friend this time. Sweet. The interest went up, by the way. World ended. Prices go up.",
                choices = {
                    { text = "Just take the payment.", ["end"] = true },
                    { text = "[Intimidate] The interest just went back down.", check = { kind = "intimidate", base = 0.35 }, pass = "down", fail = "up", tags = { "defiant" } },
                } },
            down = { speaker = "{cred.name}", role = "cred", text = "Ha. Sure. Original terms. For now.", ["end"] = true, effects = { { "loyalty", nil, 5 } } },
            up = { speaker = "{cred.name}", role = "cred", text = "Cute. Now it's double next time.", ["end"] = true, effects = { { "pflag", "debtDoubled" } } },
        } },
    },
})

loyalty({
    id = "loyalty_debt_2",
    build = function(ctx)
        local p = pal(ctx); if p == nil then return nil end
        local st = story(ctx)
        if st.creditor == nil then return nil end
        local vault = K.site(ctx, { "police", "office", "warehouse" }, 300, 900)
        return {
            title = p.first .. ": One Last Job",
            summary = st.creditor.first .. " offered to clear " .. p.first .. "'s debt for one job: an evidence locker in " .. vault.name .. ". It's never one job.",
            giver = p.name, site = vault, risk = 3, vars = { pal = p, cred = st.creditor },
            steps = {
                B.step("in", "Get in", {
                    B.reach("Reach " .. vault.name, vault, vault.radius + 10),
                    B.lock("Get through the side door", "Side door", K.point(vault, 1), { difficulty = 0.4 }),
                }),
                B.step("locker", "Crack the locker", {
                    B.search("Find the code (optional)", "Search the duty desk", K.point(vault, 2), { type = "Base.Key1", name = "Locker key", key = true }, { optional = true }),
                    B.lock("Open the evidence locker", "Evidence locker", K.point(vault, 3), { keyQuestItem = true, difficulty = 0.7 }),
                }),
                B.step("take", "Take the package", {
                    B.retrieve("Take the package", K.point(vault, 3), "Base.Briefcase", "{cred.first}'s package"),
                }),
                B.step("choice", "Decide", { B.radio("Talk to {pal.first}", "loyalty_debt_2:choice", "{pal.first}") }),
            },
            reward = K.reward(ctx, "medium"),
        }
    end,
    dialogues = {
        choice = { radio = true, start = "a", nodes = {
            a = { speaker = "{pal.name}", role = "pal", text = "I looked inside. It's a ledger. Names. Every family they're squeezing. Mine's on page two. Yours is on page nine. We could hand it over. Or we could burn it.",
                choices = {
                    { text = "Burn it.", ["end"] = true, effects = { { "pflag", "ledgerBurned" }, { "loyalty", nil, 10 } }, tags = { "defiant", "mercy" } },
                    { text = "Give it to {cred.him}. Clear your debt.", ["end"] = true, effects = { { "pflag", "ledgerGiven" }, { "loyalty", nil, 3 } }, tags = { "pragmatic" } },
                    { text = "Keep it. Leverage.", ["end"] = true, effects = { { "pflag", "ledgerKept" } }, tags = { "clever", "greed" } },
                } },
        } },
    },
})

loyalty({
    id = "loyalty_debt_3",
    build = function(ctx)
        local p = pal(ctx); if p == nil then return nil end
        local st = story(ctx)
        if st.creditor == nil then return nil end
        local ps = DDS.State.player(ctx.username)
        local site = K.site(ctx, { "bar", "warehouse", "gas", "motel" }, 250, 800)
        local steps
        if ps.flags.ledgerGiven then
            steps = { K.meet("free", "Collect", st.creditorFaction, st.creditor.name, K.point(site, 1), "loyalty_debt_3:free") }
        else
            steps = {
                B.step("reach", "End it", { B.reach("Reach " .. site.name, site, site.radius + 15) }),
                B.step("fight", "End it", { B.eliminate("Break " .. st.creditor.first .. "'s crew", st.creditorFaction, K.guards(ctx, 4), site) }),
            }
        end
        return {
            title = p.first .. ": Paid in Full",
            summary = "One way or another, " .. p.first .. "'s debt ends today at " .. site.name .. ".",
            giver = p.name, site = site, risk = ps.flags.ledgerGiven and 1 or 4, vars = { pal = p, cred = st.creditor },
            steps = steps,
            reward = K.reward(ctx, "large"),
            onComplete = { { "loyalty", nil, 15 }, { "chronicle", "{pal.name} doesn't owe anybody anything anymore." } },
        }
    end,
    dialogues = {
        free = { start = "a", nodes = {
            a = { speaker = "{cred.name}", role = "cred", text = "Ledger's back where it belongs. The debt's clear. Pleasure doing business. If you ever want work...",
                choices = { { text = "{pal.he} doesn't.", ["end"] = true, effects = { { "loyalty", nil, 5 } } } } },
        } },
    },
})

---------------------------------------------------------------------------
-- HOME: the house they left in July.
---------------------------------------------------------------------------

loyalty({
    id = "loyalty_home_1",
    build = function(ctx)
        local p = pal(ctx); if p == nil then return nil end
        local st = story(ctx)
        local house = K.site(ctx, { "house" }, 250, 900)
        st.house = { x = house.x, y = house.y, name = house.name }
        st.family = st.family or N.person(ctx.rng, true)
        return {
            title = p.first .. ": The House on " .. house.town,
            summary = p.first .. " left home in July without " .. st.family.first .. ". " .. p.He .. " has never gone back. " .. p.He .. " wants to now.",
            giver = p.name, site = house, risk = 2, vars = { pal = p, fam = st.family },
            steps = {
                B.step("go", "Go home", { B.reach("Reach " .. house.name, house, house.radius + 8),
                    B.infected("Clear the street", ctx.rng:int(8, 16), house, house.radius + 30) }),
                B.step("search", "Look for {fam.first}", {
                    B.search("Search upstairs", "Search the bedroom", K.point(house, 1), { type = "Base.Photo", name = "Photo of {fam.first}" },
                        { doneLine = "A photo, and a note on the back: 'Went to the shelter at the school. Come find me. - {fam.first}'" }),
                }),
            },
            reward = K.reward(ctx, "small"),
            onComplete = { { "loyalty", nil, 8 } },
        }
    end,
})

loyalty({
    id = "loyalty_home_2",
    build = function(ctx)
        local p = pal(ctx); if p == nil then return nil end
        local st = story(ctx)
        if st.family == nil then return nil end
        local school = K.site(ctx, { "school", "church", "library" }, 250, 900)
        st.fate = st.fate or ctx.rng:pick({ "alive", "grave", "turned" })
        return {
            title = p.first .. ": The Shelter",
            summary = "The note said the shelter at the school. " .. school.name .. " is the closest. " .. p.first .. " hasn't said a word since you found it.",
            giver = p.name, site = school, risk = 3, vars = { pal = p, fam = st.family },
            steps = {
                B.step("go", "Reach the shelter", { B.reach("Reach " .. school.name, school, school.radius + 10) }),
                B.step("clear", "Clear the shelter", { B.infected("Clear the gym", ctx.rng:int(15, 25), school, school.radius + 15) }),
                B.step("records", "Find the sign-in sheets", {
                    B.search("Search the office", "Search the office", K.point(school, 1), { type = "Base.Paperwork", name = "Shelter sign-in sheets" },
                        { doneLine = "{fam.first}'s name. Then, in a different hand: 'Transferred.' Just that." }),
                }),
            },
            reward = K.reward(ctx, "medium"),
            onComplete = { { "loyalty", nil, 8 } },
        }
    end,
})

loyalty({
    id = "loyalty_home_3",
    build = function(ctx)
        local p = pal(ctx); if p == nil then return nil end
        local st = story(ctx)
        if st.family == nil then return nil end
        local site = K.site(ctx, { "church", "house", "warehouse" }, 300, 1000)
        local steps = { B.step("go", "Follow 'Transferred'", { B.reach("Reach " .. site.name, site, site.radius + 10) }) }
        if st.fate == "alive" then
            steps[#steps + 1] = K.meet("found", "{fam.first}", (DDS.Factions.pickCivilian(ctx.rng) or {}).id, st.family.name, K.point(site, 1), "loyalty_home_3:alive")
        elseif st.fate == "grave" then
            steps[#steps + 1] = B.step("grave", "The graves", {
                B.interact("Find {fam.first}'s grave", "Read the grave markers", K.point(site, 1), { duration = 200,
                    doneLine = "A cross. {fam.first}'s name, misspelled. Somebody tried." }),
            })
            steps[#steps + 1] = B.step("talk", "Stay", { B.radio("Be there for {pal.first}", "loyalty_home_3:grave", "{pal.first}") })
        else
            steps[#steps + 1] = B.step("turned", "{fam.first}", {
                B.infected("End it for {pal.first}", 1, site, site.radius + 10),
            }, { say = "{pal.first}: 'That's - that's {fam.his} coat. Oh no. No.'" })
            steps[#steps + 1] = B.step("talk", "Afterward", { B.radio("Be there for {pal.first}", "loyalty_home_3:turned", "{pal.first}") })
        end
        return {
            title = p.first .. ": Transferred",
            summary = "'Transferred' meant " .. site.name .. ". Whatever's there, " .. p.first .. " needs to see it.",
            giver = p.name, site = site, risk = 2, vars = { pal = p, fam = st.family },
            steps = steps,
            reward = K.reward(ctx, "large"),
            onComplete = { { "loyalty", nil, 15 } },
        }
    end,
    dialogues = {
        alive = { start = "a", nodes = {
            a = { speaker = "{fam.name}", role = "fam", text = "Is that... oh my God. They told me everyone from our street was gone. Come here. Come here.",
                effects = { { "chronicle", "{pal.name} found {fam.name} alive." } }, choices = {
                    { text = "[Give them a moment]", ["end"] = true, effects = { { "loyalty", nil, 10 } }, tags = { "mercy" } } } },
        } },
        grave = { radio = true, start = "a", nodes = {
            a = { speaker = "{pal.name}", role = "pal", text = "Somebody buried her. Somebody I'll never meet took the time to do it. I keep thinking about that more than anything.",
                choices = { { text = "We'll be that somebody for someone else.", ["end"] = true, tags = { "mercy", "loyal" } },
                    { text = "[Say nothing. Stay.]", ["end"] = true, effects = { { "loyalty", nil, 5 } } } } },
        } },
        turned = { radio = true, start = "a", nodes = {
            a = { speaker = "{pal.name}", role = "pal", text = "Thank you for doing it so I didn't have to. I'm going to be angry at you for a while. Not much. Just a little.",
                ["end"] = true },
        } },
    },
})

---------------------------------------------------------------------------
-- GUILT: they left people behind.
---------------------------------------------------------------------------

loyalty({
    id = "loyalty_guilt_1",
    build = function(ctx)
        local p = pal(ctx); if p == nil then return nil end
        local st = story(ctx)
        local site = K.site(ctx, { "hospital", "school", "police" }, 300, 1000)
        st.guiltSite = { x = site.x, y = site.y, name = site.name }
        st.survivor = st.survivor or N.person(ctx.rng, true)
        return {
            title = p.first .. ": The Evacuation",
            summary = p.first .. " was supposed to hold the doors at " .. site.name .. " in July. " .. p.He .. " didn't. " .. p.He .. " wants to see what happened to the people inside.",
            giver = p.name, site = site, risk = 3, vars = { pal = p },
            steps = {
                B.step("go", "Go back", { B.reach("Reach " .. site.name, site, site.radius + 10) }),
                B.step("inside", "Go inside", {
                    B.infected("Clear the halls", ctx.rng:int(18, 30), site, site.radius + 10),
                    B.search("Find the evacuation roster", "Search the front desk", K.point(site, 1), { type = "Base.Paperwork", name = "Evacuation roster" },
                        { doneLine = "Most names crossed out. One circled: " .. st.survivor.name .. ". 'Got out - east door.'" }),
                }),
            },
            reward = K.reward(ctx, "small"),
            onComplete = { { "loyalty", nil, 8 } },
        }
    end,
})

loyalty({
    id = "loyalty_guilt_2",
    build = function(ctx)
        local p = pal(ctx); if p == nil then return nil end
        local st = story(ctx)
        if st.survivor == nil then return nil end
        local site = K.site(ctx, { "house", "church", "motel" }, 250, 900)
        return {
            title = p.first .. ": The One Who Got Out",
            summary = st.survivor.name .. " got out of the east door. " .. st.survivor.first .. " lives at " .. site.name .. " now. " .. p.first .. " has to face " .. st.survivor.him .. ".",
            giver = p.name, site = site, risk = 1, vars = { pal = p, surv = st.survivor },
            steps = { K.meet("face", "Face {surv.first}", (DDS.Factions.pickCivilian(ctx.rng) or {}).id, st.survivor.name, K.point(site, 1), "loyalty_guilt_2:face") },
            reward = K.reward(ctx, "small"),
        }
    end,
    dialogues = {
        face = { start = "a", nodes = {
            a = { speaker = "{surv.name}", role = "surv", text = "I know you. You were on the doors that night. You ran. My husband didn't get out. And now you show up here. Why?",
                choices = {
                    { text = "[Let {pal.first} speak]", next = "pal" },
                    { text = "[Persuade] {pal.he}'s spent every day since trying to make up for it.", check = { kind = "persuade", base = 0.4 }, pass = "soft", fail = "hard" },
                } },
            pal = { speaker = "{pal.name}", role = "pal", text = "Because I'm sorry. I know that isn't enough. I needed to hear you say it to my face.",
                next = "judge" },
            soft = { speaker = "{surv.name}", role = "surv", text = "Every day? Okay. I don't forgive you. But I'll stop hating you. That's what I've got.",
                effects = { { "loyalty", nil, 12 }, { "pflag", "guiltEased" } }, ["end"] = true },
            hard = { speaker = "{surv.name}", role = "surv", text = "Don't you speak for them. Get out. Both of you.",
                effects = { { "loyalty", nil, -3 } }, ["end"] = true },
            judge = { speaker = "{surv.name}", role = "surv", text = "You're shaking. You really mean it. Then do something with it. There are people at the old co-op who are starving. Help them. That's what I want.",
                effects = { { "pflag", "guiltPrice" }, { "loyalty", nil, 8 } }, ["end"] = true },
        } },
    },
})

loyalty({
    id = "loyalty_guilt_3",
    build = function(ctx)
        local p = pal(ctx); if p == nil then return nil end
        local site = K.site(ctx, { "warehouse", "church", "school", "supermarket" }, 250, 900)
        local need = { { type = "Base.TinnedBeans", count = 6, label = "tins of food" }, { type = "Base.WaterBottle", count = 4, label = "water bottles" },
            { type = "Base.Bandage", count = 4, label = "bandages" } }
        return {
            title = p.first .. ": Amends",
            summary = "Some people at " .. site.name .. " are starving. " .. p.first .. " wants to be the one who shows up this time.",
            giver = p.name, site = site, risk = 2, vars = { pal = p },
            steps = {
                B.step("bring", "Bring what they need", {
                    B.npc((DDS.Factions.pickCivilian(ctx.rng) or {}).id, "Survivor", K.point(site, 1)),
                    B.handin("Deliver food, water and bandages", need, K.point(site, 1)),
                }),
                B.step("hold", "Hold the doors", {
                    B.hold("Hold the doors while they eat. This time, nobody runs.", site, 120, nil, { waves = 3, zombieWave = 10 }),
                }),
            },
            reward = K.reward(ctx, "large"),
            onComplete = { { "loyalty", nil, 15 }, { "chronicle", "{pal.name} held the doors at " .. site.name .. ". Nobody ran." } },
        }
    end,
})

return true
