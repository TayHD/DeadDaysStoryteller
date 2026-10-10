-- ACT IV: WINTER
-- The last push against whoever the player didn't side with.

require "DeadDaysStory/DDS_StoryKit"

local K = DDS.Kit
local B = DDS.Quests.B

local function war(s)
    local side = s.choices and s.choices.side or "community"
    if side == "warlord" then
        return { side = side, enemy = "military", ally = "antagonist", target = s.checkpoint, bossKey = "officer",
            secondName = "the detachment's sergeant" }
    end
    return { side = side, enemy = "antagonist", ally = side == "military" and "military" or "community",
        target = s.strongholdSite, bossKey = "warlord",
        secondName = (s.cast.lieutenant.status == "alive" and s.cast.lieutenant.name) or "{warlord.name}'s new second" }
end

---------------------------------------------------------------------------
-- 1. Allies (political)
---------------------------------------------------------------------------

K.chapter({ id = "a4_rally", act = 4, line = "finale", title = "Allies" }, {
    build = function(ctx)
        local s = ctx.saga
        local w = war(s)
        local repSite = K.site(ctx, { "bar", "church", "gas", "warehouse" }, 200, 700)
        local need = ctx.rng:pick({
            { { type = "Base.Bullets9mmBox", count = 3, label = "boxes of 9mm" }, { type = "Base.Bandage", count = 6, label = "bandages" } },
            { { type = "Base.ShotgunShellsBox", count = 2, label = "boxes of shells" }, { type = "Base.TinnedBeans", count = 6, label = "cans of food" } },
        })
        local allyAt = w.side == "warlord" and K.point(s.strongholdSite, 1)
            or (w.side == "military" and K.point(s.checkpoint, 1) or K.point(s.home, 1))
        return {
            title = "Allies",
            summary = "You can't take on the {enemy.name} alone. The {wildcard.name} have people and guns and no reason to help anyone. Talk to them, and get your own side supplied for the fight.",
            giver = "You", risk = 2,
            steps = {
                K.meet("wildcard", "Talk to the {wildcard.name}", K.f("wildcard"), "Their spokesman", K.point(repSite, 1), "a4_rally:wildcard",
                    { npc = { role = "spokesman" } }),
                B.step("arm", "Supply your side", {
                    B.npc(K.f(w.ally), "Quartermaster", allyAt, { role = "quartermaster" }),
                    B.handin("Bring supplies for the fight", need, allyAt, { label = "Hand over supplies" }),
                }),
            },
            reward = K.reward(ctx, "medium"),
            standingReward = { [w.ally] = 10 },
            onComplete = { { "power", w.ally, 8 } },
        }
    end,
    dialogues = {
        wildcard = { start = "a", nodes = {
            a = { speaker = "Spokesman", role = "spokesman",
                text = "Everybody wants our help all of a sudden. Last month you'd have shot us for our boots. Why should we bleed for your fight?",
                choices = {
                    { text = "Because when they're done with us, they'll come for you.", next = "fear" },
                    { text = "[Persuade] Because whoever wins will remember who helped.", check = { kind = "persuade", base = 0.4, role = "wildcard" },
                        pass = "yes", fail = "no" },
                    { text = "What would it take?", next = "price", tags = { "greed" } },
                    { text = "Then stay out of the way.", next = "neutral" },
                } },
            fear = { speaker = "Spokesman", role = "spokesman",
                text = "Probably true. Fine. We'll watch the back roads. Anybody running from the fight runs into us.",
                effects = { { "flag", "wildcardAllied" }, { "standing", "wildcard", 10 } }, ["end"] = true },
            yes = { speaker = "Spokesman", role = "spokesman", text = "That's a reason I can sell to my people. We're in. Don't make us regret it.",
                effects = { { "flag", "wildcardAllied" }, { "standing", "wildcard", 15 }, { "power", "wildcard", 5 } }, ["end"] = true },
            no = { speaker = "Spokesman", role = "spokesman", text = "Nice speech. No.",
                effects = { { "flag", "wildcardRefused" } }, ["end"] = true },
            price = { speaker = "Spokesman", role = "spokesman", text = "Whatever they've got stored away when it's over. All of it.",
                choices = {
                    { text = "Deal.", ["end"] = true, effects = { { "flag", "wildcardAllied" }, { "flag", "wildcardPaid" }, { "standing", "wildcard", 10 } } },
                    { text = "Too much.", ["end"] = true, effects = { { "flag", "wildcardRefused" } } },
                } },
            neutral = { speaker = "Spokesman", role = "spokesman", text = "That we can do.", ["end"] = true },
        } },
    },
})

---------------------------------------------------------------------------
-- 2. Recon
---------------------------------------------------------------------------

K.chapter({ id = "a4_eyes", act = 4, line = "finale", title = "Recon" }, {
    build = function(ctx)
        local w = war(ctx.saga)
        return {
            title = "Recon",
            summary = "Before anyone goes in, somebody has to know how many guns are inside " .. w.target.name .. " and where the gaps are.",
            giver = "You", site = w.target, risk = 3,
            steps = K.shapeRecon(ctx, { site = w.target, title = "Watch " .. w.target.name, intelName = "Notes on the guard rotation" }),
            reward = K.reward(ctx, "medium"),
            onComplete = { { "flag", "targetScouted" } },
        }
    end,
})

---------------------------------------------------------------------------
-- 3. Their Second
---------------------------------------------------------------------------

K.chapter({ id = "a4_head", act = 4, line = "finale", title = "Their Second", requires = { "a4_eyes" } }, {
    build = function(ctx)
        local w = war(ctx.saga)
        local post = K.site(ctx, { "gas", "house", "motel", "warehouse" }, 200, 700)
        local steps = K.shapeBounty(ctx, { site = post, role = w.enemy, guards = 4, title = "Go after " .. w.secondName,
            killText = "Take out " .. w.secondName .. "'s group" })
        local sab = K.shapeSabotage(ctx, { role = w.enemy, title = "Take out their radio" })
        for _, st in ipairs(sab) do st.id = "sab_" .. st.id; steps[#steps + 1] = st end
        return {
            title = "Their Second",
            summary = w.secondName .. " runs the {enemy.name}'s forward post. With them gone and the radio down, the main group can't call for help.",
            giver = "You", site = post, risk = 4, steps = steps,
            reward = K.reward(ctx, "large"),
            standingReward = { [w.enemy] = -10 },
            onComplete = { { "power", w.enemy, -12 }, { "flag", "enemyBlind" } },
        }
    end,
})

---------------------------------------------------------------------------
-- 4. FINALE
---------------------------------------------------------------------------

K.chapter({ id = "a4_reckoning", act = 4, line = "finale", title = "The Last of It", finale = true,
    requires = { "a4_rally", "a4_head" } }, {
    build = function(ctx)
        local s = ctx.saga
        local w = war(s)
        local t = w.target
        local staging = K.ring(ctx, t, 40, 55)
        local outer = K.guards(ctx, 5) - (s.flags.enemyBlind and 1 or 0) - (s.flags.stronghold_backdoor and 1 or 0)
        local inner = K.guards(ctx, 3)
        local boss = s.cast[w.bossKey]
        local steps = {
            B.step("stage", "Meet your people at the staging point", {
                B.allies(K.f(w.ally), 4, staging),
                B.reach("Join the others", staging, 14),
            }, { say = "[[Nobody says much. Somebody checks the same magazine three times.|Somebody's praying under their breath.|It's cold enough to see your breath.]]" }),
            B.step("gate", "Get through the gate", {
                B.eliminate("Break the defenders at the gate", K.f(w.enemy), math.max(3, outer), t,
                    { bark = "[[They're here!|Hold the gate!|Everybody up!]]" }),
                B.lock("Force the inner door", "Inner door", t.inner, { difficulty = 0.6, optional = true }),
            }),
            B.step("inside", "Push inside", {
                B.eliminate("Clear the rooms inside", K.f(w.enemy), inner, t.inner),
            }),
        }
        if w.bossKey == "warlord" and (s.flags.strongholdPen or s.flags.othersTaken) then
            table.insert(steps[3].objectives, B.captive("Free the people in the cooler", (DDS.Factions.pickCivilian(ctx.rng) or {}).id,
                "the prisoners", K.point(t, 2), { optional = true, cry = "[[Is it over?|In here! The cooler!|The door's chained!]]",
                    onDone = { { "flag", "prisonersFreed" }, { "standing", "community", 10 } } }))
        end
        steps[#steps + 1] = K.meet("boss", "Face {boss.name}", K.f(w.enemy), boss.name, t.inner, "a4_reckoning:boss",
            { npc = { mortal = true, role = "boss" } })
        return {
            title = "The Last of It",
            summary = "It ends at " .. t.name .. ". {boss.name} is inside.",
            giver = "You", site = t, risk = 5,
            steps = steps,
            reward = K.reward(ctx, "spine"),
            standingReward = { [w.ally] = 25 },
            onComplete = { { "power", w.enemy, -40 }, { "chronicle", "The fight at " .. t.name .. " is over." } },
        }
    end,
    dialogues = {
        boss = { start = "r", nodes = {
            r = { route = { { cond = { "flag", "choice_side", "warlord" }, next = "officer" }, { next = "warlord" } }, text = "" },

            warlord = { speaker = "{warlord.name}", role = "warlord",
                text = "[tired] Well. You got in. I had forty people eating every day in here. You know how many of them are going to make it through the winter now? Neither do I.",
                byArch = {
                    psychotic = "[laughs] Look at this. Look at what you did to my place. You know, I'd have made you my second. You don't hesitate. I always liked that about you.",
                },
                choices = {
                    { text = "Why did you do it? Any of it?", next = "w_why" },
                    { text = "Your {lost.kin} deserves an apology.", next = "w_lost", cond = { "revealed", "blood" } },
                    { text = "It's over.", next = "w_judge" },
                } },
            w_why = { speaker = "{warlord.name}", role = "warlord",
                text = "Because nobody else was going to. The Guard was leaving, the farmers were praying, and people were starving in the meantime. I did what had to be done. I'm not going to apologize for keeping my people fed.",
                byArch = {
                    psychotic = "Because it was easy. Everything fell apart and nobody stopped me. I kept waiting for someone to. Turns out it was you.",
                },
                next = "w_judge" },
            w_lost = { speaker = "{warlord.name}", role = "warlord",
                text = "If {lost.he} wants to hear it, {lost.he} can come and hear it from me. I'm not sending it through the person who's about to decide whether I live.",
                effects = { { "flag", "warlordSoftened" } }, next = "w_judge" },
            w_judge = { speaker = "{warlord.name}", role = "warlord",
                text = "Go on, then. Everybody's watching.",
                choices = {
                    { text = "[Execute]", next = "w_exec", tags = { "ruthless" } },
                    { text = "Leave the county. Don't come back.", next = "w_spare", tags = { "mercy" } },
                    { text = "You're going back to the settlement. They'll decide what happens to you.", next = "w_trial", tags = { "lawful", "honest" } },
                } },
            w_exec = { speaker = "{warlord.name}", role = "warlord", text = "Fair enough.",
                byArch = { psychotic = "[laughs] Yeah. I'd have done the same." },
                effects = { { "killNpc" }, { "cast", "warlord", "status", "dead" }, { "flag", "bossKilled" },
                    { "chronicle", "{warlord.name} was killed at {saga.stronghold}." } }, ["end"] = true },
            w_spare = { speaker = "{warlord.name}", role = "warlord", text = "Mercy. Huh. You'll regret it. People usually do.",
                effects = { { "releaseNpc", nil, "You'll see me again." }, { "cast", "warlord", "status", "exiled" }, { "flag", "bossSpared" },
                    { "flag", "bossName", "{warlord.name}" }, { "flag", "bossMoniker", "{warlord.last}" },
                    { "chronicle", "{warlord.name} was let go and left the county." } }, ["end"] = true },
            w_trial = { speaker = "{warlord.name}", role = "warlord",
                text = "A trial. In front of farmers. That's the most civilized thing anyone around here has done since summer.",
                effects = { { "releaseNpc", nil, "Lead the way." }, { "cast", "warlord", "status", "on_trial" }, { "flag", "bossTried" }, { "standing", "community", 15 },
                    { "chronicle", "{warlord.name} was taken to {saga.settlement} to stand trial." } }, ["end"] = true },

            officer = { speaker = "{officer.full}", role = "officer",
                text = "So that's it. I kept telling myself I'd refuse the orders when it came to it. I never did. You never even had to think about it.",
                byArch = {
                    bythebook = "Stand down your people. I'm not going to fight this anymore. Whatever you think of me, I followed lawful orders.",
                },
                choices = {
                    { text = "You were going to leave them to freeze.", next = "o_judge", cond = { "twist", "firebreak" } },
                    { text = "You were going to take their only medic and leave the rest.", next = "o_judge", cond = { "twist", "lab" } },
                    { text = "Tell your soldiers to put their weapons down. They can walk.", next = "o_judge" },
                } },
            o_judge = { speaker = "{officer.full}", role = "officer",
                text = "I know what I was going to do. I've known every night. So how does this end?",
                choices = {
                    { text = "[Execute]", next = "o_exec", tags = { "ruthless" } },
                    { text = "Take off the uniform and go.", next = "o_spare", tags = { "mercy" } },
                    { text = "[Persuade] Stay. Someone has to keep the trucks running.", check = { kind = "persuade", base = 0.35 },
                        pass = "o_join", fail = "o_refuse", tags = { "pragmatic" } },
                } },
            o_exec = { speaker = "{officer.full}", role = "officer", text = "[quietly] Tell my people it wasn't their fault.",
                effects = { { "killNpc" }, { "cast", "officer", "status", "dead" }, { "flag", "bossKilled" },
                    { "chronicle", "{officer.full} died at {checkpoint.name}. The {military.name} detachment is finished." } }, ["end"] = true },
            o_spare = { speaker = "{officer.full}", role = "officer", text = "The uniform's the only thing I have left that fits. Fine.",
                effects = { { "releaseNpc", nil, "Goodbye." }, { "cast", "officer", "status", "exiled" }, { "flag", "bossSpared" },
                    { "flag", "bossName", "{officer.full}" }, { "flag", "bossMoniker", "{officer.callsign}" } }, ["end"] = true },
            o_join = { speaker = "{officer.full}", role = "officer", text = "God help me. All right. Somebody has to keep the trucks running.",
                effects = { { "cast", "officer", "status", "turned" }, { "flag", "officerJoined" }, { "recruit", "officer" } }, ["end"] = true },
            o_refuse = { speaker = "{officer.full}", role = "officer", text = "No. I'm not working for a road crew. Do what you're going to do.",
                next = "o_judge" },
        } },
    },
})

return true
