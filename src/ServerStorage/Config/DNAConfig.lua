--!strict
-- ServerStorage/Config/DNAConfig.lua
local Config = {}

-- Редкости и веса выпадения (в %; суммарно 100)
Config.RARITY_WEIGHTS = {
	Common   = 75;
	Uncommon = 20;
	Rare     = 4;
	Mythic   = 1;
}

-- Диапазон веса блока, кг
Config.WEIGHT_MIN = 0.1
Config.WEIGHT_MAX = 5.0

-- Аффикс: ±5–10% к случайному стату
Config.AFFIX_PERCENT_MIN = 0.05
Config.AFFIX_PERCENT_MAX = 0.10
Config.AFFIX_STATS = { "Mass", "Jump", "Speed" } -- можно расширить позже

-- 30 «вкусов»
Config.FLAVORS = {
	"Amber","Basalt","Cherry","Citrus","Cobalt","Coral","Crystal","Echo","Fern","Frost",
	"Graphite","Honey","Indigo","Ivy","Jade","Lavender","Lime","Marble","Mint","Moss",
	"Nectar","Obsidian","Petal","Plasma","Quartz","Ruby","Saffron","Slate","Smoke","Velvet",
}

-- Pity: гарантировать >= Rare после N неудачных попыток
Config.PITY_THRESHOLD = 20
Config.PITY_MIN_RARITY = "Rare"

return Config
