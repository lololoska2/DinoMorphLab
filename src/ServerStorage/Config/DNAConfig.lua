--!strict
-- Конфигурация генерации ДНК‑блоков

local Config = {}

-- Редкости и веса (сумма не обязана быть 1.0 — нормируется при выборе)
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

-- Веса по редкости (КАК ТЫ ПРОСИЛ)
Config.WEIGHT_BY_RARITY = {
	Common   = { min = 0.1, max = 3  },
	Uncommon = { min = 0.1, max = 7  },
	Rare     = { min = 0.1, max = 15 },
	Mythic   = { min = 0.1, max = 50 },
}

-- Набор «вкусов» (примерные 30; дополняй по вкусу)
Config.FLAVORS = {
	"Amber", "Basalt", "Cobalt", "Jade", "Quartz", "Onyx",
	"Coral", "Ivory", "Magnetite", "Opal", "Pearl", "Ruby",
	"Sapphire", "Topaz", "Obsidian", "Granite", "Marble",
	"Graphite", "Silt", "Fossil", "Chalk", "Ash", "Cedar",
	"Smoke", "Lime", "Nebula", "Cosmic", "Vine", "Blaze", "Frost"
}

return Config
