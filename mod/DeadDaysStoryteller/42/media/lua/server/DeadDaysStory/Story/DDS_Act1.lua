-- ACT I: TAKEN
-- Storylines: the settlement, the crew on the roads, the ham operator, the kid.
-- Finale: getting the kid back.
--
-- Writing rules (all acts): people talk plainly, about concrete things. Spoken
-- lines (node.text) never contain names or places, so they can be voiced once
-- and shipped; names live in the speaker header, the player's choices and the
-- mission text. `role` = who is speaking; `byArch` = per-archetype versions.

require "DeadDaysStory/DDS_StoryKit"

local K = DDS.Kit
local B = DDS.Quests.B
local D = DDS.Dialogue

---------------------------------------------------------------------------
-- The first call
---------------------------------------------------------------------------

D.register("spine:intro", { radio = true, title = "Emergency channel", start = "a", nodes = {
    a = { speaker = "{contact.name}", role = "contact",
        text = "[hesitant] This is a recorded... no. [clears throat] No, this is live. If anyone's on this channel, we're a group of survivors, about thirty of us. We have a fence, a well, and a little food. If you're alone out there, you don't have to be.",
        choices = {
            { text = "I hear you. Who is this?", next = "b" },
            { text = "What do you want in return?", next = "c", tags = { "greed" } },
            { text = "How long have you been broadcasting?", next = "d" },
            { text = "[Turn the radio off]", ["end"] = true, effects = { { "pflag", "ignoredIntro" } } },
        } },
    b = { speaker = "{contact.name}", role = "contact",
        text = "I'm the one who ended up in charge, mostly because nobody else wanted it. We've got farmers, a mechanic, a couple of teachers. What we don't have is anyone who can go out on the roads and come back.",
        byArch = {
            caretaker = "I'm the one who ended up in charge, I guess. Somebody had to make the lists and keep people fed. We've got good people here. We just don't have anyone who can go out on the roads and come back.",
        },
        next = "e" },
    c = { speaker = "{contact.name}", role = "contact",
        text = "Fair question. A bed, a share of the food, somebody awake while you sleep. That's what we've got. In return we need help getting supplies. Medicine, mostly.",
        next = "e" },
    d = { speaker = "{contact.name}", role = "contact",
        text = "Every hour, for about a week. We run the radio off a car battery. You're the first person who's answered who didn't want something.",
        byArch = {
            survivor = "Every hour for a week, on a car battery. The last two people who answered wanted to know how many guns we had. So you'll understand if I'm careful.",
        },
        next = "e" },
    e = { speaker = "{contact.name}", role = "contact",
        text = "There's also a crew working the roads around here. They stop our people when they go out, take whatever they're carrying. Nobody's been killed yet. I'd like to keep it that way.",
        choices = {
            { text = "Who are they?", next = "f" },
            { text = "Where are you? I'll come to you.", next = "g", effects = { { "standing", "community", 5 }, { "trust", "contact", 10 } } },
            { text = "Not my problem.", next = "h", effects = { { "standing", "community", -3 } }, tags = { "cold" } },
        } },
    f = { speaker = "{contact.name}", role = "contact",
        text = "Local people, mostly. Some of them I knew before. They're hungry like everybody else, they've just decided it's easier to take it from us than find it. They're not stupid, and there's more of them every week.",
        choices = {
            { text = "Where are you? I'll come to you.", next = "g", effects = { { "standing", "community", 5 }, { "trust", "contact", 10 } } },
            { text = "I'll think about it.", next = "h" },
        } },
    g = { speaker = "{contact.name}", role = "contact",
        text = "Come in slow, from the road side, with your hands where we can see them. People here are jumpy. I'll tell them you're coming.",
        effects = { { "meet", "contact" } }, ["end"] = true },
    h = { speaker = "{contact.name}", role = "contact",
        text = "All right. We're on this channel every hour if you change your mind. Stay safe out there.",
        effects = { { "meet", "contact" } }, ["end"] = true },
} })

---------------------------------------------------------------------------
-- 1. The Fence (settlement)
---------------------------------------------------------------------------

K.chapter({ id = "a1_voices", act = 1, line = "community", title = "The Fence" }, {
    build = function(ctx)
        local s = ctx.saga
        local home = s.home
        return {
            title = "The Fence",
            summary = "{contact.name} has been on the emergency channel for a week. The group is holding out at {saga.settlement}. Go and see them.",
            giver = "{contact.name}",
            risk = 1,
            steps = {
                B.step("travel", "Go to {saga.settlement}", {
                    B.reach("Reach " .. home.name, home, home.radius + 10),
                }, { say = "[[Smoke from a chimney. Washing on a line.|You hear a generator before you see the fence.|Someone has painted HELP on the roof. Someone else painted over it.]]" }),
                K.homeMeet(ctx, "meet", "Talk to {contact.first}", "contact", "a1_voices:meet"),
                B.step("wire", "Clear the fence line", {
                    B.infected("Clear the infected along the fence", ctx.rng:int(10, 18), home, home.radius + 45),
                }),
                K.homeMeet(ctx, "doctor", "Talk to {doctor.first}", "doctor", "a1_voices:doctor"),
            },
            reward = K.reward(ctx, "medium", "community"),
            standingReward = { community = 10 },
            onComplete = { { "meet", "doctor" }, { "power", "community", 3 }, { "recruit", "starter" },
                { "chronicle", "A stranger came in to {saga.settlement} and stayed." } },
        }
    end,
    dialogues = {
        meet = { start = "a", nodes = {
            a = { speaker = "{contact.name}", role = "contact",
                text = "[relieved] You came. Good. Sorry about the rifle at the gate. In the summer we let a man in who said he was a trader. Two people didn't wake up.",
                byArch = {
                    caretaker = "[relieved] You came. Thank God. Sorry about the rifle at the gate. We let a man in over the summer who said he was a trader. We lost two people that night. We're more careful now.",
                },
                choices = {
                    { text = "How many people do you have here?", next = "people" },
                    { text = "How many of them can fight?", next = "guns" },
                    { text = "What do you need first?", next = "work" },
                } },
            people = { speaker = "{contact.name}", role = "contact",
                text = "Thirty-one this morning. Six kids. A few old folks who can't walk far. My {lost.kin} is here too. Most of us were neighbors before. Now we're all we've got.",
                effects = { { "meet", "lost" } }, next = "work" },
            guns = { speaker = "{contact.name}", role = "contact",
                text = "Maybe five who can shoot straight. Eleven rifles if you count the ones nobody has ammunition for. That's why they keep stopping us on the road. They know.",
                next = "work" },
            work = { speaker = "{contact.name}", role = "contact",
                text = "The fence. The dead pile up on the north side every night and we're using bullets we can't spare to keep it standing. Clear it out, then go and see our medic. There's a list.",
                choices = {
                    { text = "I'll take care of it.", ["end"] = true, effects = { { "trust", "contact", 5 } } },
                    { text = "And after that?", next = "after" },
                } },
            after = { speaker = "{contact.name}", role = "contact",
                text = "After that we talk about the road crew. Let's see how today goes first.",
                ["end"] = true },
        } },
        doctor = { start = "r", nodes = {
            r = { route = { { cond = { "flag", "moleIs_doctor" }, next = "nervous" }, { next = "plain" } }, text = "" },
            plain = { speaker = "{doctor.name}", role = "doctor",
                text = "You're the new one. Sit down, let me look at that hand. I'm out of antibiotics, I've got two people with infected cuts and a kid with an ear infection that won't clear. Everything I need is on this list.",
                byArch = {
                    burnout = "You're the new one. Sit. Let me see the hand. I was a nurse, not a doctor, so don't expect miracles. No antibiotics, no sutures, two infected cuts I can't do anything about. Here's the list.",
                },
                next = "list" },
            nervous = { speaker = "{doctor.name}", role = "doctor",
                text = "[nervous] You're the new one. Sorry, I haven't slept. Let me look at you. Do you go out on the east road much? No reason. People just talk about who goes where.",
                choices = {
                    { text = "Why do you want to know?", next = "deflect" },
                    { text = "Just tell me what you need.", next = "list" },
                } },
            deflect = { speaker = "{doctor.name}", role = "doctor",
                text = "Because I'm the one who stitches up whoever comes back hurt. That's all. Here. The list.",
                next = "list" },
            list = { speaker = "{doctor.name}", role = "doctor",
                text = "Antibiotics. Sutures. Disinfectant. Anything from a pharmacy. People are dying of things that would've been a ten-minute visit to the clinic a few months ago.",
                choices = {
                    { text = "I'll see what I can find.", ["end"] = true, effects = { { "trust", "doctor", 5 } } },
                    { text = "[First Aid] Let me help with the patients first.", cond = { "perk", "Doctor", 2 }, next = "help",
                        effects = { { "trust", "doctor", 15 }, { "xp", "Doctor", 40 } }, tags = { "mercy" } },
                } },
            help = { speaker = "{doctor.name}", role = "doctor",
                text = "You actually know what you're doing. Okay. That's one less fever tonight. Thank you.",
                ["end"] = true },
        } },
    },
})

---------------------------------------------------------------------------
-- 2. The List (settlement)
---------------------------------------------------------------------------

K.chapter({ id = "a1_list", act = 1, line = "community", title = "The List", requires = { "a1_voices" } }, {
    build = function(ctx)
        local s = ctx.saga
        local site = K.site(ctx, { "pharmacy", "hospital", "supermarket" }, 200, 800)
        local steps, facts = K.shapeSupply(ctx, {
            site = site, title = "Search " .. site.name, text = "Find the medicine on the list",
            itemType = "Base.Bag_DuffelBag", itemName = "Bag of medicine", rivalRole = "wildcard",
            deliverTo = K.point(s.home, 2), deliverName = s.cast.doctor.name,
        })
        return {
            title = "The List",
            summary = "{doctor.name} needs antibiotics and sutures. " .. site.name .. " might not have been picked clean yet.",
            giver = "{doctor.name}", site = site, risk = 2,
            vars = { site = site, complication = facts.complication },
            steps = steps,
            reward = K.reward(ctx, "medium", "community"),
            standingReward = { community = 8 },
            onComplete = { { "trust", "doctor", 10 }, { "power", "community", 4 },
                { "call", "a1_list:thanks", "{doctor.name}", nil, 0.5 },
                { "chronicle", "Medicine came back to {saga.settlement}." } },
            deadlineHours = 72,
        }
    end,
    dialogues = {
        thanks = { radio = true, start = "r", nodes = {
            r = { route = { { cond = { "flag", "moleIs_doctor" }, next = "guilty" }, { next = "plain" } }, text = "" },
            plain = { speaker = "{doctor.name}", role = "doctor",
                text = "[relieved] The boy with the infected leg is going to keep it. I wasn't sure he would. Come see me when you get hurt. You will.",
                ["end"] = true },
            guilty = { speaker = "{doctor.name}", role = "doctor",
                text = "[hesitant] You brought all of it. I didn't think anyone would. [lowers voice] Listen... be careful who you trust here. Even people who've been good to you. Forget it. Thank you.",
                effects = { { "flag", "doctorHinted" } }, ["end"] = true },
        } },
    },
})

---------------------------------------------------------------------------
-- 3. The Road Crew (warlord)
---------------------------------------------------------------------------

K.chapter({ id = "a1_counting", act = 1, line = "warlord", title = "The Road Crew", requires = { "a1_voices" } }, {
    build = function(ctx)
        local s = ctx.saga
        local site = K.site(ctx, { "gas", "bar", "warehouse", "motel" }, 300, 900)
        local steps = K.shapeRecon(ctx, { site = site, title = "Watch the {antagonist.name} at " .. site.name, intelName = "Notebook of stops and names" })
        steps[#steps + 1] = B.step("home", "Get back to {saga.settlement}", {
            B.reach("Head back to " .. s.home.name, s.home, s.home.radius + 20),
        }, { onStart = { { "ambush", "antagonist", K.guards(ctx, 2) } },
            say = "[[Engines behind you. Somebody saw you.|A shout from the roof, then people moving.|A truck pulls out of the lot and turns your way.]]" })
        steps[#steps + 1] = K.homeMeet(ctx, "report", "Tell {contact.first} what you saw", "contact", "a1_counting:report")
        return {
            title = "The Road Crew",
            summary = "{warlord.name}'s people work out of " .. site.name .. ". Find out how many there are and how they operate.",
            giver = "{contact.name}", site = site, risk = 3, vars = { site = site },
            steps = steps,
            reward = K.reward(ctx, "medium", "community"),
            standingReward = { community = 6, antagonist = -4 },
            onComplete = { { "flag", "knowsTollPost" }, { "meet", "lieutenant" }, { "meet", "warlord" },
                { "chronicle", "Someone from {saga.settlement} scouted the road crew at their base." } },
        }
    end,
    dialogues = {
        report = { start = "a", nodes = {
            a = { speaker = "{contact.name}", role = "contact", text = "Well? How bad is it?",
                choices = {
                    { text = "There's more of them than you think, and they're better armed.", next = "truth", tags = { "honest" } },
                    { text = "It's manageable.", next = "lie", tags = { "reckless" } },
                    { text = "They keep a book. Names, what people carry, when they travel.", next = "book" },
                } },
            truth = { speaker = "{contact.name}", role = "contact",
                text = "Thank you for not dressing it up. Everyone else here tells me what they think I want to hear.",
                effects = { { "trust", "contact", 10 } }, next = "who" },
            lie = { speaker = "{contact.name}", role = "contact",
                text = "[sharply] Don't. I saw your face when you came in. Just tell me straight.",
                effects = { { "trust", "contact", -5 } }, next = "who" },
            book = { speaker = "{contact.name}", role = "contact",
                text = "So they're organized. That's worse than hungry. Hungry people make mistakes.",
                next = "who" },
            who = { speaker = "{contact.name}", role = "contact",
                text = "The one who runs things for them out there used to fix tractors. Nice enough, before. Now he's the one who stops our people on the road. If they come here, he'll be leading them.",
                ["end"] = true },
        } },
    },
})

---------------------------------------------------------------------------
-- 4. The Ham Operator (informant) - optional
---------------------------------------------------------------------------

K.chapter({ id = "a1_static", act = 1, line = "informant", title = "The Ham Operator", requires = { "a1_voices" }, optional = 0.85 }, {
    build = function(ctx)
        local s = ctx.saga
        local house = K.site(ctx, { "house", "office", "library" }, 200, 700)
        local meet = K.site(ctx, { "gas", "restaurant", "bar" }, 250, 800)
        return {
            title = "The Ham Operator",
            summary = "Someone keeps breaking in on the settlement's channel reading lists of numbers. {contact.first} traced the strongest signal to " .. house.name .. ".",
            giver = "{contact.name}", site = house, risk = 2, vars = { site = house, meet = meet },
            steps = {
                B.step("signal", "Find the transmitter", {
                    B.reach("Reach " .. house.name, house, house.radius + 15),
                    B.lock("Get into the radio room", "Locked door", K.point(house, 1), { difficulty = 0.45 }),
                }),
                B.step("search", "Search the radio room", {
                    B.search("Take the logbook", "Search the desk", K.point(house, 1),
                        { type = "Base.Notebook", name = "Radio logbook (" .. s.cast.informant.alias .. ")", questItem = true },
                        { doneLine = "A logbook of frequencies and times. The callsign on the cover is {informant.alias}." }),
                }),
                B.step("call", "Call the operator", {
                    B.radio("Use the frequency in the logbook", "a1_static:first", "{informant.alias}"),
                }),
                K.meet("meet", "Meet {informant.first}", K.f("wildcard"), s.cast.informant.name, K.point(meet, 1), "a1_static:meet"),
            },
            reward = K.reward(ctx, "small", "wildcard"),
            standingReward = { wildcard = 8 },
            onComplete = { { "meet", "informant" }, { "flag", "informantContact" } },
        }
    end,
    dialogues = {
        first = { radio = true, start = "a", nodes = {
            a = { speaker = "{informant.alias}", role = "informant",
                text = "[amused] So you're the one who broke into my place. It's fine. I don't keep anything there worth shooting someone over.",
                byArch = {
                    scared = "Who is this? How did you get this frequency? Were you in my house? Please tell me you didn't touch the antenna.",
                },
                choices = {
                    { text = "Who are you?", next = "b" },
                    { text = "Why are you breaking in on our channel?", next = "c" },
                } },
            b = { speaker = "{informant.alias}", role = "informant",
                text = "I listen. Everybody's on the radio now. The road crew, the Guard, your people. I write down what I hear and trade it for food. It's honest work, more or less.",
                next = "c" },
            c = { speaker = "{informant.alias}", role = "informant",
                text = "Because your people are going to need what I hear, and I'm going to need things your people have. Let's meet in person. Come alone. Don't come in shooting.",
                ["end"] = true },
        } },
        meet = { start = "a", nodes = {
            a = { speaker = "{informant.name}", role = "informant",
                text = "You came. Most people don't, they just get angry on the radio. Sit down.",
                byArch = {
                    scared = "You came alone? Okay. Okay. Sorry, I don't do this much. Sit. Please. I'll keep my hands on the table.",
                },
                choices = {
                    { text = "What do you know about the road crew?", next = "w" },
                    { text = "What do you want?", next = "want" },
                    { text = "[Intimidate] You're going to tell me everything you know.", check = { kind = "intimidate", base = 0.35 },
                        pass = "scared", fail = "laugh", tags = { "ruthless" } },
                } },
            w = { speaker = "{informant.name}", role = "informant",
                text = "They keep a list of every group around here. How many people, what they have, how many can fight. Your people are near the top, ever since they started broadcasting.",
                next = "want" },
            scared = { speaker = "{informant.name}", role = "informant",
                text = "All right, all right. They move people through their place every few days. People who can't pay. Some of them don't come back out. That's all I know, I swear.",
                effects = { { "trust", "informant", -15 }, { "flag", "knowsStronghold" } }, next = "want" },
            laugh = { speaker = "{informant.name}", role = "informant",
                text = "[laughs] I've been threatened by people with bigger guns than you. Do you want to try that again, nicely?",
                effects = { { "trust", "informant", -5 } }, next = "want" },
            want = { speaker = "{informant.name}", role = "informant",
                text = "Batteries. Radio parts. And somewhere to sleep behind a fence when it gets bad. I'll keep listening. When I hear something you need, I'll call.",
                choices = {
                    { text = "Deal.", ["end"] = true, effects = { { "trust", "informant", 10 }, { "standing", "wildcard", 5 } } },
                    { text = "I don't trust you.", ["end"] = true, effects = { { "flag", "distrustInformant" } } },
                } },
        } },
    },
})

---------------------------------------------------------------------------
-- 5. Hold the Fence (settlement)
---------------------------------------------------------------------------

K.chapter({ id = "a1_wire", act = 1, line = "community", title = "Hold the Fence", requires = { "a1_list" } }, {
    build = function(ctx)
        local s = ctx.saga
        local at = K.point(s.home, 1)
        local need = ctx.rng:pick({
            { { type = "Base.Plank", count = 8, label = "planks" }, { type = "Base.Nails", count = 20, label = "nails" } },
            { { type = "Base.Plank", count = 6, label = "planks" }, { type = "Base.Wire", count = 2, label = "wire" } },
            { { type = "Base.NailsBox", count = 1, label = "box of nails" }, { type = "Base.Plank", count = 10, label = "planks" } },
        })
        return {
            title = "Hold the Fence",
            summary = "Word is the road crew is coming to {saga.settlement}, probably at night. The fence needs repairs and every rifle on it.",
            giver = "{contact.name}", risk = 3,
            steps = {
                B.step("materials", "Bring materials for the fence", {
                    B.npc(K.f("community"), "Fence crew", at),
                    B.handin("Hand over materials", need, at, { label = "Hand over materials" }),
                }),
                B.step("night", "Wait for dark", {
                    B.wait("They'll come after dark", 1, { atHour = 20 }),
                }, { say = "Get some rest while you can." }),
                B.step("raid", "Hold the fence", {
                    B.hold("Defend " .. s.settlement, s.home, 150, K.f("antagonist"),
                        { waves = 3, waveSize = K.guards(ctx, 2), radius = s.home.radius + 10,
                          startLine = "Headlights on the road. Three vehicles." }),
                }),
                K.homeMeet(ctx, "after", "Afterward", "contact", "a1_wire:after"),
            },
            reward = K.reward(ctx, "large", "community"),
            standingReward = { community = 12, antagonist = -6 },
            onComplete = { { "power", "antagonist", -5 }, { "power", "community", 5 },
                { "chronicle", "The road crew hit {saga.settlement} at night and was driven off." } },
            onFail = { { "power", "community", -8 }, { "chronicle", "The road crew got through {saga.settlement}'s fence. People died." } },
        }
    end,
    dialogues = {
        after = { start = "a", nodes = {
            a = { speaker = "{contact.name}", role = "contact",
                text = "[exhales] We didn't lose anyone. [softly] First time since the summer that I haven't had to write a name down in the morning.",
                choices = {
                    { text = "They'll be back. With more people.", next = "b" },
                    { text = "Your people held up well.", next = "c", effects = { { "standing", "community", 3 } } },
                } },
            b = { speaker = "{contact.name}", role = "contact",
                text = "I know. But now they know it costs them something to come here. That might be enough to make them pick somebody else.",
                ["end"] = true },
            c = { speaker = "{contact.name}", role = "contact",
                text = "They held because you were on the fence with them. Don't let it go to your head.",
                ["end"] = true, effects = { { "trust", "contact", 5 } } },
        } },
    },
})

---------------------------------------------------------------------------
-- 6. The Lieutenant (warlord) - optional
---------------------------------------------------------------------------

K.chapter({ id = "a1_lieutenant", act = 1, line = "warlord", title = "The Lieutenant", requires = { "a1_counting" }, optional = 0.7 }, {
    build = function(ctx)
        local s = ctx.saga
        local camp = K.site(ctx, { "gas", "motel", "warehouse", "house" }, 350, 1000)
        local steps = K.shapeBounty(ctx, { site = camp, role = "antagonist", guards = 3,
            title = "Find {lieutenant.name}", findText = "Track {lieutenant.name}'s group to " .. camp.name,
            killText = "Deal with his people", bark = "[[That's the one from the fence!|Get down!|Over there!]]" })
        steps[#steps + 1] = K.meet("kneel", "{lieutenant.name}", K.f("antagonist"), s.cast.lieutenant.name,
            K.point(camp, 1), "a1_lieutenant:kneel", { npc = { mortal = true, role = "lieutenant" } })
        return {
            title = "The Lieutenant",
            summary = "{lieutenant.name} - '{lieutenant.moniker}' - led the attack on the fence. {contact.first} won't say it out loud, but people at {saga.settlement} want him dealt with.",
            giver = "{contact.name}", site = camp, risk = 4, vars = { site = camp },
            steps = steps,
            reward = K.reward(ctx, "large", "antagonist"),
            standingReward = { community = 8 },
        }
    end,
    dialogues = {
        kneel = { start = "a", nodes = {
            a = { speaker = "{lieutenant.name}", role = "lieutenant",
                text = "[panicked] Okay! Okay, I'm done. I'm unarmed. Look, I've got information. I can be useful to you. Just let me talk.",
                byArch = {
                    psychotic = "[laughs] Look at that. You actually did it. You know what, I'm almost glad. I was getting bored. Go on, then. Or don't. I know things you want to know.",
                },
                choices = {
                    { text = "Where does your boss sleep?", next = "where" },
                    { text = "[Intimidate] Tell me everything, or this goes badly for you.", check = { kind = "intimidate", base = 0.5 },
                        pass = "spill", fail = "spit", tags = { "ruthless" } },
                    { text = "[Shoot him]", next = "shoot", tags = { "ruthless" } },
                } },
            where = { speaker = "{lieutenant.name}", role = "lieutenant",
                text = "At their base, same as everybody. But there's a loading dock around back. Nobody watches it after midnight. That has to be worth something.",
                effects = { { "flag", "stronghold_backdoor" } }, next = "judge" },
            spill = { speaker = "{lieutenant.name}", role = "lieutenant",
                text = "The loading dock, around back, nobody on it after midnight. They keep people they've taken in the walk-in cooler. And somebody at your place is talking to them. I don't know who. I swear I don't.",
                effects = { { "flag", "stronghold_backdoor" }, { "flag", "knowsInsideMan" } }, next = "judge" },
            spit = { speaker = "{lieutenant.name}", role = "lieutenant",
                text = "You're not going to do anything. I can tell.",
                byArch = { psychotic = "That's it? That's your scary voice? I've done worse to people for less." },
                next = "judge" },
            judge = { speaker = "{lieutenant.name}", role = "lieutenant",
                text = "So what happens now?",
                choices = {
                    { text = "[Shoot him]", next = "shoot", tags = { "ruthless" } },
                    { text = "Go. If I see you again, you're dead.", next = "spare", tags = { "mercy" } },
                    { text = "Go back to your boss. Tell them to leave the settlement alone.", next = "message", tags = { "defiant" } },
                } },
            shoot = { speaker = "{lieutenant.name}", role = "lieutenant",
                text = "[panicked] Wait, wait-",
                effects = { { "killNpc" }, { "cast", "lieutenant", "status", "dead" }, { "power", "antagonist", -6 },
                    { "schedule", 30, "revenge", { role = "antagonist", count = 4 } },
                    { "chronicle", "{lieutenant.name} was shot at {site.name}." } },
                ["end"] = true },
            spare = { speaker = "{lieutenant.name}", role = "lieutenant",
                text = "Yeah. Okay. You won't see me. Nobody will.",
                byArch = { psychotic = "Huh. Mercy. Okay. You'll regret that, but okay." },
                effects = { { "releaseNpc", nil, "I'm going." },
                    { "cast", "lieutenant", "status", "fled" }, { "flag", "lieutenantSpared" }, { "power", "antagonist", -3 },
                    { "chronicle", "{lieutenant.name} was let go and left the area." } },
                ["end"] = true },
            message = { speaker = "{lieutenant.name}", role = "lieutenant",
                text = "I'll tell them. They won't listen. They'll come at you harder, and I'll be with them.",
                effects = { { "releaseNpc", nil, "This isn't over." }, { "cast", "lieutenant", "status", "alive" },
                    { "flag", "lieutenantMessenger" }, { "schedule", 18, "revenge", { role = "antagonist", count = 5 } } },
                ["end"] = true },
        } },
    },
})

---------------------------------------------------------------------------
-- 7. FINALE: Taken (the kid)
---------------------------------------------------------------------------

K.chapter({ id = "a1_taken", act = 1, line = "lost", title = "Taken", finale = true,
    requires = { "a1_wire", "a1_counting" } }, {
    build = function(ctx)
        local s = ctx.saga
        local site = K.site(ctx, { "mall", "supermarket", "school", "hospital", "warehouse" }, 350, 1100)
        local hasBlood = s.twists.blood ~= nil
        local steps, facts = K.shapeRescue(ctx, {
            site = site, name = s.cast.lost.first, captorRole = "antagonist", captiveFaction = K.f("community"),
            guards = 4, approachTitle = "Find {lost.first}", approachText = "Get eyes on " .. site.name,
            approachSay = "[[Two trucks out front. Fresh tire marks.|Music coming from inside.|A pair of shoes on the steps.]]",
            bark = "[[Who the hell are you?|Get to the doors!|Somebody followed us!]]",
            freeDialogue = hasBlood and "a1_taken:blood" or "a1_taken:free",
            cries = { "[[Is somebody there?|I'm in here!|Please!]]", "[[Help me!|In the back!|They locked the door!]]" },
        })
        steps[#steps + 1] = K.homeMeet(ctx, "home", "Bring {lost.first} home", "contact", "a1_taken:reunion")
        return {
            title = "Taken",
            summary = "The road crew stopped the water run at dawn and took {lost.name}, {contact.first}'s {lost.kin}. {doctor.first} followed the tire tracks to " .. site.name .. ".",
            giver = "{contact.name}", site = site, risk = 4, vars = { site = site, variant = facts.variant },
            hookCall = { tree = "a1_taken:hook", from = s.cast.contact.name },
            steps = steps,
            reward = K.reward(ctx, "spine", "community"),
            standingReward = { community = 15, antagonist = -8 },
            deadlineHours = 96,
            onComplete = { { "power", "antagonist", -8 }, { "power", "community", 6 }, { "meet", "lost" },
                { "chronicle", "{lost.name} was brought back from " .. site.name .. "." } },
            onFail = { { "cast", "lost", "status", "held" },
                { "chronicle", "The attempt to get {lost.first} back from " .. site.name .. " failed." } },
        }
    end,
    dialogues = {
        hook = { radio = true, start = "a", nodes = {
            a = { speaker = "{contact.name}", role = "contact",
                text = "[panicked] Are you there? Please pick up. They stopped the water run at dawn. Three trucks. They took my {lost.kin}. Just put {lost.him} in the back of a truck and drove off.",
                byArch = {
                    survivor = "[urgent] Pick up. Now, please. They hit the water run this morning. They took my {lost.kin}. Threw {lost.him} in a truck and drove off. Nobody else was hurt. They only wanted {lost.him}.",
                },
                effects = { { "cast", "lost", "status", "taken" } },
                choices = {
                    { text = "Where did they take {lost.first}?", next = "where" },
                    { text = "Why {lost.first}?", next = "why", cond = { "not", { "twist", "blood" } } },
                    { text = "Why {lost.first}?", next = "whyBlood", cond = { "twist", "blood" } },
                    { text = "I'm sorry. I can't.", next = "cant" },
                } },
            where = { speaker = "{contact.name}", role = "contact",
                text = "Our medic followed the tracks most of the way. We know where they went. It's their ground out there. People who go there to argue don't come back.",
                choices = {
                    { text = "I'll bring {lost.first} back.", ["end"] = true, effects = { { "accept" }, { "trust", "contact", 10 } } },
                    { text = "What am I walking into?", next = "intel" },
                } },
            intel = { speaker = "{contact.name}", role = "contact",
                text = "Guards on the doors, maybe four or five. They keep people away from the windows, in the back. The guard on the back door carries the keys. Or you go in loud and hope you're faster than the dead.",
                choices = {
                    { text = "I'll bring {lost.first} back.", ["end"] = true, effects = { { "accept" }, { "trust", "contact", 10 } } },
                    { text = "I need time to get ready.", ["end"] = true },
                } },
            why = { speaker = "{contact.name}", role = "contact",
                text = "Because {lost.he}'s young and healthy and can work. Because it'll make the rest of us do what they say. I don't know. Does it matter?",
                next = "where" },
            whyBlood = { speaker = "{contact.name}", role = "contact",
                text = "[voice breaking] It doesn't matter why. I'm sorry. I'm not... please. Just get {lost.him} out of there.",
                effects = { { "flag", "contactEvasive" } }, next = "where" },
            cant = { speaker = "{contact.name}", role = "contact",
                text = "[bitterly] Then I'll go myself. I'll probably die in the parking lot, and {lost.he}'ll still be in there.",
                choices = {
                    { text = "Wait. I'll do it.", ["end"] = true, effects = { { "accept" } } },
                    { text = "Good luck.", ["end"] = true, effects = { { "standing", "community", -10 }, { "trust", "contact", -20 } } },
                } },
        } },
        free = { start = "a", nodes = {
            a = { speaker = "{lost.name}", role = "lost",
                text = "[shaky] You're not one of them. Did my... did they send you? Okay. There were others in here. Two days ago. They moved them somewhere else.",
                byArch = {
                    angry = "About time. No, sorry. Sorry. Thank you. There were other people in here too. They moved them two days ago. I heard them talking about it.",
                },
                choices = {
                    { text = "We'll worry about them later. Let's get you out.", next = "b", tags = { "mercy" } },
                    { text = "Stay behind me. Run when I tell you.", next = "b" },
                } },
            b = { speaker = "{lost.name}", role = "lost",
                text = "There's a door by the loading dock. I'll go for the road. Just keep them off me.",
                effects = { { "flag", "othersTaken" }, { "meet", "lost" } }, ["end"] = true },
        } },
        blood = { start = "a", nodes = {
            a = { speaker = "{lost.name}", role = "lost",
                text = "[urgently] Wait. Stop. You don't understand. The one in charge here, that's my real parent. Nobody at the settlement knows. I wasn't dragged anywhere. I got in the truck.",
                effects = { { "reveal", "blood" } },
                choices = {
                    { text = "[Persuade] Your family back home is falling apart. Come back. You can be angry at all of us later.", check = { kind = "persuade", base = 0.5 },
                        pass = "agree", fail = "refuse" },
                    { text = "It's your choice. I won't drag you anywhere.", next = "choice", tags = { "respect" } },
                    { text = "They have people locked in the back. Is that who you want to be with?", next = "guilt" },
                } },
            agree = { speaker = "{lost.name}", role = "lost", text = "Fine. I'll come back. But I'm not done here.",
                effects = { { "flag", "lostAngry" } }, ["end"] = true },
            refuse = { speaker = "{lost.name}", role = "lost", text = "No. Let go of me. I'm staying.",
                effects = { { "cast", "lost", "status", "with_warlord" }, { "flag", "lostDefected" } }, ["end"] = true },
            choice = { speaker = "{lost.name}", role = "lost",
                text = "Nobody's ever said that to me. Okay. I'll come back. For now. Because you asked.",
                effects = { { "flag", "lostRespected" } }, ["end"] = true },
            guilt = { speaker = "{lost.name}", role = "lost",
                text = "[quietly] I heard them crying at night. I kept telling myself it wasn't what it sounded like. Okay. Get me out of here.",
                effects = { { "flag", "lostDisillusioned" } }, ["end"] = true },
        } },
        reunion = { start = "r", nodes = {
            r = { route = {
                    { cond = { "flag", "lostDefected" }, next = "gone" },
                    { cond = { "revealed", "blood" }, next = "truth" },
                    { next = "home" },
                }, text = "" },
            home = { speaker = "{contact.name}", role = "contact",
                text = "[softly] {lost.He}'s asleep. First real sleep in three days. I keep going in to check {lost.he}'s still breathing. We don't have much, but what we have, you're welcome to.",
                choices = {
                    { text = "Keep it. Just keep {lost.first} safe.", ["end"] = true, effects = { { "trust", "contact", 15 }, { "standing", "community", 5 } }, tags = { "mercy" } },
                    { text = "There were other people in there. They were moved.", next = "others", cond = { "flag", "othersTaken" } },
                    { text = "They're not going to let this go.", next = "warn" },
                } },
            others = { speaker = "{contact.name}", role = "contact",
                text = "So they're holding people. Not just taking supplies. Then sooner or later somebody's going to have to go there. I was hoping it wouldn't come to that.",
                ["end"] = true, effects = { { "flag", "strongholdPen" } } },
            warn = { speaker = "{contact.name}", role = "contact",
                text = "No, they won't. And there's something else. Somebody's been talking on the old Guard channel. Military talk. Somebody new is in the area.",
                ["end"] = true },
            truth = { speaker = "{contact.name}", role = "contact",
                text = "So now you know. It was a long time ago, and it ended badly. I didn't tell you because I was afraid you wouldn't go.",
                choices = {
                    { text = "You lied to me.", next = "lied", effects = { { "trust", "contact", -15 } } },
                    { text = "I would've gone anyway.", next = "anyway", effects = { { "trust", "contact", 10 } }, tags = { "mercy" } },
                } },
            lied = { speaker = "{contact.name}", role = "contact", text = "I did. I'd do it again. That's what being a parent is now.",
                ["end"] = true },
            anyway = { speaker = "{contact.name}", role = "contact", text = "Yeah. I think you would have.",
                ["end"] = true },
            gone = { speaker = "{contact.name}", role = "contact",
                text = "[stunned] What do you mean, stayed? {lost.He} chose to stay there? Get out. No. Sorry. Sit down. I don't have anybody else to say this to.",
                effects = { { "trust", "contact", -5 }, { "power", "community", -3 } },
                choices = {
                    { text = "We'll get {lost.first} back.", ["end"] = true, effects = { { "flag", "promisedLost" } } },
                    { text = "Maybe it was {lost.first}'s choice to make.", ["end"] = true, effects = { { "trust", "contact", -10 } }, tags = { "cold" } },
                } },
        } },
    },
})

return true
