-- Dead Days: Storyteller - shared core.
-- Namespace, seeded randomness, small table helpers, text templating and the
-- network bridge. Everything else in the mod is built on these.

DDS = DDS or {}
DDS.VERSION = "0.3.0"
DDS.MODULE = "DeadDaysStory"

---------------------------------------------------------------------------
-- Environment
---------------------------------------------------------------------------

function DDS.isClientOnly()
    return type(isClient) == "function" and isClient() == true
end

function DDS.isDedicated()
    return type(isServer) == "function" and isServer() == true
end

function DDS.isSP()
    return not DDS.isClientOnly() and not DDS.isDedicated()
end

-- The side that owns story state: the dedicated server, or the game itself in SP.
function DDS.isAuthority()
    return not DDS.isClientOnly()
end

function DDS.log(message)
    print("[DeadDaysStory] " .. tostring(message))
end

function DDS.guard(label, fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then DDS.log("error in " .. tostring(label) .. ": " .. tostring(err)) end
        return ok and err or nil
    end
end

function DDS.nowHours()
    local hours = 0
    pcall(function() hours = getGameTime():getWorldAgeHours() end)
    return tonumber(hours) or 0
end

function DDS.day()
    return math.floor(DDS.nowHours() / 24) + 1
end

function DDS.hourOfDay()
    local hour = 12
    pcall(function() hour = getGameTime():getHour() end)
    return tonumber(hour) or 12
end

function DDS.nowMs()
    if type(getTimestampMs) == "function" then return getTimestampMs() end
    return os.time() * 1000
end

function DDS.username(player)
    if player == nil then return nil end
    local name
    pcall(function() name = player:getUsername() end)
    if name == nil or name == "" then
        local num = 0
        pcall(function() num = player:getPlayerNum() end)
        name = "player" .. tostring(num)
    end
    return tostring(name)
end

function DDS.displayName(player)
    local name
    pcall(function()
        local desc = player:getDescriptor()
        name = desc:getForename() .. " " .. desc:getSurname()
    end)
    return name or DDS.username(player) or "Survivor"
end

function DDS.onlinePlayers()
    local result = {}
    if DDS.isDedicated() or DDS.isClientOnly() then
        pcall(function()
            local list = getOnlinePlayers()
            for i = 0, list:size() - 1 do
                local p = list:get(i)
                if p ~= nil then result[#result + 1] = p end
            end
        end)
    end
    if #result == 0 and not DDS.isDedicated() then
        pcall(function()
            for i = 0, getNumActivePlayers() - 1 do
                local p = getSpecificPlayer(i)
                if p ~= nil then result[#result + 1] = p end
            end
        end)
    end
    return result
end

function DDS.playerByName(username)
    for _, p in ipairs(DDS.onlinePlayers()) do
        if DDS.username(p) == username then return p end
    end
    return nil
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

function DDS.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function DDS.dist(x1, y1, x2, y2)
    local dx, dy = (x1 or 0) - (x2 or 0), (y1 or 0) - (y2 or 0)
    return math.sqrt(dx * dx + dy * dy)
end

function DDS.copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for k, v in pairs(value) do result[DDS.copy(k, seen)] = DDS.copy(v, seen) end
    return result
end

-- Kahlua has no next(); this is the portable emptiness check.
function DDS.isEmpty(t)
    if t == nil then return true end
    for _ in pairs(t) do return false end
    return true
end

function DDS.count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

function DDS.contains(list, value)
    for _, v in ipairs(list or {}) do if v == value then return true end end
    return false
end

function DDS.push(list, value, cap)
    list[#list + 1] = value
    if cap then while #list > cap do table.remove(list, 1) end end
    return value
end

function DDS.titleCase(text)
    -- Kahlua passes nil (not "") for an empty capture.
    return (string.gsub(tostring(text or ""), "(%a)([%w']*)", function(a, b)
        return string.upper(a or "") .. string.lower(b or "")
    end))
end

function DDS.compass(dx, dy)
    -- Project Zomboid: +x is east-south-east on screen, +y south-south-east.
    -- Plain map compass on world axes: north is -y. tan(22.5deg) ~= 0.414.
    local ax, ay = math.abs(dx or 0), math.abs(dy or 0)
    if ax <= ay * 0.414 then return dy < 0 and "N" or "S" end
    if ay <= ax * 0.414 then return dx > 0 and "E" or "W" end
    return (dy < 0 and "N" or "S") .. (dx > 0 and "E" or "W")
end

---------------------------------------------------------------------------
-- Seeded randomness (Park-Miller). Stories must replay identically from a
-- seed, so nothing story-shaped uses math.random directly.
---------------------------------------------------------------------------

local Rng = {}
Rng.__index = Rng

function DDS.rng(seed)
    local s = math.floor(math.abs(tonumber(seed) or 1)) % 2147483647
    if s == 0 then s = 1 end
    return setmetatable({ state = s }, Rng)
end

function DDS.freshSeed()
    return (math.floor(DDS.nowMs()) % 2147483000) + ZombRand(1, 99999)
end

function Rng:next()
    self.state = (self.state * 48271) % 2147483647
    return self.state / 2147483647
end

function Rng:int(lo, hi)
    if hi == nil then lo, hi = 1, lo end
    if hi < lo then return lo end
    return lo + math.floor(self:next() * (hi - lo + 1))
end

function Rng:chance(p)
    return self:next() < (tonumber(p) or 0)
end

function Rng:pick(list)
    if type(list) ~= "table" or #list == 0 then return nil end
    return list[self:int(1, #list)]
end

function Rng:weighted(list, weightOf)
    local total = 0
    for _, item in ipairs(list or {}) do total = total + math.max(0, weightOf(item) or 0) end
    if total <= 0 then return nil end
    local needle = self:next() * total
    local last
    for _, item in ipairs(list) do
        local w = math.max(0, weightOf(item) or 0)
        if w > 0 then
            last = item
            needle = needle - w
            if needle < 0 then return item end
        end
    end
    return last
end

function Rng:shuffle(list)
    for i = #list, 2, -1 do
        local j = self:int(1, i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

---------------------------------------------------------------------------
-- Text templating.
--   {key} / {key.sub}  -> value from vars
--   [[a|b|c]]          -> one variant, chosen by rng
-- Variants resolve first so a variant can itself carry {keys}.
---------------------------------------------------------------------------

DDS.Text = DDS.Text or {}

local function lookup(vars, path)
    local value = vars
    for part in string.gmatch(path, "[^%.]+") do
        if type(value) ~= "table" then return nil end
        value = value[part]
    end
    return value
end

function DDS.Text.render(text, vars, rng)
    if type(text) == "table" then
        text = rng and rng:pick(text) or text[1]
    end
    text = tostring(text or "")
    vars = vars or {}
    local guard = 0
    while guard < 4 and string.find(text, "%[%[") do
        guard = guard + 1
        text = string.gsub(text, "%[%[([^%[%]]-)%]%]", function(body)
            body = body or ""
            local options = {}
            for option in string.gmatch(body .. "|", "([^|]*)|") do options[#options + 1] = option or "" end
            if #options == 0 then return "" end
            if rng then return rng:pick(options) end
            return options[ZombRand(1, #options + 1)]
        end)
    end
    text = string.gsub(text, "{([%w_%.]+)}", function(path)
        local value = lookup(vars, path)
        if value == nil then return "{" .. path .. "}" end
        if type(value) == "table" then value = value.name or value.label or "?" end
        return tostring(value)
    end)
    return text
end

---------------------------------------------------------------------------
-- Network bridge. In single player both halves live in one Lua state, so we
-- dispatch directly instead of trusting the engine to loop commands back.
---------------------------------------------------------------------------

DDS.Net = DDS.Net or { serverHandlers = {}, clientHandlers = {} }

function DDS.Net.onServer(command, fn) DDS.Net.serverHandlers[command] = fn end
function DDS.Net.onClient(command, fn) DDS.Net.clientHandlers[command] = fn end

function DDS.Net.dispatchServer(command, player, args)
    local fn = DDS.Net.serverHandlers[command]
    if fn == nil then return end
    local ok, err = pcall(fn, player, args or {})
    if not ok then DDS.log("server handler " .. command .. " failed: " .. tostring(err)) end
end

function DDS.Net.dispatchClient(command, args)
    local fn = DDS.Net.clientHandlers[command]
    if fn == nil then return end
    local ok, err = pcall(fn, args or {})
    if not ok then DDS.log("client handler " .. command .. " failed: " .. tostring(err)) end
end

function DDS.Net.toServer(command, args)
    if DDS.isSP() then
        DDS.Net.dispatchServer(command, getPlayer(), args)
    else
        sendClientCommand(DDS.MODULE, command, args or {})
    end
end

function DDS.Net.toPlayer(player, command, args)
    if player == nil then return end
    if DDS.isSP() then
        DDS.Net.dispatchClient(command, args)
    else
        sendServerCommand(player, DDS.MODULE, command, args or {})
    end
end

function DDS.Net.toAll(command, args)
    if DDS.isSP() then
        DDS.Net.dispatchClient(command, args)
    else
        sendServerCommand(DDS.MODULE, command, args or {})
    end
end

if not DDS.Net.registered and type(Events) == "table" then
    DDS.Net.registered = true
    if Events.OnClientCommand then
        Events.OnClientCommand.Add(function(module, command, player, args)
            if module ~= DDS.MODULE then return end
            DDS.Net.dispatchServer(command, player, args)
        end)
    end
    if Events.OnServerCommand then
        Events.OnServerCommand.Add(function(module, command, args)
            if module ~= DDS.MODULE then return end
            DDS.Net.dispatchClient(command, args)
        end)
    end
end

return DDS
