-- Plain helpers with no frames: text matching, parsing what the player typed, click combinations.
-- They use no game API, so tests/run.lua checks them outside the game.
local _, ns = ...
ns.util = {}
local U = ns.util

------------------------------------------------------------------------
-- Lower case that also knows Cyrillic (string.lower only knows A-Z)
------------------------------------------------------------------------
local CYRILLIC = {}
do
    -- А-Я -> а-я: U+0410..U+042F -> U+0430..U+044F; Ё Є І Ї Ґ -> ё є і ї ґ.
    local function utf8char(cp)
        if cp < 0x800 then
            return string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64)
        end
        return string.char(0xE0 + math.floor(cp / 4096), 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
    end
    for cp = 0x410, 0x42F do CYRILLIC[utf8char(cp)] = utf8char(cp + 0x20) end
    for _, pair in ipairs({ { 0x401, 0x451 }, { 0x404, 0x454 }, { 0x406, 0x456 }, { 0x407, 0x457 }, { 0x490, 0x491 } }) do
        CYRILLIC[utf8char(pair[1])] = utf8char(pair[2])
    end
end

function U.Lower(s)
    if not s then return "" end
    s = s:lower()
    if s:find("[\208\210]") then s = s:gsub("[\208\210][\128-\191]", CYRILLIC) end
    return s
end

function U.Trim(s) return (s or ""):match("^%s*(.-)%s*$") end

------------------------------------------------------------------------
-- What was typed: a link, an item ID or a name
------------------------------------------------------------------------
-- Returns kind, value: "id", 2589 (a link or a number) / "name", "Linen Cloth" / nil when empty.
-- A link pasted by shift-click and a "[Linen Cloth]" typed by hand both work.
function U.ParseInput(text)
    text = U.Trim(text)
    if text == "" then return nil end
    local id = text:match("|Hitem:(%d+)") or text:match("^item:(%d+)") or text:match("^#?(%d+)$")
    if id then return "id", tonumber(id) end
    local name = text:match("^%[(.-)%]$") or text
    return "name", U.Trim(name)
end

------------------------------------------------------------------------
-- How well a name fits what was typed: 1 starts with it, 2 a word starts with it, 3 has it, nil no
------------------------------------------------------------------------
function U.MatchScore(lowerName, query)
    if query == "" then return nil end
    local at = lowerName:find(query, 1, true)
    if not at then return nil end
    if at == 1 then return 1 end
    -- a later word that starts with it: "cloth" in "linen cloth", "bolt" in "bolt of linen"
    local from = 1
    while at do
        local before = lowerName:sub(at - 1, at - 1)
        if before:find("[%s%-%(%[,:']") then return 2 end
        from = at + 1
        at = lowerName:find(query, from, true)
    end
    return 3
end

-- Items of the game nobody can get: monster weapons, deprecated and test items. Left out of the suggestions
-- that come from the game's whole list (items seen in bags or links always show).
local JUNK = { "^monster %- ", "deprecated", "%[ph%]", "^test ", " test$", "qatest", "^zz", "%(old%)",
    "unused", "^npc equip", "dnd" }
function U.IsJunkName(lower)
    for _, p in ipairs(JUNK) do
        if lower:find(p) then return true end
    end
    return false
end

------------------------------------------------------------------------
-- Click combinations: "ctrl" + "LeftButton"
------------------------------------------------------------------------
-- Modifier sets in the settings; "none" means no modifier is held.
U.MODIFIERS = {
    { value = "none",       text = "No modifier" },
    { value = "shift",      text = "Shift" },
    { value = "ctrl",       text = "Ctrl" },
    { value = "alt",        text = "Alt" },
    { value = "ctrl-shift", text = "Ctrl + Shift" },
    { value = "ctrl-alt",   text = "Ctrl + Alt" },
    { value = "alt-shift",  text = "Alt + Shift" },
    { value = "meta",       text = "Cmd", mac = true },
}

U.BUTTONS = {
    { value = "LeftButton",   text = "Left click" },
    { value = "RightButton",  text = "Right click" },
    { value = "MiddleButton", text = "Middle click" },
}

-- held = { shift = bool, ctrl = bool, alt = bool, meta = bool }: true when exactly the modifiers of `mods`
-- are held, so Ctrl+Shift+click doesn't count as Ctrl+click.
function U.ModifiersMatch(mods, held)
    local want = { shift = false, ctrl = false, alt = false, meta = false }
    if mods and mods ~= "none" then
        for m in mods:gmatch("[^%-]+") do want[m] = true end
    end
    for k, v in pairs(want) do
        if (held[k] and true or false) ~= v then return false end
    end
    return true
end

------------------------------------------------------------------------
-- The number on an item
------------------------------------------------------------------------
-- format: "count" -> "12", "goal" -> "12/20", "left" -> "8" (how many are still missing, the count once done)
function U.FormatCount(count, goal, format)
    goal = goal or 0
    if goal > 0 and format == "goal" then return count .. "/" .. goal end
    if goal > 0 and format == "left" and count < goal then return tostring(goal - count) end
    return tostring(count)
end

function U.Reached(count, goal) return goal and goal > 0 and count >= goal or false end
