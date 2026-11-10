-- The bar: an icon per item with its count, and the + that adds the next one. No frame, no background
-- (unless set): only the icons and the numbers. Drag any icon to move it, the corner to resize it.
local _, ns = ...
local L = ns.L
local U = ns.util

local DEFAULT_POINT = { "TOPLEFT", "CENTER", -120, -160 }
local MIN_SIZE, MAX_SIZE = 16, 96
local IDLE_PLUS_ALPHA = 0.45

local function HideTip(owner)
    if GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
end

-- Exactly the modifiers held now.
local function Held()
    return {
        shift = IsShiftKeyDown() and true or false,
        ctrl = IsControlKeyDown() and true or false,
        alt = IsAltKeyDown() and true or false,
        meta = IsMetaKeyDown and IsMetaKeyDown() and true or false,
    }
end

local function TextOf(list, value)
    for _, e in ipairs(list) do
        if e.value == value then return L[e.text] end
    end
    return tostring(value)
end

-- "Ctrl + Left click"
function ns.RemoveComboText()
    local button = TextOf(U.BUTTONS, ns.db.removeButton)
    if ns.db.removeMods == "none" then return button end
    return TextOf(U.MODIFIERS, ns.db.removeMods) .. " + " .. button
end

local function IsRemoveClick(button)
    return button == ns.db.removeButton and U.ModifiersMatch(ns.db.removeMods, Held())
end

------------------------------------------------------------------------
-- Position: the bar's top left corner from the screen's center, so it grows right and down
------------------------------------------------------------------------
local function SavePoint(bar)
    local ux, uy = UIParent:GetCenter()
    local left, top = bar:GetLeft(), bar:GetTop()
    if not ux or not left then return end
    local ratio = UIParent:GetEffectiveScale() / bar:GetEffectiveScale()
    ns.db.point = { "TOPLEFT", "CENTER", left - ux * ratio, top - uy * ratio }
end

local function ApplyPoint(bar)
    if bar.moving or bar.sizing then return end
    local p = ns.db.point or DEFAULT_POINT
    bar:ClearAllPoints()
    bar:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------
function ns.CreateBar()
    local bar = CreateFrame("Frame", "ItemsCollectTrackerBar", UIParent, "BackdropTemplate")
    bar:SetSize(40, 40)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:SetFrameStrata("MEDIUM")
    bar.cells = {}
    local StyleCell

    local function StartMoving()
        if ns.db.locked then return end
        bar.moving = true
        bar:StartMoving()
    end
    local function StopMoving()
        if not bar.moving then return end
        bar:StopMovingOrSizing()
        bar.moving = nil
        if bar.SetUserPlaced then bar:SetUserPlaced(false) end
        SavePoint(bar)
        ApplyPoint(bar)
    end

    local function ShowMenu(entries)
        HideTip(GameTooltip:GetOwner())
        table.insert(entries, { separator = true })
        table.insert(entries, {
            text = ns.db.locked and L["Unlock the bar"] or L["Lock the bar"],
            func = function() ns.db.locked = not ns.db.locked; ns.ApplyAll() end,
        })
        table.insert(entries, { text = L["Settings"], func = ns.ToggleOptions })
        ns.Menu:Open(entries)
    end

    -- An item dropped on the bar: added, or its goal opened when it's there already.
    local function Dropped(anchor)
        local id = ns.TakeCursorItem()
        if not id then return false end
        ns.dialog:OpenGoal(anchor, id)
        return true
    end

    ------------------------------------------------------------------------
    -- The + button
    ------------------------------------------------------------------------
    local plus = CreateFrame("Button", nil, bar)
    bar.plus = plus
    plus:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    plus:RegisterForDrag("LeftButton")
    plus.edges = {}
    for i = 1, 4 do
        local t = plus:CreateTexture(nil, "BORDER")
        t:SetColorTexture(1, 1, 1, 0.35)
        plus.edges[i] = t
    end
    plus.h = plus:CreateTexture(nil, "ARTWORK")
    plus.v = plus:CreateTexture(nil, "ARTWORK")
    plus.h:SetColorTexture(1, 1, 1, 0.9)
    plus.v:SetColorTexture(1, 1, 1, 0.9)
    plus.h:SetPoint("CENTER")
    plus.v:SetPoint("CENTER")
    plus:SetScript("OnClick", function(self, button)
        if Dropped(self) then return end
        if button == "RightButton" then
            return ShowMenu({ { text = L["Add an item"], func = function() ns.dialog:OpenAdd(self) end } })
        end
        if ns.dialog:IsShown() then ns.dialog:Hide() else ns.dialog:OpenAdd(self) end
    end)
    plus:SetScript("OnReceiveDrag", function(self) Dropped(self) end)
    plus:SetScript("OnDragStart", StartMoving)
    plus:SetScript("OnDragStop", StopMoving)
    plus:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        GameTooltip:SetText(L["Add an item"])
        GameTooltip:AddLine(L["Click: type a name. Or drop an item from your bags here."], 1, 1, 1, true)
        if not ns.db.locked then GameTooltip:AddLine(L["Drag: move the bar"], 0.6, 0.6, 0.6) end
        GameTooltip:AddLine(L["Right click: menu"], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    plus:SetScript("OnLeave", HideTip)

    function plus:Style(size)
        self:SetSize(size, size)
        local e = self.edges
        e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(1)
        e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(1)
        e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(1)
        e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(1)
        local len, thick = math.floor(size * 0.45 + 0.5), math.max(2, math.floor(size / 14 + 0.5))
        self.h:SetSize(len, thick)
        self.v:SetSize(thick, len)
    end

    ------------------------------------------------------------------------
    -- Item cells
    ------------------------------------------------------------------------
    local function CellTooltip(cell)
        local item = cell.item
        if not item then return end
        GameTooltip:SetOwner(cell, "ANCHOR_TOPRIGHT")
        GameTooltip:SetItemByID(item.id)
        local n = ns.counts[item.id] or 0
        GameTooltip:AddLine(" ")
        if item.goal > 0 then
            local done = U.Reached(n, item.goal)
            GameTooltip:AddDoubleLine(L["Collected"], n .. " / " .. item.goal, 1, 0.82, 0,
                done and 0.25 or 1, 1, done and 0.25 or 1)
            if not done then GameTooltip:AddDoubleLine(L["Still needed"], item.goal - n, 1, 0.82, 0, 1, 1, 1) end
        else
            GameTooltip:AddDoubleLine(L["Collected"], n, 1, 0.82, 0, 1, 1, 1)
        end
        GameTooltip:AddLine(string.format(L["%s: remove"], ns.RemoveComboText()), 0.6, 0.6, 0.6)
        GameTooltip:AddLine(L["Right click: goal, order, settings"], 0.6, 0.6, 0.6)
        if not ns.db.locked then GameTooltip:AddLine(L["Drag: move the bar"], 0.6, 0.6, 0.6) end
        GameTooltip:Show()
    end

    local function CellMenu(cell)
        local id = cell.item.id
        local _, index = ns.FindItem(id)
        ShowMenu({
            { text = ns.ColoredName(id, cell.item.name), disabled = true },
            { text = L["Change the goal..."], func = function() ns.dialog:OpenGoal(cell, id) end },
            { text = L["Move left"], func = function() ns.MoveItem(id, -1) end, disabled = index == 1 },
            { text = L["Move right"], func = function() ns.MoveItem(id, 1) end, disabled = index == #ns.Items() },
            { text = L["Remove"], func = function() ns.RemoveItem(id) end },
        })
    end

    local function TextRoom()
        local p = ns.db.text.position
        if p == "above" or p == "below" then return math.ceil(ns.db.text.size * 1.15) + 2 end
        return 0
    end

    local function PlaceText(cell)
        local fs, p = cell.count, ns.db.text.position
        fs:ClearAllPoints()
        if p == "above" then
            fs:SetPoint("BOTTOM", cell, "TOP", 0, 2)
        elseif p == "below" then
            fs:SetPoint("TOP", cell, "BOTTOM", 0, -2)
        elseif p == "bottomright" then
            fs:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -1, 2)
        elseif p == "top" then
            fs:SetPoint("TOP", cell, "TOP", 0, -2)
        else
            fs:SetPoint("CENTER", cell, "CENTER", 0, 0)
        end
    end

    -- The number's font and place, from the settings.
    function StyleCell(cell)
        local t = ns.db.text
        ns.ApplyFont(cell.count, t.font, t.size, t.outline)
        cell.count:SetShadowOffset(1, -1)
        cell.count:SetShadowColor(0, 0, 0, t.outline == "" and 1 or 0)
        PlaceText(cell)
    end

    local function Cell(i)
        local cell = CreateFrame("Button", nil, bar)
        cell:RegisterForClicks("AnyUp")
        cell:RegisterForDrag("LeftButton")
        cell.icon = cell:CreateTexture(nil, "ARTWORK")
        cell.icon:SetAllPoints()
        cell.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        cell:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        -- The number sits on its own frame above the icon, so it's never under the highlight.
        cell.over = CreateFrame("Frame", nil, cell)
        cell.over:SetAllPoints()
        cell.over:SetFrameLevel(cell:GetFrameLevel() + 2)
        cell.count = cell.over:CreateFontString(nil, "OVERLAY")
        cell:SetScript("OnClick", function(self, button)
            if Dropped(self) then return end
            if not self.item then return end
            if IsRemoveClick(button) then
                HideTip(self)
                return ns.RemoveItem(self.item.id)
            end
            if button == "RightButton" then return CellMenu(self) end
            if IsModifiedClick and IsModifiedClick("CHATLINK") then
                local _, link = ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(self.item.id)
                if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
            end
        end)
        cell:SetScript("OnReceiveDrag", function(self) Dropped(self) end)
        cell:SetScript("OnDragStart", StartMoving)
        cell:SetScript("OnDragStop", StopMoving)
        cell:SetScript("OnEnter", CellTooltip)
        cell:SetScript("OnLeave", HideTip)
        StyleCell(cell)
        bar.cells[i] = cell
        return cell
    end

    ------------------------------------------------------------------------
    -- Resize grip: drag the corner, the icons grow or shrink
    ------------------------------------------------------------------------
    local grip = CreateFrame("Button", nil, bar)
    bar.grip = grip
    grip:SetSize(12, 12)
    grip:SetPoint("TOPLEFT", bar, "BOTTOMRIGHT", -4, 4)
    grip:SetFrameLevel(bar:GetFrameLevel() + 10)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:Hide()
    grip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Drag to resize"])
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", HideTip)
    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or ns.db.locked then return end
        HideTip(self)
        local x = GetCursorPosition()
        bar.sizing = { x = x / bar:GetEffectiveScale(), width = bar:GetWidth(), size = ns.db.iconSize, cols = bar.cols }
    end)
    grip:SetScript("OnMouseUp", function()
        if not bar.sizing then return end
        bar.sizing = nil
        SavePoint(bar)
        ns.ApplyAll()
    end)
    grip:SetScript("OnUpdate", function()
        local s = bar.sizing
        if not s then return end
        local x = GetCursorPosition() / bar:GetEffectiveScale()
        local width = s.width + (x - s.x)
        local size = (width - (s.cols - 1) * ns.db.spacing) / s.cols
        size = math.max(MIN_SIZE, math.min(MAX_SIZE, math.floor(size + 0.5)))
        if size ~= ns.db.iconSize then
            ns.db.iconSize = size
            bar:Layout()
        end
    end)

    ------------------------------------------------------------------------
    -- Layout and updates
    ------------------------------------------------------------------------
    function bar:Layout()
        local db = ns.db
        local size, gap = db.iconSize, db.spacing
        local room = TextRoom()
        local items = ns.Items()
        local n = #items + 1 -- the + keeps its place, seen or not, so the bar doesn't jump under the mouse
        local cols = math.max(1, math.min(db.columns, n))
        self.cols = cols
        local rows = math.ceil(n / cols)
        local rowH = size + room
        local pad = db.background > 0 and 4 or 0
        local top = (db.text.position == "above") and room or 0
        local function Place(f, i)
            local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", self, "TOPLEFT", pad + col * (size + gap), -pad - top - row * (rowH + gap))
            f:SetSize(size, size)
        end
        for i = 1, #items do Place(self.cells[i], i) end
        Place(plus, n)
        plus:Style(size)
        self:SetSize(pad * 2 + cols * size + (cols - 1) * gap, pad * 2 + rows * rowH + (rows - 1) * gap)
    end

    function bar:Update()
        local items = ns.Items()
        local t = ns.db.text
        for i, item in ipairs(items) do
            local cell = self.cells[i] or Cell(i)
            cell.item = item
            cell.icon:SetTexture(ns.ItemIcon(item.id))
            local n = ns.counts[item.id] or 0
            local done = U.Reached(n, item.goal)
            cell.count:SetText(U.FormatCount(n, item.goal, t.format))
            local c = done and t.doneColor or t.color
            cell.count:SetTextColor(c[1], c[2], c[3], c[4] or 1)
            local missing = ns.db.dimMissing and n == 0
            cell.icon:SetDesaturated(missing)
            cell.icon:SetAlpha(missing and 0.5 or 1)
            cell:Show()
            if GameTooltip:IsOwned(cell) then CellTooltip(cell) end
        end
        for i = #items + 1, #self.cells do
            self.cells[i]:Hide()
            self.cells[i].item = nil
        end
        self:Layout()
        self:UpdateHover(true)
    end

    function bar:ApplySettings()
        for _, cell in ipairs(self.cells) do StyleCell(cell) end
        if ns.db.background > 0 then
            self:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            self:SetBackdropColor(0, 0, 0, ns.db.background)
        else
            self:SetBackdrop(nil)
        end
        ApplyPoint(self)
        self:UpdateVisibility()
        self:Update()
    end

    -- Hidden by /ic hide, or in combat when set. `inCombat` comes from the combat events.
    function bar:UpdateVisibility(inCombat)
        if inCombat == nil then inCombat = InCombatLockdown() end
        self:SetShown(not ns.db.hidden and not (ns.db.hideInCombat and inCombat))
    end

    -- Under the mouse: full opacity, the + and the resize corner show.
    function bar:UpdateHover(force)
        local over = self:IsMouseOver(6, -14, -6, 14) or (ns.Menu:IsShown()) or self.sizing ~= nil
            or (ns.dialog:IsShown())
        if over == self.over and not force then return end
        self.over = over
        self:SetAlpha(over and 1 or ns.db.alpha)
        local showPlus = ns.db.plusButton == "always" or over or #ns.Items() == 0
        plus:SetAlpha(showPlus and (plus:IsMouseOver() and 1 or IDLE_PLUS_ALPHA) or 0)
        grip:SetShown(over and not ns.db.locked)
    end

    local elapsed = 0
    bar:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed < 0.05 then return end
        elapsed = 0
        self:UpdateHover()
        if self.over then plus:SetAlpha(plus:IsMouseOver() and 1 or IDLE_PLUS_ALPHA) end -- brighter under the mouse
    end)

    return bar
end
