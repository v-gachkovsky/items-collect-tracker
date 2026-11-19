-- Checks the helpers in Util.lua outside the game: lua tests/run.lua (from the repository root).
local ns = {}
assert(loadfile("ItemsCollectTracker/Util.lua"))("ItemsCollectTracker", ns)
local U = ns.util

local failed, passed = 0, 0
local function eq(name, got, want)
    if got == want then
        passed = passed + 1
    else
        failed = failed + 1
        print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
    end
end

-- Lower
eq("lower latin", U.Lower("Linen Cloth"), "linen cloth")
eq("lower cyrillic", U.Lower("Лляна Тканина"), "лляна тканина")
eq("lower ukrainian letters", U.Lower("ЄІЇҐЁ"), "єіїґё")
eq("lower nil", U.Lower(nil), "")

-- ParseInput
local function parse(text) local k, v = U.ParseInput(text); return tostring(k) .. ":" .. tostring(v) end
eq("parse empty", parse("   "), "nil:nil")
eq("parse id", parse("2589"), "id:2589")
eq("parse #id", parse("#2589"), "id:2589")
eq("parse link", parse("|cffffffff|Hitem:2589::::::::60:::::|h[Linen Cloth]|h|r"), "id:2589")
eq("parse item:", parse("item:2589"), "id:2589")
eq("parse name", parse("  Linen Cloth "), "name:Linen Cloth")
eq("parse [name]", parse("[Linen Cloth]"), "name:Linen Cloth")

-- MatchScore
eq("score start", U.MatchScore("linen cloth", "lin"), 1)
eq("score word", U.MatchScore("linen cloth", "clo"), 2)
eq("score word after paren", U.MatchScore("elixir (old)", "old"), 2)
eq("score inside", U.MatchScore("linen cloth", "nen"), 3)
eq("score later word after inside hit", U.MatchScore("bolt of silk", "o"), 2)
eq("score none", U.MatchScore("linen cloth", "silk"), nil)
eq("score empty", U.MatchScore("linen cloth", ""), nil)
eq("score plain find", U.MatchScore("a.b", "."), 3)

-- IsJunkName
eq("junk monster", U.IsJunkName("monster - sword, 1h"), true)
eq("junk deprecated", U.IsJunkName("deprecated elixir"), true)
eq("not junk", U.IsJunkName("old crafty"), false)
eq("not junk cloth", U.IsJunkName("linen cloth"), false)

-- ModifiersMatch
local function held(s)
    local h = {}
    for m in s:gmatch("%a+") do h[m] = true end
    return h
end
eq("ctrl exact", U.ModifiersMatch("ctrl", held("ctrl")), true)
eq("ctrl with shift", U.ModifiersMatch("ctrl", held("ctrl shift")), false)
eq("ctrl-shift", U.ModifiersMatch("ctrl-shift", held("shift ctrl")), true)
eq("none", U.ModifiersMatch("none", held("")), true)
eq("none with alt", U.ModifiersMatch("none", held("alt")), false)
eq("alt missing", U.ModifiersMatch("alt", held("")), false)

-- FormatCount / Reached
eq("count", U.FormatCount(12, 20, "count"), "12")
eq("goal", U.FormatCount(12, 20, "goal"), "12/20")
eq("goal none", U.FormatCount(12, 0, "goal"), "12")
eq("left", U.FormatCount(12, 20, "left"), "8")
eq("left done", U.FormatCount(25, 20, "left"), "25")
eq("reached", U.Reached(20, 20), true)
eq("not reached", U.Reached(19, 20), false)
eq("no goal", U.Reached(100, 0), false)

-- Rate, SplitDuration, MoveInList
eq("no rate without gains", U.Rate({}, 1000), nil)
eq("rate over an hour", U.Rate({ { t = 0, d = 30 }, { t = 1800, d = 30 } }, 3600), 60)
eq("rate: a burst counts over 5 minutes", U.Rate({ { t = 100, d = 10 } }, 110), 120)
eq("rate: old gains don't count", U.Rate({ { t = 0, d = 500 }, { t = 4000, d = 10 } }, 4300), 120)
local gains = { { t = 0, d = 1 }, { t = 100, d = 1 }, { t = 3700, d = 1 } }
U.PruneGains(gains, 3650)
eq("prune old gains", #gains == 2 and gains[1].t == 100, true)
local h, m = U.SplitDuration(3700)
eq("duration 1 h 2 min", h == 1 and m == 2, true)
h, m = U.SplitDuration(5)
eq("duration under a minute is a minute", h == 0 and m == 1, true)
local list = { "a", "b", "c", "d" }
U.MoveInList(list, 1, 3)
eq("move forward", table.concat(list), "bcad")
U.MoveInList(list, 4, 2)
eq("move back", table.concat(list), "bdca")
U.MoveInList(list, 2, 9)
eq("move past the end", table.concat(list), "bcad")

-- MinimapButton.Offset (pure Lua part of MinimapButton.lua)
local mb = assert(loadfile("ItemsCollectTracker/MinimapButton.lua"))("ItemsCollectTracker", { L = {} })
local function near(a, b) return math.abs(a - b) < 0.01 end
local x, y = mb.Offset(0, 140, 140)
eq("offset right", near(x, 75) and near(y, 0), true)
x, y = mb.Offset(90, 140, 140)
eq("offset up", near(x, 0) and near(y, 75), true)
x, y = mb.Offset(45, 140, 140, "SQUARE")
eq("offset square corner", near(x, 75) and near(y, 75), true)
x, y = mb.Offset(45, 140, 140, "CORNER-BOTTOMLEFT")
eq("offset square away from the round corner", near(x, 75) and near(y, 75), true)
x, y = mb.Offset(225, 140, 140, "CORNER-BOTTOMLEFT")
eq("offset round at the round corner", near(x, -75 * math.cos(math.rad(45))) and near(y, x), true)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
