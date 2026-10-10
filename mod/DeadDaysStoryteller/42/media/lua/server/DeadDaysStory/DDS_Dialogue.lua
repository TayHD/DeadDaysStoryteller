-- Dialogue engine. Trees are static content (registered by templates); a
-- session holds where a player is in a tree. The server renders each node
-- (text resolved, choices filtered, skill-check odds computed) and the client
-- only ever sees the current node.
--
-- Tree format:
--   tree = { start = "a", nodes = {
--     a = { speaker = "{contact.name}", radio = true, text = "...",
--           effects = {...},                       -- run when the node is shown
--           choices = {
--             { text = "...", cond = {...}, effects = {...}, next = "b", tags = {"mercy"} },
--             { text = "...", check = { kind = "persuade", base = 0.5, role = "community" },
--               pass = "c", fail = "d", passEffects = {...}, failEffects = {...} },
--           },
--           next = "b",                            -- no choices: Continue
--           ["end"] = true },                      -- closes the conversation
--   } }

require "DeadDaysStory/DDS_Core"
require "DeadDaysStory/DDS_State"
require "DeadDaysStory/DDS_Effects"

DDS.Dialogue = DDS.Dialogue or { trees = {}, sessions = {} }
local D = DDS.Dialogue

function D.register(id, tree) D.trees[id] = tree end

function D.tree(id)
    local tree = D.trees[id]
    if tree then return tree end
    -- "template:key" looks inside a quest template's dialogue table.
    local templateId, key = string.match(tostring(id), "^([^:]+):(.+)$")
    if templateId and DDS.Quests and DDS.Quests.templates[templateId] then
        local t = DDS.Quests.templates[templateId]
        return t.dialogues and t.dialogues[key] or nil
    end
    return nil
end

local function ctxFor(username, session)
    local quest = session.questId and DDS.Quests.get(username, session.questId) or nil
    return {
        username = username,
        player = DDS.playerByName(username),
        quest = quest,
        rng = DDS.rng((session.seed or 1) + (session.steps or 0)),
        extra = session.vars,
    }
end

---------------------------------------------------------------------------
-- Voice lines. A node with `role` is spoken by that character. Its text may be
-- a list of alternatives, and `byArch` may hold per-archetype versions. Every
-- combination of (line, alternative, archetype, voice gender, kid's gender)
-- has a stable id; the pre-generated voice pack is keyed by these ids.
-- Spoken text may only use the kid's pronouns ({lost.he} etc.) and {lost.kin};
-- anything else that changes per world (names, places) can't be pre-recorded.
---------------------------------------------------------------------------

-- Characters that aren't part of the saga cast. `var` = take gender from a
-- quest variable (a generated person); `g` = fixed voice gender.
D.voiceRoles = {
    command = { g = "m" }, soldier = { g = "m" }, tollman = { g = "m" }, broker = { g = "m" },
    spokesman = { g = "m" }, private = { g = "m" }, builder = { g = "f" }, quartermaster = { g = "m" },
    victim = { var = "victim" }, asker = { var = "asker" }, receiver = { var = "receiver" }, seeker = { var = "seeker" },
    repA = { var = "repA" }, repB = { var = "repB" }, voice = { var = "voice" }, survivor = { g = "f" },
    sib = { g = "m" }, cred = { var = "cred" }, fam = { g = "f" }, surv = { g = "f" }, pal = { buddy = true },
    -- Cast members who are always the same gender (only one voice needed).
    lieutenant = { g = "m" },
}

-- Audio tags ([sighs], [whispers], [nervous]...) direct the voice model. They
-- stay in the exported script and are removed from on-screen subtitles.
function D.stripTags(text)
    if type(text) ~= "string" then return text end
    local out = string.gsub(text, "%[[%a][%a%s%-']*%]%s*", "")
    out = string.gsub(out, "^%s+", "")
    return out
end

-- Delivery for lines that don't carry a hand-written tag.
D.archDelivery = {
    scared = "[nervous]", burnedout = "[tired]", burnout = "[exhausted]", quiet = "[quietly]",
    angry = "[frustrated]", caretaker = "[warmly]", follower = "[nervous]",
}

function D.withDelivery(text, arch)
    if type(text) ~= "string" or string.find(text, "^%s*%[") then return text end
    local tag = arch and D.archDelivery[arch]
    if tag then return tag .. " " .. text end
    return text
end

function D.hash(s)
    local h = 5381
    for i = 1, string.len(s) do
        h = (h * 33 + string.byte(s, i)) % 4294967296
    end
    return string.format("%.0f", h)
end

-- Which raw text a node uses for a speaker with archetype `arch`.
function D.rawText(node, arch)
    if node.byArch and arch and node.byArch[arch] then return node.byArch[arch], arch end
    return node.text, nil
end

local function genderOf(role, ctx, s)
    if s and s.cast and s.cast[role] then return s.cast[role].female and "f" or "m" end
    local def = D.voiceRoles[role]
    if def == nil then return "m" end
    if def.g then return def.g end
    if def.buddy then
        local b = DDS.Buddies and DDS.Buddies.active(ctx.username)
        return b and b.female and "f" or "m"
    end
    local p = ctx.quest and ctx.quest.vars and ctx.quest.vars[def.var]
    if p == nil and ctx.extra then p = ctx.extra[def.var] end
    return (type(p) == "table" and p.female) and "f" or "m"
end

function D.voiceKey(treeId, nodeId, alt, arch, g, lg)
    return table.concat({ treeId, nodeId, tostring(alt), arch or "-", g, lg or "-" }, "|")
end

local function chooseAlt(raw, session, nodeId)
    if type(raw) ~= "table" then return raw, 1 end
    local seed = tonumber(D.hash((session.id or "") .. nodeId)) or 1
    local k = (seed % #raw) + 1
    return raw[k], k
end

-- "leader" = whoever speaks for the settlement right now.
function D.resolveRole(role)
    if role == "leader" then return (DDS.Kit and DDS.Kit.leaderKey()) or "contact" end
    return role
end

local function renderNode(username, session)
    local tree = D.tree(session.treeId)
    local node = tree and tree.nodes[session.nodeId] or nil
    if node == nil then return nil end
    local ctx = ctxFor(username, session)
    local s = DDS.State.world().saga
    local role = D.resolveRole(node.role)
    local arch
    if role and s and s.cast and s.cast[role] then arch = s.cast[role].arch end
    local raw = D.rawText(node, arch)
    local text, alt = chooseAlt(raw or "", session, session.nodeId)
    local voice
    if role then
        local lg = (type(text) == "string" and string.find(text, "{lost.", 1, true)) and (s and s.cast.lost.female and "f" or "m") or nil
        voice = D.hash(D.voiceKey(session.treeId, session.nodeId, alt, arch, genderOf(role, ctx, s), lg))
    end
    local view = {
        sessionId = session.id,
        speaker = DDS.Effects.render(node.speaker or "", ctx),
        title = DDS.Effects.render(node.title or tree.title or "", ctx),
        text = D.stripTags(DDS.Effects.render(text or "", ctx)),
        radio = node.radio == true or tree.radio == true,
        mood = node.mood,
        voice = voice,
        choices = {},
    }
    session.visible = {}
    for index, choice in ipairs(node.choices or {}) do
        if DDS.Effects.check(choice.cond, ctx) then
            local label = DDS.Effects.render(choice.text, ctx)
            local odds
            if choice.check then
                local p, name = DDS.Effects.checkChance(choice.check, ctx)
                odds = math.floor(p * 100 + 0.5)
                label = "[" .. name .. " " .. odds .. "%] " .. label
            end
            local tag
            if choice.tags and #choice.tags > 0 then tag = choice.tags[1] end
            view.choices[#view.choices + 1] = { index = index, text = label, tag = tag, odds = odds }
            session.visible[#session.visible + 1] = index
        end
    end
    if #view.choices == 0 then
        view.choices[1] = { index = 0, text = node["end"] and "[End]" or "[Continue]" }
    end
    return view
end

local function finish(username, session, outcome)
    D.sessions[username] = nil
    local player = DDS.playerByName(username)
    if player then DDS.Net.toPlayer(player, "dialogueClose", { sessionId = session.id }) end
    if session.onEnd and DDS.Quests then
        DDS.Quests.onDialogueEnd(username, session, outcome or {})
    end
    DDS.Server.markDirty(username)
end

local function enter(username, session, nodeId)
    local tree = D.tree(session.treeId)
    local node = tree and tree.nodes[nodeId] or nil
    if node == nil then return finish(username, session, session.outcome) end
    session.nodeId = nodeId
    session.steps = (session.steps or 0) + 1
    if session.steps > 80 then return finish(username, session, session.outcome) end
    local ctx = ctxFor(username, session)
    -- Router node: jump to the first branch whose condition holds.
    if node.route then
        for _, r in ipairs(node.route) do
            if DDS.Effects.check(r.cond, ctx) then return enter(username, session, r.next) end
        end
    end
    if node.effects then
        local r = DDS.Effects.run(node.effects, ctx)
        for k, v in pairs(r) do session.outcome[k] = v end
    end
    if node.meet then DDS.State.player(username).met[node.meet] = true end
    local view = renderNode(username, session)
    if view == nil then return finish(username, session, session.outcome) end
    local player = DDS.playerByName(username)
    if player then DDS.Net.toPlayer(player, "dialogue", view) end
end

-- Begin a conversation now. opts: questId, vars, onEnd (bool), nodeId
function D.start(username, treeId, opts)
    opts = opts or {}
    local tree = D.tree(treeId)
    if tree == nil then
        DDS.log("missing dialogue tree " .. tostring(treeId))
        return false
    end
    local session = {
        id = DDS.State.newId("d"),
        treeId = treeId,
        questId = opts.questId,
        vars = opts.vars,
        onEnd = opts.onEnd ~= false,
        seed = opts.seed or DDS.freshSeed(),
        outcome = {},
        tag = opts.tag,
    }
    D.sessions[username] = session
    enter(username, session, opts.nodeId or tree.start or "start")
    return true
end

function D.choose(username, sessionId, index)
    local session = D.sessions[username]
    if session == nil or session.id ~= sessionId then return end
    local tree = D.tree(session.treeId)
    local node = tree and tree.nodes[session.nodeId] or nil
    if node == nil then return finish(username, session, session.outcome) end
    index = tonumber(index) or 0
    if index == 0 or node.choices == nil or #node.choices == 0 then
        if node["end"] or node.next == nil then return finish(username, session, session.outcome) end
        return enter(username, session, node.next)
    end
    if not DDS.contains(session.visible or {}, index) then return end
    local choice = node.choices[index]
    local ctx = ctxFor(username, session)
    local nextNode = choice.next
    local function apply(effects)
        if effects then
            local r = DDS.Effects.run(effects, ctx)
            for k, v in pairs(r) do session.outcome[k] = v end
        end
    end
    apply(choice.effects)
    if choice.tags and DDS.Buddies then DDS.Buddies.react(username, choice.tags, ctx) end
    if choice.check then
        local p = DDS.Effects.checkChance(choice.check, ctx)
        local passed = ZombRandFloat(0, 1) < p
        session.lastCheck = passed
        if passed then apply(choice.passEffects); nextNode = choice.pass or nextNode
        else apply(choice.failEffects); nextNode = choice.fail or nextNode end
        DDS.Server.notify(username, passed and "Check passed" or "Check failed", passed and "good" or "bad")
    end
    if choice["end"] or nextNode == nil then return finish(username, session, session.outcome) end
    enter(username, session, nextNode)
end

function D.cancel(username)
    local session = D.sessions[username]
    if session then
        -- Walking away is a choice too: no effects, quest decides what it means.
        session.outcome.walkedAway = true
        finish(username, session, session.outcome)
    end
end

function D.resend(username)
    local session = D.sessions[username]
    if session == nil then return end
    local view = renderNode(username, session)
    local player = DDS.playerByName(username)
    if view and player then DDS.Net.toPlayer(player, "dialogue", view) end
end

---------------------------------------------------------------------------
-- Voice export: every recordable line, for tools/Generate-Voices.ps1.
-- Writes Zomboid/Lua/DeadDaysStory_voicelines.txt and a report of spoken
-- lines that can't be pre-recorded (they still contain names or places).
---------------------------------------------------------------------------

local lostForms = {
    m = { he = "he", him = "him", his = "his", He = "He", His = "His", kin = "son", first = "{lost.first}" },
    f = { he = "she", him = "her", his = "her", He = "She", His = "Her", kin = "daughter", first = "{lost.first}" },
}

local function allTrees()
    local list = {}
    for id, tree in pairs(D.trees) do list[#list + 1] = { id = id, tree = tree } end
    if DDS.Quests then
        for tid, t in pairs(DDS.Quests.templates) do
            for key, tree in pairs(t.dialogues or {}) do list[#list + 1] = { id = tid .. ":" .. key, tree = tree } end
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local function clean(text)
    return (string.gsub(tostring(text or ""), "[\t\r\n]", " "))
end

function D.exportVoiceLines()
    local rows, bad, seen = {}, {}, {}
    local function add(id, role, arch, g, radio, text, origin)
        if seen[id] then return end
        seen[id] = true
        rows[#rows + 1] = table.concat({ id, role, arch or "-", g, radio and "1" or "0", clean(text), origin }, "\t")
    end
    for _, entry in ipairs(allTrees()) do
        for nodeId, node in pairs(entry.tree.nodes or {}) do
            if node.role then
                local radio = node.radio == true or entry.tree.radio == true
                local A = DDS.Saga and DDS.Saga.archetypes or {}
                local archs = A[node.role]
                if node.role == "leader" then
                    archs = {}
                    for _, a in ipairs(A.contact or {}) do archs[#archs + 1] = a end
                    for _, a in ipairs(A.doctor or {}) do archs[#archs + 1] = a end
                end
                if archs == nil then archs = { false } end
                local def = D.voiceRoles[node.role]
                local genders = (def and def.g) and { def.g } or { "m", "f" }
                for _, a in ipairs(archs) do
                    local arch = a or nil
                    local raw = D.rawText(node, arch)
                    local alts = type(raw) == "table" and raw or { raw }
                    for k, text in ipairs(alts) do
                        local lgs = (type(text) == "string" and string.find(text, "{lost.", 1, true)) and { "m", "f" } or { false }
                        for _, g in ipairs(genders) do
                            for _, lg in ipairs(lgs) do
                                local rendered = D.withDelivery(DDS.Text.render(text, { lost = lostForms[lg or "m"] }), arch)
                                local origin = entry.id .. "/" .. nodeId
                                if string.find(rendered, "{", 1, true) or string.find(rendered, "[[", 1, true) then
                                    bad[origin] = rendered
                                else
                                    local key = D.voiceKey(entry.id, nodeId, k, arch, g, lg or nil)
                                    add(D.hash(key), node.role, arch, g, radio, rendered, origin)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    -- Buddy banter.
    if DDS.Buddies then
        for pers, pools in pairs(DDS.Buddies.personalities) do
            for _, pool in ipairs({ "idle", "night", "rain", "kill", "hurt" }) do
                for i, line in ipairs(pools[pool] or {}) do
                    for _, g in ipairs({ "m", "f" }) do
                        local key = table.concat({ "buddy", pers, pool, tostring(i), g }, "|")
                        if string.find(line, "{", 1, true) then bad["buddy/" .. pers .. "/" .. pool .. "/" .. i] = line
                        else add(D.hash(key), "buddy_" .. pers, "-", g, false, line, "buddy/" .. pers .. "/" .. pool) end
                    end
                end
            end
        end
    end
    local ok, err = pcall(function()
        local w = getFileWriter("DeadDaysStory_voicelines.txt", true, false)
        w:write("id\trole\tarch\tgender\tradio\ttext\torigin\n")
        for _, r in ipairs(rows) do w:write(r .. "\n") end
        w:close()
        local rep = getFileWriter("DeadDaysStory_voice_report.txt", true, false)
        local n = 0
        for origin, text in pairs(bad) do rep:write(origin .. "\t" .. clean(text) .. "\n"); n = n + 1 end
        rep:close()
        DDS.log("voice export: " .. #rows .. " recordable lines, " .. n .. " spoken lines need rewording")
    end)
    if not ok then DDS.log("voice export write failed: " .. tostring(err)) end
    return ok, #rows
end

---------------------------------------------------------------------------
-- Radio calls: conversations waiting for the player to answer. They queue
-- instead of popping up mid-fight.
---------------------------------------------------------------------------

function D.queueCall(username, treeId, from, questId, vars, delayHours)
    local ps = DDS.State.player(username)
    local call = {
        id = DDS.State.newId("c"),
        treeId = treeId,
        from = from or "Unknown frequency",
        questId = questId,
        vars = vars,
        atHours = DDS.nowHours() + (delayHours or 0),
        expiresHours = DDS.nowHours() + 48,
    }
    DDS.push(ps.calls, call, 12)
    if (delayHours or 0) <= 0 then
        DDS.Server.notify(username, "Incoming radio: " .. tostring(call.from) .. " (answer it from the Journal)", "radio")
    end
    DDS.Server.markDirty(username)
    return call
end

function D.answer(username, callId)
    local ps = DDS.State.player(username)
    for i, call in ipairs(ps.calls) do
        if call.id == callId and (call.atHours or 0) <= DDS.nowHours() then
            table.remove(ps.calls, i)
            D.start(username, call.treeId, { questId = call.questId, vars = call.vars })
            DDS.Server.markDirty(username)
            return true
        end
    end
    return false
end

function D.pendingCalls(username)
    local ps = DDS.State.player(username)
    local now = DDS.nowHours()
    local list, keep = {}, {}
    for _, call in ipairs(ps.calls) do
        if (call.expiresHours or now + 1) > now then
            keep[#keep + 1] = call
            if (call.atHours or 0) <= now then list[#list + 1] = { id = call.id, from = call.from } end
        end
    end
    ps.calls = keep
    return list
end

return D
