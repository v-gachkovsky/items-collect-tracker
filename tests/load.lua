-- Loads the whole addon against a pretend game API and plays a session: login, adding items, counts changing,
-- a goal reached, removing, the settings window. Catches errors only the game would show otherwise.
-- lua tests/load.lua (from the repository root).

------------------------------------------------------------------------
-- Pretend frames: every method exists; the few that answer something answer it
------------------------------------------------------------------------
local frames = {}
local Mock
local function newMock(kind)
    local o = { _kind = kind, _shown = true, _scripts = {}, _text = "", _w = 40, _h = 40 }
    frames[#frames + 1] = o
    return setmetatable(o, Mock)
end
local methods = {
    CreateTexture = function() return newMock("Texture") end,
    CreateFontString = function() return newMock("FontString") end,
    CreateAnimationGroup = function() return newMock("AnimationGroup") end,
    CreateAnimation = function() return newMock("Animation") end,
    GetFontString = function(self) self._fs = self._fs or newMock("FontString"); return self._fs end,
    SetScript = function(self, name, fn) self._scripts[name] = fn end,
    HookScript = function(self, name, fn)
        local old = self._scripts[name]
        self._scripts[name] = function(...) if old then old(...) end fn(...) end
    end,
    GetScript = function(self, name) return self._scripts[name] end,
    HasScript = function() return true end,
    Show = function(self) self._shown = true; if self._scripts.OnShow then self._scripts.OnShow(self) end end,
    Hide = function(self)
        local was = self._shown
        self._shown = false
        if was and self._scripts.OnHide then self._scripts.OnHide(self) end
    end,
    SetShown = function(self, v) if v then self:Show() else self:Hide() end end,
    IsShown = function(self) return self._shown end,
    IsVisible = function(self) return self._shown end,
    SetText = function(self, t) self._text = t == nil and "" or tostring(t) end,
    GetText = function(self) return self._text end,
    SetSize = function(self, w, h) self._w, self._h = w, h end,
    SetWidth = function(self, w) self._w = w end,
    SetHeight = function(self, h) self._h = h end,
    GetWidth = function(self) return self._w end,
    GetHeight = function(self) return self._h end,
    GetStringWidth = function() return 50 end,
    GetStringHeight = function() return 12 end,
    GetEffectiveScale = function() return 1 end,
    GetCenter = function() return 500, 400 end,
    GetLeft = function() return 100 end,
    GetTop = function() return 500 end,
    GetBottom = function() return 300 end,
    GetRect = function() return 100, 300, 40, 40 end,
    IsMouseOver = function() return false end,
    HasFocus = function(self) return self._focus or false end,
    SetFocus = function(self) self._focus = true end,
    ClearFocus = function(self) self._focus = false end,
    GetChecked = function() return false end,
    GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "" end,
    SetFont = function() return true end,
    GetFrameLevel = function() return 1 end,
    IsOwned = function(self, owner) return self._owner == owner end,
    SetOwner = function(self, owner) self._owner = owner end,
    GetOwner = function(self) return self._owner end,
    IsProtected = function() return false end,
    RegisterEvent = function(self, e) self._events = self._events or {}; self._events[e] = true end,
    GetNumPoints = function() return 1 end,
}
-- Game methods are capitalized; any other key is the addon's own field, nil until it's set.
Mock = { __index = function(_, k)
    if not k:match("^%u") or k == "CloseButton" then return nil end
    return methods[k] or function() end
end }

------------------------------------------------------------------------
-- Pretend game
------------------------------------------------------------------------
local bags = { [2589] = 5, [2592] = 0 } -- Linen Cloth, Wool Cloth
local itemNames = { [2589] = "Linen Cloth", [2592] = "Wool Cloth", [4306] = "Silk Cloth", [14047] = "Runecloth" }
local played = {}
local time = 0
local timers = {}
local printed = {}

_G.CreateFrame = function(kind, name)
    local f = newMock(kind)
    if name then _G[name] = f end
    return f
end
_G.UIParent = newMock("Frame")
_G.Minimap = newMock("Frame")
_G.GameTooltip = newMock("GameTooltip")
_G.ColorPickerFrame = newMock("Frame")
_G.UISpecialFrames = {}
_G.tinsert = table.insert
_G.unpack = table.unpack
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.print = function(...) printed[#printed + 1] = table.concat({ ... }, " ") end
_G.hooksecurefunc = function(a, b, c)
    if type(a) == "string" then
        local old = _G[a]
        _G[a] = function(...) local r = old(...); b(...); return r end
    else
        local old = a[b]
        a[b] = function(...) local r = old(...); c(...); return r end
    end
end
_G.ChatEdit_InsertLink = function() return false end
_G.C_Timer = { After = function(s, fn) timers[#timers + 1] = { at = time + s, fn = fn } end }
_G.GetTime = function() return time end
_G.debugprofilestop = function() return os.clock() * 1000 end
_G.GetCursorPosition = function() return 600, 400 end
_G.GetCursorInfo = function() return nil end
_G.ClearCursor = function() end
_G.InCombatLockdown = function() return false end
_G.IsShiftKeyDown = function() return _G.shiftDown or false end
_G.IsAltKeyDown = function() return false end
_G.IsControlKeyDown = function() return _G.ctrlDown or false end
_G.IsMetaKeyDown = function() return false end
_G.IsMacClient = function() return true end
_G.IsModifiedClick = function() return false end
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
_G.UnitName = function() return "Me" end
_G.GetRealmName = function() return "Realm" end
_G.UnitClass = function() return "Mage", "MAGE" end
_G.RAID_CLASS_COLORS = { MAGE = { colorStr = "ff3fc7eb" } }
_G.ITEM_QUALITY_COLORS = { [1] = { hex = "|cffffffff" } }
_G.SOUNDKIT = { IG_QUEST_LIST_COMPLETE = 878 }
_G.PlaySound = function(id) played[#played + 1] = id; return true end
_G.PlaySoundFile = function(path) played[#played + 1] = path; return true end
_G.SlashCmdList = {}
_G.StaticPopupDialogs = {}
_G.StaticPopup_Show = function() end
_G.Settings = {
    RegisterCanvasLayoutCategory = function() return {} end,
    RegisterAddOnCategory = function() end,
}
_G.C_Item = {
    GetItemCount = function(id, ...)
        _G.lastCountArgs = { id, ... }
        return bags[id] or 0
    end,
    GetItemInfoInstant = function(id)
        if itemNames[id] then return id, "Trade Goods", "Cloth", "", 132889 + id end
    end,
    GetItemNameByID = function(id) return itemNames[id] end,
    GetItemInfo = function(id)
        if type(id) == "string" then
            for k, v in pairs(itemNames) do
                if v == id then id = k end
            end
        end
        local name = itemNames[id]
        if name then
            return name, "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. name .. "]|h|r", 1, 1, 1, "", "", 20
        end
    end,
    GetItemQualityByID = function() return 1 end,
}
_G.C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end,
    GetContainerItemLink = function(bag, slot)
        if bag == 0 and slot == 1 then return "|cffffffff|Hitem:2589::::::::|h[Linen Cloth]|h|r" end
    end,
}

local function RunTimers()
    local due = timers
    timers = {}
    for _, t in ipairs(due) do t.fn() end
end

-- Every registered handler of an event.
local function Fire(event, ...)
    for _, f in ipairs(frames) do
        if f._events and f._events[event] and f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
    end
end

------------------------------------------------------------------------
-- Load the addon in TOC order
------------------------------------------------------------------------
local ns = {}
for line in io.lines("ItemsCollectTracker/ItemsCollectTracker.toc") do
    if line:match("%.lua$") then
        local path = "ItemsCollectTracker/" .. line:gsub("\\", "/")
        assert(loadfile(path))("ItemsCollectTracker", ns)
    end
end

local function check(name, cond)
    if not cond then error("FAIL: " .. name, 2) end
    io.write("ok  ", name, "\n")
end

-- Saved by 0.1.0-beta2: one list of items, a start for the bags and one for the bank.
_G.ItemsCollectTrackerDB = { point = { "TOPLEFT", "CENTER", 10, 20 } }
_G.ItemsCollectTrackerCharDB = { items = { { id = 4306, goal = 5, name = "Silk Cloth", start = 3, startBank = 8 } } }
Fire("ADDON_LOADED", "ItemsCollectTracker")
Fire("PLAYER_LOGIN")
RunTimers()
check("bar created", ns.bar ~= nil)
local old = ns.Items()[1]
check("old list is the first bar", #ns.Bars() == 1 and ns.char.items == nil and old and old.id == 4306)
check("old start kept", old.key == "b" and old.startBank == nil and ns.char.bars[1].point[3] == 10)
ns.RemoveItem(4306)
check("starts empty", #ns.Items() == 0)
check("remembered bag item", ns.db.known[2589] == "Linen Cloth")
local mm = ItemsCollectTrackerMinimapButton
check("minimap button", mm ~= nil and mm:IsShown())
mm._scripts.OnClick(mm, "RightButton")
check("right click hides the bar", ns.db.hidden == true and not ns.bar:IsShown())
mm._scripts.OnClick(mm, "RightButton")
check("right click shows it again", ns.db.hidden == false and ns.bar:IsShown())
SlashCmdList.ITEMSCOLLECTTRACKER("minimap")
check("/ic minimap hides the button", not mm:IsShown())
SlashCmdList.ITEMSCOLLECTTRACKER("minimap")
check("/ic minimap brings it back", mm:IsShown())

-- The background read of the client's items finds the rest.
local scanner
for _, f in ipairs(frames) do
    if f._kind == "Frame" and f._scripts.OnUpdate and f ~= ns.bar then scanner = scanner or f end
end
for _ = 1, 2000 do
    if scanner._scripts.OnUpdate then scanner._scripts.OnUpdate(scanner, 0.016) end
    time = time + 0.016
    if not scanner._shown then break end
end
local found = ns.search.Find("cl")
check("suggestions for 'cl'", #found >= 3)
check("bag item first", found[1].id == 2589 and found[1].hint == "x5")
check("word match", ns.search.Find("cloth")[1] ~= nil)
check("one letter: starts only", #ns.search.Find("c") == 0 and ns.search.Find("r")[1].id == 14047)
check("exact name", ns.search.Exact("wool cloth") == 2592)

-- Add through the dialog: type, pick, set the goal.
ns.dialog:OpenAdd(ns.bar.plus)
local nameBox
for _, f in ipairs(frames) do
    if f._kind == "EditBox" and f._scripts.OnArrowPressed then nameBox = f end
end
nameBox:SetText("wool")
nameBox._focus = true
nameBox._scripts.OnTextChanged(nameBox, true)
RunTimers()
check("popup open", ns.Popup:IsShown() and ns.Popup:Selected().id == 2592)
nameBox._scripts.OnEnterPressed(nameBox)
check("goal step", ns.dialog.step == "goal" and ns.dialog.itemID == 2592)
ns.dialog:Confirm()
check("item added with stack size goal", ns.Items()[1].id == 2592 and ns.Items()[1].goal == 20)
check("dialog closed", not ns.dialog:IsShown())

-- What's in the bags when an item is added doesn't count: 60 there, goal 40, the bar starts at 0.
local function BagsChange(id, n)
    bags[id] = n
    Fire("BAG_UPDATE_DELAYED")
    RunTimers()
end
bags[2589] = 60
ns.SetItem(2589, 40)
check("two items", #ns.Items() == 2)
check("counting starts from 0", ns.counts[2589] == 0 and ns.bar.cells[2].count:GetText() == "0")
check("no sound for what was there", #played == 0)
BagsChange(2589, 90)
check("no sound below goal", #played == 0 and ns.counts[2589] == 30)
BagsChange(2589, 100)
check("sound on goal", #played == 1 and played[1] == 878)
BagsChange(2589, 100)
check("sound only once", #played == 1)
check("count shown", ns.bar.cells[2].count:GetText() == "40")
-- Fewer than at the start (sold some): what comes next counts from there.
BagsChange(2589, 50)
check("start comes down", ns.counts[2589] == 0 and ns.Items()[2].start == 50)
BagsChange(2589, 55)
check("looted after selling counts", ns.counts[2589] == 5)
ns.SetItem(2589, 10)
check("changing the goal keeps the count, no sound", ns.counts[2589] == 5 and #played == 1)
ns.RestartCount(2589)
check("count from 0 again", ns.counts[2589] == 0 and ns.Items()[2].start == 55)
BagsChange(2589, 65)
check("sound after restart", #played == 2)

-- Ctrl + left click removes.
_G.ctrlDown = true
ns.bar.cells[1]._scripts.OnClick(ns.bar.cells[1], "LeftButton")
_G.ctrlDown = false
check("removed by ctrl+click", #ns.Items() == 1 and ns.Items()[1].id == 2589)
ns.bar.cells[1]._scripts.OnClick(ns.bar.cells[1], "LeftButton")
check("plain click keeps it", #ns.Items() == 1)

-- Pace: how many come in an hour, and when the goal is reached at that pace.
ns.SetItem(2592, 20)
BagsChange(2592, 5)
time = time + 600
BagsChange(2592, 10)
local rate, eta = ns.Pace(2592)
check("pace per hour", rate and math.abs(rate - 60) < 0.01)
check("time to the goal", eta and math.abs(eta - 600) < 0.01)
ns.bar.cells[2]._scripts.OnEnter(ns.bar.cells[2])
check("tooltip with the pace", GameTooltip:IsOwned(ns.bar.cells[2]))

-- A goal reached: the icon flashes; with "hide items whose goal is reached" it leaves after the flash.
ns.db.hideDone = true
ns.ApplyAll()
BagsChange(2592, 20)
local function CellOf(bar, id)
    for _, c in ipairs(bar.cells) do if c:IsShown() and c.item and c.item.id == id then return c end end
end
-- Linen Cloth reached its goal before: it's hidden at once.
check("goal reached flashes", ns.flashUntil[2592] ~= nil and CellOf(ns.bar, 2592).glow:IsShown())
check("still there while it flashes", #ns.bar.visible == 1 and ns.bar.hiddenDone == 1)
time = time + 3
RunTimers()
RunTimers()
check("gone after the flash", #ns.bar.visible == 0 and ns.bar.hiddenDone == 2)
ns.bar.plus._scripts.OnEnter(ns.bar.plus)
ns.db.hideDone = false
ns.ApplyAll()
check("back when shown again", #ns.bar.visible == 2)

-- The thin progress bar.
ns.db.progressBar = true
ns.ApplyAll()
check("progress bar", ns.bar.cells[2].progress:IsShown())
ns.db.progressBar = false
ns.ApplyAll()

-- More bars; shift + drag takes an item to another bar, a plain drag on locked bars changes the order.
check("second bar", ns.AddBar() == 2 and #ns.bars == 2 and ns.bars[2]:IsShown())
ns.SetItem(14047, 3, 2)
check("item on the second bar", ns.Items(2)[1].id == 14047)
local function DragOnto(from, to)
    from._scripts.OnDragStart(from)
    to.IsMouseOver = function() return true end
    from._scripts.OnDragStop(from)
    to.IsMouseOver = nil
end
_G.shiftDown = true
DragOnto(ns.bar.cells[1], ns.bars[2].cells[1])
_G.shiftDown = false
check("dragged to the other bar", #ns.Items(1) == 1 and ns.Items(2)[1].id == 2589 and ns.Items(2)[2].id == 14047)
ns.db.locked = true
DragOnto(ns.bars[2].cells[1], ns.bars[2].cells[2])
ns.db.locked = false
check("locked: a drag changes the order", ns.Items(2)[1].id == 14047 and ns.Items(2)[2].id == 2589)
ns.bars[2].plus._scripts.OnClick(ns.bars[2].plus, "RightButton")
check("bar menu", ns.Menu:IsShown())
ns.Menu:Hide()
ns.RemoveBar(2)
check("bar removed with its items", #ns.Bars() == 1 and not ns.bars[2]:IsShown() and not ns.FindItem(14047))

-- Another character's list.
ns.db.lists["Alt - Realm"] = { class = "MAGE", items = { { id = 4306, goal = 7, name = "Silk Cloth" } } }
check("other characters' lists", #ns.OtherLists() == 1 and ns.OtherLists()[1].key == "Alt - Realm")
ns.CopyList("Alt - Realm", 1)
check("copied with its goal", ns.FindItem(4306) and ns.FindItem(4306).goal == 7)
ns.RemoveItem(4306)
Fire("PLAYER_LOGOUT")
check("own list kept for the others", ns.db.lists["Me - Realm"] and #ns.db.lists["Me - Realm"].items == 1)

-- A recipe's reagents from the profession window (the old window of Forever and Classic).
local reagents = { { 2592, 2 }, { 14047, 1 }, { 2589, 1 } }
_G.TradeSkillFrame = newMock("Frame")
_G.TradeSkillCreateAllButton = newMock("Button")
_G.TradeSkillInputBox = newMock("EditBox")
_G.TradeSkillInputBox.GetNumber = function() return 3 end
_G.GetTradeSkillSelectionIndex = function() return 4 end
_G.GetTradeSkillInfo = function() return "Bolt of Cloth", "optimal" end
_G.GetTradeSkillIcon = function() return 132889 end
_G.GetTradeSkillNumReagents = function() return #reagents end
_G.GetTradeSkillReagentInfo = function(_, k) return "?", 1, reagents[k][2] end
_G.GetTradeSkillReagentItemLink = function(_, k) return "|Hitem:" .. reagents[k][1] .. "::|h[x]|h" end
local recipe = ns.recipe.Current()
check("recipe read", recipe and #recipe.reagents == 3 and recipe.reagents[1].id == 2592 and recipe.reagents[1].count == 2)
ns.recipe.Attach()
check("button in the profession window", ns.recipe.attached.TradeSkillFrame ~= nil)
ns.recipe.attached.TradeSkillFrame._scripts.OnClick(ns.recipe.attached.TradeSkillFrame)
check("asks how many crafts", ns.dialog.step == "recipe")
ns.dialog:Confirm()
check("reagent on the bar gets more to collect", ns.FindItem(2592).goal == 26)
check("missing reagent added", ns.FindItem(14047) and ns.FindItem(14047).goal == 3)
check("enough of a reagent: stays off", not ns.FindItem(2589))
ns.RemoveItem(14047)
_G.TradeSkillFrame:Hide()
check("no recipe with the window closed", ns.recipe.Current() == nil)

-- Syndicator: the mail and the other characters count too; the number goes on from where it was.
local before = ns.counts[2592]
_G.Syndicator = { API = {
    GetInventoryInfoByItemID = function(id)
        if id ~= 2592 then return { characters = {} } end
        return { characters = {
            { character = "Me", realmNormalized = "Realm", bags = 20, bank = 0, mail = 4 },
            { character = "Alt", realmNormalized = "Realm", bags = 10, bank = 1, mail = 0 },
        } }
    end,
    GetCurrentCharacter = function() return "Me-Realm" end,
} }
ns.db.countMail, ns.db.countAlts = true, true
ns.ApplyAll()
check("mail and other characters counted", ns.have[2592] == 20 + 4 + 11 and ns.parts[2592].mail == 4
    and ns.parts[2592].alts == 11)
check("the count goes on from where it was", ns.counts[2592] == before)
ns.db.countMail, ns.db.countAlts = false, false
_G.Syndicator = nil
ns.ApplyAll()
check("and back", ns.counts[2592] == before and ns.have[2592] == 20)

-- The bank: on Retail that's also the reagent and warband banks.
ns.db.includeBank = true
ns.ApplyAll()
check("all the banks asked for", lastCountArgs[2] == true and lastCountArgs[4] == true and lastCountArgs[5] == true)
ns.db.includeBank = false
ns.ApplyAll()

-- LibDBIcon brought by another addon: the button is a standard one.
local registered, hidden = {}, {}
local libButton = newMock("Button")
libButton.border, libButton.background, libButton.icon = newMock("Texture"), newMock("Texture"), newMock("Texture")
local libs = {
    ["LibDataBroker-1.1"] = {
        objects = {},
        GetDataObjectByName = function(self, n) return self.objects[n] end,
        NewDataObject = function(self, n, o) self.objects[n] = o; return o end,
    },
    ["LibDBIcon-1.0"] = {
        IsRegistered = function(_, n) return registered[n] ~= nil end,
        Register = function(_, n, o, db) registered[n] = { object = o, db = db } end,
        Refresh = function(_, n, db) hidden[n] = db.hide end,
        GetMinimapButton = function() return libButton end,
    },
}
_G.LibStub = function(name) return libs[name] end
ns.MinimapButton.Update()
check("LibDBIcon button", registered.ItemsCollectTracker ~= nil and not ItemsCollectTrackerMinimapButton:IsShown())
check("the logo's own ring, no library border", not libButton.border:IsShown() and not libButton.background:IsShown())
libs["LibDataBroker-1.1"].objects.ItemsCollectTracker.OnClick(nil, "RightButton")
check("broker right click hides the bars", ns.db.hidden == true and not ns.bar:IsShown())
ns.ToggleBar()
SlashCmdList.ITEMSCOLLECTTRACKER("minimap")
check("hidden through LibDBIcon", hidden.ItemsCollectTracker == true)
SlashCmdList.ITEMSCOLLECTTRACKER("minimap")
_G.LibStub = nil

-- Settings window builds in both languages.
ns.ToggleOptions()
ns.db.locale = "ukUA"
ns.ToggleOptions()
ns.ToggleOptions()
check("settings window", ItemsCollectTrackerOptions ~= nil)
check("ukrainian text", ns.L["Add an item"] == "Додати предмет")
SlashCmdList.ITEMSCOLLECTTRACKER("lock")
check("lock", ns.db.locked == true)
SlashCmdList.ITEMSCOLLECTTRACKER("add Silk Cloth")
check("slash add goes to goal step", ns.dialog.step == "goal" and ns.dialog.itemID == 4306)
ns.ResetSettings()
check("reset keeps language and items", ns.db.locale == "ukUA" and #ns.Items() == 1 and ns.db.locked == false)
print = io.write
io.write("all good\n")
