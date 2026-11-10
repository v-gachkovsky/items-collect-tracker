-- Fonts and sounds the settings offer.
local _, ns = ...
local L = ns.L

ns.FONTS = {
    { value = "Fonts\\FRIZQT__.TTF",     text = "Friz Quadrata" },
    { value = "Fonts\\FRIZQT___CYR.TTF", text = "Friz Quadrata (Cyrillic)" },
    { value = "Fonts\\ARIALN.TTF",       text = "Arial Narrow" },
    { value = "Fonts\\MORPHEUS.TTF",     text = "Morpheus" },
    { value = "Fonts\\SKURRI.TTF",       text = "Skurri" },
}

ns.OUTLINES = {
    { value = "",                     text = "None" },
    { value = "OUTLINE",              text = "Outline" },
    { value = "THICKOUTLINE",         text = "Thick outline" },
    { value = "MONOCHROME, OUTLINE",  text = "Pixel outline" },
}

-- Game sounds by SOUNDKIT key; `id` is the fallback when a client lacks the key.
ns.SOUNDS = {
    { value = "IG_QUEST_LIST_COMPLETE",       text = "Quest Complete",  id = 878 },
    { value = "LEVEL_UP",                     text = "Level Up",        id = 888 },
    { value = "READY_CHECK",                  text = "Ready Check",     id = 8960 },
    { value = "RAID_WARNING",                 text = "Raid Warning",    id = 8959 },
    { value = "AUCTION_WINDOW_OPEN",          text = "Auction House",   id = 5274 },
    { value = "LOOT_WINDOW_COIN_SOUND",       text = "Coins",           id = 120 },
    { value = "ALARM_CLOCK_WARNING_1",        text = "Alarm Clock 1",   id = 12867 },
    { value = "ALARM_CLOCK_WARNING_2",        text = "Alarm Clock 2",   id = 12868 },
    { value = "ALARM_CLOCK_WARNING_3",        text = "Alarm Clock 3",   id = 12889 },
    { value = "RAID_BOSS_EMOTE_WARNING",      text = "Boss Emote",      id = 12197 },
    { value = "PVP_THROUGH_QUEUE",            text = "Queue Ready",     id = 8459 },
    { value = "IG_PLAYER_INVITE",             text = "Group Invite",    id = 880 },
    { value = "TELL_MESSAGE",                 text = "Whisper",         id = 3081 },
    { value = "MAP_PING",                     text = "Map Ping",        id = 3175 },
}

-- Folder for the player's own sound files; a bare file name points here. It lies outside the addon
-- folder, so updating the addon doesn't delete the files.
ns.CUSTOM_SOUND_DIR = "Interface\\ItemsCollectTrackerSounds\\"

local function LSM() return LibStub and LibStub("LibSharedMedia-3.0", true) end

function ns.GetFontList()
    local list, seen = {}, {}
    for _, f in ipairs(ns.FONTS) do list[#list + 1] = f; seen[f.value] = true end
    local lsm = LSM()
    if lsm then
        for _, name in ipairs(lsm:List("font")) do
            local path = lsm:Fetch("font", name)
            if path and not seen[path] then
                list[#list + 1] = { value = path, text = name }
                seen[path] = true
            end
        end
    end
    return list
end

function ns.ApplyFont(fs, path, size, outline)
    local ok = fs:SetFont(path or STANDARD_TEXT_FONT, size, outline or "")
    if ok == false or not fs:GetFont() then fs:SetFont(STANDARD_TEXT_FONT, size, outline or "") end
end

-- Game sounds, then the player's files, then sounds from LibSharedMedia (value = file path).
function ns.GetSoundList()
    local list, seen = {}, {}
    for _, s in ipairs(ns.SOUNDS) do list[#list + 1] = s; seen[s.value] = true end
    for _, c in ipairs(ns.db and ns.db.customSounds or {}) do
        if not seen[c.path] then
            list[#list + 1] = { value = c.path, text = string.format(L["%s (your file)"], c.name) }
            seen[c.path] = true
        end
    end
    local lsm = LSM()
    if lsm then
        for _, name in ipairs(lsm:List("sound")) do
            local path = lsm:Fetch("sound", name)
            if path and path ~= "" and not seen[path] then
                list[#list + 1] = { value = path, text = name }
                seen[path] = true
            end
        end
    end
    return list
end

-- "coins.ogg" -> Interface\ItemsCollectTrackerSounds\coins.ogg; full paths are kept.
function ns.NormalizeSoundPath(path)
    path = (path or ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("/", "\\")
    if path == "" then return nil end
    if not path:lower():find("^interface\\") then path = ns.CUSTOM_SOUND_DIR .. path end
    return path
end

-- Returns whether the sound will play (false for a missing or unreadable file).
function ns.PlaySound(name)
    if not name then return false end
    for _, s in ipairs(ns.SOUNDS) do
        if s.value == name then
            local id = (SOUNDKIT and SOUNDKIT[s.value]) or s.id
            local ok, willPlay = pcall(PlaySound, id, "Master")
            return ok and willPlay ~= false
        end
    end
    local ok, willPlay = pcall(PlaySoundFile, name, "Master")
    return ok and willPlay and true or false
end

-- Adds the player's file to the sound list and picks it. Returns false when it doesn't play.
function ns.AddCustomSound(text)
    local path = ns.NormalizeSoundPath(text)
    if not path then return end
    local name = path:match("([^\\]+)$"):gsub("%.%w+$", "")
    local found
    for _, c in ipairs(ns.db.customSounds) do
        if c.path:lower() == path:lower() then found = c end
    end
    if not found then table.insert(ns.db.customSounds, { name = name, path = path }) end
    ns.db.soundName = path
    if not ns.PlaySound(path) then
        ns.Print("added %s, but it doesn't play yet: check the name, or restart the game (new files need a full restart).", path)
    end
end

function ns.RemoveCustomSound(path)
    for i, c in ipairs(ns.db.customSounds) do
        if c.path == path then table.remove(ns.db.customSounds, i); break end
    end
    if ns.db.soundName == path then ns.db.soundName = ns.defaults.soundName end
end
