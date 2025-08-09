--// ServerScriptService/Leaderstats.server.lua

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

-- Подключаем ProfileService (положи модуль в ServerScriptService/Modules/ProfileService)
local ProfileService = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("ProfileService"))

-- Схема данных игрока (то, что сохраняем)
local DEFAULTS = {
	GooDNA = 0,
	Level  = 1,
	XP     = 0,
	Likes  = 0,
}

-- Хранилище профилей
local profileStore = ProfileService.GetProfileStore("DinoMorph_Profile_v1", DEFAULTS)

-- Активные профили по игрокам
local Profiles: { [Player]: any } = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local saveEvent = Instance.new("RemoteEvent")
saveEvent.Name = "AutoSaveEvent"
saveEvent.Parent = ReplicatedStorage



-- Создаём только нужное для leaderboard + скрытую папку для прочих статов
local function attachStatsContainers(player: Player, profile)
	-- В leaderboard пойдёт только валюта
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local goo = Instance.new("IntValue")
	goo.Name = "GooDNA"
	goo.Value = profile.Data.GooDNA
	goo.Parent = leaderstats

	-- Скрытые статы (не попадают в leaderboard)
	local hidden = Instance.new("Folder")
	hidden.Name = "PlayerData"    -- можно переименовать; главное, НЕ "leaderstats"
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

	-- Двусторонняя синхронизация: изменения в Value -> в профиль
	local function pushToProfile()
		if profile and profile:IsActive() then
			profile.Data.GooDNA = goo.Value
			profile.Data.Level  = level.Value
			profile.Data.XP     = xp.Value
			profile.Data.Likes  = likes.Value
		end
	end

	goo.Changed:Connect(pushToProfile)
	level.Changed:Connect(pushToProfile)
	xp.Changed:Connect(pushToProfile)
	likes.Changed:Connect(pushToProfile)

	-- На всякий случай — хелпер, если где‑то в коде меняешь профиль напрямую:
	local function pullFromProfile()
		if profile and profile:IsActive() then
			if goo.Value   ~= profile.Data.GooDNA then goo.Value   = profile.Data.GooDNA end
			if level.Value ~= profile.Data.Level  then level.Value = profile.Data.Level  end
			if xp.Value    ~= profile.Data.XP     then xp.Value    = profile.Data.XP     end
			if likes.Value ~= profile.Data.Likes  then likes.Value = profile.Data.Likes  end
		end
	end

	-- Можно вызвать при загрузке/после покупок и т.п.
	profile._pullToValues = pullFromProfile
end

-- Автосейв каждые 60 секунд
task.spawn(function()
	while true do
		task.wait(60)
		for player, profile in pairs(Profiles) do
			if profile:IsActive() then
				profile:Save()
				-- Сообщаем клиенту, что автосейв произошёл
				saveEvent:FireClient(player)
			end
		end
	end
end)


-- Загрузка профиля игрока
local function onPlayerAdded(player: Player)
	local profile = profileStore:LoadProfileAsync("Player_" .. player.UserId, "ForceLoad")

	if not profile then
		player:Kick("Не удалось загрузить данные.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile() -- добавит недостающие поля из DEFAULTS

	-- Если профиль где‑то ещё уже загружен — кикнем этого игрока
	profile:ListenToRelease(function()
		Profiles[player] = nil
		if player.Parent then
			player:Kick("Данные выгружены (возможно повторный вход).")
		end
	end)

	-- Если игрок всё ещё в игре — активируем профиль
	if player.Parent == Players then
		Profiles[player] = profile
		attachStatsContainers(player, profile)
	else
		profile:Release()
	end
end

-- Сохранение при выходе игрока
local function onPlayerRemoving(player: Player)
	local profile = Profiles[player]
	if profile then
		profile:Save()
		profile:Release()
	end
end

-- Корректное завершение сервера — сохранение всех
game:BindToClose(function()
	-- В Studio во время Play тут может быть несколько секунд
	for player, profile in pairs(Profiles) do
		if profile:IsActive() then
			profile:Save()
			profile:Release()
		end
	end
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
