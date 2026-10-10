-- Client: holds the last view the server sent, routes server messages to the
-- UI, and turns right-clicks near objectives into story interactions.

require "DeadDaysStory/DDS_Core"
require "TimedActions/ISBaseTimedAction"

DDS.Client = DDS.Client or { view = nil, toasts = {}, helloSent = false }
local C = DDS.Client

C.KEY = Keyboard.KEY_J

function C.send(command, args)
    DDS.Net.toServer(command, args or {})
end

function C.playerXY()
    local p = getPlayer()
    if p == nil then return 0, 0, 0 end
    return p:getX(), p:getY(), p:getZ()
end

function C.distanceTo(x, y)
    local px, py = C.playerXY()
    return DDS.dist(px, py, x, y), DDS.compass(x - px, y - py)
end

function C.trackedQuest()
    local v = C.view
    if v == nil then return nil end
    for _, q in ipairs(v.active or {}) do
        if q.id == v.tracked then return q end
    end
    return (v.active or {})[1]
end

function C.nextObjective(q)
    if q == nil then return nil end
    for _, o in ipairs(q.objectives or {}) do
        if not o.done and not o.optional then return o end
    end
    for _, o in ipairs(q.objectives or {}) do
        if not o.done then return o end
    end
    return nil
end

---------------------------------------------------------------------------
-- Server messages
---------------------------------------------------------------------------

local On = DDS.Net.onClient

On("sync", function(view)
    C.view = view
    if DDS.UI and DDS.UI.Journal and DDS.UI.Journal.instance then DDS.UI.Journal.instance:onSync() end
end)

On("toast", function(args)
    if DDS.UI and DDS.UI.Toast then DDS.UI.Toast.push(args.text, args.tone) end
    if args.tone == "radio" and DDS.Audio then
        DDS.Audio.incomingCall()
    elseif args.tone == "act" or args.tone == "twist" then
        pcall(function() getSoundManager():playUISound("UIActivateMainMenuItem") end)
    end
end)

On("dialogue", function(view)
    if DDS.UI and DDS.UI.Dialogue then DDS.UI.Dialogue.show(view) end
end)

On("dialogueClose", function()
    if DDS.UI and DDS.UI.Dialogue then DDS.UI.Dialogue.close(true) end
end)

---------------------------------------------------------------------------
-- Startup and keys
---------------------------------------------------------------------------

local function hello()
    if C.helloSent then return end
    if getPlayer() == nil then return end
    C.helloSent = true
    C.send("hello", {})
end

Events.OnGameStart.Add(function()
    C.helloSent = false
    C.startTicks = 0
end)

Events.OnTick.Add(function()
    if C.helloSent then return end
    C.startTicks = (C.startTicks or 0) + 1
    if C.startTicks > 90 then hello() end
end)

Events.OnKeyPressed.Add(function(key)
    if key == C.KEY and getPlayer() ~= nil then
        if DDS.UI and DDS.UI.Dialogue and DDS.UI.Dialogue.instance and DDS.UI.Dialogue.instance:isVisible() then return end
        if DDS.UI and DDS.UI.Journal then DDS.UI.Journal.toggle() end
    end
end)

---------------------------------------------------------------------------
-- Timed action for story interactions
---------------------------------------------------------------------------

DDSInteractAction = ISBaseTimedAction:derive("DDSInteractAction")

function DDSInteractAction:isValid()
    return self.character ~= nil and not self.character:isDead()
end

function DDSInteractAction:waitToStart()
    self.character:faceLocation(self.tx, self.ty)
    return self.character:shouldBeTurning()
end

function DDSInteractAction:update()
    self.character:faceLocation(self.tx, self.ty)
end

function DDSInteractAction:start()
    self:setActionAnim(self.anim or "Loot")
end

function DDSInteractAction:stop()
    ISBaseTimedAction.stop(self)
end

function DDSInteractAction:perform()
    C.send("interact", self.args)
    ISBaseTimedAction.perform(self)
end

function DDSInteractAction:new(character, duration, tx, ty, args, anim)
    local o = ISBaseTimedAction.new(self, character)
    o.maxTime = duration or 60
    o.tx, o.ty = tx, ty
    o.args = args
    o.anim = anim
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end

function C.doInteract(questId, index, point, duration, method, anim)
    local player = getPlayer()
    if player == nil then return end
    if luautils and luautils.walkAdj and point then
        local sq = getCell():getGridSquare(math.floor(point.x), math.floor(point.y), math.floor(point.z or 0))
        if sq and DDS.dist(player:getX(), player:getY(), point.x, point.y) > 1.6 then luautils.walkAdj(player, sq, true) end
    end
    ISTimedActionQueue.add(DDSInteractAction:new(player, duration, point.x, point.y,
        { questId = questId, index = index, method = method }, anim))
end

---------------------------------------------------------------------------
-- Right-click near an objective
---------------------------------------------------------------------------

local lockMethods = {
    pick = { label = "Pick the lock (screwdriver or paperclip)", duration = 180, anim = "Loot" },
    pry = { label = "Pry it open with a crowbar (loud)", duration = 90, anim = "Loot" },
    key = { label = "Use the key", duration = 30, anim = "Loot" },
}

Events.OnFillWorldObjectContextMenu.Add(function(playerNum, context, worldobjects, test)
    if test then return end
    local v = C.view
    if v == nil then return end
    local px, py = C.playerXY()
    for _, q in ipairs(v.active or {}) do
        for _, o in ipairs(q.objectives or {}) do
            local it = o.interact
            if it and not o.done and DDS.dist(px, py, it.x, it.y) <= 4.5 then
                if o.kind == "lock" then
                    local root = context:addOption(it.label)
                    local sub = ISContextMenu:getNew(context)
                    context:addSubMenu(root, sub)
                    for _, m in ipairs(it.methods or { "pick", "pry" }) do
                        local spec = lockMethods[m]
                        sub:addOption(spec.label, nil, function()
                            C.doInteract(q.id, o.index, it, spec.duration, m, spec.anim)
                        end)
                    end
                elseif o.kind == "talk" or o.kind == "handin" then
                    context:addOption(it.label, nil, function()
                        C.doInteract(q.id, o.index, it, 15, nil, "Loot")
                    end)
                else
                    context:addOption(it.label, nil, function()
                        C.doInteract(q.id, o.index, it, it.duration or 60, nil, "Loot")
                    end)
                end
            end
        end
    end
end)

return C
