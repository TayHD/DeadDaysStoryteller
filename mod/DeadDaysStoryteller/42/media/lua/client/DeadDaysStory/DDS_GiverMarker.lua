-- Marks the people your missions want you to talk to: an outline on the
-- person and a gold "Talk to ..." label over their head, so they stand out
-- from everyone else at a settlement.

require "DeadDaysStory/DDS_Client"

DDS.GiverMarker = DDS.GiverMarker or { targets = {}, lit = {}, nextScanMs = 0 }
local M = DDS.GiverMarker
local C = DDS.Client

M.RANGE = 45
M.COLOR = { 1.0, 0.78, 0.3 }

local function shellUid(z)
    local uid
    pcall(function() uid = z:GetVariable("ALifeUID") end)
    if uid == nil or uid == "" then
        pcall(function() uid = z:getModData().ProjectALifeUID end)
    end
    return uid
end

-- uid -> label, from the talk objectives in the current view.
local function collectTargets()
    local targets = {}
    local v = C.view
    for _, q in ipairs(v and v.active or {}) do
        for _, o in ipairs(q.objectives or {}) do
            if o.kind == "talk" and o.uid and not o.done then targets[o.uid] = o.text or "Talk" end
        end
    end
    return targets
end

local function setOutline(z, on)
    pcall(function()
        z:setOutlineHighlight(on)
        if on then z:setOutlineHighlightCol(M.COLOR[1], M.COLOR[2], M.COLOR[3], 1.0) end
    end)
    pcall(function()
        z:setOutlineHighlight(0, on)
        if on then z:setOutlineHighlightCol(0, M.COLOR[1], M.COLOR[2], M.COLOR[3], 1.0) end
    end)
end

Events.OnPreUIDraw.Add(function()
    local player = getPlayer()
    if player == nil then return end
    local now = getTimestampMs()
    if now >= M.nextScanMs then
        M.nextScanMs = now + 500
        M.targets = collectTargets()
    end
    local ok, err = pcall(function()
        local seen = {}
        if not DDS.isEmpty(M.targets) then
            local list = getCell():getZombieList()
            local px, py = player:getX(), player:getY()
            local zoom = getCore():getZoom(0)
            for i = 0, list:size() - 1 do
                local z = list:get(i)
                if z and math.abs(z:getX() - px) < M.RANGE and math.abs(z:getY() - py) < M.RANGE then
                    local uid = shellUid(z)
                    local label = uid and M.targets[uid] or nil
                    if label and not z:isDead() then
                        seen[uid] = z
                        setOutline(z, true)
                        local sx = isoToScreenX(0, z:getX(), z:getY(), z:getZ())
                        local sy = isoToScreenY(0, z:getX(), z:getY(), z:getZ()) - (150 / zoom)
                        getTextManager():DrawStringCentre(UIFont.Medium, sx, sy, label,
                            M.COLOR[1], M.COLOR[2], M.COLOR[3], 0.95)
                    end
                end
            end
        end
        -- Whoever is no longer a target loses the outline.
        for uid, z in pairs(M.lit) do
            if seen[uid] == nil then setOutline(z, false) end
        end
        M.lit = seen
    end)
    if not ok and not M.warned then M.warned = true; print("[DeadDaysStory] giver marker: " .. tostring(err)) end
end)

return M
