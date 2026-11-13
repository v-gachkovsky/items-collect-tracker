-- The window that adds an item: first which item (typed with suggestions, shift-clicked, or dropped), then how
-- many to collect. It also changes the goal of an item already on the bar.
local _, ns = ...
local L = ns.L
local U = ns.util
local Popup = ns.Popup

local WIDTH = 300

local D = CreateFrame("Frame", "ItemsCollectTrackerDialog", UIParent, "BackdropTemplate")
ns.dialog = D
D:SetSize(WIDTH, 112)
D:SetFrameStrata("DIALOG")
D:SetClampedToScreen(true)
D:EnableMouse(true)
D:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
D:SetBackdropColor(0.05, 0.05, 0.07, 0.92)
D:SetBackdropBorderColor(1, 1, 1, 0.12)
D:Hide()
tinsert(UISpecialFrames, "ItemsCollectTrackerDialog")

local function Box(parent, width)
    local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    e:SetSize(width, 24)
    e:SetAutoFocus(false)
    e:SetFontObject("ChatFontNormal")
    e:SetTextInsets(6, 6, 0, 0)
    e:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    e:SetBackdropColor(0, 0, 0, 0.5)
    e:SetBackdropBorderColor(1, 1, 1, 0.2)
    e:HookScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(0.5, 0.8, 1, 0.7) end)
    e:HookScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(1, 1, 1, 0.2) end)
    return e
end

local function SmallButton(parent, text, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetText(text)
    b:SetSize(math.max(64, b:GetFontString():GetStringWidth() + 20), 22)
    b:SetScript("OnClick", onClick)
    return b
end

-- The slot on the left: the chosen item, or an empty slot to drop one on.
local slot = CreateFrame("Button", nil, D)
slot:SetSize(40, 40)
slot:SetPoint("TOPLEFT", 10, -10)
slot.bg = slot:CreateTexture(nil, "BACKGROUND")
slot.bg:SetAllPoints()
slot.bg:SetColorTexture(0, 0, 0, 0.5)
slot.icon = slot:CreateTexture(nil, "ARTWORK")
slot.icon:SetPoint("TOPLEFT", 1, -1)
slot.icon:SetPoint("BOTTOMRIGHT", -1, 1)
slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
slot.plus = slot:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
slot.plus:SetPoint("CENTER")
slot.plus:SetText("?")
slot:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

local title = D:CreateFontString(nil, "ARTWORK", "GameFontNormal")
title:SetPoint("TOPLEFT", slot, "TOPRIGHT", 10, 0)
title:SetPoint("RIGHT", -28, 0)
title:SetJustifyH("LEFT")
title:SetWordWrap(false)

local close = CreateFrame("Button", nil, D, "UIPanelCloseButton")
close:SetSize(22, 22)
close:SetPoint("TOPRIGHT", -2, -2)
close:SetScript("OnClick", function() D:Hide() end)

local nameBox = Box(D, WIDTH - 70)
nameBox:SetPoint("TOPLEFT", slot, "TOPRIGHT", 10, -18)

local goalBox = Box(D, 80)
goalBox:SetPoint("TOPLEFT", slot, "TOPRIGHT", 10, -18)
goalBox:SetNumeric(true)
goalBox:SetMaxLetters(7)
goalBox:SetJustifyH("CENTER")

local okButton = SmallButton(D, OKAY or "OK", function() D:Confirm() end)
okButton:SetPoint("LEFT", goalBox, "RIGHT", 8, 0)

local note = D:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
note:SetPoint("TOPLEFT", slot, "BOTTOMLEFT", 0, -10)
note:SetPoint("RIGHT", -10, 0)
note:SetJustifyH("LEFT")

D.step, D.itemID = "name", nil

local function SetSlot(id)
    slot.icon:SetShown(id ~= nil)
    slot.plus:SetShown(id == nil)
    if id then slot.icon:SetTexture(ns.ItemIcon(id)) end
end

local function Fit()
    D:SetHeight(math.max(60, 10 + 40 + 10 + note:GetStringHeight() + 12))
end

local function SetNote(text, isError)
    note:SetText(text or "")
    if isError then note:SetTextColor(1, 0.35, 0.3) else note:SetTextColor(0.6, 0.6, 0.6) end
    Fit()
end

-- Step 1: which item.
local function ShowNameStep(text)
    D.step, D.itemID = "name", nil
    SetSlot(nil)
    title:SetText(L["Add an item"])
    goalBox:Hide(); okButton:Hide()
    nameBox:Show()
    nameBox:SetText(text or "")
    SetNote(L["Type a name and pick it from the list, shift-click an item, or drop it on the slot."])
    nameBox:SetFocus()
    if text then nameBox:HighlightText() end
end

-- Step 2: how many.
local function ShowGoalStep(id)
    Popup:Hide()
    D.step, D.itemID = "goal", id
    SetSlot(id)
    local item = ns.FindItem(id)
    title:SetText(ns.ColoredName(id, item and item.name))
    nameBox:Hide()
    goalBox:Show(); okButton:Show()
    okButton:SetText(item and (SAVE or "Save") or ADD or "Add")
    local goal = item and item.goal
    if not goal then
        local stack = ns.ItemStackSize(id)
        goal = (stack and stack > 1) and stack or 1
    end
    goalBox:SetText(tostring(goal))
    if item then
        SetNote(string.format(L["How many to collect? Collected so far: %d. 0 means no goal: just count."],
            ns.counts[id] or 0))
    else
        SetNote(string.format(L["How many to collect? Counting starts from 0: the %d you have don't count. 0 means no goal: just count."],
            ns.Count(id) or 0))
    end
    goalBox:SetFocus()
    goalBox:HighlightText()
end

local function Choose(id)
    if not id or not ns.ItemExists(id) then
        return SetNote(L["The game doesn't know an item with this ID."], true)
    end
    ShowGoalStep(id)
end

-- Enter in the name box: the highlighted suggestion, else a link, an ID or an exact name.
local function ConfirmName()
    local picked = Popup:Selected()
    if picked then return Choose(picked.id) end
    local kind, value = U.ParseInput(nameBox:GetText())
    if kind == "id" then return Choose(value) end
    if kind == "name" then
        local id = ns.search.Exact(value)
        if id then return Choose(id) end
        return SetNote(L["Can't find this item. Pick it from the list, shift-click it in your bags, or drop it on the slot."], true)
    end
end

function D:Confirm()
    if self.step == "name" then return ConfirmName() end
    local id = self.itemID
    local isNew = not ns.FindItem(id)
    ns.SetItem(id, goalBox:GetText())
    if isNew then
        local item = ns.FindItem(id)
        ns.Print("added %s%s.", ns.ColoredName(id, item.name),
            item.goal > 0 and string.format(L[", goal %d"], item.goal) or "")
    end
    self:Hide()
end

-- The item on the cursor (dragged from the bags), taken off the cursor.
function ns.TakeCursorItem()
    local kind, id = GetCursorInfo()
    if kind ~= "item" or not id then return nil end
    ClearCursor()
    return id
end

local function Dropped()
    local id = ns.TakeCursorItem()
    if id then Choose(id); return true end
end

-- Next to `anchor`: under it, or above it near the bottom of the screen.
local function Place(anchor)
    D:ClearAllPoints()
    if not anchor or not anchor:IsVisible() then return D:SetPoint("CENTER") end
    local bottom = (anchor:GetBottom() or 0) * anchor:GetEffectiveScale() / D:GetEffectiveScale()
    if bottom < 200 then
        D:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 8)
    else
        D:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    end
end

-- Opens on step 1; `text` fills the name box (/ic add Linen Cloth).
function D:OpenAdd(anchor, text)
    Place(anchor)
    self:Show()
    ShowNameStep()
    if text then
        nameBox:SetText(text)
        local kind, value = U.ParseInput(text)
        local id = (kind == "id" and value) or (kind == "name" and ns.search.Exact(value))
        if id and ns.ItemExists(id) then return ShowGoalStep(id) end
        Popup:Open(nameBox, ns.search.Find(text))
    end
end

-- Opens on step 2 for an item on the bar.
function D:OpenGoal(anchor, id)
    Place(anchor)
    self:Show()
    ShowGoalStep(id)
end

------------------------------------------------------------------------
-- Name box: suggestions while typing
------------------------------------------------------------------------
local searchQueued
nameBox:SetScript("OnTextChanged", function(self, userInput)
    if not userInput then return end
    SetNote(L["Type a name and pick it from the list, shift-click an item, or drop it on the slot."])
    if searchQueued then return end
    searchQueued = true
    C_Timer.After(0, function()
        searchQueued = false
        if not nameBox:IsVisible() or not nameBox:HasFocus() then return end
        local text = nameBox:GetText()
        if U.ParseInput(text) == "id" then return Popup:Hide() end
        Popup:Open(nameBox, ns.search.Find(text))
    end)
end)
nameBox:SetScript("OnArrowPressed", function(_, key)
    if not Popup:IsShown() then return end
    if key == "UP" then Popup:Move(-1) elseif key == "DOWN" then Popup:Move(1) end
end)
nameBox:SetScript("OnTabPressed", function()
    if not Popup:IsShown() then return end
    Popup:Move(IsShiftKeyDown() and -1 or 1)
end)
nameBox:SetScript("OnEnterPressed", ConfirmName)
nameBox:SetScript("OnEscapePressed", function(self)
    if Popup:IsShown() then return Popup:Hide() end
    D:Hide()
end)
nameBox:HookScript("OnEditFocusLost", function()
    -- A click on the list takes the focus first: leave the list open for the click.
    if Popup:IsShown() and Popup:IsMouseOver() then return end
    Popup:Hide()
end)
nameBox:SetScript("OnHide", function() Popup:Hide() end)

Popup.onAccept = function(item) Choose(item.id) end

goalBox:SetScript("OnEnterPressed", function() D:Confirm() end)
goalBox:SetScript("OnEscapePressed", function() D:Hide() end)

------------------------------------------------------------------------
-- Dropping and shift-clicking items
------------------------------------------------------------------------
slot:SetScript("OnReceiveDrag", Dropped)
slot:SetScript("OnClick", function()
    if Dropped() then return end
    if D.step == "goal" then ShowNameStep() end -- another item
end)
slot:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    if D.itemID then
        GameTooltip:SetItemByID(D.itemID)
        GameTooltip:AddLine(L["Click to pick another item"], 0.6, 0.6, 0.6)
    else
        GameTooltip:SetText(L["Drop an item here"])
    end
    GameTooltip:Show()
end)
slot:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
D:SetScript("OnReceiveDrag", Dropped)
D:SetScript("OnMouseUp", Dropped)
pcall(nameBox.SetScript, nameBox, "OnReceiveDrag", Dropped)

-- Shift-click on an item while the name box has the focus picks it.
local function OnInsertLink(link)
    if not (D:IsShown() and D.step == "name" and nameBox:HasFocus() and link) then return end
    local id = tonumber(link:match("|Hitem:(%d+)"))
    if id then
        ns.search.AddLink(link)
        Choose(id)
    end
end
if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", OnInsertLink) end
if ChatFrameUtil and ChatFrameUtil.InsertLink then hooksecurefunc(ChatFrameUtil, "InsertLink", OnInsertLink) end

D:SetScript("OnHide", function() Popup:Hide() end)
