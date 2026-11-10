local _, ns = ...

-- Translations: LOCALES[code][English text] = translated text. There is no Ukrainian game client,
-- so the language is picked in the addon settings (ns.db.locale) instead of following GetLocale().
ns.LOCALES = {}

ns.LANGUAGES = {
    { value = "enUS", text = "English" },
    { value = "ukUA", text = "Українська" },
}

-- L[text]: the text in the chosen language, or the English text itself. Looked up when shown,
-- so strings defined before the settings load still follow the language.
ns.L = setmetatable({}, {
    __index = function(_, key)
        local t = ns.db and ns.LOCALES[ns.db.locale]
        return t and t[key] or key
    end,
})
