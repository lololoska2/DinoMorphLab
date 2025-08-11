--// ServerScriptService/Server/AdminClearBlocks.server.lua
-- Админ-команды: очистка Blocks и выдача блоков в инвентарь

--!strict
local Players             = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerStorage       = game:GetService("ServerStorage")
local HttpService         = game:GetService("HttpService")

-- ==== НАСТРОЙКА ДОСТУПА ====
local ADMIN_USER_IDS = {
	[474079740] = true, -- мой id
}

-- ==== ПОДГРУЗКА КОНФИГА (совместим с DNAService) ====
local Config = require(ServerStorage:WaitForChild("Config"):WaitForChild("DNAConfig"))

-- ==== УТИЛЫ ====
local function isAdmin(plr: Player): boolean
	return ADMIN_USER_IDS[plr.UserId] == true
end

local function shortId(id: string): string
	return string.sub(id, 1, 8)
end

local function getBlocksFolder(player: Player): Folder
	local inv = player:FindFirstChild("Blocks") :: Folder?
	if not inv then
		inv = Instance.new("Folder")
		inv.Name = "Blocks"
		inv.Parent = player
	end
	return inv
end

local function chooseOne<T>(list: {T}): T
	return list[math.random(1, #list)]
end

local function randRange(minVal: number, maxVal: number): number
	return minVal + math.random() * (maxVal - minVal)
end

local function normRarity(s: string): string?
	local m = string.lower(s)
	if m == "common" then return "Common" end
	if m == "uncommon" then return "Uncommon" end
	if m == "rare" then return "Rare" end
	if m == "mythic" then return "Mythic" end
	return nil
end

local function makeBarcode(player: Player): string
	local salt = string.sub(HttpService:GenerateGUID(false), 1, 4)
	return string.format("%d-%d-%s", player.UserId, os.time(), salt)
end

-- ==== СОЗДАНИЕ ИНСТАНСА БЛОКА (Value-дети, НЕ атрибуты) ====
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

	newString("Id",       data.id)
	newString("Barcode",  data.barcode)
	newString("Rarity",   data.rarity)
	newNumber("WeightKg", data.weightKg)
	newString("Flavor",   data.flavor)
	newInt("CreatedAt",   data.createdAt)
	newInt("Owner",       data.owner or player.UserId)

	local affixFolder = Instance.new("Folder")
	affixFolder.Name = "Affix"
	affixFolder.Parent = blockFolder

	local s1 = Instance.new("StringValue")
	s1.Name = "Stat"
	s1.Value = data.affix and tostring(data.affix.stat) or ""
	s1.Parent = affixFolder

	local s2 = Instance.new("StringValue")
	s2.Name = "PercentStr"
	s2.Value = data.affix and tostring(data.affix.percent) or ""
	s2.Parent = affixFolder

	return blockFolder
end

-- ==== ГЕНЕРАЦИЯ ДАННЫХ БЛОКА (совместимо с DNAService) ====
local function generateBlockFor(player: Player, forcedRarity: string?): {[string]: any}
	local rarity = forcedRarity or "Common"

	-- вес по редкости
	local weightRange = Config.WEIGHT_BY_RARITY[rarity] or { min = 0.1, max = 3 }
	local weightKg = randRange(weightRange.min, weightRange.max)
	weightKg = math.floor(weightKg * 100 + 0.5) / 100 -- окр. до 0.01

	-- аффикс
	local affixStat = chooseOne(Config.AFFIX_STATS)
	local range = Config.AFFIX_BY_RARITY[rarity] or { min = -0.10, max = 0.10 }
	local affixPercent = randRange(range.min, range.max) * 100
	affixPercent = math.floor(affixPercent * 10 + 0.5) / 10

	return {
		id        = HttpService:GenerateGUID(false),
		barcode   = makeBarcode(player),
		rarity    = rarity,
		weightKg  = weightKg,
		flavor    = chooseOne(Config.FLAVORS),
		affix     = {
			stat    = affixStat,
			percent = string.format("%+.1f%%", affixPercent),
		},
		createdAt = os.time(),
		owner     = player.UserId,
	}
end

-- ==== ОЧИСТКА ИНВЕНТАРЯ (ОНЛАЙН) ====
local function clearBlocksOnline(target: Player): number
	local folder = target:FindFirstChild("Blocks")
	if not folder then return 0 end
	local count = #folder:GetChildren()
	for _, child in ipairs(folder:GetChildren()) do
		child:Destroy()
	end
	target:SetAttribute("PityCount", 0)
	return count
end

-- ==== ПОМОЩНИКИ ====
local function findPlayerByName(name: string): Player?
	for _, p in ipairs(Players:GetPlayers()) do
		if string.lower(p.Name) == string.lower(name) then
			return p
		end
	end
	return nil
end

-- ==== ПАРСЕР КОМАНД ====
local function handleCommand(from: Player, raw: string)
	if not isAdmin(from) then return end
	if not raw or raw == "" then return end

	-- ---------- CLEAR ----------
	if raw:sub(1, 12) == "/clearblocks" then
		local parts = {}
		for token in string.gmatch(raw, "%S+") do table.insert(parts, token) end

		if #parts == 1 then
			local n = clearBlocksOnline(from)
			print(("[Admin] %s очистил %d блоков у себя"):format(from.Name, n))
			return
		end

		if parts[2] == "user" and parts[3] then
			local target = findPlayerByName(parts[3])
			if target then
				local n = clearBlocksOnline(target)
				print(("[Admin] %s очистил %d блоков у %s"):format(from.Name, n, target.Name))
			end
			return
		end

		if parts[2] == "id" and parts[3] then
			local uid = tonumber(parts[3])
			if not uid then return end
			for _, p in ipairs(Players:GetPlayers()) do
				if p.UserId == uid then
					local n = clearBlocksOnline(p)
					print(("[Admin] %s очистил %d блоков у %s(%d)"):format(from.Name, n, p.Name, uid))
					break
				end
			end
			return
		end

		warn("[Admin] /clearblocks | /clearblocks user <name> | /clearblocks id <userId>")
		return
	end

	-- ---------- GIVEBLOCK ----------
	if raw:sub(1, 10) == "/giveblock" then
		local parts = {}
		for token in string.gmatch(raw, "%S+") do table.insert(parts, token) end

		-- варианты:
		-- /giveblock rare
		-- /giveblock rare x3
		-- /giveblock user Name rare x5
		-- /giveblock id 12345 mythic x2

		local tgt: Player = from
		local rarityStr: string? = nil
		local count = 1

		local i = 2
		if parts[i] == "user" and parts[i+1] then
			local p = findPlayerByName(parts[i+1])
			if p then tgt = p end
			i = i + 2
		elseif parts[i] == "id" and parts[i+1] then
			local uid = tonumber(parts[i+1])
			if uid then
				for _, p in ipairs(Players:GetPlayers()) do
					if p.UserId == uid then tgt = p break end
				end
			end
			i = i + 2
		end

		if parts[i] then
			rarityStr = normRarity(parts[i])
			i = i + 1
		end
		if not rarityStr then
			warn("[Admin] Укажи редкость: common|uncommon|rare|mythic")
			return
		end

		if parts[i] and string.sub(parts[i], 1, 1) == "x" then
			local n = tonumber(string.sub(parts[i], 2))
			if n and n > 0 then count = math.min(n, 100) end -- safety лимит
		end

		for _ = 1, count do
			local data = generateBlockFor(tgt, rarityStr)
			storeBlockInstance(tgt, data)
		end

		print(("[Admin] %s выдал %d блок(ов) [%s] игроку %s")
			:format(from.Name, count, rarityStr, tgt.Name))
		return
	end
end

-- ==== ПОДПИСКА НА ЧАТ ====
Players.PlayerAdded:Connect(function(plr)
	plr.Chatted:Connect(function(msgText)
		handleCommand(plr, msgText)
	end)
end)
