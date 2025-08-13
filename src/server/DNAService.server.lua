--!strict
-- Генерация ДНК‑блоков + складирование в player/Blocks через Value-объекты

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local HttpService       = game:GetService("HttpService")

-- Конфиг
local Config = require(ServerStorage:WaitForChild("Config"):WaitForChild("DNAConfig"))

-- ==== RemoteFunction ====
local RF_NAME = "GetRandomBlock"
local GetRandomBlockRF: RemoteFunction = ReplicatedStorage:FindFirstChild(RF_NAME) :: RemoteFunction
if not GetRandomBlockRF then
	GetRandomBlockRF = Instance.new("RemoteFunction")
	GetRandomBlockRF.Name = RF_NAME
	GetRandomBlockRF.Parent = ReplicatedStorage
end

-- ==== Утилиты ====
local function randRange(minVal: number, maxVal: number): number
	return minVal + math.random() * (maxVal - minVal)
end

local function chooseWeighted(weights: {[string]: number}): string
	local total = 0
	for _, w in pairs(weights) do total += w end
	local r = math.random() * total
	local acc = 0
	for key, w in pairs(weights) do
		acc += w
		if r <= acc then return key end
	end
	-- fallback (на всякий случай)
	for k, _ in pairs(weights) do return k end
	return "Common"
end

local function chooseOne<T>(list: {T}): T
	return list[math.random(1, #list)]
end

local function rarityRank(r: string): number
	if r == "Common" then return 1 end
	if r == "Uncommon" then return 2 end
	if r == "Rare" then return 3 end
	if r == "Mythic" then return 4 end
	return 0
end

-- ==== Pity-счётчик ====
local function ensurePity(player: Player)
	if player:GetAttribute("PityCount") == nil then
		player:SetAttribute("PityCount", 0)
	end
end

Players.PlayerAdded:Connect(ensurePity)

local function rollRarityWithPity(player: Player): string
	local pity = player:GetAttribute("PityCount") or 0
	local rolled = chooseWeighted(Config.RARITY_WEIGHTS)

	if rarityRank(rolled) < rarityRank(Config.PITY_MIN_RARITY) then
		pity += 1
		if pity >= Config.PITY_THRESHOLD then
			rolled = Config.PITY_MIN_RARITY
			pity = 0
		end
	else
		pity = 0
	end

	player:SetAttribute("PityCount", pity)
	return rolled
end

-- ==== Генерация баркода/ID ====
local function makeBarcode(player: Player): string
	local salt = string.sub(HttpService:GenerateGUID(false), 1, 4)
	return string.format("%d-%d-%s", player.UserId, os.time(), salt)
end

-- ==== Инвентарь игрока ====
local function getBlocksFolder(player: Player): Folder
	local inv = player:FindFirstChild("Blocks") :: Folder?
	if not inv then
		inv = Instance.new("Folder")
		inv.Name = "Blocks"
		inv.Parent = player
	end
	return inv
end

local function shortId(id: string): string
	return string.sub(id, 1, 8)
end

-- Кладём блок как папку с Value-объектами (НЕ атрибуты)
local function storeBlockInstance(player: Player, data: {[string]: any}): Folder
	local inv = getBlocksFolder(player)

	local blockFolder = Instance.new("Folder")
	blockFolder.Name = string.format("Block_%s", shortId(data.id))
	blockFolder.Parent = inv

	local function newString(name: string, value: string?)
		local v = Instance.new("StringValue")
		v.Name = name
		v.Value = value or ""
		v.Parent = blockFolder
	end
	local function newNumber(name: string, value: number?)
		local v = Instance.new("NumberValue")
		v.Name = name
		v.Value = value or 0
		v.Parent = blockFolder
	end
	local function newInt(name: string, value: number?)
		local v = Instance.new("IntValue")
		v.Name = name
		v.Value = typeof(value) == "number" and math.floor(value :: number) or 0
		v.Parent = blockFolder
	end

	-- Базовые поля
	newString("Id",       data.id)
	newString("Barcode",  data.barcode)
	newString("Rarity",   data.rarity)
	newNumber("WeightKg", data.weightKg)
	newString("Flavor",   data.flavor)
	newInt("CreatedAt",   data.createdAt)
	newInt("Owner",       data.owner or player.UserId)

	-- Аффикс
	local affixFolder = Instance.new("Folder")
	affixFolder.Name = "Affix"
	affixFolder.Parent = blockFolder

	local s1 = Instance.new("StringValue")
	s1.Name = "Stat"
	s1.Value = data.affix and tostring(data.affix.stat) or ""
	s1.Parent = affixFolder

	local s2 = Instance.new("StringValue")
	s2.Name = "PercentStr"
	s2.Value = data.affix and tostring(data.affix.percent) or "" -- формат "+7.5%"
	s2.Parent = affixFolder

	return blockFolder
end

-- ==== Генерация блока (таблица данных) ====
local function generateBlock(player: Player): {[string]: any}
	local rarity = rollRarityWithPity(player)

	-- Вес по РЕДКОСТИ (диапазоны в Config.WEIGHT_BY_RARITY)
	local weightRange = Config.WEIGHT_BY_RARITY[rarity]
	if not weightRange then weightRange = { min = 0.1, max = 3 } end
	local weightKg = randRange(weightRange.min, weightRange.max)
	weightKg = math.floor(weightKg * 100 + 0.5) / 100 -- округление до 0.01 кг

	-- Аффикс по редкости
	local affixStat = chooseOne(Config.AFFIX_STATS)
	local range = Config.AFFIX_BY_RARITY[rarity] or { min = -0.10, max = 0.10 }
	local affixPercent = randRange(range.min, range.max) * 100
	affixPercent = math.floor(affixPercent * 10 + 0.5) / 10 -- до 0.1%

	-- Flavor по редкости с внутренними шансами
	local flavor = "Unknown"
	local flavorWeights = Config.FLAVORS_BY_RARITY and Config.FLAVORS_BY_RARITY[rarity]
	if flavorWeights then
		flavor = chooseWeighted(flavorWeights)
	end

	local barcode = makeBarcode(player)

	return {
		id        = HttpService:GenerateGUID(false),
		barcode   = barcode,
		rarity    = rarity,
		weightKg  = weightKg,
		flavor    = flavor,
		affix     = {
			stat    = affixStat,
			percent = string.format("%+.1f%%", affixPercent),
		},
		createdAt = os.time(),
		owner     = player.UserId,
	}
end

-- ==== Обработчик RemoteFunction ====
GetRandomBlockRF.OnServerInvoke = function(player: Player)
	ensurePity(player)
	local blockData = generateBlock(player)
	storeBlockInstance(player, blockData) -- кладём в player.Blocks
	return blockData                       -- отдаём таблицу клиенту
end

print("[DNAService] Ready: GetRandomBlock() is live")
