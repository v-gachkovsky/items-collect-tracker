local ADDON, ns = ...
_G.ItemsCollectTracker = ns

local L = ns.L
local U = ns.util

local PREFIX = "|cff7fd4ffItemsCollectTracker|r: "
function ns.Print(text, ...) print(PREFIX .. string.format(L[text], ...)) end

ns.defaults = {
    locale = "enUS",          -- language of the addon's texts (Locale.lua)
    -- The bar
    locked = false,
    hidden = false,           -- /ic hide
    point = nil,              -- { "TOPLEFT", "CENTER", x, y }: its top left corner from the screen's center
    iconSize = 36,
    spacing = 6,
    columns = 10,             -- items in a row before the next row starts
    background = 0,           -- opacity of a dark backdrop behind the bar (0 = none)
    alpha = 1,                -- opacity of the bar while the mouse isn't over it
    plusButton = "hover",     -- "always" / "hover": the + shows only under the mouse (always on an empty bar)
    dimMissing = true,        -- items you have none of are greyed out
    includeBank = false,
    hideInCombat = false,
    -- The number
    text = {
        position = "below",   -- "above", "below", "center", "bottomright", "top"
        format = "count",     -- U.FormatCount
        font = "Fonts\\FRIZQT__.TTF",
        size = 18,
        outline = "THICKOUTLINE",
        color = { 1, 1, 1, 1 },
        doneColor = { 0.25, 1, 0.25, 1 },
    },
    -- When a goal is reached
    sound = true,
    soundName = "IG_QUEST_LIST_COMPLETE",
    chat = true,
    customSounds = {},        -- { name = "coins", path = "Interface\\ItemsCollectTrackerSounds\\coins.ogg" }
    -- The click that takes an item off the bar
    removeMods = "ctrl",
    removeButton = "LeftButton",
    -- [itemID] = name: items seen in bags, links and tooltips, for the suggestions
    known = {},
}

ns.charDefaults = {
    items = {},               -- { id = 2589, goal = 20, name = "Linen Cloth" }, in bar order
}

-- Fills missing keys from the defaults. Tables with values in the defaults are filled key by key; empty ones
-- (lists such as known items or custom sounds) are kept as they are.
local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            if next(v) and #v == 0 then CopyDefaults(v, dst[k]) end
            if #v > 0 and #dst[k] == 0 then for i, x in ipairs(v) do dst[k][i] = x end end
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

-- Every setting back to the defaults. The language, the items on the bar and the remembered names stay.
function ns.ResetSettings()
    local keep = { locale = ns.db.locale, known = ns.db.known, customSounds = ns.db.customSounds }
    wipe(ns.db)
    for k, v in pairs(keep) do ns.db[k] = v end
    CopyDefaults(ns.defaults, ns.db)
    ns.ApplyAll()
end

------------------------------------------------------------------------
-- Game API that differs between clients
------------------------------------------------------------------------
local IsSecret = issecretvalue or function() return false end
local GetCount = (C_Item and C_Item.GetItemCount) or GetItemCount
local NameByID = C_Item and C_Item.GetItemNameByID
local InfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local Info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local QualityByID = C_Item and C_Item.GetItemQualityByID

ns.QUESTION_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- How many you have: bags (and the bank when set). Nil when the game won't say (a secret value in combat):
-- the bar keeps the last number then.
function ns.Count(id)
    local ok, n = pcall(GetCount, id, ns.db.includeBank, false)
    if ok and type(n) == "number" and not IsSecret(n) then return n end
end

-- Whether the client knows an item with this ID.
function ns.ItemExists(id)
    return id and InfoInstant(id) ~= nil
end

function ns.ItemIcon(id)
    local icon = select(5, InfoInstant(id))
    return icon or ns.QUESTION_ICON
end

-- The name, or nil while the game is still loading it (it asks the server; GET_ITEM_INFO_RECEIVED follows).
function ns.ItemName(id)
    local name = NameByID and NameByID(id) or Info(id)
    return name
end

function ns.ItemQuality(id)
    if QualityByID then return QualityByID(id) end
    return select(3, Info(id))
end

function ns.ItemStackSize(id)
    return select(8, Info(id))
end

-- "|cff1eff00Name|r" in the item's quality color.
function ns.ColoredName(id, name)
    name = name or ns.ItemName(id) or ("#" .. id)
    local q = ns.ItemQuality(id)
    local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    return c and (c.hex .. name .. "|r") or name
end

------------------------------------------------------------------------
-- The collection: items on the bar, their counts and goals
------------------------------------------------------------------------
ns.counts = {}   -- [id] = last count read
local reached = {} -- [id] = the goal was reached at the last count
local primed = false -- the first count after login sets the state without sounds

function ns.Items() return ns.char.items end

function ns.FindItem(id)
    for i, item in ipairs(ns.char.items) do
        if item.id == id then return item, i end
    end
end

function ns.PlayGoalSound()
    if ns.db.sound then ns.PlaySound(ns.db.soundName) end
end

-- Reads every count; plays the sound for goals reached since the last count.
function ns.Refresh()
    if not ns.char then return end
    for _, item in ipairs(ns.char.items) do
        local n = ns.Count(item.id)
        if n then
            ns.counts[item.id] = n
            local done = U.Reached(n, item.goal)
            if done and reached[item.id] == false and primed then
                ns.PlayGoalSound()
                if ns.db.chat then
                    ns.Print("goal reached: %s x%d.", ns.ColoredName(item.id, item.name), item.goal)
                end
            end
            reached[item.id] = done
        end
        if not item.name then item.name = ns.ItemName(item.id) end
    end
    primed = true
    if ns.bar then ns.bar:Update() end
end

-- Counts change in bursts (looting, stacking): one refresh for the burst.
local refreshQueued
function ns.QueueRefresh()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0.1, function()
        refreshQueued = false
        ns.Refresh()
    end)
end

-- Adds an item, or changes its goal when it's on the bar already. A goal reached already doesn't play a sound.
function ns.SetItem(id, goal)
    goal = math.max(0, math.floor(tonumber(goal) or 0))
    local item = ns.FindItem(id)
    if item then
        item.goal = goal
    else
        item = { id = id, goal = goal, name = ns.ItemName(id) }
        table.insert(ns.char.items, item)
        if item.name then ns.db.known[id] = item.name end
    end
    local n = ns.Count(id) or ns.counts[id] or 0
    ns.counts[id] = n
    reached[id] = U.Reached(n, goal)
    ns.Refresh()
end

function ns.RemoveItem(id)
    local item, i = ns.FindItem(id)
    if not item then return end
    table.remove(ns.char.items, i)
    reached[id], ns.counts[id] = nil, nil
    ns.Print("removed %s.", ns.ColoredName(id, item.name))
    if ns.bar then ns.bar:Update() end
end

-- Moves an item one place left (-1) or right (+1).
function ns.MoveItem(id, delta)
    local items = ns.char.items
    local _, i = ns.FindItem(id)
    local j = i and i + delta
    if not j or j < 1 or j > #items then return end
    items[i], items[j] = items[j], items[i]
    if ns.bar then ns.bar:Update() end
end

-- Settings changed: the bar and the open windows follow.
function ns.ApplyAll()
    if ns.bar then ns.bar:ApplySettings() end
    ns.Refresh()
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local events = CreateFrame("Frame")
local handlers = {}
function ns.On(event, fn)
    handlers[event] = handlers[event] or {}
    table.insert(handlers[event], fn)
    pcall(events.RegisterEvent, events, event) -- an event a client doesn't have is left out
end
events:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event] or {}) do fn(...) end
end)

ns.On("ADDON_LOADED", function(name)
    if name ~= ADDON then return end
    ItemsCollectTrackerDB = ItemsCollectTrackerDB or {}
    ItemsCollectTrackerCharDB = ItemsCollectTrackerCharDB or {}
    ns.db, ns.char = ItemsCollectTrackerDB, ItemsCollectTrackerCharDB
    CopyDefaults(ns.defaults, ns.db)
    CopyDefaults(ns.charDefaults, ns.char)
end)

ns.On("PLAYER_LOGIN", function()
    ns.bar = ns.CreateBar()
    ns.InitOptions()
    ns.search.Init()
    ns.ApplyAll()
end)

for _, e in ipairs({ "BAG_UPDATE_DELAYED", "BAG_UPDATE", "PLAYERBANKSLOTS_CHANGED", "BANKFRAME_OPENED",
    "BANKFRAME_CLOSED", "PLAYER_ENTERING_WORLD" }) do
    ns.On(e, ns.QueueRefresh)
end

-- A name or an icon the game was still loading.
ns.On("GET_ITEM_INFO_RECEIVED", function(id)
    if id and ns.char and ns.FindItem(id) then ns.QueueRefresh() end
end)

ns.On("PLAYER_REGEN_DISABLED", function() if ns.bar then ns.bar:UpdateVisibility(true) end end)
ns.On("PLAYER_REGEN_ENABLED", function() if ns.bar then ns.bar:UpdateVisibility(false) end end)

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
local function Help()
    ns.Print("commands:")
    print("  /ic - " .. L["settings"])
    print("  /ic add [" .. L["item"] .. "] - " .. L["add an item"])
    print("  /ic lock, /ic unlock - " .. L["lock or unlock the bar"])
    print("  /ic show, /ic hide - " .. L["show or hide the bar"])
    print("  /ic reset - " .. L["put the bar back in the middle of the screen"])
end

SLASH_ITEMSCOLLECTTRACKER1 = "/ic"
SLASH_ITEMSCOLLECTTRACKER2 = "/itemscollecttracker"
SlashCmdList.ITEMSCOLLECTTRACKER = function(msg)
    local cmd, rest = U.Trim(msg):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "" or cmd == "config" or cmd == "options" then
        ns.ToggleOptions()
    elseif cmd == "add" then
        ns.db.hidden = false
        ns.ApplyAll()
        ns.dialog:OpenAdd(ns.bar.plus, rest ~= "" and rest or nil)
    elseif cmd == "lock" or cmd == "unlock" then
        ns.db.locked = cmd == "lock"
        ns.Print(ns.db.locked and "bar locked." or "bar unlocked: drag an item to move it, the corner to resize.")
        ns.ApplyAll()
    elseif cmd == "show" or cmd == "hide" then
        ns.db.hidden = cmd == "hide"
        ns.ApplyAll()
    elseif cmd == "reset" then
        ns.db.point = nil
        ns.db.hidden = false
        ns.ApplyAll()
    else
        Help()
    end
end
