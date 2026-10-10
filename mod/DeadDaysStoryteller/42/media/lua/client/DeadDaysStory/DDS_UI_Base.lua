-- UI foundations: palette, fonts, word wrap, and a custom-drawn panel with
-- simple click regions. Every story window is built on this, so the look is
-- consistent and nothing depends on fiddly widget layouts.

require "ISUI/ISPanel"
require "DeadDaysStory/DDS_Core"

DDS.UI = DDS.UI or {}
local UI = DDS.UI

UI.color = {
    bg = { 0.07, 0.07, 0.08 }, panel = { 0.11, 0.11, 0.12 }, panelHi = { 0.16, 0.16, 0.17 },
    line = { 0.25, 0.24, 0.22 }, text = { 0.93, 0.91, 0.86 }, muted = { 0.62, 0.61, 0.58 }, dim = { 0.42, 0.41, 0.4 },
    accent = { 0.96, 0.66, 0.22 }, good = { 0.48, 0.82, 0.46 }, bad = { 0.92, 0.38, 0.32 }, radio = { 0.46, 0.76, 0.93 },
    twist = { 0.78, 0.52, 0.94 }, danger = { 0.97, 0.3, 0.25 },
}

UI.tones = {
    info = "text", good = "good", bad = "bad", radio = "radio", lead = "accent", story = "text", twist = "twist",
    act = "accent", complete = "good", danger = "danger", loss = "bad", morning = "accent", buddy = "radio",
}

UI.arcColor = { spine = "accent", side = "text", daily = "good", loyalty = "radio", chain = "twist", incident = "danger" }
UI.arcLabel = { spine = "STORY", side = "SIDE", daily = "DAILY", loyalty = "LOYALTY", chain = "LONG HAUL", incident = "URGENT" }

function UI.rgb(name) return UI.color[name] or UI.color.text end

function UI.fontH(font)
    return getTextManager():getFontHeight(font)
end

function UI.textW(font, text)
    return getTextManager():MeasureStringX(font, tostring(text or ""))
end

-- Sentence case for anything the UI shows: generated names often start with
-- "the" ("the Camp"), so the first letter of a line and of each sentence is
-- raised. An ellipsis ("wait... no") is left alone.
-- No empty captures here: Kahlua mangles them (it dropped the letter).
function UI.sentence(text)
    text = tostring(text or "")
    local i = string.find(text, "%S")
    if i and string.find(string.sub(text, i, i), "%l") then
        text = string.sub(text, 1, i - 1) .. string.upper(string.sub(text, i, i)) .. string.sub(text, i + 1)
    end
    text = string.gsub(text, "([^%.][%.!%?:]%s+)(%l)", function(lead, letter)
        return (lead or "") .. string.upper(letter or "")
    end)
    return text
end

-- Word wrap with explicit newlines respected.
function UI.wrap(text, font, width)
    local lines = {}
    text = tostring(text or "")
    for para in string.gmatch(text .. "\n", "(.-)\n") do
        para = UI.sentence(para or "")  -- Kahlua yields nil for an empty capture
        local line = ""
        for word in string.gmatch(para, "%S+") do
            local candidate = line == "" and word or (line .. " " .. word)
            if UI.textW(font, candidate) > width and line ~= "" then
                lines[#lines + 1] = line
                line = word
            else
                line = candidate
            end
        end
        lines[#lines + 1] = line
    end
    return lines
end

---------------------------------------------------------------------------
-- DDSPanel: custom-drawn panel with click regions and hover.
---------------------------------------------------------------------------

DDSPanel = ISPanel:derive("DDSPanel")

function DDSPanel:new(x, y, w, h)
    local o = ISPanel.new(self, x, y, w, h)
    o.background = false
    o.hits = {}
    o.scroll = {}
    return o
end

function DDSPanel:hover(x, y, w, h)
    local mx, my = self:getMouseX(), self:getMouseY()
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function DDSPanel:hit(x, y, w, h, fn, scrollKey)
    self.hits[#self.hits + 1] = { x = x, y = y, w = w, h = h, fn = fn, scrollKey = scrollKey }
end

function DDSPanel:fill(x, y, w, h, c, a)
    c = type(c) == "string" and UI.rgb(c) or c
    self:drawRect(x, y, w, h, a or 1, c[1], c[2], c[3])
end

function DDSPanel:border(x, y, w, h, c, a)
    c = type(c) == "string" and UI.rgb(c) or c
    self:drawRectBorder(x, y, w, h, a or 1, c[1], c[2], c[3])
end

function DDSPanel:text(s, x, y, c, font, a)
    c = type(c) == "string" and UI.rgb(c) or (c or UI.color.text)
    self:drawText(UI.sentence(s), x, y, c[1], c[2], c[3], a or 1, font or UIFont.Small)
end

function DDSPanel:textRight(s, x, y, c, font, a)
    c = type(c) == "string" and UI.rgb(c) or (c or UI.color.text)
    self:drawTextRight(UI.sentence(s), x, y, c[1], c[2], c[3], a or 1, font or UIFont.Small)
end

function DDSPanel:textCentre(s, x, y, c, font, a)
    c = type(c) == "string" and UI.rgb(c) or (c or UI.color.text)
    self:drawTextCentre(UI.sentence(s), x, y, c[1], c[2], c[3], a or 1, font or UIFont.Small)
end

-- A line that came out of UI.wrap: already sentence-cased as a paragraph, so
-- it is drawn as-is (a wrapped line starting "group of..." must stay lowercase).
function DDSPanel:line(s, x, y, c, font, a)
    c = type(c) == "string" and UI.rgb(c) or (c or UI.color.text)
    self:drawText(tostring(s or ""), x, y, c[1], c[2], c[3], a or 1, font or UIFont.Small)
end

-- Draw wrapped text; returns height used.
function DDSPanel:para(s, x, y, w, c, font, gap)
    font = font or UIFont.Small
    local lh = UI.fontH(font) + (gap or 2)
    local lines = UI.wrap(s, font, w)
    for i, line in ipairs(lines) do self:line(line, x, y + (i - 1) * lh, c, font) end
    return #lines * lh
end

function DDSPanel:button(label, x, y, w, h, fn, style)
    style = style or "normal"
    local over = self:hover(x, y, w, h)
    local base = style == "primary" and UI.color.accent or (style == "danger" and UI.color.bad or UI.color.panelHi)
    if style == "primary" or style == "danger" then
        self:fill(x, y, w, h, base, over and 1 or 0.85)
        self:textCentre(label, x + w / 2, y + (h - UI.fontH(UIFont.Small)) / 2, { 0.08, 0.07, 0.06 }, UIFont.Small)
    else
        self:fill(x, y, w, h, base, over and 1 or 0.9)
        self:border(x, y, w, h, over and "accent" or "line")
        self:textCentre(label, x + w / 2, y + (h - UI.fontH(UIFont.Small)) / 2, over and "accent" or "text", UIFont.Small)
    end
    self:hit(x, y, w, h, fn)
end

function DDSPanel:bar(x, y, w, h, frac, c)
    self:fill(x, y, w, h, "panelHi")
    self:fill(x, y, math.max(0, math.min(1, frac)) * w, h, c or "accent")
end

function DDSPanel:prerender()
    self.hits = {}
end

function DDSPanel:onMouseDown(x, y)
    for i = #self.hits, 1, -1 do
        local h = self.hits[i]
        if x >= h.x and x <= h.x + h.w and y >= h.y and y <= h.y + h.h then
            pcall(function() getSoundManager():playUISound("UISelectListItem") end)
            h.fn()
            return true
        end
    end
    if self.dragOnBody then
        self.dragging = true
        self.dragX, self.dragY = x, y
        self:setCapture(true)
    end
    return true
end

function DDSPanel:onMouseMove(dx, dy)
    if self.dragging then
        self:setX(self:getX() + dx)
        self:setY(self:getY() + dy)
    end
end

function DDSPanel:onMouseMoveOutside(dx, dy)
    if self.dragging then
        self:setX(self:getX() + dx)
        self:setY(self:getY() + dy)
    end
end

function DDSPanel:onMouseUp(x, y)
    if self.dragging then self.dragging = false; self:setCapture(false) end
    return true
end

function DDSPanel:onMouseUpOutside(x, y)
    if self.dragging then self.dragging = false; self:setCapture(false) end
end

return UI
