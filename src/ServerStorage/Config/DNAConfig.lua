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

-- Какие статы модифицируем аффиксом
Config.AFFIX_STATS = { "Mass", "Jump", "Speed" }

-- Диапазоны аффиксов по РЕДКОСТИ (значения — ДОЛИ, не проценты!)
-- Common:   -5% .. +5%     → -0.05 .. +0.05
-- Uncommon: -15%.. +15%    → -0.15 .. +0.15
-- Rare:     -50%.. +50%    → -0.50 .. +0.50
-- Mythic:   -200%.. +150%  → -2.00 .. +1.50
Config.AFFIX_BY_RARITY = {
	Common   = { min = -0.05, max =  0.05 },
	Uncommon = { min = -0.15, max =  0.15 },
	Rare     = { min = -0.50, max =  0.50 },
	Mythic   = { min = -2.00, max =  1.50 },
}

-- Диапазон веса блока, кг
Config.WEIGHT_MIN = 0.1
Config.WEIGHT_MAX = 5.0

-- 30 «вкусов»
Config.FLAVORS = {
	"Amber","Basalt","Cherry","Citrus","Cobalt","Coral","Crystal","Echo","Fern","Frost",
	"Graphite","Honey","Indigo","Ivy","Jade","Lavender","Lime","Marble","Mint","Moss",
	"Nectar","Obsidian","Petal","Plasma","Quartz","Ruby","Saffron","Slate","Smoke","Velvet",
}

-- Pity: гарантировать >= Rare после N неудачных попыток
Config.PITY_THRESHOLD   = 20
Config.PITY_MIN_RARITY  = "Rare"

return Config
