-- A small right-click menu in the bar's look: { { text = "...", func = fn, disabled = bool }, { separator = true } }.
local _, ns = ...

local ROW, PAD = 20, 4

local Menu = CreateFrame("Frame", "ItemsCollectTrackerMenu", UIParent, "BackdropTemplate")
ns.Menu = Menu
Menu:SetFrameStrata("FULLSCREEN_DIALOG")
Menu:SetClampedToScreen(true)
Menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
Menu:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
Menu:SetBackdropBorderColor(1, 1, 1, 0.12)
Menu:EnableMouse(true)
Menu:Hide()
tinsert(UISpecialFrames, "ItemsCollectTrackerMenu") -- Escape closes it
Menu.rows = {}

local function Row(i)
    local b = CreateFrame("Button", nil, Menu)
    b:SetHeight(ROW)
    b.hl = b:CreateTexture(nil, "BACKGROUND")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(0.5, 0.8, 1, 0.18)
    b.hl:Hide()
    b.text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    b.text:SetPoint("LEFT", 8, 0)
    b.text:SetJustifyH("LEFT")
    b.line = b:CreateTexture(nil, "ARTWORK")
    b.line:SetColorTexture(1, 1, 1, 0.12)
    b.line:SetHeight(1)
    b.line:SetPoint("LEFT", 4, 0)
    b.line:SetPoint("RIGHT", -4, 0)
    b:SetScript("OnEnter", function(self) if self.entry and self.entry.func and not self.entry.disabled then self.hl:Show() end end)
    b:SetScript("OnLeave", function(self) self.hl:Hide() end)
    b:SetScript("OnClick", function(self)
        local e = self.entry
        if not e or e.disabled or not e.func then return end
        Menu:Hide()
        e.func()
    end)
    return b
end

-- Opens at the cursor.
function Menu:Open(entries)
    local width, y = 120, -PAD
    for i, e in ipairs(entries) do
        local b = self.rows[i] or Row(i)
        self.rows[i] = b
        b.entry = e
        local h = e.separator and 8 or ROW
        b:SetHeight(h)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", PAD, y)
        b:SetPoint("TOPRIGHT", -PAD, y)
        b.line:SetShown(e.separator == true)
        b.text:SetText(e.text or "")
        b.text:SetTextColor(e.disabled and 0.5 or 1, e.disabled and 0.5 or 1, e.disabled and 0.5 or 1)
        b.hl:Hide()
        b:Show()
        if not e.separator then width = math.max(width, b.text:GetStringWidth() + 24) end
        y = y - h
    end
    for i = #entries + 1, #self.rows do self.rows[i]:Hide() end
    self:SetSize(width + PAD * 2, -y + PAD)
    local x, cy = GetCursorPosition()
    local s = self:GetEffectiveScale()
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s + 2, cy / s - 2)
    self:Show()
end

-- A click anywhere else closes it.
Menu:SetScript("OnShow", function(self) pcall(self.RegisterEvent, self, "GLOBAL_MOUSE_DOWN") end)
Menu:SetScript("OnHide", function(self) pcall(self.UnregisterEvent, self, "GLOBAL_MOUSE_DOWN") end)
Menu:SetScript("OnEvent", function(self)
    if not self:IsMouseOver() then self:Hide() end
end)
