--// ServerScriptService/Leaderstats.server.lua
-- Автосейв профиля + инвентарь Blocks через дочерние Value-объекты (НЕ атрибуты)

--!strict
local Players            = game:GetService("Players")
local ServerScriptService= game:GetService("ServerScriptService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local HttpService        = game:GetService("HttpService")

-- ProfileService должен лежать в ServerScriptService/Modules/ProfileService
local ProfileService = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("ProfileService"))

-- ---------- СХЕМА ДАННЫХ ----------
-- Blocks хранится как массив таблиц вида:
-- {
--   id, barcode, rarity, weightKg, flavor,
--   affix = { stat, percent },  -- percent строка вида "+7.5%"
--   createdAt, owner
-- }
local DEFAULTS = {
	GooDNA    = 0,
	Level     = 1,
	XP        = 0,
	Likes     = 0,
	Blocks    = {},
	PityCount = 0,
}

local profileStore = ProfileService.GetProfileStore("DinoMorph_Profile_v1", DEFAULTS)
local Profiles : { [Player]: any } = {}

-- Клиентское событие "сохранилось"
local saveEvent = ReplicatedStorage:FindFirstChild("AutoSaveEvent") :: RemoteEvent?
if not saveEvent then
	saveEvent = Instance.new("RemoteEvent")
	saveEvent.Name = "AutoSaveEvent"
	saveEvent.Parent = ReplicatedStorage
end

-- ---------- УТИЛИТЫ ----------
local function shortId(id: string): string
	return string.sub(id, 1, 8)
end

-- Создание Value-детей
local function newString(name: string, value: string?, parent: Instance)
	local v = Instance.new("StringValue")
	v.Name = name
	v.Value = value or ""
	v.Parent = parent
	return v
end

local function newNumber(name: string, value: number?, parent: Instance)
	local v = Instance.new("NumberValue")
	v.Name = name
	v.Value = value or 0
	v.Parent = parent
	return v
end

local function newInt(name: string, value: number?, parent: Instance)
	local v = Instance.new("IntValue")
	v.Name = name
	v.Value = typeof(value) == "number" and math.floor(value :: number) or 0
	v.Parent = parent
	return v
end

-- ---------- СЕРИАЛИЗАЦИЯ БЛОКА (Folder -> table) ----------
local function readStr(folder: Instance, name: string): string?
	local v = folder:FindFirstChild(name)
	return (v and v:IsA("StringValue")) and v.Value or nil
end

local function readNum(folder: Instance, name: string): number?
	local v = folder:FindFirstChild(name)
	return (v and v:IsA("NumberValue")) and v.Value or nil
end

local function readInt(folder: Instance, name: string): number?
	local v = folder:FindFirstChild(name)
	return (v and v:IsA("IntValue")) and v.Value or nil
end

local function serializeBlockFolder(blockFolder: Folder): {[string]: any}
	-- ожидаем:
	-- Id(String), Barcode(String), Rarity(String), WeightKg(Number), Flavor(String),
	-- CreatedAt(Int), Owner(Int),
	-- Affix(Folder) -> Stat(String), PercentStr(String)
	local affixFolder = blockFolder:FindFirstChild("Affix")
	local affix = nil
	if affixFolder and affixFolder:IsA("Folder") then
		affix = {
			stat    = readStr(affixFolder, "Stat"),
			percent = readStr(affixFolder, "PercentStr"),
		}
	end

	return {
		id        = readStr(blockFolder, "Id") or HttpService:GenerateGUID(false),
		barcode   = readStr(blockFolder, "Barcode"),
		rarity    = readStr(blockFolder, "Rarity"),
		weightKg  = readNum(blockFolder, "WeightKg"),
		flavor    = readStr(blockFolder, "Flavor"),
		affix     = affix,
		createdAt = readInt(blockFolder, "CreatedAt"),
		owner     = readInt(blockFolder, "Owner"),
	}
end

local function serializeBlocksFolder(blocksFolder: Folder): {{[string]: any}}
	local out = {}
	for _, child in ipairs(blocksFolder:GetChildren()) do
		if child:IsA("Folder") then
			table.insert(out, serializeBlockFolder(child))
		end
	end
	return out
end

-- ---------- РАЗГИДРАТАЦИЯ (table -> Folder с Value-детями) ----------
local function hydrateBlockFolder(data: {[string]: any}): Folder
	local id = typeof(data.id) == "string" and data.id or HttpService:GenerateGUID(false)
	local block = Instance.new("Folder")
	block.Name = ("Block_%s"):format(shortId(id))

	newString("Id",        id,                  block)
	newString("Barcode",   data.barcode,        block)
	newString("Rarity",    data.rarity,         block)
	newNumber("WeightKg",  tonumber(data.weightKg), block)
	newString("Flavor",    data.flavor,         block)
	newInt("CreatedAt",    tonumber(data.createdAt), block)
	newInt("Owner",        tonumber(data.owner), block)

	local affixData = data.affix
	local affixFolder = Instance.new("Folder")
	affixFolder.Name = "Affix"
	affixFolder.Parent = block
	newString("Stat",       affixData and tostring(affixData.stat) or "",  affixFolder)
	newString("PercentStr", affixData and tostring(affixData.percent) or "", affixFolder)

	return block
end

local function hydrateBlocksFolder(blocksFolder: Folder, dataArray: {{[string]: any}}?)
	blocksFolder:ClearAllChildren()
	for _, data in ipairs(dataArray or {}) do
		local inst = hydrateBlockFolder(data)
		inst.Parent = blocksFolder
	end
end

-- ---------- ЛАЙВ-СИНХРОНИЗАЦИЯ (любые изменения -> профиль) ----------
local function hookBlocksAutoSync(blocksFolder: Folder, profile)
	local function resave()
		if profile and profile:IsActive() then
			profile.Data.Blocks = serializeBlocksFolder(blocksFolder)
		end
	end

	-- Подписки на любые изменения значений
	local function wire(obj: Instance)
		if obj:IsA("ValueBase") then
			obj.Changed:Connect(resave)
		end
	end

	-- Существующие
	for _, d in ipairs(blocksFolder:GetDescendants()) do
		wire(d)
	end

	-- Новые/удалённые
	blocksFolder.DescendantAdded:Connect(function(obj)
		wire(obj)
		resave()
		end)
	blocksFolder.DescendantRemoving:Connect(function(_)
		resave()
	end)

	blocksFolder.ChildAdded:Connect(resave)
	blocksFolder.ChildRemoved:Connect(resave)

	-- Первичный снимок
	resave()
end

-- ---------- Привязка контейнеров и значений игрока ----------
local function attachStatsContainers(player: Player, profile)
	-- leaderstats
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local goo = Instance.new("IntValue")
	goo.Name = "GooDNA"
	goo.Value = profile.Data.GooDNA
	goo.Parent = leaderstats

	-- скрытые статы
	local hidden = Instance.new("Folder")
	hidden.Name = "PlayerData"
	hidden.Parent = player

	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = profile.Data.Level
	level.Parent = hidden

	local xp = Instance.new("IntValue")
	xp.Name = "XP"
	xp.Value = profile.Data.XP
	xp.Parent = hidden

	local likes = Instance.new("IntValue")
	likes.Name = "Likes"
	likes.Value = profile.Data.Likes
	likes.Parent = hidden

	-- инвентарь
	local blocks = Instance.new("Folder")
	blocks.Name = "Blocks"
	blocks.Parent = player

	-- восстановление из профиля
	hydrateBlocksFolder(blocks, profile.Data.Blocks)
	hookBlocksAutoSync(blocks, profile)

	-- pity как атрибут игрока (можно тоже сделать IntValue, но оставим как атрибут)
	player:SetAttribute("PityCount", tonumber(profile.Data.PityCount) or 0)

	-- пуш базовых статов
	local function pushBase()
		if profile and profile:IsActive() then
            profile.Data.GooDNA    = goo.Value
            profile.Data.Level     = level.Value
            profile.Data.XP        = xp.Value
            profile.Data.Likes     = likes.Value
            profile.Data.PityCount = player:GetAttribute("PityCount") or 0
		end
	end
	goo.Changed:Connect(pushBase)
	level.Changed:Connect(pushBase)
	xp.Changed:Connect(pushBase)
	likes.Changed:Connect(pushBase)
	player:GetAttributeChangedSignal("PityCount"):Connect(pushBase)
end

-- ---------- Автосейв ----------
task.spawn(function()
	while true do
		task.wait(300)
		for player, profile in pairs(Profiles) do
			if profile:IsActive() then
				-- финальная синхронизация инвентаря перед сейвом
				local blocksFolder = player:FindFirstChild("Blocks")
				if blocksFolder then
					profile.Data.Blocks = serializeBlocksFolder(blocksFolder)
				end
				profile.Data.PityCount = player:GetAttribute("PityCount") or 0

				profile:Save()
				if saveEvent then saveEvent:FireClient(player) end
			end
		end
	end
end)

-- ---------- Жизненный цикл профиля ----------
local function onPlayerAdded(player: Player)
	local profile = profileStore:LoadProfileAsync("Player_" .. player.UserId, "ForceLoad")
	if not profile then
		player:Kick("Не удалось загрузить данные.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile:ListenToRelease(function()
		Profiles[player] = nil
		if player.Parent then
			player:Kick("Данные выгружены (повторный вход?).")
		end
	end)

	if player.Parent == Players then
		Profiles[player] = profile
		attachStatsContainers(player, profile)
	else
		profile:Release()
	end
end

local function onPlayerRemoving(player: Player)
	local profile = Profiles[player]
	if profile then
		local blocksFolder = player:FindFirstChild("Blocks")
		if blocksFolder then
			profile.Data.Blocks = serializeBlocksFolder(blocksFolder)
		end
		profile.Data.PityCount = player:GetAttribute("PityCount") or 0
		profile:Save()
		profile:Release()
	end
end

game:BindToClose(function()
	for player, profile in pairs(Profiles) do
		if profile:IsActive() then
			local blocksFolder = player:FindFirstChild("Blocks")
			if blocksFolder then
				profile.Data.Blocks = serializeBlocksFolder(blocksFolder)
			end
			profile.Data.PityCount = player:GetAttribute("PityCount") or 0
			profile:Save()
			profile:Release()
		end
	end
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
