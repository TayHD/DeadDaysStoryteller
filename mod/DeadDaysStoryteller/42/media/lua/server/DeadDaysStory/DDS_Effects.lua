-- Conditions, skill checks and effects: the shared vocabulary of dialogue
-- choices, mission steps and director events. All content is plain data
-- ({"op", args...}) so it can be stored in ModData and replayed.

require "DeadDaysStory/DDS_Core"
require "DeadDaysStory/DDS_State"
require "DeadDaysStory/DDS_Factions"
require "DeadDaysStory/DDS_Items"

DDS.Effects = DDS.Effects or {}
local E = DDS.Effects

local function saga() return DDS.State.world().saga end

local function compare(a, op, b)
    a, b = tonumber(a) or 0, tonumber(b) or 0
    if op == ">=" then return a >= b end
    if op == "<=" then return a <= b end
    if op == ">" then return a > b end
    if op == "<" then return a < b end
    if op == "==" then return a == b end
    return false
end

local function professionOf(player)
    local text = ""
    pcall(function()
        local p = player:getDescriptor():getCharacterProfession()
        text = tostring(p and (p.getName and p:getName() or p) or "")
    end)
    if text == "" then
        pcall(function() text = tostring(player:getDescriptor():getProfession() or "") end)
    end
    return string.lower(text)
end

local function hasTrait(player, name)
    local yes = false
    pcall(function()
        if CharacterTrait and CharacterTrait[string.upper(name)] then
            yes = player:hasTrait(CharacterTrait[string.upper(name)]) == true
        end
    end)
    if not yes then pcall(function() yes = player:HasTrait(name) == true end) end
    return yes
end

local function perkLevel(player, perkName)
    local level = 0
    pcall(function() level = player:getPerkLevel(Perks.FromString(perkName)) end)
    return tonumber(level) or 0
end
E.perkLevel = perkLevel

function E.check(cond, ctx)
    if cond == nil then return true end
    if type(cond) ~= "table" then return cond == true end
    local op = cond[1]
    local ps = DDS.State.player(ctx.username)
    local s = saga()
    if op == "all" then
        for i = 2, #cond do if not E.check(cond[i], ctx) then return false end end
        return true
    elseif op == "any" then
        for i = 2, #cond do if E.check(cond[i], ctx) then return true end end
        return false
    elseif op == "not" then
        return not E.check(cond[2], ctx)
    elseif op == "standing" then
        return compare(DDS.Factions.get(ps, DDS.Factions.resolve(cond[2])), cond[3], cond[4])
    elseif op == "power" then
        return compare(DDS.Factions.power(cond[2]), cond[3], cond[4])
    elseif op == "flag" then
        local v = s and s.flags[cond[2]]
        if cond[3] == nil then return v ~= nil and v ~= false end
        return v == cond[3]
    elseif op == "noflag" then
        return not (s and s.flags[cond[2]])
    elseif op == "pflag" then
        local v = ps.flags[cond[2]]
        if cond[3] == nil then return v ~= nil and v ~= false end
        return v == cond[3]
    elseif op == "var" then
        local q = ctx.quest
        return q ~= nil and q.vars ~= nil and q.vars[cond[2]] == cond[3]
    elseif op == "twist" then
        return s ~= nil and s.twists ~= nil and s.twists[cond[2]] ~= nil
    elseif op == "revealed" then
        return s ~= nil and s.twists ~= nil and s.twists[cond[2]] ~= nil and s.twists[cond[2]].revealed == true
    elseif op == "cast" then
        local c = s and s.cast and s.cast[cond[2]]
        return c ~= nil and c[cond[3]] == cond[4]
    elseif op == "has" then
        return ctx.player ~= nil and DDS.Items.count(ctx.player, cond[2]) >= (cond[3] or 1)
    elseif op == "profession" then
        if ctx.player == nil then return false end
        local prof = professionOf(ctx.player)
        for _, want in ipairs(cond[2] or {}) do
            if string.find(prof, want, 1, true) then return true end
        end
        return false
    elseif op == "trait" then
        return ctx.player ~= nil and hasTrait(ctx.player, cond[2])
    elseif op == "perk" then
        return ctx.player ~= nil and perkLevel(ctx.player, cond[2]) >= (cond[3] or 1)
    elseif op == "act" then
        return s ~= nil and compare(s.act, cond[2], cond[3])
    elseif op == "buddy" then
        local b = DDS.Buddies and DDS.Buddies.active(ctx.username) or nil
        if cond[2] == nil then return b ~= nil end
        return b ~= nil and (b.id == cond[2] or b.archetype == cond[2])
    elseif op == "chance" then
        return ZombRandFloat(0, 1) < (cond[2] or 0.5)
    end
    return true
end

---------------------------------------------------------------------------
-- Skill checks: shown to the player as "[Persuade 62%]".
---------------------------------------------------------------------------

E.checkKinds = {
    persuade = { label = "Persuade", professions = { "priest", "teacher", "nurse", "doctor", "salesman", "secretary" },
        traits = { "Brave", "Lucky" }, against = { "Cowardly" } },
    intimidate = { label = "Intimidate", professions = { "police", "veteran", "securityguard", "construction", "lumberjack" },
        traits = { "Brave", "Strong", "Athletic" }, against = { "Weak", "Cowardly" } },
    lie = { label = "Lie", professions = { "burglar", "salesman", "unemployed" },
        traits = { "Lucky", "Inconspicuous" }, against = { "Unlucky" } },
    medic = { label = "Medicine", professions = { "doctor", "nurse" }, perk = "Doctor" },
    mechanic = { label = "Mechanics", professions = { "mechanic", "engineer", "electrician" }, perk = "Mechanics" },
    soldier = { label = "Military", professions = { "veteran", "police", "fireofficer", "securityguard" },
        traits = { "Brave", "Desensitized" } },
    stealth = { label = "Stealth", perk = "Sneak", professions = { "burglar" } },
}

function E.checkChance(check, ctx)
    local kind = E.checkKinds[check.kind] or { label = check.kind }
    local p = check.base or 0.45
    if check.role then
        local ps = DDS.State.player(ctx.username)
        p = p + DDS.Factions.get(ps, DDS.Factions.resolve(check.role)) / 250
    end
    if ctx.player then
        local prof = professionOf(ctx.player)
        for _, want in ipairs(kind.professions or {}) do
            if string.find(prof, want, 1, true) then p = p + 0.25; break end
        end
        for _, t in ipairs(kind.traits or {}) do if hasTrait(ctx.player, t) then p = p + 0.1 end end
        for _, t in ipairs(kind.against or {}) do if hasTrait(ctx.player, t) then p = p - 0.15 end end
        if kind.perk then p = p + perkLevel(ctx.player, kind.perk) * 0.05 end
    end
    local buddy = DDS.Buddies and DDS.Buddies.active(ctx.username) or nil
    if buddy and buddy.skills and buddy.skills[check.kind] then p = p + 0.1 end
    return DDS.clamp(p, 0.05, 0.95), kind.label or check.kind
end

---------------------------------------------------------------------------
-- Effects
---------------------------------------------------------------------------

function E.vars(ctx)
    local vars = {}
    local s = saga()
    if s then
        for k, v in pairs(s.cast or {}) do vars[k] = v end
        for role, r in pairs(s.roles or {}) do vars[role] = r end
        vars.saga = { title = s.title, act = s.act, settlement = s.settlement, stronghold = s.stronghold, town = s.town,
            operation = s.operation }
        for k, v in pairs(s.vars or {}) do vars[k] = v end
        if DDS.Kit and DDS.Kit.leaderKey then vars.leader = s.cast[DDS.Kit.leaderKey()] end
        local side = s.choices and s.choices.side
        if side == "warlord" then vars.enemy = s.roles.military; vars.boss = s.cast.officer
        else vars.enemy = s.roles.antagonist; vars.boss = s.cast.warlord end
    end
    if ctx.quest and ctx.quest.vars then
        for k, v in pairs(ctx.quest.vars) do vars[k] = v end
    end
    if ctx.player then
        local full = DDS.displayName(ctx.player)
        local first = string.match(full, "^(%S+)") or full
        vars.me = { name = full, first = first }
    end
    local buddy = DDS.Buddies and DDS.Buddies.active(ctx.username) or nil
    if buddy then vars.buddy = buddy end
    for k, v in pairs(ctx.extra or {}) do vars[k] = v end
    return vars
end

function E.render(text, ctx)
    return DDS.Text.render(text, E.vars(ctx), ctx.rng)
end

function E.run(effects, ctx)
    local result = {}
    if type(effects) ~= "table" then return result end
    local ps = DDS.State.player(ctx.username)
    local s = saga()
    for _, raw in ipairs(effects) do
        -- Faction/role arguments may be templates like "{enemyF.id}".
        local fx = raw
        if type(raw[2]) == "string" and string.find(raw[2], "{", 1, true)
                and (raw[1] == "standing" or raw[1] == "ambush" or raw[1] == "power") then
            fx = DDS.copy(raw)
            fx[2] = E.render(raw[2], ctx)
        end
        local op = fx[1]
        local ok, err = pcall(function()
            if op == "standing" then
                -- On a shared mission the world judges the whole faction.
                local party = ctx.quest and ctx.quest.party
                if party and DDS.Party then
                    for _, name in ipairs(DDS.Party.members(party)) do
                        DDS.Factions.change(name, fx[2], fx[3], fx[4] or ctx.quest.title)
                    end
                else
                    DDS.Factions.change(ctx.username, fx[2], fx[3], fx[4] or (ctx.quest and ctx.quest.title))
                end
            elseif op == "standingAll" then
                -- Everyone online who is present feels it (world-level choices).
                for _, p in ipairs(DDS.onlinePlayers()) do DDS.Factions.change(DDS.username(p), fx[2], fx[3], "world") end
            elseif op == "power" then
                DDS.Factions.shiftPower(fx[2], fx[3], fx[4])
            elseif op == "flag" then
                local value = fx[3]
                if type(value) == "string" and string.find(value, "{", 1, true) then value = E.render(value, ctx) end
                if s then s.flags[fx[2]] = value == nil and true or value end
            elseif op == "pflag" then
                ps.flags[fx[2]] = fx[3] == nil and true or fx[3]
            elseif op == "var" then
                if ctx.quest then ctx.quest.vars[fx[2]] = fx[3] end
            elseif op == "cast" then
                if s and s.cast[fx[2]] then s.cast[fx[2]][fx[3]] = fx[4] end
            elseif op == "trust" then
                if s and s.cast[fx[2]] then s.cast[fx[2]].trust = DDS.clamp((s.cast[fx[2]].trust or 50) + fx[3], 0, 100) end
            elseif op == "meet" then
                ps.met[fx[2]] = true
            elseif op == "chronicle" then
                DDS.State.chronicle(E.render(fx[2], ctx), fx[3] or "story")
            elseif op == "toast" then
                DDS.Server.notify(ctx.username, E.render(fx[2], ctx), fx[3] or "info")
            elseif op == "reward" then
                if ctx.player then
                    local rng = DDS.State.rng(DDS.nowMs())
                    local bloc = fx[3] and (DDS.ALife.factionInfo(DDS.Factions.resolve(fx[3])) or {}).bloc or nil
                    local reward = DDS.Items.rollReward(rng, fx[2] or "small", bloc)
                    DDS.Items.grant(ctx.player, reward)
                    DDS.Server.notify(ctx.username, "Received: " .. table.concat(DDS.Items.describe(reward), ", "), "good")
                end
            elseif op == "give" then
                if ctx.player then DDS.Items.give(ctx.player, fx[2], fx[3] or 1, fx[4] and E.render(fx[4], ctx) or nil) end
            elseif op == "take" then
                if ctx.player then DDS.Items.take(ctx.player, fx[2], fx[3] or 1) end
            elseif op == "xp" then
                if ctx.player then DDS.Items.xp(ctx.player, fx[2], fx[3] or 50) end
            elseif op == "branch" then
                result.branch = fx[2]
            elseif op == "complete" then
                result.complete = true
            elseif op == "fail" then
                result.fail = fx[2] or "failed"
            elseif op == "accept" then
                result.accept = true
            elseif op == "decline" then
                result.decline = true
            elseif op == "startQuest" then
                DDS.Quests.offerTemplate(ctx.username, fx[2], fx[3], fx[4] == "auto")
            elseif op == "schedule" then
                local data = DDS.copy(fx[4] or {})
                data.username = data.username or ctx.username
                DDS.State.schedule(fx[2], fx[3], data)
            elseif op == "call" then
                -- {"call", treeId, from, questId|nil, delayHours|nil}
                DDS.Dialogue.queueCall(ctx.username, fx[2], fx[3] and E.render(fx[3], ctx) or nil,
                    fx[4] or (ctx.quest and ctx.quest.id), nil, fx[5])
            elseif op == "reveal" then
                DDS.Saga.reveal(fx[2], ctx)
            elseif op == "choose" then
                if s then
                    s.choices = s.choices or {}
                    s.choices[fx[2]] = fx[3]
                    s.flags["choice_" .. fx[2]] = fx[3]
                end
                ps.stats.choices = (ps.stats.choices or 0) + 1
            elseif op == "advance" then
                DDS.Saga.advance(ctx)
            elseif op == "ambush" then
                DDS.Quests.ambush(ctx.username, fx[2] or "antagonist", fx[3] or 3)
            elseif op == "loyalty" then
                if DDS.Buddies then DDS.Buddies.loyalty(ctx.username, fx[2], fx[3], fx[4]) end
            elseif op == "recruit" then
                if DDS.Buddies then DDS.Buddies.recruit(ctx.username, fx[2], ctx) end
            elseif op == "buddyFate" then
                if DDS.Buddies then DDS.Buddies.setFate(ctx.username, fx[2], fx[3], ctx) end
            elseif op == "killNpc" or op == "releaseNpc" then
                -- Act on the story NPCs standing in the current step.
                local q = ctx.quest
                local step = q and q.steps[q.current]
                for _, obj in ipairs(step and step.objectives or {}) do
                    if obj.uid and (fx[2] == nil or obj.name == fx[2] or obj.role == fx[2]) then
                        if op == "killNpc" then
                            local shell = DDS.ALife.shell(obj.uid)
                            pcall(function() shell:Kill(ctx.player) end)
                        else
                            DDS.ALife.say(obj.uid, E.render(fx[3] or "...", ctx), 20)
                            local w = DDS.State.world()
                            w.cleanup = w.cleanup or {}
                            w.cleanup[#w.cleanup + 1] = { uid = obj.uid, sinceHours = DDS.nowHours() - 23.9 }
                        end
                    end
                end
            elseif op == "tension" then
                ps.tension = DDS.clamp((ps.tension or 0) + fx[2], 0, 100)
            end
        end)
        if not ok then DDS.log("effect " .. tostring(op) .. " failed: " .. tostring(err)) end
    end
    if ctx.username then DDS.Server.markDirty(ctx.username) end
    return result
end

return E
