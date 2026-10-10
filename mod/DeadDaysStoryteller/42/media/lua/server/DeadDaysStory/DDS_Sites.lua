-- Finding real places. Missions happen in buildings that exist on the map:
-- the director asks for "a mall 300-900 tiles from this player" and gets a
-- building, its bounds, and a few interior points, read from the metagrid
-- (works for unloaded chunks too).

require "DeadDaysStory/DDS_Core"
require "DeadDaysStory/DDS_ALife"

DDS.Sites = DDS.Sites or {}
local Sites = DDS.Sites

Sites.kinds = {
    mall = { label = "[[mall|shopping center|department store]]", rooms = {
        "departmentstore", "departmentstorage", "clothingstore", "shoestore", "jewelrystore", "giftstore",
        "sportstore", "toystore", "bookstore", "electronicstore", "plazastore1", "glassesstore",
        "leatherclothesstore", "musicstore", "comicstore", "camerastore", "candystore", "bagstore",
        "walletshop", "weddingstoredress", "weddingstoresuit", "cdstore", "movierental" }, minRooms = 4 },
    supermarket = { label = "[[supermarket|grocery store|Gigamart]]", rooms = {
        "gigamart", "grocery", "grocerystorage", "gigamartkitchen" }, minRooms = 1 },
    hospital = { label = "[[hospital|medical center|clinic]]", rooms = {
        "hospitalroom", "hospitalhallway", "hospitalstorage", "medicalstorage", "medicaloffice", "medical",
        "laboratory", "morgue" }, minRooms = 2 },
    pharmacy = { label = "[[pharmacy|drugstore]]", rooms = { "pharmacy", "pharmacystorage" }, minRooms = 1 },
    police = { label = "[[police station|sheriff's office|precinct]]", rooms = {
        "policeoffice", "policestorage", "policehall", "policelocker", "policegunstorage", "prisoncells",
        "policearchive", "evidenceroom", "interrogationroom", "detectiveoffice" }, minRooms = 2 },
    school = { label = "[[school|high school|elementary school]]", rooms = {
        "classroom", "elementaryclassroom", "secondaryclassroom", "schoolstorage", "schoollab",
        "schoolgymstorage", "elementaryschool" }, minRooms = 2 },
    church = { label = "[[church|chapel]]", rooms = { "church", "officechurch" }, minRooms = 1 },
    warehouse = { label = "[[warehouse|depot|factory]]", rooms = {
        "warehouse", "factory", "factorystorage", "loggingwarehouse", "loggingfactory", "metalshipping",
        "metalfabrication" }, minRooms = 1 },
    motel = { label = "[[motel|motor court]]", rooms = { "motelroom", "motelroomoccupied" }, minRooms = 3 },
    gas = { label = "[[gas station|truck stop]]", rooms = { "gasstore", "fossoil", "gas2go", "gasstorage" }, minRooms = 1 },
    gunstore = { label = "[[gun store|army surplus]]", rooms = { "gunstore", "gunstorestorage", "armysurplus" }, minRooms = 1 },
    bar = { label = "[[bar|roadhouse|tavern]]", rooms = { "bar", "ww_bar", "barkitchen" }, minRooms = 1 },
    restaurant = { label = "[[diner|restaurant|Spiffo's]]", rooms = {
        "spiffo_dining", "spiffoskitchen", "pizzawhirled", "burgerdining", "burgerkitchen", "dinerkitchen",
        "restaurantkitchen", "italiankitchen", "mexicankitchen", "chinesekitchen" }, minRooms = 1 },
    office = { label = "[[office building|business park]]", rooms = { "office", "officestorage" }, minRooms = 3 },
    military = { label = "[[army post|military depot]]", rooms = { "armystorage", "armytent", "oldarmy" }, minRooms = 1 },
    library = { label = "[[library|county library]]", rooms = { "library", "universitylibrary" }, minRooms = 1 },
    theatre = { label = "[[theatre|cinema]]", rooms = { "theatre", "theatrestorage", "theatrekitchen" }, minRooms = 1 },
    house = { label = "[[house|farmhouse|home]]", rooms = { "bedroom", "livingroom", "kitchen" }, minRooms = 3, maxRooms = 12 },
}

local roomKind
local function kindIndex()
    if roomKind then return roomKind end
    roomKind = {}
    for kind, def in pairs(Sites.kinds) do
        for _, room in ipairs(def.rooms) do
            roomKind[room] = roomKind[room] or {}
            roomKind[room][#roomKind[room] + 1] = kind
        end
    end
    return roomKind
end

-- Scan the metagrid around (x,y) and group matching rooms by building.
function Sites.scan(x, y, radius, wantKinds)
    radius = math.min(radius or 600, 1500)
    local index = kindIndex()
    local want = {}
    for _, k in ipairs(wantKinds) do want[k] = true end
    local buildings = {}
    local ok, err = pcall(function()
        local rooms = ArrayList.new()
        getWorld():getMetaGrid():getRoomsIntersecting(
            math.floor(x - radius), math.floor(y - radius), math.floor(radius * 2), math.floor(radius * 2), rooms)
        local total = math.min(rooms:size(), 6000)
        for i = 0, total - 1 do
            local def = rooms:get(i)
            if def ~= nil then
                local name = string.lower(tostring(def:getName() or ""))
                local kinds = index[name]
                if kinds then
                    local building = def:getBuilding()
                    if building ~= nil then
                        local key = tostring(building:getX()) .. "," .. tostring(building:getY())
                        local entry = buildings[key]
                        if entry == nil then
                            entry = {
                                key = key, building = building, rooms = {}, kinds = {}, total = 0,
                                x1 = building:getX(), y1 = building:getY(),
                                x2 = building:getX() + building:getW(), y2 = building:getY() + building:getH(),
                            }
                            buildings[key] = entry
                        end
                        entry.total = entry.total + 1
                        entry.rooms[#entry.rooms + 1] = {
                            name = name,
                            x = def:getX() + math.floor(def:getW() / 2),
                            y = def:getY() + math.floor(def:getH() / 2),
                            z = def:getZ(),
                            w = def:getW(), h = def:getH(),
                        }
                        for _, k in ipairs(kinds) do
                            if want[k] then entry.kinds[k] = (entry.kinds[k] or 0) + 1 end
                        end
                    end
                end
            end
        end
    end)
    if not ok then DDS.log("site scan failed: " .. tostring(err)) end
    return buildings
end

local function buildingRoomCount(entry)
    local count = 0
    pcall(function() count = entry.building:getRooms():size() end)
    return count
end

-- Find a site of one of `kinds` between minDist and maxDist from (x,y).
-- avoid: table of building keys already used by live missions.
function Sites.find(x, y, kinds, minDist, maxDist, rng, avoid)
    rng = rng or DDS.rng(DDS.freshSeed())
    minDist = minDist or 0
    maxDist = maxDist or 600
    avoid = avoid or {}
    local buildings = Sites.scan(x, y, maxDist, kinds)
    local candidates = {}
    for key, entry in pairs(buildings) do
        if not avoid[key] then
            local cx, cy = (entry.x1 + entry.x2) / 2, (entry.y1 + entry.y2) / 2
            local d = DDS.dist(x, y, cx, cy)
            if d >= minDist and d <= maxDist then
                for _, kind in ipairs(kinds) do
                    local def = Sites.kinds[kind]
                    local hits = entry.kinds[kind] or 0
                    local okSize = def and hits >= (def.minRooms or 1)
                    if okSize and def.maxRooms then okSize = buildingRoomCount(entry) <= def.maxRooms end
                    if okSize then
                        candidates[#candidates + 1] = { entry = entry, kind = kind, dist = d, cx = cx, cy = cy, score = hits }
                        break
                    end
                end
            end
        end
    end
    if #candidates == 0 then return nil end
    -- Prefer bigger matches a little; distance band already filtered.
    local pick = rng:weighted(candidates, function(c) return 1 + math.min(6, c.score) end)
    return Sites.describe(pick.entry, pick.kind, rng)
end

function Sites.describe(entry, kind, rng)
    local def = Sites.kinds[kind] or {}
    local cx, cy = math.floor((entry.x1 + entry.x2) / 2), math.floor((entry.y1 + entry.y2) / 2)
    local town = DDS.ALife.townAt(cx, cy)
    -- Interior points: the matched rooms, ground floor first.
    local rooms = {}
    for _, r in ipairs(entry.rooms) do rooms[#rooms + 1] = r end
    table.sort(rooms, function(a, b) return (a.z or 0) < (b.z or 0) end)
    local deep = rooms[1]
    local best = -1
    for _, r in ipairs(rooms) do
        local edge = math.min(r.x - entry.x1, entry.x2 - r.x, r.y - entry.y1, entry.y2 - r.y)
        if (r.z or 0) == 0 and edge > best then best, deep = edge, r end
    end
    local points = {}
    for i = 1, math.min(6, #rooms) do
        local r = rooms[i]
        points[#points + 1] = { x = r.x, y = r.y, z = r.z or 0, room = r.name }
    end
    local label = DDS.Text.render(def.label or kind, {}, rng)
    return {
        kind = kind,
        key = entry.key,
        x = cx, y = cy, z = 0,
        x1 = entry.x1, y1 = entry.y1, x2 = entry.x2, y2 = entry.y2,
        radius = math.max(12, math.floor(math.max(entry.x2 - entry.x1, entry.y2 - entry.y1) / 2) + 6),
        inner = deep and { x = deep.x, y = deep.y, z = deep.z or 0, room = deep.name } or { x = cx, y = cy, z = 0 },
        points = points,
        town = town,
        label = label,
        name = "the " .. town .. " " .. label,
    }
end

-- Open ground near a point (camps, rendezvous, ambush sites): a spot on a
-- ring around origin. Exact square validity is checked by A-Life at spawn.
function Sites.ring(x, y, minDist, maxDist, rng)
    rng = rng or DDS.rng(DDS.freshSeed())
    local angle = rng:next() * math.pi * 2
    local d = minDist + rng:next() * math.max(1, maxDist - minDist)
    local px, py = math.floor(x + math.cos(angle) * d), math.floor(y + math.sin(angle) * d)
    local town = DDS.ALife.townAt(px, py)
    return { kind = "open", key = "ring:" .. px .. "," .. py, x = px, y = py, z = 0, radius = 14,
        inner = { x = px, y = py, z = 0 }, points = { { x = px, y = py, z = 0 } },
        town = town, label = "clearing",
        name = DDS.Text.render("a [[clearing|tree line|field]] near " .. town, {}, rng) }
end

-- Try a list of kinds with a widening distance band; fall back to open ground.
function Sites.pick(x, y, kinds, minDist, maxDist, rng, avoid)
    local site = Sites.find(x, y, kinds, minDist, maxDist, rng, avoid)
    if site then return site end
    site = Sites.find(x, y, kinds, math.floor(minDist / 2), maxDist * 2, rng, avoid)
    if site then return site end
    site = Sites.find(x, y, { "house", "warehouse", "gas", "church" }, math.floor(minDist / 2), maxDist, rng, avoid)
    if site then return site end
    return Sites.ring(x, y, minDist, maxDist, rng)
end

function Sites.squareLoaded(x, y, z)
    local loaded = false
    pcall(function() loaded = getCell():getGridSquare(math.floor(x), math.floor(y), math.floor(z or 0)) ~= nil end)
    return loaded
end

return Sites
