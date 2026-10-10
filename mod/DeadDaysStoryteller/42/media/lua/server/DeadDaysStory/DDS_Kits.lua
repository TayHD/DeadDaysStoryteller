-- Starting kits: a new character arrives with what someone in their line of
-- work would plausibly have on them on the first day. Given once per
-- character, on the server, the first time they say hello.

require "DeadDaysStory/DDS_Core"
require "DeadDaysStory/DDS_Items"

DDS.Kits = DDS.Kits or {}
local Kits = DDS.Kits

-- Everyone grabbed something on the way out the door.
Kits.common = { "Base.WaterBottle", "Base.TinnedBeans", "Base.TinOpener" }

-- Keyed by profession name as the game reports it (lowercase, no "base:").
-- Entries are { type, count }.
Kits.byProfession = {
    policeofficer = { { "Base.Pistol" }, { "Base.9mmClip", 2 }, { "Base.Bullets9mmBox" }, { "Base.Nightstick" }, { "Base.HandTorch" } },
    securityguard = { { "Base.Nightstick" }, { "Base.HandTorch" }, { "Base.WalkieTalkie2" } },
    fireofficer = { { "Base.Axe" }, { "Base.Bandage", 2 }, { "Base.HandTorch" } },
    parkranger = { { "Base.HuntingRifle" }, { "Base.308Box" }, { "Base.HuntingKnife" }, { "Base.Matches" } },
    veteran = { { "Base.Pistol2" }, { "Base.45Clip" }, { "Base.Bullets45Box" }, { "Base.HuntingKnife" } },
    doctor = { { "Base.Bag_MedicalBag" }, { "Base.Scalpel" }, { "Base.SutureNeedle", 2 }, { "Base.Tweezers" },
        { "Base.Antibiotics" }, { "Base.Bandage", 3 }, { "Base.Disinfectant" } },
    nurse = { { "Base.Bandage", 4 }, { "Base.Disinfectant" }, { "Base.Pills" }, { "Base.Tweezers" }, { "Base.AlcoholWipes", 2 } },
    constructionworker = { { "Base.Hammer" }, { "Base.NailsBox" }, { "Base.Saw" } },
    carpenter = { { "Base.Hammer" }, { "Base.Saw" }, { "Base.NailsBox" }, { "Base.Screwdriver" } },
    lumberjack = { { "Base.WoodAxe" }, { "Base.Saw" } },
    burglar = { { "Base.Crowbar" }, { "Base.Screwdriver" }, { "Base.Bag_DuffelBag" } },
    chef = { { "Base.MeatCleaver" }, { "Base.KitchenKnife" }, { "Base.TinnedSoup", 2 } },
    burgerflipper = { { "Base.KitchenKnife" }, { "Base.Pan" }, { "Base.Crisps", 2 } },
    farmer = { { "Base.Shovel" }, { "Base.CarrotSeed" }, { "Base.PotatoSeed" }, { "Base.HandScythe" } },
    fisherman = { { "Base.FishingRod" }, { "Base.FishingLine" }, { "Base.KitchenKnife" } },
    repairman = { { "Base.Wrench" }, { "Base.Screwdriver" }, { "Base.Hammer" }, { "Base.DuctTape" } },
    mechanics = { { "Base.Wrench" }, { "Base.LugWrench" }, { "Base.Jack" }, { "Base.Screwdriver" } },
    electrician = { { "Base.Screwdriver" }, { "Base.Pliers" }, { "Base.ElectricWire" }, { "Base.Battery", 2 }, { "Base.HandTorch" } },
    engineer = { { "Base.Screwdriver" }, { "Base.ElectronicsScrap", 3 }, { "Base.Battery" }, { "Base.DuctTape" } },
    metalworker = { { "Base.BlowTorch" }, { "Base.WeldingMask" }, { "Base.PipeWrench" } },
    fitnessinstructor = { { "Base.Bag_Satchel" }, { "Base.GranolaBar", 2 }, { "Base.WaterBottle" } },
    unemployed = { { "Base.BaseballBat" }, { "Base.Bag_Schoolbag" }, { "Base.Crisps" }, { "Base.Pop" } },
}

function Kits.professionOf(player)
    local name
    pcall(function() name = player:getDescriptor():getCharacterProfession():getName() end)
    if name == nil then
        pcall(function() name = tostring(player:getDescriptor():getCharacterProfession()) end)
    end
    name = string.lower(tostring(name or "unemployed"))
    local colon = string.find(name, ":", 1, true)
    if colon then name = string.sub(name, colon + 1) end
    name = string.gsub(name, "[^%a]", "")
    return name
end

local function characterKey(player)
    local first, last = "", ""
    pcall(function()
        local desc = player:getDescriptor()
        first, last = desc:getForename() or "", desc:getSurname() or ""
    end)
    local survived = 0
    pcall(function() survived = player:getHoursSurvived() or 0 end)
    local spawnedAt = math.floor(DDS.nowHours() - survived + 0.5)
    return "kit_" .. first .. "_" .. last .. "_" .. tostring(spawnedAt), survived
end

function Kits.give(player)
    local profession = Kits.professionOf(player)
    local kit = Kits.byProfession[profession] or Kits.byProfession.unemployed
    local given = 0
    for _, fullType in ipairs(Kits.common) do given = given + DDS.Items.give(player, fullType, 1) end
    for _, entry in ipairs(kit) do given = given + DDS.Items.give(player, entry[1], entry[2] or 1) end
    DDS.log("starting kit for " .. tostring(DDS.username(player)) .. " (" .. profession .. "): " .. given .. " items")
    return given
end

-- Only brand-new characters (under an hour lived) and only once each.
function Kits.onHello(player)
    if player == nil then return end
    local key, survived = characterKey(player)
    if survived >= 1 then return end
    local data
    pcall(function() data = player:getModData() end)
    if data and data.DDSKit then return end
    local ps = DDS.State.player(DDS.username(player))
    if ps.flags[key] then return end
    ps.flags[key] = true
    if data then data.DDSKit = true end
    Kits.give(player)
end

return Kits
