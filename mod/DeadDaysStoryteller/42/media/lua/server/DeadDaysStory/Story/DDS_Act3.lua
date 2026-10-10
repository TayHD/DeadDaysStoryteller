-- ACT III: ORDERS
-- What the Guard was sent here to do comes out. The player picks a side and
-- the act splits three ways: the settlement, the soldiers, or the road crew.
--
-- Twist ids kept from earlier versions:
--   firebreak = requisition: take civilian fuel/medicine for the pull-out,
--               hold the cordon, leave the civilians.
--   lab       = triage: limited seats on the last trucks; the medic is on the
--               list, nobody else is.

require "DeadDaysStory/DDS_StoryKit"

local K = DDS.Kit
local B = DDS.Quests.B

local function leaderMeet(ctx, id, title, tree, extra)
    return K.homeMeet(ctx, id, title, K.leaderKey(), tree, extra)
end

---------------------------------------------------------------------------
-- 1. The Landline
---------------------------------------------------------------------------

K.chapter({ id = "a3_intercept", act = 3, line = "military", title = "The Landline" }, {
    build = function(ctx)
        local s = ctx.saga
        local cp = s.checkpoint
        local tap = K.ring(ctx, cp, 70, 110)
        return {
            title = "The Landline",
            summary = "The Guard's radios are encrypted, but the old phone line out of " .. cp.name .. " still runs past a junction box down the road. Splice in and listen.",
            giver = "{leader.name}", site = cp, risk = 2,
            steps = {
                B.step("tap", "Splice the line", {
                    B.reach("Find the junction box", tap, 8),
                    B.interact("Splice into the line", "Splice the line", tap, { duration = 260 }),
                }),
                B.step("listen", "Listen", { B.radio("Listen in", "a3_intercept:listen", "Phone line (tapped)") }),
            },
            reward = K.reward(ctx, "small", "community"),
        }
    end,
    dialogues = {
        listen = { radio = true, start = "r", nodes = {
            r = { route = { { cond = { "twist", "firebreak" }, next = "req" }, { next = "tri" } }, text = "" },
            req = { speaker = "Command", role = "command",
                text = "Confirm the pull-out is on schedule. You are authorized to requisition fuel, vehicles and medical supplies from civilian holdouts in your sector. Civilians are not to be moved past the cordon. Repeat, not past the cordon.",
                next = "req2" },
            req2 = { speaker = "{officer.callsign}", role = "officer",
                text = "[hesitant] Sir, if we take their fuel and their medicine, half of them won't make it through the winter.",
                byArch = { bythebook = "Sir, understood. For the record, taking their fuel and medicine will cost lives over the winter." },
                next = "req3" },
            req3 = { speaker = "Command", role = "command",
                text = "Noted. Your orders stand. The cordon stays closed. Acknowledge.",
                next = "req4" },
            req4 = { speaker = "{officer.callsign}", role = "officer", text = "Acknowledged.",
                effects = { { "reveal", "firebreak" } }, ["end"] = true },
            tri = { speaker = "Command", role = "command",
                text = "Confirm your seat count for the last convoy. Priority is your personnel, then medical and technical civilians on the list we sent. No one else boards. We don't have the room.",
                next = "tri2" },
            tri2 = { speaker = "{officer.callsign}", role = "officer",
                text = "Sir, the medic at the settlement is on that list. Nobody else from there is. They're going to find out.",
                byArch = { bythebook = "Understood, sir. The settlement's medic is on the list. I'll make the approach." },
                next = "tri3" },
            tri3 = { speaker = "Command", role = "command",
                text = "Then make sure the medic is on the truck before they do. Acknowledge.",
                next = "tri4" },
            tri4 = { speaker = "{officer.callsign}", role = "officer", text = "Acknowledged.",
                effects = { { "reveal", "lab" } }, ["end"] = true },
        } },
    },
})

---------------------------------------------------------------------------
-- 2. Three Calls: choose a side
---------------------------------------------------------------------------

K.chapter({ id = "a3_council", act = 3, line = "finale", title = "Three Calls", requires = { "a3_intercept" } }, {
    build = function(ctx)
        return {
            title = "Three Calls",
            summary = "Everyone knows now. Everyone is calling you.",
            giver = "Everyone", risk = 1,
            steps = { B.step("choose", "Choose", { B.radio("Answer the radio", "a3_council:choose", "Three channels") }) },
            reward = K.reward(ctx, "medium"),
        }
    end,
    dialogues = {
        choose = { radio = true, start = "a", nodes = {
            a = { speaker = "{leader.name}", role = "leader",
                text = "You heard it. We all did. I don't know how to fight soldiers. I don't even know if we can. But we're not giving them what we need to get through the winter. Not without a fight.",
                next = "b" },
            b = { speaker = "{officer.callsign}", role = "officer",
                text = "This is the Guard. I know what you heard. I didn't write those orders, but they're happening with or without me. Work with me and I can keep it orderly. Nobody has to get hurt.",
                byArch = {
                    burnedout = "It's me. I know what you heard. I'm not going to defend it. It's happening either way. If you're with me, I can at least make sure nobody gets shot over a fuel tank.",
                },
                next = "c" },
            c = { speaker = "{warlord.name}", role = "warlord",
                text = "Hey. It's me. You've been a real problem for me this season, so I'll keep it short. The soldiers are leaving and they're taking everything with them. When they're gone, somebody has to run things around here. Come talk to me.",
                byArch = {
                    psychotic = "[amused] There you are. You know, I've thought about killing you a lot this season. Funny thing is, I like you. The soldiers are running, your farmers are going to starve, and I'm the only one with a plan. Come see me.",
                },
                next = "d" },
            d = { speaker = "", text = "Three channels. Static in between. Your thumb on the key.",
                choices = {
                    { text = "[{saga.settlement}] We stand together.", ["end"] = true, tags = { "loyal", "defiant" },
                        effects = { { "choose", "side", "community" }, { "standing", "community", 25 }, { "standing", "military", -50 },
                            { "power", "community", 8 }, { "chronicle", "{me.first} stood with {saga.settlement} against the {military.name}." } } },
                    { text = "[{military.name}] I'll work with you. Keep it orderly.", ["end"] = true, tags = { "pragmatic", "lawful" },
                        effects = { { "choose", "side", "military" }, { "standing", "military", 30 }, { "standing", "community", -25 },
                            { "power", "military", 8 }, { "chronicle", "{me.first} sided with the {military.name}. {saga.settlement} stopped answering the radio." } } },
                    { text = "[{warlord.name}] I'll come talk.", ["end"] = true, tags = { "ruthless", "greed" },
                        effects = { { "choose", "side", "warlord" }, { "standing", "antagonist", 85 }, { "standing", "community", -35 },
                            { "standing", "military", -40 }, { "power", "antagonist", 10 },
                            { "chronicle", "{me.first} went over to {warlord.name}'s crew." } } },
                } },
        } },
    },
})

---------------------------------------------------------------------------
-- SETTLEMENT PATH
---------------------------------------------------------------------------

K.chapter({ id = "a3c_blind", act = 3, line = "community", title = "Radio Silence", requires = { "a3_council" }, cond = K.side("community") }, {
    build = function(ctx)
        local steps = K.shapeSabotage(ctx, { role = "military", title = "Take out the Guard's radio" })
        return {
            title = "Radio Silence",
            summary = "The {military.name} can't coordinate the requisition without their radio. Take it out and buy {saga.settlement} some time.",
            giver = "{leader.name}", risk = 4, steps = steps,
            reward = K.reward(ctx, "large", "community"),
            standingReward = { community = 8 },
            onComplete = { { "power", "military", -10 }, { "chronicle", "The {military.name}'s radio went dead." } },
        }
    end,
})

K.chapter({ id = "a3c_armory", act = 3, line = "community", title = "Rifles", requires = { "a3_council" }, cond = K.side("community") }, {
    build = function(ctx)
        local s = ctx.saga
        local site = K.site(ctx, { "gunstore", "police", "military" }, 300, 900)
        local steps = K.shapeSupply(ctx, { site = site, title = "Search " .. site.name, text = "Find rifles and ammunition",
            itemType = "Base.Bag_DuffelBag", itemName = "Bag of rifles", rivalRole = "military",
            complication = ctx.rng:pick({ "occupied", "locked" }),
            deliverTo = K.point(s.home, 1), deliverName = "Armorer" })
        return {
            title = "Rifles",
            summary = "Eleven rifles won't stop a Guard detachment. " .. site.name .. " might still have a locked cabinet nobody's opened.",
            giver = "{leader.name}", site = site, risk = 4, steps = steps,
            reward = K.reward(ctx, "medium", "community"),
            onComplete = { { "power", "community", 10 }, { "flag", "settlementArmed" } },
        }
    end,
})

K.chapter({ id = "a3c_evac", act = 3, line = "lost", title = "The Children", requires = { "a3_council" }, cond = K.side("community"), optional = 0.8 }, {
    build = function(ctx)
        local fallback = K.site(ctx, { "church", "school", "library", "warehouse" }, 250, 600)
        return {
            title = "The Children",
            summary = "{doctor.first} wants the sick, the old and the kids moved to " .. fallback.name .. " before the soldiers come. Someone has to secure it and hold it until they're settled.",
            giver = "{leader.name}", site = fallback, risk = 3,
            steps = {
                B.step("go", "Secure the building", {
                    B.reach("Reach " .. fallback.name, fallback, fallback.radius + 10),
                    B.infected("Clear the infected", ctx.rng:int(10, 20), fallback, fallback.radius + 30),
                }),
                B.step("hold", "Hold while they arrive", {
                    B.allies(K.f("community"), 2, fallback),
                    B.hold("Hold the building while the others arrive", fallback, 120, nil, { waves = 3, zombieWave = 8 }),
                }),
            },
            reward = K.reward(ctx, "medium", "community"),
            standingReward = { community = 10 },
            onComplete = { { "flag", "weakEvacuated" }, { "chronicle", "The children and the sick were moved out of {saga.settlement}." } },
        }
    end,
})

K.chapter({ id = "a3c_line", act = 3, line = "community", title = "The Requisition", finale = true,
    requires = { "a3c_blind", "a3c_armory" }, cond = K.side("community") }, {
    build = function(ctx)
        local s = ctx.saga
        return {
            title = "The Requisition",
            summary = "The soldiers are coming for the fuel and the medicine. Trucks on the county road tonight. {saga.settlement} isn't handing anything over.",
            giver = "{leader.name}", risk = 5,
            steps = {
                B.step("ready", "Take your position", {
                    B.reach("Get to " .. s.home.name, s.home, s.home.radius + 5),
                    B.wait("Wait for them", 1, { atHour = 22 }),
                }),
                B.step("fight", "Hold the fence", {
                    B.allies(K.f("community"), 3, s.home),
                    B.hold("Hold " .. s.settlement, s.home, 210, K.f("military"),
                        { waves = 4, waveSize = K.guards(ctx, 3), radius = s.home.radius + 10,
                          startLine = "Headlights. A loudspeaker: 'This is a lawful requisition. Step away from the fence.'" }),
                }),
                leaderMeet(ctx, "dawn", "Morning", "a3c_line:dawn"),
            },
            reward = K.reward(ctx, "spine", "community"),
            standingReward = { community = 20, military = -20 },
            onComplete = { { "power", "military", -20 }, { "power", "community", 10 },
                { "chronicle", "The {military.name} pulled back from {saga.settlement} without the fuel." } },
            onFail = { { "power", "community", -25 }, { "flag", "settlementBurned" },
                { "chronicle", "The soldiers took everything from {saga.settlement}. People started leaving the next day." } },
        }
    end,
    dialogues = {
        dawn = { start = "a", nodes = {
            a = { speaker = "{leader.name}", role = "leader",
                text = "[relieved] It's morning and we're still here. With our fuel. I keep saying it out loud to make sure it's true.",
                choices = {
                    { text = "They'll try again.", next = "b" },
                    { text = "Your people did this. Not me.", next = "c", tags = { "loyal" } },
                } },
            b = { speaker = "{leader.name}", role = "leader",
                text = "Maybe. Or maybe they'll just leave like they were always going to. Either way, the road crew is still out there, and they watched all of this.",
                ["end"] = true },
            c = { speaker = "{leader.name}", role = "leader",
                text = "Both of us did. Now we have to finish it. The road crew is still out there, and they're not going to wait for spring.",
                ["end"] = true },
        } },
    },
})

---------------------------------------------------------------------------
-- MILITARY PATH
---------------------------------------------------------------------------

K.chapter({ id = "a3m_orders", act = 3, line = "military", title = "Briefing", requires = { "a3_council" }, cond = K.side("military") }, {
    build = function(ctx)
        local s = ctx.saga
        local cp = s.checkpoint
        return {
            title = "Briefing",
            summary = "{officer.full} wants you at " .. cp.name .. " to go over the plan in person.",
            giver = "{officer.full}", site = cp, risk = 1,
            steps = {
                B.step("go", "Go to the checkpoint", { B.reach("Reach " .. cp.name, cp, cp.radius + 20) }),
                K.meet("meet", "Talk to {officer.full}", K.f("military"), s.cast.officer.full, K.point(cp, 1), "a3m_orders:meet"),
            },
            reward = K.reward(ctx, "medium", "military"),
        }
    end,
    dialogues = {
        meet = { start = "a", nodes = {
            a = { speaker = "{officer.full}", role = "officer",
                text = "I wanted you to hear it from me and not from a wiretap. I don't like these orders. I'm going to carry them out anyway, because the alternative is someone who does like them.",
                byArch = {
                    bythebook = "Thanks for coming in. Here's the situation. The orders are clear and they're lawful. I'd rather carry them out with someone who knows the area than without.",
                },
                choices = {
                    { text = "Then let's do it with as little harm as possible.", next = "clean", tags = { "pragmatic" } },
                    { text = "Orders are orders.", next = "loyal", tags = { "lawful" } },
                    { text = "[Persuade] There might be another way.", check = { kind = "persuade", base = 0.3, role = "military" },
                        pass = "other", fail = "noother", tags = { "mercy" } },
                } },
            clean = { speaker = "{officer.full}", role = "officer",
                text = "That's the idea. First, the road crew is sitting on the route we need for the convoy. Clear them out. Then we deal with the rest.",
                effects = { { "trust", "officer", 10 } }, ["end"] = true },
            loyal = { speaker = "{officer.full}", role = "officer",
                text = "Don't say it like it's easy. It isn't. It shouldn't be.",
                byArch = { bythebook = "Good. Then we're on the same page. First job is the road crew on our convoy route." },
                effects = { { "trust", "officer", -5 } }, ["end"] = true },
            other = { speaker = "{officer.full}", role = "officer",
                text = "If there's another way, find it before Command finds out I'm looking for one. That's all I can give you.",
                effects = { { "flag", "officerWavering" }, { "trust", "officer", 15 } }, ["end"] = true },
            noother = { speaker = "{officer.full}", role = "officer",
                text = "There isn't. I've looked. Clear the road.", ["end"] = true },
        } },
    },
})

K.chapter({ id = "a3m_purge", act = 3, line = "warlord", title = "The Convoy Route", requires = { "a3m_orders" }, cond = K.side("military") }, {
    build = function(ctx)
        local site = K.site(ctx, { "gas", "warehouse", "motel", "bar" }, 300, 900)
        local staging = K.ring(ctx, site, 35, 50)
        local steps = {
            B.step("stage", "Meet the soldiers", {
                B.allies(K.f("military"), 4, staging),
                B.reach("Meet the soldiers at the staging point", staging, 12),
            }),
        }
        local bounty = K.shapeBounty(ctx, { site = site, role = "antagonist", guards = 5, title = "Hit " .. site.name,
            killText = "Clear out the road crew" })
        for _, st in ipairs(bounty) do steps[#steps + 1] = st end
        return {
            title = "The Convoy Route",
            summary = "{warlord.name}'s crew holds " .. site.name .. " and the road past it. The convoy needs that road.",
            giver = "{officer.full}", site = site, risk = 4, steps = steps,
            reward = K.reward(ctx, "large", "military"),
            standingReward = { military = 12, antagonist = -10 },
            onComplete = { { "power", "antagonist", -12 }, { "power", "military", 6 } },
        }
    end,
})

K.chapter({ id = "a3m_houses", act = 3, line = "community", title = "Requisition", requires = { "a3m_purge" },
    cond = function(s) return s.choices and s.choices.side == "military" and s.twists.firebreak ~= nil end }, {
    build = function(ctx)
        local s = ctx.saga
        local p1, p2, p3 = K.ring(ctx, s.home, 6, 18), K.ring(ctx, s.home, 6, 18), K.ring(ctx, s.home, 6, 18)
        return {
            title = "Requisition",
            summary = "The convoy needs fuel and medical supplies. {saga.settlement} has both. You know where they keep them.",
            giver = "{officer.full}", risk = 3,
            steps = {
                B.step("take", "Collect the supplies", {
                    B.interact("Drain the generator tank", "Drain the fuel", p1, { duration = 180 }),
                    B.interact("Take the fuel cans from the shed", "Take the fuel cans", p2, { duration = 150 }),
                    B.interact("Take the medicine from the clinic", "Take the medicine", p3, { duration = 150 }),
                }),
                leaderMeet(ctx, "face", "Someone saw you", "a3m_houses:face"),
            },
            reward = K.reward(ctx, "large", "military"),
            standingReward = { military = 15, community = -30 },
        }
    end,
    dialogues = {
        face = { start = "a", nodes = {
            a = { speaker = "{leader.name}", role = "leader",
                text = "[angry] I watched you do it. You walked right past the room where the kids sleep and took the fuel that keeps them warm. Say something. Anything.",
                choices = {
                    { text = "I left some of it behind the shed. Enough for a few weeks.", next = "warn", tags = { "mercy" },
                        effects = { { "flag", "warnedSettlement" }, { "standing", "military", -15 }, { "standing", "community", 10 } } },
                    { text = "They'd have taken it by force. This way nobody got shot.", next = "cold", tags = { "pragmatic", "cold" },
                        effects = { { "flag", "settlementBurned" }, { "power", "community", -35 } } },
                    { text = "[Say nothing]", next = "silent", effects = { { "flag", "settlementBurned" }, { "power", "community", -35 } } },
                } },
            warn = { speaker = "{leader.name}", role = "leader",
                text = "Behind the shed. Okay. That's something. It's not enough, but it's something. Now get out.",
                effects = { { "chronicle", "Someone left fuel hidden behind {saga.settlement}'s shed." } }, ["end"] = true },
            cold = { speaker = "{leader.name}", role = "leader",
                text = "[bitterly] Nobody got shot. Right. We'll just freeze instead. Thank you so much.",
                effects = { { "chronicle", "{saga.settlement} lost its fuel and medicine to the {military.name}." } }, ["end"] = true },
            silent = { speaker = "{leader.name}", role = "leader", text = "Right.", ["end"] = true },
        } },
    },
})

K.chapter({ id = "a3m_bringin", act = 3, line = "community", title = "The Medic", requires = { "a3m_purge" },
    cond = function(s) return s.choices and s.choices.side == "military" and s.twists.lab ~= nil end }, {
    build = function(ctx)
        local s = ctx.saga
        return {
            title = "The Medic",
            summary = "{doctor.name} is on the evacuation list. {officer.full} wants them at {checkpoint.name} before the settlement finds out nobody else is.",
            giver = "{officer.full}", risk = 3,
            steps = {
                K.homeMeet(ctx, "talk", "Talk to {doctor.first}", "doctor", "a3m_bringin:talk"),
                B.step("walk", "Bring {doctor.first} to the checkpoint", {
                    B.reach("Reach " .. s.checkpoint.name, s.checkpoint, s.checkpoint.radius + 15),
                }, { onStart = { { "ambush", "community", 2 } },
                    say = "[[Somebody from the settlement is following you.|You hear shouting behind you.|Two people from the settlement on the road behind you, armed.]]" }),
            },
            reward = K.reward(ctx, "large", "military"),
            standingReward = { military = 20, community = -30 },
            onComplete = { { "cast", "doctor", "status", "with_military" },
                { "chronicle", "{doctor.name} left {saga.settlement} with the {military.name}." } },
        }
    end,
    dialogues = {
        talk = { start = "a", nodes = {
            a = { speaker = "{doctor.name}", role = "doctor",
                text = "I know why you're here. They told me I'm on a list. A seat on a truck out of the county. Just me. Not the kids, not anyone else.",
                byArch = {
                    burnout = "I know. They told me. A seat on a truck, just for me. And the worst part is part of me wants to go. I'm so tired.",
                },
                choices = {
                    { text = "[Persuade] Out there you can help a lot more people. Go.", check = { kind = "persuade", base = 0.45 },
                        pass = "willing", fail = "refuse", tags = { "pragmatic" } },
                    { text = "You're coming either way. I'm sorry.", next = "forced", tags = { "cold" } },
                    { text = "Don't go. Hide. I'll tell them you ran.", next = "run", tags = { "mercy" } },
                } },
            willing = { speaker = "{doctor.name}", role = "doctor",
                text = "Maybe. Maybe that's true. Let me write down the doses for the people here first. Then I'll go.",
                effects = { { "flag", "doctorWilling" } }, ["end"] = true },
            refuse = { speaker = "{doctor.name}", role = "doctor",
                text = "No. These people need me more than some base camp does. You'll have to make me.",
                next = "forced" },
            forced = { speaker = "{doctor.name}", role = "doctor",
                text = "[coldly] Then let's go. And you can explain it to them when they get sick.",
                effects = { { "flag", "doctorForced" } }, ["end"] = true },
            run = { speaker = "{doctor.name}", role = "doctor",
                text = "Thank you. I won't forget this. I don't think the soldiers will either.",
                effects = { { "cast", "doctor", "status", "hiding" }, { "standing", "military", -25 }, { "flag", "doctorHidden" },
                    { "trust", "officer", -20 }, { "complete" },
                    { "chronicle", "{doctor.name} disappeared before the {military.name} could take them." } }, ["end"] = true },
        } },
    },
})

K.chapter({ id = "a3m_clean", act = 3, line = "military", title = "Counterattack", finale = true,
    requiresAny = { "a3m_houses", "a3m_bringin" }, cond = K.side("military") }, {
    build = function(ctx)
        local s = ctx.saga
        local cp = s.checkpoint
        return {
            title = "Counterattack",
            summary = "{warlord.name}'s crew knows the soldiers are pulling out, and they want the convoy. They're coming for {checkpoint.name}.",
            giver = "{officer.full}", site = cp, risk = 5,
            steps = {
                B.step("hold", "Get to the checkpoint", {
                    B.reach("Get to " .. cp.name, cp, cp.radius + 10),
                    B.allies(K.f("military"), 4, cp),
                }),
                B.step("fight", "Hold the checkpoint", {
                    B.hold("Hold " .. cp.name, cp, 180, K.f("antagonist"), { waves = 4, waveSize = K.guards(ctx, 3), radius = cp.radius + 10 }),
                }),
                K.meet("debrief", "Debrief", K.f("military"), s.cast.officer.full, K.point(cp, 1), "a3m_clean:debrief"),
            },
            reward = K.reward(ctx, "spine", "military"),
            standingReward = { military = 20 },
            onComplete = { { "power", "antagonist", -10 }, { "power", "military", 10 } },
        }
    end,
    dialogues = {
        debrief = { start = "a", nodes = {
            a = { speaker = "{officer.full}", role = "officer",
                text = "Command wants a full report. Everything we did and why. I'm the one writing it. How do you want it to read?",
                choices = {
                    { text = "The truth. All of it.", next = "truth", tags = { "honest" }, effects = { { "flag", "reportTruth" } } },
                    { text = "Write that it went smoothly.", next = "lie", tags = { "pragmatic" }, effects = { { "flag", "reportFalse" } } },
                    { text = "Write that the road crew took the supplies.", next = "frame", tags = { "ruthless" }, effects = { { "flag", "reportFramed" } } },
                } },
            truth = { speaker = "{officer.full}", role = "officer",
                text = "All right. I'll sign it. If they want someone to blame, it'll be me. Now let's finish the road crew before the convoy rolls.", ["end"] = true },
            lie = { speaker = "{officer.full}", role = "officer",
                text = "Smoothly. Sure. Let's deal with the road crew before I have time to think about it.", ["end"] = true },
            frame = { speaker = "{officer.full}", role = "officer",
                text = "That's convenient. I hate that it's convenient. Fine. Let's go make it true.", ["end"] = true },
        } },
    },
})

---------------------------------------------------------------------------
-- ROAD CREW PATH
---------------------------------------------------------------------------

K.chapter({ id = "a3w_kneel", act = 3, line = "warlord", title = "Terms", requires = { "a3_council" }, cond = K.side("warlord") }, {
    build = function(ctx)
        local s = ctx.saga
        local hold = s.strongholdSite
        return {
            title = "Terms",
            summary = "{warlord.name} is waiting at {saga.stronghold}. Walk in the front. Nobody's supposed to shoot.",
            giver = "{warlord.name}", site = hold, risk = 2,
            steps = {
                B.step("go", "Go to {saga.stronghold}", { B.reach("Reach " .. hold.name, hold, hold.radius + 10) },
                    { say = "[[Nobody raises a gun. They just watch you.|Somebody laughs. Somebody else tells them to shut up.|A kid with a rifle that's too big for him opens the gate.]]" }),
                K.meet("kneel", "Talk to {warlord.name}", K.f("antagonist"), s.cast.warlord.name, K.point(hold, 1), "a3w_kneel:meet"),
            },
            reward = K.reward(ctx, "large", "antagonist"),
            onComplete = { { "meet", "warlord" } },
        }
    end,
    dialogues = {
        meet = { start = "a", nodes = {
            a = { speaker = "{warlord.name}", role = "warlord",
                text = "Sit down. You want something to drink? We've got coffee, and whiskey if you'd rather. I'll be straight with you. I've got forty people here who eat every day. I'd like it to stay that way.",
                byArch = {
                    psychotic = "[cheerfully] Sit, sit. Don't look at the guys by the door, they're just there for decoration. Mostly. You know, I almost had you killed twice this season. I'm glad I didn't. You're more fun alive.",
                },
                choices = {
                    { text = "Why do you take people?", next = "take" },
                    { text = "What do you want from me?", next = "want" },
                    { text = "Your {lost.kin} is at the settlement.", next = "lost", cond = { "revealed", "blood" } },
                } },
            take = { speaker = "{warlord.name}", role = "warlord",
                text = "Because people can work. Food runs out. Fuel runs out. A person who can dig a ditch or fix an engine keeps being useful. The soldiers are leaving people to freeze. I put them to work and feed them. You tell me which is worse.",
                byArch = {
                    psychotic = "[laughs] Because I can. That's the honest answer. Nobody's coming to stop me. You'd do the same if you thought about it long enough. Everyone would.",
                },
                next = "want" },
            lost = { speaker = "{warlord.name}", role = "warlord",
                text = "I know where {lost.he} is. I know {lost.he} came back with you. If you ever get the chance, tell {lost.him} the door's still open here. That's all.",
                next = "want" },
            want = { speaker = "{warlord.name}", role = "warlord",
                text = "Two things. The settlement has medicine I need. The soldiers have a supply truck I need more. Bring me both, and you're one of us. Food, a bed, people who'll back you up.",
                choices = {
                    { text = "Done.", ["end"] = true, tags = { "ruthless" }, effects = { { "trust", "warlord", 10 } } },
                    { text = "I'm not working for you. I'm working with you.", ["end"] = true, tags = { "defiant" }, effects = { { "flag", "partner" } } },
                    { text = "And if I say no?", next = "no" },
                } },
            no = { speaker = "{warlord.name}", role = "warlord",
                text = "Then you walk out the same way you came in, and next time we meet it won't be over coffee. Your call.",
                byArch = { psychotic = "Then you walk out. And I'll find out where you sleep. I always do. Your call." },
                choices = {
                    { text = "Fine. Done.", ["end"] = true, tags = { "ruthless" }, effects = { { "trust", "warlord", 5 } } },
                } },
        } },
    },
})

K.chapter({ id = "a3w_proof", act = 3, line = "community", title = "The Clinic", requires = { "a3w_kneel" }, cond = K.side("warlord") }, {
    build = function(ctx)
        local s = ctx.saga
        local store = K.point(s.home, 2)
        local hold = s.strongholdSite
        return {
            title = "The Clinic",
            summary = "{saga.settlement}'s medicine is in {doctor.first}'s clinic. They still open the gate for you. For now.",
            giver = "{warlord.name}", risk = 3,
            steps = {
                B.step("steal", "Take the medicine", {
                    B.lock("Get into the clinic storeroom", "Storeroom door", store, { difficulty = 0.5 }),
                    B.retrieve("Take the medicine", store, "Base.FirstAidKit", "The settlement's medicine"),
                }),
                B.step("deliver", "Bring it to {saga.stronghold}", {
                    B.npc(K.f("antagonist"), "Quartermaster", K.point(hold, 1), { role = "quartermaster" }),
                    B.handin("Hand over the medicine", { { quest = true } }, K.point(hold, 1)),
                }, { onStart = { { "ambush", "community", 2 } } }),
            },
            reward = K.reward(ctx, "large", "antagonist"),
            standingReward = { antagonist = 10, community = -25 },
            onComplete = { { "power", "community", -12 }, { "power", "antagonist", 6 },
                { "chronicle", "{saga.settlement}'s medicine was stolen. They know who took it." } },
        }
    end,
})

K.chapter({ id = "a3w_train", act = 3, line = "military", title = "The Supply Truck", requires = { "a3w_kneel" }, cond = K.side("warlord") }, {
    build = function(ctx)
        local s = ctx.saga
        local road = DDS.Sites.ring(s.checkpoint.x, s.checkpoint.y, 120, 260, ctx.rng)
        return {
            title = "The Supply Truck",
            summary = "A {military.name} supply truck uses this road every few days. {warlord.name} wants what's on it, and nobody left to report it missing.",
            giver = "{warlord.name}", site = road, risk = 4,
            steps = {
                B.step("hit", "Hit the supply truck", {
                    B.allies(K.f("antagonist"), 3, K.ring(ctx, road, 25, 35)),
                    B.eliminate("Kill the escort", K.f("military"), K.guards(ctx, 4), road),
                    B.retrieve("Take the crate", road, "Base.Bag_Military", "Military supply crate"),
                }),
                B.step("deliver", "Bring it to {saga.stronghold}", {
                    B.npc(K.f("antagonist"), "Quartermaster", K.point(s.strongholdSite, 1), { role = "quartermaster" }),
                    B.handin("Hand over the crate", { { quest = true } }, K.point(s.strongholdSite, 1)),
                }),
            },
            reward = K.reward(ctx, "large", "antagonist"),
            standingReward = { antagonist = 10, military = -20 },
            onComplete = { { "power", "military", -10 }, { "power", "antagonist", 8 } },
        }
    end,
})

K.chapter({ id = "a3w_bridge", act = 3, line = "military", title = "Cut Off", finale = true,
    requires = { "a3w_proof", "a3w_train" }, cond = K.side("warlord") }, {
    build = function(ctx)
        local steps = K.shapeSabotage(ctx, { role = "military", title = "Take out the Guard's radio" })
        steps[#steps + 1] = B.step("report", "Report in", {
            B.radio("Radio {saga.stronghold}", "a3w_bridge:report", "{warlord.name}"),
        })
        return {
            title = "Cut Off",
            summary = "Before {warlord.name} moves on the checkpoint, the soldiers need to lose their radio.",
            giver = "{warlord.name}", risk = 4, steps = steps,
            reward = K.reward(ctx, "spine", "antagonist"),
            standingReward = { antagonist = 10 },
            onComplete = { { "power", "military", -12 } },
        }
    end,
    dialogues = {
        report = { radio = true, start = "a", nodes = {
            a = { speaker = "{warlord.name}", role = "warlord",
                text = "Their radio's dead. I can hear them yelling at each other from here. Good. Get some rest. We go for the checkpoint soon.",
                byArch = {
                    psychotic = "Their radio's dead. You should hear them, running around like chickens. I love this part. Get some sleep. We go soon.",
                },
                choices = {
                    { text = "Let's finish it.", ["end"] = true, tags = { "ruthless" } },
                    { text = "And afterwards? What happens to the settlement?", next = "after" },
                } },
            after = { speaker = "{warlord.name}", role = "warlord",
                text = "They pay like everyone else, and they stay alive. That's a better deal than the soldiers were offering them.",
                byArch = { psychotic = "That depends on how nicely they ask. Don't worry about it." },
                ["end"] = true },
        } },
    },
})

return true
