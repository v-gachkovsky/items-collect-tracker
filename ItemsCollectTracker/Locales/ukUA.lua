local _, ns = ...

ns.LOCALES.ukUA = {
    -- Adding an item
    ["Add an item"] = "Додати предмет",
    ["Type a name and pick it from the list, shift-click an item, or drop it on the slot."] =
        "Введіть назву й виберіть зі списку, натисніть на предмет із Shift або перетягніть його в комірку.",
    ["How many to collect? Counting starts from 0: the %d you have don't count. 0 means no goal: just count."] =
        "Скільки зібрати? Рахунок почнеться з 0: ті %d, що вже є, не рахуються. 0 - без мети, лише рахувати.",
    ["How many to collect? Collected so far: %d. 0 means no goal: just count."] =
        "Скільки зібрати? Вже зібрано: %d. 0 - без мети, лише рахувати.",
    ["The game doesn't know an item with this ID."] = "Гра не знає предмета з таким ID.",
    ["Can't find this item. Pick it from the list, shift-click it in your bags, or drop it on the slot."] =
        "Не знайшов такого предмета. Виберіть його зі списку, натисніть на нього в сумці з Shift або перетягніть у комірку.",
    [", goal %d"] = ", мета %d",
    ["Click to pick another item"] = "Клацніть, щоб вибрати інший предмет",
    ["Drop an item here"] = "Перетягніть предмет сюди",
    ["added %s%s."] = "додано %s%s.",

    -- The bar
    ["Settings"] = "Налаштування",
    ["Click: type a name. Or drop an item from your bags here."] =
        "Клацніть, щоб ввести назву. Або перетягніть сюди предмет із сумки.",
    ["Drag: move the bar"] = "Перетягування: рухати панель",
    ["Right click: menu"] = "Правий клік: меню",
    ["Collected"] = "Зібрано",
    ["Still needed"] = "Ще треба",
    ["You have"] = "Усього є",
    ["%s: remove"] = "%s: прибрати",
    ["Right click: goal, order, settings"] = "Правий клік: мета, порядок, налаштування",
    ["Change the goal..."] = "Змінити мету...",
    ["Count from 0 again"] = "Рахувати знову з 0",
    ["Move left"] = "Посунути ліворуч",
    ["Move right"] = "Посунути праворуч",
    ["Remove"] = "Прибрати",
    ["Drag to resize"] = "Тягніть, щоб змінити розмір",

    -- Chat
    ["settings"] = "налаштування",
    ["item"] = "предмет",
    ["add an item"] = "додати предмет",
    ["show or hide the minimap button"] = "показати або сховати кнопку біля мінімапи",

    -- Minimap button
    ["Click: settings"] = "Клік: налаштування",
    ["Drag: move the button"] = "Перетягування: рухати кнопку",
    ["Minimap button"] = "Кнопка біля мінімапи",
    ["goal reached: %s x%d."] = "мету досягнуто: %s x%d.",
    ["removed %s."] = "прибрано %s.",
    ["commands:"] = "команди:",
    ["settings reset."] = "налаштування скинуто.",
    ["can't play %s. A new file needs a full restart of the game."] =
        "не вдається відтворити %s. Новий файл потребує повного перезапуску гри.",
    ["added %s, but it doesn't play yet: check the name, or restart the game (new files need a full restart)."] =
        "додано %s, але він поки не грає: перевірте назву або перезапустіть гру (нові файли потребують повного перезапуску).",

    -- Fonts, outlines, sounds
    ["%s (your file)"] = "%s (ваш файл)",
    ["None"] = "Без обведення",
    ["Outline"] = "Обведення",
    ["Thick outline"] = "Товсте обведення",
    ["Pixel outline"] = "Піксельне обведення",
    ["Quest Complete"] = "Завдання виконано",
    ["Level Up"] = "Новий рівень",
    ["Ready Check"] = "Перевірка готовності",
    ["Raid Warning"] = "Попередження рейду",
    ["Auction House"] = "Аукціон",
    ["Coins"] = "Монети",
    ["Alarm Clock 1"] = "Будильник 1",
    ["Alarm Clock 2"] = "Будильник 2",
    ["Alarm Clock 3"] = "Будильник 3",
    ["Boss Emote"] = "Емоція боса",
    ["Queue Ready"] = "Черга готова",
    ["Group Invite"] = "Запрошення в групу",
    ["Whisper"] = "Шепіт",
    ["Map Ping"] = "Позначка на мапі",

    -- Settings
    ["Reset all settings to the defaults? The items on the bar stay."] =
        "Скинути всі налаштування до початкових? Предмети на панелі залишаться.",
    ["Open settings (/ic)"] = "Відкрити налаштування (/ic)",
    ["Now: %s on an item takes it off the bar."] = "Зараз: %s на предметі прибирає його з панелі.",
    ["Language"] = "Мова",
    ["Hide the bar in combat"] = "Ховати панель у бою",
    ["Grey out items you have none of"] = "Сірі іконки для предметів, яких немає",
    ["The game knows what's in your bank after you open it once."] =
        "Гра знає, що у вашому банку, після того як ви раз його відкриєте.",
    ["The + button"] = "Кнопка +",
    ["Icon size"] = "Розмір іконок",
    ["Space between icons"] = "Відстань між іконками",
    ["Items in a row"] = "Предметів у рядку",
    ["Opacity when the mouse is away, %"] = "Непрозорість без миші, %",
    ["Background, %"] = "Тло, %",
    ["Number"] = "Число",
    ["Where"] = "Де",
    ["Shows"] = "Що показує",
    ["Font"] = "Шрифт",
    ["Size"] = "Розмір",
    ["Color"] = "Колір",
    ["Color when the goal is reached"] = "Колір, коли мету досягнуто",
    ["Goal reached"] = "Мету досягнуто",
    ["Play a sound"] = "Грати звук",
    ["Sound"] = "Звук",
    ["Your sound file"] = "Ваш звуковий файл",
    ["Put .ogg or .mp3 files in World of Warcraft\\_forever_\\Interface\\ItemsCollectTrackerSounds\\ and restart the game, then type the file name here (coins.ogg) and press Enter. A full path from Interface\\ works too."] =
        "Покладіть файли .ogg або .mp3 у World of Warcraft\\_forever_\\Interface\\ItemsCollectTrackerSounds\\ і перезапустіть гру, тоді введіть тут назву файлу (coins.ogg) і натисніть Enter. Повний шлях від Interface\\ теж підходить.",
    ["Remove this file from the list"] = "Прибрати цей файл зі списку",
    ["Write it in the chat"] = "Писати про це в чат",
    ["Removing an item"] = "Як прибрати предмет",
    ["Hold"] = "Тримати",
    ["And click"] = "І клацнути",
    ["Exactly these keys: with Ctrl set, Ctrl+Shift+click doesn't remove. A plain right click set here removes the item instead of opening its menu."] =
        "Саме ці клавіші: якщо вибрано Ctrl, то Ctrl+Shift+клік не прибирає. Якщо вибрати простий правий клік, він прибиратиме предмет замість меню.",
    ["Reset"] = "Скидання",
    ["Reset all settings"] = "Скинути всі налаштування",
    ["Only under the mouse"] = "Лише під мишею",
    ["Always"] = "Завжди",
    ["Below the icon"] = "Під іконкою",
    ["Above the icon"] = "Над іконкою",
    ["On the icon, in the middle"] = "На іконці, посередині",
    ["On the icon, at the top"] = "На іконці, згори",
    ["On the icon, bottom right"] = "На іконці, праворуч унизу",
    ["How many you have: 12"] = "Скільки є: 12",
    ["With the goal: 12/20"] = "З метою: 12/20",
    ["How many are still missing: 8"] = "Скільки ще бракує: 8",
    ["Test"] = "Тест",
    ["No modifier"] = "Без клавіші",
    ["Left click"] = "Лівий клік",
    ["Right click"] = "Правий клік",
    ["Middle click"] = "Середній клік",

    -- 0.1.0-beta3
    ["%d h %d min"] = "%d год %d хв",
    ["%d min"] = "%d хв",
    ["%s x%d: %d reagents added, %d goals raised."] =
        "%s x%d: додано реагентів: %d, збільшено мет: %d.",
    ["A thin progress bar on the icon"] = "Тонка смужка прогресу на іконці",
    ["Bars"] = "Панелі",
    ["Copy from another character..."] = "Скопіювати з іншого персонажа...",
    ["Copy the items of"] = "Скопіювати предмети персонажа",
    ["Drag any icon or the + to move the bar, its bottom right corner to resize it. Shift + drag an icon (or just drag it on locked bars) to put it in another place, on this bar or another one. Right-click the + for more bars and for copying another character's items."] =
        "Тягніть будь-яку іконку або +, щоб рухати панель, а її правий нижній кут, щоб змінити розмір. Shift + перетягування іконки (або просто перетягування на закріплених панелях) ставить її в інше місце, на цій панелі чи на іншій. Правий клік на + додає панелі й копіює предмети іншого персонажа.",
    ["Drag: change the order"] = "Перетягування: змінити порядок",
    ["Goal in"] = "До мети",
    ["Hide items whose goal is reached"] = "Ховати предмети, мету яких досягнуто",
    ["How many times will you craft it? Its %d reagents go on the bar: those you have enough of stay off, and an item on a bar already gets them added to its goal."] =
        "Скільки разів будете крафтити? %d реагентів піде на панель: яких вистачає, ті не додаються, а предмету, що вже на панелі, вони додаються до мети.",
    ["In the bags"] = "У сумках",
    ["In the bank"] = "У банку",
    ["In the mail"] = "На пошті",
    ["Items whose goal is reached, hidden: %d"] = "Сховано предметів із досягнутою метою: %d",
    ["Lock the bars"] = "Закріпити панелі",
    ["Unlock the bars"] = "Відкріпити панелі",
    ["Lock the bars (no moving, no resizing; drag an item to change the order)"] =
        "Закріпити панелі (не рухати й не змінювати розмір; перетягування предмета змінює порядок)",
    ["New bar"] = "Нова панель",
    ["Only what comes after an item is added counts. When you change what counts, its number goes on from where it was."] =
        "Рахується лише те, що прийшло після додавання предмета. Якщо змінити, що рахується, число продовжить з того, де було.",
    ["Other characters"] = "Інші персонажі",
    ["Per hour"] = "За годину",
    ["Put the bars in the middle"] = "Поставити панелі в центр",
    ["Put the reagents of this recipe on the bar."] = "Поставити реагенти цього рецепта на панель.",
    ["Reagents of the open recipe..."] = "Реагенти відкритого рецепта...",
    ["Remove this bar"] = "Прибрати цю панель",
    ["Remove this bar and its %d items?"] = "Прибрати цю панель разом з її предметами (%d)?",
    ["Right click: hide the bars"] = "Правий клік: сховати панелі",
    ["Right click: show the bars"] = "Правий клік: показати панелі",
    ["Shift + drag: change the order"] = "Shift + перетягування: змінити порядок",
    ["Show items whose goal is reached"] = "Показувати предмети, мету яких досягнуто",
    ["Syndicator is here: it remembers the mail and your other characters."] =
        "Syndicator є: він пам'ятає пошту й інших персонажів.",
    ["Syndicator isn't installed: without it the mail and other characters don't count."] =
        "Syndicator не встановлено: без нього пошта й інші персонажі не рахуються.",
    ["The bank"] = "Банк",
    ["The icon flashes"] = "Іконка спалахує",
    ["The mail (with Syndicator)"] = "Пошта (з Syndicator)",
    ["What counts"] = "Що рахувати",
    ["Your other characters: bags, bank and mail (with Syndicator)"] =
        "Інші персонажі: сумки, банк і пошта (з Syndicator)",
    ["a new bar"] = "нова панель",
    ["bars locked: drag an item to change the order."] =
        "панелі закріплено: перетягуйте предмет, щоб змінити порядок.",
    ["bars unlocked: drag an item to move its bar, the corner to resize."] =
        "панелі відкріплено: тягніть предмет, щоб рухати панель, кут, щоб змінити розмір.",
    ["copied %d items from %s."] = "скопійовано предметів: %d, від %s.",
    ["lock or unlock the bars"] = "закріпити або відкріпити панелі",
    ["open a profession window and pick a recipe first."] =
        "спершу відкрийте вікно професії й виберіть рецепт.",
    ["put the bars back in the middle of the screen"] = "повернути панелі в центр екрана",
    ["show or hide the bars"] = "показати або сховати панелі",
    ["the reagents of the recipe open in the profession window"] =
        "реагенти рецепта, відкритого у вікні професії",
    ["you have enough already: %s."] = "вже вистачає: %s.",
}
