-- StarterPlayerScripts/Client/Backpack.client.lua
-- DinoMorph Lab — Backpack v3.2
-- • Инвентарь, фильтры, сорт (rarity → flavorChance ↑ → affix% ↓)
-- • Детальная карточка + 3D превью ДНК.
-- • DNA Preview: сперва берём Mesh из ReplicatedStorage/Art/DNAHelix (RailA/RailB/Axis),
--   если нет — процедурный fallback на цилиндрах (без «бусинок»).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ========= THEME =========
local THEME = {
	bg=Color3.fromRGB(14,16,22),
	panel=Color3.fromRGB(20,24,32),
	panelEdge=Color3.fromRGB(66,255,194),
	text=Color3.fromRGB(230,236,245),
	textDim=Color3.fromRGB(180,190,205),
	sidebar=Color3.fromRGB(17,20,28),
	chipText=Color3.fromRGB(12,14,18),
	panelSoft=Color3.fromRGB(26,30,40),
	rarity={
		Common   = Color3.fromRGB(180,190,205),
		Uncommon = Color3.fromRGB(104,224,148),
		Rare     = Color3.fromRGB(84,140,255),
		Mythic   = Color3.fromRGB(255,140,92),
	}
}

local TOGGLE_KEY = Enum.KeyCode.B
local SLOT_SIZE  = Vector2.new(220,120)
local RARITY_FILTER = { Common=true, Uncommon=true, Rare=true, Mythic=true }

-- ========= DATA UTILS =========
local function getBlocksFolder()
	return player:FindFirstChild("Blocks") or player:WaitForChild("Blocks")
end

local function readValue(obj, name)
	local v = obj:GetAttribute(name)
	if v ~= nil then return v end
	local c = obj:FindFirstChild(name)
	if c and c:IsA("ValueBase") then return c.Value end
	return nil
end

local function readAffix(obj)
	-- 1) атрибуты
	local p = readValue(obj,"AffixPercent")
	local s = readValue(obj,"AffixStat")
	if p ~= nil and s ~= nil then
		local num = tonumber(p)
		if num then
			local one = math.floor(num * 1000 + 0.5)/10
			return (tostring(one).."%"), tostring(s)
		end
	end
	-- 2) значения в папке Affix
	local aff = obj:FindFirstChild("Affix")
	if aff then
		local ps = aff:FindFirstChild("PercentStr")
		local st = aff:FindFirstChild("Stat")
		if ps and st and ps:IsA("StringValue") and st:IsA("StringValue") then
			return ps.Value, st.Value
		end
	end
	return nil,nil
end

local function getAffixPercent(obj)
	local v = readValue(obj,"AffixPercent")
	if typeof(v)=="number" then return v end
	local s
	local aff = obj:FindFirstChild("Affix")
	if aff then
		local ps = aff:FindFirstChild("PercentStr")
		if ps and ps:IsA("StringValue") then s = tostring(ps.Value or "") end
	end
	if not s then s = select(1, readAffix(obj)) end
	if not s then return 0 end
	s = tostring(s):gsub("%%",""):gsub(",","."):gsub("%s+",""):gsub("−","-")
	local n = tonumber(s)
	return n or 0
end

local function rarityColor(r) return THEME.rarity[tostring(r)] or THEME.rarity.Common end
local function fmtTime(ts) return (typeof(ts)=="number" and ts>0) and os.date("%d.%m.%Y %H:%M", ts) or "—" end

-- ========= FLAVOR CHANCES (для сортировки) =========
local flavorCache
local function buildFlavorCacheFromFolder(root)
	if not root then return end
	flavorCache = flavorCache or {}
	for _,rFolder in ipairs(root:GetChildren()) do
		local rname = rFolder.Name
		local map = flavorCache[rname] or {}
		for _,nv in ipairs(rFolder:GetChildren()) do
			if nv:IsA("NumberValue") then map[nv.Name] = nv.Value end
		end
		flavorCache[rname] = map
	end
end
local function buildFlavorCacheFallbackModule()
	local mod = ReplicatedStorage:FindFirstChild("DNAConfig")
	if not (mod and mod:IsA("ModuleScript")) then return end
	local ok,cfg = pcall(require, mod); if not ok or type(cfg)~="table" then return end
	local keys = {"FLAVORS_BY_RARITY","FLAVOR_WEIGHTS","FLAVOR_WEIGHTS_BY_RARITY","RARITY_FLAVOR_WEIGHTS","RARITY_FLAVORS","FLAVORS"}
	for _,k in ipairs(keys) do
		local t = cfg[k]
		if type(t)=="table" then
			flavorCache = flavorCache or {}
			for r,fl in pairs(t) do
				local m = flavorCache[r] or {}
				for f,val in pairs(fl) do if type(val)=="number" then m[f]=val end end
				flavorCache[r]=m
			end
			break
		end
	end
end
local function getFlavorDropChance(rarity, flavor)
	if not rarity or not flavor or flavor=="" then return 999 end
	if not flavorCache then
		local cfg = ReplicatedStorage:FindFirstChild("Config")
		local folder = cfg and cfg:FindFirstChild("DNAFlavorChances")
		if folder then buildFlavorCacheFromFolder(folder) end
		if not flavorCache or next(flavorCache)==nil then buildFlavorCacheFallbackModule() end
	end
	local v = flavorCache and flavorCache[tostring(rarity)] and flavorCache[tostring(rarity)][tostring(flavor)]
	return (type(v)=="number" and v) or 999 -- чем меньше — тем реже
end

-- ========= UI HELPERS =========
local function mkStroke(p,c,th,tr) local s=Instance.new("UIStroke"); s.Thickness=th or 1.5; s.Color=c or Color3.new(1,1,1); s.Transparency=tr or 0; s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; s.Parent=p; return s end
local function mkCorner(p,r) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 12); c.Parent=p; return c end
local function mkLabel(p,t,sz,bold,col,alignLeft) local l=Instance.new("TextLabel"); l.BackgroundTransparency=1; l.Text=t or ""; l.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham; l.TextSize=sz or 14; l.TextColor3=col or THEME.text; l.TextXAlignment=(alignLeft==false and Enum.TextXAlignment.Right) or Enum.TextXAlignment.Left; l.Parent=p; return l end

-- ========= DNA PREVIEW (ViewportFrame) =========
local preview = {}

local function hashString(s) local h=0; for i=1,#(s or "") do h=(h*33 + string.byte(s,i))%360 end; return h/360 end
local function colorFromFlavor(name) return Color3.fromHSV(hashString(tostring(name or "")), 0.55, 0.95) end
local function colorFromStat(stat)
	stat = tostring(stat or ""):lower()
	if stat=="speed" then return Color3.fromRGB(80,220,255)
	elseif stat=="stamina" then return Color3.fromRGB(255,205,70)
	elseif stat=="hp" or stat=="health" then return Color3.fromRGB(255,120,150)
	elseif stat=="jump" then return Color3.fromRGB(120,255,140)
	elseif stat=="grip" then return Color3.fromRGB(200,120,255)
	else return Color3.fromRGB(210,210,230) end
end
local function clamp(x,a,b) if x<a then return a elseif x>b then return b else return x end end

local function buildPart(parent, size, cf, color, material, shape, tr)
	local p=Instance.new("Part")
	p.Anchored=true; p.CanCollide=false; p.CastShadow=false
	p.Size=size; p.CFrame=cf or CFrame.new()
	p.Material=material or Enum.Material.SmoothPlastic
	p.Color=color or Color3.new(1,1,1)
	p.Transparency=tr or 0
	p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
	if shape=="Cylinder" then p.Shape=Enum.PartType.Cylinder end
	p.Parent=parent
	return p
end

local function cylinderBetween(parent, p0, p1, radius, color, material)
	local d = p1 - p0; local len = d.Magnitude; if len < 1e-6 then return end
	local mid = (p0 + p1) * 0.5
	-- цилиндр ориентирован вдоль Y
	local cf  = CFrame.lookAt(mid, p1) * CFrame.Angles(math.pi/2, 0, 0)
	return buildPart(parent, Vector3.new(radius*2, len, radius*2), cf, color, material or Enum.Material.SmoothPlastic, "Cylinder", 0)
end

-- Процедурная спираль без «бусинок»: много перекрытых цилиндров
local function createDNAHelixRails(params)
	local model = Instance.new("Model")
	local root  = buildPart(model, Vector3.new(0.2,0.2,0.2), CFrame.new(), Color3.new(0,0,0), Enum.Material.SmoothPlastic, nil, 1)
	model.PrimaryPart = root

	local height     = params.height or 8
	local radius     = params.radius or 1.0
	local railR      = params.railRadius or 0.14
	local rungR      = params.rungRadius or (railR*0.6)
	local turns      = params.turns or 3.0
	local segments   = params.segments or 110
	local rungEvery  = params.rungEvery or 4
	local overlapLen = railR * 2.2

	local c1         = params.strand1Color or Color3.new(1,1,1)
	local c2         = params.strand2Color or Color3.fromRGB(230,230,240)
	local cRung      = params.rungColor   or Color3.new(1,1,1)

	-- центральная ось (1 деталь)
	buildPart(model, Vector3.new(railR*0.9, height, railR*0.9),
		CFrame.new(0,0,0) * CFrame.Angles(0,0,math.rad(90)), cRung, Enum.Material.Neon, "Cylinder", 0.35)

	local lastA, lastB
	for i=0,segments do
		local tNorm = i/segments
		local t     = tNorm * turns * math.pi*2
		local y     = (tNorm - 0.5) * height
		local pA    = Vector3.new(radius*math.cos(t),        y, radius*math.sin(t))
		local pB    = Vector3.new(radius*math.cos(t+math.pi),y, radius*math.sin(t+math.pi))

		if lastA then
			local dirA = (pA - lastA).Unit
			cylinderBetween(model, lastA - dirA*overlapLen, pA + dirA*overlapLen, railR, c1, Enum.Material.SmoothPlastic)
		end
		if lastB then
			local dirB = (pB - lastB).Unit
			cylinderBetween(model, lastB - dirB*overlapLen, pB + dirB*overlapLen, railR, c2, Enum.Material.SmoothPlastic)
		end

		if (i % rungEvery)==0 and i>0 then
			local rung = cylinderBetween(model, pA, pB, rungR, cRung, Enum.Material.Neon)
			if rung then rung.Transparency = 0.55 end
		end

		lastA, lastB = pA, pB
	end

	return model
end

-- Mesh-first: используем ReplicatedStorage/Art/DNAHelix (RailA/RailB/Axis). Иначе — fallback.
local function mountPreview(container, attrs)
	-- очистка
	if preview.conn then preview.conn:Disconnect() end
	if preview.viewport then preview.viewport:Destroy() end
	preview = {}

	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1,1)
	viewport.ZIndex = container.ZIndex + 1
	viewport.LightColor = Color3.fromRGB(255,255,255)
	viewport.LightDirection = Vector3.new(-1,-1,-0.5)
	viewport.Ambient = Color3.fromRGB(70,70,80)
	viewport.Parent = container

	local world = Instance.new("WorldModel"); world.Parent = viewport

	-- параметры блока
	local rarity  = tostring(attrs.rarity or "Common")
	local flavor  = tostring(attrs.flavor or "")
	local affPct  = tonumber(attrs.affPct or 0) or 0
	local affStat = tostring(attrs.affStat or "")
	local weight  = tonumber(attrs.weight or 1) or 1

	local strand1 = rarityColor(rarity)
	local strand2 = colorFromFlavor(flavor)
	local rungCol = colorFromStat(affStat)

	local weight01 = clamp((weight or 0)/30, 0, 1)
	local thicknessScale = 0.85 + 0.75*weight01

	-- пробуем готовую модель
	local dnaModel
	do
		local art = ReplicatedStorage:FindFirstChild("Art")
		local src = art and art:FindFirstChild("DNAHelix")
		if src and src:IsA("Model") then
			dnaModel = src:Clone()
			dnaModel.Parent = world
			local pp = dnaModel:FindFirstChild("Pivot") or dnaModel.PrimaryPart or dnaModel:FindFirstChildWhichIsA("BasePart")
			if pp then dnaModel.PrimaryPart = pp end

			local railA = dnaModel:FindFirstChild("RailA")
			local railB = dnaModel:FindFirstChild("RailB")
			local axis  = dnaModel:FindFirstChild("Axis")

			for _,rail in ipairs({railA, railB}) do
				if rail and rail:IsA("BasePart") then
					rail.Material = Enum.Material.SmoothPlastic
					-- толщина зависит от веса (по X/Z)
					local s = rail.Size
					rail.Size = Vector3.new(s.X*thicknessScale, s.Y, s.Z*thicknessScale)
				end
			end
			if railA then railA.Color = strand1 end
			if railB then railB.Color = strand2 end
			if axis and axis:IsA("BasePart") then
				axis.Color = rungCol; axis.Material = Enum.Material.Neon; axis.Transparency = 0.35
			end
			if dnaModel.PrimaryPart then
				dnaModel:PivotTo(CFrame.new(0,0,0))
			end
		end
	end

	-- fallback — процедурная спираль
	if not dnaModel then
		local turnsByRarity = {Common=2.2, Uncommon=2.6, Rare=3.0, Mythic=3.6}
		local turns = turnsByRarity[rarity] or 2.6
		local radius = 0.85 + 0.75*weight01
		local railR  = 0.11 + 0.13*weight01

		dnaModel = createDNAHelixRails({
			height = 8, radius = radius, railRadius = railR, rungRadius = railR*0.6,
			turns = turns, segments = 110, rungEvery = 4,
			strand1Color = strand1, strand2Color = strand2, rungColor = rungCol
		})
		dnaModel.Parent = world
	end

	-- камера
	local cam = Instance.new("Camera")
	cam.CFrame = CFrame.new(Vector3.new(0,1.2,7), Vector3.new(0,0.2,0))
	cam.Parent = viewport
	viewport.CurrentCamera = cam

	-- вращение от процента аффикса
	local dir   = (affPct >= 0) and 1 or -1
	local speed = dir * (0.35 + math.min(math.abs(affPct)/100, 2.0) * 0.6)

	preview.conn = RunService.RenderStepped:Connect(function(dt)
		if dnaModel and dnaModel.PrimaryPart then
			dnaModel:SetPrimaryPartCFrame(dnaModel.PrimaryPart.CFrame * CFrame.Angles(0, speed*dt*math.pi*2, 0))
		end
	end)

	preview.viewport = viewport
	preview.world    = world
	preview.model    = dnaModel
end

-- ========= GUI (панели, грид, модалка) =========
local gui, dim, root, sidebar, gridScroll, gridLayout, searchBox, sortDrop, titleLbl, countLbl
local detailDim, detailRoot, detailPreview, detailInfo, detailTitle, detailRarity, detailScroll, detailListLayout
local currentDetailBlock, currentAttrConn
local rebuild

local function closeDetails()
	if detailDim then detailDim.Visible=false end
	if detailRoot then detailRoot.Visible=false end
	if currentAttrConn then currentAttrConn:Disconnect(); currentAttrConn=nil end
	if preview.conn then preview.conn:Disconnect() end
	if preview.viewport then preview.viewport:Destroy() end
	preview = {}
	currentDetailBlock=nil
end

local function makeRarityToggle(name, color, baseZ)
	baseZ = baseZ or 822
	local btn = Instance.new("TextButton")
	btn.AutoButtonColor=false; btn.Text=""; btn.BackgroundColor3=THEME.panel; btn.Size=UDim2.fromOffset(206,28); btn.ZIndex=baseZ
	mkCorner(btn,8)

	local chip = Instance.new("Frame"); chip.Size=UDim2.fromOffset(14,14); chip.Position=UDim2.fromOffset(8,7); chip.BackgroundColor3=color; chip.ZIndex=baseZ+1
	mkCorner(chip,7); chip.Parent=btn

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency=1; label.Text=name; label.TextXAlignment=Enum.TextXAlignment.Left
	label.Font=Enum.Font.GothamMedium; label.TextSize=14; label.Position=UDim2.fromOffset(28,0)
	label.Size=UDim2.new(1,-28,1,0); label.ZIndex=baseZ+1; label.Parent=btn

	local stroke = mkStroke(btn,color,1.5,0.55); stroke.ZIndex=baseZ+2

	local on=true
	local function refresh()
		RARITY_FILTER[name]=on
		if on then
			btn.BackgroundColor3=THEME.panelSoft; label.TextColor3=THEME.text; stroke.Transparency=0.15; chip.BackgroundTransparency=0
		else
			btn.BackgroundColor3=THEME.panel; label.TextColor3=THEME.textDim; stroke.Transparency=0.6; chip.BackgroundTransparency=0.3
		end
	end

	btn.MouseEnter:Connect(function() stroke.Transparency = on and 0.08 or 0.5 end)
	btn.MouseLeave:Connect(refresh)
	btn.Activated:Connect(function() on = not on; refresh(); rebuild() end)
	refresh()
	return btn
end

local function ensureGui()
	if gui then return end
	gui=Instance.new("ScreenGui"); gui.Name="BackpackV2"; gui.IgnoreGuiInset=true; gui.ResetOnSpawn=false; gui.Parent=playerGui
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global

	dim=Instance.new("Frame"); dim.BackgroundColor3=THEME.bg; dim.BackgroundTransparency=0.35; dim.Size=UDim2.fromScale(1,1); dim.Visible=false; dim.Parent=gui; dim.ZIndex=800

	root=Instance.new("Frame"); root.AnchorPoint=Vector2.new(0.5,0.5); root.Position=UDim2.fromScale(0.5,0.52); root.Size=UDim2.new(0,980,0,560)
	root.BackgroundColor3=THEME.panel; root.Visible=false; root.Parent=gui; root.ZIndex=810
	mkCorner(root,18); local glow=mkStroke(root,THEME.panelEdge,2,0.3); glow.ZIndex=811
	local grad=Instance.new("UIGradient"); grad.Rotation=90; grad.Color=ColorSequence.new{
		ColorSequenceKeypoint.new(0,Color3.fromRGB(24,160,160)),
		ColorSequenceKeypoint.new(0.5,THEME.panelEdge),
		ColorSequenceKeypoint.new(1,Color3.fromRGB(24,160,160)),
	}; grad.Parent=glow

	local top=Instance.new("Frame"); top.BackgroundTransparency=1; top.Size=UDim2.new(1,-24,0,48); top.Position=UDim2.fromOffset(12,10); top.Parent=root; top.ZIndex=812
	titleLbl=mkLabel(top,"Backpack — DNA Blocks (B)",22,true,THEME.text,true); titleLbl.Size=UDim2.new(1,-48,1,0); titleLbl.ZIndex=813
	countLbl=mkLabel(top,"0",16,false,THEME.textDim,false); countLbl.Size=UDim2.new(1,-48,1,0); countLbl.ZIndex=813
	local closeBtn=Instance.new("TextButton"); closeBtn.Text="×"; closeBtn.Font=Enum.Font.GothamBold; closeBtn.TextSize=28; closeBtn.TextColor3=THEME.text; closeBtn.BackgroundTransparency=1
	closeBtn.AnchorPoint=Vector2.new(1,0); closeBtn.Position=UDim2.new(1,0,0,0); closeBtn.Size=UDim2.fromOffset(44,44); closeBtn.Parent=top; closeBtn.ZIndex=813
	closeBtn.Activated:Connect(function() dim.Visible=false; root.Visible=false; closeDetails() end)

	-- Sidebar
	sidebar=Instance.new("Frame"); sidebar.BackgroundColor3=THEME.sidebar; sidebar.Position=UDim2.fromOffset(12,60); sidebar.Size=UDim2.new(0,230,1,-72)
	sidebar.Parent=root; sidebar.ZIndex=820; mkCorner(sidebar,14); mkStroke(sidebar,Color3.fromRGB(52,60,78),1,0.35).ZIndex=821
	local sidePad=Instance.new("UIPadding"); sidePad.PaddingTop=UDim.new(0,12); sidePad.PaddingBottom=UDim.new(0,12); sidePad.PaddingLeft=UDim.new(0,12); sidePad.PaddingRight=UDim.new(0,12); sidePad.Parent=sidebar
	local function mkSideLabel(text) local l=mkLabel(sidebar,text,16,true,THEME.text,true); l.Size=UDim2.fromOffset(206,20); l.ZIndex=822; return l end

	mkSideLabel("Search")
	searchBox=Instance.new("TextBox"); searchBox.PlaceholderText="Flavor / Barcode / Stat"; searchBox.ClearTextOnFocus=false; searchBox.Text=""
	searchBox.Font=Enum.Font.Gotham; searchBox.TextSize=14; searchBox.TextColor3=THEME.text; searchBox.BackgroundColor3=THEME.panel
	searchBox.Size=UDim2.fromOffset(206,32); searchBox.Parent=sidebar; searchBox.ZIndex=822; mkCorner(searchBox,10); mkStroke(searchBox,Color3.fromRGB(60,72,96),1,0.4).ZIndex=823

	local uiList=Instance.new("UIListLayout"); uiList.SortOrder=Enum.SortOrder.LayoutOrder; uiList.Padding=UDim.new(0,10); uiList.Parent=sidebar

	mkSideLabel("Rarity")
	makeRarityToggle("Common",   THEME.rarity.Common,   822).Parent = sidebar
	makeRarityToggle("Uncommon", THEME.rarity.Uncommon, 822).Parent = sidebar
	makeRarityToggle("Rare",     THEME.rarity.Rare,     822).Parent = sidebar
	makeRarityToggle("Mythic",   THEME.rarity.Mythic,   822).Parent = sidebar

	mkSideLabel("Sort")
	sortDrop=Instance.new("TextButton"); sortDrop.Text="  Newest first"; sortDrop.Font=Enum.Font.Gotham; sortDrop.TextSize=14; sortDrop.TextColor3=THEME.text
	sortDrop.BackgroundColor3=THEME.panel; sortDrop.Size=UDim2.fromOffset(206,28); sortDrop.Parent=sidebar; sortDrop.ZIndex=822; mkCorner(sortDrop,8); mkStroke(sortDrop,Color3.fromRGB(60,72,96),1,0.4).ZIndex=823
	local sortMode=1; local sortNames={"Newest first","Oldest first","Heaviest","Lightest","Rarity ↓","Rarity ↑"}
	sortDrop.Activated:Connect(function() sortMode=(sortMode % #sortNames)+1; sortDrop.Text="  "..sortNames[sortMode]; rebuild() end)

	-- Правая часть (грид)
	local right=Instance.new("Frame"); right.BackgroundTransparency=1; right.Position=UDim2.fromOffset(260,60); right.Size=UDim2.new(1,-272,1,-72); right.Parent=root; right.ZIndex=830
	gridScroll=Instance.new("ScrollingFrame"); gridScroll.BackgroundTransparency=1; gridScroll.Size=UDim2.fromScale(1,1); gridScroll.CanvasSize=UDim2.new(0,0,0,0)
	gridScroll.ScrollBarThickness=8; gridScroll.ClipsDescendants=true; gridScroll.Parent=right; gridScroll.ZIndex=831
	local gridPad=Instance.new("UIPadding"); gridPad.PaddingLeft=UDim.new(0,12); gridPad.PaddingRight=UDim.new(0,8); gridPad.PaddingTop=UDim.new(0,6); gridPad.PaddingBottom=UDim.new(0,6); gridPad.Parent=gridScroll
	gridLayout=Instance.new("UIGridLayout"); gridLayout.CellPadding=UDim2.fromOffset(10,10); gridLayout.CellSize=UDim2.fromOffset(SLOT_SIZE.X,SLOT_SIZE.Y); gridLayout.SortOrder=Enum.SortOrder.LayoutOrder; gridLayout.Parent=gridScroll

	-- Детальная модалка
	detailDim=Instance.new("Frame"); detailDim.BackgroundColor3=Color3.new(0,0,0); detailDim.BackgroundTransparency=0.4; detailDim.Size=UDim2.fromScale(1,1); detailDim.Visible=false; detailDim.ZIndex=900; detailDim.Active=true; detailDim.Parent=gui
	detailRoot=Instance.new("Frame"); detailRoot.AnchorPoint=Vector2.new(0.5,0.5); detailRoot.Position=UDim2.fromScale(0.5,0.5); detailRoot.Size=UDim2.new(0,820,0,520)
	detailRoot.BackgroundColor3=THEME.panel; detailRoot.Visible=false; detailRoot.ZIndex=910; detailRoot.Parent=gui; mkCorner(detailRoot,16); mkStroke(detailRoot,THEME.panelEdge,2,0.25).ZIndex=911

	local dTop=Instance.new("Frame"); dTop.BackgroundTransparency=1; dTop.Size=UDim2.new(1,-20,0,46); dTop.Position=UDim2.fromOffset(10,8); dTop.Parent=detailRoot; dTop.ZIndex=912
	detailTitle=mkLabel(dTop,"DNA Block",20,true,THEME.text,true); detailTitle.Size=UDim2.new(1,-90,1,0); detailTitle.ZIndex=913
	local dClose=Instance.new("TextButton"); dClose.Text="×"; dClose.Font=Enum.Font.GothamBold; dClose.TextSize=28; dClose.TextColor3=THEME.text; dClose.BackgroundTransparency=1
	dClose.AnchorPoint=Vector2.new(1,0); dClose.Position=UDim2.new(1,-2,0,0); dClose.Size=UDim2.fromOffset(44,44); dClose.ZIndex=913; dClose.Parent=dTop; dClose.Activated:Connect(closeDetails)
	detailDim.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 then closeDetails() end end)

	detailPreview=Instance.new("Frame"); detailPreview.BackgroundColor3=THEME.panelSoft; detailPreview.Size=UDim2.new(0.33,-16,1,-68)
	detailPreview.Position=UDim2.fromOffset(10,58); detailPreview.Parent=detailRoot; detailPreview.ZIndex=912; mkCorner(detailPreview,12); mkStroke(detailPreview,Color3.fromRGB(60,72,96),1,0.45).ZIndex=913

	detailInfo=Instance.new("Frame"); detailInfo.BackgroundTransparency=1; detailInfo.Position=UDim2.new(0.33,12,0,58); detailInfo.Size=UDim2.new(0.67,-22,1,-68); detailInfo.Parent=detailRoot; detailInfo.ZIndex=914
	detailRarity=Instance.new("TextLabel"); detailRarity.BackgroundColor3=THEME.rarity.Common; detailRarity.TextColor3=THEME.chipText; detailRarity.Font=Enum.Font.GothamBold
	detailRarity.TextSize=12; detailRarity.Text="Common"; detailRarity.Size=UDim2.fromOffset(86,22); detailRarity.Position=UDim2.fromOffset(0,0); detailRarity.Parent=detailInfo; detailRarity.ZIndex=915; mkCorner(detailRarity,6)

	local infoCard=Instance.new("Frame"); infoCard.BackgroundColor3=THEME.panelSoft; infoCard.Size=UDim2.new(1,0,1,-30); infoCard.Position=UDim2.fromOffset(0,30); infoCard.Parent=detailInfo; infoCard.ZIndex=914
	mkCorner(infoCard,12); mkStroke(infoCard,Color3.fromRGB(60,72,96),1,0.45).ZIndex=915
	local inPad=Instance.new("UIPadding"); inPad.PaddingTop=UDim.new(0,12); inPad.PaddingBottom=UDim.new(0,12); inPad.PaddingLeft=UDim.new(0,12); inPad.PaddingRight=UDim.new(0,12); inPad.Parent=infoCard

	detailScroll=Instance.new("ScrollingFrame"); detailScroll.BackgroundTransparency=1; detailScroll.Size=UDim2.fromScale(1,1)
	detailScroll.CanvasSize=UDim2.new(0,0,0,0); detailScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	detailScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	detailScroll.ScrollBarThickness=6; detailScroll.Parent=infoCard; detailScroll.ZIndex=916

	detailListLayout=Instance.new("UIListLayout"); detailListLayout.FillDirection=Enum.FillDirection.Vertical; detailListLayout.SortOrder=Enum.SortOrder.LayoutOrder
	detailListLayout.Padding=UDim.new(0,8); detailListLayout.Parent=detailScroll; detailListLayout.Name="RowsLayout"
end

local function addRow(name,value)
	local row=Instance.new("Frame"); row.Name="Row"; row.BackgroundTransparency=1; row.Size=UDim2.new(1,0,0,28); row.Parent=detailScroll; row.ZIndex=917
	local left=mkLabel(row,tostring(name),14,true,THEME.text,true); left.Size=UDim2.new(0.4,-6,1,0); left.ZIndex=918
	local right=mkLabel(row,tostring(value),14,false,THEME.textDim,true); right.Size=UDim2.new(0.6,0,1,0); right.Position=UDim2.new(0.4,0,0,0); right.ZIndex=918
end
local function clearDetails()
	for _,c in ipairs(detailScroll:GetChildren()) do
		if c:IsA("GuiObject") and c.Name=="Row" then c:Destroy() end
	end
end
local function finalizeDetailCanvas()
	RunService.Heartbeat:Wait()
	detailScroll.CanvasSize = UDim2.fromOffset(detailListLayout.AbsoluteContentSize.X, detailListLayout.AbsoluteContentSize.Y)
end

local function openDetails(blockObj)
	if currentAttrConn then currentAttrConn:Disconnect() currentAttrConn=nil end
	currentDetailBlock=blockObj

	local flavor=tostring(readValue(blockObj,"Flavor") or "DNA Block")
	local rarity=tostring(readValue(blockObj,"Rarity") or "Common")
	detailTitle.Text=flavor; detailRarity.Text=rarity; detailRarity.BackgroundColor3=rarityColor(rarity)

	clearDetails()

	local weight=readValue(blockObj,"WeightKg")
	local pStr,pStat=readAffix(blockObj)
	local barcode=readValue(blockObj,"Barcode")
	local id=readValue(blockObj,"Id") or blockObj.Name
	local created=readValue(blockObj,"CreatedAt")
	local owner=readValue(blockObj,"Owner")

	addRow("Flavor",flavor)
	addRow("Rarity",rarity)
	addRow("Weight",weight and string.format("%.2f kg",weight) or "—")
	addRow("Affix",(pStr and pStat) and (pStr.." → "..pStat) or "—")
	addRow("Barcode",barcode or "—")
	addRow("Id",id or "—")
	addRow("Created At",fmtTime(created))
	if owner then addRow("Owner",tostring(owner)) end

	local shown={Flavor=true,Rarity=true,WeightKg=true,AffixPercent=true,AffixStat=true,Barcode=true,Id=true,CreatedAt=true,Owner=true}
	for k,v in pairs(blockObj:GetAttributes()) do if not shown[k] then addRow(k,v) end end

	local aff=blockObj:FindFirstChild("Affix")
	if aff then
		local ps=aff:FindFirstChild("PercentStr"); local st=aff:FindFirstChild("Stat")
		if ps and st and ps:IsA("StringValue") and st:IsA("StringValue") then
			addRow("Affix.Raw.PercentStr",ps.Value)
			addRow("Affix.Raw.Stat",st.Value)
		end
	end

	-- Монтируем 3D превью
	local affPctNum = getAffixPercent(blockObj)
	mountPreview(detailPreview, {
		rarity = rarity,
		flavor = flavor,
		affPct = affPctNum,
		affStat= readValue(blockObj,"AffixStat") or (aff and aff:FindFirstChild("Stat") and aff.Stat.Value),
		weight = weight or 1,
	})

	finalizeDetailCanvas()

	currentAttrConn=blockObj.AttributeChanged:Connect(function() openDetails(blockObj) end)

	detailDim.Visible=true
	detailRoot.Visible=true
end

-- Слот блока
local function makeSlot(blockObj)
	local rarity=tostring(readValue(blockObj,"Rarity") or "Common")
	local colorR=rarityColor(rarity)
	local weight=readValue(blockObj,"WeightKg")
	local flavor=tostring(readValue(blockObj,"Flavor") or "DNA Block")
	local id=tostring(readValue(blockObj,"Id") or blockObj.Name)
	local pStr,pStat=readAffix(blockObj)

	local slot=Instance.new("TextButton"); slot.Name="Block_"..id; slot.Text=""; slot.AutoButtonColor=false; slot.BackgroundColor3=THEME.panel; slot.Parent=gridScroll; slot.ZIndex=835
	mkCorner(slot,14); local s=mkStroke(slot,colorR,2,0.0); s.ZIndex=836

	local inner=Instance.new("Frame"); inner.BackgroundColor3=THEME.panelSoft; inner.Size=UDim2.new(1,-12,1,-12); inner.Position=UDim2.fromOffset(6,6); inner.Parent=slot; inner.ZIndex=836
	mkCorner(inner,12); mkStroke(inner,Color3.fromRGB(60,72,96),1,0.5).ZIndex=837

	local chip=Instance.new("TextLabel"); chip.BackgroundColor3=colorR; chip.TextColor3=THEME.chipText; chip.Font=Enum.Font.GothamBold; chip.TextSize=12; chip.Text=rarity
	chip.Size=UDim2.fromOffset(78,22); chip.Position=UDim2.fromOffset(8,8); chip.Parent=inner; chip.ZIndex=838; mkCorner(chip,6)

	local name=mkLabel(inner,flavor,16,false,THEME.text,true); name.Position=UDim2.fromOffset(96,8); name.Size=UDim2.new(1,-104,0,22); name.ZIndex=838
	local w=mkLabel(inner,weight and string.format("Weight: %.2f kg",weight) or "Weight: —",14,false,THEME.textDim,true); w.Position=UDim2.fromOffset(12,44); w.Size=UDim2.new(1,-24,0,18); w.ZIndex=838
	local a=mkLabel(inner,(pStr and pStat) and ("Affix: "..pStr.." → "..pStat) or "Affix: —",14,false,THEME.textDim,true); a.Position=UDim2.fromOffset(12,66); a.Size=UDim2.new(1,-24,0,18); a.ZIndex=838

	slot.MouseEnter:Connect(function() s.Transparency=0; slot.BackgroundColor3=THEME.panelSoft end)
	slot.MouseLeave:Connect(function() s.Transparency=0.0; slot.BackgroundColor3=THEME.panel end)
	slot.Activated:Connect(function() openDetails(blockObj) end)

	return slot
end

-- Поиск/фильтр
local function matches(blockObj, q)
	local r=tostring(readValue(blockObj,"Rarity") or "Common")
	if RARITY_FILTER[r]==false then return false end
	if q=="" then return true end
	q=string.lower(q)
	local flavor=tostring(readValue(blockObj,"Flavor") or "")
	local barcode=tostring(readValue(blockObj,"Barcode") or "")
	local aff1,aff2=readAffix(blockObj)
	local blob=string.lower(table.concat({flavor,barcode or "",aff1 or "",aff2 or ""}," "))
	return string.find(blob,q,1,true)~=nil
end

-- Сортировка
local function rarityRank(r) local order={Common=1,Uncommon=2,Rare=3,Mythic=4}; return order[tostring(r)] or 1 end
local function sortFunc(mode)
	return function(a,b)
		local ra,rb = rarityRank(readValue(a,"Rarity")), rarityRank(readValue(b,"Rarity"))
		if mode==1 then
			return (readValue(a,"CreatedAt") or 0) > (readValue(b,"CreatedAt") or 0)
		elseif mode==2 then
			return (readValue(a,"CreatedAt") or 0) < (readValue(b,"CreatedAt") or 0)
		elseif mode==3 then
			return (readValue(a,"WeightKg") or 0) > (readValue(b,"WeightKg") or 0)
		elseif mode==4 then
			return (readValue(a,"WeightKg") or 0) < (readValue(b,"WeightKg") or 0)
		elseif mode==5 then
			-- Rarity ↓: редкие раньше → tie: реже flavor → tie: больший % аффикса → дата
			if ra ~= rb then return ra > rb end
			local fa = tostring(readValue(a,"Flavor") or "")
			local fb = tostring(readValue(b,"Flavor") or "")
			local ca = getFlavorDropChance(readValue(a,"Rarity"), fa)
			local cb = getFlavorDropChance(readValue(b,"Rarity"), fb)
			if ca ~= cb then return ca < cb end
			local pa,pb = getAffixPercent(a), getAffixPercent(b)
			if pa ~= pb then return pa > pb end
			return (readValue(a,"CreatedAt") or 0) > (readValue(b,"CreatedAt") or 0)
		else
			-- Rarity ↑: обычные раньше → tie: реже flavor → tie: больший % аффикса → дата
			if ra ~= rb then return ra < rb end
			local fa = tostring(readValue(a,"Flavor") or "")
			local fb = tostring(readValue(b,"Flavor") or "")
			local ca = getFlavorDropChance(readValue(a,"Rarity"), fa)
			local cb = getFlavorDropChance(readValue(b,"Rarity"), fb)
			if ca ~= cb then return ca < cb end
			local pa,pb = getAffixPercent(a), getAffixPercent(b)
			if pa ~= pb then return pa > pb end
			return (readValue(a,"CreatedAt") or 0) > (readValue(b,"CreatedAt") or 0)
		end
	end
end
local function currentSortMode()
	local t=sortDrop.Text or "Newest first"
	local names={"Newest first","Oldest first","Heaviest","Lightest","Rarity ↓","Rarity ↑"}
	for i,name in ipairs(names) do if t:find(name,1,true) then return i end end
	return 1
end

local function updateTitle(n) titleLbl.Text="Backpack — DNA Blocks (B)"; countLbl.Text=tostring(n) end

local function makeAndAddSlots(list)
	for _,c in ipairs(gridScroll:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	for i,obj in ipairs(list) do local slot=makeSlot(obj); slot.LayoutOrder=i end
	RunService.Heartbeat:Wait()
	gridScroll.CanvasSize = UDim2.fromOffset(gridLayout.AbsoluteContentSize.X, gridLayout.AbsoluteContentSize.Y)
	updateTitle(#list)
end

rebuild = function()
	if not root or not root.Parent then return end
	local query=string.lower(searchBox.Text or "")
	local list={}
	for _,o in ipairs(getBlocksFolder():GetChildren()) do if matches(o,query) then table.insert(list,o) end end
	table.sort(list, sortFunc(currentSortMode()))
	makeAndAddSlots(list)
end

-- Подписки
local connsBlocks={}
local function wire()
	for _,c in ipairs(connsBlocks) do pcall(function() c:Disconnect() end) end
	table.clear(connsBlocks)
	local blocks=getBlocksFolder()
	table.insert(connsBlocks, blocks.ChildAdded:Connect(function(ch)
		table.insert(connsBlocks, ch.AttributeChanged:Connect(rebuild))
		rebuild()
	end))
	table.insert(connsBlocks, blocks.ChildRemoved:Connect(function(ch)
		if currentDetailBlock==ch then closeDetails() end
		rebuild()
	end))
	for _,o in ipairs(blocks:GetChildren()) do
		table.insert(connsBlocks, o.AttributeChanged:Connect(rebuild))
	end
	table.insert(connsBlocks, searchBox:GetPropertyChangedSignal("Text"):Connect(rebuild))
end

local function setOpen(open)
	dim.Visible=open; root.Visible=open
	if open then wire(); rebuild() else closeDetails() end
end

UserInputService.InputBegan:Connect(function(input,gpe)
	if gpe then return end
	if input.KeyCode==TOGGLE_KEY then setOpen(not (root and root.Visible)) end
end)

ensureGui()
