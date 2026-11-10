-- The list of suggestions under the item name box. Shows up to VISIBLE rows; the wheel scrolls the rest.
local _, ns = ...

local VISIBLE, ROW, PAD = 10, 20, 3

local Popup = CreateFrame("Frame", "ItemsCollectTrackerPopup", UIParent, "BackdropTemplate")
ns.Popup = Popup
Popup:SetFrameStrata("TOOLTIP")
Popup:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
Popup:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
Popup:SetBackdropBorderColor(1, 1, 1, 0.12)
Popup:EnableMouse(true)
Popup:Hide()

Popup.items, Popup.rows, Popup.selected, Popup.offset = {}, {}, 1, 0
Popup.onAccept = nil -- function(item)

local function ShowTip(row)
    if not row.item then return end
    GameTooltip:SetOwner(Popup, "ANCHOR_NONE")
    GameTooltip:SetPoint("TOPLEFT", Popup, "TOPRIGHT", 4, 0)
    GameTooltip:SetItemByID(row.item.id)
    GameTooltip:Show()
end

local function Row(i)
    local row = CreateFrame("Button", nil, Popup)
    row:SetHeight(ROW)
    row:SetPoint("TOPLEFT", PAD, -PAD - (i - 1) * ROW)
    row:SetPoint("TOPRIGHT", -PAD, -PAD - (i - 1) * ROW)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.5, 0.8, 1, 0.18)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW - 4, ROW - 4)
    row.icon:SetPoint("LEFT", 2, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.hint = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.hint:SetPoint("RIGHT", -4, 0)
    row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetPoint("RIGHT", row.hint, "LEFT", -6, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row:SetScript("OnClick", function()
        Popup.selected = Popup.offset + i
        Popup:Accept()
    end)
    row:SetScript("OnEnter", function(self)
        Popup.selected = Popup.offset + i
        Popup:Refresh()
        ShowTip(self)
    end)
    row:SetScript("OnLeave", function() if GameTooltip:IsOwned(Popup) then GameTooltip:Hide() end end)
    return row
end

function Popup:Refresh()
    for i = 1, VISIBLE do
        local row = self.rows[i]
        local index = self.offset + i
        local item = self.items[index]
        if row then row:SetShown(item ~= nil) end
        if item then
            row = row or Row(i)
            self.rows[i] = row
            row.item = item
            row.icon:SetTexture(item.icon)
            row.text:SetText(ns.ColoredName(item.id, item.name))
            row.hint:SetText(item.hint or "")
            row.bg:SetShown(index == self.selected)
            row:Show()
        end
    end
end

local function MaxOffset() return math.max(0, #Popup.items - VISIBLE) end

function Popup:Scroll(offset)
    self.offset = math.max(0, math.min(MaxOffset(), offset))
    self:Refresh()
end

-- Shows `items` under `owner` (above it near the bottom of the screen), or hides when there are none.
function Popup:Open(owner, items)
    if #items == 0 then return self:Hide() end
    self.items, self.selected, self.offset = items, 1, 0
    local rows = math.min(#items, VISIBLE)
    self:SetSize(math.max(owner:GetWidth(), 260), rows * ROW + PAD * 2)
    self:ClearAllPoints()
    local bottom = owner:GetBottom() or 0
    if bottom * owner:GetEffectiveScale() < self:GetHeight() * self:GetEffectiveScale() + 40 then
        self:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 2)
    else
        self:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    end
    self:Refresh()
    self:Show()
end

-- Up / Down go round the list; PageUp / PageDown stop at its ends.
function Popup:Move(delta)
    local n = #self.items
    if n == 0 then return end
    if math.abs(delta) == 1 then
        self.selected = (self.selected - 1 + delta) % n + 1
    else
        self.selected = math.max(1, math.min(n, self.selected + delta))
    end
    if self.selected <= self.offset then
        self.offset = self.selected - 1
    elseif self.selected > self.offset + VISIBLE then
        self.offset = self.selected - VISIBLE
    end
    self:Scroll(self.offset)
end

function Popup:Selected() return self:IsShown() and self.items[self.selected] or nil end

function Popup:Accept()
    local item = self:Selected()
    self:Hide()
    if item and self.onAccept then self.onAccept(item) end
end

Popup:EnableMouseWheel(true)
Popup:SetScript("OnMouseWheel", function(self, delta) self:Scroll(self.offset - delta * 3) end)
Popup:SetScript("OnHide", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
