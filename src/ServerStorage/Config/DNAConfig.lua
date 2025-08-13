--!strict
-- Конфигурация генерации ДНК‑блоков

local Config = {}

-- Редкости и веса выпадения (вероятности)
Config.RARITY_WEIGHTS = {
	Common   = 75,
	Uncommon = 20,
	Rare     = 4,
	Mythic   = 1,
}

-- Pity‑система: после N неудачных роллов гарантируется минимум эта редкость
Config.PITY_THRESHOLD  = 20
Config.PITY_MIN_RARITY = "Rare"

-- Доступные статы для аффиксов
Config.AFFIX_STATS = {
	"speed", "jump", "hp", "stamina", "grip"
}

-- Диапазоны аффикса по редкости (в долях от 1.0; ±10% = ±0.10)
Config.AFFIX_BY_RARITY = {
	Common   = { min = -0.05,  max =  0.05  },   -- -5..+5%
	Uncommon = { min = -0.15,  max =  0.15  },   -- -15..+15%
	Rare     = { min = -0.50,  max =  0.50  },   -- -50..+50%
	Mythic   = { min = -2.00,  max =  1.50  },   -- -200..+150%
}

-- Диапазоны веса по редкости (кг)
Config.WEIGHT_BY_RARITY = {
	Common   = { min = 0.1, max = 3  },
	Uncommon = { min = 0.1, max = 7  },
	Rare     = { min = 0.1, max = 15 },
	Mythic   = { min = 0.1, max = 50 },
}

-- ВКУСЫ (FLAVORS) ПО РЕДКОСТИ С ВНУТРЕННИМИ ВЕСАМИ
-- Формат: [редкость] = { [FlavorName] = weight, ... }
-- Распределение по твоему ТЗ (комментарии — русские названия):
Config.FLAVORS_BY_RARITY = {
	Common = {
		Amber    = 95,  -- Янтарь
		Basalt   = 95,  -- Базальт
		Granite  = 95,  -- Гранит
		Marble   = 95,  -- Мрамор
		Silt     = 95,  -- Ил
		Chalk    = 95,  -- Мел
		Lime     = 95,  -- Известь
		Jade     = 5,   -- Нефрит
		Onyx     = 5,   -- Оникс
		Quartz   = 5,   -- Кварц
	},
	Uncommon = {
		Smoke     = 95, -- Дым
		Vine      = 95, -- Лоза
		Frost     = 95, -- Иней
		Cedar     = 95, -- Кедр
		Graphite  = 95, -- Графит
		Obsidian  = 95, -- Обсидиан
		Magnetite = 5,  -- Магнетит
		Ivory     = 5,  -- Слоновая кость
		Ash       = 5,  -- Пепел
	},
	Rare = {
		Fossil  = 95,   -- Окаменелость
		Opal    = 95,   -- Опал
		Cobalt  = 95,   -- Кобальт
		Pearl   = 5,    -- Жемчуг
		Coral   = 5,    -- Коралл
		Topaz   = 5,    -- Топаз
	},
	Mythic = {
		Ruby     = 95,  -- Рубин
		Sapphire = 95,  -- Сапфир
		Blaze    = 95,  -- Пламя
		Nebula   = 5,   -- Туманность
		Cosmic   = 5,   -- Космический
	},
}

return Config
