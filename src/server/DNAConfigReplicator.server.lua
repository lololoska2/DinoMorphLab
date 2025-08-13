-- ServerScriptService/DNAConfigReplicator.server.lua
-- Копирует шансы flavor из ServerStorage в ReplicatedStorage/Config/DNAFlavorChances

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function findDNAConfig()
	-- поддерживаю оба варианта вложенности
	local root = ServerStorage:FindFirstChild("Config")
	if root then
		if root:FindFirstChild("DNAConfig") then return root:FindFirstChild("DNAConfig") end
		local inner = root:FindFirstChild("Config")
		if inner and inner:FindFirstChild("DNAConfig") then return inner:FindFirstChild("DNAConfig") end
	end
	return ServerStorage:FindFirstChild("DNAConfig")
end

local module = findDNAConfig()
assert(module and module:IsA("ModuleScript"), "[DNAConfigReplicator] Не нашёл ModuleScript DNAConfig в ServerStorage/Config")

local ok, CFG = pcall(require, module)
assert(ok and type(CFG) == "table", "[DNAConfigReplicator] Не удалось require DNAConfig")

-- ищем таблицу вида map[rarity][flavor] = число (шанс/вес)
local candidates = {
	"FLAVORS_BY_RARITY",           -- <<< твой ключ
	"FLAVOR_WEIGHTS",
	"FLAVOR_WEIGHTS_BY_RARITY",
	"RARITY_FLAVOR_WEIGHTS",
	"RARITY_FLAVORS",
	"FLAVORS",
}
local map
for _,k in ipairs(candidates) do
	local t = CFG[k]
	if type(t) == "table" then map = t break end
end
assert(type(map)=="table", "[DNAConfigReplicator] В DNAConfig не найдено таблицы шансов flavor")

-- создаём/чистим выходную структуру в ReplicatedStorage
local cfgFolder = ReplicatedStorage:FindFirstChild("Config") or Instance.new("Folder", ReplicatedStorage)
cfgFolder.Name = "Config"

local out = cfgFolder:FindFirstChild("DNAFlavorChances") or Instance.new("Folder", cfgFolder)
out.Name = "DNAFlavorChances"
out:ClearAllChildren()

for rarity, flavors in pairs(map) do
	if type(flavors) == "table" then
		local rFolder = Instance.new("Folder")
		rFolder.Name = tostring(rarity)
		rFolder.Parent = out
		for flavor, chance in pairs(flavors) do
			if type(chance) == "number" then
				local v = Instance.new("NumberValue")
				v.Name = tostring(flavor)
				v.Value = chance   -- трактуем: меньше число → реже flavor
				v.Parent = rFolder
			end
		end
	end
end

print("[DNAConfigReplicator] Опубликованы шансы в ReplicatedStorage/Config/DNAFlavorChances")
