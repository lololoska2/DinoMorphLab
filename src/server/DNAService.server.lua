--!strict
-- ServerScriptService/Server/DNAService.server.lua
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local ServerStorage      = game:GetService("ServerStorage")
local HttpService        = game:GetService("HttpService")

local Config = require(ServerStorage:WaitForChild("Config"):WaitForChild("DNAConfig"))

-- === RemoteFunction ===
local remoteName = "GetRandomBlock"
local getRandomBlockRF = ReplicatedStorage:FindFirstChild(remoteName)
if not getRandomBlockRF then
	getRandomBlockRF = Instance.new("RemoteFunction")
	getRandomBlockRF.Name = remoteName
	getRandomBlockRF.Parent = ReplicatedStorage
end

-- === Утилиты ===
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
		if r <= acc then
			return key
		end
	end
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

-- === Pity-счётчик ===
local function ensurePityAttrs(player: Player)
	if player:GetAttribute("PityCount") == nil then
		player:SetAttribute("PityCount", 0)
	end
end

Players.PlayerAdded:Connect(function(plr) ensurePityAttrs(plr) end)

-- === Генерация штрих-кода/ID ===
local function makeBarcode(player: Player): string
	local salt = string.sub(HttpService:GenerateGUID(false), 1, 4)
	return string.format("%d-%d-%s", player.UserId, os.time(), salt)
end

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

-- === Генерация блока ===
local function generateBlock(player: Player): {[string]: any}
	local rarity   = rollRarityWithPity(player)
	local weightKg = math.round(randRange(Config.WEIGHT_MIN, Config.WEIGHT_MAX) * 100) / 100

	local affixStat = chooseOne(Config.AFFIX_STATS)

	-- Новый расчёт аффикса: берём диапазон по редкости
	local range = Config.AFFIX_BY_RARITY[rarity]
	if not range then range = { min = -0.10, max = 0.10 } end -- safety fallback

	-- Генерируем долю и сразу переводим в проценты
	local affixPercent = randRange(range.min, range.max) * 100
	-- Округляем до 1 знака после запятой
	affixPercent = math.floor(affixPercent * 10 + 0.5) / 10

	local flavor  = chooseOne(Config.FLAVORS)
	local barcode = makeBarcode(player)

	local block = {
		id        = HttpService:GenerateGUID(false),
		barcode   = barcode,
		rarity    = rarity,
		weightKg  = weightKg,
		flavor    = flavor,
		affix     = {
			stat    = affixStat,
			percent = string.format("%+.1f%%", affixPercent) -- например "+7.5%" или "-3.0%"
		},
		createdAt = os.time(),
		owner     = player.UserId,
	}
	return block
end

-- === Инвентарь игрока (папка Blocks) ===
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

local function storeBlockInstance(player: Player, data: {[string]: any})
	local inv = getBlocksFolder(player)
	local folder = Instance.new("Folder")
	folder.Name = string.format("Block_%s", shortId(data.id))

	folder:SetAttribute("Rarity",        data.rarity)
	folder:SetAttribute("WeightKg",      data.weightKg)
	folder:SetAttribute("Flavor",        data.flavor)
	folder:SetAttribute("Barcode",       data.barcode)
	folder:SetAttribute("AffixStat",     data.affix.stat)
	folder:SetAttribute("AffixPercent", tostring(data.affix.percent))
	folder:SetAttribute("CreatedAt",     data.createdAt)

	folder.Parent = inv
	return folder
end

-- === RemoteFunction обработчик ===
getRandomBlockRF.OnServerInvoke = function(player: Player)
	ensurePityAttrs(player)
	local blockData = generateBlock(player)
	storeBlockInstance(player, blockData) -- кладём в инвентарь (Blocks)
	return blockData                      -- и отдаём клиенту
end

print("[DNAService] Ready: RemoteFunction GetRandomBlock() is live.")
