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
_G.IsShiftKeyDown = function() return false end
_G.IsAltKeyDown = function() return false end
_G.IsControlKeyDown = function() return _G.ctrlDown or false end
_G.IsMetaKeyDown = function() return false end
_G.IsMacClient = function() return true end
_G.IsModifiedClick = function() return false end
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
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
    GetItemCount = function(id) return bags[id] or 0 end,
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

Fire("ADDON_LOADED", "ItemsCollectTracker")
Fire("PLAYER_LOGIN")
RunTimers()
check("bar created", ns.bar ~= nil)
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

-- Count rises to the goal: one sound.
ns.SetItem(2589, 10)
check("two items", #ns.Items() == 2)
bags[2589] = 9
Fire("BAG_UPDATE_DELAYED")
RunTimers()
check("no sound below goal", #played == 0)
bags[2589] = 12
Fire("BAG_UPDATE_DELAYED")
RunTimers()
check("sound on goal", #played == 1 and played[1] == 878)
Fire("BAG_UPDATE_DELAYED")
RunTimers()
check("sound only once", #played == 1)
check("count shown", ns.bar.cells[2].count:GetText() == "12")

-- Ctrl + left click removes.
_G.ctrlDown = true
ns.bar.cells[1]._scripts.OnClick(ns.bar.cells[1], "LeftButton")
_G.ctrlDown = false
check("removed by ctrl+click", #ns.Items() == 1 and ns.Items()[1].id == 2589)
ns.bar.cells[1]._scripts.OnClick(ns.bar.cells[1], "LeftButton")
check("plain click keeps it", #ns.Items() == 1)

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
