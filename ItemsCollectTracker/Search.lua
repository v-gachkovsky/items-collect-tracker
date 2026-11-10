-- Item names for the suggestions while typing. The game can't search items by name, so the addon keeps its
-- own list: items it saw (bags, bank, loot, tooltips: remembered across sessions in ns.db.known) and every
-- item the client knows, read in the background a little each frame after login.
local _, ns = ...
local U = ns.util

local S = {}
ns.search = S

local InfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local Container = C_Container or {}
local NumSlots = Container.GetContainerNumSlots or GetContainerNumSlots
local SlotLink = Container.GetContainerItemLink or GetContainerItemLink

-- Parallel lists: position -> item ID, name, lower-case name. indexOf[id] = position.
local ids, names, lowers = {}, {}, {}
local indexOf = {}

local function Add(id, name, seen)
    if not id or not name or name == "" then return end
    if seen and ns.db.known[id] ~= name then ns.db.known[id] = name end
    local i = indexOf[id]
    if i then
        if names[i] ~= name then names[i], lowers[i] = name, U.Lower(name) end
        return
    end
    local lower = U.Lower(name)
    -- Monster weapons, test and deprecated items from the client's list: only when the player saw them.
    if not seen and not ns.db.known[id] and U.IsJunkName(lower) then return end
    i = #ids + 1
    ids[i], names[i], lowers[i], indexOf[id] = id, name, lower, i
end

-- An item link or a "[Name]" with its ID.
local function AddLink(link)
    local id = link and tonumber(link:match("item:(%d+)"))
    local name = link and link:match("|h%[(.-)%]|h")
    if id and name then Add(id, (name:gsub("|A.-|a", ""):gsub("|T.-|t", "")), true) end
end
S.AddLink = AddLink

local function ScanBags(first, last)
    if not NumSlots then return end
    for bag = first, last do
        for slot = 1, NumSlots(bag) or 0 do AddLink(SlotLink(bag, slot)) end
    end
end

local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
local function ScanInventory()
    ScanBags(0, LAST_BAG)
end

local function ScanBank()
    local bank = BANK_CONTAINER or -1
    ScanBags(bank, bank)
    local first = LAST_BAG + 1
    ScanBags(first, first + (NUM_BANKBAGSLOTS or 7) - 1)
end

------------------------------------------------------------------------
-- Every item the client knows, a few milliseconds per frame
------------------------------------------------------------------------
local SCAN_MAX = 260000       -- highest item ID read
local BUDGET_MS = 3           -- time per frame
local MAX_PENDING = 40        -- names asked from the server and not come yet
local MAX_REQUESTS_PER_SEC = 40
local scanNext = 1
local pending, pendingCount = {}, 0
local requestsThisSecond, second = 0, 0
local scanner = CreateFrame("Frame")
scanner:Hide()

local function Prune(now)
    for id, t in pairs(pending) do
        if now - t > 10 then pending[id] = nil; pendingCount = pendingCount - 1 end
    end
end

scanner:SetScript("OnUpdate", function(self)
    local now = GetTime()
    if math.floor(now) ~= second then
        second, requestsThisSecond = math.floor(now), 0
        Prune(now)
    end
    local start = debugprofilestop()
    while scanNext <= SCAN_MAX and debugprofilestop() - start < BUDGET_MS do
        if pendingCount >= MAX_PENDING or requestsThisSecond >= MAX_REQUESTS_PER_SEC then break end
        local id = scanNext
        scanNext = id + 1
        if not indexOf[id] and InfoInstant(id) then
            local name = ns.ItemName(id)
            if name then
                Add(id, name)
            else
                pending[id] = now
                pendingCount = pendingCount + 1
                requestsThisSecond = requestsThisSecond + 1
            end
        end
    end
    if scanNext > SCAN_MAX and pendingCount <= 0 then self:Hide() end
end)

ns.On("GET_ITEM_INFO_RECEIVED", function(id, success)
    if not id then return end
    if pending[id] then
        pending[id] = nil
        pendingCount = pendingCount - 1
        if success ~= false then Add(id, ns.ItemName(id)) end
    end
end)

function S.Progress() return math.min(1, (scanNext - 1) / SCAN_MAX), #ids end

------------------------------------------------------------------------
-- Searching
------------------------------------------------------------------------
-- How close to the top: items in your bags, then items seen before, then the rest.
local function Rank(i)
    local id = ids[i]
    if not ns.db.known[id] then return 2 end
    local n = ns.Count(id)
    return (n and n > 0) and 0 or 1
end

-- Up to `limit` suggestions for what was typed: { id, name, icon, hint }. One letter looks only at the starts
-- of names; more letters at the starts of words and then anywhere in the name.
function S.Find(text, limit)
    limit = limit or 30
    local q = U.Lower(U.Trim(text))
    if q == "" then return {} end
    local found = {}
    for i = 1, #lowers do
        local score = U.MatchScore(lowers[i], q)
        if score and (#q > 1 or score == 1) then
            found[#found + 1] = { i = i, score = score, rank = Rank(i) }
        end
    end
    table.sort(found, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        if a.rank ~= b.rank then return a.rank < b.rank end
        local la, lb = #lowers[a.i], #lowers[b.i]
        if la ~= lb then return la < lb end
        if lowers[a.i] ~= lowers[b.i] then return lowers[a.i] < lowers[b.i] end
        return ids[a.i] < ids[b.i]
    end)
    -- One item per name and icon: the game keeps old copies of some items under the same name.
    local out, seen, byName = {}, {}, {}
    for _, f in ipairs(found) do
        local id = ids[f.i]
        local icon = ns.ItemIcon(id)
        local key = lowers[f.i] .. "\1" .. tostring(icon)
        if not seen[key] then
            seen[key] = true
            local n = ns.Count(id) or 0
            local entry = { id = id, name = names[f.i], icon = icon, hint = n > 0 and ("x" .. n) or nil }
            out[#out + 1] = entry
            -- Same name, other icon: tell them apart by ID.
            local other = byName[lowers[f.i]]
            if other then
                entry.hint = entry.hint or ("#" .. id)
                other.hint = other.hint or ("#" .. other.id)
            end
            byName[lowers[f.i]] = entry
            if #out >= limit then break end
        end
    end
    return out
end

-- The item with exactly this name (any case), the best one when there are several. Asks the game too: it
-- knows names of items it has loaded.
function S.Exact(name)
    local q = U.Lower(U.Trim(name))
    local best, bestRank
    for i = 1, #lowers do
        if lowers[i] == q then
            local r = Rank(i)
            if not best or r < bestRank then best, bestRank = ids[i], r end
        end
    end
    if best then return best end
    local Info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local _, link = Info(name)
    return link and tonumber(link:match("item:(%d+)"))
end

------------------------------------------------------------------------
-- Start
------------------------------------------------------------------------
local function HookTooltips()
    local function FromTooltip(tip)
        if not tip or not tip.GetItem then return end
        local ok, _, link = pcall(tip.GetItem, tip)
        if ok then AddLink(link) end
    end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, FromTooltip)
    elseif GameTooltip and GameTooltip.HasScript and GameTooltip:HasScript("OnTooltipSetItem") then
        GameTooltip:HookScript("OnTooltipSetItem", FromTooltip)
        if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", FromTooltip) end
    end
end

function S.Init()
    for id, name in pairs(ns.db.known) do
        if type(id) == "number" and type(name) == "string" then Add(id, name, true) end
    end
    for _, item in ipairs(ns.char.items) do
        if item.name then Add(item.id, item.name, true) end
    end
    ScanInventory()
    HookTooltips()
    ns.On("BAG_UPDATE_DELAYED", ScanInventory)
    ns.On("BANKFRAME_OPENED", ScanBank)
    ns.On("CHAT_MSG_LOOT", function(msg)
        for link in (msg or ""):gmatch("|Hitem:[^|]+|h%[.-%]|h") do AddLink(link) end
    end)
    -- The whole list a moment after login, when loading is done.
    C_Timer.After(5, function() scanner:Show() end)
end
