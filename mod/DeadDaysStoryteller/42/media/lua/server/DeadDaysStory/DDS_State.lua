-- Persistent story state. Everything the story knows lives in one global
-- ModData table, mirrored to a backup file on save so a lost ModData blob
-- does not erase a season of story.

require "DeadDaysStory/DDS_Core"

DDS.State = DDS.State or {}
local State = DDS.State

State.KEY = "DeadDaysStory.v1"
State.SCHEMA = 1
State.root = nil

local function fresh()
    return {
        schema = State.SCHEMA,
        seed = DDS.freshSeed(),
        nextId = 1,
        saga = nil,
        sagaHistory = {},
        players = {},
        events = {},
        chronicle = {},
        flags = {},
        createdHours = DDS.nowHours(),
    }
end

---------------------------------------------------------------------------
-- Serializer for the backup file (a strict subset of Lua table syntax).
---------------------------------------------------------------------------

local function encode(value, out, depth)
    local kind = type(value)
    if kind == "table" then
        if depth > 40 then out[#out + 1] = "nil"; return end
        out[#out + 1] = "{"
        for k, v in pairs(value) do
            local vk = type(v)
            if vk == "table" or vk == "string" or vk == "number" or vk == "boolean" then
                out[#out + 1] = "["
                encode(k, out, depth + 1)
                out[#out + 1] = "]="
                encode(v, out, depth + 1)
                out[#out + 1] = ","
            end
        end
        out[#out + 1] = "}"
    elseif kind == "string" then
        out[#out + 1] = '"' .. string.gsub(value, '[%c"\\]', function(c)
            return string.format("\\%03d", string.byte(c))
        end) .. '"'
    elseif kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            out[#out + 1] = "0"
        elseif value == math.floor(value) then
            out[#out + 1] = string.format("%d", value)
        else
            out[#out + 1] = string.format("%.6f", value)
        end
    elseif kind == "boolean" then
        out[#out + 1] = value and "true" or "false"
    else
        out[#out + 1] = "nil"
    end
end

function State.serialize(value)
    local out = {}
    encode(value, out, 0)
    return table.concat(out)
end

function State.deserialize(text)
    local pos = 1
    local len = string.len(text)
    local function skip()
        while pos <= len do
            local c = string.sub(text, pos, pos)
            if c == " " or c == "\n" or c == "\r" or c == "\t" then pos = pos + 1 else break end
        end
    end
    local parseValue
    local function parseString()
        pos = pos + 1
        local parts = {}
        while pos <= len do
            local c = string.sub(text, pos, pos)
            if c == '"' then pos = pos + 1; return table.concat(parts) end
            if c == "\\" then
                local code = tonumber(string.sub(text, pos + 1, pos + 3))
                parts[#parts + 1] = string.char(code or 63)
                pos = pos + 4
            else
                parts[#parts + 1] = c
                pos = pos + 1
            end
        end
        error("unterminated string")
    end
    parseValue = function()
        skip()
        local c = string.sub(text, pos, pos)
        if c == "{" then
            pos = pos + 1
            local result = {}
            while true do
                skip()
                local d = string.sub(text, pos, pos)
                if d == "}" then pos = pos + 1; return result end
                if d ~= "[" then error("expected [ at " .. pos) end
                pos = pos + 1
                local key = parseValue()
                skip()
                if string.sub(text, pos, pos + 1) ~= "]=" then error("expected ]= at " .. pos) end
                pos = pos + 2
                local v = parseValue()
                if key ~= nil then result[key] = v end
                skip()
                if string.sub(text, pos, pos) == "," then pos = pos + 1 end
            end
        elseif c == '"' then
            return parseString()
        elseif string.sub(text, pos, pos + 3) == "true" then
            pos = pos + 4; return true
        elseif string.sub(text, pos, pos + 4) == "false" then
            pos = pos + 5; return false
        elseif string.sub(text, pos, pos + 2) == "nil" then
            pos = pos + 3; return nil
        else
            local s, e = string.find(text, "^-?[%d%.]+", pos)
            if not s then error("bad token at " .. pos) end
            pos = e + 1
            return tonumber(string.sub(text, s, e))
        end
    end
    return parseValue()
end

function State.backupPath()
    local world = "world"
    pcall(function() world = getWorld():getWorld() end)
    world = string.gsub(tostring(world), "[^%w_%-]", "_")
    return "DeadDaysStory_" .. world .. ".txt"
end

function State.writeBackup()
    if State.root == nil then return false end
    local ok, err = pcall(function()
        local writer = getFileWriter(State.backupPath(), true, false)
        writer:write(State.serialize(State.root))
        writer:close()
    end)
    if not ok then DDS.log("backup write failed: " .. tostring(err)) end
    return ok
end

function State.readBackup()
    local data
    local ok, err = pcall(function()
        local reader = getFileReader(State.backupPath(), false)
        if reader == nil then return end
        local lines = {}
        while true do
            local line = reader:readLine()
            if line == nil then break end
            lines[#lines + 1] = line
        end
        reader:close()
        if #lines > 0 then data = State.deserialize(table.concat(lines, "\n")) end
    end)
    if not ok then DDS.log("backup read failed: " .. tostring(err)) end
    return type(data) == "table" and data or nil
end

---------------------------------------------------------------------------
-- Access
---------------------------------------------------------------------------

function State.load()
    local store = ModData.getOrCreate(State.KEY)
    if store.schema == nil then
        local restored = State.readBackup()
        local source = restored or fresh()
        for k, v in pairs(source) do store[k] = v end
        if restored then
            DDS.log("story state was empty; restored from " .. State.backupPath())
        else
            DDS.log("new story state created (seed " .. tostring(store.seed) .. ")")
        end
    end
    store.players = store.players or {}
    store.events = store.events or {}
    store.chronicle = store.chronicle or {}
    store.sagaHistory = store.sagaHistory or {}
    store.flags = store.flags or {}
    State.root = store
    return store
end

function State.world()
    if State.root == nil then State.load() end
    return State.root
end

function State.newId(prefix)
    local w = State.world()
    w.nextId = (w.nextId or 1) + 1
    return tostring(prefix or "q") .. tostring(w.nextId)
end

function State.player(username)
    if username == nil then return nil end
    local w = State.world()
    local ps = w.players[username]
    if ps == nil then
        ps = {
            username = username,
            createdHours = DDS.nowHours(),
            standing = {},
            quests = {},
            order = {},
            history = {},
            done = {},
            daily = { day = 0, ids = {} },
            streak = 0,
            tension = 10,
            lastLeadHours = -100,
            lastIncidentHours = -100,
            met = {},
            flags = {},
            calls = {},
            seen = {},
            stats = { completed = 0, failed = 0, kills = 0, choices = 0 },
        }
        w.players[username] = ps
    end
    ps.calls = ps.calls or {}
    ps.seen = ps.seen or {}
    return ps
end

function State.playerFor(player)
    return State.player(DDS.username(player))
end

function State.rng(salt)
    local w = State.world()
    w.rngCounter = (w.rngCounter or 0) + 1
    return DDS.rng((w.seed or 1) + w.rngCounter * 7919 + (tonumber(salt) or 0))
end

---------------------------------------------------------------------------
-- Chronicle: the world's shared memory, shown to players in the journal.
---------------------------------------------------------------------------

function State.chronicle(text, kind, extra)
    local w = State.world()
    local entry = { day = DDS.day(), hours = DDS.nowHours(), text = text, kind = kind or "event" }
    if type(extra) == "table" then for k, v in pairs(extra) do entry[k] = v end end
    DDS.push(w.chronicle, entry, 120)
    return entry
end

---------------------------------------------------------------------------
-- Scheduled events (consequences that land later).
---------------------------------------------------------------------------

function State.schedule(delayHours, kind, data)
    local w = State.world()
    local event = { atHours = DDS.nowHours() + (tonumber(delayHours) or 1), kind = kind, data = data or {} }
    DDS.push(w.events, event, 200)
    return event
end

function State.dueEvents()
    local w = State.world()
    local now = DDS.nowHours()
    local due, keep = {}, {}
    for _, event in ipairs(w.events) do
        if (event.atHours or 0) <= now then due[#due + 1] = event else keep[#keep + 1] = event end
    end
    w.events = keep
    return due
end

return State
