-- The journal (J). One window, seven tabs, everything one click deep.

require "DeadDaysStory/DDS_UI_Base"
require "DeadDaysStory/DDS_Client"

local UI = DDS.UI
local C = DDS.Client

UI.Journal = UI.Journal or {}
local J = UI.Journal

DDSJournal = DDSPanel:derive("DDSJournal")

-- All spacing lives here. Tweak these to resize the whole journal.
J.L = {
    maxW = 1280, maxH = 840, margin = 60,     -- window size cap and screen margin
    header = 58,                              -- title bar height
    navW = 220, navItemH = 44, navGap = 6,    -- left navigation
    pad = 28,                                 -- content padding
    listW = 360, listGap = 12, itemPad = 16,  -- mission list column
    detailGap = 36,                           -- space between list and detail
    section = 26,                             -- space before a section title
    row = 42, rowGap = 8,                     -- story chapter rows
    button = 36,                              -- button height
}
local L = J.L

J.tabs = {
    { id = "story", label = "Story" },
    { id = "missions", label = "Missions" },
    { id = "leads", label = "Leads" },
    { id = "daily", label = "Daily Ops" },
    { id = "buddies", label = "Buddies" },
    { id = "factions", label = "Factions" },
    { id = "log", label = "Log" },
}

local stateLabel = { available = "OPEN", claimed = "IN PROGRESS", done = "DONE", locked = "LOCKED", failed = "FAILED" }
local stateColor = { available = "accent", claimed = "radio", done = "good", locked = "dim", failed = "bad" }

function DDSJournal:new()
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local w, h = math.min(L.maxW, sw - L.margin * 2), math.min(L.maxH, sh - L.margin * 2)
    local o = DDSPanel.new(self, (sw - w) / 2, (sh - h) / 2, w, h)
    o.tab = "story"
    o.selected = {}
    o.scrollY = { list = 0, detail = 0, page = 0 }
    o.dragOnBody = false
    return o
end

function DDSJournal:onSync() end

function DDSJournal:listFor(tab)
    local v = C.view or {}
    local list = {}
    if tab == "missions" then
        for _, q in ipairs(v.active or {}) do if q.arc ~= "daily" then list[#list + 1] = q end end
    elseif tab == "leads" then
        for _, q in ipairs(v.offered or {}) do if q.arc ~= "daily" then list[#list + 1] = q end end
    elseif tab == "daily" then
        for _, q in ipairs(v.active or {}) do if q.arc == "daily" then list[#list + 1] = q end end
        for _, q in ipairs(v.offered or {}) do if q.arc == "daily" then list[#list + 1] = q end end
    end
    return list
end

function DDSJournal:onMouseWheel(del)
    local mx = self:getMouseX()
    local key = "page"
    if self.tab == "missions" or self.tab == "leads" or self.tab == "daily" then
        key = mx < (self.listX or 0) + (self.listW or 0) and "list" or "detail"
    end
    self.scrollY[key] = math.max(0, (self.scrollY[key] or 0) + del * 48)
    return true
end

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------

function DDSJournal:render()
    self.hits = {}
    local v = C.view
    local W, H = self.width, self.height
    local fs, fm, fl = UIFont.Small, UIFont.Medium, UIFont.Large
    self:fill(0, 0, W, H, "bg", 0.96)
    self:border(0, 0, W, H, "line")

    -- Header (drag handle).
    local hh = L.header
    self:fill(0, 0, W, hh, "panel", 1)
    self:fill(0, hh, W, 1, "line")
    local ty = (hh - UI.fontH(fm)) / 2
    self:text("DEAD DAYS", L.pad, ty, "accent", fm)
    local sagaTitle = v and v.saga and v.saga.title or "..."
    self:text(sagaTitle, L.pad + UI.textW(fm, "DEAD DAYS") + 20, ty + 2, "text", fm)
    local right = v and ("Day " .. tostring(v.day) .. (v.saga and ("   |   Act " .. v.saga.act .. ": " .. v.saga.actTitle) or "")) or ""
    self:textRight(right, W - 70, ty + 2, "muted", fs)
    self:button("X", W - 50, (hh - 32) / 2, 32, 32, function() J.close() end)
    self:hit(0, 0, W - 80, hh, function()
        self.dragging = true
        self:setCapture(true)
    end)

    if v == nil then
        self:textCentre("Waiting for the story server...", W / 2, H / 2, "muted", fm)
        return
    end

    -- Navigation.
    local navW = L.navW
    self:fill(0, hh + 1, navW, H - hh - 1, "panel", 0.6)
    self:fill(navW, hh + 1, 1, H - hh - 1, "line", 0.6)
    local ny = hh + 18
    for _, t in ipairs(J.tabs) do
        local count = 0
        if t.id == "missions" or t.id == "leads" or t.id == "daily" then count = #self:listFor(t.id) end
        local active = self.tab == t.id
        local over = self:hover(0, ny, navW, L.navItemH)
        if active then self:fill(0, ny, navW, L.navItemH, "panelHi"); self:fill(0, ny, 4, L.navItemH, "accent") end
        local ly = ny + (L.navItemH - UI.fontH(fm)) / 2
        self:text(t.label, L.pad, ly, active and "accent" or (over and "text" or "muted"), fm)
        if count > 0 then self:textRight(tostring(count), navW - 20, ly + 2, t.id == "leads" and "accent" or "muted", fs) end
        local id = t.id
        self:hit(0, ny, navW, L.navItemH, function() self.tab = id; self.scrollY = { list = 0, detail = 0, page = 0 } end)
        ny = ny + L.navItemH + L.navGap
    end
    self:text(v.alife and "A-Life: online" or "A-Life: offline (fallback)", L.pad, H - 36, v.alife and "dim" or "bad", fs)

    -- Content area.
    local cx, cy = navW + L.pad, hh + L.pad
    local cw, ch = W - navW - L.pad * 2, H - hh - L.pad * 2
    if v.calls and #v.calls > 0 then
        local call = v.calls[1]
        local bh = 60
        self:fill(cx, cy, cw, bh, "panelHi")
        self:fill(cx, cy, 4, bh, "radio")
        local blink = math.floor(getTimestampMs() / 600) % 2 == 0
        self:text("INCOMING RADIO", cx + 20, cy + 10, blink and "radio" or "muted", fs)
        self:text(call.from .. (#v.calls > 1 and ("   (+" .. (#v.calls - 1) .. " more)") or ""), cx + 20, cy + 12 + UI.fontH(fs), "text", fm)
        local callId = call.id
        self:button("Answer", cx + cw - 140, cy + (bh - L.button) / 2, 120, L.button, function()
            C.send("answer", { id = callId })
            J.close()
        end, "primary")
        cy = cy + bh + L.pad
        ch = ch - bh - L.pad
    end
    self.cx, self.cy, self.cw, self.ch = cx, cy, cw, ch

    self:setStencilRect(cx - 8, cy - 8, cw + 16, ch + 16)
    local ok, err = pcall(function()
        if self.tab == "story" then self:renderStory(v)
        elseif self.tab == "missions" or self.tab == "leads" or self.tab == "daily" then self:renderQuests(v)
        elseif self.tab == "buddies" then self:renderBuddies(v)
        elseif self.tab == "factions" then self:renderFactions(v)
        elseif self.tab == "log" then self:renderLog(v) end
    end)
    self:clearStencilRect()
    if not ok then self:text("UI error: " .. tostring(err), cx, cy, "bad", fs) end
end

function DDSJournal:sectionTitle(text, x, y)
    self:text(string.upper(text), x, y, "accent", UIFont.Small)
    self:fill(x, y + UI.fontH(UIFont.Small) + 6, self.cw, 1, "line", 0.6)
    return y + UI.fontH(UIFont.Small) + 16
end

---------------------------------------------------------------------------
-- Story
---------------------------------------------------------------------------

function DDSJournal:renderStory(v)
    local s = v.saga
    local fs, fm, fl = UIFont.Small, UIFont.Medium, UIFont.Large
    local x, w = self.cx, self.cw
    local y = self.cy - self.scrollY.page
    if s == nil then self:text("The story hasn't started yet.", x, y, "muted", fm); return end
    if s.ended then
        self:text("THE END", x, y, "accent", fl); y = y + UI.fontH(fl) + 12
        y = y + self:para(s.epilogue or "", x, y, w, "text", fm, 6) + 16
        self:text("A new story begins soon.", x, y, "muted", fm)
        return
    end
    self:text("ACT " .. s.act .. "  -  " .. string.upper(s.actTitle), x, y, "accent", fl)
    y = y + UI.fontH(fl) + 12
    y = y + self:para(s.actBlurb, x, y, math.min(w, 860), "text", fm, 6) + 18
    if s.progress and s.progress.all > 0 then
        self:text(string.format("Main story: %d of %d chapters", s.progress.done, s.progress.all), x, y, "muted", fs)
        self:bar(x + 240, y + 6, w - 240, 8, s.progress.done / s.progress.all, "accent")
        y = y + UI.fontH(fs) + L.section
    end

    y = self:sectionTitle("Storylines this act", x, y)
    for _, c in ipairs(s.chapters or {}) do
        local col = stateColor[c.state] or "muted"
        local rh = L.row
        local ry = y + (rh - UI.fontH(fs)) / 2
        self:fill(x, y, w, rh, "panel", 0.85)
        self:fill(x, y, 4, rh, col)
        self:text(c.line, x + 20, ry, "muted", fs)
        self:text(c.title .. (c.finale and "   (finale)" or ""), x + 220, ry - 1, c.state == "locked" and "dim" or "text", fm)
        local st = stateLabel[c.state] or c.state
        if c.state == "claimed" and c.owner then st = "IN PROGRESS: " .. c.owner end
        self:textRight(st, x + w - 20, ry, col, fs)
        y = y + rh + L.rowGap
    end
    y = y + L.section

    y = self:sectionTitle("People", x, y)
    local gap = 16
    local colW = math.floor((w - gap) / 2)
    local cardH = 66
    for i, c in ipairs(s.cast or {}) do
        local col = (i - 1) % 2
        local cxp = x + col * (colW + gap)
        local statusCol = (c.status == "dead") and "bad" or ((c.status == "alive" or c.status == "free" or c.status == "home") and "good" or "accent")
        self:fill(cxp, y, colW, cardH, "panel", 0.85)
        self:text(c.name, cxp + 18, y + 12, c.met and "text" or "muted", fm)
        self:text(c.role, cxp + 18, y + 16 + UI.fontH(fm), "muted", fs)
        self:textRight(string.upper(c.status or ""), cxp + colW - 18, y + 14, statusCol, fs)
        if col == 1 or i == #s.cast then y = y + cardH + gap end
    end
    y = y + L.section - gap

    y = self:sectionTitle("Who holds " .. (s.town or "the county"), x, y)
    for _, role in ipairs({ "community", "military", "antagonist", "wildcard" }) do
        local name = s.roles and s.roles[role] or role
        local val = s.power and s.power[role] or 50
        self:text(name, x, y, "text", fm)
        self:bar(x + 320, y + 8, w - 380, 8, val / 100, role == "antagonist" and "bad" or (role == "military" and "radio" or (role == "community" and "good" or "twist")))
        self:textRight(tostring(val), x + w, y + 2, "muted", fs)
        y = y + UI.fontH(fm) + 14
    end
    y = y + L.section

    y = self:sectionTitle("Chronicle", x, y)
    for _, e in ipairs(s.chronicle or {}) do
        local col = e.kind == "twist" and "twist" or (e.kind == "act" and "accent" or (e.kind == "loss" and "bad" or "text"))
        self:text("Day " .. tostring(e.day), x, y + 2, "dim", fs)
        y = y + self:para(e.text, x + 80, y, w - 80, col, fm, 4) + 12
    end
end

---------------------------------------------------------------------------
-- Missions / Leads / Daily
---------------------------------------------------------------------------

function DDSJournal:renderQuests(v)
    local fs, fm, fl = UIFont.Small, UIFont.Medium, UIFont.Large
    local list = self:listFor(self.tab)
    local x, y, w = self.cx, self.cy, self.cw
    local listW = L.listW
    self.listX, self.listW = x, listW

    if self.tab == "daily" and v.daily then
        self:text(string.format("Today: %d done      Streak: %d day%s%s", v.daily.done or 0, v.daily.streak or 0,
            (v.daily.streak == 1) and "" or "s", (v.daily.streak or 0) >= 3 and "   (bonus XP active)" or ""), x, y, "muted", fm)
        y = y + UI.fontH(fm) + 20
    end

    if #list == 0 then
        local empty = { missions = "No active missions. Check Leads, or answer the radio.",
            leads = "No leads right now. The radio will crackle soon enough.",
            daily = "Daily ops post every morning at 6:00." }
        self:text(empty[self.tab] or "", x, y + 10, "muted", fm)
        return
    end

    local selId = self.selected[self.tab]
    local sel
    for _, q in ipairs(list) do if q.id == selId then sel = q end end
    if sel == nil then sel = list[1]; self.selected[self.tab] = sel.id end

    -- List column.
    local ly = y - self.scrollY.list
    local ip = L.itemPad
    for _, q in ipairs(list) do
        local isSel = q.id == sel.id
        local lines = UI.wrap(q.title, fm, listW - ip * 2)
        local h = ip + UI.fontH(fs) + 6 + #lines * (UI.fontH(fm) + 2) + ip
        local over = self:hover(x, ly, listW, h)
        self:fill(x, ly, listW, h, isSel and "panelHi" or "panel", (isSel or over) and 1 or 0.75)
        self:fill(x, ly, 4, h, UI.arcColor[q.arc] or "accent")
        self:text(UI.arcLabel[q.arc] or "", x + ip + 4, ly + ip, UI.arcColor[q.arc] or "accent", fs)
        local meta = q.hoursLeft and (q.hoursLeft .. "h left") or (q.offerLeft and (q.offerLeft .. "h") or "")
        if q.party then meta = "SHARED   " .. meta end
        if q.id == v.tracked then meta = "TRACKED   " .. meta end
        self:textRight(meta, x + listW - ip, ly + ip, "muted", fs)
        local ty = ly + ip + UI.fontH(fs) + 6
        for _, line in ipairs(lines) do self:line(line, x + ip + 4, ty, isSel and "text" or "muted", fm); ty = ty + UI.fontH(fm) + 2 end
        local id = q.id
        self:hit(x, ly, listW, h, function() self.selected[self.tab] = id; self.scrollY.detail = 0 end)
        ly = ly + h + L.listGap
    end

    -- Detail column.
    local dx = x + listW + L.detailGap
    local dw = w - listW - L.detailGap
    local dy = y - self.scrollY.detail
    self:text(UI.arcLabel[sel.arc] or "", dx, dy, UI.arcColor[sel.arc] or "accent", fs)
    local riskX = dx + UI.textW(fs, UI.arcLabel[sel.arc] or "") + 20
    self:text("Risk", riskX, dy, "dim", fs)
    for i = 1, 5 do
        self:fill(riskX + 44 + (i - 1) * 16, dy + 4, 10, 10, i <= (sel.risk or 1) and ((sel.risk or 1) >= 4 and "bad" or "accent") or "panelHi")
    end
    dy = dy + UI.fontH(fs) + 10
    dy = dy + self:para(sel.title, dx, dy, dw, "text", fl, 4) + 10
    if sel.giver then self:text("From: " .. sel.giver, dx, dy, "muted", fm); dy = dy + UI.fontH(fm) + 6 end
    if sel.party then
        local who = sel.shared and ("   (started by " .. tostring(sel.owner) .. ")") or ""
        self:text("Shared with " .. sel.party .. who, dx, dy, "radio", fm)
        dy = dy + UI.fontH(fm) + 6
    end
    if sel.site and sel.site.name then
        local d, dir = C.distanceTo(sel.site.x, sel.site.y)
        self:text(sel.site.name .. string.format("   (%dm %s)", math.floor(d), dir), dx, dy, "radio", fm)
        dy = dy + UI.fontH(fm) + 6
    end
    if sel.requiresBuddy then self:text("PARTNER REQUIRED - bring a buddy", dx, dy, "accent", fm); dy = dy + UI.fontH(fm) + 6 end
    dy = dy + 14
    dy = dy + self:para(sel.summary, dx, dy, dw, "text", fm, 6) + L.section

    if sel.status == "active" then
        if sel.stepTitle then
            self:text(string.upper(sel.stepTitle), dx, dy, "accent", fs)
            dy = dy + UI.fontH(fs) + 12
        end
        for _, o in ipairs(sel.objectives or {}) do
            local box = o.done and "good" or (o.optional and "dim" or "accent")
            self:border(dx, dy + 5, 14, 14, box)
            if o.done then self:fill(dx + 3, dy + 8, 8, 8, "good") end
            local label = o.text .. (o.optional and "   (optional)" or "")
            local th = self:para(label, dx + 28, dy, dw - 28 - 120, o.done and "dim" or "text", fm, 4)
            if o.x and not o.done then
                local d, dir = C.distanceTo(o.x, o.y)
                self:textRight(string.format("%dm %s", math.floor(d), dir), dx + dw, dy + 2, "radio", fs)
            end
            dy = dy + th + 8
            if o.remoteHandIn and not o.done then
                local qid, idx = sel.id, o.index
                self:button("Hand over", dx + 28, dy, 140, L.button - 4, function() C.send("handin", { questId = qid, index = idx }) end, "primary")
                dy = dy + L.button + 6
            end
            if o.radio and not o.done then
                self:text("Waiting on the radio - answer the call above.", dx + 28, dy, "radio", fs)
                dy = dy + UI.fontH(fs) + 8
            end
            if o.interact and not o.done then
                self:text("Right-click at the spot: " .. o.interact.label, dx + 28, dy, "dim", fs)
                dy = dy + UI.fontH(fs) + 8
            end
        end
        dy = dy + L.section
    end

    if sel.rewards and #sel.rewards > 0 then
        self:text("REWARD", dx, dy, "accent", fs); dy = dy + UI.fontH(fs) + 8
        dy = dy + self:para(table.concat(sel.rewards, ", "), dx, dy, dw, "muted", fm, 4) + L.section
    end
    if sel.log and #sel.log > 0 and sel.status == "active" then
        self:text("SO FAR", dx, dy, "accent", fs); dy = dy + UI.fontH(fs) + 8
        for _, line in ipairs(sel.log) do dy = dy + self:para("-  " .. line, dx, dy, dw, "dim", fs, 4) + 2 end
        dy = dy + L.section
    end

    local by = math.max(dy, self.cy + 10)
    local id = sel.id
    local bw = 150
    if sel.status == "offered" then
        self:button("Accept", dx, by, bw, L.button, function() C.send("accept", { id = id }) end, "primary")
        if sel.arc ~= "spine" then
            self:button("Decline", dx + bw + 14, by, bw, L.button, function() C.send("decline", { id = id }) end)
        end
    elseif sel.status == "taken" then
        self:text("Someone else has taken point on this one.", dx, by, "muted", fm)
    elseif sel.status == "active" then
        local tracked = v.tracked == id
        self:button(tracked and "Tracking" or "Track", dx, by, bw, L.button, function() C.send("track", { id = id }) end, tracked and "normal" or "primary")
        if not sel.shared then
            self:button(sel.arc == "spine" and "Step back" or "Abandon", dx + bw + 14, by, bw, L.button, function()
                C.send("abandon", { id = id })
            end, "danger")
        end
    end
end

---------------------------------------------------------------------------
-- Buddies
---------------------------------------------------------------------------

function DDSJournal:renderBuddies(v)
    local fs, fm = UIFont.Small, UIFont.Medium
    local x, w = self.cx, self.cw
    local y = self.cy - self.scrollY.page
    local list = v.buddies or {}
    if #list == 0 then
        local where = v.saga and v.saga.settlement or "the settlement"
        self:para("No one rides with you yet. Help " .. where .. " and they'll send someone. People you rescue may offer to come along too.",
            x, y, math.min(w, 820), "muted", fm, 6)
        return
    end
    y = y + self:para("Buddies follow you, fight beside you and remember what you do. Missions marked PARTNER REQUIRED need one along. Loyalty unlocks their personal story.",
        x, y, math.min(w, 860), "dim", fm, 4) + L.section
    local p = 22
    for _, b in ipairs(list) do
        local gone = b.status == "dead" or b.status == "left"
        local bioLines = #UI.wrap(b.bio or "", fs, w - p * 2)
        local cardH = p + UI.fontH(fm) + 6 + UI.fontH(fs) + 16 + UI.fontH(fs) + 12 + bioLines * (UI.fontH(fs) + 4) + 10
            + UI.fontH(fs) + 18 + (gone and 0 or (L.button + 4)) + p
        self:fill(x, y, w, cardH, b.active and "panelHi" or "panel", gone and 0.5 or 0.92)
        self:fill(x, y, 4, cardH, gone and "bad" or (b.active and "accent" or "line"))
        local cy = y + p
        self:text(b.name, x + p, cy, gone and "dim" or "text", fm)
        local st = string.upper(b.status or "")
        if b.active and not gone then st = "ACTIVE  -  " .. st end
        self:textRight(st, x + w - p, cy + 2, gone and "bad" or (b.active and "accent" or "muted"), fs)
        cy = cy + UI.fontH(fm) + 6
        self:text(b.role .. "   |   " .. b.personality, x + p, cy, "muted", fs)
        cy = cy + UI.fontH(fs) + 16
        self:text("Loyalty: " .. b.mood, x + p, cy, "text", fs)
        self:bar(x + p + 170, cy + 5, 260, 8, (b.loyalty or 0) / 100, b.loyalty >= 60 and "good" or (b.loyalty >= 25 and "accent" or "bad"))
        self:text(string.format("Story %d/3      Missions %d      Kills %d", b.stage or 0, b.missions or 0, b.kills or 0), x + p + 460, cy, "muted", fs)
        cy = cy + UI.fontH(fs) + 12
        cy = cy + self:para(b.bio or "", x + p, cy, w - p * 2, "dim", fs, 4) + 10
        self:text("Likes: " .. b.likes .. "      Dislikes: " .. b.dislikes .. "      Perk: " .. b.perk, x + p, cy, "muted", fs)
        cy = cy + UI.fontH(fs) + 18
        if not gone then
            local id = b.id
            local bw = 150
            if b.active then
                self:button("Call to me", x + p, cy, bw, L.button, function() C.send("buddy", { op = "call" }) end, b.status ~= "following" and "primary" or "normal")
                self:button("Wait here", x + p + bw + 12, cy, bw, L.button, function() C.send("buddy", { op = "wait" }) end)
                self:button("Send home", x + p + (bw + 12) * 2, cy, bw, L.button, function() C.send("buddy", { op = "dismiss" }) end)
            else
                self:button("Take " .. (b.name:match("^(%S+)") or b.name), x + p, cy, bw + 30, L.button, function() C.send("buddy", { op = "select", id = id }) end, "primary")
            end
        end
        y = y + cardH + 16
    end
end

---------------------------------------------------------------------------
-- Factions
---------------------------------------------------------------------------

function DDSJournal:renderFactions(v)
    local fs, fm = UIFont.Small, UIFont.Medium
    local x, w = self.cx, self.cw
    local y = self.cy - self.scrollY.page
    y = y + self:para("How each group sees you. Standing changes how their people treat you on sight: Hostile and worse shoot first.",
        x, y, math.min(w, 860), "dim", fm, 4) + L.section
    local p = 20
    for _, f in ipairs(v.factions or {}) do
        local h = p * 2 + UI.fontH(fm) + 6 + UI.fontH(fs)
        self:fill(x, y, w, h, "panel", 0.88)
        self:text(f.name, x + p, y + p, "text", fm)
        local sub = (f.role and (string.upper(f.role) .. "   |   ") or "") .. (f.heading or "")
        self:text(sub, x + p, y + p + UI.fontH(fm) + 6, "muted", fs)
        local barW = 260
        local barX = x + w - p - barW - 170
        local mid = barX + barW / 2
        local by = y + h / 2 - 4
        self:fill(barX, by, barW, 8, "panelHi")
        self:fill(mid, by - 5, 1, 18, "line")
        local frac = (f.value or 0) / 100
        local col = f.value >= 20 and "good" or (f.value <= -25 and "bad" or "accent")
        if frac >= 0 then self:fill(mid, by, frac * barW / 2, 8, col)
        else self:fill(mid + frac * barW / 2, by, -frac * barW / 2, 8, col) end
        self:textRight(f.label .. "  (" .. tostring(f.value) .. ")", x + w - p, by - 4, col, fm)
        y = y + h + 12
    end
end

---------------------------------------------------------------------------
-- Log (+ admin tools)
---------------------------------------------------------------------------

function DDSJournal:renderLog(v)
    local fs, fm = UIFont.Small, UIFont.Medium
    local x, w = self.cx, self.cw
    local y = self.cy - self.scrollY.page
    local st = v.stats or {}
    self:text(string.format("Missions done: %d      Failed: %d      Kills: %d      Big choices: %d",
        st.completed or 0, st.failed or 0, st.kills or 0, st.choices or 0), x, y, "muted", fm)
    y = y + UI.fontH(fm) + L.section
    y = self:sectionTitle("Recent", x, y)
    for _, e in ipairs(v.feed or {}) do
        self:text(string.format("Day %d  %02d:00", e.day or 0, e.hour or 0), x, y + 2, "dim", fs)
        y = y + self:para(e.text, x + 130, y, w - 130, UI.tones[e.tone] or "text", fm, 4) + 10
    end
    y = y + L.section
    y = self:sectionTitle("Closed", x, y)
    for _, q in ipairs(v.closed or {}) do
        local col = q.status == "done" and "good" or (q.status == "failed" and "bad" or "dim")
        self:text(string.upper(q.status), x, y + 2, col, fs)
        self:text(q.title, x + 130, y, "muted", fm)
        y = y + UI.fontH(fm) + 8
    end
    if v.admin then
        y = y + L.section
        y = self:sectionTitle("Admin story tools", x, y)
        local ops = {
            { "New lead", "lead" }, { "Unlock act chapters", "unlock" }, { "Advance act", "advance" },
            { "Give buddy", "buddy" }, { "Show secrets", "secrets" }, { "New saga", "newSaga" },
        }
        local bx = x
        for _, op in ipairs(ops) do
            local bw = UI.textW(fs, op[1]) + 40
            if bx + bw > x + w then bx = x; y = y + L.button + 12 end
            local code = op[2]
            self:button(op[1], bx, y, bw, L.button, function() C.send("admin", { op = code }) end, code == "newSaga" and "danger" or "normal")
            bx = bx + bw + 12
        end
    end
end

---------------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------------

function DDSJournal:onMouseDown(x, y)
    DDSPanel.onMouseDown(self, x, y)
    return true
end

function J.open(tab, questId)
    if J.instance == nil then
        J.instance = DDSJournal:new()
        J.instance:initialise()
        J.instance:addToUIManager()
    end
    if tab == "calls" then tab = J.instance.tab or "story" end
    if tab then J.instance.tab = tab end
    if questId then J.instance.selected[tab or "missions"] = questId end
    J.instance:setVisible(true)
    J.instance:bringToTop()
    C.send("requestSync", {})
end

function J.close()
    if J.instance then J.instance:setVisible(false) end
end

function J.toggle(tab)
    if J.instance and J.instance:isVisible() then J.close() else J.open(tab) end
end

return J
