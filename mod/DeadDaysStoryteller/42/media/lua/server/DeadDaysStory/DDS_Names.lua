-- Name and flavour pools. Kentucky, 1993.

require "DeadDaysStory/DDS_Core"

DDS.Names = DDS.Names or {}
local N = DDS.Names

N.male = { "Earl", "Dale", "Wade", "Clint", "Russell", "Travis", "Darrell", "Marcus", "Leon", "Curtis", "Wendell",
    "Roy", "Silas", "Abel", "Jesse", "Calvin", "Hollis", "Virgil", "Danny", "Tommy", "Ray", "Gene", "Lyle", "Otis",
    "Boyd", "Cecil", "Dwayne", "Floyd", "Garrett", "Harlan", "Isaiah", "Jasper", "Kenny", "Luther", "Mitch", "Nate",
    "Owen", "Preston", "Quincy", "Reuben", "Shane", "Toby", "Vernon", "Wesley", "Zeke", "Andre", "Terrence", "Hector",
    "Luis", "Miguel", "Tran", "Samuel", "Elijah", "Grady", "Hank" }
N.female = { "Ruth", "June", "Darlene", "Tammy", "Loretta", "Opal", "Marlene", "Faye", "Nadine", "Rosa", "Wanda",
    "Bonnie", "Carla", "Dottie", "Ellie", "Frances", "Georgia", "Hazel", "Ida", "Jolene", "Kay", "Lacey", "Maddie",
    "Nell", "Patsy", "Reba", "Sadie", "Tessa", "Vera", "Wynona", "Alma", "Billie", "Celeste", "Della", "Esther",
    "Grace", "Hattie", "Inez", "Josie", "Kendra", "Lena", "Marisol", "Naomi", "Priya", "Shonda", "Tia", "Yolanda", "Abby" }
N.surname = { "Mattingly", "Hardin", "Crane", "Pruitt", "Skaggs", "Hornback", "Tackett", "Ledford", "Bledsoe",
    "Combs", "Napier", "Vittitoe", "Kessinger", "Whitaker", "Dabney", "Crume", "Hobbs", "Renfro", "Coyle", "Prather",
    "Sizemore", "Gentry", "Holbrook", "Caudill", "Begley", "Slone", "Fugate", "Mullins", "Hensley", "Blevins",
    "Stidham", "Turner", "Wolfe", "Brewer", "Calloway", "Delk", "Embry", "Goins", "Harmon", "Isom", "Jett", "Kincaid",
    "Lykins", "Moberly", "Noe", "Osborne", "Puckett", "Raleigh", "Spurlock", "Thacker", "Vance", "Walters", "Yates",
    "Ortiz", "Nguyen", "Washington", "Jefferson", "Reyes", "Castillo", "Okafor", "Brooks" }
-- Ordinary nicknames. Nobody out here calls themselves anything grander.
N.lieutenantMoniker = { "Tiny", "Red", "Junior", "Skeeter", "Dusty", "Bo", "Shorty", "Bub", "Rusty", "Hoss",
    "Lefty", "Peanut", "Tater", "Sonny" }
N.rank = { "Captain", "First Lieutenant", "Second Lieutenant", "Staff Sergeant", "Sergeant First Class" }
N.callsign = { "Dagger Six", "Warhorse Two", "Sentry One-One", "Ironside Six", "Lancer Three", "Rawhide Two-Six",
    "Mustang Six", "Bravo Two-Six", "Gator One", "Hammer Three" }

-- Amateur radio callsigns, Kentucky is 4-land.
function N.hamCallsign(rng)
    local prefix = rng:pick({ "KD4", "KE4", "KJ4", "KY4", "N4", "W4", "KB4", "KC4" })
    local letters = ""
    for _ = 1, rng:int(2, 3) do letters = letters .. string.char(65 + rng:int(0, 25)) end
    return prefix .. letters
end

-- What a group of survivors would actually call the place they hold.
function N.placeName(rng, site, lastName)
    -- Sites out of town come back as "outside X" / "the backroads outside X".
    local town = site.town or lastName
    if string.sub(town, 1, 8) == "outside " or string.sub(town, 1, 4) == "the " then town = lastName end
    local by = {
        church = { lastName .. " Road Baptist", "First Methodist", town .. " Church of Christ", "St. Paul's" },
        school = { town .. " Elementary", town .. " High", town .. " Middle School" },
        motel = { "the " .. lastName .. " Motor Court", "the Starlite Motel", "the Pines Motel" },
        warehouse = { "the " .. lastName .. " lumber yard", "the co-op warehouse", "the feed mill" },
        gas = { "the truck stop", "the Fossoil station", "the Gas-2-Go" },
        bar = { "the roadhouse", "Hank's Tavern", "the VFW hall" },
        police = { "the old sheriff's office", "the state police post" },
    }
    local pool = by[site.kind] or { "the " .. lastName .. " place" }
    return rng:pick(pool)
end
N.kin = {
    { word = "daughter", pronoun = "she", object = "her", possessive = "her", female = true },
    { word = "son", pronoun = "he", object = "him", possessive = "his", female = false },
    { word = "little brother", pronoun = "he", object = "him", possessive = "his", female = false },
    { word = "sister", pronoun = "she", object = "her", possessive = "her", female = true },
    { word = "wife", pronoun = "she", object = "her", possessive = "her", female = true },
    { word = "husband", pronoun = "he", object = "him", possessive = "his", female = false },
}

function N.person(rng, female)
    if female == nil then female = rng:chance(0.5) end
    local first = rng:pick(female and N.female or N.male)
    local last = rng:pick(N.surname)
    return {
        first = first, last = last, name = first .. " " .. last, female = female,
        he = female and "she" or "he", him = female and "her" or "him", his = female and "her" or "his",
        He = female and "She" or "He", His = female and "Her" or "His",
    }
end

return N
