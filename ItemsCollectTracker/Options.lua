-- The settings window (/ic), also opened from the game's AddOns settings.
local _, ns = ...
local L = ns.L
local U = ns.util

local panel, scroll, content, settingsButton
local BuildContent
local y = 0
local refreshers = {}
local LEFT, RIGHT = 20, 250
local WIDTH = 540

local function Refresh() for _, r in ipairs(refreshers) do r() end end

local function Changed()
    ns.ApplyAll()
    Refresh()
end

------------------------------------------------------------------------
-- Widgets
------------------------------------------------------------------------
local function Label(text, x, template)
    local fs = content:CreateFontString(nil, "ARTWORK", template or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", x or LEFT, y)
    fs:SetText(L[text])
    return fs
end

local function Header(text)
    y = y - 12
    Label(text, 12, "GameFontNormalLarge")
    local line = content:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.15)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 12, y - 22)
    line:SetPoint("TOPRIGHT", -12, y - 22)
    y = y - 32
end

local function Note(text)
    local fs = Label(text, LEFT, "GameFontDisableSmall")
    fs:SetWidth(WIDTH - LEFT - 20)
    fs:SetJustifyH("LEFT")
    y = y - (fs:GetStringHeight() + 10)
end

local function Check(text, get, set)
    local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", LEFT - 4, y + 4)
    local fs = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    fs:SetWidth(WIDTH - LEFT - 50)
    fs:SetJustifyH("LEFT")
    fs:SetText(L[text])
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); Changed() end)
    refreshers[#refreshers + 1] = function() cb:SetChecked(get() and true or false) end
    y = y - math.max(26, fs:GetStringHeight() + 12)
end

local function RowLabel(text)
    local fs = Label(text)
    fs:SetWidth(RIGHT - LEFT - 8)
    fs:SetJustifyH("LEFT")
    return fs
end

local function RowHeight(fs, height) return math.max(height, fs:GetStringHeight() + 12) end

-- A slider with a box to type the value in. `scale` shows 0..1 settings as 0..100.
local function Slider(text, min, max, step, get, set, scale)
    scale = scale or 1
    local fs = RowLabel(text)
    local s = CreateFrame("Slider", nil, content)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(170, 16)
    s:SetPoint("TOPLEFT", RIGHT, y + 1)
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:EnableMouse(true)
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0, 0, 0, 0.6)
    track:SetPoint("LEFT"); track:SetPoint("RIGHT"); track:SetHeight(6)
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local val = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    val:SetSize(42, 20)
    val:SetPoint("LEFT", s, "RIGHT", 14, 0)
    val:SetAutoFocus(false)
    val:SetJustifyH("CENTER")
    local function Value() return math.floor(get() * scale + 0.5) end
    local function Put(v)
        v = math.min(max, math.max(min, math.floor(v / step + 0.5) * step))
        if v ~= Value() then set(v / scale); ns.ApplyAll() end
        val:SetText(v)
    end
    local function Show()
        s.refreshing = true
        s:SetValue(Value())
        s.refreshing = nil
        val:SetText(Value())
        val:SetCursorPosition(0)
    end
    s:SetScript("OnValueChanged", function(self, v) if not self.refreshing then Put(v) end end)
    val:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if v then Put(v); Show() end
        self:ClearFocus()
    end)
    val:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    val:SetScript("OnEditFocusLost", Show)
    refreshers[#refreshers + 1] = Show
    y = y - RowHeight(fs, 28)
end

local function Color(text, get, set)
    local b = CreateFrame("Button", nil, content)
    b:SetSize(18, 18)
    b:SetPoint("TOPLEFT", LEFT, y + 2)
    local border = b:CreateTexture(nil, "BACKGROUND")
    border:SetColorTexture(1, 1, 1, 1)
    border:SetAllPoints()
    local sw = b:CreateTexture(nil, "ARTWORK")
    sw:SetPoint("TOPLEFT", 1, -1)
    sw:SetPoint("BOTTOMRIGHT", -1, 1)
    local fs = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("LEFT", b, "RIGHT", 6, 0)
    fs:SetText(L[text])
    local function Paint() local c = get(); sw:SetColorTexture(c[1], c[2], c[3], 1) end
    b:SetScript("OnClick", function()
        local c = get()
        local r0, g0, b0 = c[1], c[2], c[3]
        local function OnColor()
            local r, g, bb = ColorPickerFrame:GetColorRGB()
            set({ r, g, bb, 1 }); Paint(); ns.ApplyAll()
        end
        local function OnCancel()
            set({ r0, g0, b0, 1 }); Paint(); ns.ApplyAll()
        end
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r0, g = g0, b = b0, hasOpacity = false, swatchFunc = OnColor, cancelFunc = OnCancel,
            })
        else
            ColorPickerFrame.func, ColorPickerFrame.cancelFunc = OnColor, OnCancel
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame:SetColorRGB(r0, g0, b0)
            ColorPickerFrame:Show()
        end
    end)
    refreshers[#refreshers + 1] = Paint
    y = y - 26
end

-- Dropdown list: the new menu system's dropdown where the client has it, the old UIDropDownMenu otherwise.
local selectCount = 0
local function Select(text, values, get, set, extra)
    local fs = RowLabel(text)
    local function List() return type(values) == "function" and values() or values end
    local function Pick(value) set(value); Changed() end
    local ok, btn = pcall(CreateFrame, "DropdownButton", nil, content, "WowStyle1DropdownTemplate")
    local gap = 4
    if ok and btn and btn.SetupMenu then
        btn:SetSize(200, 22)
        btn:SetPoint("TOPLEFT", RIGHT, y + 4)
        btn:SetupMenu(function(_, root)
            if root.SetScrollMode then root:SetScrollMode(400) end
            for _, item in ipairs(List()) do
                root:CreateRadio(L[item.text], function() return get() == item.value end, function() Pick(item.value) end)
            end
        end)
        refreshers[#refreshers + 1] = function() btn:GenerateMenu() end
    else
        selectCount = selectCount + 1 -- the old template needs a named frame
        btn = CreateFrame("Frame", "ItemsCollectTrackerSelect" .. selectCount, content, "UIDropDownMenuTemplate")
        btn:SetPoint("TOPLEFT", RIGHT - 16, y + 6)
        UIDropDownMenu_SetWidth(btn, 180)
        UIDropDownMenu_Initialize(btn, function(_, level)
            for _, item in ipairs(List()) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = L[item.text]
                info.checked = get() == item.value
                info.func = function() Pick(item.value) end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        refreshers[#refreshers + 1] = function()
            local label = tostring(get())
            for _, item in ipairs(List()) do
                if item.value == get() then label = L[item.text] end
            end
            UIDropDownMenu_SetText(btn, label)
        end
        gap = -12 -- the old template has empty space on its right
    end
    if extra then
        local e = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        e:SetPoint("LEFT", btn, "RIGHT", gap, 0)
        e:SetText(L[extra.text])
        e:SetSize(math.max(50, e:GetFontString():GetStringWidth() + 24), 22)
        e:SetScript("OnClick", extra.onClick)
    end
    y = y - RowHeight(fs, 30)
end

local function Input(text, width, onEnter)
    local fs = RowLabel(text)
    local e = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    e:SetSize(width, 20)
    e:SetPoint("TOPLEFT", RIGHT + 6, y + 3)
    e:SetAutoFocus(false)
    e:SetScript("OnEnterPressed", function(self) onEnter(self:GetText()); self:SetText(""); self:ClearFocus() end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    y = y - RowHeight(fs, 28)
    return e
end

local function Button(text, onClick, x)
    local b = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    b:SetText(L[text])
    b:SetSize(math.max(120, b:GetFontString():GetStringWidth() + 24), 22)
    b:SetPoint("TOPLEFT", x or LEFT, y + 4)
    b:SetScript("OnClick", onClick)
    return b
end

------------------------------------------------------------------------
-- Lists
------------------------------------------------------------------------
local PLUS_MODES = {
    { value = "hover",  text = "Only under the mouse" },
    { value = "always", text = "Always" },
}

local POSITIONS = {
    { value = "below",       text = "Below the icon" },
    { value = "above",       text = "Above the icon" },
    { value = "center",      text = "On the icon, in the middle" },
    { value = "top",         text = "On the icon, at the top" },
    { value = "bottomright", text = "On the icon, bottom right" },
}

local FORMATS = {
    { value = "count", text = "How many you have: 12" },
    { value = "goal",  text = "With the goal: 12/20" },
    { value = "left",  text = "How many are still missing: 8" },
}

local function Modifiers()
    local list = {}
    for _, m in ipairs(U.MODIFIERS) do
        if not m.mac or (IsMacClient and IsMacClient()) then list[#list + 1] = m end
    end
    return list
end

local function IsCustomSound(value)
    for _, c in ipairs(ns.db.customSounds) do if c.path == value then return true end end
    return false
end

local function ConfirmReset()
    StaticPopupDialogs.ITEMSCOLLECTTRACKER_RESET = {
        text = L["Reset all settings to the defaults? The items on the bar stay."],
        button1 = YES, button2 = NO,
        OnAccept = function()
            ns.ResetSettings()
            C_Timer.After(0, function() BuildContent(); Changed() end)
            ns.Print("settings reset.")
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopup_Show("ITEMSCOLLECTTRACKER_RESET")
end

------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------
local function Build()
    local ok, f = pcall(CreateFrame, "Frame", "ItemsCollectTrackerOptions", UIParent, "BasicFrameTemplateWithInset")
    if not ok then
        f = CreateFrame("Frame", "ItemsCollectTrackerOptions", UIParent, "BackdropTemplate")
        f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 24,
            insets = { left = 6, right = 6, top = 6, bottom = 6 } })
        f.CloseButton = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        f.CloseButton:SetPoint("TOPRIGHT")
    end
    panel = f
    local close = f.CloseButton or _G["ItemsCollectTrackerOptionsCloseButton"]
    if close then close:SetScript("OnClick", function() f:Hide() end) end
    f:SetSize(WIDTH + 50, 620)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()
    tinsert(UISpecialFrames, "ItemsCollectTrackerOptions")

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -6)
    title:SetText("|cff7fd4ffItemsCollectTracker|r")

    scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -30)
    scroll:SetPoint("BOTTOMRIGHT", -32, 10)
    f:SetScript("OnShow", Refresh)
end

function BuildContent()
    if content then content:Hide() end
    wipe(refreshers)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH, 100)
    scroll:SetScrollChild(content)
    y = -4
    local db = ns.db
    local function T(key) return function() return db.text[key] end, function(v) db.text[key] = v end end

    Header("Bar")
    Select("Language", ns.LANGUAGES, function() return db.locale end, function(v)
        db.locale = v
        C_Timer.After(0, function()
            BuildContent()
            if settingsButton then settingsButton:SetText(L["Open settings (/ic)"]) end
            Changed()
        end)
    end)
    Check("Lock the bar (no moving, no resizing)", function() return db.locked end, function(v) db.locked = v end)
    Check("Hide the bar in combat", function() return db.hideInCombat end, function(v) db.hideInCombat = v end)
    Check("Grey out items you have none of", function() return db.dimMissing end, function(v) db.dimMissing = v end)
    Check("Count the bank too", function() return db.includeBank end, function(v) db.includeBank = v end)
    Note("The game knows what's in your bank after you open it once.")
    Select("The + button", PLUS_MODES, function() return db.plusButton end, function(v) db.plusButton = v end)
    Slider("Icon size", 16, 96, 1, function() return db.iconSize end, function(v) db.iconSize = v end)
    Slider("Space between icons", 0, 30, 1, function() return db.spacing end, function(v) db.spacing = v end)
    Slider("Items in a row", 1, 40, 1, function() return db.columns end, function(v) db.columns = v end)
    Slider("Opacity when the mouse is away, %", 0, 100, 5, function() return db.alpha end,
        function(v) db.alpha = v end, 100)
    Slider("Background, %", 0, 100, 5, function() return db.background end,
        function(v) db.background = v end, 100)
    Note("Drag any icon or the + to move the bar, its bottom right corner to resize it. Right-click for the menu.")

    Header("Number")
    Select("Where", POSITIONS, T("position"))
    Select("Shows", FORMATS, T("format"))
    Select("Font", ns.GetFontList, T("font"))
    Select("Outline", ns.OUTLINES, T("outline"))
    Slider("Size", 8, 48, 1, T("size"))
    Color("Color", T("color"))
    Color("Color when the goal is reached", T("doneColor"))

    Header("Goal reached")
    Check("Play a sound", function() return db.sound end, function(v) db.sound = v end)
    Select("Sound", ns.GetSoundList, function() return db.soundName end, function(v) db.soundName = v end,
        { text = "Test", onClick = function()
            if not ns.PlaySound(db.soundName) then
                ns.Print("can't play %s. A new file needs a full restart of the game.", tostring(db.soundName))
            end
        end })
    Input("Your sound file", 200, function(text) ns.AddCustomSound(text); Changed() end)
    Note("Put .ogg or .mp3 files in World of Warcraft\\_forever_\\Interface\\ItemsCollectTrackerSounds\\ and restart " ..
        "the game, then type the file name here (coins.ogg) and press Enter. A full path from Interface\\ works too.")
    local remove = Button("Remove this file from the list", function()
        ns.RemoveCustomSound(db.soundName)
        Changed()
    end)
    refreshers[#refreshers + 1] = function() remove:SetShown(IsCustomSound(db.soundName)) end
    y = y - 30
    Check("Write it in the chat", function() return db.chat end, function(v) db.chat = v end)

    Header("Removing an item")
    Select("Hold", Modifiers, function() return db.removeMods end, function(v) db.removeMods = v end)
    Select("And click", U.BUTTONS, function() return db.removeButton end, function(v) db.removeButton = v end)
    local combo = Label("")
    refreshers[#refreshers + 1] = function()
        combo:SetText(string.format(L["Now: %s on an item takes it off the bar."], ns.RemoveComboText()))
    end
    y = y - 26
    Note("Exactly these keys: with Ctrl set, Ctrl+Shift+click doesn't remove. A plain right click set here " ..
        "removes the item instead of opening its menu.")

    Header("Reset")
    Button("Put the bar in the middle", function()
        db.point, db.hidden = nil, false
        Changed()
    end)
    Button("Reset all settings", ConfirmReset, LEFT + 200)
    y = y - 34

    content:SetHeight(-y + 20)
    Refresh()
end

function ns.ToggleOptions()
    if not panel then Build(); BuildContent() end
    panel:SetShown(not panel:IsShown())
end

-- Entry in the game's AddOns settings list with a button that opens the window.
function ns.InitOptions()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    local p = CreateFrame("Frame")
    local t = p:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16)
    t:SetText("ItemsCollectTracker")
    local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    b:SetSize(200, 26)
    b:SetPoint("TOPLEFT", 16, -50)
    b:SetText(L["Open settings (/ic)"])
    settingsButton = b
    b:SetScript("OnClick", function()
        if SettingsPanel then HideUIPanel(SettingsPanel) end
        if not panel or not panel:IsShown() then ns.ToggleOptions() end
    end)
    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, p, "ItemsCollectTracker")
    if ok and category then pcall(Settings.RegisterAddOnCategory, category) end
end
