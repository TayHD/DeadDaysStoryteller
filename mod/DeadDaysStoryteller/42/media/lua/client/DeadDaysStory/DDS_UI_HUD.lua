-- HUD: the mission tracker (top right, left of the moodles) and toast notifications.

require "DeadDaysStory/DDS_UI_Base"
require "DeadDaysStory/DDS_Client"

local UI = DDS.UI
local C = DDS.Client

---------------------------------------------------------------------------
-- Toasts
---------------------------------------------------------------------------

UI.Toast = UI.Toast or { items = {} }
local Toast = UI.Toast

function Toast.push(text, tone)
    local item = { text = text, tone = tone or "info", born = getTimestampMs() }
    local life = (tone == "twist" or tone == "act" or tone == "morning") and 11000 or 6500
    item.life = life
    table.insert(Toast.items, 1, item)
    while #Toast.items > 5 do table.remove(Toast.items) end
end

---------------------------------------------------------------------------
-- Tracker + toast host panel
---------------------------------------------------------------------------

DDSHud = DDSPanel:derive("DDSHud")

-- Keep clear of the moodle column on the right edge. The moodles UI reports
-- where it sits; if it can't, fall back to a margin that clears it at the
-- default moodle size.
function DDSHud.rightMargin()
    local margin = 120
    pcall(function()
        local m = MoodlesUI.getInstance()
        if m then
            local left = tonumber(m:getX()) or 0
            if left > 0 then margin = getCore():getScreenWidth() - left + 24 end
        end
    end)
    return DDS.clamp(margin, 100, 260)
end

function DDSHud:new()
    local w = 390
    local o = DDSPanel.new(self, getCore():getScreenWidth() - w - DDSHud.rightMargin(), 90, w, 400)
    o.anchorRight = true
    return o
end

function DDSHud:onMouseDown(x, y)
    for i = #self.hits, 1, -1 do
        local h = self.hits[i]
        if x >= h.x and x <= h.x + h.w and y >= h.y and y <= h.y + h.h then h.fn(); return true end
    end
    return false
end

function DDSHud:isMouseOverHits()
    local mx, my = self:getMouseX(), self:getMouseY()
    for _, h in ipairs(self.hits) do
        if mx >= h.x and mx <= h.x + h.w and my >= h.y and my <= h.y + h.h then return true end
    end
    return false
end

function DDSHud:render()
    self.hits = {}
    self:setX(getCore():getScreenWidth() - self.width - DDSHud.rightMargin())
    local v = C.view
    local y = 0
    local W = self.width
    local fs, fm = UIFont.Small, UIFont.Medium
    local lh = UI.fontH(fs)

    -- Journal button + radio indicator.
    local calls = v and v.calls and #v.calls or 0
    local label = "JOURNAL"
    if calls > 0 then label = "RADIO (" .. calls .. ")  JOURNAL" end
    local bw = UI.textW(fs, label) + 32
    local blink = calls > 0 and (math.floor(getTimestampMs() / 600) % 2 == 0)
    self:fill(W - bw, y, bw, lh + 16, "bg", 0.8)
    self:border(W - bw, y, bw, lh + 16, blink and "radio" or "line", 0.9)
    self:textRight(label, W - 16, y + 8, calls > 0 and "radio" or "muted", fs)
    self:hit(W - bw, y, bw, lh + 16, function() if UI.Journal then UI.Journal.toggle(calls > 0 and "calls" or nil) end end)
    y = y + lh + 26

    -- Tracked mission.
    local q = C.trackedQuest()
    if q and not (UI.Journal and UI.Journal.instance and UI.Journal.instance:isVisible()) then
        local o = C.nextObjective(q)
        local lines = UI.wrap(q.title, fm, W - 40)
        local objLines = o and UI.wrap(o.text, fs, W - 40) or {}
        local h = 18 + lh + 6 + #lines * (UI.fontH(fm) + 3) + 10 + #objLines * (lh + 3) + 18
        local dist
        if o and o.x then
            local d, dir = C.distanceTo(o.x, o.y)
            dist = string.format("%dm %s", math.floor(d), dir)
            h = h + lh + 8
        end
        if q.stepTitle then h = h + lh + 6 end
        self:fill(0, y, W, h, "bg", 0.72)
        self:fill(0, y, 3, h, UI.arcColor[q.arc] or "accent")
        local ty = y + 18
        self:text(UI.arcLabel[q.arc] or "", 20, ty, UI.arcColor[q.arc] or "accent", fs, 0.9)
        if q.hoursLeft then self:textRight(q.hoursLeft .. "h left", W - 18, ty, q.hoursLeft < 6 and "bad" or "muted", fs) end
        ty = ty + lh + 6
        for _, line in ipairs(lines) do self:line(line, 20, ty, "text", fm); ty = ty + UI.fontH(fm) + 3 end
        if q.stepTitle then self:text(q.stepTitle, 20, ty, "muted", fs); ty = ty + lh + 6 end
        ty = ty + 10
        for _, line in ipairs(objLines) do self:line(line, 20, ty, "accent", fs); ty = ty + lh + 3 end
        if dist then self:text(dist, 20, ty + 6, "radio", fs) end
        self:hit(0, y, W, h, function() if UI.Journal then UI.Journal.open("missions", q.id) end end)
        y = y + h + 14
    end

    -- Toasts.
    local now = getTimestampMs()
    local keep = {}
    for _, t in ipairs(Toast.items) do
        local age = now - t.born
        if age < t.life then
            keep[#keep + 1] = t
            local alpha = age > t.life - 1200 and (t.life - age) / 1200 or 1
            local lines = UI.wrap(t.text, fs, W - 40)
            local h = #lines * (lh + 3) + 28
            local col = UI.tones[t.tone] or "text"
            self:fill(0, y, W, h, "bg", 0.8 * alpha)
            self:fill(0, y, 3, h, col, alpha)
            local ty = y + 14
            for _, line in ipairs(lines) do self:line(line, 20, ty, col, fs, alpha); ty = ty + lh + 3 end
            y = y + h + 10
        end
    end
    Toast.items = keep
    self:setHeight(math.max(40, y))
end

Events.OnCreatePlayer.Add(function(playerNum)
    if playerNum ~= 0 or UI.hud then return end
    UI.hud = DDSHud:new()
    UI.hud:initialise()
    UI.hud:addToUIManager()
    UI.hud:setAlwaysOnTop(false)
end)

Events.OnResolutionChange.Add(function()
    if UI.hud then UI.hud:setX(getCore():getScreenWidth() - UI.hud.width - DDSHud.rightMargin()) end
end)

return UI
