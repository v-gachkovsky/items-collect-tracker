local ADDON, ns = ...
_G.ItemsCollectTracker = ns

local L = ns.L
local U = ns.util

local PREFIX = "|cff7fd4ffItems Collect Tracker|r: "
function ns.Print(text, ...) print(PREFIX .. string.format(L[text], ...)) end

ns.defaults = {
    locale = "enUS",          -- language of the addon's texts (Locale.lua)
    -- The bars
    locked = false,
    hidden = false,           -- /ic hide: every bar
    point = nil,              -- where the first bar of a new character goes (the last place a first bar had)
    iconSize = 36,
    spacing = 6,
    columns = 10,             -- items in a row before the next row starts
    background = 0,           -- opacity of a dark backdrop behind the bar (0 = none)
    alpha = 1,                -- opacity of the bar while the mouse isn't over it
    plusButton = "hover",     -- "always" / "hover": the + shows only under the mouse (always on an empty bar)
    dimMissing = true,        -- items you have none of are greyed out
    hideInCombat = false,
    hideDone = false,         -- items whose goal is reached leave the bar
    minimapButton = true,
    minimapAngle = 200,       -- where on the minimap's edge, in degrees (0 = right, 90 = up)
    minimapIcon = {},         -- LibDBIcon's settings for the button (minimapPos, hide), when another addon brought it
    -- What counts
    includeBank = false,
    countMail = false,        -- with Syndicator
    countAlts = false,        -- with Syndicator: bags, bank and mail of your other characters
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
    progressBar = false,      -- a thin bar along the bottom of the icon
    -- When a goal is reached
    sound = true,
    soundName = "IG_QUEST_LIST_COMPLETE",
    flash = true,             -- the icon flashes
    chat = true,
    customSounds = {},        -- { name = "coins", path = "Interface\\ItemsCollectTrackerSounds\\coins.ogg" }
    -- The click that takes an item off the bar
    removeMods = "ctrl",
    removeButton = "LeftButton",
    -- [itemID] = name: items seen in bags, links and tooltips, for the suggestions
    known = {},
    -- ["Name - Realm"] = { class = "MAGE", items = { { id, goal, name } } }: what each character collects,
    -- to copy it to another one
    lists = {},
}

ns.charDefaults = {
    -- { items = { ... }, point = { "TOPLEFT", "CENTER", x, y } }: the bars, each with its items in order.
    -- An item: { id = 2589, goal = 20, name = "Linen Cloth", start = 60, key = "bk", last = 5 }. start: how many
    -- there were when it was added (only what comes after counts); key: what was counted then (U.SourceKey);
    -- last: the last count, to go on from when what's counted changes.
    bars = {},
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

-- Every setting back to the defaults. The language, the items on the bars and the remembered names stay.
function ns.ResetSettings()
    local keep = { locale = ns.db.locale, known = ns.db.known, customSounds = ns.db.customSounds,
        lists = ns.db.lists }
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

-- How many you have in the bags, or the bags and the banks: on Retail the bank also means the reagent bank
-- and the warband bank (the other clients take no such arguments). Nil when the game won't say (a secret
-- value in combat): the bar keeps the last number then.
local function CountIn(id, bank)
    local ok, n = pcall(GetCount, id, bank, false, bank, bank)
    if ok and type(n) == "number" and not IsSecret(n) then return n end
end

-- Syndicator remembers the bank, the mail and the other characters' bags.
local function Syndicator_()
    local s = _G.Syndicator
    return s and s.API and s.API.GetInventoryInfoByItemID and s
end
function ns.HasSyndicator() return Syndicator_() ~= nil end

-- What counts now, as a short key: "b" bags, "k" bank, "m" mail, "a" other characters.
function ns.SourceKey()
    local syn = ns.HasSyndicator()
    return U.SourceKey(ns.db.includeBank, syn and ns.db.countMail, syn and ns.db.countAlts)
end

-- How many you have, counting what the settings say, and where they are: { bags, bank, mail, alts }.
function ns.Count(id)
    local bags = CountIn(id, false)
    if not bags then return nil end
    local parts, total = { bags = bags }, bags
    if ns.db.includeBank then
        local all = CountIn(id, true)
        if not all then return nil end
        parts.bank, total = all - bags, all
    end
    local syn = Syndicator_()
    if syn and (ns.db.countMail or ns.db.countAlts) then
        local ok, info = pcall(syn.API.GetInventoryInfoByItemID, id, true, false)
        local me = syn.API.GetCurrentCharacter and syn.API.GetCurrentCharacter()
        if ok and type(info) == "table" then
            for _, c in ipairs(info.characters or {}) do
                local full = (c.character or "") .. "-" .. (c.realmNormalized or "")
                if full == me or c.character == me then
                    if ns.db.countMail then parts.mail = (parts.mail or 0) + (c.mail or 0) end
                elseif ns.db.countAlts then
                    parts.alts = (parts.alts or 0) + (c.bags or 0) + (c.bank or 0) + (c.mail or 0)
                end
            end
        end
        total = total + (parts.mail or 0) + (parts.alts or 0)
    end
    return total, parts
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
-- The bars and their items
------------------------------------------------------------------------
ns.counts = {}   -- [id] = collected since the item was added (the last count read)
ns.have = {}     -- [id] = how many you have, collected or not
ns.parts = {}    -- [id] = where they are: { bags, bank, mail, alts }
ns.gains = {}    -- [id] = { { t, d }, ... }: what came in this session, for the pace
ns.flashUntil = {} -- [id] = until when a goal just reached shows (hidden done items wait for the flash)
ns.activeBar = 1 -- the bar new items go to: the last one clicked
local reached = {} -- [id] = the goal was reached at the last count
local primed = false -- the first count after login sets the state without sounds

function ns.Bars() return ns.char.bars end
function ns.Items(bar) return ns.char.bars[bar or 1].items end

-- Every item on every bar: for item, bar, index in ns.EachItem() do.
function ns.EachItem()
    local b, i = 1, 0
    return function()
        local bars = ns.char.bars
        while bars[b] do
            i = i + 1
            local item = bars[b].items[i]
            if item then return item, b, i end
            b, i = b + 1, 0
        end
    end
end

-- The item, its bar and its place there.
function ns.FindItem(id)
    for item, b, i in ns.EachItem() do
        if item.id == id then return item, i, b end
    end
end

function ns.IsDone(id)
    local item = ns.FindItem(id)
    return item and U.Reached(ns.counts[id] or 0, item.goal) or false
end

function ns.PlayGoalSound()
    if ns.db.sound then ns.PlaySound(ns.db.soundName) end
end

-- What there is now doesn't count: counting starts from 0.
local function StartCounting(item)
    item.start = ns.Count(item.id) or 0
    item.key = ns.SourceKey()
    item.last = 0
    ns.gains[item.id] = nil
end

-- Right after login the bags may still be loading and read as empty: the start mustn't come down to that.
local bagsLoaded = false

-- How many were collected out of `have`. Fewer than at the start (sold, used, put in the bank): the start
-- comes down with them, so what's looted next counts. When what's counted changed (the bank, the mail), the
-- count goes on from where it was.
local function Collected(item, have)
    local key = ns.SourceKey()
    local start = item.start or 0 -- items added before 0.1.0-beta2 count everything
    if item.key and item.key ~= key then
        start = math.max(0, have - (item.last or 0))
        if bagsLoaded then item.start, item.key = start, key end
    end
    if have < start then
        if not bagsLoaded then return 0 end
        item.start, start = have, have
    end
    local n = have - start
    if bagsLoaded then item.last, item.key = n, key end
    return n
end

-- A goal reached: the sound, the chat line, the flash.
local function GoalReached(item)
    ns.PlayGoalSound()
    if ns.db.chat then ns.Print("goal reached: %s x%d.", ns.ColoredName(item.id, item.name), item.goal) end
    if ns.db.flash then
        ns.flashUntil[item.id] = GetTime() + ns.FLASH_TIME
        C_Timer.After(ns.FLASH_TIME + 0.05, ns.QueueRefresh) -- a hidden done item leaves after it
        for _, bar in ipairs(ns.bars or {}) do bar:Flash(item.id) end
    end
end
ns.FLASH_TIME = 2

local function UpdateBars()
    for i, bar in ipairs(ns.bars or {}) do
        if ns.char.bars[i] then bar:Update() end
    end
end

-- Reads every count; plays the sound for goals reached since the last count.
function ns.Refresh()
    if not ns.char then return end
    local now = GetTime()
    for item in ns.EachItem() do
        local have, parts = ns.Count(item.id)
        if have then
            local n = Collected(item, have)
            local before = ns.counts[item.id]
            if primed and bagsLoaded and before and n > before then
                local g = ns.gains[item.id] or {}
                ns.gains[item.id] = g
                g[#g + 1] = { t = now, d = n - before }
                U.PruneGains(g, now)
            end
            ns.have[item.id], ns.parts[item.id], ns.counts[item.id] = have, parts, n
            local done = U.Reached(n, item.goal)
            if done and reached[item.id] == false and primed then GoalReached(item) end
            reached[item.id] = done
        end
        if not item.name then item.name = ns.ItemName(item.id) end
    end
    primed = true
    UpdateBars()
end

-- How many of an item come in an hour, and in how many seconds the goal is reached at that pace.
function ns.Pace(id)
    local item = ns.FindItem(id)
    local rate = ns.gains[id] and U.Rate(ns.gains[id], GetTime())
    if not (item and rate) then return nil end
    local left = item.goal - (ns.counts[id] or 0)
    return rate, left > 0 and left / rate * 3600 or nil
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

-- Marks whether the goal is reached now, so that it doesn't play a sound.
local function Settle(item)
    local have = ns.Count(item.id)
    local n = have and Collected(item, have) or ns.counts[item.id] or 0
    ns.counts[item.id] = n
    reached[item.id] = U.Reached(n, item.goal)
end

local function NewItem(id, goal, bar)
    local bars = ns.char.bars
    bar = bars[bar] and bar or (bars[ns.activeBar] and ns.activeBar) or 1
    local item = { id = id, goal = goal, name = ns.ItemName(id) }
    StartCounting(item)
    table.insert(bars[bar].items, item)
    if item.name then ns.db.known[id] = item.name end
    Settle(item)
    return item
end

-- Adds an item to a bar (the last one clicked when not said), counting from 0 whatever you have of it
-- already, or changes its goal when it's on a bar.
function ns.SetItem(id, goal, bar)
    goal = math.max(0, math.floor(tonumber(goal) or 0))
    local item = ns.FindItem(id)
    if item then
        item.goal = goal
        Settle(item)
    else
        NewItem(id, goal, bar)
    end
    ns.Refresh()
end

-- Counts an item from 0 again.
function ns.RestartCount(id)
    local item = ns.FindItem(id)
    if not item then return end
    StartCounting(item)
    Settle(item)
    ns.Refresh()
end

local function Forget(id)
    reached[id], ns.counts[id], ns.have[id], ns.parts[id], ns.gains[id], ns.flashUntil[id] =
        nil, nil, nil, nil, nil, nil
end

function ns.RemoveItem(id)
    local item, i, b = ns.FindItem(id)
    if not item then return end
    table.remove(ns.char.bars[b].items, i)
    Forget(id)
    ns.Print("removed %s.", ns.ColoredName(id, item.name))
    UpdateBars()
end

-- Moves an item one place left (-1) or right (+1) on its bar.
function ns.MoveItem(id, delta)
    local _, i, b = ns.FindItem(id)
    if not i then return end
    local items = ns.char.bars[b].items
    local j = i + delta
    if j < 1 or j > #items then return end
    items[i], items[j] = items[j], items[i]
    UpdateBars()
end

-- Moves an item to `bar`, to the place `pos` there (the end when nil): dragged onto another item or bar.
function ns.MoveItemTo(id, bar, pos)
    local item, i, b = ns.FindItem(id)
    local target = ns.char.bars[bar]
    if not (item and target) then return end
    if b == bar then
        U.MoveInList(target.items, i, pos or #target.items)
    else
        table.remove(ns.char.bars[b].items, i)
        table.insert(target.items, math.max(1, math.min(pos or #target.items + 1, #target.items + 1)), item)
    end
    UpdateBars()
end

------------------------------------------------------------------------
-- More bars
------------------------------------------------------------------------
local function CopyPoint(p) return p and { p[1], p[2], p[3], p[4] } end

-- A new empty bar, below the last one.
function ns.AddBar()
    local bars = ns.char.bars
    bars[#bars + 1] = { items = {} }
    ns.activeBar = #bars
    ns.ApplyAll()
    return #bars
end

-- Takes a bar away with its items. The first bar is always there.
function ns.RemoveBar(index)
    local bars = ns.char.bars
    if #bars < 2 or not bars[index] then return end
    for _, item in ipairs(bars[index].items) do Forget(item.id) end
    table.remove(bars, index)
    if not bars[ns.activeBar] then ns.activeBar = 1 end
    ns.ApplyAll()
end

------------------------------------------------------------------------
-- Other characters' lists
------------------------------------------------------------------------
local function CharKey()
    return (UnitName and UnitName("player") or "?") .. " - " .. (GetRealmName and GetRealmName() or "?")
end

-- Keeps what this character collects where the others can copy it.
function ns.SaveList()
    if not ns.char then return end
    local items = {}
    for item in ns.EachItem() do items[#items + 1] = { id = item.id, goal = item.goal, name = item.name } end
    local class = UnitClass and select(2, UnitClass("player"))
    ns.db.lists[CharKey()] = #items > 0 and { class = class, items = items } or nil
end

-- The other characters' lists: { { key = "Name - Realm", class, items }, ... } by name.
function ns.OtherLists()
    local me, out = CharKey(), {}
    for key, list in pairs(ns.db.lists) do
        if key ~= me and list.items and #list.items > 0 then
            out[#out + 1] = { key = key, class = list.class, items = list.items }
        end
    end
    table.sort(out, function(a, b) return a.key < b.key end)
    return out
end

-- Puts another character's items on a bar, with their goals. Items on a bar already stay as they are.
function ns.CopyList(key, bar)
    local list = ns.db.lists[key]
    if not list then return 0 end
    local added = 0
    for _, e in ipairs(list.items) do
        if not ns.FindItem(e.id) and ns.ItemExists(e.id) then
            NewItem(e.id, e.goal or 0, bar)
            added = added + 1
        end
    end
    ns.Print("copied %d items from %s.", added, key)
    ns.Refresh()
    return added
end

------------------------------------------------------------------------
-- A recipe's reagents
------------------------------------------------------------------------
-- recipe = { name, reagents = { { id, count }, ... } }. For `times` crafts: an item on a bar already gets the
-- reagents added to its goal; a new one goes on `bar` with what's missing as its goal; what you have enough
-- of stays off.
function ns.AddReagents(recipe, times, bar)
    times = math.max(1, math.floor(tonumber(times) or 1))
    local added, raised, enough = 0, 0, {}
    for _, r in ipairs(recipe.reagents) do
        local need = r.count * times
        local item = ns.FindItem(r.id)
        if item then
            item.goal = item.goal + need
            Settle(item)
            raised = raised + 1
        else
            local missing = need - (ns.Count(r.id) or 0)
            if missing > 0 then
                NewItem(r.id, missing, bar)
                added = added + 1
            else
                enough[#enough + 1] = ns.ColoredName(r.id)
            end
        end
    end
    ns.Print("%s x%d: %d reagents added, %d goals raised.", recipe.name or "?", times, added, raised)
    if #enough > 0 then ns.Print("you have enough already: %s.", table.concat(enough, ", ")) end
    ns.Refresh()
end

-- Settings changed: the bars and the open windows follow.
function ns.ApplyAll()
    if ns.char then
        ns.bars = ns.bars or {}
        for i = 1, #ns.char.bars do ns.bars[i] = ns.bars[i] or ns.CreateBar(i) end
        ns.bar = ns.bars[1]
        for _, bar in ipairs(ns.bars) do bar:ApplySettings() end
    end
    if ns.MinimapButton then ns.MinimapButton.Update() end
    ns.Refresh()
end

------------------------------------------------------------------------
-- Saved data from older versions
------------------------------------------------------------------------
local function Upgrade()
    local char = ns.char
    if char.items then -- before 0.1.0: one bar
        if #char.bars == 0 then char.bars[1] = { items = char.items, point = CopyPoint(ns.db.point) } end
        char.items = nil
    end
    if #char.bars == 0 then char.bars[1] = { items = {}, point = CopyPoint(ns.db.point) } end
    for _, bar in ipairs(char.bars) do
        bar.items = bar.items or {}
        for _, item in ipairs(bar.items) do
            if item.startBank then -- 0.1.0-beta2: separate starts for the bags and the bank
                if ns.db.includeBank then item.start = item.startBank end
                item.startBank = nil
                item.key = ns.db.includeBank and "bk" or "b"
            end
        end
    end
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
    Upgrade()
end)

-- Syndicator tells when the bags, the bank or the mail it keeps change.
local function WatchSyndicator()
    local s = Syndicator_()
    local reg = s and s.CallbackRegistry
    if not (reg and reg.RegisterCallback) then return end
    for _, e in ipairs({ "BagCacheUpdate", "MailCacheUpdate" }) do
        pcall(reg.RegisterCallback, reg, e, ns.QueueRefresh, ns)
    end
end

ns.On("PLAYER_LOGIN", function()
    C_Timer.After(10, function() bagsLoaded = true end) -- in case the bags send no update
    ns.InitOptions()
    ns.search.Init()
    if ns.recipe then ns.recipe.Init() end
    WatchSyndicator()
    ns.ApplyAll()
    ns.SaveList()
end)

ns.On("PLAYER_LOGOUT", function() ns.SaveList() end)

ns.On("BAG_UPDATE_DELAYED", function() bagsLoaded = true end)
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "BAG_UPDATE", "PLAYERBANKSLOTS_CHANGED", "BANKFRAME_OPENED",
    "BANKFRAME_CLOSED", "PLAYER_ENTERING_WORLD" }) do
    ns.On(e, ns.QueueRefresh)
end

-- A name or an icon the game was still loading.
ns.On("GET_ITEM_INFO_RECEIVED", function(id)
    if id and ns.char and ns.FindItem(id) then ns.QueueRefresh() end
end)

local function CombatChanged(inCombat)
    for _, bar in ipairs(ns.bars or {}) do bar:UpdateVisibility(inCombat) end
end
ns.On("PLAYER_REGEN_DISABLED", function() CombatChanged(true) end)
ns.On("PLAYER_REGEN_ENABLED", function() CombatChanged(false) end)

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
local function Help()
    ns.Print("commands:")
    print("  /ic - " .. L["settings"])
    print("  /ic add [" .. L["item"] .. "] - " .. L["add an item"])
    print("  /ic recipe - " .. L["the reagents of the recipe open in the profession window"])
    print("  /ic bar - " .. L["a new bar"])
    print("  /ic lock, /ic unlock - " .. L["lock or unlock the bars"])
    print("  /ic show, /ic hide - " .. L["show or hide the bars"])
    print("  /ic reset - " .. L["put the bars back in the middle of the screen"])
    print("  /ic minimap - " .. L["show or hide the minimap button"])
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
        if not ns.char.bars[ns.activeBar] then ns.activeBar = 1 end
        ns.dialog:OpenAdd(ns.bars[ns.activeBar].plus, rest ~= "" and rest or nil)
    elseif cmd == "recipe" then
        ns.recipe.Open(ns.bars[ns.activeBar] and ns.bars[ns.activeBar].plus)
    elseif cmd == "bar" then
        ns.AddBar()
    elseif cmd == "lock" or cmd == "unlock" then
        ns.db.locked = cmd == "lock"
        ns.Print(ns.db.locked and "bars locked: drag an item to change the order."
            or "bars unlocked: drag an item to move its bar, the corner to resize.")
        ns.ApplyAll()
    elseif cmd == "show" or cmd == "hide" then
        ns.db.hidden = cmd == "hide"
        ns.ApplyAll()
    elseif cmd == "minimap" then
        ns.db.minimapButton = not ns.db.minimapButton
        ns.ApplyAll()
    elseif cmd == "reset" then
        ns.ResetPositions()
    else
        Help()
    end
end

-- Every bar back near the middle of the screen, one under the other.
function ns.ResetPositions()
    ns.db.point, ns.db.hidden = nil, false
    for _, bar in ipairs(ns.char.bars) do bar.point = nil end
    ns.ApplyAll()
end
