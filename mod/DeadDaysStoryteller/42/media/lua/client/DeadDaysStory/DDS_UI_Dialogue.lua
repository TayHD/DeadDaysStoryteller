-- Dialogue window. Bottom-centre, cinematic letterbox feel. Number keys pick
-- choices; Escape walks away (the story notices).

require "DeadDaysStory/DDS_UI_Base"
require "DeadDaysStory/DDS_Client"
require "DeadDaysStory/DDS_Audio"

local UI = DDS.UI
local C = DDS.Client

UI.Dialogue = UI.Dialogue or {}
local Dlg = UI.Dialogue

DDSDialogue = DDSPanel:derive("DDSDialogue")

local tagColor = {
    mercy = "good", loyal = "good", honest = "good", respect = "good",
    ruthless = "bad", cold = "bad", greed = "bad", reckless = "bad",
    defiant = "accent", pragmatic = "muted", lawful = "radio", clever = "twist", independent = "accent", suspicious = "muted",
}

function DDSDialogue:new()
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local w = math.min(1000, sw - 80)
    local o = DDSPanel.new(self, (sw - w) / 2, sh - 420, w, 380)
    o.view = nil
    o.revealed = 0
    o.shownAt = 0
    return o
end

function DDSDialogue:setView(view)
    self.view = view
    self.shownAt = getTimestampMs()
    self.locked = false
end

function DDSDialogue:choose(index)
    if self.view == nil or self.locked then return end
    self.locked = true
    C.send("choose", { sessionId = self.view.sessionId, index = index })
end

function DDSDialogue:render()
    self.hits = {}
    local v = self.view
    if v == nil then return end
    local W = self.width
    local fs, fm = UIFont.Small, UIFont.Medium
    local pad = 34
    local textW = W - pad * 2

    -- Measure.
    local lines = UI.wrap(v.text, fm, textW)
    local lhM = UI.fontH(fm) + 6
    local lhS = UI.fontH(fs)
    local lhC = UI.fontH(fm) + 3
    local choiceLines = {}
    local choicesH = 0
    for i, c in ipairs(v.choices or {}) do
        local wl = UI.wrap(i .. ".   " .. c.text, fm, textW - 32)
        choiceLines[i] = wl
        choicesH = choicesH + #wl * lhC + 20 + 6
    end
    local H = pad + lhS + 18 + #lines * lhM + 26 + choicesH + pad
    local sh = getCore():getScreenHeight()
    self:setHeight(H)
    self:setY(sh - H - 90)
    self:setX((getCore():getScreenWidth() - W) / 2)

    -- Frame.
    self:fill(0, 0, W, H, "bg", 0.94)
    self:fill(0, 0, W, 4, v.radio and "radio" or "accent")
    self:border(0, 0, W, H, "line", 0.9)

    -- Speaker.
    local y = pad - 4
    local who = v.speaker ~= "" and string.upper(v.speaker) or ""
    if v.radio then
        self:text("RADIO", pad, y, "radio", fs)
        self:text(who, pad + UI.textW(fs, "RADIO") + 12, y, "accent", fs)
    else
        self:text(who, pad, y, "accent", fs)
    end
    if v.title and v.title ~= "" then self:textRight(v.title, W - pad, y, "dim", fs) end
    y = y + lhS + 18

    -- Text, typed out.
    local elapsed = getTimestampMs() - self.shownAt
    local budget = math.floor(elapsed / 12)
    local typed = 0
    for _, line in ipairs(lines) do
        local show = line
        if typed + #line > budget then show = string.sub(line, 1, math.max(0, budget - typed)) end
        typed = typed + #line
        self:line(show, pad, y, v.speaker == "" and "muted" or "text", fm)
        y = y + lhM
    end
    local done = typed <= budget
    y = y + 26

    -- Choices: full-width rows, generous click targets.
    for i, c in ipairs(v.choices or {}) do
        local wl = choiceLines[i]
        local h = #wl * lhC + 20
        local over = self:hover(pad - 12, y, textW + 24, h)
        self:fill(pad - 12, y, textW + 24, h, over and "panelHi" or "panel", over and 0.95 or 0.55)
        if over then self:fill(pad - 12, y, 3, h, "accent") end
        local col = over and "accent" or (c.tag and tagColor[c.tag]) or "text"
        if c.odds then col = over and "accent" or "radio" end
        for li, line in ipairs(wl) do
            self:line(line, pad + 8, y + 10 + (li - 1) * lhC, col, fm, done and 1 or 0.5)
        end
        local index = c.index
        self:hit(pad - 12, y, textW + 24, h, function()
            if not done then self.shownAt = 0; return end
            self:choose(index)
        end)
        y = y + h + 6
    end
    if not v.radio then
        self:textRight("[Esc] walk away", W - pad, H - lhS - 12, "dim", fs)
    end
end

function DDSDialogue:onKeyPress(key)
end

function Dlg.show(view)
    if Dlg.instance == nil then
        Dlg.instance = DDSDialogue:new()
        Dlg.instance:initialise()
        Dlg.instance:addToUIManager()
        Dlg.instance:setAlwaysOnTop(true)
    end
    local A = DDS.Audio
    if A then
        -- Key up once per radio conversation, then each line's voice if generated.
        if view.radio and Dlg.radioSession ~= view.sessionId then
            Dlg.radioSession = view.sessionId
            A.radioOpen()
        end
        A.voice(view.voice)
    end
    Dlg.instance:setView(view)
    Dlg.instance:setVisible(true)
    Dlg.instance:bringToTop()
end

function Dlg.close(fromServer)
    if Dlg.instance then
        Dlg.instance:setVisible(false)
        Dlg.instance.view = nil
    end
    if DDS.Audio then
        if Dlg.radioSession then DDS.Audio.radioClose() else DDS.Audio.stopVoice() end
    end
    Dlg.radioSession = nil
    if not fromServer then C.send("dialogueCancel", {}) end
end

Events.OnKeyPressed.Add(function(key)
    local d = Dlg.instance
    if d == nil or not d:isVisible() or d.view == nil then return end
    -- Mouse only for choices: number keys are hotbar slots and Enter opens chat.
    if key == Keyboard.KEY_ESCAPE and not d.view.radio then Dlg.close(false) end
end)

return Dlg
