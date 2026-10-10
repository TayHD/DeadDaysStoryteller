-- ACT II: THE GUARD
-- A Guard detachment is still operating in the county. Arguments at the
-- settlement. The toll on the river road. What happened to the kid's family.
-- The betrayal, in whichever form this world rolled.

require "DeadDaysStory/DDS_StoryKit"

local K = DDS.Kit
local B = DDS.Quests.B

---------------------------------------------------------------------------
-- 1. Contact (military)
---------------------------------------------------------------------------

K.chapter({ id = "a2_contact", act = 2, line = "military", title = "Contact" }, {
    build = function(ctx)
        local s = ctx.saga
        local cp = s.checkpoint
        return {
            title = "Contact",
            summary = "{officer.full} of the {military.name} has been calling on the old Guard channel. They're holding " .. cp.name .. " and want to talk.",
            giver = "{officer.callsign}", site = cp, risk = 2,
            hookCall = { tree = "a2_contact:hook", from = s.cast.officer.callsign },
            steps = {
                B.step("travel", "Go to the checkpoint", {
                    B.reach("Reach " .. cp.name, cp, cp.radius + 25),
                }, { say = "[[Sandbags, wire, a hand-painted sign: STOP 50 METERS.|Someone is watching you through a scope the whole way in.|A Humvee with no tires, used as a barricade.]]" }),
                K.meet("meet", "Talk to {officer.full}", K.f("military"), s.cast.officer.full, K.point(cp, 1), "a2_contact:meet"),
            },
            reward = K.reward(ctx, "medium", "military"),
            standingReward = { military = 10 },
            onComplete = { { "meet", "officer" }, { "chronicle", "The {military.name} made contact with {saga.settlement}." } },
        }
    end,
    dialogues = {
        hook = { radio = true, start = "a", nodes = {
            a = { speaker = "{officer.callsign}", role = "officer",
                text = "Unknown station, this is a Kentucky National Guard detachment. We've been monitoring your traffic. We'd like to speak with whoever's been running supplies for the group by the river. Over.",
                byArch = {
                    burnedout = "Whoever's been running supplies out of that settlement, this is the Guard. What's left of it out here, anyway. We've been listening to you for a while. We should talk.",
                },
                choices = {
                    { text = "Who am I talking to?", next = "b" },
                    { text = "I don't work for the government.", next = "c", tags = { "independent" } },
                    { text = "Stay off this channel.", ["end"] = true, effects = { { "standing", "military", -5 } } },
                } },
            b = { speaker = "{officer.callsign}", role = "officer",
                text = "A detachment of about twenty. We hold a position nearby with fuel, medical supplies and a working generator. We need people who know the area. Over.",
                next = "d" },
            c = { speaker = "{officer.callsign}", role = "officer",
                text = "Neither does anybody else these days. This isn't a draft. It's a trade. Over.",
                next = "d" },
            d = { speaker = "{officer.callsign}", role = "officer",
                text = "Come to the checkpoint in daylight, weapon slung. We'll talk face to face. Out.",
                choices = {
                    { text = "I'll come.", ["end"] = true, effects = { { "accept" }, { "meet", "officer" } } },
                    { text = "[Say nothing]", ["end"] = true, effects = { { "meet", "officer" } } },
                } },
        } },
        meet = { start = "a", nodes = {
            a = { speaker = "{officer.full}", role = "officer",
                text = "Sit down. There's coffee if you want it. It's the real stuff, the last of it. Consider it a gesture of good faith.",
                byArch = {
                    burnedout = "Sit. Coffee's real, last can we have. I'm not going to make a speech. I'm tired and you look tired, so let's just talk.",
                },
                choices = {
                    { text = "What do you want from me?", next = "want" },
                    { text = "Who do you answer to?", next = "chain" },
                    { text = "[Military] Where's the rest of your unit?", check = { kind = "soldier", base = 0.35 },
                        pass = "honest", fail = "stone" },
                } },
            chain = { speaker = "{officer.full}", role = "officer",
                text = "A command post outside the exclusion zone. They call twice a week. They ask how many civilians we've processed. I don't like that word either.",
                effects = { { "flag", "processedWord" } }, next = "want" },
            honest = { speaker = "{officer.full}", role = "officer",
                text = "Dead, or gone home. Most of them left in July and didn't come back. I've got under twenty people and orders I'm not allowed to share. You asked that like someone who's served.",
                effects = { { "trust", "officer", 10 } }, next = "want" },
            stone = { speaker = "{officer.full}", role = "officer",
                text = "Where they need to be. Next question.",
                next = "want" },
            want = { speaker = "{officer.full}", role = "officer",
                text = "There's a building I need cleared so we can use it as an aid station. The road crew is living in it. Help my people clear it, and your settlement gets put on our supply list. Medicine, ammunition.",
                choices = {
                    { text = "And what does that cost the settlement?", next = "cost" },
                    { text = "Deal.", ["end"] = true, effects = { { "standing", "military", 5 }, { "trust", "officer", 5 } } },
                    { text = "I'll think about it.", ["end"] = true },
                } },
            cost = { speaker = "{officer.full}", role = "officer",
                text = "A list of names. Who's there, who's sick, who has a trade. It's standard procedure. Nothing they need to worry about.",
                byArch = {
                    burnedout = "A list of names. Who's sick, who's healthy, who has a trade. They tell me it's standard. [sighs] I stopped asking what they do with the lists.",
                },
                effects = { { "flag", "officerHeadcount" } },
                choices = {
                    { text = "That sounds like more than paperwork.", ["end"] = true, effects = { { "trust", "officer", -5 } }, tags = { "suspicious" } },
                    { text = "Fine. I'll help.", ["end"] = true, effects = { { "standing", "military", 5 } } },
                } },
        } },
    },
})

---------------------------------------------------------------------------
-- 2. Aid Station (military)
---------------------------------------------------------------------------

K.chapter({ id = "a2_greenzone", act = 2, line = "military", title = "Aid Station", requires = { "a2_contact" } }, {
    build = function(ctx)
        local site = K.site(ctx, { "hospital", "police", "school" }, 300, 1000)
        local staging = K.ring(ctx, site, 35, 50)
        return {
            title = "Aid Station",
            summary = "{officer.callsign} wants " .. site.name .. " for an aid station. The road crew is using it. A fireteam will meet you on the approach.",
            giver = "{officer.full}", site = site, risk = 4, vars = { site = site },
            steps = {
                B.step("stage", "Meet the fireteam", {
                    B.allies(K.f("military"), 3, staging),
                    B.reach("Meet the fireteam on the approach", staging, 12),
                }, { say = "[[The sergeant nods at you. 'We go when you go.'|'Stay out of our line of fire and we'll get along fine.']]" }),
                B.step("clear", "Clear " .. site.name, {
                    B.eliminate("Clear out the road crew", K.f("antagonist"), K.guards(ctx, 4), site,
                        { bark = "[[Soldiers!|Hold the doors!|They brought the army!]]" }),
                    B.interact("Set up the radio relay", "Set up radio relay", site.inner, { duration = 200 }),
                }),
                B.step("debrief", "Report in", {
                    B.radio("Report to {officer.callsign}", "a2_greenzone:debrief", "{officer.callsign}"),
                }),
            },
            reward = K.reward(ctx, "large", "military"),
            standingReward = { military = 15, antagonist = -6 },
            onComplete = { { "power", "military", 8 }, { "power", "antagonist", -6 },
                { "chronicle", "The {military.name} took " .. site.name .. " from the road crew." } },
        }
    end,
    dialogues = {
        debrief = { radio = true, start = "a", nodes = {
            a = { speaker = "{officer.callsign}", role = "officer",
                text = "Relay's up. Good work. Your settlement goes on the supply list, like I said. Over.",
                choices = {
                    { text = "When do the supplies arrive?", next = "b" },
                    { text = "What's the building for, really?", next = "c" },
                } },
            b = { speaker = "{officer.callsign}", role = "officer",
                text = "Soon. One more thing. Somebody on the civilian bands has been talking to you. A ham operator. We hear everything out here. Be careful what you buy from people who sell to everyone. Out.",
                effects = { { "flag", "militaryWarnedInformant" } }, ["end"] = true },
            c = { speaker = "{officer.callsign}", role = "officer",
                text = "On paper it's a collection point. For civilians who need evacuation. Don't read too much into it. Out.",
                effects = { { "flag", "collectionPoint" } }, ["end"] = true },
        } },
    },
})

---------------------------------------------------------------------------
-- 3. The Drop (military / political) - optional
---------------------------------------------------------------------------

K.chapter({ id = "a2_drop", act = 2, line = "military", title = "The Drop", requires = { "a2_contact" }, optional = 0.75 }, {
    build = function(ctx)
        local x, y = K.origin(ctx)
        local crash = DDS.Sites.ring(x, y, 300, 700, ctx.rng)
        return {
            title = "The Drop",
            summary = "A helicopter supply drop for the {military.name} came down off target near " .. crash.town .. ". Everyone heard it.",
            giver = "{officer.callsign}", site = crash, risk = 3,
            steps = {
                B.step("reach", "Get to the drop", { B.reach("Find the crate", crash, 20) }),
                B.step("hold", "Secure the crate", {
                    B.retrieve("Grab the supply crate", crash, "Base.Bag_Military", "Military supply crate"),
                    B.hold("Hold off the scavengers", crash, 90, K.f("antagonist"), { waves = 2, waveSize = 3 }),
                }),
                B.step("choose", "Decide who gets it", { B.radio("Two people are on the radio", "a2_drop:choose", "Two channels") }),
            },
            reward = K.reward(ctx, "medium", "military"),
        }
    end,
    dialogues = {
        choose = { radio = true, start = "a", nodes = {
            a = { speaker = "{officer.callsign}", role = "officer",
                text = "You have our crate. Bring it to the checkpoint. That isn't a request.",
                next = "b" },
            b = { speaker = "{contact.name}", role = "contact",
                text = "I'm on this channel too. There's antibiotics in that crate. We have three people who won't make it through the week without them. I'm not ordering you. I'm asking.",
                choices = {
                    { text = "[Take it to the {military.name}]", ["end"] = true, tags = { "lawful" },
                        effects = { { "take", "Base.Bag_Military", 1 }, { "standing", "military", 12 }, { "standing", "community", -8 },
                            { "power", "military", 4 }, { "choose", "drop", "military" },
                            { "chronicle", "The supply drop went to the soldiers." } } },
                    { text = "[Take it to {saga.settlement}]", ["end"] = true, tags = { "mercy" },
                        effects = { { "take", "Base.Bag_Military", 1 }, { "standing", "community", 12 }, { "standing", "military", -10 },
                            { "power", "community", 5 }, { "choose", "drop", "community" },
                            { "chronicle", "The supply drop went to {saga.settlement}. The soldiers noticed." } } },
                    { text = "[Persuade] Split it. Medicine to the settlement, ammunition to the checkpoint.", check = { kind = "persuade", base = 0.4, role = "military" },
                        passEffects = { { "take", "Base.Bag_Military", 1 }, { "standing", "community", 6 }, { "standing", "military", 6 }, { "choose", "drop", "split" } },
                        failEffects = { { "take", "Base.Bag_Military", 1 }, { "standing", "military", -8 }, { "standing", "community", 6 }, { "choose", "drop", "community" } },
                        pass = "split", fail = "nosplit" },
                } },
            split = { speaker = "{officer.callsign}", role = "officer", text = "Fine. Fine. Bring me the ammunition. Out.", ["end"] = true },
            nosplit = { speaker = "{officer.callsign}", role = "officer", text = "I said it wasn't a request. We'll remember this. Out.", ["end"] = true },
        } },
    },
})

---------------------------------------------------------------------------
-- 4. The Vote (settlement / political)
---------------------------------------------------------------------------

K.chapter({ id = "a2_council", act = 2, line = "community", title = "The Vote", requires = { "a2_greenzone" } }, {
    build = function(ctx)
        return {
            title = "The Vote",
            summary = "The {military.name} will protect {saga.settlement} if they hand over their guns and accept a curfew. {contact.first} and {doctor.first} disagree, loudly. Everyone wants to hear what you think.",
            giver = "{contact.name}", risk = 1,
            steps = {
                K.homeMeet(ctx, "contact", "Hear {contact.first} out", "contact", "a2_council:contact"),
                K.homeMeet(ctx, "doctor", "Hear {doctor.first} out", "doctor", "a2_council:doctor"),
                K.homeMeet(ctx, "vote", "Speak at the meeting", "contact", "a2_council:vote"),
            },
            reward = K.reward(ctx, "small", "community"),
        }
    end,
    dialogues = {
        contact = { start = "a", nodes = {
            a = { speaker = "{contact.name}", role = "contact",
                text = "[angry] Hand over our guns to people who talk about processing civilians. We've kept everyone here alive since summer with eleven rifles. I'm not giving them up because somebody in a uniform asked nicely.",
                byArch = {
                    caretaker = "I want to say yes. I want someone else to be responsible for once. But I've heard how they talk on that radio. If we give up the guns, we can't ever take them back.",
                },
                choices = {
                    { text = "You can't hold off the road crew alone forever.", next = "b" },
                    { text = "I agree. Don't trust them.", next = "c", effects = { { "trust", "contact", 8 } } },
                } },
            b = { speaker = "{contact.name}", role = "contact", text = "We're not alone. We've got you now. Don't we?", ["end"] = true },
            c = { speaker = "{contact.name}", role = "contact", text = "Then say so at the meeting. People listen to you now.", ["end"] = true },
        } },
        doctor = { start = "a", nodes = {
            a = { speaker = "{doctor.name}", role = "doctor",
                text = "They have antibiotics. Insulin. A working autoclave. I've watched people die here from things I could have treated in a clinic in an afternoon. I don't care about the guns. I care about the patients.",
                byArch = {
                    burnout = "[exhausted] I buried four people this month. Four. They have insulin and antibiotics. I don't care whose flag is on the gate anymore. I'm tired of digging.",
                },
                choices = {
                    { text = "And when they want more than guns?", next = "b" },
                    { text = "You're right. People come first.", next = "c", effects = { { "trust", "doctor", 8 } } },
                } },
            b = { speaker = "{doctor.name}", role = "doctor", text = "Then we deal with it, alive. That's the whole point.", ["end"] = true },
            c = { speaker = "{doctor.name}", role = "doctor", text = "Thank you. Pride isn't a plan. It's just a slower way to die.", ["end"] = true },
        } },
        vote = { start = "a", nodes = {
            a = { speaker = "{contact.name}", role = "contact",
                text = "Everybody's here. Go ahead. Say what you came to say.",
                choices = {
                    { text = "Take the deal. Hand in the guns.", next = "deal", tags = { "lawful", "pragmatic" },
                        effects = { { "choose", "council", "military" }, { "standing", "military", 15 }, { "trust", "contact", -15 },
                            { "trust", "doctor", 10 }, { "power", "military", 6 }, { "power", "community", -4 }, { "flag", "militaryProtection" } } },
                    { text = "Refuse. Stay independent.", next = "refuse", tags = { "independent" },
                        effects = { { "choose", "council", "independent" }, { "standing", "military", -12 }, { "standing", "community", 8 },
                            { "trust", "contact", 15 }, { "trust", "doctor", -10 }, { "power", "community", 4 } } },
                    { text = "[Persuade] Take the medicine. Keep the guns. Make them earn the rest.", check = { kind = "persuade", base = 0.35, role = "community" },
                        pass = "middle", fail = "split",
                        passEffects = { { "choose", "council", "middle" }, { "standing", "community", 10 }, { "standing", "military", 4 }, { "trust", "contact", 5 }, { "trust", "doctor", 5 } },
                        failEffects = { { "choose", "council", "split" }, { "power", "community", -6 }, { "flag", "settlementDivided" } } },
                } },
            deal = { speaker = "{contact.name}", role = "contact",
                text = "[resigned] Then that's the vote. Somebody box up the rifles. I'll hand mine over myself.",
                effects = { { "chronicle", "{saga.settlement} voted to accept the {military.name}'s protection." } }, ["end"] = true },
            refuse = { speaker = "{doctor.name}", role = "doctor",
                text = "Then I hope you're as good as they say. Because we're on our own now.",
                effects = { { "chronicle", "{saga.settlement} turned down the {military.name}." } }, ["end"] = true },
            middle = { speaker = "{contact.name}", role = "contact",
                text = "That's the first idea tonight nobody's yelling about. All right. We do it that way.",
                effects = { { "chronicle", "{saga.settlement} worked out a deal with the soldiers." } }, ["end"] = true },
            split = { speaker = "{contact.name}", role = "contact",
                text = "Half of them want the guns gone and half want them loaded. Great. Now we're two groups.",
                effects = { { "chronicle", "The meeting at {saga.settlement} ended in a shouting match." } }, ["end"] = true },
        } },
    },
})

---------------------------------------------------------------------------
-- 5. The Toll (warlord)
---------------------------------------------------------------------------

K.chapter({ id = "a2_tollroad", act = 2, line = "warlord", title = "The Toll" }, {
    build = function(ctx)
        local x, y = K.origin(ctx)
        local road = DDS.Sites.ring(x, y, 250, 600, ctx.rng)
        local price = ctx.rng:pick({
            { type = "Base.PetrolCan", count = 1, label = "can of gas" },
            { type = "Base.Bullets9mmBox", count = 2, label = "boxes of 9mm" },
            { type = "Base.CigarettePack", count = 3, label = "packs of cigarettes" },
        })
        return {
            title = "The Toll",
            summary = "{warlord.last}'s crew has blocked the only clear road to the river and is charging people to pass. Trade runs have stopped. Pay, talk your way through, or clear it.",
            giver = "{contact.name}", site = road, risk = 3, vars = { price = price },
            steps = {
                K.meet("toll", "Reach the roadblock", K.f("antagonist"), "Roadblock guard", road, "a2_tollroad:toll",
                    { npc = { mortal = true, role = "tollman" } }),
                B.step("pay", "Pay the toll", {
                    B.handin("Pay " .. price.count .. " " .. price.label, { price }, road, { label = "Pay the toll" }),
                }, { next = "complete" }),
                B.step("fight", "Clear the roadblock", {
                    B.eliminate("Clear the roadblock crew", K.f("antagonist"), K.guards(ctx, 3), road, { mode = "guard" }),
                    B.interact("Push the cars out of the road", "Clear the road", road, { duration = 150, noise = 30 }),
                }, { onComplete = { { "power", "antagonist", -6 }, { "standing", "community", 6 },
                    { "chronicle", "The roadblock on the river road was cleared." } } }),
            },
            reward = K.reward(ctx, "medium", "community"),
            standingReward = { community = 6 },
        }
    end,
    dialogues = {
        toll = { start = "a", nodes = {
            a = { speaker = "Roadblock guard", role = "tollman",
                text = "Road's open. It just costs something to use it now. Pay and you can go back and forth all week. Don't pay and you can go around. It's about thirty miles.",
                choices = {
                    { text = "Fine. I'll pay. ({price.count} {price.label})", effects = { { "branch", "pay" } }, ["end"] = true, tags = { "pragmatic" } },
                    { text = "[Lie] My people already paid this week. Check with your boss.", check = { kind = "lie", base = 0.4 },
                        pass = "fooled", fail = "caught", tags = { "clever" } },
                    { text = "[Intimidate] Walk away from the roadblock.", check = { kind = "intimidate", base = 0.3 },
                        pass = "walks", fail = "caught", tags = { "ruthless" } },
                    { text = "The road's not yours.", next = "draw", tags = { "defiant" } },
                } },
            fooled = { speaker = "Roadblock guard", role = "tollman", text = "Nobody keeps track of anything around here anyway. Go on. Don't tell anybody.",
                effects = { { "complete" }, { "flag", "tollFooled" } }, ["end"] = true },
            walks = { speaker = "Roadblock guard", role = "tollman", text = "Yeah, okay. This isn't worth getting shot over.",
                effects = { { "releaseNpc", nil, "I'm going." }, { "power", "antagonist", -3 }, { "complete" } }, ["end"] = true },
            caught = { speaker = "Roadblock guard", role = "tollman", text = "Nice try. [shouting] Hey! Get over here!",
                effects = { { "branch", "fight" } }, ["end"] = true },
            draw = { speaker = "Roadblock guard", role = "tollman", text = "Have it your way.",
                effects = { { "branch", "fight" } }, ["end"] = true },
        } },
    },
})

---------------------------------------------------------------------------
-- 6. The Old House (the kid) - optional
---------------------------------------------------------------------------

K.chapter({ id = "a2_lostsaw", act = 2, line = "lost", title = "The Old House", optional = 0.8 }, {
    build = function(ctx)
        local s = ctx.saga
        local house = s.lostHome
        return {
            title = "The Old House",
            summary = "{lost.first} wants to go back to the house {lost.he} lived in before the evacuation. {contact.first} won't let {lost.him} go alone.",
            giver = "{lost.name}", site = house, risk = 2,
            steps = {
                B.step("house", "Go to the old house", {
                    B.reach("Reach " .. house.name, house, house.radius + 10),
                    B.infected("Clear the yard", ctx.rng:int(6, 12), house, house.radius + 25),
                }),
                B.step("search", "Search the house", {
                    B.search("Find {lost.first}'s box of photos", "Search the bedroom closet", K.point(house, 1),
                        { type = "Base.PhotoAlbum", name = "Family photos", questItem = true }),
                    B.search("Check the kitchen table", "Search the kitchen", K.point(house, 2),
                        { type = "Base.Paperwork", name = "Evacuation paperwork" }, { optional = true,
                        doneLine = "An evacuation intake form from July, and a second page: a list headed ESSENTIAL PERSONNEL. Nurses, mechanics, an electrician. Everyone else is just a number." }),
                }),
                K.homeMeet(ctx, "talk", "Bring them to {lost.first}", "lost", "a2_lostsaw:talk"),
            },
            reward = K.reward(ctx, "small", "community"),
            onComplete = { { "meet", "lost" }, { "flag", "lostPast" } },
        }
    end,
    dialogues = {
        talk = { start = "a", nodes = {
            a = { speaker = "{lost.name}", role = "lost",
                text = "You found them. I just wanted to remember what everybody looked like before. Before they looked scared all the time.",
                byArch = {
                    angry = "You actually found them. I figured they'd burned or something. I just wanted proof we were normal once.",
                },
                choices = {
                    { text = "There was paperwork from the evacuation too. A list.", next = "list" },
                    { text = "Hold on to them.", next = "end1", tags = { "mercy" } },
                } },
            list = { speaker = "{lost.name}", role = "lost",
                text = "At the evac center they split everyone into two lines. People with useful jobs went on buses. Everyone else waited. We waited three days. Then the fence went down and we ran.",
                effects = { { "flag", "lostSawTriage" } },
                choices = {
                    { text = "Who got on the buses?", next = "buses" },
                } },
            buses = { speaker = "{lost.name}", role = "lost",
                text = "Nurses. Doctors. Mechanics. Anyone who could keep the soldiers going. They didn't even pretend it was about saving people.",
                choices = {
                    { text = "I'm sorry.", ["end"] = true, tags = { "mercy" } },
                    { text = "Keep that to yourself for now.", ["end"] = true, effects = { { "flag", "keptLostSecret" } } },
                } },
            end1 = { speaker = "{lost.name}", role = "lost", text = "Yeah. Thanks for coming with me. You didn't have to.", ["end"] = true },
        } },
    },
})

---------------------------------------------------------------------------
-- 7. The Meet (ham operator) - the betrayal surfaces
---------------------------------------------------------------------------

K.chapter({ id = "a2_rendezvous", act = 2, line = "informant", title = "The Meet", requires = { "a2_greenzone" } }, {
    build = function(ctx)
        local s = ctx.saga
        local rv = K.site(ctx, { "church", "gas", "restaurant", "house" }, 250, 700)
        local ambushAt = K.ring(ctx, rv, 22, 35)
        local tree = "a2_rendezvous:mole_informant"
        if s.betrayal == "bargain" then tree = "a2_rendezvous:bargain"
        elseif s.twists.mole and s.twists.mole.who == "doctor" then tree = "a2_rendezvous:mole_doctor" end
        return {
            title = "The Meet",
            summary = "{informant.name} says it's urgent, and that it can't go over the air. Meet at " .. rv.name .. " after dark.",
            giver = "{informant.alias}", site = rv, risk = 4, vars = { site = rv },
            hookCall = { tree = "a2_rendezvous:hook", from = s.cast.informant.alias },
            steps = {
                B.step("wait", "Wait for dark", { B.wait("The meet is after dark", 1, { atHour = 21 }) }),
                K.meet("meet", "Meet {informant.first}", K.f("wildcard"), s.cast.informant.name, K.point(rv, 1), tree,
                    { npc = { role = "informant" } }),
                B.step("ambush", "Survive", {
                    B.eliminate("Survive the ambush", K.f("antagonist"), K.guards(ctx, 4), ambushAt,
                        { mode = "assault", trigger = 150, bark = "[[There! By the door!|Don't let them leave!|Go, go!]]" }),
                }),
            },
            reward = K.reward(ctx, "medium", "wildcard"),
            onComplete = { { "flag", "rendezvousDone" } },
        }
    end,
    dialogues = {
        hook = { radio = true, start = "a", nodes = {
            a = { speaker = "{informant.alias}", role = "informant",
                text = "Not on the radio. Not this one. Same place as before, after dark. Come by yourself. It's about your settlement, and people are listening.",
                byArch = {
                    scared = "I can't say it on the air. I can't. Meet me tonight, after dark. Please come alone. I think they're listening to everything now.",
                },
                choices = {
                    { text = "I'll be there.", ["end"] = true, effects = { { "accept" } } },
                    { text = "Why should I trust you?", next = "b" },
                } },
            b = { speaker = "{informant.alias}", role = "informant", text = "You probably shouldn't. Come anyway.", ["end"] = true, effects = { { "accept" } } },
        } },
        mole_informant = { start = "a", nodes = {
            a = { speaker = "{informant.name}", role = "informant",
                text = "[quietly] You came. I knew you would. That's what they were counting on.",
                byArch = {
                    scared = "[crying] You came. Oh God, you actually came. I'm so sorry. I'm so sorry.",
                },
                choices = {
                    { text = "What did you do?", next = "b" },
                    { text = "[Draw your weapon]", next = "b", tags = { "ruthless" } },
                } },
            b = { speaker = "{informant.name}", role = "informant",
                text = "[voice breaking] They have my brother. Since August. Every time I told you something, I told them first. Supply runs, patrol times, where you sleep. I'm sorry. They're already outside.",
                effects = { { "reveal", "mole" }, { "cast", "informant", "status", "exposed" }, { "branch", "ambush" } }, ["end"] = true },
        } },
        mole_doctor = { start = "a", nodes = {
            a = { speaker = "{informant.name}", role = "informant",
                text = "Shut the door. Look at these. Letters. I took them off one of their runners. Look at the handwriting.",
                choices = { { text = "...That's {doctor.first}'s handwriting.", next = "b" } } },
            b = { speaker = "{informant.name}", role = "informant",
                text = "Patrol times. Who's sick and who's armed. When the supply runs go out. Your medic's been writing to them for weeks. And I think the runner I took these from was followed.",
                effects = { { "reveal", "mole" }, { "give", "Base.LetterHandwritten", 1, "Letters in {doctor.first}'s handwriting" },
                    { "trust", "informant", 20 }, { "branch", "ambush" } }, ["end"] = true },
        } },
        bargain = { start = "a", nodes = {
            a = { speaker = "{informant.name}", role = "informant",
                text = "You ever wonder why they let the kid go so easy? Or how they knew where the Guard kept their fuel?",
                choices = { { text = "Tell me.", next = "b" } } },
            b = { speaker = "{informant.name}", role = "informant",
                text = "Your leader traded them the location of the Guard's fuel cache to get the kid back. The raid on that cache killed two soldiers. And I'm pretty sure I was followed here.",
                effects = { { "reveal", "bargain" }, { "trust", "informant", 15 }, { "branch", "ambush" } }, ["end"] = true },
        } },
    },
})

---------------------------------------------------------------------------
-- 8. FINALE: Judgment
---------------------------------------------------------------------------

K.chapter({ id = "a2_judgment", act = 2, line = "finale", title = "Judgment", finale = true,
    requires = { "a2_rendezvous", "a2_council" } }, {
    build = function(ctx)
        local s = ctx.saga
        local steps
        if s.betrayal == "bargain" then
            steps = { K.homeMeet(ctx, "judge", "Confront {contact.first}", "contact", "a2_judgment:contact") }
        elseif s.twists.mole and s.twists.mole.who == "doctor" then
            steps = { K.homeMeet(ctx, "judge", "Confront {doctor.first}", "doctor", "a2_judgment:doctor",
                { npc = { mortal = true, role = "doctor" } }) }
        else
            local hide = K.site(ctx, { "house", "motel", "church" }, 200, 600)
            steps = {
                B.step("find", "Find {informant.first}", {
                    B.reach("{informant.first} ran. Find them at " .. hide.name, hide, hide.radius + 10),
                }),
                K.meet("judge", "Confront {informant.first}", K.f("wildcard"), s.cast.informant.name, K.point(hide, 1),
                    "a2_judgment:informant", { npc = { mortal = true, role = "informant" } }),
            }
        end
        return {
            title = "Judgment",
            summary = "Someone you trusted sold out {saga.settlement}. Everyone is waiting to see what you do about it.",
            giver = "You", risk = 2, steps = steps,
            reward = K.reward(ctx, "large", "community"),
        }
    end,
    dialogues = {
        informant = { start = "a", nodes = {
            a = { speaker = "{informant.name}", role = "informant",
                text = "I'm not going to beg. Do what you have to. But if you ever get inside their place, my brother's in the cooler in the back. He didn't do anything.",
                byArch = {
                    scared = "[crying] Please. I know. I know what I did. I'm not asking for me. My brother's in there, in the cooler. If you ever go in, please get him out.",
                },
                choices = {
                    { text = "[Execute]", next = "exec", tags = { "ruthless" } },
                    { text = "Leave. If I see you again, I won't stop to talk.", next = "exile", tags = { "mercy" } },
                    { text = "[Intimidate] You work for me now. You tell them what I want them to hear.", check = { kind = "intimidate", base = 0.45 },
                        pass = "turn", fail = "bolt", tags = { "pragmatic" } },
                    { text = "Come with me. We'll get your brother out together.", next = "recruit", tags = { "mercy", "loyal" } },
                } },
            exec = { speaker = "{informant.name}", role = "informant", text = "[quietly] Yeah. Okay.",
                effects = { { "killNpc" }, { "cast", "informant", "status", "dead" }, { "standing", "wildcard", -20 },
                    { "chronicle", "{informant.name} was executed for informing on {saga.settlement}." } }, ["end"] = true },
            exile = { speaker = "{informant.name}", role = "informant", text = "Thank you. I'll get him out myself. Or I'll die trying.",
                effects = { { "releaseNpc", nil, "Goodbye." }, { "cast", "informant", "status", "exiled" }, { "standing", "wildcard", 5 },
                    { "chronicle", "{informant.name} was run out of the county." } }, ["end"] = true },
            turn = { speaker = "{informant.name}", role = "informant", text = "Fine. I'll feed them whatever you want. I'm dead either way. At least this way I'm useful.",
                effects = { { "cast", "informant", "status", "turned" }, { "flag", "doubleAgent" }, { "releaseNpc", nil, "I'll be in touch." } }, ["end"] = true },
            bolt = { speaker = "{informant.name}", role = "informant", text = "No. I'm done taking orders from anyone.",
                effects = { { "releaseNpc", nil, "No." }, { "cast", "informant", "status", "fled" } }, ["end"] = true },
            recruit = { speaker = "{informant.name}", role = "informant",
                text = "You're serious. After all that. Okay. I know the back roads and I know every frequency they use. I'm with you.",
                effects = { { "cast", "informant", "status", "ally" }, { "recruit", "informant" }, { "standing", "wildcard", 15 },
                    { "chronicle", "{me.first} took in {informant.name}. Not everyone at {saga.settlement} agreed." } }, ["end"] = true },
        } },
        doctor = { start = "a", nodes = {
            a = { speaker = "{doctor.name}", role = "doctor",
                text = "[defensive] You found the letters. I can see it. Before you say anything: they have insulin. I have two diabetics here. Every letter bought a month of insulin. Every one.",
                byArch = {
                    idealist = "You found the letters. I know how it looks. They have insulin. I have two diabetics. I told myself I was saving lives. I'm not sure anymore.",
                },
                choices = {
                    { text = "People died because of what you told them.", next = "b" },
                    { text = "[First Aid] There were other ways to get insulin.", check = { kind = "medic", base = 0.3 }, pass = "c", fail = "b" },
                } },
            b = { speaker = "{doctor.name}", role = "doctor", text = "And people lived. I did the math. Every night, I did the math.", next = "judge" },
            c = { speaker = "{doctor.name}", role = "doctor", text = "Were there? Where? You weren't here in July. You don't know what it was like.", next = "judge" },
            judge = { speaker = "{contact.name}", role = "contact",
                text = "Everyone's watching. It's your call. They'll go along with whatever you decide.",
                choices = {
                    { text = "Exile. Gone by morning.", next = "exile", tags = { "mercy" } },
                    { text = "We need a medic more than we need a hanging. They stay.", next = "stay", tags = { "pragmatic" } },
                    { text = "[Execute]", next = "exec", tags = { "ruthless" } },
                } },
            exile = { speaker = "{doctor.name}", role = "doctor", text = "Who's going to set the next broken leg? You? Fine.",
                effects = { { "releaseNpc", nil, "Good luck." }, { "cast", "doctor", "status", "exiled" },
                    { "power", "community", -6 }, { "chronicle", "{doctor.name} was exiled from {saga.settlement}." } }, ["end"] = true },
            stay = { speaker = "{doctor.name}", role = "doctor", text = "I won't write to them again. I swear it.",
                effects = { { "cast", "doctor", "status", "watched" }, { "flag", "doctorForgiven" }, { "trust", "doctor", 20 },
                    { "standing", "community", -5 }, { "chronicle", "{doctor.name} informed on {saga.settlement} and was allowed to stay." } }, ["end"] = true },
            exec = { speaker = "{doctor.name}", role = "doctor", text = "[shaky] Then who takes care of them now?",
                effects = { { "killNpc" }, { "cast", "doctor", "status", "dead" }, { "power", "community", -10 }, { "standing", "community", -10 },
                    { "chronicle", "{doctor.name} was executed at {saga.settlement}." } }, ["end"] = true },
        } },
        contact = { start = "a", nodes = {
            a = { speaker = "{contact.name}", role = "contact", text = "You know. I can see it on your face. Go on, say it.",
                choices = {
                    { text = "You traded the soldiers' lives for {lost.first}.", next = "b" },
                    { text = "Why didn't you tell me?", next = "c" },
                } },
            b = { speaker = "{contact.name}", role = "contact",
                text = "[firmly] I traded strangers' lives for my {lost.kin}. Yes. I'd do it again. Anyone would. Most people just never have to choose.",
                next = "judge" },
            c = { speaker = "{contact.name}", role = "contact",
                text = "Because you'd have looked at me the way you're looking at me now.",
                next = "judge" },
            judge = { speaker = "{contact.name}", role = "contact", text = "So what happens now?",
                choices = {
                    { text = "Tell everyone the truth. Let them decide.", next = "truth", tags = { "honest" } },
                    { text = "This stays between us. You owe me.", next = "secret", tags = { "pragmatic" } },
                    { text = "Turn yourself in to the soldiers.", next = "military", tags = { "lawful", "cold" } },
                } },
            truth = { speaker = "{contact.name}", role = "contact", text = "Yeah. I figured you'd say that. That's why people trust you.",
                effects = { { "cast", "contact", "status", "deposed" }, { "flag", "contactDeposed" }, { "standing", "community", 8 },
                    { "power", "community", -4 }, { "chronicle", "{contact.name} told {saga.settlement} the truth and stepped down. {doctor.name} is in charge now." } }, ["end"] = true },
            secret = { speaker = "{contact.name}", role = "contact", text = "Then I owe you. For as long as either of us is alive.",
                effects = { { "flag", "contactOwes" }, { "trust", "contact", 20 } }, ["end"] = true },
            military = { speaker = "{contact.name}", role = "contact", text = "[bitterly] You'd hand me over to them. Okay. Then my {lost.kin} has nobody.",
                effects = { { "cast", "contact", "status", "arrested" }, { "standing", "military", 15 }, { "standing", "community", -20 },
                    { "power", "community", -8 }, { "chronicle", "{contact.name} was handed over to the {military.name}." } }, ["end"] = true },
        } },
    },
})

return true
