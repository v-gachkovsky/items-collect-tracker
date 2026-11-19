-- The recipe chosen in the profession window: its reagents go on a bar, as many as the crafts need.
-- Forever and the Classic clients have the old window (TradeSkillFrame, and CraftFrame for enchanting);
-- Retail has the Professions window.
local _, ns = ...
local L = ns.L

local R = {}
ns.recipe = R

local function Shown(name)
    local f = _G[name]
    return f and f.IsShown and f:IsShown()
end

local function ItemID(link)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

-- Old window: the recipe at `i` through the functions of that window.
local function OldRecipe(i, api)
    if not (i and i > 0) then return nil end
    local name, second, third = api.info(i)
    local kind = api.isCraft and third or second -- GetCraftInfo has the rank second, the kind third
    if not name or kind == "header" or kind == "subheader" then return nil end
    local recipe = { name = name, icon = api.icon and api.icon(i), reagents = {} }
    for k = 1, api.count(i) or 0 do
        local _, _, need = api.reagent(i, k)
        local id = ItemID(api.link(i, k))
        if id then recipe.reagents[#recipe.reagents + 1] = { id = id, count = need or 1 } end
    end
    return #recipe.reagents > 0 and recipe or nil
end

local function TradeSkill()
    if not (Shown("TradeSkillFrame") and GetTradeSkillSelectionIndex and GetTradeSkillNumReagents) then return end
    return OldRecipe(GetTradeSkillSelectionIndex(), {
        info = GetTradeSkillInfo, count = GetTradeSkillNumReagents, reagent = GetTradeSkillReagentInfo,
        link = GetTradeSkillReagentItemLink, icon = GetTradeSkillIcon,
    })
end

local function Craft()
    if not (Shown("CraftFrame") and GetCraftSelectionIndex and GetCraftNumReagents) then return end
    return OldRecipe(GetCraftSelectionIndex(), {
        info = GetCraftInfo, count = GetCraftNumReagents, reagent = GetCraftReagentInfo,
        link = GetCraftReagentItemLink, icon = GetCraftIcon, isCraft = true,
    })
end

-- Retail: the basic reagents of the recipe on the crafting page.
local BASIC = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic or 1
local function Professions()
    if not (Shown("ProfessionsFrame") and C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic) then return end
    local page = ProfessionsFrame.CraftingPage
    local form = page and page.SchematicForm
    local ok, info = pcall(function() return form:GetRecipeInfo() end)
    if not (ok and info and info.recipeID) then return end
    local okS, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, info.recipeID, false)
    if not (okS and schematic) then return end
    local recipe = { name = schematic.name or info.name, icon = info.icon, reagents = {} }
    for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
        local first = slot.reagents and slot.reagents[1]
        if (slot.reagentType == nil or slot.reagentType == BASIC) and first and first.itemID then
            recipe.reagents[#recipe.reagents + 1] = { id = first.itemID, count = slot.quantityRequired or 1 }
        end
    end
    return #recipe.reagents > 0 and recipe or nil
end

-- The chosen recipe: { name, icon, reagents = { { id, count }, ... } }, or nil.
function R.Current()
    return Craft() or TradeSkill() or Professions()
end

-- How many crafts the window is set to make.
local function TimesInWindow()
    local box = (Shown("TradeSkillFrame") and _G.TradeSkillInputBox)
        or (Shown("ProfessionsFrame") and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.CreateMultipleInputBox)
    local ok, n = pcall(function() return box.GetValue and box:GetValue() or box:GetNumber() end)
    n = ok and tonumber(n)
    return n and n > 0 and math.floor(n) or 1
end

-- Asks how many crafts, then puts the reagents on the bar.
function R.Open(anchor)
    local recipe = R.Current()
    if not recipe then return ns.Print("open a profession window and pick a recipe first.") end
    ns.dialog:OpenRecipe(anchor, recipe, TimesInWindow())
end

------------------------------------------------------------------------
-- A button in the profession window, left of the craft buttons
------------------------------------------------------------------------
local WINDOWS = {
    { frame = "TradeSkillFrame", next = function() return _G.TradeSkillCreateAllButton or _G.TradeSkillCreateButton end },
    { frame = "CraftFrame", next = function() return _G.CraftCreateButton end },
    { frame = "ProfessionsFrame", next = function()
        local page = ProfessionsFrame.CraftingPage
        return page and (page.CreateAllButton or page.CreateButton)
    end },
}
local attached = {}
R.attached = attached -- [window name] = its button

local function MakeButton(window, nextTo)
    local b = CreateFrame("Button", nil, nextTo:GetParent())
    b:SetSize(22, 22)
    b:SetPoint("RIGHT", nextTo, "LEFT", -6, 0)
    b:SetFrameLevel(nextTo:GetFrameLevel() + 1)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(ns.LOGO)
    icon:SetTexCoord(unpack(ns.LOGO_COORDS))
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnClick", function(self) R.Open(self) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Items Collect Tracker")
        GameTooltip:AddLine(L["Put the reagents of this recipe on the bar."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    attached[window] = b
end

-- Adds the button to every profession window there is now (some load later: Blizzard_TradeSkillUI...).
function R.Attach()
    for _, w in ipairs(WINDOWS) do
        if not attached[w.frame] and _G[w.frame] then
            local ok, nextTo = pcall(w.next)
            if ok and nextTo and nextTo.GetParent then MakeButton(w.frame, nextTo) end
        end
    end
end

function R.Init()
    R.Attach()
    ns.On("ADDON_LOADED", function() R.Attach() end)
    ns.On("TRADE_SKILL_SHOW", function() R.Attach() end)
    ns.On("CRAFT_SHOW", function() R.Attach() end)
end
