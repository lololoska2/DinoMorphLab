local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

-- Убираем дефолтный экран Roblox
pcall(function() ReplicatedFirst:RemoveDefaultLoadingScreen() end)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- === GUI ===
local gui = Instance.new("ScreenGui")
gui.Name = "DinoMorphLoading"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 10_000
gui.Parent = playerGui

-- Фон
local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
bg.BackgroundTransparency = 0
bg.Parent = gui

-- Лого
local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.4)
title.Size = UDim2.fromOffset(600, 80)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 48
title.Text = "DinoMorph Lab"
title.TextColor3 = Color3.fromRGB(235, 240, 255)
title.Parent = bg

-- Надпись над прогресс-баром
local loadingLabel = Instance.new("TextLabel")
loadingLabel.AnchorPoint = Vector2.new(0.5, 0.5)
loadingLabel.Position = UDim2.fromScale(0.5, 0.85)
loadingLabel.Size = UDim2.fromOffset(400, 40)
loadingLabel.BackgroundTransparency = 1
loadingLabel.Font = Enum.Font.Gotham
loadingLabel.TextSize = 24
loadingLabel.Text = "Loading assets: 0/0"
loadingLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
loadingLabel.Parent = bg

-- Прогресс-бар фон
local progressBg = Instance.new("Frame")
progressBg.AnchorPoint = Vector2.new(0.5, 0.5)
progressBg.Position = UDim2.fromScale(0.5, 0.92)
progressBg.Size = UDim2.fromOffset(400, 20)
progressBg.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
progressBg.BorderSizePixel = 0
progressBg.Parent = bg
local cornerBg = Instance.new("UICorner")
cornerBg.CornerRadius = UDim.new(0, 8)
cornerBg.Parent = progressBg

-- Прогресс-бар заполнение
local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBg
local cornerFill = Instance.new("UICorner")
cornerFill.CornerRadius = UDim.new(0, 8)
cornerFill.Parent = progressFill

-- === Список для предзагрузки ===
local assetsToLoad = {
	game:GetService("ReplicatedStorage"),
	game:GetService("StarterGui"),
}
-- Можно вручную добавить модели/изображения:ы
-- table.insert(assetsToLoad, game.ReplicatedStorage.MyModel)

local totalAssets = #assetsToLoad
local loadedAssets = 0

-- Функция обновления прогресса
local function updateProgress()
	loadingLabel.Text = string.format("Loading assets: %d/%d", loadedAssets, totalAssets)
	local percent = totalAssets > 0 and loadedAssets / totalAssets or 1
	progressFill.Size = UDim2.new(percent, 0, 1, 0)
end

updateProgress()

-- Предзагрузка с обновлением
for _, asset in ipairs(assetsToLoad) do
	ContentProvider:PreloadAsync({asset})
	loadedAssets += 1
	updateProgress()
end

-- Маленькая пауза
task.wait(0.5)

-- Плавное исчезновение
local fade = TweenService:Create(bg, TweenInfo.new(0.5), {BackgroundTransparency = 1})
local fadeTitle = TweenService:Create(title, TweenInfo.new(0.5), {TextTransparency = 1})
local fadeLabel = TweenService:Create(loadingLabel, TweenInfo.new(0.5), {TextTransparency = 1})
local fadeBar = TweenService:Create(progressBg, TweenInfo.new(0.5), {BackgroundTransparency = 1})
local fadeFill = TweenService:Create(progressFill, TweenInfo.new(0.5), {BackgroundTransparency = 1})

fade:Play()
fadeTitle:Play()
fadeLabel:Play()
fadeBar:Play()
fadeFill:Play()
fade.Completed:Wait()

gui:Destroy()
