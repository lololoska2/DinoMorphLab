-- StarterPlayerScripts/AutoSaveIndicator.client.lua
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local saveEvent = ReplicatedStorage:WaitForChild("AutoSaveEvent")

-- ========= helpers =========
local function waitAllCompleted(tweens)
	local done = 0
	for _, tw in ipairs(tweens) do
		tw.Completed:Once(function() done += 1 end)
	end
	while done < #tweens do task.wait() end
end

local function playAll(tweens)
	for _, tw in ipairs(tweens) do tw:Play() end
end

-- ========= GUI =========
local gui = Instance.new("ScreenGui")
gui.Name = "AutoSaveGUI"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 9999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- Иконка (зелёный спиннер/диск)
local icon = Instance.new("ImageLabel")
icon.Name = "SaveIcon"
icon.AnchorPoint = Vector2.new(1, 1)
icon.Position = UDim2.fromScale(0.98, 0.98)
icon.Size = UDim2.fromOffset(64, 64)
icon.BackgroundTransparency = 1
icon.ZIndex = 10000
icon.Image = "rbxassetid://103104755322227"
icon.ImageTransparency = 1
icon.Rotation = 0
icon.Parent = gui

-- Текст "Saved" (можешь скрыть, если не нужен)
local savedLabel = Instance.new("TextLabel")
savedLabel.AnchorPoint = Vector2.new(0.5, 1)
savedLabel.Position = UDim2.fromScale(0.5, 0.1) -- чуть выше центра иконки
savedLabel.Size = UDim2.fromOffset(80, 20)
savedLabel.BackgroundTransparency = 1
savedLabel.Font = Enum.Font.GothamBold
savedLabel.TextSize = 30
savedLabel.Text = "Saved"
savedLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
savedLabel.TextTransparency = 1
savedLabel.ZIndex = 10001
savedLabel.Parent = icon

-- Белая галочка
local checkIcon = Instance.new("ImageLabel")
checkIcon.AnchorPoint = Vector2.new(0.5, 0.5)
checkIcon.Position = UDim2.fromScale(1.23, 0.55) -- справа от текста
checkIcon.Size = UDim2.fromOffset(20, 20)
checkIcon.BackgroundTransparency = 1
checkIcon.Image = "rbxassetid://76372556952453" -- твой белый чек
checkIcon.ImageTransparency = 1
checkIcon.ZIndex = 10001
checkIcon.Parent = savedLabel

-- ========= Animation =========
local isPlaying = false

local function playSaveAnimation()
	if isPlaying then return end
	isPlaying = true

	icon.Visible = true
	-- reset
	icon.Rotation = 0
	icon.Size = UDim2.fromOffset(0, 0)
	icon.ImageTransparency = 1

	savedLabel.Size = UDim2.fromOffset(0, 0)
	savedLabel.TextTransparency = 1

	checkIcon.Size = UDim2.fromOffset(0, 0)
	checkIcon.ImageTransparency = 1

	-- Pop-in icon
	local appearBig = TweenService:Create(icon, TweenInfo.new(0.41, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(117, 117),
		ImageTransparency = 0
	})
	local shrinkToNormal = TweenService:Create(icon, TweenInfo.new(0.29, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.fromOffset(106, 106)
	})

	appearBig:Play(); appearBig.Completed:Wait()
	shrinkToNormal:Play(); shrinkToNormal.Completed:Wait()

	-- Spin 3 cycles: slow + fast
	local rotateSlow = TweenService:Create(icon, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Rotation = 45 })
	local rotateFast = TweenService:Create(icon, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Rotation = 360 })

	for i = 1, 3 do
		rotateSlow:Play(); rotateSlow.Completed:Wait()
		rotateFast:Play(); rotateFast.Completed:Wait()
		icon.Rotation = 0
		task.wait(0.15)
	end

	-- Parallel appear: text + check + small pop of icon
	local appearText = TweenService:Create(savedLabel, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(76, 24),
		TextTransparency = 0
	})
	local appearTick = TweenService:Create(checkIcon, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(24, 24),
		ImageTransparency = 0
	})
	local iconPopver2 = TweenService:Create(icon, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(120, 120)
	})
	local iconBack = TweenService:Create(icon, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.fromOffset(115, 115)
	})

	playAll({appearText, appearTick, iconPopver2})
	waitAllCompleted({appearText, appearTick, iconPopver2})
	iconBack:Play(); iconBack.Completed:Wait()

	-- hold a bit
	task.wait(0.25)

	-- Parallel fade-out (всё вместе) и затем спрячем контейнер
	local tFade = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local f1 = TweenService:Create(icon, tFade, { ImageTransparency = 1 })
	local f2 = TweenService:Create(savedLabel, tFade, { TextTransparency = 1 })
	local f3 = TweenService:Create(checkIcon, tFade, { ImageTransparency = 1 })

	playAll({f1, f2, f3})
	waitAllCompleted({f1, f2, f3})

	icon.Visible = false
	isPlaying = false
end

-- Подписка
saveEvent.OnClientEvent:Connect(playSaveAnimation)

-- Тестовый запуск (удали в продакшене)
task.delay(1, playSaveAnimation)
