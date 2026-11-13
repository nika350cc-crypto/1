local getGlobalEnv = getgenv or function()
	return _G
end

local globalEnv = getGlobalEnv()

local DEFAULT_CONFIG = {
	Team = "Pirates",
	FastTween = true,
	AutoHop = false,
	HopWhenIdle = false,
	FpsBoost = true,
	FpsCap = 60,
	RemoveSFX = true,
	BlockAcc = true,
	BlackScreen = false,
	DisableIslandLOD = false,
	["Buy Haki"] = {
		Skyjump = true,
		Buso = true,
		Soru = true,
		Observation = true,
	},
	CursedDualKatana = false,
	SoulGuitar = false,
	FarmBoneForx2EXP = true,
	WebhookEnabled = false,
	WebhookUrl = "",
	WebhookIntervalMinutes = 5,
}

local function mergeDefaultConfig(targetTable, defaultTable)
	for key, defaultValue in pairs(defaultTable) do
		if type(defaultValue) == "table" then
			if type(targetTable[key]) ~= "table" then
				targetTable[key] = {}
			end
			mergeDefaultConfig(targetTable[key], defaultValue)
		elseif targetTable[key] == nil then
			targetTable[key] = defaultValue
		end
	end
	return targetTable
end

if type(globalEnv.Config) ~= "table" and type(Config) == "table" then
	globalEnv.Config = Config
elseif type(globalEnv.Config) ~= "table" then
	globalEnv.Config = {}
end

Config = mergeDefaultConfig(globalEnv.Config, DEFAULT_CONFIG)
globalEnv.Config = Config

local isfolder = isfolder or function()
	return false
end
local makefolder = makefolder or function() end
local isfile = isfile or function()
	return false
end
local readfile = readfile or function()
	return ""
end
local writefile = writefile or function() end
local setfpscap = setfpscap or function() end
local firesignal = firesignal or function() end
local getconnections = getconnections or get_signal_cons or function()
	return {}
end
local hookfunction = hookfunction
local sethiddenproperty = sethiddenproperty or function() end
local setscriptable = setscriptable or function() end
local fireclickdetector = fireclickdetector or function() end
local firetouchinterest = firetouchinterest or function() end
local fireproximityprompt = fireproximityprompt
	or function(promptInstance)
		if promptInstance and promptInstance:IsA("ProximityPrompt") then
			pcall(function()
				promptInstance:InputHoldBegin()
				task.wait(math.max(promptInstance.HoldDuration or 0, 0.05))
				promptInstance:InputHoldEnd()
			end)
		end
	end
local httpRequest = request
	or http_request
	or (syn and syn.request)
	or (http and http.request)
	or (fluxus and fluxus.request)

local gethui = gethui
	or function()
		local ok, coreGui = pcall(function()
			return game:GetService("CoreGui")
		end)
		if ok and coreGui then
			return coreGui
		end
		local lp = game:GetService("Players").LocalPlayer
		return lp and lp:FindFirstChild("PlayerGui") or nil
	end

local function ensureDirectoryPath(folderPath)
	if not isfolder(folderPath) then
		pcall(makefolder, folderPath)
	end
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local LogService = game:GetService("LogService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
	Players.PlayerAdded:Wait()
	LocalPlayer = Players.LocalPlayer
end
repeat
	task.wait()
until LocalPlayer:FindFirstChild("PlayerGui")

if type(globalEnv.BananaCat) == "table" and type(globalEnv.BananaCat.Cleanup) == "function" then
	pcall(globalEnv.BananaCat.Cleanup)
end

local CURRENT_SESSION_ID = HttpService:GenerateGUID(false)
local sessionConnections = {}
local sessionCleanupCallbacks = {}

local function trackSessionConnection(connection)
	if connection then
		table.insert(sessionConnections, connection)
	end
	return connection
end

local function registerCleanupCallback(callback)
	if type(callback) == "function" then
		table.insert(sessionCleanupCallbacks, callback)
	end
end

local function isSessionActive()
	return not _G.Stop and type(globalEnv.BananaCat) == "table" and globalEnv.BananaCat.SessionId == CURRENT_SESSION_ID
end

local function cleanupCurrentSession()
	for _, connection in ipairs(sessionConnections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(sessionConnections)

	for _, callback in ipairs(sessionCleanupCallbacks) do
		pcall(callback)
	end
	table.clear(sessionCleanupCallbacks)
end

globalEnv.BananaCat = {
	Loaded = true,
	SessionId = CURRENT_SESSION_ID,
	Cleanup = cleanupCurrentSession,
}

_G.NR = Config.BlackScreen == true
pcall(function()
	RunService:Set3dRenderingEnabled(not _G.NR)
end)

if Config.FpsCap then
	pcall(setfpscap, Config.FpsCap)
end

if Config.RemoveSFX then
	local function muteContainerSounds(container)
		if not container then
			return
		end
		for _, descendant in ipairs(container:GetDescendants()) do
			if descendant:IsA("Sound") then
				descendant.Volume = 0
			end
		end
		trackSessionConnection(container.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("Sound") then
				task.defer(function()
					pcall(function()
						descendant.Volume = 0
					end)
				end)
			end
		end))
	end

	pcall(muteContainerSounds, workspace)
	pcall(muteContainerSounds, ReplicatedStorage)
end

local function getCommFRemote()
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	return remotesFolder and remotesFolder:FindFirstChild("CommF_") or nil
end

local function selectConfiguredTeam()
	local targetTeam = (Config.Team == "Marines") and "Marines" or "Pirates"
	local commF = getCommFRemote()
	if commF then
		pcall(function()
			commF:InvokeServer("SetTeam", targetTeam)
		end)
	end

	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	local mainGui = playerGui and (playerGui:FindFirstChild("Main (minimal)") or playerGui:FindFirstChild("Main"))
	local chooseTeam = mainGui and mainGui:FindFirstChild("ChooseTeam")
	local container = chooseTeam and chooseTeam:FindFirstChild("Container")
	local teamSlot = container and container:FindFirstChild(targetTeam)
	local buttonFrame = teamSlot and teamSlot:FindFirstChild("Frame")
	local teamButton = buttonFrame and buttonFrame:FindFirstChild("TextButton")

	if teamButton then
		for _, signalConn in ipairs(getconnections(teamButton.Activated)) do
			pcall(function()
				signalConn:Function()
			end)
		end
	end
end

if not LocalPlayer.Team then
	local waitStart = os.clock()
	repeat
		selectConfiguredTeam()
		task.wait(1)
	until LocalPlayer.Team or (os.clock() - waitStart) > 30 or not isSessionActive()
end

do
	local oldPlatform = workspace:FindFirstChild("BananaCat_WaterWalk") or workspace:FindFirstChild("WaterWalk")
	if oldPlatform then
		pcall(function()
			oldPlatform:Destroy()
		end)
	end

	local waterPlatform = Instance.new("Part")
	waterPlatform.Name = "BananaCat_WaterWalk"
	waterPlatform.Anchored = true
	waterPlatform.CanCollide = true
	waterPlatform.Transparency = 1
	waterPlatform.Size = Vector3.new(2048, 1, 2048)
	waterPlatform.Position = Vector3.new(0, -3.5, 0)
	waterPlatform.Parent = workspace

	registerCleanupCallback(function()
		if waterPlatform and waterPlatform.Parent then
			waterPlatform:Destroy()
		end
	end)

	task.spawn(function()
		while isSessionActive() do
			pcall(function()
				local character = LocalPlayer.Character
				local rootPart = character and character:FindFirstChild("HumanoidRootPart")
				if rootPart and waterPlatform and waterPlatform.Parent then
					local mapFolder = workspace:FindFirstChild("Map")
					local waterBasePlane = mapFolder and mapFolder:FindFirstChild("WaterBase-Plane")
					local surfaceY = waterBasePlane and (waterBasePlane.Position.Y - 9) or -3.5
					waterPlatform.Position = Vector3.new(rootPart.Position.X, surfaceY, rootPart.Position.Z)
				end
			end)
			task.wait(0.25)
		end
	end)
end

do
	local isReconnecting = false
	local lastReconnectClock = 0

	local function fetchFallbackServerJobId()
		if not httpRequest then
			return nil
		end
		local apiUrl =
			string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
		local ok, response = pcall(httpRequest, { Url = apiUrl, Method = "GET" })
		if not ok or type(response) ~= "table" or not response.Body then
			return nil
		end
		local decodedOk, decoded = pcall(HttpService.JSONDecode, HttpService, response.Body)
		if not decodedOk or type(decoded) ~= "table" or type(decoded.data) ~= "table" then
			return nil
		end
		for _, entry in ipairs(decoded.data) do
			local serverId = entry and entry.id
			local playing = tonumber(entry.playing) or 0
			local maxPlayers = tonumber(entry.maxPlayers) or 12
			if
				serverId
				and tostring(serverId) ~= tostring(game.JobId)
				and playing > 0
				and playing < (maxPlayers - 1)
			then
				return tostring(serverId)
			end
		end
		return nil
	end

	local function handleUnexpectedDisconnect(reason)
		if isReconnecting or not isSessionActive() or (os.clock() - lastReconnectClock) < 8 then
			return
		end
		isReconnecting = true
		lastReconnectClock = os.clock()

		task.spawn(function()
			warn(
				"[BananaCat Kaitun] Phát hiện ngắt kết nối ("
					.. tostring(reason)
					.. ") -> Đang tự động kết nối lại..."
			)
			task.wait(2)
			while isSessionActive() do
				local targetJobId = fetchFallbackServerJobId()
				if targetJobId then
					pcall(function()
						TeleportService:TeleportToPlaceInstance(game.PlaceId, targetJobId, LocalPlayer)
					end)
				else
					pcall(function()
						TeleportService:Teleport(game.PlaceId, LocalPlayer)
					end)
				end
				task.wait(5)
			end
			isReconnecting = false
		end)
	end

	UnifiedReconnect = handleUnexpectedDisconnect

	pcall(function()
		local promptGui = CoreGui:FindFirstChild("RobloxPromptGui") or CoreGui:WaitForChild("RobloxPromptGui", 5)
		local promptOverlay = promptGui and promptGui:FindFirstChild("promptOverlay")
		if promptOverlay then
			trackSessionConnection(promptOverlay.ChildAdded:Connect(function(child)
				if child.Name == "ErrorPrompt" then
					handleUnexpectedDisconnect("ErrorPrompt")
				end
			end))
			if promptOverlay:FindFirstChild("ErrorPrompt") then
				handleUnexpectedDisconnect("ExistingErrorPrompt")
			end
		end
	end)

	trackSessionConnection(LogService.MessageOut:Connect(function(message, messageType)
		if messageType == Enum.MessageType.MessageError then
			local lowerMsg = string.lower(tostring(message))
			if
				string.find(lowerMsg, "disconnected", 1, true)
				or string.find(lowerMsg, "kick", 1, true)
				or string.find(lowerMsg, "teleport failed", 1, true)
				or string.find(lowerMsg, "connection attempt failed", 1, true)
			then
				handleUnexpectedDisconnect(message)
			end
		end
	end))
end

local reportThrottleMap = {}
local function Report(errorText)
	local message = tostring(errorText or "Unknown error")
	local now = os.clock()
	if reportThrottleMap[message] and (now - reportThrottleMap[message]) < 15 then
		return
	end
	reportThrottleMap[message] = now
	warn("[BananaCat Kaitun] " .. message)
end

local function formatNumberWithCommas(numberValue)
	local formatted = tostring(math.floor(tonumber(numberValue) or 0))
	while true do
		local updated, count = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		formatted = updated
		if count == 0 then
			break
		end
	end
	return formatted
end

local hasBoughtSkyjump = false
local hasBoughtBuso = false
local hasBoughtSoru = false
local hasBoughtObservation = false

local function createKaitunHUD(sessionTiming)
	sessionTiming = sessionTiming or {}
	local sessionStartUnix = tonumber(sessionTiming.StartTime) or os.time()
	local previousTotalSeconds = tonumber(sessionTiming.OldSessionTime) or 0

	local HUD_ICONS = {
		ChevronDown = "rbxassetid://7733717447",
		Minus = "rbxassetid://7734000129",
		Target = "rbxassetid://7743872758",
		Shield = "rbxassetid://7734056608",
		Cpu = "rbxassetid://7733765398",
		Crown = "rbxassetid://7733765045",
		Coins = "rbxassetid://7743866529",
		Gem = "rbxassetid://7733954760",
		Swords = "rbxassetid://7743872929",
	}

	local THEME = {
		DashboardBg = Color3.fromRGB(11, 14, 21),
		DeckBg = Color3.fromRGB(17, 22, 33),
		CardGlow = Color3.fromRGB(28, 36, 54),
		BorderGlass = Color3.fromRGB(58, 70, 96),
		ChampagneGold = Color3.fromRGB(246, 206, 112),
		GoldDark = Color3.fromRGB(85, 68, 28),
		EmeraldMint = Color3.fromRGB(72, 232, 168),
		CrystalCyan = Color3.fromRGB(88, 204, 255),
		AmberGold = Color3.fromRGB(255, 196, 77),
		VividPurple = Color3.fromRGB(184, 128, 255),
		ErrorRed = Color3.fromRGB(248, 113, 113),
		TextPure = Color3.fromRGB(244, 247, 255),
		TextSub = Color3.fromRGB(168, 180, 204),
		FontTitle = Enum.Font.GothamBold,
		FontBody = Enum.Font.GothamMedium,
		FontNumbers = Enum.Font.GothamBlack,
		Quick = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		SpringBouncy = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		SpringExpand = TweenInfo.new(0.38, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		SpringCollapse = TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
	}

	local uiContainer = gethui() or CoreGui
	for _, child in ipairs(uiContainer:GetChildren()) do
		if child.Name == "BananaCatKaitunUI" then
			pcall(function()
				child:Destroy()
			end)
		end
	end
	for _, effect in ipairs(Lighting:GetChildren()) do
		if effect.Name == "BananaCatKaitunBlur" then
			pcall(function()
				effect:Destroy()
			end)
		end
	end

	local activeTweens = {}
	local function playUiTween(instance, properties, tweenInfo)
		if not instance then
			return nil
		end
		if activeTweens[instance] then
			pcall(function()
				activeTweens[instance]:Cancel()
			end)
		end
		local tween = TweenService:Create(instance, tweenInfo or THEME.Quick, properties)
		activeTweens[instance] = tween
		tween:Play()
		return tween
	end

	local function cancelUiTween(instance)
		if instance and activeTweens[instance] then
			pcall(function()
				activeTweens[instance]:Cancel()
			end)
			activeTweens[instance] = nil
		end
	end

	local uiState = {
		IsOpen = true,
		CurrentIslandTask = "LevelFarm • Active",
		IslandTransitionId = 0,
		LastIslandTransitionAt = 0,
		Labels = {},
	}

	local function bindTweenOnce(tween, expectedTransitionId, callback)
		if not tween or type(callback) ~= "function" then
			return
		end
		tween.Completed:Once(function()
			if expectedTransitionId and uiState.IslandTransitionId ~= expectedTransitionId then
				return
			end
			callback()
		end)
	end

	local function createUiElement(className, properties)
		local instance = Instance.new(className)
		local childList = {}
		local targetParent = nil
		for key, value in pairs(properties or {}) do
			if type(key) == "number" then
				table.insert(childList, value)
			elseif key == "Parent" then
				targetParent = value
			else
				instance[key] = value
			end
		end
		for _, child in ipairs(childList) do
			if typeof(child) == "Instance" then
				child.Parent = instance
			end
		end
		if targetParent then
			instance.Parent = targetParent
		end
		return instance
	end

	local isCompactMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local currentCamera = workspace.CurrentCamera

	local screenGui = createUiElement("ScreenGui", {
		Name = "BananaCatKaitunUI",
		Parent = uiContainer,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	local blurEffect = createUiElement("BlurEffect", {
		Name = "BananaCatKaitunBlur",
		Parent = Lighting,
		Size = 24,
	})

	registerCleanupCallback(function()
		if screenGui and screenGui.Parent then
			screenGui:Destroy()
		end
		if blurEffect and blurEffect.Parent then
			blurEffect:Destroy()
		end
	end)

	local islandWidth = isCompactMobile and 290 or 340
	local islandHeight = isCompactMobile and 34 or 38
	local islandTopOffset = isCompactMobile and 28 or 33
	local islandDefaultSize = UDim2.fromOffset(islandWidth, islandHeight)
	local islandAnchorPos = UDim2.new(0.5, 0, 0, islandTopOffset)
	local dashboardCenterPos = UDim2.new(0.5, 0, 0.5, 0)

	local dynamicIslandButton = createUiElement("TextButton", {
		Name = "DynamicIsland",
		Parent = screenGui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = islandAnchorPos,
		Size = islandDefaultSize,
		BackgroundColor3 = THEME.DashboardBg,
		BackgroundTransparency = 0.08,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 80,
		createUiElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})

	local islandBorderGradient = createUiElement("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, THEME.ChampagneGold),
			ColorSequenceKeypoint.new(0.5, THEME.EmeraldMint),
			ColorSequenceKeypoint.new(1, THEME.BorderGlass),
		}),
		Rotation = 45,
	})

	createUiElement("UIStroke", {
		Parent = dynamicIslandButton,
		Color = Color3.new(1, 1, 1),
		Thickness = 1.3,
		Transparency = 0.25,
		islandBorderGradient,
	})

	local statusPulseRing = createUiElement("Frame", {
		Parent = dynamicIslandButton,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 18, 0.5, 0),
		Size = UDim2.new(0, 9, 0, 9),
		BackgroundColor3 = THEME.EmeraldMint,
		BackgroundTransparency = 1,
		ZIndex = 81,
		createUiElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})

	local statusDot = createUiElement("Frame", {
		Parent = dynamicIslandButton,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 18, 0.5, 0),
		Size = UDim2.new(0, 9, 0, 9),
		BackgroundColor3 = THEME.EmeraldMint,
		ZIndex = 82,
		createUiElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})

	createUiElement("TextLabel", {
		Parent = dynamicIslandButton,
		Position = UDim2.new(0, 32, 0, 0),
		Size = UDim2.new(0, 62, 1, 0),
		BackgroundTransparency = 1,
		Font = THEME.FontTitle,
		Text = "KAITUN",
		TextColor3 = THEME.ChampagneGold,
		TextSize = isCompactMobile and 11 or 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 82,
	})

	local compactTaskClip = createUiElement("Frame", {
		Parent = dynamicIslandButton,
		Position = UDim2.new(0, 96, 0, 0),
		Size = UDim2.new(1, -124, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 81,
	})

	local compactTaskLabel = createUiElement("TextLabel", {
		Name = "CompactTaskLabel",
		Parent = compactTaskClip,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Font = THEME.FontBody,
		Text = "LevelFarm • Active",
		TextColor3 = THEME.TextPure,
		TextSize = isCompactMobile and 11.5 or 12.5,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 82,
	})

	local islandChevronIcon = createUiElement("ImageLabel", {
		Parent = dynamicIslandButton,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 14, 0, 14),
		BackgroundTransparency = 1,
		Image = HUD_ICONS.ChevronDown,
		ImageColor3 = THEME.ChampagneGold,
		Rotation = 180,
		ZIndex = 82,
	})

	local function pulseStatusIndicator(accentColor)
		statusPulseRing.BackgroundColor3 = accentColor or statusDot.BackgroundColor3
		statusPulseRing.Size = UDim2.new(0, 9, 0, 9)
		statusPulseRing.BackgroundTransparency = 0.35
		playUiTween(
			statusPulseRing,
			{ Size = UDim2.new(0, 26, 0, 26), BackgroundTransparency = 1 },
			TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		)
	end

	local function sweepIslandGradient()
		islandBorderGradient.Rotation = 45
		playUiTween(
			islandBorderGradient,
			{ Rotation = 225 },
			TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		)
	end

	local function updateDynamicIslandText(summaryText, accentColor)
		local formatted = tostring(summaryText or "Active")
		if uiState.CurrentIslandTask == formatted then
			return
		end

		uiState.CurrentIslandTask = formatted
		uiState.IslandTransitionId += 1
		local transitionId = uiState.IslandTransitionId
		local now = os.clock()
		local isRapidUpdate = (uiState.LastIslandTransitionAt > 0) and ((now - uiState.LastIslandTransitionAt) < 0.65)
		uiState.LastIslandTransitionAt = now

		if isRapidUpdate then
			cancelUiTween(compactTaskLabel)
			cancelUiTween(dynamicIslandButton)
			cancelUiTween(statusDot)
			cancelUiTween(statusPulseRing)
			cancelUiTween(islandBorderGradient)
			compactTaskLabel.Text = formatted
			compactTaskLabel.Position = UDim2.new(0, 0, 0.5, 0)
			compactTaskLabel.TextTransparency = 0
			dynamicIslandButton.Size = islandDefaultSize
			statusDot.Size = UDim2.new(0, 9, 0, 9)
			statusDot.BackgroundColor3 = accentColor or THEME.EmeraldMint
			statusPulseRing.Size = UDim2.new(0, 9, 0, 9)
			statusPulseRing.BackgroundTransparency = 1
			return
		end

		bindTweenOnce(
			playUiTween(compactTaskLabel, { Position = UDim2.new(0, 0, 0.5, -18), TextTransparency = 1 }, THEME.Quick),
			transitionId,
			function()
				compactTaskLabel.Text = formatted
				compactTaskLabel.Position = UDim2.new(0, 0, 0.5, 18)
				playUiTween(
					compactTaskLabel,
					{ Position = UDim2.new(0, 0, 0.5, 0), TextTransparency = 0 },
					THEME.SpringBouncy
				)
			end
		)

		bindTweenOnce(
			playUiTween(
				dynamicIslandButton,
				{ Size = UDim2.fromOffset(islandWidth + 24, islandHeight - 4) },
				TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			),
			transitionId,
			function()
				bindTweenOnce(
					playUiTween(
						dynamicIslandButton,
						{ Size = UDim2.fromOffset(islandWidth - 6, islandHeight + 3) },
						TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					),
					transitionId,
					function()
						playUiTween(dynamicIslandButton, { Size = islandDefaultSize }, THEME.SpringBouncy)
					end
				)
			end
		)

		pulseStatusIndicator(accentColor)
		sweepIslandGradient()

		if accentColor then
			bindTweenOnce(
				playUiTween(statusDot, { BackgroundColor3 = accentColor, Size = UDim2.new(0, 12, 0, 12) }, THEME.Quick),
				transitionId,
				function()
					playUiTween(statusDot, { Size = UDim2.new(0, 9, 0, 9) }, THEME.SpringBouncy)
				end
			)
		end
	end

	local dashboardFrame = createUiElement("Frame", {
		Name = "Dashboard",
		Parent = screenGui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = dashboardCenterPos,
		Size = UDim2.new(0, 600, 0, 440),
		BackgroundColor3 = THEME.DashboardBg,
		BackgroundTransparency = 0.18,
		ClipsDescendants = true,
		Visible = true,
		ZIndex = 50,
	})

	local dashboardScale = createUiElement("UIScale", { Parent = dashboardFrame, Scale = 1 })
	local function refreshViewportScale()
		local viewport = (currentCamera and currentCamera.ViewportSize) or Vector2.new(1280, 720)
		if isCompactMobile or viewport.X < 750 or viewport.Y < 500 then
			dashboardScale.Scale = math.clamp(math.min(viewport.X / 680, viewport.Y / 490), 0.6, 0.82)
		else
			dashboardScale.Scale = 1
		end
	end

	if currentCamera then
		trackSessionConnection(currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshViewportScale))
		refreshViewportScale()
	end

	local dashboardCorner = createUiElement("UICorner", {
		Parent = dashboardFrame,
		CornerRadius = UDim.new(0, 24),
	})

	createUiElement("UIStroke", {
		Parent = dashboardFrame,
		Color = Color3.new(1, 1, 1),
		Thickness = 1.4,
		Transparency = 0.22,
		createUiElement("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, THEME.ChampagneGold),
				ColorSequenceKeypoint.new(0.5, THEME.CrystalCyan),
				ColorSequenceKeypoint.new(1, THEME.BorderGlass),
			}),
			Rotation = 45,
		}),
	})

	local glassReflectionFrame = createUiElement("Frame", {
		Parent = dashboardFrame,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.93,
		BorderSizePixel = 0,
		ZIndex = 50,
		createUiElement("UICorner", { CornerRadius = UDim.new(0, 24) }),
		createUiElement("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(190, 225, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 13, 20)),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.78),
				NumberSequenceKeypoint.new(0.35, 0.92),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rotation = 65,
		}),
	})

	local innerRimFrame = createUiElement("Frame", {
		Parent = dashboardFrame,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 50,
		createUiElement("UICorner", { CornerRadius = UDim.new(0, 23) }),
		createUiElement("UIStroke", {
			Color = Color3.new(1, 1, 1),
			Thickness = 1,
			Transparency = 0.78,
			createUiElement("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
					ColorSequenceKeypoint.new(0.4, Color3.fromRGB(150, 200, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 30, 45)),
				}),
				Rotation = 90,
			}),
		}),
	})

	local headerBar = createUiElement("Frame", {
		Parent = dashboardFrame,
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = THEME.DeckBg,
		BackgroundTransparency = 0.5,
		ZIndex = 52,
		createUiElement("UICorner", { CornerRadius = UDim.new(0, 24) }),
		createUiElement("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, THEME.CardGlow),
				ColorSequenceKeypoint.new(1, THEME.DeckBg),
			}),
			Rotation = 90,
		}),
	})

	createUiElement("TextLabel", {
		Parent = headerBar,
		Position = UDim2.new(0, 18, 0, 0),
		Size = UDim2.new(0, 190, 1, 0),
		BackgroundTransparency = 1,
		Font = THEME.FontTitle,
		Text = "BANANA CAT HUB",
		TextColor3 = THEME.ChampagneGold,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 53,
	})

	createUiElement("Frame", {
		Parent = headerBar,
		Position = UDim2.new(0, 195, 0.5, -11),
		Size = UDim2.new(0, 80, 0, 22),
		BackgroundColor3 = Color3.fromRGB(16, 38, 28),
		BackgroundTransparency = 0.3,
		ZIndex = 53,
		createUiElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
		createUiElement("UIStroke", { Color = THEME.EmeraldMint, Thickness = 1, Transparency = 0.4 }),
		createUiElement("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 9, 0.5, 0),
			Size = UDim2.new(0, 6, 0, 6),
			BackgroundColor3 = THEME.EmeraldMint,
			BorderSizePixel = 0,
			ZIndex = 54,
			createUiElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),
		createUiElement("TextLabel", {
			Position = UDim2.new(0, 20, 0, 0),
			Size = UDim2.new(1, -24, 1, 0),
			BackgroundTransparency = 1,
			Font = THEME.FontTitle,
			Text = "ACTIVE",
			TextColor3 = THEME.EmeraldMint,
			TextSize = 10.5,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 54,
		}),
	})

	local minimizeButton = createUiElement("TextButton", {
		Parent = headerBar,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0, 28, 0, 28),
		BackgroundColor3 = THEME.DeckBg,
		BackgroundTransparency = 0.3,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 54,
		createUiElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
		createUiElement("UIStroke", { Color = THEME.BorderGlass, Thickness = 1, Transparency = 0.4 }),
		createUiElement("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0, 13, 0, 13),
			BackgroundTransparency = 1,
			Image = HUD_ICONS.Minus,
			ImageColor3 = THEME.TextPure,
			ZIndex = 55,
		}),
	})

	minimizeButton.MouseEnter:Connect(function()
		playUiTween(minimizeButton, { BackgroundColor3 = THEME.GoldDark }, THEME.Quick)
	end)
	minimizeButton.MouseLeave:Connect(function()
		playUiTween(minimizeButton, { BackgroundColor3 = THEME.DeckBg }, THEME.Quick)
	end)

	local isDraggingWindow = false
	local latestDragInput = nil
	local dragOriginPointer = nil
	local dragOriginPosition = nil

	headerBar.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			isDraggingWindow = true
			dragOriginPointer = input.Position
			dragOriginPosition = dashboardFrame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					isDraggingWindow = false
				end
			end)
		end
	end)

	headerBar.InputChanged:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			latestDragInput = input
		end
	end)

	trackSessionConnection(UserInputService.InputChanged:Connect(function(input)
		if input == latestDragInput and isDraggingWindow and uiState.IsOpen then
			local delta = input.Position - dragOriginPointer
			dashboardFrame.Position = UDim2.new(
				dragOriginPosition.X.Scale,
				dragOriginPosition.X.Offset + delta.X,
				dragOriginPosition.Y.Scale,
				dragOriginPosition.Y.Offset + delta.Y
			)
		end
	end))

	local function createGlassCard(parentInstance, position, size, accentColor)
		return createUiElement("Frame", {
			Parent = parentInstance,
			Position = position,
			Size = size,
			BackgroundColor3 = THEME.DeckBg,
			BackgroundTransparency = 0.45,
			ZIndex = 52,
			createUiElement("UICorner", { CornerRadius = UDim.new(0, 12) }),
			createUiElement("UIStroke", {
				Name = "Stroke",
				Color = Color3.new(1, 1, 1),
				Thickness = 1.1,
				Transparency = 0.4,
				createUiElement("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, accentColor),
						ColorSequenceKeypoint.new(1, THEME.BorderGlass),
					}),
					Rotation = 45,
				}),
			}),
			createUiElement("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, THEME.CardGlow),
					ColorSequenceKeypoint.new(1, THEME.DeckBg),
				}),
				Rotation = 90,
			}),
		})
	end

	local profileCard =
		createGlassCard(dashboardFrame, UDim2.new(0, 14, 0, 52), UDim2.new(1, -28, 0, 36), THEME.BorderGlass)
	createUiElement("ImageLabel", {
		Parent = profileCard,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.new(0, 26, 0, 26),
		BackgroundTransparency = 1,
		Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId) .. "&w=150&h=150",
		ZIndex = 53,
		createUiElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
		createUiElement("UIStroke", { Color = THEME.ChampagneGold, Thickness = 1, Transparency = 0.5 }),
	})
	createUiElement("TextLabel", {
		Parent = profileCard,
		Position = UDim2.new(0, 38, 0, 0),
		Size = UDim2.new(0, 230, 1, 0),
		BackgroundTransparency = 1,
		Font = THEME.FontTitle,
		Text = string.format("%s (@%s)", tostring(LocalPlayer.DisplayName), tostring(LocalPlayer.Name)),
		TextColor3 = THEME.TextPure,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 53,
	})
	local uptimeLabel = createUiElement("TextLabel", {
		Parent = profileCard,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0, 270, 1, 0),
		BackgroundTransparency = 1,
		Font = THEME.FontBody,
		Text = "Uptime: 00:00:00",
		TextColor3 = THEME.ChampagneGold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 53,
	})

	local missionCard =
		createGlassCard(dashboardFrame, UDim2.new(0, 14, 0, 94), UDim2.new(0, 355, 0, 140), THEME.ChampagneGold)
	createUiElement("Frame", {
		Parent = missionCard,
		Position = UDim2.new(0, 12, 0, 10),
		Size = UDim2.new(0, 138, 0, 20),
		BackgroundColor3 = Color3.fromRGB(38, 32, 16),
		BackgroundTransparency = 0.3,
		ZIndex = 53,
		createUiElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
		createUiElement("UIStroke", { Color = THEME.ChampagneGold, Thickness = 1, Transparency = 0.4 }),
		createUiElement("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.new(0, 12, 0, 12),
			BackgroundTransparency = 1,
			Image = HUD_ICONS.Target,
			ImageColor3 = THEME.ChampagneGold,
			ZIndex = 54,
		}),
		createUiElement("TextLabel", {
			Position = UDim2.new(0, 24, 0, 0),
			Size = UDim2.new(1, -26, 1, 0),
			BackgroundTransparency = 1,
			Font = THEME.FontTitle,
			Text = "MISSION CONTROL",
			TextColor3 = THEME.ChampagneGold,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 54,
		}),
	})

	local mainTaskLabel = createUiElement("TextLabel", {
		Parent = missionCard,
		Position = UDim2.new(0, 12, 0, 36),
		Size = UDim2.new(1, -24, 0, 94),
		BackgroundTransparency = 1,
		Font = THEME.FontBody,
		Text = "...",
		TextColor3 = THEME.TextPure,
		TextSize = 13.5,
		TextWrapped = true,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 53,
	})

	local rightColumn = createUiElement("Frame", {
		Parent = dashboardFrame,
		Position = UDim2.new(0, 377, 0, 94),
		Size = UDim2.new(0, 209, 0, 140),
		BackgroundTransparency = 1,
		ZIndex = 52,
	})

	local sideTaskCard = createGlassCard(rightColumn, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 66), THEME.CrystalCyan)
	createUiElement("ImageLabel", {
		Parent = sideTaskCard,
		Position = UDim2.new(0, 10, 0, 7),
		Size = UDim2.new(0, 13, 0, 13),
		BackgroundTransparency = 1,
		Image = HUD_ICONS.Shield,
		ImageColor3 = THEME.CrystalCyan,
		ZIndex = 53,
	})
	createUiElement("TextLabel", {
		Parent = sideTaskCard,
		Position = UDim2.new(0, 28, 0, 6),
		Size = UDim2.new(1, -38, 0, 14),
		BackgroundTransparency = 1,
		Font = THEME.FontTitle,
		Text = "AUXILIARY TASK",
		TextColor3 = THEME.CrystalCyan,
		TextSize = 10.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 53,
	})
	local sideTaskLabel = createUiElement("TextLabel", {
		Parent = sideTaskCard,
		Position = UDim2.new(0, 10, 0, 24),
		Size = UDim2.new(1, -20, 0, 36),
		BackgroundTransparency = 1,
		Font = THEME.FontBody,
		Text = "None",
		TextColor3 = THEME.TextSub,
		TextSize = 12.5,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 53,
	})

	local engineControllerCard =
		createGlassCard(rightColumn, UDim2.new(0, 0, 0, 74), UDim2.new(1, 0, 0, 66), THEME.EmeraldMint)
	createUiElement("ImageLabel", {
		Parent = engineControllerCard,
		Position = UDim2.new(0, 10, 0, 7),
		Size = UDim2.new(0, 13, 0, 13),
		BackgroundTransparency = 1,
		Image = HUD_ICONS.Cpu,
		ImageColor3 = THEME.EmeraldMint,
		ZIndex = 53,
	})
	createUiElement("TextLabel", {
		Parent = engineControllerCard,
		Position = UDim2.new(0, 28, 0, 6),
		Size = UDim2.new(1, -38, 0, 14),
		BackgroundTransparency = 1,
		Font = THEME.FontTitle,
		Text = "ENGINE CONTROLLER",
		TextColor3 = THEME.EmeraldMint,
		TextSize = 10.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 53,
	})
	local debugLineLabel = createUiElement("TextLabel", {
		Parent = engineControllerCard,
		Position = UDim2.new(0, 10, 0, 24),
		Size = UDim2.new(1, -20, 0, 36),
		BackgroundTransparency = 1,
		Font = THEME.FontBody,
		Text = "Idle",
		TextColor3 = THEME.TextSub,
		TextSize = 12.5,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 53,
	})

	local currenciesRow = createUiElement("Frame", {
		Parent = dashboardFrame,
		Position = UDim2.new(0, 14, 0, 242),
		Size = UDim2.new(1, -28, 0, 70),
		BackgroundTransparency = 1,
		ZIndex = 52,
	})

	local function createMetricCard(xPos, accentColor, iconAsset, titleText, initialText)
		local card = createGlassCard(currenciesRow, UDim2.new(0, xPos, 0, 0), UDim2.new(0, 180, 1, 0), accentColor)
		createUiElement("ImageLabel", {
			Parent = card,
			Position = UDim2.new(0, 10, 0, 8),
			Size = UDim2.new(0, 13, 0, 13),
			BackgroundTransparency = 1,
			Image = iconAsset,
			ImageColor3 = accentColor,
			ZIndex = 53,
		})
		createUiElement("TextLabel", {
			Parent = card,
			Position = UDim2.new(0, 28, 0, 8),
			Size = UDim2.new(1, -38, 0, 14),
			BackgroundTransparency = 1,
			Font = THEME.FontTitle,
			Text = titleText,
			TextColor3 = accentColor,
			TextSize = 10.5,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 53,
		})
		return createUiElement("TextLabel", {
			Parent = card,
			Position = UDim2.new(0, 12, 0, 24),
			Size = UDim2.new(1, -24, 0, 36),
			BackgroundTransparency = 1,
			Font = THEME.FontNumbers,
			Text = initialText,
			TextColor3 = THEME.TextPure,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 53,
		})
	end

	local levelLabel = createMetricCard(0, THEME.EmeraldMint, HUD_ICONS.Crown, "PLAYER LEVEL", "0")
	local beliLabel = createMetricCard(196, THEME.AmberGold, HUD_ICONS.Coins, "BELI WEALTH", "$ 0")
	local fragmentsLabel = createMetricCard(392, THEME.VividPurple, HUD_ICONS.Gem, "FRAGMENTS", "0")

	local arsenalCard =
		createGlassCard(dashboardFrame, UDim2.new(0, 14, 0, 320), UDim2.new(1, -28, 0, 95), THEME.VividPurple)
	createUiElement("ImageLabel", {
		Parent = arsenalCard,
		Position = UDim2.new(0, 12, 0, 8),
		Size = UDim2.new(0, 14, 0, 14),
		BackgroundTransparency = 1,
		Image = HUD_ICONS.Swords,
		ImageColor3 = THEME.VividPurple,
		ZIndex = 53,
	})
	createUiElement("TextLabel", {
		Parent = arsenalCard,
		Position = UDim2.new(0, 32, 0, 8),
		Size = UDim2.new(1, -44, 0, 14),
		BackgroundTransparency = 1,
		Font = THEME.FontTitle,
		Text = "COMBAT MASTERY / ARSENAL",
		TextColor3 = THEME.VividPurple,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 53,
	})
	local arsenalLabel = createUiElement("TextLabel", {
		Parent = arsenalCard,
		Position = UDim2.new(0, 14, 0, 26),
		Size = UDim2.new(1, -28, 0, 62),
		BackgroundTransparency = 1,
		Font = THEME.FontBody,
		Text = "Scanning melee data...",
		TextColor3 = THEME.TextPure,
		TextSize = 16,
		TextWrapped = true,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 53,
	})

	for _, card in ipairs({ missionCard, sideTaskCard, engineControllerCard, arsenalCard }) do
		card.MouseEnter:Connect(function()
			playUiTween(card, { BackgroundTransparency = 0.28 }, THEME.Quick)
		end)
		card.MouseLeave:Connect(function()
			playUiTween(card, { BackgroundTransparency = 0.45 }, THEME.Quick)
		end)
	end

	uiState.Labels.Task1 = { Lbl = mainTaskLabel, Card = missionCard }
	uiState.Labels.MainTextLabel = uiState.Labels.Task1
	uiState.Labels.Task2 = { Lbl = sideTaskLabel, Card = sideTaskCard }
	uiState.Labels.DebugLine = { Lbl = debugLineLabel, Card = engineControllerCard }
	uiState.Labels.Currencies = { Lbl = levelLabel, Card = currenciesRow }
	uiState.Labels.Melees = { Lbl = arsenalLabel, Card = arsenalCard }
	uiState.Labels.LiveTime = { Lbl = uptimeLabel, Card = profileCard }

	local function setDashboardOpen(shouldOpen)
		uiState.IsOpen = shouldOpen
		if shouldOpen then
			dashboardFrame.Visible = true
			dashboardFrame.Position = islandAnchorPos
			dashboardFrame.Size = islandDefaultSize
			dashboardFrame.BackgroundTransparency = 0.18
			dashboardCorner.CornerRadius = UDim.new(1, 0)
			glassReflectionFrame.UICorner.CornerRadius = UDim.new(1, 0)
			innerRimFrame.UICorner.CornerRadius = UDim.new(1, 0)

			playUiTween(islandChevronIcon, { Rotation = 180 }, THEME.SpringBouncy)
			pulseStatusIndicator(THEME.ChampagneGold)
			sweepIslandGradient()
			playUiTween(
				dashboardFrame,
				{ Position = dashboardCenterPos, Size = UDim2.new(0, 600, 0, 440) },
				THEME.SpringExpand
			)
			playUiTween(dashboardCorner, { CornerRadius = UDim.new(0, 24) }, THEME.SpringExpand)
			playUiTween(glassReflectionFrame.UICorner, { CornerRadius = UDim.new(0, 24) }, THEME.SpringExpand)
			playUiTween(innerRimFrame.UICorner, { CornerRadius = UDim.new(0, 23) }, THEME.SpringExpand)
			playUiTween(blurEffect, { Size = 24 }, THEME.Quick)

			bindTweenOnce(
				playUiTween(
					dynamicIslandButton,
					{ Size = UDim2.fromOffset(islandWidth + 18, islandHeight + 4) },
					THEME.Quick
				),
				nil,
				function()
					playUiTween(dynamicIslandButton, { Size = islandDefaultSize }, THEME.SpringExpand)
				end
			)
		else
			playUiTween(islandChevronIcon, { Rotation = 0 }, THEME.SpringBouncy)
			local collapseTween = playUiTween(
				dashboardFrame,
				{ Position = islandAnchorPos, Size = islandDefaultSize },
				THEME.SpringCollapse
			)
			playUiTween(dashboardCorner, { CornerRadius = UDim.new(1, 0) }, THEME.SpringCollapse)
			playUiTween(glassReflectionFrame.UICorner, { CornerRadius = UDim.new(1, 0) }, THEME.SpringCollapse)
			playUiTween(innerRimFrame.UICorner, { CornerRadius = UDim.new(1, 0) }, THEME.SpringCollapse)
			playUiTween(blurEffect, { Size = 0 }, THEME.Quick)

			bindTweenOnce(collapseTween, nil, function()
				if uiState.IsOpen then
					return
				end
				dashboardFrame.Visible = false
				bindTweenOnce(
					playUiTween(
						dynamicIslandButton,
						{ Size = UDim2.fromOffset(islandWidth + 22, islandHeight + 4) },
						THEME.Quick
					),
					nil,
					function()
						playUiTween(dynamicIslandButton, { Size = islandDefaultSize }, THEME.SpringExpand)
					end
				)
				pulseStatusIndicator(THEME.EmeraldMint)
				sweepIslandGradient()
			end)
		end
	end

	local function toggleUI(explicitOpen)
		if explicitOpen == nil then
			setDashboardOpen(not uiState.IsOpen)
		else
			setDashboardOpen(explicitOpen and true or false)
		end
	end

	dynamicIslandButton.MouseButton1Click:Connect(function()
		toggleUI()
	end)
	minimizeButton.MouseButton1Click:Connect(function()
		toggleUI(false)
	end)

	trackSessionConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.RightControl then
			toggleUI()
		end
	end))

	local function getPlayerStatNumber(statKey)
		if type(ScriptStorage) == "table" and type(ScriptStorage.PlayerData) == "table" then
			return tonumber(ScriptStorage.PlayerData[statKey]) or 0
		end
		local dataFolder = LocalPlayer:FindFirstChild("Data")
		local statObj = dataFolder and dataFolder:FindFirstChild(statKey)
		return statObj and tonumber(statObj.Value) or 0
	end

	local function setText(labelName, textValue)
		local entry = uiState.Labels[labelName]
		local formatted = tostring(textValue or "")
		if entry and entry.Lbl then
			entry.Lbl.Text = formatted
		end
		if labelName == "Task1" or labelName == "MainTextLabel" then
			local cleanMain = formatted:gsub("\n.*", ""):gsub("<[^>]->", "")
			local lowerMain = cleanMain:lower()
			local accent = THEME.EmeraldMint
			if lowerMain:find("error", 1, true) or lowerMain:find("loi", 1, true) then
				accent = THEME.ErrorRed
			elseif lowerMain:find("waiting", 1, true) or lowerMain:find("loading", 1, true) then
				accent = THEME.AmberGold
			end
			updateDynamicIslandText(cleanMain, accent)
		end
	end

	local isAutoBuyingHaki = false
	local lastAutoBuyHakiClock = 0

	local function tryAutoPurchaseHakiAsync()
		if isAutoBuyingHaki or (os.clock() - lastAutoBuyHakiClock) < 15 then
			return
		end
		local buyHakiCfg = Config["Buy Haki"]
		if type(buyHakiCfg) ~= "table" then
			return
		end
		isAutoBuyingHaki = true
		lastAutoBuyHakiClock = os.clock()

		task.spawn(function()
			local commF = getCommFRemote()
			if commF then
				local currentBeli = getPlayerStatNumber("Beli")
				if buyHakiCfg.Skyjump and not hasBoughtSkyjump and currentBeli >= 10000 then
					local ok, res = pcall(commF.InvokeServer, commF, "BuyHaki", "Geppo")
					if ok and (res == 1 or res == 2) then
						hasBoughtSkyjump = true
					end
				end
				currentBeli = getPlayerStatNumber("Beli")
				if buyHakiCfg.Buso and not hasBoughtBuso and currentBeli >= 25000 then
					local ok, res = pcall(commF.InvokeServer, commF, "BuyHaki", "Buso")
					if ok and (res == 1 or res == 2) then
						hasBoughtBuso = true
					end
				end
				currentBeli = getPlayerStatNumber("Beli")
				if buyHakiCfg.Soru and not hasBoughtSoru and currentBeli >= 100000 then
					local ok, res = pcall(commF.InvokeServer, commF, "BuyHaki", "Soru")
					if ok and (res == 1 or res == 2) then
						hasBoughtSoru = true
					end
				end
				currentBeli = getPlayerStatNumber("Beli")
				if buyHakiCfg.Observation and not hasBoughtObservation and currentBeli >= 750000 then
					local ok, res = pcall(commF.InvokeServer, commF, "KenTalk", "Buy")
					if ok and (res == 1 or res == 2) then
						hasBoughtObservation = true
					end
				end
			end
			isAutoBuyingHaki = false
		end)
	end

	local MELEE_BADGES = {
		{ Name = "Superhuman", Tag = "SH" },
		{ Name = "Death Step", Tag = "DS" },
		{ Name = "Sharkman Karate", Tag = "SK" },
		{ Name = "Electric Claw", Tag = "EC" },
		{ Name = "Dragon Talon", Tag = "DT" },
		{ Name = "Godhuman", Tag = "GH" },
		{ Name = "Sanguine Art", Tag = "SA" },
	}

	local RARE_ITEM_BADGES = {
		{ Name = "Cursed Dual Katana", Tag = "CDK" },
		{ Name = "Yama", Tag = "YM" },
		{ Name = "Tushita", Tag = "TS" },
		{ Name = "Soul Guitar", Tag = "SG" },
		{ Name = "Valkyrie Helm", Tag = "VH" },
		{ Name = "Mirror Fractal", Tag = "MF" },
	}

	local lastTimeSaveUnix = 0

	local function syncRuntimeUI()
		local currentSessionElapsed = math.max(0, os.time() - sessionStartUnix)
		local cumulativeElapsed = currentSessionElapsed + previousTotalSeconds
		local nowUnix = os.time()

		if (nowUnix - lastTimeSaveUnix) >= 10 then
			lastTimeSaveUnix = nowUnix
			pcall(function()
				ensureDirectoryPath("BananaCatHubKaitunGodMax")
				writefile("BananaCatHubKaitunGodMax/.tdif-" .. LocalPlayer.Name, tostring(cumulativeElapsed))
			end)
		end

		local sessionStr = tostring(currentSessionElapsed) .. "s"
		local totalStr = tostring(cumulativeElapsed) .. "s"
		if type(DispTime) == "function" then
			local callSucceeded, executionResult = pcall(DispTime, currentSessionElapsed, true)
			if callSucceeded and executionResult then
				sessionStr = executionResult
			end
			local callSucceededCurrent, executionResultCurrent = pcall(DispTime, cumulativeElapsed, true)
			if callSucceededCurrent and executionResultCurrent then
				totalStr = executionResultCurrent
			end
		end

		setText("LiveTime", string.format("Session: %s | Total: %s", sessionStr, totalStr))
		levelLabel.Text = formatNumberWithCommas(getPlayerStatNumber("Level"))
		beliLabel.Text = "$ " .. formatNumberWithCommas(getPlayerStatNumber("Beli"))
		fragmentsLabel.Text = formatNumberWithCommas(getPlayerStatNumber("Fragments"))

		tryAutoPurchaseHakiAsync()

		if type(ScriptStorage) == "table" then
			local taskInfo = ScriptStorage.Task or {}
			local mainTaskDisplay = tostring(taskInfo.MainTask or "Idle")
			if taskInfo.QuestDebug and taskInfo.QuestDebug ~= "" then
				mainTaskDisplay = mainTaskDisplay
					.. '\n<font color="#7DD3FC">'
					.. tostring(taskInfo.QuestDebug)
					.. "</font>"
			end
			setText("Task1", mainTaskDisplay)
			setText("Task2", tostring(taskInfo.SideTask or "None"))

			local meleesMap = ScriptStorage.Melees or {}
			local backpackMap = ScriptStorage.Backpack or {}
			local meleeChunks = {}
			for _, badge in ipairs(MELEE_BADGES) do
				local mastery = tonumber(meleesMap[badge.Name])
				if mastery and mastery >= 0 then
					table.insert(
						meleeChunks,
						string.format('<font color="#48E8A8"><b>%s</b></font>:%d', badge.Tag, mastery)
					)
				else
					table.insert(meleeChunks, string.format('<font color="#6E7A94">%s</font>', badge.Tag))
				end
			end

			local rareChunks = {}
			for _, item in ipairs(RARE_ITEM_BADGES) do
				if backpackMap[item.Name] then
					table.insert(rareChunks, string.format('<font color="#F6CE70"><b>%s</b></font>', item.Tag))
				end
			end

			local arsenalText = table.concat(meleeChunks, "  ")
			if #rareChunks > 0 then
				arsenalText = arsenalText .. "\n" .. table.concat(rareChunks, " • ")
			end
			arsenalLabel.Text = arsenalText
		end
	end

	setDashboardOpen(true)

	return {
		Instances = {
			Task1 = mainTaskLabel,
			MainTextLabel = mainTaskLabel,
			Task2 = sideTaskLabel,
			DebugLine = debugLineLabel,
			Currencies = levelLabel,
			Melees = arsenalLabel,
			LiveTime = uptimeLabel,
		},
		SetText = setText,
		SyncRuntimeUI = syncRuntimeUI,
		ToggleUI = toggleUI,
		ToggleInterface = toggleUI,
		BlurManager = {},
		State = uiState,
		GUI = screenGui,
	}
end

local function startKaitunEngine()
	local lastIdleTick, runtimeUI, bindPlayerDataValueObject, ItemReplicationService, getReplicatedFruitPrice
	local electroQuestCheckTick, cachedElectroQuestReady, resetElectroQuestCache, getTeamPlayerSpawnsFolder, cachedPlayerSpawnsFolder
	local SUBMARINE_ENTER_CFRAME, nextSubmarineInvokeClock, SUBMARINE_EXIT_FALLBACK_CFRAME, SUBMERGED_QUEST_IDS, SUBMERGED_QUEST_GIVER_NAMES
	local isPositionInSubmergedIsland, findNpcCFrame, isPlayerInSubmergedIsland, resetCurrentQuest, QuestController

	do
		_G.Stop = false
		ensureDirectoryPath("BananaCatHubKaitunGodMax")

		local engineStartUnix = os.time()
		lastIdleTick = engineStartUnix

		local savedTimePath = "BananaCatHubKaitunGodMax/.tdif-" .. LocalPlayer.Name
		local previousElapsed = isfile(savedTimePath) and (tonumber(readfile(savedTimePath)) or 0) or 0
		OldSessionTime = previousElapsed

		runtimeUI = createKaitunHUD({
			StartTime = engineStartUnix,
			OldSessionTime = OldSessionTime,
		})

		local activeCharacter = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
		while not activeCharacter or not activeCharacter:FindFirstChild("HumanoidRootPart") do
			task.wait(0.1)
			activeCharacter = LocalPlayer.Character
		end

		if Config.DisableIslandLOD == true then
			task.spawn(function()
				local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
				if playerScripts then
					local newLod = playerScripts:WaitForChild("NewIslandLOD", 30)
					if newLod then
						pcall(newLod.Destroy, newLod)
					end
					local oldLod = playerScripts:WaitForChild("IslandLOD", 30)
					if oldLod then
						pcall(oldLod.Destroy, oldLod)
					end
				end
			end)
		end

		StartTick = tick()
		local unixTimestamp = os.time()
		ScriptStorage = {
			IsInitalized = false,
			PlayerData = {},
			Melees = {},
			MeleesOwned = {},
			TargetMelee = nil,
			MeleesLiveScanDone = false,
			CurrentMeleeData = {},
			Enemies = {},
			Tools = {},
			Backpack = {},
			IgnoreStoreFruits = {},
			Connections = { LocalPlayer = {} },
			Task = {},
			Tracebacks = {},
			TaskController = {},
			TracebackUpdater = {},
			Interface = runtimeUI,
			NPCs = {},
			Map = {},
		}
		Character = activeCharacter
		Humanoid = activeCharacter:WaitForChild("Humanoid")
		HumanoidRootPart = activeCharacter:WaitForChild("HumanoidRootPart")
		PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
		Services = setmetatable({}, {
			__index = function(serviceCache, serviceName)
				local ok, serviceInstance = pcall(game.GetService, game, serviceName)
				if ok and serviceInstance then
					rawset(serviceCache, serviceName, serviceInstance)
					return serviceInstance
				end
				return nil
			end,
		})

		if Config.FpsBoost then
			if not _G.FPSB then
				_G.FPSB = true

				local constructedObject = setmetatable({}, {
					__index = function(primaryArg, secondaryArg)
						local ok, result = pcall(game.GetService, game, secondaryArg)
						if ok then
							rawset(primaryArg, secondaryArg, result)
							return result
						end
					end,
				})

				constructedObject.RunService:Set3dRenderingEnabled(not _G.NR)
				constructedObject.Lighting.GlobalShadows = false
				constructedObject.Lighting.FogEnd = 9000000000
				constructedObject.Lighting.FogStart = 9000000000
				constructedObject.Lighting.Brightness = 1
				constructedObject.Lighting.ClockTime = 14
				constructedObject.Lighting.EnvironmentDiffuseScale = 0
				constructedObject.Lighting.EnvironmentSpecularScale = 0

				pcall(function()
					settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
				end)

				pcall(function()
					sethiddenproperty(constructedObject.Lighting, "Technology", 2)
				end)

				pcall(function()
					local terrain = workspace.Terrain
					terrain.WaterWaveSize = 0
					terrain.WaterWaveSpeed = 0
					terrain.WaterReflectance = 0
					terrain.WaterTransparency = 0
					terrain.Decoration = false
				end)

				for _, descendant in ipairs(constructedObject.Lighting:GetDescendants()) do
					pcall(function()
						if descendant:IsA("Sky") then
							descendant.SkyboxBk = ""
							descendant.SkyboxDn = ""
							descendant.SkyboxFt = ""
							descendant.SkyboxLf = ""
							descendant.SkyboxRt = ""
							descendant.SkyboxUp = ""
							descendant.StarCount = 0
							descendant.MoonSize = 0
							descendant.SunAngularSize = 0
							return
						end

						if descendant:IsA("Atmosphere") then
							descendant.Density = 0
							descendant.Glare = 0
							descendant.Haze = 0
							return
						end

						if descendant:IsA("Clouds") then
							descendant.Enabled = false
							return
						end

						if descendant:IsA("PostEffect") then
							descendant.Enabled = false
							return
						end
					end)
				end

				local function findAncestorHumanoid(primaryArg)
					local model = primaryArg:FindFirstAncestorWhichIsA("Model")

					if model then
						local humanoid = model:FindFirstChildOfClass("Humanoid")
						if humanoid then
							return humanoid
						end
						local isCheckPassed = model.Name == "Characters"
						if isCheckPassed then
							return isCheckPassed
						end
						local isCheckPassedCurrent = model.Name == "Enemies"
						if isCheckPassedCurrent then
							return isCheckPassedCurrent
						end
						return model.Name == "NPCs"
					end

					return model
				end

				local function isPlayerCharacterDescendant(primaryArg)
					local players, iterState = constructedObject.Players:GetPlayers()

					for _, nextItem in next, players, iterState do
						if nextItem.Character then
							if primaryArg:IsDescendantOf(nextItem.Character) then
								return true
							end
						end
					end

					return false
				end

				local function optimizeInstanceForFps(targetInstance)
					if targetInstance then
						if targetInstance.Parent then
							pcall(function()
								if not targetInstance:IsA("Humanoid") then
									if not targetInstance:IsA("ProximityPrompt") then
										if not targetInstance:IsA("ClickDetector") then
											if not targetInstance:IsA("Camera") then
												if not targetInstance:IsA("SpawnLocation") then
													if not targetInstance:IsA("Tool") then
														if not targetInstance:IsA("BaseScript") then
															if not targetInstance:IsA("RemoteEvent") then
																if not targetInstance:IsA("RemoteFunction") then
																	if targetInstance:IsA("BillboardGui") then
																		return
																	end

																	if targetInstance:IsA("ScreenGui") then
																		return
																	end

																	if targetInstance:IsA("SurfaceGui") then
																		return
																	end

																	if isPlayerCharacterDescendant(targetInstance) then
																		return
																	end

																	if targetInstance:IsA("ParticleEmitter") then
																		targetInstance.Enabled = false
																		targetInstance.Rate = 0
																		targetInstance.Lifetime = NumberRange.new(0, 0)
																		return
																	end

																	if not targetInstance:IsA("Fire") then
																		if not targetInstance:IsA("Smoke") then
																			if not targetInstance:IsA("Sparkles") then
																				if targetInstance:IsA("Trail") then
																					targetInstance.Enabled = false
																					return
																				end

																				if targetInstance:IsA("Beam") then
																					targetInstance.Enabled = false
																					return
																				end

																				if targetInstance:IsA("Highlight") then
																					targetInstance.Enabled = false
																					return
																				end

																				if
																					targetInstance:IsA("SelectionBox")
																				then
																					targetInstance.Enabled = false
																					return
																				end

																				if targetInstance:IsA("Explosion") then
																					targetInstance.Visible = false
																					return
																				end

																				if targetInstance:IsA("Light") then
																					targetInstance.Enabled = false
																					return
																				end

																				if targetInstance:IsA("Decal") then
																					targetInstance.Transparency = 1
																					return
																				end

																				if targetInstance:IsA("Texture") then
																					targetInstance.Transparency = 1
																					return
																				end

																				if targetInstance:IsA("Sound") then
																					local lower =
																						targetInstance.Name:lower()

																					if not lower:find("ambient") then
																						if not lower:find("music") then
																							if
																								not lower:find("wind")
																							then
																								if
																									not lower:find(
																										"water"
																									)
																								then
																									if
																										not lower:find(
																											"bgm"
																										)
																									then
																										if
																											not lower:find(
																												"background"
																											)
																										then
																											if
																												not lower:find(
																													"ocean"
																												)
																											then
																												if
																													lower:find(
																														"rain"
																													)
																												then
																													targetInstance.Volume =
																														0
																													targetInstance.Playing =
																														false
																													return
																												end

																												return
																											end
																										end
																									end
																								end
																							end
																						end
																					end

																					targetInstance.Volume = 0
																					targetInstance.Playing = false
																					return
																				end

																				if targetInstance:IsA("BasePart") then
																					if
																						not targetInstance:FindFirstAncestor(
																							"FX"
																						)
																					then
																						if
																							not targetInstance:FindFirstAncestor(
																								"Effects"
																							)
																						then
																							if
																								not targetInstance:FindFirstAncestor(
																									"Debris"
																								)
																							then
																								if
																									findAncestorHumanoid(
																										targetInstance
																									)
																								then
																									return
																								end

																								if
																									targetInstance.Name
																									== "HumanoidRootPart"
																								then
																									return
																								end

																								if
																									targetInstance.Name
																									== "Head"
																								then
																									return
																								end
																							end
																						end
																					end

																					targetInstance.Transparency = 1
																					targetInstance.CastShadow = false
																					targetInstance.Reflectance = 0
																					targetInstance.Material =
																						Enum.Material.SmoothPlastic

																					if
																						targetInstance:IsA("MeshPart")
																					then
																						pcall(function()
																							targetInstance.TextureID =
																								""
																						end)
																					end

																					return
																				end

																				return
																			end
																		end
																	end

																	targetInstance.Enabled = false
																	return
																end
															end
														end
													end
												end
											end
										end
									end
								end
							end)

							return
						end
					end
				end

				task.spawn(function()
					local descendants = workspace:GetDescendants()

					for i = 1, #descendants do
						optimizeInstanceForFps(descendants[i])

						if (i % 300) == 0 then
							task.wait()
						end
					end

					for _, descendant in ipairs(constructedObject.ReplicatedStorage:GetDescendants()) do
						pcall(function()
							if descendant:IsA("ParticleEmitter") then
								descendant.Enabled = false
								descendant.Rate = 0
								descendant.Lifetime = NumberRange.new(0, 0)
								return
							end

							if descendant:IsA("Fire") then
								descendant.Enabled = false
								return
							end

							if descendant:IsA("Smoke") then
								descendant.Enabled = false
								return
							end

							if descendant:IsA("Sparkles") then
								descendant.Enabled = false
								return
							end

							if descendant:IsA("Trail") then
								descendant.Enabled = false
								return
							end

							if descendant:IsA("Beam") then
								descendant.Enabled = false
								return
							end
						end)
					end
				end)

				if _G.FPSBConn then
					pcall(function()
						_G.FPSBConn:Disconnect()
					end)
				end

				_G.FPSBConn = workspace.DescendantAdded:Connect(function(descendant)
					task.defer(optimizeInstanceForFps, descendant)
				end)
			end
		end

		shared.BananaEnemyWeaponCleanupVersion = (shared.BananaEnemyWeaponCleanupVersion or 0) + 1

		setmetatable(ScriptStorage.Enemies, {
			__index = function(primaryArg, childName)
				local firstChild = Services.Workspace.Enemies:FindFirstChild(childName)
				if firstChild then
					return firstChild
				end
				return (Services.ReplicatedStorage:FindFirstChild(childName))
			end,
		})

		setmetatable(ScriptStorage.Map, {
			__index = function(primaryArg, childName)
				local firstChild = Services.Workspace.Map:FindFirstChild(childName)
				if firstChild then
					return firstChild
				end
				return (Services.Workspace:FindFirstChild(childName))
			end,
		})

		setmetatable(ScriptStorage.Tools, {
			__index = function(primaryArg, childName)
				local character = LocalPlayer.Character
				local backpack = LocalPlayer:FindFirstChild("Backpack")

				if character then
					local firstChild = character:FindFirstChild(childName)
					if firstChild then
						return firstChild
					end
				end

				if backpack then
					return (backpack:FindFirstChild(childName))
				end
				return backpack
			end,
		})

		MeleeDataFile = "BananaCatHubKaitunGodMax" .. ("/" .. (tostring(LocalPlayer.Name) .. "MeleeData"))

		setmetatable(ScriptStorage.NPCs, {
			__index = function(_, npcName)
				local workspaceNpcs = workspace:FindFirstChild("NPCs")
				local foundNpc = workspaceNpcs and workspaceNpcs:FindFirstChild(npcName, true)
				if foundNpc then
					return foundNpc
				end

				local replicatedNpcs = ReplicatedStorage:FindFirstChild("NPCs")
				foundNpc = replicatedNpcs and replicatedNpcs:FindFirstChild(npcName, true)
				if foundNpc then
					return foundNpc
				end

				local mapFolder = workspace:FindFirstChild("Map")
				foundNpc = mapFolder and mapFolder:FindFirstChild(npcName, true)
				if foundNpc then
					return foundNpc
				end

				return workspace:FindFirstChild(npcName, true)
			end,
		})

		local function appendTracebackEntry(primaryArg, secondaryArg)
			local dispTime = DispTime
			table.insert(
				ScriptStorage.Tracebacks,
				GetCurrentDateTime()
					.. (
						" ( "
						.. (
							dispTime(os.time() - unixTimestamp, true)
							.. (" ) after execution | " .. (primaryArg .. (" | " .. secondaryArg)))
						)
					)
			)
			if #ScriptStorage.Tracebacks > 30 then
				table.remove(ScriptStorage.Tracebacks, 1)
				return
			end
		end

		CreateTraceback = appendTracebackEntry

		task.spawn(function()
			while task.wait(60) do
				if not _G.Stop then
					pcall(function()
						local debris = workspace:FindFirstChild("Debris")

						if debris then
							for _, child in ipairs(debris:GetChildren()) do
								pcall(function()
									child:Destroy()
								end)
							end
						end

						local cutParts = workspace:FindFirstChild("CutParts")

						if cutParts then
							for _, child in ipairs(cutParts:GetChildren()) do
								pcall(function()
									child:Destroy()
								end)
							end
						end

						for _, child in ipairs(workspace:GetChildren()) do
							if child:IsA("ParticleEmitter") then
								pcall(function()
									child:Destroy()
								end)
							elseif child:IsA("Beam") then
								pcall(function()
									child:Destroy()
								end)
							elseif child:IsA("Trail") then
								pcall(function()
									child:Destroy()
								end)
							elseif child:IsA("Explosion") then
								pcall(function()
									child:Destroy()
								end)
							end
						end
					end)

					if ScriptStorage then
						if ScriptStorage.Tracebacks then
							if #ScriptStorage.Tracebacks > 30 then
								while #ScriptStorage.Tracebacks > 20 do
									table.remove(ScriptStorage.Tracebacks, 1)
								end
							end
						end
					end

					continue
				end

				break
			end
		end)

		SetTask = function(primaryArg, secondaryArg)
			if secondaryArg ~= nil then
				if ScriptStorage.Task[primaryArg] ~= tostring(secondaryArg) then
					ScriptStorage.Task[primaryArg] = tostring(secondaryArg)
					return
				end
				return
			end
		end

		Remotes = {}

		setmetatable(Remotes, {
			__index = function(primaryArg, secondaryArg)
				if secondaryArg ~= "CommF_" then
					return Services.ReplicatedStorage.Remotes[secondaryArg]
				end

				return {
					InvokeServer = function(...)
						return Services.ReplicatedStorage.Remotes.CommF_:InvokeServer(select(2, ...))
					end,
				}
			end,
		})

		Tasks = {}

		AwaitUntilPlayerLoaded = function(playerInstance)
			while isSessionActive() do
				local charModel = playerInstance and playerInstance.Character
				local humComp = charModel and charModel:FindFirstChildOfClass("Humanoid")
				if humComp and humComp.Health > 0 then
					break
				end
				task.wait(0.1)
			end
		end

		AddPoint = function()
			if LocalPlayer:FindFirstChild("Data") then
				local points = LocalPlayer.Data:FindFirstChild("Points")

				if points then
					local storedValueNum = tonumber(points.Value)

					if storedValueNum then
						if storedValueNum <= 0 then
							return
						end
						local stats = LocalPlayer.Data:FindFirstChild("Stats")

						if stats then
							local configRecord = { Defense = 0, Melee = 0, Sword = 0 }

							for _, childInst in stats:GetChildren() do
								if childInst:FindFirstChild("Level") then
									configRecord[childInst.Name] = childInst.Level.Value
								end
							end

							local level = ScriptStorage.PlayerData.Level

							if not level then
								if LocalPlayer.Data:FindFirstChild("Level") then
									level = LocalPlayer.Data.Level.Value or 0
								else
									level = 0
								end
							end

							local statusMessage, measuredValue, invokeAddStatPoint

							if configRecord.Defense < MaxLevel then
								if configRecord.Defense < (level / 80) then
									statusMessage = "Defense"
								elseif (MaxLevel - configRecord.Melee) < 100 then
									statusMessage = "Defense"

									invokeAddStatPoint = function()
										Remotes.CommF_:InvokeServer("AddPoint", statusMessage, storedValueNum)
									end

									pcall(invokeAddStatPoint)
									return
								elseif configRecord.Melee < MaxLevel then
									statusMessage = "Melee"
								else
									statusMessage = "Sword"
								end
							elseif configRecord.Melee < MaxLevel then
								statusMessage = "Melee"
							else
								statusMessage = "Sword"
							end

							invokeAddStatPoint = function()
								Remotes.CommF_:InvokeServer("AddPoint", statusMessage, storedValueNum)
							end

							pcall(invokeAddStatPoint)
							return
						end

						return
					end
				end
			end
		end

		GetLiveLevel = function()
			local ok, result = pcall(function()
				return LocalPlayer.Data.Level.Value
			end)

			if ok then
				if tonumber(result) then
					return result
				end
			end

			local level = ScriptStorage.PlayerData.Level
			if level then
				return level
			end
			return 0
		end

		RefreshPlayerData = function()
			local data = LocalPlayer:FindFirstChild("Data")

			if data then
				for _, childInst in data:GetChildren() do
					pcall(function()
						ScriptStorage.PlayerData[childInst.Name] = childInst.Value
					end)
				end

				ScriptStorage.PlayerData.Level = GetLiveLevel()
				return
			end
		end

		local function syncValueObjectToPlayerData(valueBaseObj)
			if valueBaseObj then
				if valueBaseObj:IsA("ValueBase") then
					ScriptStorage.PlayerData[valueBaseObj.Name] = valueBaseObj.Value

					if ScriptStorage.Interface then
						if ScriptStorage.Interface.SyncRuntimeUI then
							pcall(ScriptStorage.Interface.SyncRuntimeUI)
							return
						end
					end

					return
				end

				return
			end
		end

		bindPlayerDataValueObject = function(child)
			if child then
				if child:IsA("ValueBase") then
					syncValueObjectToPlayerData(child)
					local combinedText = "Data_" .. child.Name

					if ScriptStorage.Connections.LocalPlayer[combinedText] then
						pcall(function()
							ScriptStorage.Connections.LocalPlayer[combinedText]:Disconnect()
						end)
					end

					ScriptStorage.Connections.LocalPlayer[combinedText] = child.Changed:Connect(function()
						syncValueObjectToPlayerData(child)
					end)

					return
				end
			end
		end

		local function refreshPlayerRaceTier()
			ScriptStorage.PlayerData.RaceLevel = 1
			local charModel = LocalPlayer.Character
			if charModel and charModel:FindFirstChild("RaceTransformed") then
				ScriptStorage.PlayerData.RaceLevel = 4
			end
		end

		RefreshRace = refreshPlayerRaceTier
		local ReplicatedStorage = game:GetService("ReplicatedStorage")

		if pcall(function()
			return require(ReplicatedStorage.ItemReplicationService)
		end) then
			ItemReplicationService = require(ReplicatedStorage.ItemReplicationService) or nil
		else
			ItemReplicationService = nil
		end

		local ItemId

		if pcall(function()
			return require(ReplicatedStorage.Economy.ItemId)
		end) then
			ItemId = require(ReplicatedStorage.Economy.ItemId) or nil
		else
			ItemId = nil
		end

		local collectedItems = {}
		local initialCounter = 0

		getReplicatedFruitPrice = function(fruitIdentifier)
			if not fruitIdentifier then
				return 0
			end
			if (os.clock() - initialCounter) > 300 or not next(collectedItems) then
				pcall(function()
					local response = Remotes.CommF_:InvokeServer("GetFruits")
					if type(response) ~= "table" then
						return
					end
					for _, fruitEntry in ipairs(response) do
						if fruitEntry and fruitEntry.Name and fruitEntry.Price then
							collectedItems[fruitEntry.Name] = fruitEntry.Price
							local shortName = string.gsub(fruitEntry.Name, "%-.*", "")
							collectedItems[shortName] = fruitEntry.Price
							collectedItems[shortName .. " Fruit"] = fruitEntry.Price
						end
					end
					initialCounter = os.clock()
				end)
			end

			local rawKey = tostring(fruitIdentifier)
			if collectedItems[rawKey] then
				return collectedItems[rawKey]
			end
			local cleanKey = string.gsub(string.gsub(rawKey, " Fruit", ""), "%-.*", "")
			return collectedItems[cleanKey] or 0
		end

		local function refreshPlayerInventory()
			local backpack = {}

			if not ItemId then
				pcall(function()
					ItemId = require(ReplicatedStorage.Economy.ItemId)
				end)
			end

			if not ItemReplicationService then
				local function loadItemReplicationModule()
					ItemReplicationService = require(ReplicatedStorage.ItemReplicationService)
				end

				pcall(loadItemReplicationModule)
			end

			if ItemId then
				if ItemReplicationService then
					local ok, result = pcall(function()
						return ItemId._IDS:unwrap()
					end)

					if ok then
						if type(result) == "table" then
							local initialCounterCurrent, storageKey, scopedValue

							for _, resultItem in ipairs(result) do
								local id = resultItem and resultItem.Id
								local scopedValueCurrent, type_, measuredValue, gatheredItems, scopedValueTarget, checkPassed

								if not ((type(id) ~= "table") or not id.ItemId) then
									initialCounterCurrent = tonumber(
										ItemReplicationService:ReadItem(ItemReplicationService.KEYS.QUANTITY, id.ItemId)
									) or 0

									if
										ItemReplicationService:ReadItem(ItemReplicationService.KEYS.IS_OWNED, id.ItemId)
										== true
									then
										storageKey = (id.StorageKey or resultItem.Name) or tostring(id.ItemId)
										scopedValueCurrent = tostring
										type_ = id.Type or "Material"
										scopedValue = scopedValueCurrent(type_)

										local itemValue
										if scopedValue == "PhysicalMoveset" then
											local fruitPrice = getReplicatedFruitPrice(storageKey)
											itemValue = (fruitPrice and fruitPrice > 0) and fruitPrice or 1
										else
											itemValue = initialCounterCurrent
										end

										local itemRecord = {
											Name = storageKey,
											Count = initialCounterCurrent,
											Value = itemValue,
											Amount = initialCounterCurrent,
											Type = scopedValue,
											ItemId = id.ItemId,
										}
										backpack[storageKey] = itemRecord

										if scopedValue == "PhysicalMoveset" and FruitIdToName then
											local okName, mappedFruitName = pcall(FruitIdToName, storageKey)
											if okName and mappedFruitName and mappedFruitName ~= storageKey then
												backpack[mappedFruitName] = itemRecord
											end
										end
									end
								end
							end
						end
					end
				end

				pcall(function()
					local response = Remotes.CommF_:InvokeServer("getInventoryWeapons")
					if type(response) ~= "table" then
						return
					end

					for _, responseItem in ipairs(response) do
						if responseItem then
							if responseItem.Name then
								local name = responseItem.Name
								local backpackEntry = backpack[responseItem.Name]

								if not backpackEntry then
									backpackEntry = {
										Name = responseItem.Name,
										Count = 1,
										Value = 1,
										Amount = 1,
										Type = responseItem.Type or "Weapon",
										Rarity = responseItem.Rarity or 1,
									}
								end

								backpack[name] = backpackEntry
							end
						end
					end
				end)

				pcall(function()
					local response = Remotes.CommF_:InvokeServer("getInventoryFruits")
					if type(response) ~= "table" then
						return
					end

					for _, responseItem in ipairs(response) do
						if responseItem then
							if responseItem.Name then
								local price = (responseItem.Price or getReplicatedFruitPrice(responseItem.Name)) or 1
								local configRecord = {
									Name = responseItem.Name,
									Count = responseItem.Count or 1,
									Value = price,
									Amount = responseItem.Count or 1,
									Type = "Blox Fruit",
									Price = price,
									Rarity = responseItem.Rarity or 1,
								}
								backpack[responseItem.Name] = backpack[responseItem.Name] or configRecord
								local gsub = responseItem.Name:gsub("%-.*", "")
								backpack[gsub .. " Fruit"] = backpack[gsub .. " Fruit"] or configRecord
								backpack[gsub] = backpack[gsub] or configRecord
							end
						end
					end
				end)

				if LocalPlayer then
					if LocalPlayer:FindFirstChild("Backpack") then
						for _, child in ipairs(LocalPlayer.Backpack:GetChildren()) do
							backpack[child.Name] = backpack[child.Name]
								or { Name = child.Name, Count = 1, Value = 1, Amount = 1, Type = child.ClassName }
						end
					end
				end

				if LocalPlayer then
					if LocalPlayer.Character then
						for _, child in ipairs(LocalPlayer.Character:GetChildren()) do
							if child:IsA("Tool") then
								backpack[child.Name] = backpack[child.Name]
									or { Name = child.Name, Count = 1, Value = 1, Amount = 1, Type = child.ClassName }
							end
						end
					end
				end

				pcall(function()
					local response = Remotes.CommF_:InvokeServer("getInventory")
					if type(response) ~= "table" then
						return
					end

					for _, responseItem in ipairs(response) do
						if responseItem then
							if responseItem.Name then
								backpack[responseItem.Name] = backpack[responseItem.Name] or responseItem
							end
						end
					end
				end)

				ScriptStorage.Backpack = backpack
			end

			RefreshInventory = refreshPlayerInventory

			ResearchMoves = function(primaryArg)
				if primaryArg then
					if tostring(primaryArg) == "V" then
						if ScriptStorage.Connections.BurstCheck then
							ScriptStorage.Connections.BurstCheck:Disconnect()
							task.wait(1)
						end

						ScriptStorage.Connections.BurstCheck = primaryArg.Cooldown
							:GetPropertyChangedSignal("AbsoluteSize")
							:Connect(function()
								if EnablingBurstDebounce then
									local enablingBurstDebounce = EnablingBurstDebounce
									if (os.time() - enablingBurstDebounce) < 10 then
										return
									end
								end

								if primaryArg.Cooldown.AbsoluteSize.X < 3 then
									EnablingBurstDebounce = os.time()
									task.wait(5)
									SendKey("V", 0)
									return
								end
							end)

						return
					end
				end
			end

			CheckMeleeBurstMove = function(primaryArg)
				if primaryArg.Name ~= "Black Leg" then
					if primaryArg.Name ~= "Death Step" then
						return
					end
				end

				ResearchMoves(PlayerGui.Main.Skills:WaitForChild(primaryArg.Name, 9):WaitForChild("V"))
			end

			local function resolveNonFruitItemId(primaryArg)
				if ItemId then
					local ok, result = pcall(function()
						return ItemId.getId(primaryArg, "NonFruitItem"):unwrap()
					end)

					if ok then
						if result then
							return result
						end
					end

					return nil
				end

				return nil
			end

			local function readReplicatedMeleeMastery(primaryArg)
				if ItemReplicationService then
					local resolveNonFruitItemIdCurrent = resolveNonFruitItemId(primaryArg)

					if resolveNonFruitItemIdCurrent then
						local initialCounterCurrent = tonumber(
							ItemReplicationService:ReadItem(
								ItemReplicationService.KEYS.MASTERY,
								resolveNonFruitItemIdCurrent
							)
						) or 0
						local isCheckPassed = ItemReplicationService:ReadItem(
							ItemReplicationService.KEYS.IS_OWNED,
							resolveNonFruitItemIdCurrent
						) == true
						if isCheckPassed then
							return initialCounterCurrent, isCheckPassed, resolveNonFruitItemIdCurrent
						end
						return initialCounterCurrent, initialCounterCurrent > 0, resolveNonFruitItemIdCurrent
					end

					return 0, false
				end

				return 0, false
			end

			RefreshMelees = function(primaryArg)
				if ApplyMeleeDerivedProgress then
					pcall(ApplyMeleeDerivedProgress)
				end

				local statusMessage = ""

				for k, melee in pairs(ScriptStorage.Melees) do
					if ScriptStorage.MeleesOwned[k] then
						statusMessage ..= k .. (": " .. (melee .. " "))
					else
						local meleeCopyNum = tonumber(melee)

						if meleeCopyNum then
							if meleeCopyNum > 0 then
								statusMessage ..= k .. (": " .. (melee .. " "))
							end
						end
					end
				end

				if statusMessage == "" then
					statusMessage = "[0]"
				end

				if primaryArg then
					return statusMessage
				end
			end

			LoadMeleeData = function()
				if MeleesTable then
					for _, meleeName in ipairs(MeleesTable) do
						local readReplicatedMeleeMasteryCurrent, readReplicatedMeleeMasteryTarget =
							readReplicatedMeleeMastery(meleeName)

						if readReplicatedMeleeMasteryTarget or (readReplicatedMeleeMasteryCurrent > 0) then
							local meleeStyleName = (NormalizeMeleeName and NormalizeMeleeName(meleeName)) or meleeName
							ScriptStorage.Melees[meleeStyleName] = math.max(
								tonumber(ScriptStorage.Melees[meleeStyleName]) or 0,
								readReplicatedMeleeMasteryCurrent
							)
							ScriptStorage.MeleesOwned[meleeStyleName] = true
						end
					end
				end
			end

			MeleeNameAliases = {
				["Dark Step"] = "Black Leg",
				["Water Kung Fu"] = "Fishman Karate",
				["Water Kung-fu"] = "Fishman Karate",
				Electric = "Electro",
				["Dragon Breath"] = "Dragon Claw",
			}

			NormalizeMeleeName = function(primaryArg)
				local statusMessageText = tostring(primaryArg or "")
				local meleeNameAliaseEntry = MeleeNameAliases[statusMessageText]
				if meleeNameAliaseEntry then
					return meleeNameAliaseEntry
				end
				return statusMessageText
			end

			MeleeDerivedProgress = {
				["Death Step"] = { { "Black Leg", 400 } },
				["Electric Claw"] = { { "Electro", 400 } },
				["Sharkman Karate"] = { { "Fishman Karate", 400 } },
				["Dragon Talon"] = { { "Dragon Claw", 400 } },
				Godhuman = {
					{ "Black Leg", 400 },
					{ "Electro", 400 },
					{ "Fishman Karate", 400 },
					{ "Dragon Claw", 400 },
					{ "Superhuman", 400 },
					{ "Death Step", 400 },
					{ "Electric Claw", 400 },
					{ "Sharkman Karate", 400 },
					{ "Dragon Talon", 400 },
				},
			}

			ApplyMeleeDerivedProgress = function()
				for k, melee in pairs(ScriptStorage.Melees) do
					if tonumber(melee) then
						if tonumber(melee) > 0 then
							ScriptStorage.MeleesOwned[k] = true
						end
					end
				end

				for ownedMeleeName, derivedList in pairs(MeleeDerivedProgress) do
					local ownedMastery = tonumber(ScriptStorage.Melees[ownedMeleeName])
					if ownedMastery and ownedMastery > 0 then
						ScriptStorage.MeleesOwned[ownedMeleeName] = true
						for _, prereqPair in ipairs(derivedList) do
							local prereqMeleeName = prereqPair[1]
							local minRequiredMastery = prereqPair[2]
							local currentPrereqMastery = tonumber(ScriptStorage.Melees[prereqMeleeName])
							if currentPrereqMastery then
								if currentPrereqMastery < minRequiredMastery then
									ScriptStorage.Melees[prereqMeleeName] = minRequiredMastery
								end
							elseif minRequiredMastery > 0 then
								ScriptStorage.Melees[prereqMeleeName] = minRequiredMastery
							end
							ScriptStorage.MeleesOwned[prereqMeleeName] = true
						end
					end
				end
			end

			MeleeCheck = function(toolInstance)
				if not toolInstance or typeof(toolInstance) ~= "Instance" or not toolInstance:IsA("Tool") then
					return
				end

				if toolInstance.ToolTip ~= "Melee" then
					if string.find(tostring(toolInstance), "Fruit") then
						task.spawn(function()
							local originalName = toolInstance:GetAttribute("OriginalName")
							if originalName and not table.find(ScriptStorage.IgnoreStoreFruits, originalName) then
								pcall(function()
									Remotes.CommF_:InvokeServer("StoreFruit", originalName, toolInstance)
								end)
							end
						end)
					end
					return
				end

				if ScriptStorage.Connections.Melees then
					pcall(function()
						ScriptStorage.Connections.Melees:Disconnect()
					end)
					ScriptStorage.Connections.Melees = nil
				end

				local normalizedMeleeName = NormalizeMeleeName(toolInstance.Name)
				ScriptStorage.CurrentMeleeData.Name = normalizedMeleeName

				local levelValueObj = toolInstance:FindFirstChild("Level")
				if not levelValueObj and LocalPlayer.Backpack then
					local bpTool = LocalPlayer.Backpack:FindFirstChild(toolInstance.Name)
					levelValueObj = bpTool and bpTool:FindFirstChild("Level") or nil
				end
				if not levelValueObj and LocalPlayer.Character then
					local charTool = LocalPlayer.Character:FindFirstChild(toolInstance.Name)
					levelValueObj = charTool and charTool:FindFirstChild("Level") or nil
				end

				local function syncEquippedMeleeMastery(rawLevel)
					local numericMastery = tonumber(rawLevel) or 0
					ScriptStorage.CurrentMeleeData.Level = numericMastery
					local prevMastery = tonumber(ScriptStorage.Melees[normalizedMeleeName]) or 0
					ScriptStorage.Melees[normalizedMeleeName] = math.max(prevMastery, numericMastery)
					ScriptStorage.MeleesOwned[normalizedMeleeName] = true
					ApplyMeleeDerivedProgress()
				end

				if levelValueObj then
					syncEquippedMeleeMastery(levelValueObj.Value)
					ScriptStorage.Connections.Melees = levelValueObj
						:GetPropertyChangedSignal("Value")
						:Connect(function()
							syncEquippedMeleeMastery(levelValueObj.Value)
						end)
				end

				for _, container in ipairs({ LocalPlayer.Backpack, LocalPlayer.Character }) do
					if container then
						for _, childTool in ipairs(container:GetChildren()) do
							if childTool:IsA("Tool") and childTool.ToolTip == "Melee" then
								local childLevel = childTool:FindFirstChild("Level")
								if childLevel then
									local meleeKey = NormalizeMeleeName(childTool.Name)
									local val = tonumber(childLevel.Value) or 0
									ScriptStorage.Melees[meleeKey] =
										math.max(tonumber(ScriptStorage.Melees[meleeKey]) or 0, val)
									ScriptStorage.MeleesOwned[meleeKey] = true
								end
							end
						end
					end
				end
				ApplyMeleeDerivedProgress()

				return
			end

			SyncLiveMeleeTools = function()
				local collectedItemsCurrent = { LocalPlayer.Character, LocalPlayer.Backpack }
				local isActiveState = false
				local isActiveStateCurrent = false

				for _, iteratedElement in ipairs(collectedItemsCurrent) do
					if iteratedElement then
						for _, child in ipairs(iteratedElement:GetChildren()) do
							if child:IsA("Tool") then
								if child.ToolTip == "Melee" then
									local normalizeMeleeName = NormalizeMeleeName(child.Name)
									local level = child:FindFirstChild("Level")
									local initialCounterCurrent

									if level then
										initialCounterCurrent = (
											tonumber(level.Value) or tonumber(ScriptStorage.Melees[normalizeMeleeName])
										) or 0
									else
										initialCounterCurrent = tonumber(ScriptStorage.Melees[normalizeMeleeName]) or 0
									end

									if
										(tonumber(ScriptStorage.Melees[normalizeMeleeName]) or 0)
										~= initialCounterCurrent
									then
										ScriptStorage.Melees[normalizeMeleeName] = initialCounterCurrent
										ScriptStorage.MeleesOwned[normalizeMeleeName] = true
										isActiveStateCurrent = true
									elseif not ScriptStorage.MeleesOwned[normalizeMeleeName] then
										ScriptStorage.Melees[normalizeMeleeName] = initialCounterCurrent
										ScriptStorage.MeleesOwned[normalizeMeleeName] = true
										isActiveStateCurrent = true
									end
								end
							end
						end

						isActiveState = true
					end
				end

				if MeleesTable then
					local normalizeMeleeName

					for _, meleeName in ipairs(MeleesTable) do
						local readReplicatedMeleeMasteryCurrent, readReplicatedMeleeMasteryTarget =
							readReplicatedMeleeMastery(meleeName)

						if not readReplicatedMeleeMasteryTarget then
							local initialCounterCurrent, melees, max, initialCounterTarget

							if readReplicatedMeleeMasteryCurrent > 0 then
								if NormalizeMeleeName then
									normalizeMeleeName = NormalizeMeleeName(meleeName)

									if normalizeMeleeName then
										initialCounterCurrent = tonumber(ScriptStorage.Melees[normalizeMeleeName]) or 0

										if
											(initialCounterCurrent < readReplicatedMeleeMasteryCurrent)
											or not ScriptStorage.MeleesOwned[normalizeMeleeName]
										then
											melees = ScriptStorage.Melees
											max = math.max
											initialCounterTarget = tonumber(ScriptStorage.Melees[normalizeMeleeName])
												or 0
											melees[normalizeMeleeName] =
												max(initialCounterTarget, readReplicatedMeleeMasteryCurrent)
											ScriptStorage.MeleesOwned[normalizeMeleeName] = true
											isActiveStateCurrent = true
										end
									else
										normalizeMeleeName = meleeName
										initialCounterCurrent = tonumber(ScriptStorage.Melees[normalizeMeleeName]) or 0

										if
											(initialCounterCurrent < readReplicatedMeleeMasteryCurrent)
											or not ScriptStorage.MeleesOwned[normalizeMeleeName]
										then
											melees = ScriptStorage.Melees
											max = math.max
											initialCounterTarget = tonumber(ScriptStorage.Melees[normalizeMeleeName])
												or 0
											melees[normalizeMeleeName] =
												max(initialCounterTarget, readReplicatedMeleeMasteryCurrent)
											ScriptStorage.MeleesOwned[normalizeMeleeName] = true
											isActiveStateCurrent = true
										end
									end
								else
									normalizeMeleeName = meleeName
									initialCounterCurrent = tonumber(ScriptStorage.Melees[normalizeMeleeName]) or 0

									if
										(initialCounterCurrent < readReplicatedMeleeMasteryCurrent)
										or not ScriptStorage.MeleesOwned[normalizeMeleeName]
									then
										melees = ScriptStorage.Melees
										max = math.max
										initialCounterTarget = tonumber(ScriptStorage.Melees[normalizeMeleeName]) or 0
										melees[normalizeMeleeName] =
											max(initialCounterTarget, readReplicatedMeleeMasteryCurrent)
										ScriptStorage.MeleesOwned[normalizeMeleeName] = true
										isActiveStateCurrent = true
									end
								end
							end
						end
					end

					if isActiveState then
						ScriptStorage.MeleesLiveScanDone = true

						if isActiveStateCurrent then
							pcall(ApplyMeleeDerivedProgress)

							if MeleeBuyRefreshCache then
								MeleeBuyRefreshCache.CheckedAt = 0
								MeleeBuyRefreshCache.Result = nil
							end

							RefreshMelees()

							if ScriptStorage.Interface then
								if ScriptStorage.Interface.SyncRuntimeUI then
									pcall(ScriptStorage.Interface.SyncRuntimeUI)
									return isActiveStateCurrent
								end
							end
						end
					elseif isActiveStateCurrent then
						pcall(ApplyMeleeDerivedProgress)

						if MeleeBuyRefreshCache then
							MeleeBuyRefreshCache.CheckedAt = 0
							MeleeBuyRefreshCache.Result = nil
						end

						RefreshMelees()

						if ScriptStorage.Interface then
							if ScriptStorage.Interface.SyncRuntimeUI then
								pcall(ScriptStorage.Interface.SyncRuntimeUI)
								return isActiveStateCurrent
							end
						end
					end
				elseif isActiveState then
					ScriptStorage.MeleesLiveScanDone = true

					if isActiveStateCurrent then
						pcall(ApplyMeleeDerivedProgress)

						if MeleeBuyRefreshCache then
							MeleeBuyRefreshCache.CheckedAt = 0
							MeleeBuyRefreshCache.Result = nil
						end

						RefreshMelees()

						if ScriptStorage.Interface then
							if ScriptStorage.Interface.SyncRuntimeUI then
								pcall(ScriptStorage.Interface.SyncRuntimeUI)
								return isActiveStateCurrent
							end
						end
					end
				elseif isActiveStateCurrent then
					pcall(ApplyMeleeDerivedProgress)

					if MeleeBuyRefreshCache then
						MeleeBuyRefreshCache.CheckedAt = 0
						MeleeBuyRefreshCache.Result = nil
					end

					RefreshMelees()

					if ScriptStorage.Interface then
						if ScriptStorage.Interface.SyncRuntimeUI then
							pcall(ScriptStorage.Interface.SyncRuntimeUI)
							return isActiveStateCurrent
						end
					end
				end

				return isActiveStateCurrent
			end

			LoadMeleeData()
			RefreshMelees()
			SetTask("MainTask", "Refreshing Player Data")
			MeleeCheck(LocalPlayer.Character:FindFirstChildOfClass("Tool"))
			SyncLiveMeleeTools()
			RefreshPlayerData()

			if LocalPlayer.Character then
				MeleeCheck(LocalPlayer.Character:FindFirstChildOfClass("Tool"))
			end
			SyncLiveMeleeTools()
			RefreshPlayerData()

			RegisterLocalPlayerEventsConnection = function()
				if type(ScriptStorage.Connections.LocalPlayer) == "table" then
					for connKey, existingConn in pairs(ScriptStorage.Connections.LocalPlayer) do
						pcall(function()
							existingConn:Disconnect()
						end)
						ScriptStorage.Connections.LocalPlayer[connKey] = nil
					end
				else
					ScriptStorage.Connections.LocalPlayer = {}
				end

				local dataFolder = LocalPlayer:WaitForChild("Data", 15)
				if dataFolder then
					for _, child in ipairs(dataFolder:GetChildren()) do
						bindPlayerDataValueObject(child)
					end
					ScriptStorage.Connections.LocalPlayer.DataChildAdded =
						dataFolder.ChildAdded:Connect(bindPlayerDataValueObject)
				end

				local currentChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
				local currentHumanoid = currentChar:WaitForChild("Humanoid", 15)
				local function syncCharacterHealth()
					local hum = currentChar and currentChar:FindFirstChildOfClass("Humanoid")
					local health = hum and hum.Health or 0
					LocalPlayer:SetAttribute("IsAvailable", health > 10)
					ScriptStorage.LocalPlayerHealth = health
				end
				if currentHumanoid then
					syncCharacterHealth()
					ScriptStorage.Connections.LocalPlayer.HealthCheck =
						currentHumanoid:GetPropertyChangedSignal("Health"):Connect(syncCharacterHealth)
				end
				ScriptStorage.Connections.LocalPlayer.Melee = currentChar.ChildAdded:Connect(MeleeCheck)
				local backpack = LocalPlayer:WaitForChild("Backpack", 15)
				if backpack then
					ScriptStorage.Connections.LocalPlayer.Fruit = backpack.ChildAdded:Connect(MeleeCheck)
				end

				if backpack then
					for _, backpackTool in ipairs(backpack:GetChildren()) do
						MeleeCheck(backpackTool)
					end
				end
				LastIdleCheck = os.time()

				local currentRootPart = currentChar:WaitForChild("HumanoidRootPart", 15)
				if currentRootPart then
					ScriptStorage.Connections.LocalPlayer.PositionChecker = currentRootPart
						:GetPropertyChangedSignal("CFrame")
						:Connect(function()
							local nowSec = os.time()
							if nowSec == LastIdleCheck then
								return
							end
							LastIdleCheck = nowSec
							local activeChar = LocalPlayer.Character
							local activeRoot = activeChar and activeChar:FindFirstChild("HumanoidRootPart")
							if not activeRoot then
								return
							end
							local currentPos = activeRoot.CFrame.Position
							if LastRecordedPlayerPos and (currentPos - LastRecordedPlayerPos).Magnitude < 2 then
								return
							end
							LastRecordedPlayerPos = currentPos
							lastIdleTick = nowSec
						end)
				end

				local playerDataRef = LocalPlayer:WaitForChild("Data", 15)
				local pointsValueObj = playerDataRef and playerDataRef:WaitForChild("Points", 15)
				if pointsValueObj then
					local function onAvailablePointsChanged()
						local currentPoints = pointsValueObj.Value
						if OldPointValue ~= currentPoints and currentPoints > 0 then
							OldPointValue = currentPoints
							AddPoint()
						end
					end
					ScriptStorage.Connections.LocalPlayer.PointConnection =
						pointsValueObj:GetPropertyChangedSignal("Value"):Connect(onAvailablePointsChanged)
				end
			end

			RegisterLocalPlayerEventsConnection()

			trackSessionConnection(game.Players.LocalPlayer.CharacterAdded:Connect(function()
				RegisterLocalPlayerEventsConnection()
			end))

			task.spawn(function()
				while isSessionActive() do
					local buyHakiCfg = Config["Buy Haki"]
					if not buyHakiCfg or buyHakiCfg.Buso ~= false then
						local charModel = LocalPlayer.Character
						if charModel and not charModel:FindFirstChild("HasBuso") then
							pcall(function()
								Remotes.CommF_:InvokeServer("Buso")
							end)
						end
					end
					task.wait(2)
				end
			end)

			electroQuestCheckTick = 0
			cachedElectroQuestReady = false

			resetElectroQuestCache = function()
				electroQuestCheckTick = 0
				cachedElectroQuestReady = false
			end

			HasLightningBolt = function(forceRemoteCheck)
				if ScriptStorage and ScriptStorage.Backpack then
					if ScriptStorage.Backpack["Lightning Bolt"] or ScriptStorage.Backpack["Material-1588"] then
						return true
					end
				end
				if ScriptStorage and ScriptStorage.Tools and ScriptStorage.Tools["Lightning Bolt"] then
					return true
				end
				if LocalPlayer then
					local bp = LocalPlayer:FindFirstChild("Backpack")
					if bp and bp:FindFirstChild("Lightning Bolt") then
						return true
					end
					local char = LocalPlayer.Character
					if char and char:FindFirstChild("Lightning Bolt") then
						return true
					end
				end
				if ItemReplicationService then
					local okQty, qtyResult = pcall(function()
						return ItemReplicationService:ReadItem(ItemReplicationService.KEYS.QUANTITY, 1588)
					end)
					if okQty and (tonumber(qtyResult) or 0) > 0 then
						return true
					end
					local okOwned, ownedResult = pcall(function()
						return ItemReplicationService:ReadItem(ItemReplicationService.KEYS.IS_OWNED, 1588)
					end)
					if okOwned and ownedResult == true then
						return true
					end
				end

				if cachedElectroQuestReady and not forceRemoteCheck then
					return true
				end
				if (cachedElectroQuestReady or forceRemoteCheck) and (os.clock() - electroQuestCheckTick) >= 0.5 then
					electroQuestCheckTick = os.clock()
					local okState, questState = pcall(function()
						return Remotes.CommF_:InvokeServer("ElectroQuestState")
					end)
					cachedElectroQuestReady = okState and (questState == 2 or questState == 3 or questState == 4)
				end
				return cachedElectroQuestReady
			end

			IsMeleePurchaseComplete = function(meleeName)
				local recordedMastery = tonumber(
					(ScriptStorage and ScriptStorage.Melees) and ScriptStorage.Melees[meleeName]
				) or 0
				if ScriptStorage and ScriptStorage.MeleesOwned and ScriptStorage.MeleesOwned[meleeName] then
					return true
				end
				if recordedMastery > 0 then
					return true
				end
				if ScriptStorage and ScriptStorage.Tools and ScriptStorage.Tools[meleeName] then
					return true
				end
				if LocalPlayer then
					local bp = LocalPlayer:FindFirstChild("Backpack")
					if bp and bp:FindFirstChild(meleeName) then
						return true
					end
					local char = LocalPlayer.Character
					if char and char:FindFirstChild(meleeName) then
						return true
					end
				end
				return false
			end

			MeleesTable = {
				"Black Leg",
				"Electro",
				"Fishman Karate",
				"Dragon Claw",
				"Superhuman",
				"Death Step",
				"Sharkman Karate",
				"Electric Claw",
				"Dragon Talon",
				"Godhuman",
				"SanguineArt",
			}
			MeleesId = {
				"BlackLeg",
				"Electro",
				"FishmanKarate",
				"DragonClaw",
				"Superhuman",
				"DeathStep",
				"SharkmanKarate",
				"ElectricClaw",
				"DragonTalon",
				"Godhuman",
				"SanguineArt",
			}

			local function alwaysAllowRequirement()
				return true
			end

			MeleePrices = {
				["Black Leg"] = {
					Price = { Beli = 150000 },
					Id = "BlackLeg",
					NextLevelRequirement = 400,
					Requirements = function()
						return true
					end,
					Buy = function(primaryArg)
						return BuyMelee("BlackLeg", primaryArg)
					end,
				},
				Electro = {
					Price = { Beli = 500000 },
					Id = "Electro",
					NextLevelRequirement = 400,
					Requirements = function()
						return HasLightningBolt(true)
					end,
					Buy = function(primaryArg)
						if primaryArg then
							local response = Remotes.CommF_:InvokeServer("BuyElectro", true)
							local isCheckPassed = response == 1
							if isCheckPassed then
								return isCheckPassed, response
							end
							return response == true, response
						end

						return Remotes.CommF_:InvokeServer("BuyElectro")
					end,
				},
				["Fishman Karate"] = {
					Price = { Beli = 750000 },
					NextLevelRequirement = 400,
					Requirements = alwaysAllowRequirement,
					Buy = function(primaryArg)
						return BuyMelee("FishmanKarate", primaryArg)
					end,
				},
				["Dragon Claw"] = {
					Price = { Fragments = 1500 },
					NextLevelRequirement = 400,
					Requirements = function()
						return (ScriptStorage.PlayerData.Fragments or 0) >= 1500
					end,
					Buy = function(primaryArg)
						if primaryArg then
							local response = game.ReplicatedStorage.Remotes.CommF_:InvokeServer(
								"BlackbeardReward",
								"DragonClaw",
								"1"
							)
							local isCheckPassed = response == true

							if not isCheckPassed then
								isCheckPassed = response == 1
								if not isCheckPassed then
									return response == 2, response
								end
							end

							return isCheckPassed, response
						end

						return Remotes.CommF_:InvokeServer("BlackbeardReward", "DragonClaw", "2")
					end,
				},
				Superhuman = {
					Price = { Beli = 3000000 },
					NextLevelRequirement = 400,
					Requirements = function()
						local isCheckPassed = (tonumber(ScriptStorage.Melees["Black Leg"]) or 0) >= 300

						if isCheckPassed then
							isCheckPassed = (tonumber(ScriptStorage.Melees.Electro) or 0) >= 300

							if isCheckPassed then
								isCheckPassed = (tonumber(ScriptStorage.Melees["Fishman Karate"]) or 0) >= 300
								if isCheckPassed then
									return (tonumber(ScriptStorage.Melees["Dragon Claw"]) or 0) >= 300
								end
							end
						end

						return isCheckPassed
					end,
					Buy = function(primaryArg)
						return BuyMelee("Superhuman", primaryArg)
					end,
				},
				["Death Step"] = {
					Price = { Beli = 2500000, Fragments = 5000 },
					NextLevelRequirement = 400,
					Requirements = function()
						local isCheckPassed = (tonumber(ScriptStorage.Melees["Black Leg"]) or 0) >= 400
						if isCheckPassed then
							return (ScriptStorage.PlayerData.Fragments or 0) >= 5000
						end
						return isCheckPassed
					end,
					Buy = function(primaryArg)
						return BuyMelee("DeathStep", primaryArg)
					end,
				},
				["Electric Claw"] = {
					Price = { Beli = 2500000, Fragments = 5000 },
					NextLevelRequirement = 400,
					Requirements = function()
						local isCheckPassed = SeaIndex == 3

						if isCheckPassed then
							isCheckPassed = (tonumber(ScriptStorage.Melees.Electro) or 0) >= 400
							if isCheckPassed then
								return (ScriptStorage.PlayerData.Fragments or 0) >= 5000
							end
						end

						return isCheckPassed
					end,
					Buy = function(primaryArg)
						return BuyMelee("ElectricClaw", primaryArg)
					end,
				},
				["Sharkman Karate"] = {
					Price = { Beli = 2500000, Fragments = 5000 },
					NextLevelRequirement = 400,
					Requirements = function()
						local isCheckPassed = (tonumber(ScriptStorage.Melees["Fishman Karate"]) or 0) >= 400
						if isCheckPassed then
							return (ScriptStorage.PlayerData.Fragments or 0) >= 5000
						end
						return isCheckPassed
					end,
					Buy = function(primaryArg)
						return BuyMelee("SharkmanKarate", primaryArg)
					end,
				},
				["Dragon Talon"] = {
					Price = { Beli = 3000000, Fragments = 5000 },
					NextLevelRequirement = 400,
					Requirements = function()
						local isCheckPassed = SeaIndex == 3

						if isCheckPassed then
							isCheckPassed = (tonumber(ScriptStorage.Melees["Dragon Claw"]) or 0) >= 400
							if isCheckPassed then
								return (ScriptStorage.PlayerData.Fragments or 0) >= 5000
							end
						end

						return isCheckPassed
					end,
					Buy = function(primaryArg)
						return BuyMelee("DragonTalon", primaryArg)
					end,
				},
				Godhuman = {
					Price = { Beli = 5000000, Fragments = 5000 },
					NextLevelRequirement = 350,
					Requirements = function()
						local isCheckPassed = SeaIndex == 3

						if isCheckPassed then
							isCheckPassed = (tonumber(ScriptStorage.Melees.Superhuman) or 0) >= 400

							if isCheckPassed then
								isCheckPassed = (tonumber(ScriptStorage.Melees["Death Step"]) or 0) >= 400

								if isCheckPassed then
									isCheckPassed = (tonumber(ScriptStorage.Melees["Sharkman Karate"]) or 0) >= 400

									if isCheckPassed then
										isCheckPassed = (tonumber(ScriptStorage.Melees["Electric Claw"]) or 0) >= 400

										if isCheckPassed then
											isCheckPassed = (tonumber(ScriptStorage.Melees["Dragon Talon"]) or 0) >= 400
											if isCheckPassed then
												return (ScriptStorage.PlayerData.Fragments or 0) >= 5000
											end
										end
									end
								end
							end
						end

						return isCheckPassed
					end,
					Buy = function(primaryArg)
						return BuyMelee("Godhuman", primaryArg)
					end,
				},
			}

			GodhumanMaterials = {
				["Fish Tail"] = {
					20,
					3,
					{ "Fishman Raider", "Fishman Captain" },
					{ "DeepForestIsland3", 1, 1775, "Turtle Adventure Quest Giver" },
				},
				["Dragon Scale"] = {
					10,
					3,
					{ "Dragon Crew Warrior", "Dragon Crew Archer" },
					{ "DragonCrewQuest", 1, 1575, "Dragon Crew Quest Giver" },
				},
				["Magma Ore"] = { 20, 2, { "Magma Ninja" }, { "FireSideQuest", 1, 1100, "Fire Quest Giver" } },
				["Mystic Droplet"] = {
					10,
					2,
					{ "Sea Soldier", "Water Fighter" },
					{ "ForgottenQuest", 2, 1425, "Forgotten Quest Giver" },
				},
			}
			SeaIndexes = { "Main", "Dressrosa", "Zou" }
			TasksOrder = {
				"CannonBuyController",
				"MeleeBuyController",
				"SpecialBossesTask",
				"RaidController",
				"Trevor",
				"UtillyItemsActivitation",
				"ColosseumPuzzle",
				"Wenlocktoad",
				"ThirdSeaPuzzle",
				"PirateRaid",
				"SecondSeaPuzzle",
				"ThirdSeaPuzzle",
				"CollectDrops",
				"BossesTask",
				"LevelFarm",
			}
			MaxLevel = 2800
			placeId = game.PlaceId

			if placeId ~= 2753915549 then
				if placeId ~= 85211729168715 then
					if placeId ~= 4442272183 then
						if placeId ~= 79091703265657 then
							if placeId ~= 7449423635 then
								if placeId ~= 100117331123089 then
									warn("Unknown PlaceId, defaulting SeaIndex=1:", placeId)
									Sea = "Main"
									SeaIndex = 1
								else
									Sea = "Zou"
									SeaIndex = 3
								end
							else
								Sea = "Zou"
								SeaIndex = 3
							end
						else
							Sea = "Dressrosa"
							SeaIndex = 2
						end
					else
						Sea = "Dressrosa"
						SeaIndex = 2
					end
				else
					Sea = "Main"
					SeaIndex = 1
				end
			else
				Sea = "Main"
				SeaIndex = 1
			end

			getTeamPlayerSpawnsFolder = function()
				local worldOrigin = workspace:FindFirstChild("_WorldOrigin")
				local playerSpawns = worldOrigin and worldOrigin:FindFirstChild("PlayerSpawns")
				if not playerSpawns then
					return nil
				end
				if
					LocalPlayer.Team
					and LocalPlayer.Team.Name
					and playerSpawns:FindFirstChild(LocalPlayer.Team.Name)
				then
					return playerSpawns[LocalPlayer.Team.Name]
				end
				return playerSpawns:FindFirstChild("Pirates") or playerSpawns:FindFirstChild("Marines")
			end

			cachedPlayerSpawnsFolder = getTeamPlayerSpawnsFolder()

			Portals = ({
				{
					Vector3.new(-7894.6201171875, 5545.4917, -380.246337890625),
					Vector3.new(-4607.82275390625, 872.5422973632812, -1667.556884765625),
					Vector3.new(61163.8515625, 11.759522438049316, 1819.7841796875),
					Vector3.new(3876.280517578125, 35.10614013671875, -1939.3201904296875),
				},
				{
					Vector3.new(-288.46246337890625, 306.130615234375, 597.9988403320312),
					Vector3.new(2284.912109375, 15.152046203613281, 905.48291015625),
					Vector3.new(923.2125244140625, 126.97600555419922, 32852.83203125),
					Vector3.new(-6508.55810546875, 89.03499603271484, -132.83953857421875),
				},
				{},
			})[SeaIndex]

			Sea3Entrances = {
				mansion = {
					pos = Vector3.new(-12500, 337, -7480),
					item_required = "Valkyrie Helm",
					island = "Mansion",
					verified = true,
					direct_radius = 3600,
					spawn_groups = { "BigMansion", "PineappleTown" },
				},
				hydra = {
					pos = Vector3.new(5710, 1015, -255),
					item_required = "Valkyrie Helm",
					island = "Hydra Island",
					verified = true,
					direct_radius = 3600,
					spawn_groups = { "Hydra1", "Hydra2", "Hydra3" },
				},
				sea_castle = {
					pos = Vector3.new(-5050, 315, -3150),
					item_required = "Valkyrie Helm",
					island = "Castle on the Sea",
					verified = true,
					direct_radius = 2600,
					spawn_groups = { "SeaCastle" },
				},
				great_tree = {
					pos = Vector3.new(3000, 2295, -7325),
					island = "Great Tree",
					direct_radius = 3000,
					spawn_groups = { "GreatTree" },
				},
				tiki = {
					pos = Vector3.new(-16800, 60, 290),
					item_required = "Feathered Visage",
					island = "Tiki Outpost",
					direct_radius = 3600,
					spawn_groups = { "Tiki" },
				},
				submarine = {
					pos = Vector3.new(11520, 0, 9830),
					item_required = "Feathered Visage",
					island = "Submerged Island",
					direct_radius = 3600,
					spawn_groups = { "SubmergedIsland" },
				},
			}

			local SUBMERGED_ISLAND_CENTER = Vector3.new(11256, -2138, 9888)
			local SUBMERGED_ISLAND_RADIUS = 4200
			SUBMARINE_ENTER_CFRAME = CFrame.new(
				-16269.4082,
				23.9799957,
				1371.66235,
				-0.999388933,
				0,
				-0.0349550731,
				0,
				1,
				0,
				0.0349550731,
				0,
				-0.999388933
			)
			nextSubmarineInvokeClock = 0
			SUBMARINE_EXIT_FALLBACK_CFRAME = CFrame.new(11427, -2157, 9726)
			SUBMERGED_QUEST_IDS = { SubmergedQuest1 = true, SubmergedQuest2 = true, SubmergedQuest3 = true }
			SUBMERGED_QUEST_GIVER_NAMES = {
				SubmergedQuest1 = "Submerged Quest Giver 1",
				SubmergedQuest2 = "Submerged Quest Giver 2",
				SubmergedQuest3 = "Submerged Quest Giver 3",
			}

			BossesOrder =
				{ "Awakened Ice Admiral", "Tide Keeper", "Deandre", "Urban", "Diablo", "Soul Reaper", "Cake Prince" }
			BossesOrderLevel = {
				["Awakened Ice Admiral"] = 700,
				["Tide Keeper"] = 700,
				Deandre = 1500,
				Urban = 1500,
				Diablo = 1500,
				["Cake Prince"] = 1500,
				["Soul Reaper"] = 1500,
			}
			BossesOrderWL = {
				Deandre = 1500,
				Urban = 1500,
				Diablo = 1500,
				["Cake Prince"] = 1500,
				["Don Swan"] = 1100,
				["Awakened Ice Admiral"] = 700,
				["Tide Keeper"] = 700,
			}
			SpecialBossesOrder = { Core = 700, Darkbeard = 700, ["rip_indra True Form"] = 1500, ["Dough King"] = 1500 }
			BlankTablets = { "Segment6", "Segment2", "Segment8", "Segment9", "Segment5" }
			Trophy = {
				Segment1 = "Trophy1",
				Segment3 = "Trophy2",
				Segment4 = "Trophy3",
				Segment7 = "Trophy4",
				Segment10 = "Trophy5",
			}
			Pipes = {
				Part1 = "Really black",
				Part2 = "Really black",
				Part3 = "Dusty Rose",
				Part4 = "Storm blue",
				Part5 = "Really black",
				Part6 = "Parsley green",
				Part7 = "Really black",
				Part8 = "Dusty Rose",
				Part9 = "Really black",
				Part10 = "Storm blue",
			}

			GenerateUUID = function()
				return string.gsub("xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx", "[xy]", function(ch)
					local nibble = (ch == "x") and math.random(0, 15) or math.random(8, 11)
					return string.format("%x", nibble)
				end)
			end

			CheckIsPlayerAlive = function(targetPlayer)
				targetPlayer = targetPlayer or LocalPlayer
				if not targetPlayer then
					return false
				end
				local char = targetPlayer.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local head = char and char:FindFirstChild("Head")
				return (hum ~= nil) and (root ~= nil) and (head ~= nil) and (hum.Health > 0)
			end

			ConvertTo = function(targetType, coordValue)
				return targetType.new(coordValue.X, coordValue.Y, coordValue.Z)
			end

			CaculateDistance = function(pointA, pointB)
				if not pointA then
					return 0
				end
				if not pointB then
					local char = LocalPlayer and LocalPlayer.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					if not root then
						return math.huge
					end
					pointB = root.CFrame
				end
				return (ConvertTo(Vector3, pointA) - ConvertTo(Vector3, pointB)).Magnitude
			end

			isPositionInSubmergedIsland = function(targetCoord)
				if SeaIndex ~= 3 or not targetCoord then
					return false
				end
				local pos = (typeof(targetCoord) == "CFrame") and targetCoord.Position or targetCoord
				return (pos - SUBMERGED_ISLAND_CENTER).Magnitude <= SUBMERGED_ISLAND_RADIUS
			end

			findNpcCFrame = function(npcName, fallbackCFrame)
				if ScriptStorage and ScriptStorage.NPCs then
					local npcObj = ScriptStorage.NPCs[npcName]
					if npcObj then
						local ok, resolved = pcall(function()
							if npcObj:IsA("Model") then
								return npcObj:GetModelCFrame()
									or npcObj:GetPivot()
									or (npcObj:FindFirstChild("HumanoidRootPart") and npcObj.HumanoidRootPart.CFrame)
							end
							return (npcObj:FindFirstChild("HumanoidRootPart") and npcObj.HumanoidRootPart.CFrame)
								or npcObj.CFrame
						end)
						if ok and resolved then
							return resolved
						end
					end
				end

				local wsNpcs = workspace:FindFirstChild("NPCs")
				if wsNpcs then
					local lowerTarget = tostring(npcName):lower()
					for _, child in ipairs(wsNpcs:GetChildren()) do
						local lowerName = child.Name:lower()
						if lowerName == lowerTarget or lowerName:find(lowerTarget, 1, true) then
							local ok, resolved = pcall(function()
								if child:IsA("Model") then
									return child:GetModelCFrame() or child:GetPivot()
								end
								return child.CFrame
							end)
							if ok and resolved then
								return resolved
							end
						end
					end
				end

				return fallbackCFrame
			end

			isPlayerInSubmergedIsland = function()
				local char = LocalPlayer and LocalPlayer.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				return root ~= nil and isPositionInSubmergedIsland(root.Position)
			end

			DispTime = function(primaryArg, secondaryArg)
				local parsedAmount = tonumber(primaryArg)

				if parsedAmount then
					local clampedNumber = math.floor(parsedAmount / 86400)
					local clampedNumberCurrent = math.floor(math.fmod(parsedAmount, 86400) / 3600)
					local clampedNumberTarget = math.floor(math.fmod(parsedAmount, 3600) / 60)
					local clampedNumberPrimary = math.floor(math.fmod(parsedAmount, 60))
					if secondaryArg then
						return clampedNumber
							.. (
								"day, "
								.. (
									clampedNumberCurrent
									.. (
										"hrs, "
										.. (clampedNumberTarget .. ("min, " .. (clampedNumberPrimary .. "sec.")))
									)
								)
							)
					end
					return clampedNumber .. ("day, " .. (clampedNumberCurrent .. "hrs."))
				end

				return "[err]"
			end

			GetCurrentDateTime = function()
				local date = os.date("*t")
				local day = date.day
				local month = date.month
				local year = date.year
				local scopedValue = ({ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" })[date.wday]
				return string.format("%02d:%02d ", date.hour, date.min)
					.. string.format(
						"%s, %s %d %d",
						scopedValue,
						({ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" })[month],
						day,
						year
					)
			end

			RandomArguments = function(...)
				local collectedItemsCurrent = { ... }
				return collectedItemsCurrent[math.random(0, #collectedItemsCurrent)]
			end

			RoundVector3Down = function(primaryArg)
				return Vector3.new(
					math.floor(primaryArg.X / 10) * 10,
					math.floor(primaryArg.Y / 10) * 10,
					math.floor(primaryArg.Z / 10) * 10
				)
			end

			local hoverCircleAngleDeg = 30
			lastChange = tick()

			CaculateCircreDirection = function(centerCFrame)
				if hoverCircleAngleDeg > 50000 then
					hoverCircleAngleDeg = hoverCircleAngleDeg % 360
				end

				if (tick() - lastChange) > 0.4 then
					hoverCircleAngleDeg = hoverCircleAngleDeg + 80
					lastChange = tick()
				end

				return CFrame.new(
					RoundVector3Down(
						(centerCFrame + Vector3.new(
							math.cos(math.rad(hoverCircleAngleDeg)) * 40,
							0,
							math.sin(math.rad(hoverCircleAngleDeg)) * 40
						)).Position
					)
				)
			end

			GetMonAsSortedRange = function()
				local collectedItemsCurrent = {}
				local enemies = Services.Workspace:FindFirstChild("Enemies")
				local isActiveState = false

				pcall(function()
					if SeaIndex ~= 1 then
						local character = LocalPlayer.Character

						if character then
							character = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

							if character then
								character = (math.abs(character.Position.X) > 40000)
									or (math.abs(character.Position.Z) > 40000)
							end
						end

						isActiveState = character
						return
					end
				end)

				if enemies then
					for _, child in ipairs(enemies:GetChildren()) do
						local humanoid = child:FindFirstChild("Humanoid")
						local humanoidRootPart = child:FindFirstChild("HumanoidRootPart")
						if child:FindFirstChild("Ignored") then
							continue
						end
						if humanoid then
							if humanoidRootPart then
								if humanoid.Health > 0 then
									local isUnderSurface = isActiveState and (humanoidRootPart.Position.Y < -5)
									local isValidRegion = not isActiveState
										or (math.abs(humanoidRootPart.Position.X) > 40000)
										or (math.abs(humanoidRootPart.Position.Z) > 40000)
									if not isUnderSurface and isValidRegion then
										collectedItemsCurrent[#collectedItemsCurrent + 1] = child
									end
								end
							end
						end
					end
				end

				local replicatedStorageService = game:GetService("ReplicatedStorage")

				if not isActiveState then
					if replicatedStorageService then
						for _, child in ipairs(replicatedStorageService:GetChildren()) do
							local humanoid = child:FindFirstChild("Humanoid")
							local humanoidRootPart = child:FindFirstChild("HumanoidRootPart")
							if child:FindFirstChild("Ignored") then
								continue
							end
							if humanoid then
								if humanoidRootPart then
									if humanoid.Health > 0 then
										collectedItemsCurrent[#collectedItemsCurrent + 1] = child
									end
								end
							end
						end
					end
				end

				local position, measuredValue, compareEnemiesByDistance

				if LocalPlayer.Character then
					local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

					if humanoidRootPart then
						position = humanoidRootPart.Position or Vector3.new(0, 0, 0)
					else
						position = Vector3.new(0, 0, 0)

						compareEnemiesByDistance = function(targetInstance, targetInstanceCurrent)
							local rootPart = targetInstance:FindFirstChild("HumanoidRootPart")
							local rootPartCurrent = targetInstanceCurrent:FindFirstChild("HumanoidRootPart")

							if rootPart then
								if rootPartCurrent then
									return (rootPart.Position - position).Magnitude
										< (rootPartCurrent.Position - position).Magnitude
								end
								return false
							end

							return false
						end

						table.sort(collectedItemsCurrent, compareEnemiesByDistance)
						return collectedItemsCurrent
					end
				else
					position = Vector3.new(0, 0, 0)

					compareEnemiesByDistance = function(targetInstance, targetInstanceCurrent)
						local humanoidRootPart = targetInstance:FindFirstChild("HumanoidRootPart")
						local rootPart = targetInstanceCurrent:FindFirstChild("HumanoidRootPart")

						if humanoidRootPart then
							if rootPart then
								return (humanoidRootPart.Position - position).Magnitude
									< (rootPart.Position - position).Magnitude
							end
							return false
						end

						return false
					end

					table.sort(collectedItemsCurrent, compareEnemiesByDistance)
					return collectedItemsCurrent
				end

				compareEnemiesByDistance = function(targetInstance, targetInstanceCurrent)
					local humanoidRootPart = targetInstance:FindFirstChild("HumanoidRootPart")
					local rootPart = targetInstanceCurrent:FindFirstChild("HumanoidRootPart")

					if humanoidRootPart then
						if rootPart then
							return (humanoidRootPart.Position - position).Magnitude
								< (rootPart.Position - position).Magnitude
						end
						return false
					end

					return false
				end

				table.sort(collectedItemsCurrent, compareEnemiesByDistance)
				return collectedItemsCurrent
			end

			GetMeleeIdByName = function(primaryArg)
				for k, meleeName in pairs(MeleesTable) do
					if meleeName ~= primaryArg then
						continue
					end
					return MeleesId[k]
				end
			end

			BuyMelee = function(primaryArg, secondaryArg)
				if secondaryArg then
					local response = Remotes.CommF_:InvokeServer("Buy" .. primaryArg, true)
					local isCheckPassed = response == 1
					if isCheckPassed then
						return isCheckPassed, response
					end
					return response == true, response
				end

				local response = Remotes.CommF_:InvokeServer("Buy" .. primaryArg)

				if response ~= 2 then
					if response ~= "2" then
						return response
					end
				end

				return (Remotes.CommF_:InvokeServer("Buy" .. primaryArg, true))
			end

			SendKey = function(virtualKeyCode, secondaryArg)
				local function sendVirtualKeyTap()
					game:GetService("VirtualInputManager"):SendKeyEvent(true, virtualKeyCode, false, game)
					task.wait(secondaryArg)
					game:GetService("VirtualInputManager"):SendKeyEvent(false, virtualKeyCode, false, game)
				end

				sendVirtualKeyTap()
			end

			local function convertFruitIdToDisplayName(fruitId)
				if type(fruitId) ~= "string" or fruitId == "" then
					return ""
				end
				local extractedName = string.match(fruitId, "(((%u)%-?)([^-.]+))$")
				return (extractedName or fruitId) .. " Fruit"
			end

			FruitIdToName = convertFruitIdToDisplayName

			Split = function(sourceText, delimiterPattern)
				if type(sourceText) ~= "string" then
					return {}
				end
				delimiterPattern = delimiterPattern or "%s"
				local segments = {}
				for segment in string.gmatch(sourceText, "([^" .. delimiterPattern .. "]+)") do
					table.insert(segments, segment)
				end
				return segments
			end

			FruitNameToId = function(fruitDisplayName)
				local baseName = Split(tostring(fruitDisplayName or ""))[1]
				if not baseName or baseName == "" then
					return ""
				end
				return baseName .. "-" .. baseName
			end

			local collectedItemsTarget = {}

			resetCurrentQuest = function(primaryArg, ...)
				local clockStamp = os.clock()

				if collectedItemsTarget[primaryArg] then
					if (clockStamp - collectedItemsTarget[primaryArg]) < 5 then
						return
					end
				end

				collectedItemsTarget[primaryArg] = clockStamp
				warn(...)
			end

			QuestController = {
				CurrentLevel = 2,
				DoubleQuest = true,
				CurrentQuests = {},
				BlacklistedQuestIds = { BartiloQuest = 1, CitizenQuest = 1, ImpelQuest = 1 },
			}

			while true do
				task.wait(0.05)

				if not game.Players.LocalPlayer:FindFirstChild("Data") then
					if not game.Players.LocalPlayer.DataLoaded then
						continue
					end
				end

				if not ScriptStorage then
					continue
				end
				break
			end

			QuestController.Quests = require(game.ReplicatedStorage.Quests)

			QuestController.Set = function(primaryArg, secondaryArg, tertiaryArg)
				primaryArg[secondaryArg] = tertiaryArg
			end

			QuestController.RefreshQuest = function(controller)
				local clockStamp = os.clock()
				local checkPassed, pos

				while true do
					local livePlayerLevel = GetLiveLevel()
					local missingLivePlayerLevelCopy = not livePlayerLevel

					if livePlayerLevel then
						if GetLiveLevel() == 0 then
							while (os.clock() - clockStamp) < 2 do
								task.wait(0.05)
								local initialCounterCurrent = nil

								while true do
									livePlayerLevel = GetLiveLevel()
									missingLivePlayerLevelCopy = not livePlayerLevel

									if livePlayerLevel then
										initialCounterCurrent = 1
									else
										if missingLivePlayerLevelCopy then
											if (os.clock() - clockStamp) < 2 then
												task.wait(0.05)
												continue
											end
										end
									end

									break
								end

								if initialCounterCurrent == 1 then
									if GetLiveLevel() == 0 then
										continue
									end
								end

								break
							end
						end

						local level = GetLiveLevel()

						if level then
							if level == 0 then
								level = 1
							end
						else
							level = 1
						end

						ScriptStorage.PlayerData.Level = level
						local name

						if LocalPlayer.Team then
							name = LocalPlayer.Team.Name

							if not name then
								if Config.Team ~= "Marines" then
									name = "Pirates"
								else
									name = "Marines"
								end
							end
						elseif Config.Team ~= "Marines" then
							name = "Pirates"
						else
							name = "Marines"
						end

						local isCheckPassed = level < 10
						local statusMessage

						if isCheckPassed then
							if name ~= "Marines" then
								statusMessage = "bandit"
							else
								statusMessage = "trainee"
							end
						else
							statusMessage = isCheckPassed
						end

						local function doesQuestMatchTargetFilter(primaryArg)
							if statusMessage then
								local task_ = primaryArg[1].Task or {}

								for k in pairs(task_) do
									if tostring(k):lower():find(statusMessage, 1, true) then
										return true
									end
								end

								return false
							end

							return true
						end

						local scopedValue = nil
						local levelReq = -1
						local currentQuestId = nil
						local questGroupListCopy = nil

						for k, questGroupList in pairs(QuestController.Quests) do
							if
								not QuestController.BlacklistedQuestIds[k]
								and questGroupList[1]
								and questGroupList[1].LevelReq <= level
							then
								if
									levelReq < questGroupList[1].LevelReq and doesQuestMatchTargetFilter(questGroupList)
								then
									if level < 1500 or SeaIndex ~= 2 or k ~= "ForgottenQuest" then
										levelReq = questGroupList[1].LevelReq
										currentQuestId = k
										questGroupListCopy = questGroupList
									end
								end
							end
						end

						if questGroupListCopy then
							local clonedQuests = {}
							for idx, questItem in ipairs(questGroupListCopy) do
								clonedQuests[idx] = questItem
							end
							if #clonedQuests > 1 then
								local lastQuestEntry = clonedQuests[#clonedQuests]
								if lastQuestEntry and lastQuestEntry.Task then
									for _, reqCount in pairs(lastQuestEntry.Task) do
										if reqCount == 1 then
											table.remove(clonedQuests, #clonedQuests)
											break
										end
									end
								end
							end

							controller.CurrentQuestId = currentQuestId
							controller.CurrentQuests = clonedQuests
							controller.LastRefreshLevel = level
							clockStamp = os.clock()

							local selectedSubQuest = nil
							local bestLevelReq = -1
							local selectedSubIndex = 1
							for subIdx, questItem in ipairs(clonedQuests) do
								if questItem.LevelReq <= level and questItem.LevelReq >= bestLevelReq then
									bestLevelReq = questItem.LevelReq
									selectedSubQuest = questItem
									selectedSubIndex = subIdx
								end
							end

							if selectedSubQuest then
								controller.CurrentLevel = selectedSubIndex
								local targetMonsterName = nil
								if selectedSubQuest.Task then
									for monKey in pairs(selectedSubQuest.Task) do
										targetMonsterName = monKey
										break
									end
								end

								local resolvedNpcCFrame = nil

								pcall(function()
									local guideMod = ReplicatedStorage:FindFirstChild("GuideModule")
									if guideMod then
										local guideData = require(guideMod)
										local npcList = guideData and guideData.Data and guideData.Data.NPCList
										if type(npcList) == "table" then
											for npcInst, npcInfo in pairs(npcList) do
												if type(npcInfo) == "table" and type(npcInfo.Levels) == "table" then
													for _, npcLvl in pairs(npcInfo.Levels) do
														if tonumber(npcLvl) == tonumber(selectedSubQuest.LevelReq) then
															if typeof(npcInst) == "Instance" then
																resolvedNpcCFrame = npcInst:GetPivot()
															elseif npcInfo.CFrame then
																resolvedNpcCFrame = npcInfo.CFrame
															elseif npcInfo.Position then
																resolvedNpcCFrame = CFrame.new(npcInfo.Position)
															end
															break
														end
													end
												end
												if resolvedNpcCFrame then
													break
												end
											end
										end
									end
								end)

								if
									not resolvedNpcCFrame
									and SUBMERGED_QUEST_GIVER_NAMES
									and SUBMERGED_QUEST_GIVER_NAMES[currentQuestId]
								then
									resolvedNpcCFrame = findNpcCFrame(SUBMERGED_QUEST_GIVER_NAMES[currentQuestId])
								end

								if not resolvedNpcCFrame then
									resolvedNpcCFrame = findNpcCFrame(currentQuestId)
										or (selectedSubQuest.Name and findNpcCFrame(selectedSubQuest.Name))
								end

								if
									not resolvedNpcCFrame
									and targetMonsterName
									and ScriptStorage.MobRegions
									and ScriptStorage.MobRegions[targetMonsterName]
								then
									resolvedNpcCFrame = ScriptStorage.MobRegions[targetMonsterName][1]
								end

								if not resolvedNpcCFrame and targetMonsterName then
									local worldOrigin = workspace:FindFirstChild("_WorldOrigin")
									local enemySpawns = worldOrigin and worldOrigin:FindFirstChild("EnemySpawns")
									if enemySpawns then
										for _, spawnPart in ipairs(enemySpawns:GetChildren()) do
											if
												string.find(spawnPart.Name, targetMonsterName, 1, true)
												and spawnPart:IsA("BasePart")
											then
												resolvedNpcCFrame = spawnPart.CFrame
												break
											end
										end
									end
								end

								controller.CurrentNpc = resolvedNpcCFrame
								if resolvedNpcCFrame then
									return
								end
								resetCurrentQuest(
									"quest_npc_lastreq_nomatch",
									string.format(
										"[Quest.Refresh] Không tìm thấy tọa độ NPC cho %s (LvReq=%s)",
										tostring(currentQuestId),
										tostring(selectedSubQuest.LevelReq)
									)
								)
								return
							end
							return
						else
							if missingLivePlayerLevelCopy and (os.clock() - clockStamp) < 2 then
								task.wait(0.05)
								continue
							end
							break
						end
					end
				end

				QuestController.GetCurrentQuest = function(controllerCurrent)
					local livePlayerLevel = GetLiveLevel()
					ScriptStorage.PlayerData.Level = livePlayerLevel

					if
						(not controllerCurrent.CurrentQuests or not controllerCurrent.LastRefreshLevel)
						or (math.abs(livePlayerLevel - controllerCurrent.LastRefreshLevel) >= 1)
					then
						pcall(function()
							controllerCurrent:RefreshQuest()
						end)
					end

					if not controllerCurrent.CurrentQuests or (#controllerCurrent.CurrentQuests == 0) then
						return
					end
					local currentLevel = 1

					for i, currentQuest in ipairs(controllerCurrent.CurrentQuests) do
						if currentQuest and ((currentQuest.LevelReq or 0) <= livePlayerLevel) then
							currentLevel = i
						end
					end

					controllerCurrent.CurrentLevel = currentLevel
					local huge = math.huge
					local statusMessage = "n/a"

					for k, quest in pairs(QuestController.Quests) do
						if
							(
								(not QuestController.BlacklistedQuestIds[k] and quest[1])
								and (livePlayerLevel < quest[1].LevelReq)
							) and (quest[1].LevelReq < huge)
						then
							huge = quest[1].LevelReq
							statusMessage = k
						end
					end

					if ScriptStorage and ScriptStorage.Task then
						local nextLvl = ((huge ~= math.huge) and huge) or "Max"
						ScriptStorage.Task.QuestDebug = "Quest: "
							.. (
								tostring(controllerCurrent.CurrentQuests[currentLevel].Name or "n/a")
								.. (
									" | Next: "
									.. (
										tostring(statusMessage)
										.. (
											" | Picked: "
											.. (
												tostring(controllerCurrent.CurrentQuestId or "n/a")
												.. (" (Lvl " .. (tostring(nextLvl) .. ")"))
											)
										)
									)
								)
							)
					end

					for monName in pairs(controllerCurrent.CurrentQuests[currentLevel].Task) do
						return monName,
							controllerCurrent.CurrentNpc,
							controllerCurrent.CurrentQuestId,
							currentLevel,
							controllerCurrent.CurrentQuests[currentLevel].Name
					end
				end

				QuestController.GetNextQuestId = function(controllerCurrent, secondaryArg)
					local currentLevel = secondaryArg or GetLiveLevel()
					local scopedValue = nil
					local huge = math.huge
					local statusMessage = "n/a"

					for k, questGroupList in pairs(QuestController.Quests) do
						if not QuestController.BlacklistedQuestIds[k] then
							if questGroupList[1] then
								if currentLevel < questGroupList[1].LevelReq then
									if questGroupList[1].LevelReq < huge then
										huge = questGroupList[1].LevelReq
										statusMessage = k
									end
								end
							end
						end
					end

					return statusMessage, huge
				end

				QuestController.IsUnderWaterQuest = function(self)
					local liveLvl = GetLiveLevel()
					if
						not self.CurrentQuestId
						or not self.LastRefreshLevel
						or math.abs(liveLvl - self.LastRefreshLevel) >= 1
					then
						pcall(function()
							self:RefreshQuest()
						end)
					end
					return SUBMERGED_QUEST_IDS[tostring(self.CurrentQuestId)] == true
				end

				QuestController.MarkAsCompleted = function() end

				QuestController.AbandonQuest = function()
					Remotes.CommF_:InvokeServer("AbandonQuest")
				end

				local function getCurrentClaimQuest()
					local pg = LocalPlayer:FindFirstChild("PlayerGui")
					if not pg then
						return nil, nil
					end

					local rawTitleText = nil

					local trackedQuestFrame = pg:FindFirstChild("TrackedQuestFrame")
					if trackedQuestFrame and trackedQuestFrame.Visible then
						local desc = trackedQuestFrame:FindFirstChild("Description")
						local header = (desc and desc:FindFirstChild("Header"))
							or trackedQuestFrame:FindFirstChild("Header", true)
						if header and header:IsA("TextLabel") and header.Text ~= "" then
							rawTitleText = header.Text
						end
					end

					if not rawTitleText then
						local mainGui = pg:FindFirstChild("Main") or pg:FindFirstChild("Main (minimal)")
						local questFrame = mainGui and mainGui:FindFirstChild("Quest")
						if questFrame and questFrame.Visible then
							local container = questFrame:FindFirstChild("Container")
							local questTitle = (container and container:FindFirstChild("QuestTitle"))
								or questFrame:FindFirstChild("QuestTitle", true)
							local titleLabel = questTitle
								and (questTitle:FindFirstChild("Title") or (questTitle:IsA("TextLabel") and questTitle))
							if titleLabel and titleLabel.Text ~= "" then
								rawTitleText = titleLabel.Text
							end
						end
					end

					if not rawTitleText or rawTitleText == "" then
						return nil, nil
					end

					local normalizedMob = rawTitleText
						:gsub("^Defeat%s+%d+%s+", "")
						:gsub("^Defeat%s+the%s+", "")
						:gsub("^Defeat%s+", "")
						:gsub("%s*%b()%s*$", "")
						:gsub("^%s+", "")
						:gsub("%s+$", "")

					if normalizedMob == "" then
						return nil, rawTitleText
					end
					return normalizedMob, rawTitleText
				end

				QuestController.GetCurrentClaimQuest = getCurrentClaimQuest

				QuestController.StartQuest = function(primaryArg, secondaryArg)
					return Remotes.CommF_:InvokeServer("StartQuest", primaryArg, secondaryArg)
				end
			end

			ScriptStorage.MobRegions = {}
			ScriptStorage.SpecialClusterMobs =
				{ ["Dangerous Prisoner"] = true, Gladiator = true, Raider = true, Mercenary = true }

			do
				local function registerMobSpawnChildren(containerFolder)
					if not containerFolder then
						return
					end
					for _, child in ipairs(containerFolder:GetChildren()) do
						local cFrame
						if child:IsA("BasePart") then
							cFrame = child.CFrame
						elseif child:IsA("Model") then
							cFrame = child:GetPivot() or child:GetModelCFrame()
						end
						if cFrame then
							local mobName = tostring(child.Name)
							ScriptStorage.MobRegions[mobName] = ScriptStorage.MobRegions[mobName] or {}
							table.insert(ScriptStorage.MobRegions[mobName], cFrame)
							local gsub = mobName:gsub("%s*%[.-%]", ""):gsub("%s+$", "")
							if gsub ~= mobName and gsub ~= "" then
								ScriptStorage.MobRegions[gsub] = ScriptStorage.MobRegions[gsub] or {}
								table.insert(ScriptStorage.MobRegions[gsub], cFrame)
							end
						end
					end
				end

				registerMobSpawnChildren(
					game:GetService("ReplicatedStorage"):FindFirstChild("FortBuilderReplicatedSpawnPositionsFolder")
				)
				local worldOrigin = workspace:FindFirstChild("_WorldOrigin")
				worldOrigin = worldOrigin and workspace._WorldOrigin:FindFirstChild("EnemySpawns")
				registerMobSpawnChildren(worldOrigin)
			end

			do
				local function registerNpcSpawnModel(mobName)
					if mobName:find("Part") then
						return
					end

					if mobName:find("Root") then
						return
					end
					local mobEntry = ScriptStorage.MobRegions[mobName]

					if mobEntry then
						if #mobEntry < 4 then
							return
						end
						local mobEntryEntry = mobEntry[1]
						local huge = math.huge

						for _, spatialTarget in ipairs(mobEntry) do
							local position

							if typeof(spatialTarget) == "CFrame" then
								position = spatialTarget.Position or spatialTarget
							else
								position = spatialTarget
							end

							local scopedValue, scopedValueCurrent, scopedValueTarget = ipairs(mobEntry)
							local initialCounterCurrent = 0

							for _, spatialTargetCurrent in ipairs(mobEntry) do
								local worldCoords

								if typeof(spatialTargetCurrent) == "CFrame" then
									worldCoords = spatialTargetCurrent.Position or spatialTargetCurrent
								else
									worldCoords = spatialTargetCurrent
								end

								initialCounterCurrent += (position - worldCoords).Magnitude
							end

							if initialCounterCurrent < huge then
								huge = initialCounterCurrent
								mobEntryEntry = position
							end
						end

						local initialCounterTarget = 0
						local initialCounterPrimary = 0

						for _, spatialTarget in ipairs(mobEntry) do
							local position

							if typeof(spatialTarget) == "CFrame" then
								position = spatialTarget.Position or spatialTarget
							else
								position = spatialTarget
							end

							local magnitude = (position - mobEntryEntry).Magnitude

							if initialCounterTarget < magnitude then
								initialCounterTarget = magnitude

								if magnitude > 350 then
									initialCounterPrimary += 1
								end
							elseif magnitude > 350 then
								initialCounterPrimary += 1
							end
						end

						if initialCounterPrimary >= 2 then
							if initialCounterTarget > 350 then
								ScriptStorage.SpecialClusterMobs[mobName] = true
								return
							end
						end

						return
					end
				end

				for k, mobRegion in pairs(ScriptStorage.MobRegions) do
					local mobRegionEntry = mobRegion[1]

					if mobRegionEntry then
						local y = ((typeof(mobRegionEntry) == "CFrame") and mobRegionEntry.Position.Y)
							or ((typeof(mobRegionEntry) == "Vector3") and mobRegionEntry.Y)

						if y and (y > -500) then
							registerNpcSpawnModel(k)
						end
					else
						registerNpcSpawnModel(k)
					end
				end
			end

			TweenController = {}
			local tweenTargetInstance
			tweenTargetInstance = nil
			local initialCounterFallback
			initialCounterFallback = 0
			TweenController.HeartbeatConn = nil
			TweenController.Playing = false
			TweenController.Hovering = false
			TweenController.HoverCFrame = nil
			TweenController.CollisionPrepared = false
			TweenController.CollisionCharacter = nil
			TweenController.CollisionConnection = nil
			TweenController.CollisionParts = {}
			local prepareCharacterCollisionParts, stopTween, recoverStuckTweenPosition
			local initialCounterCandidate = 0

			prepareCharacterCollisionParts = function()
				local character = LocalPlayer.Character

				if character then
					if TweenController.CollisionCharacter ~= character then
						if TweenController.CollisionConnection then
							TweenController.CollisionConnection:Disconnect()
						end

						TweenController.CollisionCharacter = character
						TweenController.CollisionPrepared = false
						table.clear(TweenController.CollisionParts)
						local descendantAdded = character.DescendantAdded
						local connect = descendantAdded.Connect

						local function cacheCharacterBasePart(targetInstance)
							if targetInstance:IsA("BasePart") then
								table.insert(TweenController.CollisionParts, targetInstance)
								if TweenController.CollisionPrepared then
									targetInstance.CanCollide = false
									return
								end
							end
						end

						TweenController.CollisionConnection = connect(descendantAdded, cacheCharacterBasePart)
					end

					if TweenController.CollisionPrepared then
						return
					end
					TweenController.CollisionPrepared = true
					table.clear(TweenController.CollisionParts)

					for _, descendant in ipairs(character:GetDescendants()) do
						if descendant:IsA("BasePart") then
							table.insert(TweenController.CollisionParts, descendant)
							descendant.CanCollide = false
						end
					end

					return
				end
			end

			stopTween = function(primaryArg)
				if TweenController.HeartbeatConn then
					pcall(function()
						TweenController.HeartbeatConn:Disconnect()
					end)

					TweenController.HeartbeatConn = nil
				end

				TweenController.Playing = false

				if not primaryArg then
					TweenController.Hovering = false
					TweenController.HoverCFrame = nil
				end

				if LocalPlayer.Character then
					local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

					if humanoid then
						humanoid.AutoRotate = true
					end
				end

				if TweenInstance then
					pcall(function()
						TweenInstance:Cancel()
						TweenInstance:Destroy()
					end)

					TweenInstance = nil
					return
				end
			end

			recoverStuckTweenPosition = function(primaryArg, secondaryArg, tertiaryArg)
				local clockStamp = os.clock()

				if secondaryArg then
					if tertiaryArg then
						if (secondaryArg - primaryArg):Dot(tertiaryArg) > 8 then
							initialCounterCandidate = clockStamp + 5
						end
					end
				end

				if clockStamp < initialCounterCandidate then
					return 220
				end
				return 300
			end

			do
				local connect = nil

				local function ensureCharacterNoClipLoop()
					if connect then
						return
					end

					connect = Services.RunService.Stepped:Connect(function()
						if LocalPlayer.Character then
							local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

							if humanoidRootPart then
								if not TweenController.Playing then
									if not TweenController.Hovering then
										return
									end
								end

								humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
								humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

								if TweenController.Hovering then
									if TweenController.HoverCFrame then
										if not TweenController.Playing then
											humanoidRootPart.CFrame = TweenController.HoverCFrame
										end
									end
								end

								for i = #TweenController.CollisionParts, 1, -1 do
									local collisionPartEntry = TweenController.CollisionParts[i]

									if collisionPartEntry then
										if collisionPartEntry.Parent then
											if collisionPartEntry.CanCollide then
												collisionPartEntry.CanCollide = false
											end
										else
											table.remove(TweenController.CollisionParts, i)
										end
									else
										table.remove(TweenController.CollisionParts, i)
									end
								end

								return
							end

							return
						end
					end)
				end

				ensureCharacterNoClipLoop()

				TweenController.Update = function()
					local charModel = LocalPlayer.Character
					local rootPart = charModel and charModel:FindFirstChild("HumanoidRootPart")
					if not rootPart then
						return
					end
					HumanoidRootPart = rootPart
					if CaculateDistance(rootPart.CFrame) > 250 then
						stopTween()
						TweenDebounce = true
						TweenDebounce = false
					end
					HumanoidRootPart.CFrame = rootPart.CFrame + Vector3.new(0, 3, 0)
				end

				TweenController.Tween2 = function(partInstance, secondaryArg)
					if ActiveSecondaryTween then
						pcall(function()
							ActiveSecondaryTween:Cancel()
							ActiveSecondaryTween:Destroy()
						end)

						ActiveSecondaryTween = nil
					end

					ActiveSecondaryTween = Services.TweenService:Create(
						partInstance,
						TweenInfo.new(CaculateDistance(partInstance.CFrame, secondaryArg) / 50, Enum.EasingStyle.Linear),
						{ CFrame = ConvertTo(CFrame, secondaryArg) - Vector3.new(0, 0, 0) }
					)
					ActiveSecondaryTween:Play()
				end

				local function clearGhost()
					stopTween(false)
					tweenTargetInstance = nil
					TweenController.CollisionPrepared = false
					local character = LocalPlayer.Character

					if character then
						local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

						if humanoidRootPart then
							local muse = humanoidRootPart:FindFirstChild("muse")

							if muse then
								muse:Destroy()
							end

							humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
							humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
						end

						local head = character:FindFirstChild("Head")

						if head then
							local muse = head:FindFirstChild("muse")

							if muse then
								muse:Destroy()
							end
						end

						local humanoid = character:FindFirstChildOfClass("Humanoid")

						if humanoid then
							pcall(function()
								humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
							end)
						end

						for _, child in ipairs(character:GetChildren()) do
							if child:IsA("BasePart") then
								if child.Name ~= "HumanoidRootPart" then
									if child.Name:find("Torso") then
										child.CanCollide = true
									end
								else
									child.CanCollide = true
								end
							end
						end

						return
					end
				end

				TweenController.ClearGhost = clearGhost

				LocalPlayer.CharacterAdded:Connect(function(character)
					TweenController.ClearGhost()
					ensureCharacterNoClipLoop()

					task.spawn(function()
						local humanoid = character:WaitForChild("Humanoid", 4)
						local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 4)

						if humanoid then
							if humanoidRootPart then
								repeat
									task.wait(0.1)
								until not isSessionActive() or not humanoid.Parent or humanoid.Health > 0
								if not isSessionActive() or not humanoid.Parent then
									return
								end

								task.wait(0.15)
								if RefreshTasksData then
									pcall(RefreshTasksData)
									return
								end
							end
						end
					end)
				end)
			end

			GetBypassSpawn = function(primaryArg)
				local character = LocalPlayer.Character
				if not character or not character:FindFirstChild("HumanoidRootPart") then
					warn("No character/HRP found")
					return nil, math.huge
				end
				local position = character.HumanoidRootPart.Position
				local magnitude = (primaryArg - position).Magnitude
				if magnitude < 3000 then
					warn("Distance to target < 3000, no bypass needed")
					return nil, math.huge
				end
				local cachedPlayerSpawnsFolderCopy = (getTeamPlayerSpawnsFolder and getTeamPlayerSpawnsFolder())
					or cachedPlayerSpawnsFolder
				if not cachedPlayerSpawnsFolderCopy then
					warn(" Spawns folder not found")
					return nil, math.huge
				end
				local attribute = character:GetAttribute("SpawnPoint")
				local huge = math.huge
				local childCopy = nil

				for _, child in ipairs(cachedPlayerSpawnsFolderCopy:GetChildren()) do
					local spatialTarget = (child:FindFirstChild("Part") or child:FindFirstChildWhichIsA("BasePart"))
						or (child:IsA("BasePart") and child)

					if spatialTarget then
						local distanceMagnitude = (spatialTarget.Position - position).Magnitude
						local distanceMagnitudeCurrent = (spatialTarget.Position - primaryArg).Magnitude

						if
							(
								((distanceMagnitude <= 10000) and (distanceMagnitudeCurrent < magnitude))
								and (child.Name ~= attribute)
							) and (distanceMagnitudeCurrent < huge)
						then
							huge = distanceMagnitudeCurrent
							childCopy = child
						end
					end
				end

				if not childCopy then
					warn("No spawn satisfies conditions")
				end

				return childCopy, huge
			end

			local canUsePortalShortcutEntry

			do
				local function findPrimaryPartInModel(targetInstance)
					if targetInstance then
						local part = targetInstance:FindFirstChild("Part")
						if part then
							return part
						end
						return (targetInstance:FindFirstChildWhichIsA("BasePart", true))
					end

					return nil
				end

				local function getClosestPartDistance(containerFolder, secondaryArg)
					if containerFolder then
						if secondaryArg then
							local huge = math.huge

							for _, descendant in ipairs(containerFolder:GetDescendants()) do
								if descendant:IsA("BasePart") then
									huge = math.min(huge, (descendant.Position - secondaryArg).Magnitude)
								end
							end

							return huge
						end

						return math.huge
					end

					return math.huge
				end

				canUsePortalShortcutEntry = function(portalDefinition)
					if portalDefinition then
						local itemRequired = portalDefinition.item_required

						if not itemRequired then
							itemRequired = portalDefinition.time_required
							if not itemRequired then
								return true
							end
						end

						local isCheckPassed = ScriptStorage.Backpack[itemRequired] ~= nil

						if not isCheckPassed then
							isCheckPassed = ScriptStorage.Tools[itemRequired] ~= nil

							if not isCheckPassed then
								if LocalPlayer.Character then
									isCheckPassed = LocalPlayer.Character:FindFirstChild(itemRequired) ~= nil

									if not isCheckPassed then
										isCheckPassed = LocalPlayer.Backpack
										if isCheckPassed then
											local backpack = LocalPlayer.Backpack
											return backpack:FindFirstChild(itemRequired) ~= nil
										end
									end
								else
									isCheckPassed = LocalPlayer.Backpack
									if isCheckPassed then
										return LocalPlayer.Backpack:FindFirstChild(itemRequired) ~= nil
									end
								end
							end
						end

						return isCheckPassed
					end

					return false
				end

				local function portalContainsSpawnGroup(portalDefinition, secondaryArg)
					if portalDefinition then
						if secondaryArg then
							if portalDefinition.spawn_groups then
								for _, spawnGroup in ipairs(portalDefinition.spawn_groups) do
									if spawnGroup ~= secondaryArg then
										continue
									end
									return true
								end

								return false
							end

							return false
						end

						return false
					end

					return false
				end

				local function computePortalRouteDistance(portalDefinition, secondaryArg, tertiaryArg)
					if portalDefinition then
						if secondaryArg then
							local magnitude = (portalDefinition.pos - secondaryArg).Magnitude
							local findPrimaryPartInModelCopy, spatialTarget

							if portalDefinition.spawn_groups then
								if cachedPlayerSpawnsFolder then
									for _, spawnGroup in ipairs(portalDefinition.spawn_groups) do
										magnitude = math.min(
											magnitude,
											getClosestPartDistance(
												cachedPlayerSpawnsFolder:FindFirstChild(spawnGroup),
												secondaryArg
											)
										)
									end

									if tertiaryArg then
										if portalContainsSpawnGroup(portalDefinition, tertiaryArg.Name) then
											findPrimaryPartInModelCopy = findPrimaryPartInModel
											spatialTarget = findPrimaryPartInModel(tertiaryArg)
											if spatialTarget then
												return (
													math.min(
														magnitude,
														(portalDefinition.pos - spatialTarget.Position).Magnitude
													)
												)
											end
										end
									end
								elseif tertiaryArg then
									if portalContainsSpawnGroup(portalDefinition, tertiaryArg.Name) then
										findPrimaryPartInModelCopy = findPrimaryPartInModel
										spatialTarget = findPrimaryPartInModel(tertiaryArg)
										if spatialTarget then
											return (
												math.min(
													magnitude,
													(portalDefinition.pos - spatialTarget.Position).Magnitude
												)
											)
										end
									end
								end
							elseif tertiaryArg then
								if portalContainsSpawnGroup(portalDefinition, tertiaryArg.Name) then
									findPrimaryPartInModelCopy = findPrimaryPartInModel
									spatialTarget = findPrimaryPartInModel(tertiaryArg)
									if spatialTarget then
										return (
											math.min(
												magnitude,
												(portalDefinition.pos - spatialTarget.Position).Magnitude
											)
										)
									end
								end
							end

							return magnitude
						end

						return math.huge
					end

					return math.huge
				end

				GetSea3EntranceCandidate = function(primaryArg, secondaryArg, tertiaryArg)
					if SeaIndex ~= 3 then
						return nil, math.huge
					end

					if primaryArg then
						local character = LocalPlayer.Character

						if character then
							local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

							if humanoidRootPart then
								local magnitude = (primaryArg - humanoidRootPart.Position).Magnitude
								local clampedNumber = math.min(magnitude, tertiaryArg or math.huge)
								local scopedValue = nil
								local sea3EntranceItemCopy = nil

								for _, sea3EntranceItem in pairs(Sea3Entrances) do
									if sea3EntranceItem.verified then
										if canUsePortalShortcutEntry(sea3EntranceItem) then
											local distanceMagnitude = (sea3EntranceItem.pos - humanoidRootPart.Position).Magnitude
											local computePortalRouteDistanceCurrent =
												computePortalRouteDistance(sea3EntranceItem, primaryArg, secondaryArg)

											if distanceMagnitude >= 450 then
												if computePortalRouteDistanceCurrent < (clampedNumber - 300) then
													if computePortalRouteDistanceCurrent < (magnitude - 500) then
														if scopedValue then
															if computePortalRouteDistanceCurrent < scopedValue then
																scopedValue = computePortalRouteDistanceCurrent
																sea3EntranceItemCopy = sea3EntranceItem
															end
														else
															scopedValue = computePortalRouteDistanceCurrent
															sea3EntranceItemCopy = sea3EntranceItem
														end
													end
												end
											end
										end
									end
								end

								if sea3EntranceItemCopy then
									return sea3EntranceItemCopy, scopedValue
								end
								return nil, math.huge
							end
						end

						return nil, math.huge
					end

					return nil, math.huge
				end
			end

			local initialCounterCached
			initialCounterCached = 0
			local safeInvokeRemote, trySubmarineTravel, isSubmergedPos

			do
				local scopedValue = nil

				safeInvokeRemote = function(primaryArg, secondaryArg, ...)
					if not primaryArg then
						return false
					end
					local collectedItemsCurrent = { ... }
					local isActiveState = false
					local isActiveStateCurrent = false
					local resultCopy = nil

					task.spawn(function()
						local ok, result = pcall(function()
							return primaryArg:InvokeServer(table.unpack(collectedItemsCurrent))
						end)

						isActiveStateCurrent = ok
						resultCopy = result
						isActiveState = true
					end)

					local clockStamp = os.clock()

					while not isActiveState do
						local elapsedDuration = os.clock() - clockStamp

						if secondaryArg then
							if elapsedDuration < secondaryArg then
								task.wait()
								continue
							end
						elseif elapsedDuration < 3 then
							task.wait()
							continue
						end

						break
					end

					return isActiveState and isActiveStateCurrent, resultCopy
				end

				local function resolveNetRemoteFunction(primaryArg)
					local Net

					pcall(function()
						Net = require(game.ReplicatedStorage.Modules.Net)
					end)

					local modules

					if Net then
						modules = Net:RemoteFunction(primaryArg)

						if not modules then
							modules = game:GetService("ReplicatedStorage"):FindFirstChild("Modules")

							if modules then
								modules = game.ReplicatedStorage.Modules:FindFirstChild("Net")
								if modules then
									return (modules:FindFirstChild("RF/" .. primaryArg))
								end
							end
						end
					else
						modules = game:GetService("ReplicatedStorage"):FindFirstChild("Modules")

						if modules then
							modules = game.ReplicatedStorage.Modules:FindFirstChild("Net")
							if modules then
								return (modules:FindFirstChild("RF/" .. primaryArg))
							end
						end
					end

					return modules
				end

				local function invokeSubmarineTransport(spatialTarget)
					local SubmarineTransportation = resolveNetRemoteFunction("SubmarineTransportation")

					if SubmarineTransportation then
						local getAvailableLocations, remoteResult =
							safeInvokeRemote(SubmarineTransportation, 4, "GetAvailableLocations")

						if getAvailableLocations then
							if remoteResult ~= -1 then
								if typeof(remoteResult) ~= "table" then
									return false
								end

								if typeof(spatialTarget) == "CFrame" then
									spatialTarget = spatialTarget.Position or spatialTarget
								end

								local scopedValueCurrent, scopedValueTarget, scopedValuePrimary = ipairs(remoteResult)
								local huge = math.huge
								local scopedValueFallback = nil

								for _, iteratedElement in scopedValueCurrent, scopedValueTarget, scopedValuePrimary do
									local endLocation = iteratedElement and iteratedElement.EndLocation
									local position

									if typeof(endLocation) == "CFrame" then
										position = endLocation.Position or endLocation
									else
										position = endLocation
									end

									if typeof(position) == "Vector3" then
										local magnitude

										if spatialTarget then
											magnitude = (position - spatialTarget).Magnitude

											if not magnitude then
												magnitude = math.huge
											end
										else
											magnitude = math.huge
										end

										if magnitude < huge then
											huge = magnitude
											scopedValueFallback = iteratedElement
										end
									end
								end

								if scopedValueFallback then
									local initiateTeleport, remoteResultCurrent = safeInvokeRemote(
										SubmarineTransportation,
										4,
										"InitiateTeleport",
										scopedValueFallback.Name
									)

									if initiateTeleport then
										if typeof(remoteResultCurrent) == "table" then
											return true
										end
									end
								end

								local initiateTeleport, remoteResultTarget =
									safeInvokeRemote(SubmarineTransportation, 4, "InitiateTeleport", "Tiki Outpost")

								if initiateTeleport then
									if typeof(remoteResultTarget) == "table" then
										return true
									end
								end

								return false
							end

							return false
						end

						return false
					end

					return false
				end

				trySubmarineTravel = function(spatialTarget)
					if SeaIndex ~= 3 then
						return false
					end

					if spatialTarget then
						if typeof(spatialTarget) == "CFrame" then
							spatialTarget = spatialTarget.Position or spatialTarget
						end

						local isPositionInSubmergedIslandCurrent = isPositionInSubmergedIsland(spatialTarget)

						if isPositionInSubmergedIslandCurrent ~= isPlayerInSubmergedIsland() then
							if isPositionInSubmergedIslandCurrent then
								SetTask("MainTask", "Level Farming | Under Water | Entering Submerged")
								if CaculateDistance(SUBMARINE_ENTER_CFRAME) >= 8 then
									TweenController.Create(SUBMARINE_ENTER_CFRAME)
									return true
								end
								local modules = ReplicatedStorage:FindFirstChild("Modules")
								local net = modules and modules:FindFirstChild("Net")
								local rfSubmarineWorkerSpeak = net and net:FindFirstChild("RF/SubmarineWorkerSpeak")
								if rfSubmarineWorkerSpeak and nextSubmarineInvokeClock <= os.clock() then
									nextSubmarineInvokeClock = os.clock() + 5
									pcall(function()
										rfSubmarineWorkerSpeak:InvokeServer("TravelToSubmergedIsland")
									end)
									pcall(function()
										Remotes.CommF_:InvokeServer("SetLastSpawnPoint", "SubmergedIsland")
									end)
									stopTween(false)
									return true
								end
								return true
							end

							SetTask("MainTask", "Level Farming | Under Water | Leaving Submerged")
							local findNpcCFrameCurrent =
								findNpcCFrame("Submarine Worker2", SUBMARINE_EXIT_FALLBACK_CFRAME)
							if CaculateDistance(findNpcCFrameCurrent) > 25 then
								TweenController.Create(findNpcCFrameCurrent + Vector3.new(0, 5, 3))
								return true
							end

							if isPlayerInSubmergedIsland() then
								local invokeSubmarineTransportCurrent = invokeSubmarineTransport(spatialTarget)
								task.wait(2)

								if isPlayerInSubmergedIsland() then
									local invokeSubmarineTransportTarget = invokeSubmarineTransport(spatialTarget)

									if not invokeSubmarineTransportCurrent then
										if not invokeSubmarineTransportTarget then
											SetTask("MainTask", "Submerged | Surface travel unavailable or in combat")
											return true
										end
									end
								end
							end

							return true
						end

						return false
					end

					return false
				end

				local function isPosInUnderwaterCity(spatialTarget)
					if spatialTarget then
						if typeof(spatialTarget) == "CFrame" then
							spatialTarget = spatialTarget.Position or spatialTarget
						end

						local isCheckPassed = spatialTarget.X > 50000
						if isCheckPassed then
							return spatialTarget.X < 70000
						end
						return isCheckPassed
					end

					return false
				end

				local function isPlayerInUnderwaterCity()
					if LocalPlayer.Character then
						local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

						if humanoidRootPart then
							local isPosInUnderwaterCityCurrent = isPosInUnderwaterCity(humanoidRootPart.Position)
							if isPosInUnderwaterCityCurrent then
								return isPosInUnderwaterCityCurrent
							end
						end
					end

					return false
				end

				local targetCFrame = CFrame.new(4050.31, 5, -1814.12)
				local targetCFrameCurrent = CFrame.new(61170.05, 5, 1952.83)
				local targetCFrameTarget = CFrame.new(61726.28, 528, -1559.27)

				local function firePortalTouchInterest(touchPart, secondaryArg)
					if touchPart then
						if secondaryArg then
							pcall(function()
								if typeof(firetouchinterest) ~= "function" then
									return
								end
								firetouchinterest(touchPart, secondaryArg, 0)
								firetouchinterest(touchPart, secondaryArg, 1)
							end)

							pcall(function()
								if typeof(firesignal) ~= "function" then
									return
								end
								firesignal(secondaryArg.Touched, touchPart)
							end)

							pcall(function()
								if typeof(getconnections) ~= "function" then
									return
								end

								for _, iteratedElement in ipairs(getconnections(secondaryArg.Touched)) do
									if iteratedElement.Function then
										iteratedElement.Function(touchPart)
									else
										iteratedElement:Fire(touchPart)
									end
								end
							end)

							return
						end
					end
				end

				local function tryUnderwaterWhirlpoolTransit(spatialTarget)
					if SeaIndex ~= 1 then
						return false
					end

					if spatialTarget then
						if typeof(spatialTarget) == "CFrame" then
							spatialTarget = spatialTarget.Position or spatialTarget
						end

						local isPosInUnderwaterCityCurrent = isPosInUnderwaterCity(spatialTarget)
						if isPosInUnderwaterCityCurrent == isPlayerInUnderwaterCity() then
							return false
						end

						if LocalPlayer.Character then
							local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

							if humanoidRootPart then
								if isPosInUnderwaterCityCurrent then
									SetTask("MainTask", "Entering Underwater Island (Whirlpool)")
									if (humanoidRootPart.Position - targetCFrame.Position).Magnitude > 25 then
										TweenController.Create(targetCFrame)
										return true
									end
									firePortalTouchInterest(
										humanoidRootPart,
										workspace.Map:FindFirstChild("TeleportSpawn")
											and workspace.Map.TeleportSpawn:FindFirstChild("Entrance")
									)

									pcall(function()
										Remotes.CommF_:InvokeServer(
											"requestEntrance",
											Vector3.new(61163.8515625, 11.75, 1819.780029296875)
										)
									end)

									task.wait(1.5)
									return true
								end

								SetTask("MainTask", "Leaving Underwater Island")

								if humanoidRootPart.Position.Y > 300 then
									if humanoidRootPart.Position.X > 61500 then
										if (humanoidRootPart.Position - targetCFrameTarget.Position).Magnitude > 25 then
											TweenController.Create(targetCFrameTarget)
											return true
										end
										firePortalTouchInterest(
											humanoidRootPart,
											(
												workspace.Map:FindFirstChild("Fishmen")
												and workspace.Map.Fishmen:FindFirstChild("FishmanCavern")
											)
												and workspace.Map.Fishmen.FishmanCavern:FindFirstChild("Entrance")
										)
										task.wait(1.5)
										return true
									end
								end

								if (humanoidRootPart.Position - targetCFrameCurrent.Position).Magnitude > 25 then
									TweenController.Create(targetCFrameCurrent)
									return true
								end
								firePortalTouchInterest(
									humanoidRootPart,
									workspace.Map:FindFirstChild("TeleportSpawn")
										and workspace.Map.TeleportSpawn:FindFirstChild("Exit")
								)

								pcall(function()
									Remotes.CommF_:InvokeServer(
										"requestEntrance",
										Vector3.new(3864.679931640625, 6.74, -1926.2099609375)
									)
								end)

								task.wait(1.5)
								return true
							end
						end

						return false
					end

					return false
				end

				local function isPosInUpperSkylands(spatialTarget)
					if spatialTarget then
						if typeof(spatialTarget) == "CFrame" then
							spatialTarget = spatialTarget.Position or spatialTarget
						end

						local isCheckPassed = spatialTarget.Y > 3000

						if isCheckPassed then
							isCheckPassed = spatialTarget.X < -5000
							if isCheckPassed then
								return spatialTarget.X > -9000
							end
						end

						return isCheckPassed
					end

					return false
				end

				local function isPlayerInUpperSkylands()
					if LocalPlayer.Character then
						local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

						if humanoidRootPart then
							local isPosInUpperSkylandsCurrent = isPosInUpperSkylands(humanoidRootPart.Position)
							if isPosInUpperSkylandsCurrent then
								return isPosInUpperSkylandsCurrent
							end
						end
					end

					return false
				end

				CFrame.new(-4208.15, 1089.88, -373.05)
				CFrame.new(-6022.23, 5470.49, 2217.33)

				local function tryUpperSkylandsPortalTransit(spatialTarget)
					if SeaIndex ~= 1 then
						return false
					end

					if spatialTarget then
						if typeof(spatialTarget) == "CFrame" then
							spatialTarget = spatialTarget.Position or spatialTarget
						end

						local isPosInUpperSkylandsCurrent = isPosInUpperSkylands(spatialTarget)

						if isPosInUpperSkylandsCurrent ~= isPlayerInUpperSkylands() then
							if LocalPlayer.Character then
								if LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
									if isPosInUpperSkylandsCurrent then
										SetTask("MainTask", "Entering Upper Skylands")
										TweenController.Create(CFrame.new(spatialTarget), true)
										return true
									end

									SetTask("MainTask", "Leaving Upper Skylands")
									TweenController.Create(CFrame.new(spatialTarget), true)
									return true
								end

								return false
							end

							return false
						end

						return false
					end

					return false
				end

				isSubmergedPos = function(spatialTarget)
					if spatialTarget then
						if typeof(spatialTarget) == "CFrame" then
							spatialTarget = spatialTarget.Position or spatialTarget
						end

						local isCheckPassed = spatialTarget.Z > 25000

						if isCheckPassed then
							isCheckPassed = spatialTarget.X > -2000
							if isCheckPassed then
								return spatialTarget.X < 3000
							end
						end

						return isCheckPassed
					end

					return false
				end

				local targetCFramePrimary = CFrame.new(-6496.89, 89.03, -116.51)
				local targetCFrameFallback = CFrame.new(920.48, 154.9, 32838.96)

				local function isPosInCursedShipInterior(spatialTarget)
					if typeof(spatialTarget) == "CFrame" then
						spatialTarget = spatialTarget.Position or spatialTarget
					end

					if typeof(spatialTarget) ~= "Vector3" then
						return false
					end

					if workspace:FindFirstChild("Map") then
						local ghostShipInterior = workspace.Map:FindFirstChild("GhostShipInterior")

						if ghostShipInterior then
							if ghostShipInterior:IsA("Model") then
								local ok, result, executionResult = pcall(function()
									return ghostShipInterior:GetBoundingBox()
								end)

								if ok then
									local pointToObjectSpace = result:PointToObjectSpace(spatialTarget)
									local computedTotal = (executionResult.X / 2) + 60
									local isCheckPassed = math.abs(pointToObjectSpace.X) <= computedTotal

									if isCheckPassed then
										local computedTotalCurrent = (executionResult.Y / 2) + 60
										isCheckPassed = math.abs(pointToObjectSpace.Y) <= computedTotalCurrent
										if isCheckPassed then
											local computedTotalTarget = (executionResult.Z / 2) + 60
											return math.abs(pointToObjectSpace.Z) <= computedTotalTarget
										end
									end

									return isCheckPassed
								end
							end
						end
					end

					return (spatialTarget - targetCFrameFallback.Position).Magnitude <= 1000
				end

				local function tryCursedShipDoorTransit(spatialTarget)
					if SeaIndex ~= 2 then
						return false
					end

					if spatialTarget then
						if typeof(spatialTarget) == "CFrame" then
							spatialTarget = spatialTarget.Position or spatialTarget
						end

						if LocalPlayer.Character then
							local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

							if humanoidRootPart then
								local isPosInCursedShipInteriorCurrent = isPosInCursedShipInterior(spatialTarget)

								if
									isPosInCursedShipInteriorCurrent
									~= isPosInCursedShipInterior(humanoidRootPart.Position)
								then
									if isPosInCursedShipInteriorCurrent then
										SetTask("MainTask", "Entering Cursed Ship")
										if
											(humanoidRootPart.Position - targetCFramePrimary.Position).Magnitude > 25
										then
											TweenController.Create(targetCFramePrimary)
											return true
										end
										firePortalTouchInterest(
											humanoidRootPart,
											workspace.Map:FindFirstChild("GhostShip")
												and workspace.Map.GhostShip:FindFirstChild("Teleport")
										)

										pcall(function()
											Remotes.CommF_:InvokeServer(
												"requestEntrance",
												Vector3.new(923.2100219726562, 126.97000122070312, 32852.828125)
											)
										end)

										task.wait(1.5)
										return true
									end

									SetTask("MainTask", "Leaving Cursed Ship")
									if (humanoidRootPart.Position - targetCFrameFallback.Position).Magnitude > 25 then
										TweenController.Create(targetCFrameFallback)
										return true
									end
									firePortalTouchInterest(
										humanoidRootPart,
										workspace.Map:FindFirstChild("GhostShipInterior")
											and workspace.Map.GhostShipInterior:FindFirstChild("Teleport")
									)

									pcall(function()
										Remotes.CommF_:InvokeServer(
											"requestEntrance",
											Vector3.new(-6508.5498046875, 89.02999877929688, -132.83999633789062)
										)
									end)

									task.wait(1.5)
									return true
								end

								return false
							end
						end

						return false
					end

					return false
				end

				GetSea3DirectEntrance = function(primaryArg)
					if SeaIndex ~= 3 then
						return nil
					end

					if primaryArg then
						if isPositionInSubmergedIsland(primaryArg) or isPlayerInSubmergedIsland() then
							return nil
						end
						local character = LocalPlayer.Character

						if character then
							local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

							if humanoidRootPart then
								local magnitude = (primaryArg - humanoidRootPart.Position).Magnitude
								local distanceMagnitudeCopy = nil
								local sea3EntranceItemCopy = nil

								for _, sea3EntranceItem in pairs(Sea3Entrances) do
									local directRadius = sea3EntranceItem.direct_radius

									if sea3EntranceItem.verified then
										if directRadius then
											if canUsePortalShortcutEntry(sea3EntranceItem) then
												local distanceMagnitude = (primaryArg - sea3EntranceItem.pos).Magnitude
												local distanceMagnitudeCurrent = (
													sea3EntranceItem.pos - humanoidRootPart.Position
												).Magnitude

												if distanceMagnitude <= directRadius then
													if distanceMagnitudeCurrent >= 450 then
														if magnitude > 3000 then
															if distanceMagnitudeCopy then
																if distanceMagnitude < distanceMagnitudeCopy then
																	distanceMagnitudeCopy = distanceMagnitude
																	sea3EntranceItemCopy = sea3EntranceItem
																end
															else
																distanceMagnitudeCopy = distanceMagnitude
																sea3EntranceItemCopy = sea3EntranceItem
															end
														end
													end
												end
											end
										end
									end
								end

								return sea3EntranceItemCopy
							end
						end

						return nil
					end

					return nil
				end

				TrySea3DirectEntrance = function(primaryArg)
					local sea3DirectEntrance = GetSea3DirectEntrance(primaryArg)
					if not sea3DirectEntrance then
						return false
					end
					local posText = tostring(sea3DirectEntrance.island or sea3DirectEntrance.pos)

					if scopedValue == posText then
						if (os.clock() - initialCounterCached) < 1.5 then
							return true
						end
					end

					if LocalPlayer.Character then
						local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

						if humanoidRootPart then
							local magnitude = (primaryArg - humanoidRootPart.Position).Magnitude
							local distanceMagnitude = (sea3DirectEntrance.pos - humanoidRootPart.Position).Magnitude

							local ok = pcall(function()
								Remotes.CommF_:InvokeServer("requestEntrance", sea3DirectEntrance.pos)
							end)

							task.wait(0.25)
							local character = LocalPlayer.Character

							if character then
								character = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

								if ok then
									initialCounterCached = os.clock()
									scopedValue = posText
									warn("requestEntrance direct -> " .. posText)
									return true
								end
							elseif ok then
								initialCounterCached = os.clock()
								scopedValue = posText
								warn("requestEntrance direct -> " .. posText)
								return true
							end

							if character then
								local distanceMagnitudeCurrent = (primaryArg - character.Position).Magnitude

								if
									(sea3DirectEntrance.pos - character.Position).Magnitude
									>= math.min(distanceMagnitude - 250, 650)
								then
									if distanceMagnitudeCurrent >= (magnitude - 250) then
										warn("requestEntrance direct failed -> " .. posText)
										return false
									end
								end

								initialCounterCached = os.clock()
								scopedValue = posText
								warn("requestEntrance direct -> " .. posText)
								return true
							end

							warn("requestEntrance direct failed -> " .. posText)
							return false
						end
					end

					return false
				end

				TrySea3EntranceBridge = function(primaryArg, secondaryArg, tertiaryArg)
					if isPositionInSubmergedIsland(primaryArg) or isPlayerInSubmergedIsland() then
						return false
					end
					local sea3EntranceCandidate = GetSea3EntranceCandidate(primaryArg, secondaryArg, tertiaryArg)
					if not sea3EntranceCandidate then
						return false
					end
					local magnitude

					if LocalPlayer.Character then
						local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

						if humanoidRootPart then
							magnitude = (primaryArg - humanoidRootPart.Position).Magnitude or math.huge
						else
							magnitude = math.huge
						end
					else
						magnitude = math.huge
					end

					local ok = pcall(function()
						Remotes.CommF_:InvokeServer("requestEntrance", sea3EntranceCandidate.pos)
					end)

					task.wait(0.25)
					local distanceMagnitude, scopedValueCurrent

					if LocalPlayer.Character then
						local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
						local island, warnCurrent, scopedValueTarget, pos

						if humanoidRootPart then
							distanceMagnitude = (primaryArg - humanoidRootPart.Position).Magnitude

							if not distanceMagnitude then
								distanceMagnitude = math.huge
							end
						else
							distanceMagnitude = math.huge
						end

						if ok then
							if distanceMagnitude < (magnitude - 250) then
								initialCounterCached = os.clock()
								scopedValueCurrent = tostring
								island = sea3EntranceCandidate.island or sea3EntranceCandidate.pos
								scopedValue = scopedValueCurrent(island)
								warnCurrent = warn
								scopedValueTarget = tostring
								pos = sea3EntranceCandidate.island or sea3EntranceCandidate.pos
								warnCurrent("requestEntrance bridge -> " .. scopedValueTarget(pos))
								return true
							end
						end
					else
						distanceMagnitude = math.huge

						if ok then
							if distanceMagnitude < (magnitude - 250) then
								initialCounterCached = os.clock()
								scopedValueCurrent = tostring
								scopedValue =
									scopedValueCurrent(sea3EntranceCandidate.island or sea3EntranceCandidate.pos)
								warn(
									"requestEntrance bridge -> "
										.. tostring(sea3EntranceCandidate.island or sea3EntranceCandidate.pos)
								)
								return true
							end
						end
					end

					return false
				end

				GetPortalCandidate = function(targetLocation)
					local scopedValueCurrent = nil
					local initialCounterCurrent = 9000000000
					local portalItemCopy = nil

					for _, portalItem in ipairs(Portals) do
						local targetDistance = CaculateDistance(portalItem, targetLocation)

						if targetDistance < (CaculateDistance(targetLocation) - 300) then
							if targetDistance < initialCounterCurrent then
								initialCounterCurrent = targetDistance
								portalItemCopy = portalItem
							end
						end
					end

					return portalItemCopy, initialCounterCurrent
				end

				GetPortal = function(targetLocation)
					local initialCounterCurrent = 9000000000
					local portalItemCopy

					for _, portalItem in ipairs(Portals) do
						local targetDistance = CaculateDistance(portalItem, targetLocation)

						if targetDistance < (CaculateDistance(targetLocation) - 300) then
							if targetDistance < initialCounterCurrent then
								initialCounterCurrent = targetDistance
								portalItemCopy = portalItem
							end
						end
					end

					if portalItemCopy then
						Remotes.CommF_:InvokeServer("requestEntrance", portalItemCopy)
						return task.wait()
					end
				end

				TweenController.Create = function(primaryArg, secondaryArg, tertiaryArg)
					local spatialTarget, scopedValueCurrent, scopedValueTarget, convertTo, character, humanoidRootPart, isCheckPassed, position, isCheckPassedCurrent, muse, head, targetCFrameCandidate, worldPosition, scopedValuePrimary, unitCopy, humanoid
					spatialTarget = primaryArg
					scopedValueCurrent = secondaryArg
					scopedValueTarget = tertiaryArg

					if spatialTarget then
						if not TweenDebounce then
							if typeof(spatialTarget) ~= "CFrame" then
								convertTo = ConvertTo(CFrame, spatialTarget)

								if convertTo then
									spatialTarget = convertTo
								end
							end

							character = LocalPlayer.Character

							if character then
								humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
							else
								humanoidRootPart = character
							end

							if not not humanoidRootPart then
								isCheckPassed = SeaIndex ~= 1

								if isCheckPassed then
									isCheckPassed = CombatController.IsRaidActive()
								end

								if typeof(spatialTarget) ~= "CFrame" then
									position = spatialTarget
								else
									position = spatialTarget.Position

									if not position then
										position = spatialTarget
									end
								end

								isCheckPassedCurrent = math.abs(position.X) < 25000

								if isCheckPassedCurrent then
									isCheckPassedCurrent = math.abs(position.Z) < 25000
								end

								if isCheckPassed then
									if isCheckPassedCurrent then
										return
									end
								end

								if TweenController.Playing then
									if tweenTargetInstance then
										if (tweenTargetInstance.Position - spatialTarget.Position).Magnitude < 8 then
											return
										end
									end
								end

								stopTween()
								tweenTargetInstance = spatialTarget
								initialCounterFallback = os.clock()
								muse = humanoidRootPart:FindFirstChild("muse")

								if not muse then
									muse = Instance.new("BodyVelocity")
								end

								muse.Name = "muse"
								muse.MaxForce = Vector3.new(0, math.huge, 0)
								muse.Velocity = Vector3.new(0, 0, 0)
								muse.Parent = humanoidRootPart
								head = LocalPlayer.Character:FindFirstChild("Head")

								if head then
									if head:FindFirstChild("muse") then
										head.muse:Destroy()
									end
								end

								humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
								humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

								if not scopedValueCurrent then
									if trySubmarineTravel(spatialTarget.Position) then
										return
									end

									if tryUnderwaterWhirlpoolTransit(spatialTarget.Position) then
										return
									end

									if tryUpperSkylandsPortalTransit(spatialTarget.Position) then
										return
									end

									if tryCursedShipDoorTransit(spatialTarget.Position) then
										return
									end
								end

								targetCFrameCandidate = CFrame.new(spatialTarget.Position)
								worldPosition = targetCFrameCandidate.Position
								scopedValuePrimary = nil
								unitCopy = nil
								TweenController.Playing = true
								prepareCharacterCollisionParts()

								if LocalPlayer.Character then
									humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

									if humanoid then
										humanoid.AutoRotate = false
									end
								end

								local function stepTweenHeartbeat(deltaTime)
									if TweenController.Playing then
										if humanoidRootPart then
											if humanoidRootPart.Parent then
												if LocalPlayer.Character then
													local worldPositionCurrent = humanoidRootPart.Position
													local displacementVec = worldPosition - worldPositionCurrent
													local magnitude = displacementVec.Magnitude
													local recoverStuckTweenPositionCurrent

													if Config.FastTween then
														recoverStuckTweenPositionCurrent = recoverStuckTweenPosition(
															worldPositionCurrent,
															scopedValuePrimary,
															unitCopy
														)

														if magnitude < 18 then
															recoverStuckTweenPositionCurrent = 25
														end
													elseif Config.TweenFast then
														recoverStuckTweenPositionCurrent = recoverStuckTweenPosition(
															worldPositionCurrent,
															scopedValuePrimary,
															unitCopy
														)

														if magnitude < 18 then
															recoverStuckTweenPositionCurrent = 25
														end
													elseif magnitude < 18 then
														recoverStuckTweenPositionCurrent = 100
													elseif magnitude <= 80 then
														recoverStuckTweenPositionCurrent = 160
													else
														recoverStuckTweenPositionCurrent = 220
													end

													local computedTotal = recoverStuckTweenPositionCurrent
														* math.min(deltaTime, 0.07)

													if magnitude <= math.max(computedTotal, 1.5) then
														humanoidRootPart.CFrame = targetCFrameCandidate
														if scopedValueTarget then
															stopTween(false)
															return
														end
														TweenController.Hovering = true
														TweenController.HoverCFrame = targetCFrameCandidate
														stopTween(true)
														return
													end

													local unit = displacementVec.Unit
													local computedTotalCurrent = worldPositionCurrent
														+ (unit * computedTotal)
													scopedValuePrimary = computedTotalCurrent
													unitCopy = unit
													humanoidRootPart.CFrame =
														CFrame.new(computedTotalCurrent, worldPosition)
													return
												end

												stopTween(false)
												return
											end

											stopTween(false)
											return
										end

										stopTween(false)
										return
									end

									stopTween(false)
								end

								TweenController.HeartbeatConn =
									Services.RunService.Heartbeat:Connect(stepTweenHeartbeat)
							end
						end
					end

					return
				end

				TweenController.CreateDirect = function(spatialTarget, secondaryArg, tertiaryArg)
					if spatialTarget then
						if TweenDebounce then
							return
						end

						if typeof(spatialTarget) ~= "CFrame" then
							spatialTarget = ConvertTo(CFrame, spatialTarget) or spatialTarget
						end

						if LastDirectTweenAt then
							local lastDirectTweenAt = LastDirectTweenAt

							if (os.clock() - lastDirectTweenAt) < 0.06 then
								if LastDirectTweenPosition then
									if CaculateDistance(LastDirectTweenPosition, spatialTarget) < 3 then
										return
									end
								end
							end
						end

						LastDirectTweenAt = os.clock()
						LastDirectTweenPosition = spatialTarget
						tweenTargetInstance = spatialTarget
						stopTween()
						local humanoidRootPart = LocalPlayer.Character
							and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
						if not humanoidRootPart then
							return
						end
						local isRaidActive = (SeaIndex ~= 1) and CombatController.IsRaidActive()
						local isCheckPassed = math.abs(spatialTarget.Position.X) < 25000
						local muse, cFrame, position, scopedValueCurrent, unitCopy, humanoid, measuredValue, stepDirectTweenHeartbeat

						if isCheckPassed then
							isCheckPassed = math.abs(spatialTarget.Position.Z) < 25000
						end

						if not isRaidActive then
							if not secondaryArg then
								if trySubmarineTravel(spatialTarget.Position) then
									return
								end

								if tryUnderwaterWhirlpoolTransit(spatialTarget.Position) then
									return
								end

								if tryUpperSkylandsPortalTransit(spatialTarget.Position) then
									return
								end

								if tryCursedShipDoorTransit(spatialTarget.Position) then
									return
								end
							end

							muse = humanoidRootPart:FindFirstChild("muse") or Instance.new("BodyVelocity")
							muse.Name = "muse"
							muse.MaxForce = Vector3.new(0, math.huge, 0)
							muse.Velocity = Vector3.new(0, 0, 0)
							muse.Parent = humanoidRootPart
							humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
							humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
							cFrame = spatialTarget
							position = spatialTarget.Position
							scopedValueCurrent = nil
							unitCopy = nil
							TweenController.Playing = true
							prepareCharacterCollisionParts()

							if LocalPlayer.Character then
								humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

								if humanoid then
									humanoid.AutoRotate = false
								end
							end

							stepDirectTweenHeartbeat = function(deltaTime)
								if TweenController.Playing then
									if humanoidRootPart then
										if humanoidRootPart.Parent then
											if LocalPlayer.Character then
												local worldPosition = humanoidRootPart.Position
												local displacementVec = position - worldPosition
												local magnitude = displacementVec.Magnitude
												local recoverStuckTweenPositionCurrent

												if Config.FastTween then
													recoverStuckTweenPositionCurrent = recoverStuckTweenPosition(
														worldPosition,
														scopedValueCurrent,
														unitCopy
													)

													if magnitude < 18 then
														recoverStuckTweenPositionCurrent = 25
													end
												elseif Config.TweenFast then
													recoverStuckTweenPositionCurrent = recoverStuckTweenPosition(
														worldPosition,
														scopedValueCurrent,
														unitCopy
													)

													if magnitude < 18 then
														recoverStuckTweenPositionCurrent = 25
													end
												elseif magnitude < 18 then
													recoverStuckTweenPositionCurrent = 100
												elseif magnitude <= 80 then
													recoverStuckTweenPositionCurrent = 160
												else
													recoverStuckTweenPositionCurrent = 220
												end

												local computedTotal = recoverStuckTweenPositionCurrent
													* math.min(deltaTime, 0.07)

												if magnitude <= math.max(computedTotal, 1.5) then
													humanoidRootPart.CFrame = cFrame
													if tertiaryArg then
														stopTween(false)
														return
													end
													TweenController.Hovering = true
													TweenController.HoverCFrame = cFrame
													stopTween(true)
													return
												end

												local unit = displacementVec.Unit
												local deltaVector = worldPosition + (unit * computedTotal)
												scopedValueCurrent = deltaVector
												unitCopy = unit
												humanoidRootPart.CFrame = CFrame.new(deltaVector, position)
												return
											end

											stopTween(false)
											return
										end

										stopTween(false)
										return
									end

									stopTween(false)
									return
								end

								stopTween(false)
							end

							TweenController.HeartbeatConn =
								Services.RunService.Heartbeat:Connect(stepDirectTweenHeartbeat)
							return
						end

						if isCheckPassed then
							return
						end

						if not secondaryArg then
							if trySubmarineTravel(spatialTarget.Position) then
								return
							end

							if tryUnderwaterWhirlpoolTransit(spatialTarget.Position) then
								return
							end

							if tryUpperSkylandsPortalTransit(spatialTarget.Position) then
								return
							end

							if tryCursedShipDoorTransit(spatialTarget.Position) then
								return
							end
						end

						muse = humanoidRootPart:FindFirstChild("muse") or Instance.new("BodyVelocity")
						muse.Name = "muse"
						muse.MaxForce = Vector3.new(0, math.huge, 0)
						muse.Velocity = Vector3.new(0, 0, 0)
						muse.Parent = humanoidRootPart
						humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
						humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
						cFrame = spatialTarget
						position = spatialTarget.Position
						scopedValueCurrent = nil
						unitCopy = nil
						TweenController.Playing = true
						prepareCharacterCollisionParts()

						if LocalPlayer.Character then
							humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

							if humanoid then
								humanoid.AutoRotate = false
							end
						end

						stepDirectTweenHeartbeat = function(primaryArg)
							if TweenController.Playing then
								if humanoidRootPart then
									if humanoidRootPart.Parent then
										if LocalPlayer.Character then
											local worldPosition = humanoidRootPart.Position
											local displacementVec = position - worldPosition
											local magnitude = displacementVec.Magnitude
											local recoverStuckTweenPositionCurrent

											if Config.FastTween then
												recoverStuckTweenPositionCurrent = recoverStuckTweenPosition(
													worldPosition,
													scopedValueCurrent,
													unitCopy
												)

												if magnitude < 18 then
													recoverStuckTweenPositionCurrent = 25
												end
											elseif Config.TweenFast then
												recoverStuckTweenPositionCurrent = recoverStuckTweenPosition(
													worldPosition,
													scopedValueCurrent,
													unitCopy
												)

												if magnitude < 18 then
													recoverStuckTweenPositionCurrent = 25
												end
											elseif magnitude < 18 then
												recoverStuckTweenPositionCurrent = 100
											elseif magnitude <= 80 then
												recoverStuckTweenPositionCurrent = 160
											else
												recoverStuckTweenPositionCurrent = 220
											end

											local computedTotal = recoverStuckTweenPositionCurrent
												* math.min(primaryArg, 0.07)

											if magnitude <= math.max(computedTotal, 1.5) then
												humanoidRootPart.CFrame = cFrame
												if tertiaryArg then
													stopTween(false)
													return
												end
												TweenController.Hovering = true
												TweenController.HoverCFrame = cFrame
												stopTween(true)
												return
											end

											local unit = displacementVec.Unit
											local deltaVector = worldPosition + (unit * computedTotal)
											scopedValueCurrent = deltaVector
											unitCopy = unit
											humanoidRootPart.CFrame = CFrame.new(deltaVector, position)
											return
										end

										stopTween(false)
										return
									end

									stopTween(false)
									return
								end

								stopTween(false)
								return
							end

							stopTween(false)
						end

						TweenController.HeartbeatConn = Services.RunService.Heartbeat:Connect(stepDirectTweenHeartbeat)
						return
					end
				end
			end

			local FastAttack
			FastAttack = {}
			local PlayersService
			PlayersService = game:GetService("Players")
			local VirtualInputMgr

			do
				local ReplicatedStorage = game:GetService("ReplicatedStorage")
				local Workspace = game:GetService("Workspace")
				VirtualInputMgr = game:GetService("VirtualInputManager")
				local localPlayer = PlayersService.LocalPlayer
				local modules = ReplicatedStorage:WaitForChild("Modules")
				local net = modules:WaitForChild("Net")
				local reRegisterAttack = net:WaitForChild("RE/RegisterAttack")
				local reRegisterHit = net:WaitForChild("RE/RegisterHit")
				local reShootGunEvent = net:WaitForChild("RE/ShootGunEvent")
				local validatorFunc = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Validator2")
				local attackConfig = {
					AttackDistance = 65,
					AttackMobs = true,
					AttackPlayers = true,
					AttackCooldown = 0.01,
					ComboResetTime = 0.01,
					MaxCombo = 2,
					HitboxLimbs = {
						"RightLowerArm",
						"RightUpperArm",
						"LeftLowerArm",
						"LeftUpperArm",
						"RightHand",
						"LeftHand",
					},
					AutoClickEnabled = true,
				}
				local index = {}
				index.__index = index

				index.new = function()
					local constructedObject = setmetatable({
						Debounce = 0,
						ComboDebounce = 0,
						ShootDebounce = 0,
						M1Combo = 0,
						EnemyRootPart = nil,
						Connections = {},
						Overheat = {
							Dragonstorm = {
								MaxOverheat = 3,
								Cooldown = 0,
								TotalOverheat = 0,
								Distance = 350,
								Shooting = false,
							},
						},
						ShootsPerTarget = { ["Dual Flintlock"] = 2 },
						SpecialShoots = {
							["Skull Guitar"] = "TAP",
							Bazooka = "Position",
							Cannon = "Position",
							Dragonstorm = "Overheat",
						},
					}, index)

					pcall(function()
						constructedObject.CombatFlags = require(modules.Flags).COMBAT_REMOTE_THREAD
						local localScript =
							localPlayer:WaitForChild("PlayerScripts"):FindFirstChildOfClass("LocalScript")

						if localScript then
							if getsenv then
								constructedObject.HitFunction = getsenv(localScript)._G.SendHitsToServer
								return
							end
						end
					end)

					task.spawn(function()
						pcall(function()
							local combatController = ReplicatedStorage:WaitForChild("Controllers", 10)
								:WaitForChild("CombatController", 10)
							local module = require(combatController)
							local shootFunction

							if module then
								if module.Attack then
									shootFunction = getupvalue(module.Attack, 9) or nil
								else
									shootFunction = nil
									constructedObject.ShootFunction = shootFunction
									return
								end
							else
								shootFunction = nil
								constructedObject.ShootFunction = shootFunction
								return
							end

							constructedObject.ShootFunction = shootFunction
						end)
					end)

					return constructedObject
				end

				index.IsEntityAlive = function(controller, humanoidComp)
					if humanoidComp then
						humanoidComp = humanoidComp:FindFirstChild("Humanoid")
						if humanoidComp then
							return humanoidComp.Health > 0
						end
					end

					return humanoidComp
				end

				index.CheckStun = function(primaryArg, targetInstance, humanoidComp, weaponCategory)
					local stun = targetInstance:FindFirstChild("Stun")
					local busy = targetInstance:FindFirstChild("Busy")

					if humanoidComp.Sit then
						if weaponCategory == "Sword" then
							return false
						end

						if weaponCategory == "Melee" then
							return false
						end

						if weaponCategory == "Blox Fruit" then
							return false
						end
					end

					if stun then
						if stun.Value > 0 then
							return false
						end

						if busy then
							if busy.Value then
								return false
							end
						end
					elseif busy then
						if busy.Value then
							return false
						end
					end

					return true
				end

				index.GetBladeHits = function(attackSelf, attackerCharacter, customRange)
					local originPosition = attackerCharacter:GetPivot().Position
					local hitTargets = {}
					local effectiveRange = customRange or attackConfig.AttackDistance

					local function collectAliveLimbTargets(entityContainer)
						if not entityContainer then
							return
						end
						for _, entityModel in ipairs(entityContainer:GetChildren()) do
							pcall(function()
								if entityModel ~= attackerCharacter and attackSelf:IsEntityAlive(entityModel) then
									local limbName = attackConfig.HitboxLimbs[math.random(#attackConfig.HitboxLimbs)]
									local targetLimb = entityModel:FindFirstChild(limbName)
										or entityModel:FindFirstChild("HumanoidRootPart")
									if
										targetLimb
										and (originPosition - targetLimb.Position).Magnitude <= effectiveRange
									then
										if not attackSelf.EnemyRootPart then
											attackSelf.EnemyRootPart = targetLimb
										else
											table.insert(hitTargets, { entityModel, targetLimb })
										end
									end
								end
							end)
						end
					end

					if attackConfig.AttackMobs then
						pcall(collectAliveLimbTargets, Workspace.Enemies)
					end
					if attackConfig.AttackPlayers then
						pcall(collectAliveLimbTargets, Workspace.Characters)
					end
					return hitTargets
				end

				index.GetClosestEnemy = function(attackController, targetModel, tertiaryArg)
					local bladeHits = attackController:GetBladeHits(targetModel, tertiaryArg)
					local huge = math.huge
					local bladeHitEntry = nil

					for _, bladeHit in ipairs(bladeHits) do
						local position = bladeHit[2].Position
						local magnitude = (targetModel:GetPivot().Position - position).Magnitude

						if magnitude < huge then
							bladeHitEntry = bladeHit[2]
							huge = magnitude
						end
					end

					return bladeHitEntry
				end

				index.GetCombo = function(attackModuleSelf)
					local comboDebounce = attackModuleSelf.ComboDebounce
					local m1Combo

					if (tick() - comboDebounce) <= attackConfig.ComboResetTime then
						m1Combo = attackModuleSelf.M1Combo or 0
					else
						m1Combo = 0
					end

					local m1ComboCurrent = ((attackConfig.MaxCombo <= m1Combo) and 1) or (m1Combo + 1)
					attackModuleSelf.ComboDebounce = tick()
					attackModuleSelf.M1Combo = m1ComboCurrent
					return m1ComboCurrent
				end

				index.ShootInTarget = function(attackModuleSelf, secondaryArg)
					local character = localPlayer.Character

					if attackModuleSelf:IsEntityAlive(character) then
						local tool = character:FindFirstChildOfClass("Tool")

						if tool then
							if tool.ToolTip ~= "Gun" then
								return
							end
							local initialCounterCurrent

							if tool:FindFirstChild("Cooldown") then
								initialCounterCurrent = tool.Cooldown.Value or 0.3
							else
								initialCounterCurrent = 0.3
							end

							local shootDebounce = attackModuleSelf.ShootDebounce
							if (tick() - shootDebounce) < initialCounterCurrent then
								return
							end
							local specialShootMode = attackModuleSelf.SpecialShoots[tool.Name]
							if specialShootMode then
								if specialShootMode == "TAP" then
									local gunRemote = tool:FindFirstChild("RemoteEvent")
									if gunRemote then
										local shotCount = tool:GetAttribute("LocalTotalShots") or 0
										tool:SetAttribute("LocalTotalShots", shotCount + 1)
										validatorFunc:FireServer(attackModuleSelf:GetValidator2())
										gunRemote:FireServer("TAP", secondaryArg)
										attackModuleSelf.ShootDebounce = tick()
										return
									end
									VirtualInputMgr:SendMouseButtonEvent(0, 0, 0, true, game, 1)
									task.wait(0.05)
									VirtualInputMgr:SendMouseButtonEvent(0, 0, 0, false, game, 1)
									attackModuleSelf.ShootDebounce = tick()
									return
								elseif specialShootMode == "Position" then
									local shotCount = tool:GetAttribute("LocalTotalShots") or 0
									tool:SetAttribute("LocalTotalShots", shotCount + 1)
									validatorFunc:FireServer(attackModuleSelf:GetValidator2())
									reShootGunEvent:FireServer(secondaryArg)
									attackModuleSelf.ShootDebounce = tick()
									return
								else
									VirtualInputMgr:SendMouseButtonEvent(0, 0, 0, true, game, 1)
									task.wait(0.05)
									VirtualInputMgr:SendMouseButtonEvent(0, 0, 0, false, game, 1)
									attackModuleSelf.ShootDebounce = tick()
									return
								end
							end

							specialShootEntry = "Normal"

							if specialShootEntry == "TAP" then
								if tool:FindFirstChild("RemoteEvent") then
									tool:SetAttribute(
										"LocalTotalShots",
										(tool:GetAttribute("LocalTotalShots") or 0) + 1
									)
									validatorFunc:FireServer(attackModuleSelf:GetValidator2())

									if specialShootEntry ~= "TAP" then
										reShootGunEvent:FireServer(secondaryArg)
									else
										tool.RemoteEvent:FireServer("TAP", secondaryArg)
									end

									attackModuleSelf.ShootDebounce = tick()
									return
								end
							end

							VirtualInputMgr:SendMouseButtonEvent(0, 0, 0, true, game, 1)
							task.wait(0.05)
							VirtualInputMgr:SendMouseButtonEvent(0, 0, 0, false, game, 1)
							attackModuleSelf.ShootDebounce = tick()
							return
						end

						return
					end
				end

				local function resolveValidator(primaryArg)
					if primaryArg.ShootFunction then
						local upvalueRef = getupvalue(primaryArg.ShootFunction, 15)
						local upvalueRefCurrent = getupvalue(primaryArg.ShootFunction, 13)
						local upvalueRefTarget = getupvalue(primaryArg.ShootFunction, 16)
						local upvalueRefPrimary = getupvalue(primaryArg.ShootFunction, 17)
						local upvalueRefFallback = getupvalue(primaryArg.ShootFunction, 14)
						local upvalueRefCandidate = getupvalue(primaryArg.ShootFunction, 12)
						local upvalueRefCached = getupvalue(primaryArg.ShootFunction, 18)
						local computedTotal = (
							(
								(
									((upvalueRefFallback * upvalueRefCurrent) + (upvalueRefCandidate * upvalueRef))
									% upvalueRefTarget
								) * upvalueRefTarget
							) + (upvalueRefCandidate * upvalueRefCurrent)
						) % upvalueRefPrimary
						local clampedNumber = math.floor(computedTotal / upvalueRefTarget)
						local computedTotalCurrent = computedTotal - (clampedNumber * upvalueRefTarget)
						local computedTotalTarget = upvalueRefCached + 1
						setupvalue(primaryArg.ShootFunction, 15, upvalueRef)
						setupvalue(primaryArg.ShootFunction, 13, upvalueRefCurrent)
						setupvalue(primaryArg.ShootFunction, 16, upvalueRefTarget)
						setupvalue(primaryArg.ShootFunction, 17, upvalueRefPrimary)
						setupvalue(primaryArg.ShootFunction, 14, clampedNumber)
						setupvalue(primaryArg.ShootFunction, 12, computedTotalCurrent)
						setupvalue(primaryArg.ShootFunction, 18, computedTotalTarget)
						return math.floor((computedTotal / upvalueRefPrimary) * 16777215), computedTotalTarget
					end

					return 0, 0
				end

				index.GetValidator2 = resolveValidator

				index.UseNormalClick = function(attackModuleSelf, secondaryArg, tertiaryArg, fourthArg)
					attackModuleSelf.EnemyRootPart = nil
					local bladeHits = attackModuleSelf:GetBladeHits(secondaryArg)

					if attackModuleSelf.EnemyRootPart then
						reRegisterAttack:FireServer(fourthArg)

						if attackModuleSelf.CombatFlags then
							if attackModuleSelf.HitFunction then
								attackModuleSelf.HitFunction(attackModuleSelf.EnemyRootPart, bladeHits)
								return
							end
						end

						reRegisterHit:FireServer(attackModuleSelf.EnemyRootPart, bladeHits)
						return
					end
				end

				index.UseFruitM1 = function(attackController, targetModel, tertiaryArg, fourthArg)
					local bladeHits = attackController:GetBladeHits(targetModel)
					if bladeHits[1] then
						tertiaryArg.LeftClickRemote:FireServer(
							(bladeHits[1][2].Position - targetModel:GetPivot().Position).Unit,
							fourthArg
						)
						return
					end
				end

				index.Attack = function(attackController)
					if attackConfig.AutoClickEnabled then
						local debounce = attackController.Debounce
						if (tick() - debounce) < attackConfig.AttackCooldown then
							return
						end
						local character = localPlayer.Character

						if character then
							if attackController:IsEntityAlive(character) then
								local humanoid = character.Humanoid
								local tool = character:FindFirstChildOfClass("Tool")

								if tool then
									local toolTip = tool.ToolTip

									if table.find({ "Melee", "Blox Fruit", "Sword", "Gun" }, toolTip) then
										local attackCooldown

										if tool:FindFirstChild("Cooldown") then
											attackCooldown = tool.Cooldown.Value or attackConfig.AttackCooldown
										else
											attackCooldown = attackConfig.AttackCooldown
										end

										if attackController:CheckStun(character, humanoid, toolTip) then
											local combo = attackController:GetCombo()
											local initialCounterCurrent = ((attackConfig.MaxCombo <= combo) and 0.05)
												or 0
											local computedTotal = attackCooldown + initialCounterCurrent
											local debounceCurrent

											if attackConfig.MaxCombo <= combo then
												if toolTip ~= "Gun" then
													debounceCurrent = (tick() + 0.05) or tick()
												else
													debounceCurrent = tick()
												end
											else
												debounceCurrent = tick()
											end

											attackController.Debounce = debounceCurrent

											if toolTip == "Blox Fruit" then
												if tool:FindFirstChild("LeftClickRemote") then
													attackController:UseFruitM1(character, tool, combo)
													return
												end
											end

											if toolTip == "Gun" then
												local closestEnemy = attackController:GetClosestEnemy(character, 120)
												if closestEnemy then
													attackController:ShootInTarget(closestEnemy.Position)
													return
												end
												return
											end

											attackController:UseNormalClick(character, humanoid, computedTotal)
											return
										end

										return
									end

									return
								end

								return
							end

							return
						end

						return
					end
				end

				pcall(function()
					local netCurrent = game.ReplicatedStorage.Modules.Net
					netCurrent:WaitForChild("RE/RegisterHit")
					netCurrent:WaitForChild("RE/RegisterAttack")
					local collectedItemsCurrent = {}

					local function gatherPrimaryAttackTargets()
						local collectedItemsPrimary = {}
						local character = LocalPlayer.Character
						local position

						if character then
							local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

							if humanoidRootPart then
								position = humanoidRootPart.Position or Vector3.new(0, 0, 0)
							else
								position = Vector3.new(0, 0, 0)
							end
						else
							position = Vector3.new(0, 0, 0)
						end

						local enemies = Services.Workspace:FindFirstChild("Enemies")

						if enemies then
							for _, child in ipairs(enemies:GetChildren()) do
								local humanoid = child:FindFirstChild("Humanoid")
								local humanoidRootPart = child:FindFirstChild("HumanoidRootPart")

								if humanoid then
									if humanoidRootPart then
										if humanoid.Health > 0 then
											if (humanoidRootPart.Position - position).Magnitude <= 75 then
												table.insert(collectedItemsPrimary, child)
											end
										end
									end
								end
							end

							return collectedItemsPrimary
						end

						return collectedItemsPrimary
					end

					GetAllBladeHits = gatherPrimaryAttackTargets

					local function gatherExtendedAttackTargets()
						local collectedItemsPrimary = {}
						local character = LocalPlayer.Character
						local position

						if character then
							local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

							if humanoidRootPart then
								position = humanoidRootPart.Position or Vector3.new(0, 0, 0)
							else
								position = Vector3.new(0, 0, 0)
							end
						else
							position = Vector3.new(0, 0, 0)
						end

						local characters = Services.Workspace:FindFirstChild("Characters")

						if characters then
							for _, child in ipairs(characters:GetChildren()) do
								if child ~= character then
									if child:FindFirstChild("Humanoid") then
										if child:FindFirstChild("HumanoidRootPart") then
											if child.Humanoid.Health > 0 then
												if (child.HumanoidRootPart.Position - position).Magnitude <= 75 then
													table.insert(collectedItemsPrimary, child)
												end
											end
										end
									end
								end
							end

							return collectedItemsPrimary
						end

						return collectedItemsPrimary
					end

					Getplayerhit = gatherExtendedAttackTargets
					local netTarget = Services.ReplicatedStorage.Modules.Net
					local RegisterAttack = require(netTarget):RemoteEvent("RegisterAttack", true)
					local RegisterHit = require(netTarget):RemoteEvent("RegisterHit", true)

					local function attack()
						local collectedItemsPrimary = {}

						for _, iteratedElement in ipairs(GetAllBladeHits()) do
							table.insert(collectedItemsPrimary, iteratedElement)
						end

						for _, iteratedElement in ipairs(Getplayerhit()) do
							table.insert(collectedItemsPrimary, iteratedElement)
						end

						if #collectedItemsPrimary ~= 0 then
							local targetInstance = collectedItemsPrimary[1]

							if targetInstance then
								local head = targetInstance:FindFirstChild("Head")
								local humanoidRootPart

								if head then
									humanoidRootPart = head
								else
									humanoidRootPart = targetInstance:FindFirstChild("HumanoidRootPart")
									if not humanoidRootPart then
										return
									end
								end

								local collectedItemsFallback = { humanoidRootPart, {}, [4] = "078da341" }

								for _, iteratedElement in ipairs(collectedItemsPrimary) do
									local rootPart = iteratedElement:FindFirstChild("HumanoidRootPart")

									if rootPart then
										table.insert(collectedItemsFallback[2], { iteratedElement, rootPart })
										table.insert(collectedItemsFallback[2], iteratedElement)
									end
								end

								RegisterAttack:FireServer(0)
								RegisterHit:FireServer(unpack(collectedItemsFallback))
								return
							end

							return
						end
					end

					collectedItemsCurrent.Attack = attack

					if _G.BananaAttackWorkerThread then
						pcall(task.cancel, _G.BananaAttackWorkerThread)
						_G.BananaAttackWorkerThread = nil
					end

					local bananaAttackWorkerToken = {}
					_G.BananaAttackWorkerToken = bananaAttackWorkerToken

					registerCleanupCallback(function()
						if _G.BananaAttackWorkerToken == bananaAttackWorkerToken then
							_G.BananaAttackWorkerToken = nil
						end
						if _G.BananaAttackWorkerThread then
							pcall(task.cancel, _G.BananaAttackWorkerThread)
							_G.BananaAttackWorkerThread = nil
						end
					end)

					_G.BananaAttackWorkerThread = task.spawn(function()
						while isSessionActive() and _G.BananaAttackWorkerToken == bananaAttackWorkerToken do
							local fastAttackTick = _G.FastAttackTick
							if fastAttackTick and (os.clock() - fastAttackTick) < 0.35 then
								pcall(function()
									collectedItemsCurrent.Attack()
								end)
								task.wait(0.025)
							else
								task.wait(0.05)
							end
						end
					end)
				end)

				FastAttack.Attack = function()
					_G.FastAttackTick = os.clock()
					_G.FastAttack = os.time()
					lastIdleTick = os.time()
				end

				local combatConfig = {
					GRAB = true,
					GRAB_DISTANCE = 350,
					BRING_LIMIT = 6,
					BRING_FOLLOW_DISTANCE = 45,
					MAX_ATTACK_DURATION = 3,
					MAX_ATTACK_DURATION_2 = 30,
					LEVITATE_TIME = 1,
					CurrentIndex = 1,
					FixedAnchors = {},
					BringSessions = {},
				}
				combatConfig.SpecialClusterMobs = ScriptStorage.SpecialClusterMobs
					or { ["Dangerous Prisoner"] = true, Gladiator = true, Raider = true, Mercenary = true }
				CombatController = combatConfig
				CombatController.Special1 = CombatController.SpecialClusterMobs
				CombatController.BRING_TEST_VERSION = 3
				LastFound = os.time()
				local configRecord = { FarmingVelocity = true, FarmingPosition = true }

				CombatController.ReleaseGrab = function(targetInstance)
					if targetInstance then
						local humanoidRootPart = targetInstance:FindFirstChild("HumanoidRootPart")
						local flowStep, firstChild

						if humanoidRootPart then
							for k in pairs(configRecord) do
								flowStep = nil
								firstChild = humanoidRootPart:FindFirstChild(k)

								if firstChild then
									firstChild:Destroy()
								end
							end
						else
							humanoidRootPart = targetInstance.PrimaryPart

							if humanoidRootPart then
								for k in pairs(configRecord) do
									flowStep = nil
									firstChild = humanoidRootPart:FindFirstChild(k)

									if firstChild then
										firstChild:Destroy()
									end
								end
							end
						end

						targetInstance:SetAttribute("IsGrabbed", nil)
						targetInstance:SetAttribute("MidPoint", nil)
						return
					end
				end

				CombatController.FreezeMob = function(targetInstance, cFrame)
					if targetInstance then
						if targetInstance.Parent then
							local humanoid = targetInstance:FindFirstChildOfClass("Humanoid")
							local humanoidRootPart = targetInstance:FindFirstChild("HumanoidRootPart")

							if not humanoidRootPart then
								humanoidRootPart = targetInstance.PrimaryPart
								if not humanoidRootPart then
									return
								end
							end

							if humanoid then
								if humanoid.Health <= 0 then
									return
								end

								for _, child in ipairs(targetInstance:GetChildren()) do
									if child:IsA("BasePart") then
										child.CanCollide = false
									end
								end

								humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
								humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
								local farmingVelocity = humanoidRootPart:FindFirstChild("FarmingVelocity")

								if not farmingVelocity then
									farmingVelocity = Instance.new("BodyVelocity")
									farmingVelocity.Name = "FarmingVelocity"
									farmingVelocity.Parent = humanoidRootPart
								end

								farmingVelocity.MaxForce = Vector3.new(1000000, 1000000, 1000000)
								farmingVelocity.Velocity = Vector3.new(0, 0, 0)
								if cFrame then
									humanoidRootPart.CFrame = cFrame
									return
								end
								return
							end

							return
						end

						return
					end
				end

				CombatController.CleanupGrabbed = function(primaryArg)
					local character = LocalPlayer.Character
					character = character and character:FindFirstChild("HumanoidRootPart")
					local computedTotal = CombatController.GRAB_DISTANCE + 25

					for _, childInst in Services.Workspace.Enemies:GetChildren() do
						if primaryArg and (childInst.Name ~= primaryArg) then
							if childInst:GetAttribute("IsGrabbed") then
								CombatController.ReleaseGrab(childInst)
							end
						elseif childInst:GetAttribute("IsGrabbed") then
							local humanoid = childInst:FindFirstChild("Humanoid")
							local humanoidRootPart = childInst:FindFirstChild("HumanoidRootPart")
								or childInst.PrimaryPart
							local attribute = childInst:GetAttribute("FailureCount")

							if
								(humanoid and (humanoid.Health <= 0))
								or childInst:GetAttribute("IgnoreGrab")
								or (attribute and (attribute > 5))
								or (
									character
									and humanoidRootPart
									and (computedTotal < (character.Position - humanoidRootPart.Position).Magnitude)
								)
							then
								CombatController.ReleaseGrab(childInst)
							end
						end

						if not childInst:GetAttribute("IsGrabbed") then
							local primaryPart = childInst:FindFirstChild("HumanoidRootPart") or childInst.PrimaryPart

							if primaryPart then
								for k in pairs(configRecord) do
									local firstChild = primaryPart:FindFirstChild(k)

									if firstChild then
										firstChild:Destroy()
									end
								end
							end
						end
					end
				end

				local function closeActiveDialogueGui()
					if MeleeBuyBusy then
						return
					end

					if LocalPlayer then
						local playerGui = LocalPlayer:FindFirstChild("PlayerGui")

						if playerGui then
							pcall(function()
								require(game.ReplicatedStorage.DialogueController).close()
							end)

							local dogHouse = playerGui:FindFirstChild("DogHouse")

							if dogHouse then
								if not dogHouse.Enabled then
									if dogHouse:FindFirstChild("Frame") then
										if dogHouse.Frame.Visible then
											pcall(function()
												dogHouse.Enabled = false

												for _, descendant in ipairs(dogHouse:GetDescendants()) do
													if descendant:IsA("GuiObject") then
														if descendant.Visible then
															descendant.Visible = false
														end
													end
												end
											end)

											return
										end
									end

									return
								end

								pcall(function()
									dogHouse.Enabled = false

									for _, descendant in ipairs(dogHouse:GetDescendants()) do
										if descendant:IsA("GuiObject") then
											if descendant.Visible then
												descendant.Visible = false
											end
										end
									end
								end)

								return
							end

							return
						end
					end
				end

				shared.BananaGrabCleanupVersion = (shared.BananaGrabCleanupVersion or 0) + 1
				local bananaGrabCleanupVersion = shared.BananaGrabCleanupVersion

				task.spawn(function()
					while shared.BananaGrabCleanupVersion == bananaGrabCleanupVersion do
						if not _G.Stop then
							CombatController.CleanupGrabbed()
							closeActiveDialogueGui()
							task.wait(1)
							continue
						end

						break
					end
				end)

				CombatController.SetSimulationRadius = function()
					pcall(function()
						setscriptable(LocalPlayer, "SimulationRadius", true)
						sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
					end)
				end

				CombatController.GetAliveMob = function(targetInstance)
					if targetInstance then
						local humanoid = targetInstance:FindFirstChild("Humanoid")
						local humanoidRootPart = targetInstance:FindFirstChild("HumanoidRootPart")

						if humanoid then
							if humanoidRootPart then
								if humanoid.Health > 0 then
									return humanoid, humanoidRootPart
								end
							end
						end

						return
					end
				end

				CombatController.CanGrabRoot = function(targetInstance)
					return targetInstance ~= nil and targetInstance:IsA("BasePart")
				end

				CombatController.GetSpawnAnchor = function(primaryArg)
					local mobName = tostring(primaryArg)
					if CombatController.SpecialClusterMobs[mobName] then
						return nil
					end

					if CombatController.Special1 then
						local special1 = CombatController.Special1

						if mobName then
							if special1[mobName] then
								return nil
							end

							if CombatController.FixedAnchors[mobName] then
								return CombatController.FixedAnchors[mobName]
							end
						end
					elseif CombatController.FixedAnchors[mobName] then
						return CombatController.FixedAnchors[mobName]
					end

					local mobRegions = ScriptStorage.MobRegions and ScriptStorage.MobRegions[mobName]
					local character = LocalPlayer.Character
					character = character and character:FindFirstChild("HumanoidRootPart")
					local scopedValue = nil

					if mobRegions then
						local collectedItemsCurrent = {}

						for _, mobRegion in ipairs(mobRegions) do
							local computedTotal = #collectedItemsCurrent + 1
							local goalCFrame

							if typeof(mobRegion) == "CFrame" then
								goalCFrame = mobRegion or CFrame.new(mobRegion)
							else
								goalCFrame = CFrame.new(mobRegion)
							end

							collectedItemsCurrent[computedTotal] = goalCFrame
						end

						local scopedValueCurrent = nil
						local magnitudeCopy = nil
						scopedValue = nil

						for _, spatialTarget in ipairs(collectedItemsCurrent) do
							local scopedValueTarget, scopedValuePrimary, scopedValueFallback =
								ipairs(collectedItemsCurrent)
							local initialCounterCurrent = 0

							for _, spatialTargetCurrent in ipairs(collectedItemsCurrent) do
								initialCounterCurrent += (spatialTarget.Position - spatialTargetCurrent.Position).Magnitude
							end

							local magnitude

							if character then
								magnitude = (spatialTarget.Position - character.Position).Magnitude

								if not magnitude then
									magnitude = 0
								end
							else
								magnitude = 0
							end

							if scopedValueCurrent then
								if initialCounterCurrent < scopedValueCurrent then
									scopedValueCurrent = initialCounterCurrent
									magnitudeCopy = magnitude
									scopedValue = spatialTarget
								elseif math.abs(initialCounterCurrent - scopedValueCurrent) < 0.001 then
									if magnitudeCopy then
										if magnitude < magnitudeCopy then
											scopedValueCurrent = initialCounterCurrent
											magnitudeCopy = magnitude
											scopedValue = spatialTarget
										end
									elseif magnitude < math.huge then
										scopedValueCurrent = initialCounterCurrent
										magnitudeCopy = magnitude
										scopedValue = spatialTarget
									end
								end
							else
								scopedValueCurrent = initialCounterCurrent
								magnitudeCopy = magnitude
								scopedValue = spatialTarget
							end
						end

						if scopedValue then
							CombatController.FixedAnchors[mobName] = scopedValue
							return scopedValue
						end
					elseif scopedValue then
						CombatController.FixedAnchors[mobName] = scopedValue
						return scopedValue
					end

					local enemies = Services.Workspace:FindFirstChild("Enemies")

					if enemies then
						for _, child in ipairs(enemies:GetChildren()) do
							if child.Name ~= mobName then
								continue
							end

							if child:GetAttribute("IgnoreGrab") then
								continue
							end
							local aliveMobModel, aliveMobModelCurrent = CombatController.GetAliveMob(child)
							if aliveMobModelCurrent then
								CombatController.FixedAnchors[mobName] = aliveMobModelCurrent.CFrame
								return aliveMobModelCurrent.CFrame
							end
						end
					end

					return CombatController.FixedAnchors[mobName]
				end

				CombatController.GetAttackOffset = function(primaryArg)
					local height = _G.FarmHeight or 15
					if CombatController.IsRaidActive() then
						return CFrame.new(0, math.max(height, 20), 0)
					end
					return CFrame.new(0, height, 0)
				end
			end

			CombatController.GetStandbyFrame = function(primaryArg, bringSession)
				local anchor

				if bringSession then
					anchor = bringSession.Anchor

					if not anchor then
						anchor = CombatController.GetSpawnAnchor(primaryArg)
						if not anchor then
							return anchor
						end
					end
				else
					anchor = CombatController.GetSpawnAnchor(primaryArg)
					if not anchor then
						return anchor
					end
				end

				return anchor * CombatController.GetAttackOffset(anchor)
			end

			CombatController.HasAliveMob = function(primaryArg)
				local enemies = Services.Workspace:FindFirstChild("Enemies")

				if enemies then
					for _, child in ipairs(enemies:GetChildren()) do
						if child.Name ~= primaryArg then
							continue
						end

						if CombatController.GetAliveMob(child) then
							return true
						end
					end

					return false
				end

				return false
			end

			local function shouldKeepBringMob(mobInstance, bringSession)
				local aliveMobModel, aliveMobModelCurrent = CombatController.GetAliveMob(mobInstance)

				if aliveMobModelCurrent then
					if bringSession then
						if bringSession.Anchor then
							local magnitude = (aliveMobModelCurrent.Position - bringSession.Anchor.Position).Magnitude
							if CombatController.GRAB_DISTANCE < magnitude then
								return false
							end
							local isCheckPassed = magnitude <= CombatController.BRING_FOLLOW_DISTANCE
							if isCheckPassed then
								return isCheckPassed
							end
							return (CombatController.CanGrabRoot(aliveMobModelCurrent))
						end

						return false
					end

					return false
				end

				return false
			end

			CombatController.ShouldKeepBringMob = shouldKeepBringMob

			CombatController.GetBringSession = function(primaryArg)
				local serializedText = tostring(primaryArg)
				local bringSessionEntry = CombatController.BringSessions[serializedText]
				local isActiveState = false

				if bringSessionEntry then
					local listLength = #bringSessionEntry.Mobs
					local initialCounterCurrent = 1
					local scopedValue

					for i = listLength, initialCounterCurrent, -1 do
						if CombatController.ShouldKeepBringMob(bringSessionEntry.Mobs[i], bringSessionEntry) then
							isActiveState = true
						else
							table.remove(bringSessionEntry.Mobs, i)
						end
					end
				end

				local specialClusterMobEntry = CombatController.SpecialClusterMobs[serializedText]
				local configRecord

				if bringSessionEntry then
					if not isActiveState then
						if #bringSessionEntry.Mobs == 0 then
							configRecord = { Anchor = CombatController.GetSpawnAnchor(serializedText), Mobs = {} }
							CombatController.BringSessions[serializedText] = configRecord
							return configRecord
						end
					end

					if bringSessionEntry.Anchor then
						if specialClusterMobEntry then
							if not CombatController.HasAliveMobNearAnchor(serializedText, bringSessionEntry.Anchor) then
								bringSessionEntry.Anchor = CombatController.GetSpawnAnchor(serializedText)
								return bringSessionEntry
							end
						end

						return bringSessionEntry
					end

					bringSessionEntry.Anchor = CombatController.GetSpawnAnchor(serializedText)
					return bringSessionEntry
				end

				configRecord = { Anchor = CombatController.GetSpawnAnchor(serializedText), Mobs = {} }
				CombatController.BringSessions[serializedText] = configRecord
				return configRecord
			end

			CombatController.RefreshBringTargets = function(primaryArg, bringSession)
				if bringSession then
					bringSession.Mobs = bringSession.Mobs or {}

					for i = #bringSession.Mobs, 1, -1 do
						if not CombatController.ShouldKeepBringMob(bringSession.Mobs[i], bringSession) then
							table.remove(bringSession.Mobs, i)
						end
					end

					local collectedItemsCurrent = {}
					local enemies = Services.Workspace:FindFirstChild("Enemies")

					if enemies then
						local specialClusterMobEntry = CombatController.SpecialClusterMobs[primaryArg]

						if bringSession.Anchor then
							if specialClusterMobEntry then
								if not CombatController.HasAliveMobNearAnchor(primaryArg, bringSession.Anchor) then
									bringSession.Anchor = CombatController.GetSpawnAnchor(primaryArg)
								end
							end
						else
							bringSession.Anchor = CombatController.GetSpawnAnchor(primaryArg)
						end

						if bringSession.Anchor then
							if #bringSession.Mobs >= CombatController.BRING_LIMIT then
								return
							end
							local aliveMobModel, magnitude, checkPassed

							for _, child in ipairs(enemies:GetChildren()) do
								if child.Name == primaryArg then
									local measuredValue

									if not child:GetAttribute("IgnoreGrab") then
										local attribute = child:GetAttribute("FailureCount")
										local aliveMobModelCurrent

										local isEligibleAttempt = (not attribute) or (attribute <= 7)
										if isEligibleAttempt and not table.find(bringSession.Mobs, child) then
											local _, mobRootPart = CombatController.GetAliveMob(child)
											if mobRootPart then
												local anchorDist = (mobRootPart.Position - bringSession.Anchor.Position).Magnitude
												if anchorDist <= CombatController.GRAB_DISTANCE then
													if
														anchorDist <= CombatController.BRING_FOLLOW_DISTANCE
														or CombatController.CanGrabRoot(mobRootPart)
													then
														collectedItemsCurrent[#collectedItemsCurrent + 1] =
															{ Mob = child, Distance = anchorDist }
													end
												end
											end
										end
									end
								end
							end

							local function sortCandidatesByDistanceAsc(primaryArgCurrent, secondaryArg)
								return primaryArgCurrent.Distance < secondaryArg.Distance
							end

							table.sort(collectedItemsCurrent, sortCandidatesByDistanceAsc)

							for _, iteratedElement in ipairs(collectedItemsCurrent) do
								if #bringSession.Mobs >= CombatController.BRING_LIMIT then
									break
								else
									local aliveMobModelCurrent, aliveMobModelTarget =
										CombatController.GetAliveMob(iteratedElement.Mob)

									if aliveMobModelTarget then
										iteratedElement.Mob:SetAttribute(
											"OldPosition",
											iteratedElement.Mob:GetAttribute("OldPosition")
												or aliveMobModelTarget.Position
										)
										bringSession.Mobs[#bringSession.Mobs + 1] = iteratedElement.Mob
									end
								end
							end

							return
						end

						return
					end

					return
				end
			end

			CombatController.GetCurrentBringTarget = function(primaryArg)
				local bringSession = CombatController.GetBringSession(primaryArg)
				CombatController.RefreshBringTargets(primaryArg, bringSession)

				if bringSession then
					if bringSession.Anchor then
						for _, mob in ipairs(bringSession.Mobs) do
							if CombatController.GetAliveMob(mob) then
								return mob, bringSession
							end
						end

						return
					end

					return
				end
			end

			CombatController.GetDistantBringMob = function(bringSession)
				if bringSession then
					if bringSession.Anchor then
						for _, mob in ipairs(bringSession.Mobs) do
							local aliveMobModel, aliveMobModelCurrent = CombatController.GetAliveMob(mob)

							if aliveMobModelCurrent then
								if
									CombatController.BRING_FOLLOW_DISTANCE
									< (aliveMobModelCurrent.Position - bringSession.Anchor.Position).Magnitude
								then
									return mob, aliveMobModelCurrent
								end
							end
						end

						return
					end

					return
				end
			end

			CombatController.Grab = function(primaryArg, bringSession)
				if CombatController.GRAB then
					if primaryArg then
						if GrabDebounce then
							local grabDebounce = GrabDebounce
							if (os.clock() - grabDebounce) < 0.08 then
								return
							end
						end

						GrabDebounce = os.clock()
						CombatController.SetSimulationRadius()
						CombatController.CleanupGrabbed(primaryArg)
						bringSession = bringSession or CombatController.GetBringSession(primaryArg)
						CombatController.RefreshBringTargets(primaryArg, bringSession)

						if bringSession then
							local anchor = bringSession.Anchor

							if anchor then
								local mobs = bringSession.Mobs
								mobs = mobs or {}

								for _, mob in ipairs(mobs) do
									local aliveMobModel, aliveMobModelCurrent = CombatController.GetAliveMob(mob)

									if aliveMobModelCurrent then
										if aliveMobModel then
											if CombatController.CanGrabRoot(aliveMobModelCurrent) then
												if
													(aliveMobModelCurrent.Position - anchor.Position).Magnitude
													<= CombatController.GRAB_DISTANCE
												then
													CombatController.FreezeMob(mob, anchor)
													mob:SetAttribute("IsGrabbed", true)
													mob:SetAttribute("MidPoint", anchor)
												end
											end
										end
									end
								end

								return
							end
						end

						return
					end

					return
				end
			end

			CombatController.GrabSpecial = function(primaryArg, spatialTarget)
				pcall(function()
					setscriptable(game.Players.LocalPlayer, "SimulationRadius", true)
					sethiddenproperty(game.Players.LocalPlayer, "SimulationRadius", math.huge)
				end)

				if CombatController.GRAB then
					if primaryArg then
						if spatialTarget then
							if GrabDebounce then
								local grabDebounce = GrabDebounce
								if (os.clock() - grabDebounce) < 0.08 then
									return
								end
							end

							GrabDebounce = os.clock()
							CombatController.CleanupGrabbed(primaryArg)
							local position = spatialTarget.Position
							local collectedItemsCurrent = {}
							local enemies = Services.Workspace:FindFirstChild("Enemies")

							if enemies then
								for _, child in ipairs(enemies:GetChildren()) do
									if child.Name ~= primaryArg then
										continue
									else
										local humanoid = child:FindFirstChild("Humanoid")
										local humanoidRootPart = child:FindFirstChild("HumanoidRootPart")

										if
											not humanoid
											or (
												not humanoidRootPart
												or ((humanoid.Health <= 0) or child:GetAttribute("IgnoreGrab"))
											)
										then
											continue
										else
											local attribute = child:GetAttribute("FailureCount")
											local worldPosition, scopedValue, checkPassed, scopedValueCurrent, primaryPart, childCopy, setAttribute, worldPositionCopy, computedTotal

											if not attribute or (attribute <= 7) then
												worldPosition = humanoidRootPart.Position

												if worldPosition then
													if
														(worldPosition - position).Magnitude
														< CombatController.GRAB_DISTANCE
													then
														childCopy = child
														setAttribute = child.SetAttribute
														worldPositionCopy = child:GetAttribute("OldPosition")
															or worldPosition
														setAttribute(childCopy, "OldPosition", worldPositionCopy)
														computedTotal = #collectedItemsCurrent + 1
														collectedItemsCurrent[computedTotal] = {
															Mon = child,
															Root = humanoidRootPart,
															Humanoid = humanoid,
															Position = worldPosition,
															Distance = (worldPosition - position).Magnitude,
														}
													else
														continue
													end
												else
													continue
												end
											else
												continue
											end
										end
									end
								end

								if #collectedItemsCurrent <= 0 then
									return
								end

								local function sortClusterByDistanceAsc(primaryArgCurrent, secondaryArg)
									return primaryArgCurrent.Distance < secondaryArg.Distance
								end

								table.sort(collectedItemsCurrent, sortClusterByDistanceAsc)
								local collectedItemsPrimary = {}
								local initialCounterCurrent = 0
								local clampedNumber = math.min(5, #collectedItemsCurrent)
								local initialCounterTarget = 1
								local vector = Vector3.new(0, 0, 0)
								local scopedValueTarget, spatialTargetCurrent, computedTotalCurrent

								for i = initialCounterTarget, clampedNumber do
									spatialTargetCurrent = collectedItemsCurrent[i]
									vector += spatialTargetCurrent.Position
									initialCounterCurrent += 1
									computedTotalCurrent = #collectedItemsPrimary + 1
									collectedItemsPrimary[computedTotalCurrent] = spatialTargetCurrent
								end

								local targetCFrame = CFrame.new(vector / initialCounterCurrent)

								for i = 1, #collectedItemsPrimary do
									local mon = collectedItemsPrimary[i].Mon
									local root = collectedItemsPrimary[i].Root
									local humanoid = collectedItemsPrimary[i].Humanoid

									if ((mon and root) and humanoid) and (humanoid.Health > 0) then
										if not mon:GetAttribute("DefaultMidPoint") then
											mon:SetAttribute("DefaultMidPoint", targetCFrame)
										end

										local attribute = mon:GetAttribute("OriginPosition")

										if not attribute then
											attribute = root.CFrame
											mon:SetAttribute("OriginPosition", attribute)
										end

										humanoid.WalkSpeed = 0
										humanoid.JumpPower = 0
										humanoid.AutoRotate = false
										root.CanCollide = false
										root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
										root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

										if (root.Position - targetCFrame.Position).Magnitude > 140 then
											targetCFrame = attribute
											mon:SetAttribute(
												"FailureCount",
												(mon:GetAttribute("FailureCount") or 0) + 1
											)
										end

										local farmingPosition = root:FindFirstChild("FarmingPosition")

										if not farmingPosition then
											farmingPosition = Instance.new("BodyPosition")
											farmingPosition.Name = "FarmingPosition"
											farmingPosition.Parent = root
										end

										farmingPosition.MaxForce = Vector3.new(100000, 100000, 100000)
										farmingPosition.P = 1250
										farmingPosition.D = 50
										farmingPosition.Position = targetCFrame.Position
										root.CFrame = targetCFrame
										mon:SetAttribute("IsGrabbed", true)
										mon:SetAttribute("MidPoint", targetCFrame)
									end
								end

								return
							end

							return
						end

						return
					end

					return
				end
			end

			SortEntitiesByDistance = function(mobInstance)
				local rootPart = mobInstance and mobInstance:FindFirstChild("HumanoidRootPart")
				if rootPart then
					return math.floor(CaculateDistance(rootPart.CFrame))
				end
				return math.huge
			end

			CombatController.Search = function(primaryArg)
				local collectedItemsCurrent = {}
				local isActiveState = false

				for _, characterModel in GetMonAsSortedRange() do
					if table.find(primaryArg, characterModel.Name) then
						if characterModel:FindFirstChild("Humanoid") then
							if characterModel.Humanoid.Health > 0 then
								local attribute = characterModel:GetAttribute("FailureCount")

								if attribute then
									if attribute < 3 then
										table.insert(collectedItemsCurrent, characterModel)
										isActiveState = true
									end
								else
									table.insert(collectedItemsCurrent, characterModel)
									isActiveState = true
								end
							end
						end
					end
				end

				table.sort(collectedItemsCurrent, function(leftItem, rightItem)
					return SortEntitiesByDistance(leftItem) < SortEntitiesByDistance(rightItem)
				end)

				if isActiveState then
					return collectedItemsCurrent[1]
				end

				if CombatController.IsRaidActive() then
					return
				end

				for _, childName in ipairs(primaryArg) do
					local firstChild = game.ReplicatedStorage:FindFirstChild(childName)
					if CombatController.GetAliveMob(firstChild) then
						return firstChild
					end
				end
			end

			local collectedItemsCandidate = { ["Cake Prince"] = true, ["Dough King"] = true }

			CombatController.IsCakeBossTarget = function(primaryArg)
				for _, iteratedElement in ipairs(primaryArg) do
					if collectedItemsCandidate[tostring(iteratedElement)] then
						return true
					end
				end

				return false
			end

			CombatController.IsBossTarget = function(primaryArg)
				local bossNameCurrent = tostring(primaryArg)
				if BossesOrderLevel[bossNameCurrent] then
					return true
				end

				if BossesOrderWL[bossNameCurrent] then
					return true
				end

				if SpecialBossesOrder[bossNameCurrent] then
					return true
				end

				for _, bossName in ipairs(BossesOrder) do
					if bossName ~= bossNameCurrent then
						continue
					end
					return true
				end

				return false
			end

			CombatController.IsRaidActive = function()
				if SeaIndex ~= 1 then
					local character = LocalPlayer.Character

					if character then
						local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

						if humanoidRootPart then
							local position = humanoidRootPart.Position
							if math.abs(position.X) > 40000 then
								return true
							end

							if math.abs(position.Z) > 40000 then
								return true
							end

							if LocalPlayer:FindFirstChild("PlayerGui") then
								local main = LocalPlayer.PlayerGui:FindFirstChild("Main")

								if main then
									if main:FindFirstChild("Timer") then
										if main.Timer.Visible then
											if Services.Workspace:FindFirstChild("_WorldOrigin") then
												local locations =
													Services.Workspace._WorldOrigin:FindFirstChild("Locations")

												if locations then
													for _, child in ipairs(locations:GetChildren()) do
														if string.find(child.Name, "Island ") then
															if
																(child.Position - Vector3.new(0, 0, 0)).Magnitude > 7000
															then
																if
																	(child.Position - humanoidRootPart.Position).Magnitude
																	< 3000
																then
																	return true
																end
															end
														end
													end

													return false
												end
											end

											return false
										end

										return false
									end

									return false
								end
							end

							return false
						end
					end

					return false
				end

				return false
			end

			CombatController.FindCakeBigMirror = function()
				local scopedValue = nil
				local configRecord = nil

				for _, iteratedElement in ipairs({ Services.Workspace:FindFirstChild("Map"), Services.Workspace }) do
					if iteratedElement then
						for _, descendant in ipairs(iteratedElement:GetDescendants()) do
							local processedText = string.lower(tostring(descendant.Name))
							local processedTextCurrent = string.gsub(processedText, "%W", "")

							if processedTextCurrent == "bigmirror" then
								local collectedItemsCurrent = {}
								local initialCounterCurrent = 0

								if descendant:IsA("BasePart") then
									table.insert(collectedItemsCurrent, descendant)
									initialCounterCurrent = (
										descendant:FindFirstChildWhichIsA("TouchTransmitter") and 20
									) or 5
								elseif descendant:IsA("Model") then
									for _, descendantInst in ipairs(descendant:GetDescendants()) do
										if descendantInst:IsA("BasePart") then
											table.insert(collectedItemsCurrent, descendantInst)
											initialCounterCurrent += ((descendantInst:FindFirstChildWhichIsA(
												"TouchTransmitter"
											) and 20) or 1)
										end
									end
								end

								if #collectedItemsCurrent > 0 then
									local computedTotal = initialCounterCurrent
										+ (((processedText == "bigmirror") and 50) or 10)

									if not scopedValue or (computedTotal > scopedValue) then
										configRecord = {
											Instance = descendant,
											TouchParts = collectedItemsCurrent,
											CFrame = (descendant:IsA("Model") and descendant:GetModelCFrame())
												or descendant.CFrame,
										}
										scopedValue = computedTotal
									end
								end
							end
						end
					end
				end

				return configRecord
			end

			CombatController.GetCakeBigMirrorFallbackCFrame = function()
				if ScriptStorage.NPCs then
					local cakeScientist = ScriptStorage.NPCs["Cake Scientist"]

					if cakeScientist then
						local ok, result = pcall(function()
							return cakeScientist:GetModelCFrame()
						end)

						if ok then
							if result then
								return result
							end
						end
					end
				end

				local worldOrigin = Services.Workspace:FindFirstChild("_WorldOrigin")

				if worldOrigin then
					worldOrigin = Services.Workspace._WorldOrigin:FindFirstChild("PlayerSpawns")

					if worldOrigin then
						local worldOriginCopy = worldOrigin
						local findFirstChild = worldOrigin.FindFirstChild
						local statusMessage = ((Config.Team ~= "Marines") and "Pirates") or "Marines"
						worldOrigin = findFirstChild(worldOriginCopy, tostring(statusMessage))

						if worldOrigin then
							local loaf = worldOrigin:FindFirstChild("Loaf")

							if loaf then
								local ok, result = pcall(function()
									if loaf:IsA("Model") then
										local modelCFrame = loaf:GetModelCFrame()
										if modelCFrame then
											return modelCFrame
										end
									end

									return loaf.CFrame
								end)

								if ok then
									if result then
										return result
									end
								end
							end
						end

						return CFrame.new(-2711, 63, -12896)
					end
				end

				return CFrame.new(-2711, 63, -12896)
			end

			CombatController.GetCakeMirrorDimensionCFrame = function()
				local map = Services.Workspace:FindFirstChild("Map")

				if map then
					local mirrorDimension = map:FindFirstChild("MirrorDimension")

					if mirrorDimension then
						local main = mirrorDimension:FindFirstChild("MAIN", true)

						if main then
							if main:IsA("BasePart") then
								return main.CFrame, main:GetFullName()
							end
						end
					end
				end

				if Services.Workspace:FindFirstChild("_WorldOrigin") then
					local locations = Services.Workspace._WorldOrigin:FindFirstChild("Locations")

					if locations then
						local dimensionalShift = locations:FindFirstChild("Dimensional Shift")

						if dimensionalShift then
							if dimensionalShift:IsA("BasePart") then
								return dimensionalShift.CFrame, dimensionalShift:GetFullName()
							end
						end
					end
				end
			end

			CombatController.UseCakeBigMirrorPortal = function(primaryArg)
				if SeaIndex ~= 3 then
					return false, "wrong-sea"
				end
				local cakeBigMirror = CombatController.FindCakeBigMirror()

				if cakeBigMirror then
					if primaryArg then
						local instance = cakeBigMirror.Instance
						local position = cakeBigMirror.CFrame.Position
						return true, instance:GetFullName(), position
					end

					local character = LocalPlayer.Character
					local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
					if not humanoidRootPart then
						return false, "missing-root"
					end
					SetTask("MainTask", "Auto Farm Boss - Entering BigMirror")
					TweenController.Create(cakeBigMirror.CFrame + Vector3.new(0, 4, 0))

					if CaculateDistance(cakeBigMirror.CFrame) < 35 then
						for _, iteratedElement in ipairs(cakeBigMirror or {}) do
							pcall(function()
								firetouchinterest(humanoidRootPart, iteratedElement, 0)
								task.wait()
								firetouchinterest(humanoidRootPart, iteratedElement, 1)
							end)
						end
					end

					local instance = cakeBigMirror.Instance
					local position = cakeBigMirror.CFrame.Position
					return true, instance:GetFullName(), position
				end

				if primaryArg then
					return true, "loading-bigmirror", CombatController.GetCakeBigMirrorFallbackCFrame().Position
				end
				local cakeBigMirrorFallbackCFrame = CombatController.GetCakeBigMirrorFallbackCFrame()
				SetTask("MainTask", "Auto Farm Boss - Loading BigMirror")
				TweenController.Create(cakeBigMirrorFallbackCFrame + Vector3.new(0, 5, 0))
				return true, "loading-bigmirror", cakeBigMirrorFallbackCFrame.Position
			end

			local function executeCombatAttack(
				targetNames,
				allowAnyNearbyMob,
				maxSearchRange,
				onTickCallback,
				attackOptions
			)
				if not targetNames then
					return
				end
				local targetList = (type(targetNames) == "string") and { targetNames } or targetNames
				local searchRadius = tonumber(maxSearchRange) or 500
				local options = (type(attackOptions) == "table") and attackOptions or {}
				local allowBring = options.AllowBring == true

				local primaryName = targetList[1] and tostring(targetList[1]) or nil
				local isSpecialOrBossPrimary = false
				if primaryName then
					isSpecialOrBossPrimary = CombatController.IsBossTarget(primaryName)
						or (CombatController.SpecialClusterMobs and CombatController.SpecialClusterMobs[primaryName])
						or false
				end

				if MeleeEquipBusyName then
					SetTask("MainTask", "Melee | Loading " .. tostring(MeleeEquipBusyName))
					return
				end

				if not isSpecialOrBossPrimary and ShouldPreemptForMeleeBuy and ShouldPreemptForMeleeBuy() then
					SetTask("MainTask", "Auto Melee Buy | Pending " .. tostring(GetMeleeBuyPending()))
					return
				end

				pcall(function()
					setscriptable(LocalPlayer, "SimulationRadius", true)
					sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
				end)

				local isRaidActive = CombatController.IsRaidActive()

				local function releaseSessionGrabs(primaryMob, bringSession)
					if primaryMob then
						CombatController.ReleaseGrab(primaryMob)
					end
					if bringSession and bringSession.Mobs then
						for _, grabbedMob in ipairs(bringSession.Mobs) do
							CombatController.ReleaseGrab(grabbedMob)
						end
					end
				end

				for _, rawTargetName in ipairs(targetList) do
					local mobName = tostring(rawTargetName)
					local currentTarget = nil
					local bringSession = nil

					local disableBring = isRaidActive
						or not allowBring
						or CombatController.IsBossTarget(mobName)
						or (CombatController.SpecialClusterMobs and CombatController.SpecialClusterMobs[mobName])
						or false

					if
						(mobName == "Deandre" or mobName == "Urban" or mobName == "Diablo")
						and not ScriptStorage.Backpack.Yama
					then
						local eliteKills = tonumber(FunctionsHandler.Yama:Get("EliteCount"))
						if not eliteKills or eliteKills < 30 then
							local nowUnix = os.time()
							if (nowUnix - (LastPortalTouchClock or 0)) > 180 then
								LastPortalTouchClock = nowUnix
								pcall(function()
									Remotes.CommF_:InvokeServer("EliteHunter")
								end)
							end
						end
					end

					if options.TargetInstance then
						local explicitMob = options.TargetInstance
						local enemiesFolder = workspace:FindFirstChild("Enemies")
						local explicitHum = (typeof(explicitMob) == "Instance")
								and explicitMob:FindFirstChildOfClass("Humanoid")
							or nil
						if
							not enemiesFolder
							or typeof(explicitMob) ~= "Instance"
							or explicitMob.Name ~= mobName
							or not explicitMob:IsDescendantOf(enemiesFolder)
							or not explicitHum
							or explicitHum.Health <= 0
						then
							return
						end
						currentTarget = explicitMob
					else
						currentTarget = CombatController.Search({ mobName })
						if not currentTarget and (isRaidActive or allowAnyNearbyMob) then
							local nearestAnyMob = GetMonAsSortedRange()[1]
							local nearestRoot = nearestAnyMob and nearestAnyMob:FindFirstChild("HumanoidRootPart")
							if nearestRoot and CaculateDistance(nearestRoot.Position) < searchRadius then
								currentTarget = nearestAnyMob
							end
						end

						if not currentTarget then
							local standbyCFrame = CombatController.GetStandbyFrame(mobName)
							if not standbyCFrame and ScriptStorage.MobRegions and ScriptStorage.MobRegions[mobName] then
								standbyCFrame = ScriptStorage.MobRegions[mobName][1]
							end
							if standbyCFrame then
								TweenController.Create(standbyCFrame * CFrame.new(0, 25, 0), false, isRaidActive)
							end
							task.wait(0.2)
							continue
						end
					end

					local initialRoot = currentTarget:FindFirstChild("HumanoidRootPart")
					if CombatController.IsCakeBossTarget(targetList) then
						if not initialRoot or CaculateDistance(initialRoot.CFrame) > 400 then
							if CombatController.UseCakeBigMirrorPortal() then
								return
							end
						end
					end

					LastFound = os.time()
					local lastSecondTick = os.time()

					if not disableBring then
						bringSession = CombatController.GetBringSession(mobName)
						CombatController.RefreshBringTargets(mobName, bringSession)
					end

					local wrappedStopCondition = nil
					if options.StopCondition then
						wrappedStopCondition = function()
							if options.StopCondition() then
								releaseSessionGrabs(currentTarget, bringSession)
								return true
							end
							return false
						end
					end

					local totalUnscathedSeconds = 0
					local phaseUnscathedSeconds = 0

					while isSessionActive() do
						if wrappedStopCondition and wrappedStopCondition() then
							return
						end

						if MeleeEquipBusyName then
							TweenController.ClearGhost()
							SetTask("MainTask", "Melee | Loading " .. tostring(MeleeEquipBusyName))
							return
						end

						if not disableBring and ShouldPreemptForMeleeBuy and ShouldPreemptForMeleeBuy() then
							SetTask("MainTask", "Auto Melee Buy | Pending " .. tostring(GetMeleeBuyPending()))
							return
						end

						local playerChar = LocalPlayer.Character
						local playerHum = playerChar and playerChar:FindFirstChildOfClass("Humanoid")
						if not playerChar or not playerHum or playerHum.Health <= 0 then
							TweenController.ClearGhost()
							return
						end

						if options.CheckQuest and not GetCurrentClaimQuest() then
							releaseSessionGrabs(currentTarget, bringSession)
							TweenController.Hovering = false
							TweenController.HoverCFrame = nil
							break
						end

						local mobHum = currentTarget:FindFirstChild("Humanoid")
						local mobRoot = currentTarget:FindFirstChild("HumanoidRootPart")

						if not mobHum or mobHum.Health <= 0 then
							CombatController.ReleaseGrab(currentTarget)

							if options.CheckQuest and not GetCurrentClaimQuest() then
								releaseSessionGrabs(nil, bringSession)
								TweenController.Hovering = false
								TweenController.HoverCFrame = nil
								break
							end

							local nextBringTarget = not disableBring and CombatController.GetCurrentBringTarget(mobName)
								or nil
							if not nextBringTarget then
								TweenController.Hovering = false
								TweenController.HoverCFrame = nil
								if currentTarget.Name == "Don Swan" then
									Storage:Set("SwanDefeated", true)
									Hop()
								end
								break
							end

							currentTarget = nextBringTarget
							mobHum = currentTarget:FindFirstChild("Humanoid")
							mobRoot = currentTarget:FindFirstChild("HumanoidRootPart")
						end

						if not mobHum or not mobRoot then
							TweenController.Hovering = false
							TweenController.HoverCFrame = nil
							break
						end

						if not disableBring and bringSession then
							CombatController.RefreshBringTargets(mobName, bringSession)
							CombatController.Grab(mobName, bringSession)
							local _, hasDistantMob = CombatController.GetDistantBringMob(bringSession)
							if hasDistantMob then
								CombatController.Grab(mobName, bringSession)
							end
						end

						local isSpecialCluster = CombatController.SpecialClusterMobs
							and CombatController.SpecialClusterMobs[mobName]
						local directHoverCFrame = mobRoot.CFrame * CombatController.GetAttackOffset(mobRoot.CFrame)
						local targetCombatCFrame
						if disableBring or isSpecialCluster then
							targetCombatCFrame = directHoverCFrame
						else
							targetCombatCFrame = CombatController.GetStandbyFrame(mobName, bringSession)
								or directHoverCFrame
						end

						local distToCombatPos = CaculateDistance(targetCombatCFrame)
						if isRaidActive and distToCombatPos > 1000 then
							return
						end

						if isRaidActive and distToCombatPos <= 150 then
							local playerRoot = playerChar:FindFirstChild("HumanoidRootPart")
							if playerRoot then
								stopTween(false)
								playerRoot.CFrame = targetCombatCFrame
							else
								TweenController.CreateDirect(targetCombatCFrame, false, true)
							end
						elseif distToCombatPos > 150 then
							TweenController.Create(targetCombatCFrame, false, isRaidActive)
							local approachTimeout = math.min(12, math.max(3, distToCombatPos / 200))
							local approachStart = os.clock()
							while
								CaculateDistance(targetCombatCFrame) > 150
								and (os.clock() - approachStart) < approachTimeout
							do
								if not isSessionActive() or (wrappedStopCondition and wrappedStopCondition()) then
									return
								end
								local chkChar = LocalPlayer.Character
								local chkHum = chkChar and chkChar:FindFirstChildOfClass("Humanoid")
								if not chkChar or not chkHum or chkHum.Health <= 0 then
									TweenController.ClearGhost()
									return
								end
								if not TweenController.Playing and CaculateDistance(targetCombatCFrame) > 150 then
									TweenController.Create(targetCombatCFrame, false, isRaidActive)
								end
								task.wait(0.1)
							end
						elseif disableBring or isSpecialCluster then
							TweenController.CreateDirect(targetCombatCFrame, false, isRaidActive)
						elseif CaculateDistance(targetCombatCFrame) > CombatController.BRING_FOLLOW_DISTANCE then
							TweenController.Create(targetCombatCFrame, false, isRaidActive)
						else
							TweenController.Hovering = true
							TweenController.HoverCFrame = targetCombatCFrame
							prepareCharacterCollisionParts()
						end

						if CaculateDistance(targetCombatCFrame) >= 150 then
							return
						end

						if onTickCallback then
							onTickCallback()
						end

						if isSpecialCluster then
							CombatController.GrabSpecial(mobName, mobRoot)
						end

						if currentTarget.Name ~= "Core" then
							if
								(ScriptStorage.PlayerData.Level or 0) > 100
								and totalUnscathedSeconds >= CombatController.MAX_ATTACK_DURATION_2
								and mobHum.Health == mobHum.MaxHealth
							then
								pcall(function()
									currentTarget:Destroy()
								end)
								continue
							end

							local failCount = tonumber(currentTarget:GetAttribute("FailureCount")) or 0
							if failCount > 5 then
								pcall(function()
									currentTarget:Destroy()
								end)
								continue
							end

							if
								phaseUnscathedSeconds >= CombatController.MAX_ATTACK_DURATION
								and mobHum.Health == mobHum.MaxHealth
							then
								local oldPos = currentTarget:GetAttribute("OldPosition")
								phaseUnscathedSeconds = 0
								if oldPos then
									CombatController.ReleaseGrab(currentTarget)
									currentTarget:SetPrimaryPartCFrame(CFrame.new(oldPos))
									currentTarget:SetAttribute("IgnoreGrab", true)
									currentTarget:SetAttribute("FailureCount", failCount + 1)
									while
										isSessionActive()
										and currentTarget.Parent
										and currentTarget:FindFirstChild("HumanoidRootPart")
									do
										if CaculateDistance(currentTarget.HumanoidRootPart.CFrame, oldPos) <= 6 then
											task.wait()
											return
										end
										task.wait()
										if currentTarget:FindFirstChild("HumanoidRootPart") then
											currentTarget.HumanoidRootPart.CFrame = CFrame.new(oldPos)
										end
									end
									return
								end
							end
						end

						local desiredWeaponType = ScriptStorage.ForceToUseSword and "Sword" or "Melee"
						FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call(desiredWeaponType)

						if not isRaidActive then
							CombatController.FreezeMob(currentTarget)
						end
						if not disableBring and bringSession and bringSession.Mobs then
							for _, grabbedMob in ipairs(bringSession.Mobs) do
								CombatController.FreezeMob(grabbedMob, bringSession.Anchor)
							end
						end

						if
							isRaidActive
							and playerHum.Health > 0
							and playerHum.Health < (playerHum.MaxHealth * 0.45)
						then
							local evadeStart = os.clock()
							while
								isSessionActive()
								and playerHum.Health > 0
								and playerHum.Health < (playerHum.MaxHealth * 0.85)
								and (os.clock() - evadeStart) < 8
							do
								if mobRoot and mobRoot.Parent then
									TweenController.CreateDirect(
										mobRoot.CFrame * CFrame.new(0, 100, 0),
										false,
										isRaidActive
									)
								end
								task.wait(0.2)
							end
						end

						FastAttack:Attack(currentTarget)

						if os.time() ~= lastSecondTick then
							lastSecondTick = os.time()
							phaseUnscathedSeconds += 1
							totalUnscathedSeconds += 1
						end

						if phaseUnscathedSeconds > 30 and currentTarget.Name ~= "Core" then
							break
						end

						task.wait(0.03)
					end
				end

				TweenController.Hovering = false
				TweenController.HoverCFrame = nil
			end

			CombatController.Attack = executeCombatAttack
			LevelFarmTTL = 0
			LastTravel = os.time()
			LastQuestRefreshLevel = 0
			LastQuestRefreshTick = 0
			local scopedValueCandidate
			scopedValueCandidate = nil
			local getSkipModeStageForLevel

			getSkipModeStageForLevel = function(primaryArg)
				if primaryArg < 10 then
					return 4
				end

				if primaryArg < 50 then
					return 1
				end

				if primaryArg < 80 then
					return 2
				end
				return 4
			end

			local hasCompletedSkipModeStage

			hasCompletedSkipModeStage = function(primaryArg)
				local isCheckPassed = SeaIndex ~= 1
				if isCheckPassed then
					return isCheckPassed
				end
				local level

				if GetLiveLevel then
					level = (GetLiveLevel() or ScriptStorage.PlayerData.Level) or 0
				else
					level = ScriptStorage.PlayerData.Level or 0
				end

				return primaryArg == getSkipModeStageForLevel(level)
			end

			DragonTalonNeedsFireEssence = false
			LastUptimeTick = 0
			LastSideTaskTick = 0
			FunctionsHandler = { Initalized = false }
			local meleeBuyAttemptCounts, crossSeaMeleeCooldowns, getSharedPendingMeleeRecord, clearPendingMeleeRecord, fetchElectroQuestProgress, collectElectroLightningParts, resolveMeleeTrainerCFrame, scanWorldOriginLocations, hasOwnedOrMasteredMelee, chooseNextMeleeAction

			do
				setmetatable(FunctionsHandler, {
					__index = function(registryTable, moduleName)
						local queryResult = rawget(registryTable, moduleName)
						if queryResult then
							return queryResult
						end

						return {
							Initalized = false,
							Register = function(shouldInit)
								if shouldInit == false then
									return
								end
								local moduleObject = {
									CacheListener = {},
									RealCache = {},
									Methods = {},
									Constants = {},
									Events = {},
									Initalized = true,
								}

								function moduleObject:RegisterMethod(methodName, callbackFn)
									self.Methods[methodName] = {
										Name = methodName,
										Callback = callbackFn,
										Call = function(methodObj, ...)
											return methodObj.Callback(...)
										end,
										Events = {},
									}
									return true
								end

								setmetatable(moduleObject.Constants, {
									__newindex = function()
										error("cannot change constant value!")
									end,
								})

								function moduleObject:SaveConstant(constKey, constValue)
									if self.Constants[constKey] then
										error("constant name was used before!")
									end
									rawset(self.Constants, constKey, constValue)
								end

								function moduleObject:Set(stateKey, stateValue)
									self.CacheListener[stateKey] = stateValue
									return stateValue
								end

								function moduleObject:Get(stateKey)
									local constVal = self.Constants[stateKey]
									if constVal ~= nil then
										return constVal
									end
									return self.RealCache[stateKey]
								end

								function moduleObject:AddVariableChangeListener(stateKey, listenerFn)
									self.Events[stateKey] = listenerFn
								end

								moduleObject.CacheListener.__parent = moduleObject
								setmetatable(moduleObject.CacheListener, {
									__newindex = function(listenerProxy, key, val)
										local parentMod = listenerProxy.__parent
										if parentMod.Events[key] then
											parentMod.Events[key](key, val)
										end
										parentMod.RealCache[key] = val
									end,
								})

								FunctionsHandler[moduleName] = moduleObject
							end,
						}
					end,
				})

				FunctionsHandler.SynchorizeUntilModuleLoaded = function(targetModule, timeoutSeconds)
					local waitStart = os.time()
					while not targetModule.Initalized do
						task.wait()
						assert(not (timeoutSeconds and (os.time() - waitStart) > timeoutSeconds), "timed out")
					end
				end

				GetCurrentClaimQuest = function(...)
					return QuestController.GetCurrentClaimQuest(...)
				end

				FunctionsHandler.LocalPlayerController.Register()
				FunctionsHandler.ExpRedeem:Register()
				FunctionsHandler.LevelFarm:Register()
				FunctionsHandler.Yama:Register()
				FunctionsHandler.Tushita:Register()
				FunctionsHandler.CursedDualKatana:Register()
				FunctionsHandler.SoulGuitar:Register()
				FunctionsHandler.SecondSeaPuzzle:Register()
				FunctionsHandler.ColosseumPuzzle:Register()
				FunctionsHandler.Trevor:Register()
				FunctionsHandler.ThirdSeaPuzzle:Register()
				FunctionsHandler.PirateRaid:Register()
				FunctionsHandler.RaidController:Register()
				FunctionsHandler.MeleeBuyController:Register()
				FunctionsHandler.CannonBuyController:Register()
				FunctionsHandler.MeleesController:Register()
				FunctionsHandler.MasteryTask:Register()
				FunctionsHandler.BossesTask:Register()
				FunctionsHandler.SpecialBossesTask:Register()
				FunctionsHandler.CollectDrops:Register()
				FunctionsHandler.UtillyItemsActivitation:Register()
				FunctionsHandler.RaceV2V3:Register()

				local function getRemainingExpBoostSeconds()
					local remainingBoost = 0
					pcall(function()
						local guideMod = ReplicatedStorage:FindFirstChild("GuideModule")
						if guideMod and type(getsenv) == "function" then
							local env = getsenv(guideMod)
							local serverData = env and env._G and env._G.ServerData
							if serverData and serverData.ExpBoost then
								local boostDuration = tonumber(serverData.ExpBoost) or 0
								local boostSyncTick = tonumber(serverData.ExpBoostTick) or tick()
								remainingBoost = math.max(0, math.floor(boostDuration - (tick() - boostSyncTick)))
							end
						end
					end)
					return remainingBoost
				end

				local FALLBACK_EXP_CODES = {
					"KITT_RESET",
					"Sub2CaptainMaui",
					"DEVSCOOKING",
					"kittgaming",
					"Sub2Fer999",
					"Enyu_is_Pro",
					"Magicbus",
					"JCWK",
					"Starcodeheo",
					"Bluxxy",
					"fudd10_v2",
					"SUB2GAMERROBOT_EXP1",
					"Sub2NoobMaster123",
					"Sub2UncleKizaru",
					"Sub2Daigrock",
					"Axiore",
					"TantaiGaming",
					"StrawHatMaine",
					"Sub2OfficialNoobie",
					"TheGreatAce",
				}
				local redeemedSessionCodes = {}

				local function redeemAllAvailableExpCodes()
					if getRemainingExpBoostSeconds() > 0 then
						return
					end

					local candidateCodes = {}
					local seenCodes = {}
					local function addCandidateCode(rawCode)
						if type(rawCode) ~= "string" then
							return
						end
						local trimmed = rawCode:gsub("^%s+", ""):gsub("%s+$", "")
						if
							#trimmed >= 4
							and #trimmed <= 32
							and not seenCodes[trimmed]
							and not redeemedSessionCodes[trimmed]
						then
							seenCodes[trimmed] = true
							table.insert(candidateCodes, trimmed)
						end
					end

					if httpRequest then
						pcall(function()
							local resp = httpRequest({
								Url = "https://blox-fruits.fandom.com/api.php?action=parse&page=Codes&format=json",
								Method = "GET",
							})
							if
								type(resp) == "table"
								and tonumber(resp.StatusCode) == 200
								and type(resp.Body) == "string"
							then
								local okJson, parsed = pcall(HttpService.JSONDecode, HttpService, resp.Body)
								local htmlBody = okJson
									and parsed
									and parsed.parse
									and parsed.parse.text
									and parsed.parse.text["*"]
								if type(htmlBody) == "string" then
									for codeMatch in htmlBody:gmatch("<b>([%w_]+)</b>") do
										addCandidateCode(codeMatch)
									end
									for codeMatch in htmlBody:gmatch("<code>([%w_]+)</code>") do
										addCandidateCode(codeMatch)
									end
								end
							end
						end)
					end

					for _, staticCode in ipairs(FALLBACK_EXP_CODES) do
						addCandidateCode(staticCode)
					end

					local redeemRemote = ReplicatedStorage:FindFirstChild("Remotes")
						and ReplicatedStorage.Remotes:FindFirstChild("Redeem")
					if not redeemRemote then
						return
					end

					for _, codeStr in ipairs(candidateCodes) do
						if not isSessionActive() or getRemainingExpBoostSeconds() > 0 then
							break
						end
						redeemedSessionCodes[codeStr] = true
						pcall(function()
							redeemRemote:InvokeServer(codeStr)
						end)
						task.wait(0.25)
					end
				end

				task.spawn(function()
					task.wait(3)
					while isSessionActive() do
						local level = (GetLiveLevel and GetLiveLevel()) or ScriptStorage.PlayerData.Level or 0
						if level < MaxLevel then
							if getRemainingExpBoostSeconds() == 0 then
								pcall(redeemAllAvailableExpCodes)
							end
						end

						task.wait(10)
					end
				end)

				FunctionsHandler.LevelFarm:RegisterMethod("Refresh", function()
					if SeaIndex ~= 1 then
						if CombatController.IsRaidActive() then
							return nil
						end
					end

					local raidController = FunctionsHandler.RaidController

					if raidController then
						if raidController.Initalized then
							if raidController.Methods.IsLocked then
								local ok, result = pcall(function()
									return raidController.Methods.IsLocked:Call()
								end)

								if ok then
									if result then
										return nil
									end
								end
							end
						end
					end

					local level

					if GetLiveLevel then
						level = (GetLiveLevel() or ScriptStorage.PlayerData.Level) or 0
					else
						level = ScriptStorage.PlayerData.Level or 0
					end

					if SeaIndex == 3 then
						if QuestController:IsUnderWaterQuest() then
							return 5
						end
					end

					local getSkipModeStageForLevelCurrent = getSkipModeStageForLevel(level)

					if SeaIndex == 1 then
						if scopedValueCandidate then
							if scopedValueCandidate ~= getSkipModeStageForLevelCurrent then
								TweenController.ClearGhost()
							end
						end
					end

					scopedValueCandidate = getSkipModeStageForLevelCurrent
					return getSkipModeStageForLevelCurrent
				end)

				FunctionsHandler.LevelFarm:RegisterMethod("Start", function(primaryArg)
					if hasCompletedSkipModeStage(primaryArg) then
						local function shouldStopSkipModeFarming()
							return not hasCompletedSkipModeStage(primaryArg)
						end

						if SeaIndex ~= 1 then
							if CombatController.IsRaidActive() then
								return
							end
						end

						local level = ScriptStorage.PlayerData.Level
						local isActiveState = false

						if SeaIndex == 3 then
							local bones = ScriptStorage.Backpack.Bones

							if not bones then
								bones = { Count = 0 }
							end

							if bones.Count >= 50 then
								local unixTimestampCurrent, bonesCooldown

								if ForceToRollBone then
									unixTimestampCurrent = os.time()
									bonesCooldown = BonesCooldown

									if bonesCooldown then
										if bonesCooldown < unixTimestampCurrent then
											local response, bonesReply, bonesReplyCurrent, bonesReplyTarget =
												Remotes.CommF_:InvokeServer("Bones", "Check")
											local statusMessage = bonesReplyTarget
											bonesReplyCurrent = bonesReplyCurrent or 1

											if tonumber(bonesReplyCurrent) ~= 0 then
												local setTask = SetTask
												local statusMessageCurrent

												if ScriptStorage.Tools["Fire Essence"] then
													statusMessageCurrent = "Bones | Rolling Random Surprise"
												elseif IsFireEssenceGave then
													statusMessageCurrent = "Bones | Rolling Random Surprise"
												elseif IsMeleePurchaseComplete("Dragon Talon") then
													statusMessageCurrent = "Bones | Rolling Random Surprise"
												else
													statusMessageCurrent =
														"Bones | Rolling Random Surprise for Fire Essence"
												end

												setTask("MainTask", statusMessageCurrent)

												local ok, result = pcall(function()
													return Remotes.CommF_:InvokeServer("Bones", "Buy", 1, 1)
												end)

												isActiveState = ok and (result == 1)
												task.wait(0.3)
												pcall(RefreshInventory)
											else
												statusMessage = statusMessage or "0:0"
												local match, processedText =
													tostring(statusMessage):match("(%d+):(%d+)")
												local computedTotal = (tonumber(match) or 0) * 60
												local initialCounterCurrent = tonumber(processedText) or 0
												BonesCooldown = os.time()
													+ ((computedTotal + initialCounterCurrent) * 60)
											end
										end
									else
										bonesCooldown = 0
									end
								elseif not ScriptStorage.Tools["Fire Essence"] then
									if not IsFireEssenceGave then
										if not IsMeleePurchaseComplete("Dragon Talon") then
											unixTimestampCurrent = os.time()
											bonesCooldown = BonesCooldown

											if not bonesCooldown then
												bonesCooldown = 0
											end
										end
									end
								end
							end
						end

						if SeaIndex == 3 then
							if DragonTalonNeedsFireEssence then
								if not ScriptStorage.Tools["Fire Essence"] then
									if not IsFireEssenceGave then
										if isActiveState then
											return
										end
										local count = (ScriptStorage.Backpack.Bones or { Count = 0 }).Count

										if count < 50 then
											SetTask(
												"MainTask",
												"Dragon Talon | Farming Bones for Fire Essence ( "
													.. (count .. " / 50 )")
											)
											CombatController.Attack(
												{ "Reborn Skeleton", "Living Zombie", "Demonic Soul", "Posessed Mummy" },
												nil,
												nil,
												nil,
												{ AllowBring = true }
											)
											return
										end

										local unixTimestampCurrent = os.time()
										local bonesCooldown = BonesCooldown

										if bonesCooldown then
											if bonesCooldown < unixTimestampCurrent then
												return
											end
										elseif unixTimestampCurrent > 0 then
											return
										end

										SetTask("SideTask", "Dragon Talon | Random Surprise cooldown")
									end
								end
							end
						end

						if GodHumanFlag then
							local function syncMissingGodhumanMaterial()
								getgenv()["     mphm >< <3"] = {}

								for k, materialReq in pairs(GodhumanMaterials) do
									if (ScriptStorage.Backpack[k] or { Count = 0 }).Count < materialReq[1] then
										getgenv()["     mphm >< <3"] = { k, materialReq }
									end
								end

								return unpack(getgenv()["     mphm >< <3"])
							end

							local syncMissingGodhumanMaterialCurrent, syncMissingGodhumanMaterialTarget =
								syncMissingGodhumanMaterial()

							if syncMissingGodhumanMaterialCurrent then
								if SeaIndex ~= syncMissingGodhumanMaterialTarget[2] then
									SetTask(
										"MainTask",
										"Sea Travel | Godhuman Materials | Travelling to Sea "
											.. syncMissingGodhumanMaterialTarget[2]
									)
									Remotes.CommF_:InvokeServer(
										"Travel" .. SeaIndexes[syncMissingGodhumanMaterialTarget[2]]
									)
									return
								end

								SetTask(
									"MainTask",
									"Material Farming | Godhuman | "
										.. (syncMissingGodhumanMaterialCurrent .. " | In Progress")
								)
								local scopedValue

								if syncMissingGodhumanMaterialTarget[4][3] <= level then
									local claimedMobName, rawQuestHeader = GetCurrentClaimQuest()

									if claimedMobName then
										if not string.find(rawQuestHeader, syncMissingGodhumanMaterialTarget[3][1]) then
											if
												not string.find(rawQuestHeader, syncMissingGodhumanMaterialTarget[3][2])
											then
												QuestController.AbandonQuest()
												scopedValue = syncMissingGodhumanMaterialTarget[3]
												CombatController.Attack(
													scopedValue,
													nil,
													nil,
													nil,
													{ AllowBring = true }
												)
												return
											end
										end

										CombatController.Attack(
											syncMissingGodhumanMaterialTarget[3],
											nil,
											nil,
											nil,
											{ AllowBring = true }
										)
										return
									end

									local npcEntry = ScriptStorage.NPCs[syncMissingGodhumanMaterialTarget[4][4]]

									if npcEntry then
										local modelCFrame = npcEntry:GetModelCFrame()

										if modelCFrame then
											TweenController.Create(modelCFrame + Vector3.new(0, 5, 3))
											local clockStamp = os.clock()

											while CaculateDistance(modelCFrame) > 12 do
												if (os.clock() - clockStamp) < 15 then
													if LocalPlayer.Character then
														local humanoid =
															LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

														if humanoid then
															if humanoid.Health <= 0 then
																TweenController.ClearGhost()
																return
															end
															task.wait(0.1)
															continue
														end

														TweenController.ClearGhost()
														return
													end

													TweenController.ClearGhost()
													return
												end

												break
											end

											if CaculateDistance(modelCFrame) > 15 then
												return
											end
										else
											Report("NPC HauntedQuest2 not found")
										end

										task.wait(1)
										QuestController.StartQuest(
											syncMissingGodhumanMaterialTarget[4][1],
											syncMissingGodhumanMaterialTarget[4][2]
										)
										task.wait(0.5)
										return
									end

									Report("NPC HauntedQuest2 not found")
									task.wait(1)
									QuestController.StartQuest(
										syncMissingGodhumanMaterialTarget[4][1],
										syncMissingGodhumanMaterialTarget[4][2]
									)
									task.wait(0.5)
									return
								end

								scopedValue = syncMissingGodhumanMaterialTarget[3]
								CombatController.Attack(scopedValue, nil, nil, nil, { AllowBring = true })
								return
							end

							GodHumanFlag = false
							SetTask("SideTask", "Godhuman materials ready; waiting for MeleeBuyController")
							return
						end

						local lastTravel = LastTravel

						if (os.time() - lastTravel) > 60 then
							LastTravel = os.time()

							if level >= 1500 then
								if SeaIndex ~= 2 then
									if level >= 700 then
										if SeaIndex == 1 then
											SetTask("MainTask", "Sea Travel | Teleporting to Second Sea")
											Remotes.CommF_:InvokeServer("TravelDressrosa")
										end
									end
								elseif
									not Services.Workspace.Map.IceCastle.Hall.LibraryDoor:FindFirstChild("PhoeyuDoor")
								then
									Remotes.CommF_:InvokeServer("TravelZou")
									SetTask("MainTask", "Sea Travel | Teleporting to Third Sea")
								end
							elseif level >= 700 then
								if SeaIndex == 1 then
									SetTask("MainTask", "Sea Travel | Teleporting to Second Sea")
									Remotes.CommF_:InvokeServer("TravelDressrosa")
								end
							end
						end

						if level == MaxLevel then
							if (ScriptStorage.Backpack.Bones or { Count = 0 }).Count >= 500 then
								SetTask("MainTask", "Fragments Farming | Cake Prince | Dough King")
								local cakePrince = ScriptStorage.Enemies["Cake Prince"]

								if cakePrince then
									if cakePrince:FindFirstChild("Humanoid") then
										if cakePrince.Humanoid.Health > 0 then
											CombatController.Attack(
												cakePrince.Name,
												nil,
												nil,
												nil,
												{ AllowBring = false }
											)
											return
										end
									end
								else
									cakePrince = ScriptStorage.Enemies["Dough King"]

									if cakePrince then
										if cakePrince:FindFirstChild("Humanoid") then
											if cakePrince.Humanoid.Health > 0 then
												CombatController.Attack(
													cakePrince.Name,
													nil,
													nil,
													nil,
													{ AllowBring = false }
												)
												return
											end
										end
									end
								end

								local claimedMobName, rawQuestHeader = GetCurrentClaimQuest()

								if claimedMobName then
									if string.find(rawQuestHeader, "Cookie") then
										CombatController.Attack(
											"Cookie Crafter",
											nil,
											nil,
											nil,
											{ AllowBring = true, CheckQuest = true }
										)
										Remotes.CommF_:InvokeServer("CakePrinceSpawner")
										return
									end

									if not string.find(rawQuestHeader, "Cake") then
										if not string.find(rawQuestHeader, "Guard") then
											if not string.find(rawQuestHeader, "Baker") then
												if not string.find(rawQuestHeader, "Baking") then
													QuestController.AbandonQuest()
													task.wait(0.5)
													return
												end
											end

											CombatController.Attack(
												"Baking Staff",
												nil,
												nil,
												nil,
												{ AllowBring = true, CheckQuest = true }
											)
											Remotes.CommF_:InvokeServer("CakePrinceSpawner")
											return
										end
									end

									CombatController.Attack(
										"Cake Guard",
										nil,
										nil,
										nil,
										{ AllowBring = true, CheckQuest = true }
									)
									Remotes.CommF_:InvokeServer("CakePrinceSpawner")
									return
								end

								local cakeQuestGiver = ScriptStorage.NPCs["Cake Quest Giver 1"]

								if cakeQuestGiver then
									local modelCFrame = cakeQuestGiver:GetModelCFrame()

									if modelCFrame then
										TweenController.Create(modelCFrame + Vector3.new(0, 5, 3))
										local clockStamp = os.clock()

										while CaculateDistance(modelCFrame) > 12 do
											if (os.clock() - clockStamp) < 15 then
												if LocalPlayer.Character then
													local humanoid =
														LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

													if humanoid then
														if humanoid.Health <= 0 then
															TweenController.ClearGhost()
															return
														end
														task.wait(0.1)
														continue
													end

													TweenController.ClearGhost()
													return
												end

												TweenController.ClearGhost()
												return
											end

											break
										end

										if CaculateDistance(modelCFrame) > 15 then
											return
										end
									else
										Report("NPC Cake Quest Giver 1 not found")
									end

									task.wait(1)
									QuestController.StartQuest("CakeQuest1", 1)
									task.wait(0.5)
									return
								end

								Report("NPC Cake Quest Giver 1 not found")
								task.wait(1)
								QuestController.StartQuest("CakeQuest1", 1)
								task.wait(0.5)
								return
							end
						end

						if
							Config.FarmBoneForx2EXP
							and (level >= 2025)
							and ((getRemainingExpBoostSeconds() == 0) or (level == MaxLevel))
						then
							local bones = ScriptStorage.Backpack.Bones or { Count = 0 }

							if bones.Count < 500 then
								SetTask("MainTask", "Resource Farming | Bones | For X2 Mastery/Beli")
								CurrentClaimedQuestName = GetCurrentClaimQuest(true)

								if CurrentClaimedQuestName then
									if string.find(CurrentClaimedQuestName, "Demonic") then
										CombatController.Attack(
											{ "Reborn Skeleton", "Living Zombie", "Demonic Soul", "Posessed Mummy" },
											nil,
											nil,
											nil,
											{ AllowBring = true }
										)
										return
									end
									QuestController.AbandonQuest()
									return
								end

								local hauntedCastleQuestGiver = ScriptStorage.NPCs["Haunted Castle Quest Giver 2"]

								if hauntedCastleQuestGiver then
									local modelCFrame = hauntedCastleQuestGiver:GetModelCFrame()

									if modelCFrame then
										TweenController.Create(modelCFrame + Vector3.new(0, 5, 3))
										if CaculateDistance(modelCFrame) >= 20 then
											return
										end
										task.wait(1)
									else
										Report("NPC HauntedQuest2 not found")
									end

									QuestController.StartQuest("HauntedQuest2", 1)
									return
								end

								Report("NPC HauntedQuest2 not found")
								QuestController.StartQuest("HauntedQuest2", 1)
								return
							end
						end

						if primaryArg ~= 1 then
							if primaryArg ~= 2 then
								if primaryArg ~= 3 then
									if primaryArg ~= 5 then
										if primaryArg ~= 4 then
											return
										end
										local livePlayerLevel = GetLiveLevel()
										if shouldStopSkipModeFarming() then
											return
										end
										local measuredValue, refreshActiveQuestSafe

										if livePlayerLevel ~= LastQuestRefreshLevel then
											refreshActiveQuestSafe = function()
												QuestController:RefreshQuest()
											end

											pcall(refreshActiveQuestSafe)
											LastQuestRefreshLevel = livePlayerLevel
											LastQuestRefreshTick = os.time()
										else
											local lastQuestRefreshTick = LastQuestRefreshTick

											if (os.time() - lastQuestRefreshTick) > 20 then
												refreshActiveQuestSafe = function()
													QuestController:RefreshQuest()
												end

												pcall(refreshActiveQuestSafe)
												LastQuestRefreshLevel = livePlayerLevel
												LastQuestRefreshTick = os.time()
											end
										end

										local currentQuest, questNpcCFrame, questId, questSubIndex, questTitle =
											QuestController:GetCurrentQuest()
										local currentNpc = questNpcCFrame

										if currentQuest then
											if questTitle then
												local claimedMobName, rawQuestHeader = GetCurrentClaimQuest()
												if shouldStopSkipModeFarming() then
													return
												end

												if claimedMobName then
													if claimedMobName ~= questTitle then
														if claimedMobName ~= (questTitle .. "s") then
															warn(
																"UI≠script Abandon Raw=",
																rawQuestHeader,
																" Norm=",
																claimedMobName,
																" Tit=",
																questTitle,
																" Mon=",
																currentQuest,
																" Q=",
																questId
															)
															QuestController.AbandonQuest()

															pcall(function()
																QuestController:RefreshQuest()
															end)

															LastQuestRefreshLevel = ScriptStorage.PlayerData.Level
															LastQuestRefreshTick = os.time()
															return
														end
													end
												else
													if not currentNpc then
														pcall(function()
															QuestController:RefreshQuest()
														end)

														currentNpc = QuestController.CurrentNpc
														if not currentNpc then
															resetCurrentQuest(
																"lvl4_npcpos_nil",
																"[L4] NpcPosition nil Q,"
																	.. (
																		tostring(questId)
																		.. (
																			" idx,"
																			.. (
																				tostring(questSubIndex)
																				.. (" " .. tostring(questTitle))
																			)
																		)
																	)
															)
															return Report("failed to get npc position quest 528")
														end
													end

													if shouldStopSkipModeFarming() then
														return
													end
													SetTask(
														"MainTask",
														"Level Farming | " .. (currentQuest .. " | Claiming Quest")
													)
													TweenController.Create(currentNpc + Vector3.new(0, 5, 3))
													local clockStamp = os.clock()

													while CaculateDistance(currentNpc) > 12 do
														if (os.clock() - clockStamp) < 20 then
															if shouldStopSkipModeFarming() then
																return
															end
															local humanoid = LocalPlayer.Character
																and LocalPlayer.Character:FindFirstChildOfClass(
																	"Humanoid"
																)
															local humanoidRootPart = LocalPlayer.Character
																and LocalPlayer.Character:FindFirstChild(
																	"HumanoidRootPart"
																)

															if humanoid then
																if humanoid.Health <= 0 then
																	TweenController.ClearGhost()
																	return
																end

																if humanoidRootPart then
																	if SeaIndex ~= 1 then
																		if CombatController.IsRaidActive() then
																			TweenController.ClearGhost()
																			return
																		end
																	end
																end

																if not TweenController.Playing then
																	if CaculateDistance(currentNpc) > 12 then
																		TweenController.Create(
																			currentNpc + Vector3.new(0, 5, 3)
																		)
																	end
																end

																task.wait(0.1)
																continue
															end

															TweenController.ClearGhost()
															return
														end

														break
													end

													if shouldStopSkipModeFarming() then
														return
													end

													if CaculateDistance(currentNpc) > 15 then
														resetCurrentQuest(
															"lvl4_claim_retry_exhausted",
															"[L4] claim max try d="
																.. (
																	string.format("%.0f", CaculateDistance(currentNpc))
																	.. (" " .. currentQuest)
																)
														)
														return
													end
													task.wait(2)
													if shouldStopSkipModeFarming() then
														return
													end
													LevelFarmTTL = 0
													QuestController.StartQuest(questId, questSubIndex)
													if shouldStopSkipModeFarming() then
														return
													end
													task.wait(1)
													if shouldStopSkipModeFarming() then
														return
													end

													if not GetCurrentClaimQuest() then
														task.wait(0.5)
														if shouldStopSkipModeFarming() then
															return
														end
														QuestController.StartQuest(questId, questSubIndex)
														if shouldStopSkipModeFarming() then
															return
														end
														task.wait(1)
														if shouldStopSkipModeFarming() then
															return
														end

														if not GetCurrentClaimQuest() then
															return
														end
													end
												end

												SetTask(
													"MainTask",
													"Level Farming | " .. (currentQuest .. " | Defeating Enemies")
												)
												local unixTimestampCurrent = os.time()
												CombatController.Attack(currentQuest, nil, nil, nil, {
													AllowBring = true,
													CheckQuest = true,
													StopCondition = shouldStopSkipModeFarming,
												})
												LevelFarmTTL = (LevelFarmTTL + os.time()) - unixTimestampCurrent
												return
											end
										end

										local currentQuestCopyText = tostring(currentQuest)
										resetCurrentQuest(
											"lvl4_no_montitle",
											"[L4] no Task Mon,"
												.. (
													currentQuestCopyText
													.. (
														" Tit,"
														.. (
															tostring(questTitle)
															.. (
																" id,"
																.. (
																	tostring(QuestController.CurrentQuestId)
																	.. (
																		" i,"
																		.. (
																			tostring(QuestController.CurrentLevel)
																			.. (
																				","
																				.. tostring(
																					QuestController.CurrentQuests[QuestController.CurrentLevel]
																						and QuestController.CurrentQuests[QuestController.CurrentLevel].Name
																				)
																			)
																		)
																	)
																)
															)
														)
													)
												)
										)
										return
									end

									local livePlayerLevelCurrent = GetLiveLevel()

									if livePlayerLevelCurrent ~= LastQuestRefreshLevel then
										pcall(function()
											QuestController:RefreshQuest()
										end)

										LastQuestRefreshLevel = livePlayerLevelCurrent
										LastQuestRefreshTick = os.time()
									else
										local lastQuestRefreshTick = LastQuestRefreshTick

										if (os.time() - lastQuestRefreshTick) > 20 then
											pcall(function()
												QuestController:RefreshQuest()
											end)

											LastQuestRefreshLevel = livePlayerLevelCurrent
											LastQuestRefreshTick = os.time()
										end
									end

									local currentQuest, questNpcCFrameCurrent, questIdCurrent, questSubIndexCurrent, questTitleCurrent =
										QuestController:GetCurrentQuest()
									local findNpcCFrameCurrent = questNpcCFrameCurrent

									if currentQuest then
										if questTitleCurrent then
											if SUBMERGED_QUEST_IDS[tostring(questIdCurrent)] then
												if isPlayerInSubmergedIsland() then
													local claimedMobName, rawQuestHeader = GetCurrentClaimQuest()

													if claimedMobName then
														if
															claimedMobName ~= questTitleCurrent
															and claimedMobName ~= (questTitleCurrent .. "s")
														then
															warn(
																"UI~=script Abandon Raw=",
																rawQuestHeader,
																" Norm=",
																claimedMobName,
																" Tit=",
																questTitleCurrent,
																" Mon=",
																currentQuest,
																" Q=",
																questIdCurrent
															)
															QuestController.AbandonQuest()
															pcall(function()
																QuestController:RefreshQuest()
															end)
															LastQuestRefreshLevel = ScriptStorage.PlayerData.Level
															LastQuestRefreshTick = os.time()
															return
														end
													else
														if not findNpcCFrameCurrent then
															findNpcCFrameCurrent = findNpcCFrame(
																SUBMERGED_QUEST_GIVER_NAMES[tostring(questIdCurrent)]
															)
														end
														if
															not findNpcCFrameCurrent
															and isPlayerInSubmergedIsland()
															and workspace:FindFirstChild("NPCs")
														then
															for _, child in ipairs(workspace.NPCs:GetChildren()) do
																if
																	isPositionInSubmergedIsland(
																		child:GetPivot().Position
																	)
																then
																	local lowerNpc = child.Name:lower()
																	if
																		lowerNpc:find("quest", 1, true)
																		or lowerNpc:find("giver", 1, true)
																	then
																		findNpcCFrameCurrent = child:GetPivot()
																		break
																	end
																end
															end
														end
														if not findNpcCFrameCurrent then
															local enemyMob = workspace:FindFirstChild("Enemies")
																and workspace.Enemies:FindFirstChild(currentQuest)
															local enemyRoot = enemyMob
																and enemyMob:FindFirstChild("HumanoidRootPart")
															findNpcCFrameCurrent = enemyRoot
																	and (enemyRoot.CFrame + Vector3.new(0, 20, 0))
																or CFrame.new(11256, -2138, 9888)
														end

														SetTask(
															"MainTask",
															"Level Farming | Under Water | "
																.. (currentQuest .. " | Claiming Quest")
														)
														TweenController.Create(
															findNpcCFrameCurrent + Vector3.new(0, 5, 3)
														)
														local clockStamp = os.clock()

														while CaculateDistance(findNpcCFrameCurrent) > 12 do
															if (os.clock() - clockStamp) < 20 then
																local humanoid = LocalPlayer.Character
																	and LocalPlayer.Character:FindFirstChildOfClass(
																		"Humanoid"
																	)
																local character = LocalPlayer.Character

																if character then
																	character = LocalPlayer.Character:FindFirstChild(
																		"HumanoidRootPart"
																	)
																	if not humanoid then
																		TweenController.ClearGhost()
																		return
																	end
																elseif not humanoid then
																	TweenController.ClearGhost()
																	return
																end

																if humanoid.Health <= 0 then
																	TweenController.ClearGhost()
																	return
																end

																if character then
																	if SeaIndex ~= 1 then
																		if CombatController.IsRaidActive() then
																			TweenController.ClearGhost()
																			return
																		end
																	end
																end

																if not TweenController.Playing then
																	if CaculateDistance(findNpcCFrameCurrent) > 12 then
																		TweenController.Create(
																			findNpcCFrameCurrent + Vector3.new(0, 5, 3)
																		)
																	end
																end

																task.wait(0.1)
																continue
															end

															break
														end

														if CaculateDistance(findNpcCFrameCurrent) > 15 then
															resetCurrentQuest(
																"lvl5_claim_retry_exhausted",
																"[L5] claim max try d="
																	.. (
																		string.format(
																			"%.0f",
																			CaculateDistance(findNpcCFrameCurrent)
																		) .. (" " .. currentQuest)
																	)
															)
															return
														end
														task.wait(2)
														LevelFarmTTL = 0
														QuestController.StartQuest(questIdCurrent, questSubIndexCurrent)
														task.wait(1)

														if not GetCurrentClaimQuest() then
															task.wait(0.5)
															QuestController.StartQuest(
																questIdCurrent,
																questSubIndexCurrent
															)
															task.wait(1)
															if not GetCurrentClaimQuest() then
																return
															end
														end
													end

													SetTask(
														"MainTask",
														"Level Farming | Under Water | "
															.. (currentQuest .. " | Defeating Enemies")
													)
													local unixTimestampCurrent = os.time()
													CombatController.Attack(
														currentQuest,
														nil,
														nil,
														nil,
														{ AllowBring = true, CheckQuest = true }
													)
													LevelFarmTTL = (LevelFarmTTL + os.time()) - unixTimestampCurrent
													return
												end

												SetTask("MainTask", "Level Farming | Under Water | Entering Submerged")
												trySubmarineTravel(Vector3.new(11256, -2138, 9888))
												return
											end
										end
									end

									pcall(function()
										QuestController:RefreshQuest()
									end)

									if FunctionsHandler.LevelFarm then
										if FunctionsHandler.LevelFarm.Methods then
											if FunctionsHandler.LevelFarm.Methods.Start then
												return FunctionsHandler.LevelFarm.Methods.Start.Callback(4)
											end
										end
									end

									return
								end

								SetTask("MainTask", "Level Farming | Skip Mode | Floor " .. primaryArg)
								CombatController.Attack(
									{ "God's Guard", "Shanda", "Royal Soldier", "Royal Squad" },
									nil,
									nil,
									nil,
									{ AllowBring = true, StopCondition = shouldStopSkipModeFarming }
								)
								return
							end

							SetTask("MainTask", "Level Farming | Skip Mode | Floor " .. primaryArg)
							CombatController.Attack(
								"God's Guard",
								nil,
								nil,
								nil,
								{ AllowBring = true, StopCondition = shouldStopSkipModeFarming }
							)
							return
						end

						SetTask("MainTask", "Level Farming | Skip Mode | Floor " .. primaryArg)
						local enemies = workspace:FindFirstChild("Enemies")
						local childCopy = nil

						if enemies then
							childCopy = nil

							for _, child in ipairs(enemies:GetChildren()) do
								if child.Name ~= "Sky Bandit" then
									childCopy = nil
								elseif CombatController.GetAliveMob(child) then
									childCopy = child
									break
								else
									childCopy = nil
								end
							end

							if childCopy then
								CombatController.Attack("Sky Bandit", nil, nil, nil, {
									AllowBring = true,
									TargetInstance = childCopy,
									StopCondition = shouldStopSkipModeFarming,
								})
								return
							end
						elseif childCopy then
							CombatController.Attack("Sky Bandit", nil, nil, nil, {
								AllowBring = true,
								TargetInstance = childCopy,
								StopCondition = shouldStopSkipModeFarming,
							})
							return
						end

						local skyBanditRegion = ScriptStorage.MobRegions and ScriptStorage.MobRegions["Sky Bandit"]
						local skyBanditFrame = skyBanditRegion and skyBanditRegion[1] or CFrame.new(-4955, 296, -2890)
						local standbyFrame = skyBanditFrame * CFrame.new(0, 38, 0)

						if CaculateDistance(standbyFrame) > 60 then
							local needNewTween = not TweenController.Playing
							if not needNewTween and tweenTargetInstance then
								needNewTween = (tweenTargetInstance.Position - standbyFrame.Position).Magnitude > 20
							end
							if needNewTween then
								TweenController.Create(standbyFrame)
							end
						end

						task.wait(0.5)
						return
					end
				end)

				FunctionsHandler.LocalPlayerController:RegisterMethod("EquipTool", function(weaponCategory)
					if not LocalPlayer.Character then
						return
					end
					local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
					if not humanoid then
						return
					end

					local targetMelee = ((weaponCategory == "Melee") and (ScriptStorage.TargetMelee or weaponCategory))
						or weaponCategory
					local character = LocalPlayer.Character
					local tool = character and character:FindFirstChildOfClass("Tool")

					if tool then
						if (weaponCategory == "Melee") and ScriptStorage.TargetMelee then
							if (tool.Name == targetMelee) or (NormalizeMeleeName(tool.Name) == targetMelee) then
								return
							end
						elseif
							(tool.ToolTip == weaponCategory)
							or (tool.Name == tostring(weaponCategory))
							or (NormalizeMeleeName(tool.Name) == tostring(weaponCategory))
						then
							return
						end
					end

					local backpack = LocalPlayer.Backpack
					if backpack then
						for _, childInst in ipairs(backpack:GetChildren()) do
							if childInst:IsA("Tool") and (childInst.Name ~= "Tool") then
								if (weaponCategory == "Melee") and ScriptStorage.TargetMelee then
									if
										(childInst.Name == targetMelee)
										or (NormalizeMeleeName(childInst.Name) == targetMelee)
									then
										humanoid:EquipTool(childInst)
										return
									end
								elseif
									(childInst.Name == tostring(weaponCategory))
									or (childInst.ToolTip == weaponCategory)
									or (NormalizeMeleeName(childInst.Name) == tostring(weaponCategory))
								then
									humanoid:EquipTool(childInst)
									return
								end
							end
						end
					end

					if (weaponCategory == "Melee") and ScriptStorage.TargetMelee and character then
						local targetMeleeCurrent = ScriptStorage.TargetMelee
						if targetMeleeCurrent ~= "Electro" then
							local initialCounterCurrent = tonumber(ScriptStorage.Melees[targetMeleeCurrent]) or 0
							if
								ScriptStorage.MeleesOwned[targetMeleeCurrent]
								or (initialCounterCurrent > 0)
								or IsMeleePurchaseComplete(targetMeleeCurrent)
							then
								local meleeEntry = MeleePrices[targetMeleeCurrent]
								if meleeEntry and meleeEntry.Buy then
									pcall(meleeEntry.Buy)
									task.wait(0.1)
									pcall(meleeEntry.Buy)
								else
									local meleeIdByName = GetMeleeIdByName(targetMeleeCurrent)
									if meleeIdByName then
										pcall(function()
											Remotes.CommF_:InvokeServer("Buy" .. meleeIdByName)
										end)
										task.wait(0.1)
										pcall(function()
											Remotes.CommF_:InvokeServer("Buy" .. meleeIdByName, true)
										end)
									end
								end

								task.wait(0.15)
								backpack = LocalPlayer.Backpack
								if backpack then
									for _, childInst in ipairs(backpack:GetChildren()) do
										if childInst:IsA("Tool") then
											if
												(childInst.Name == targetMeleeCurrent)
												or (NormalizeMeleeName(childInst.Name) == targetMeleeCurrent)
											then
												humanoid:EquipTool(childInst)
												return
											end
										end
									end
								end
							end
						end
					end
				end)

				FunctionsHandler.LocalPlayerController:RegisterMethod(
					"ToggleAbilities",
					function(abilityName, shouldEnable)
						local char = LocalPlayer.Character
						if not char then
							return
						end
						if abilityName == "Buso" then
							local isBusoActive = (char:FindFirstChild("HasBuso") ~= nil) or LocalPlayer:HasTag("Buso")
							if shouldEnable and not isBusoActive then
								pcall(function()
									Remotes.CommF_:InvokeServer("Buso")
								end)
							elseif not shouldEnable and isBusoActive then
								pcall(function()
									Remotes.CommF_:InvokeServer("Buso")
								end)
							end
						elseif abilityName == "Observation" and shouldEnable then
							pcall(function()
								if Remotes.CommE then
									Remotes.CommE:FireServer("Ken", true)
								end
							end)
						end
					end
				)

				FunctionsHandler.LocalPlayerController:RegisterMethod("ConfigurationAbilitiesToggle", function()
					local buyHakiCfg = Config["Buy Haki"] or {}
					FunctionsHandler.LocalPlayerController.Methods.ToggleAbilities:Call(
						"Buso",
						buyHakiCfg.Buso ~= false
					)
					FunctionsHandler.LocalPlayerController.Methods.ToggleAbilities:Call(
						"Observation",
						buyHakiCfg.Observation ~= false
					)
				end)

				MeleeBuyRefreshCache = { CheckedAt = 0, Result = nil }
				MeleeBuyBusy = false
				MeleeBuyBusyAt = 0
				MeleeBuyRetryAfter = {}
				meleeBuyAttemptCounts = {}
				crossSeaMeleeCooldowns = {}
				MeleeBuyPendingName = nil
				MeleeEquipBusyName = nil

				getSharedPendingMeleeRecord = function()
					local checkPassed

					if type(getgenv) ~= "function" then
						checkPassed = _G
					else
						checkPassed = getgenv() or _G
					end

					checkPassed.BananaCatMeleeBuyPending = checkPassed.BananaCatMeleeBuyPending or {}
					return checkPassed.BananaCatMeleeBuyPending
				end

				GetMeleeBuyPending = function()
					local getSharedPendingMeleeRecordCurrent = getSharedPendingMeleeRecord()
					local meleeBuyPendingName = MeleeBuyPendingName
					if meleeBuyPendingName then
						return meleeBuyPendingName
					end
					return getSharedPendingMeleeRecordCurrent.Name
				end

				clearPendingMeleeRecord = function(primaryArg)
					local getSharedPendingMeleeRecordCurrent = getSharedPendingMeleeRecord()

					if primaryArg then
						if getSharedPendingMeleeRecordCurrent.Name == primaryArg then
							getSharedPendingMeleeRecordCurrent.Name = nil
						end

						if MeleeBuyPendingName ~= primaryArg then
							return
						end
						MeleeBuyPendingName = nil
						return
					end

					getSharedPendingMeleeRecordCurrent.Name = nil
					MeleeBuyPendingName = nil
				end

				MeleeNPCMap = {
					["Black Leg"] = "Dark Step Teacher",
					Electro = "Mad Scientist",
					["Fishman Karate"] = "Water Kung-fu Teacher",
					["Dragon Claw"] = "Sabi",
					Superhuman = "Martial Arts Master",
					["Death Step"] = "Phoeyu, the Reformed",
					["Sharkman Karate"] = "Sharkman Teacher",
					["Electric Claw"] = "Previous Hero",
					["Dragon Talon"] = "Uzoth",
					Godhuman = "Ancient Monk",
				}
				MeleeNPCSeaMap = {
					["Black Leg"] = { 1, 2, 3 },
					Electro = { 1, 2, 3 },
					["Fishman Karate"] = { 1, 2, 3 },
					["Dragon Claw"] = { 2, 3 },
					Superhuman = { 2, 3 },
					["Death Step"] = { 2, 3 },
					["Sharkman Karate"] = { 2, 3 },
					["Electric Claw"] = 3,
					["Dragon Talon"] = 3,
					Godhuman = 3,
				}
				MeleeNPCCFrameFallbacks = {
					Electro = CFrame.new(-4607.82275, 872.542297, -1667.55688),
					["Electric Claw"] = CFrame.new(-10371.6211, 331.301849, -10131.6211),
				}
				ElectricClawMansionCFrame = CFrame.new(-12547.71, 290.139008, -7487.06494)
				local collectedItemsCurrent = {
					{ "Black Leg", "Electro", "Fishman Karate" },
					{
						"Black Leg",
						"Electro",
						"Fishman Karate",
						"Dragon Claw",
						"Superhuman",
						"Death Step",
						"Sharkman Karate",
					},
					{
						"Black Leg",
						"Electro",
						"Fishman Karate",
						"Dragon Claw",
						"Superhuman",
						"Death Step",
						"Sharkman Karate",
						"Electric Claw",
						"Dragon Talon",
						"Godhuman",
					},
				}
				local collectedItemsPrimary = {}

				local function getObjectPivotCFrame(partInstance)
					if not partInstance then
						return
					end

					local ok, result = pcall(function()
						if partInstance:IsA("Model") then
							return partInstance:GetModelCFrame()
						end

						if partInstance:IsA("BasePart") then
							return partInstance.CFrame
						end
						local humanoidRootPart = partInstance:FindFirstChild("HumanoidRootPart")

						if not humanoidRootPart then
							humanoidRootPart = partInstance:FindFirstChildWhichIsA("BasePart", true)
							if not humanoidRootPart then
								return humanoidRootPart
							end
						end

						return humanoidRootPart.CFrame
					end)

					if ok then
						return result
					end
				end

				fetchElectroQuestProgress = function()
					local ok, result = pcall(function()
						return Remotes.CommF_:InvokeServer("ElectroQuestState")
					end)

					if ok then
						return result
					end
					return nil
				end

				collectElectroLightningParts = function()
					local collectedItemsFallback = {}
					local collectedItemsCached = {}

					local function addLightningPartCandidate(targetInstance, secondaryArg)
						if targetInstance then
							if targetInstance:IsA("BasePart") then
								if targetInstance.Parent then
									if collectedItemsCached[targetInstance] then
										return
									end
									collectedItemsCached[targetInstance] = true
									table.insert(
										collectedItemsFallback,
										{ Part = targetInstance, Priority = secondaryArg or 10 }
									)
									return
								end

								return
							end

							return
						end
					end

					pcall(function()
						local bonusMoments = game:GetService("ReplicatedStorage"):FindFirstChild("BonusMoments")

						if bonusMoments then
							local electricFightingTeacher = bonusMoments:FindFirstChild("Electric Fighting Teacher")

							if electricFightingTeacher then
								if getupvalues then
									local module = require(electricFightingTeacher)

									if module then
										if module.RemoteEvents then
											if module.RemoteEvents.Charge then
												for _, iteratedElement in pairs(getupvalues(module.RemoteEvents.Charge)) do
													if type(iteratedElement) == "table" then
														for k, iteratedElementCurrent in pairs(iteratedElement) do
															if typeof(k) == "Instance" then
																if k:IsA("BasePart") then
																	if k.Parent then
																		if iteratedElementCurrent == true then
																			addLightningPartCandidate(k, 1)
																		end
																	end
																end
															end
														end
													end
												end

												return
											end
										end
									end
								end
							end
						end
					end)

					local position

					if LocalPlayer.Character then
						local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

						if humanoidRootPart then
							position = humanoidRootPart.Position or Vector3.new(-4800, 950, -1800)
						else
							position = Vector3.new(-4800, 950, -1800)
						end
					else
						position = Vector3.new(-4800, 950, -1800)
					end

					table.sort(collectedItemsFallback, function(leftItem, rightItem)
						if leftItem.Priority ~= rightItem.Priority then
							return leftItem.Priority < rightItem.Priority
						end
						return (leftItem.Part.Position - position).Magnitude
							< (rightItem.Part.Position - position).Magnitude
					end)

					local collectedItemsResolved = {}

					for _, iteratedElement in ipairs(collectedItemsFallback) do
						table.insert(collectedItemsResolved, iteratedElement.Part)
					end

					return collectedItemsResolved
				end

				local function getSupportedSeasForMelee(meleeStyleName)
					local meleeNPCSeaEntry = MeleeNPCSeaMap[meleeStyleName]

					if type(meleeNPCSeaEntry) ~= "table" then
						if meleeNPCSeaEntry then
							return { meleeNPCSeaEntry }
						end
						return {}
					end

					return meleeNPCSeaEntry
				end

				local function isMeleeSoldInSea(primaryArg, secondaryArg)
					for _, iteratedElement in ipairs(getSupportedSeasForMelee(primaryArg)) do
						if iteratedElement ~= secondaryArg then
							continue
						end
						return true
					end

					return false
				end

				local function findAlternateSeaForMelee(primaryArg)
					if isMeleeSoldInSea(primaryArg, SeaIndex) then
						return
					end

					for _, iteratedElement in ipairs(getSupportedSeasForMelee(primaryArg)) do
						if iteratedElement ~= SeaIndex then
							return iteratedElement
						end
					end
				end

				local function storeMeleeTrainerCache(primaryArg, secondaryArg, tertiaryArg)
					local getObjectPivotCFrameCurrent = getObjectPivotCFrame(secondaryArg)
					if getObjectPivotCFrameCurrent then
						collectedItemsPrimary[primaryArg] = {
							Instance = secondaryArg,
							CFrame = getObjectPivotCFrameCurrent,
							Sea = SeaIndex,
							Source = tertiaryArg,
							UpdatedAt = os.clock(),
						}
						return getObjectPivotCFrameCurrent, secondaryArg
					end
				end

				local function readMeleeTrainerCache(primaryArg, secondaryArg)
					local partInstance = collectedItemsPrimary[primaryArg]

					if partInstance then
						if typeof(partInstance) ~= "Instance" then
							if type(partInstance) ~= "table" then
								return
							end

							if partInstance.Instance then
								local cFrame = getObjectPivotCFrame(partInstance.Instance)

								if cFrame then
									partInstance.CFrame = cFrame
									partInstance.Sea = partInstance.Sea or SeaIndex
									partInstance.UpdatedAt = os.clock()
									return cFrame, partInstance.Instance
								end
							end

							if partInstance.CFrame then
								if not secondaryArg then
									return partInstance.CFrame, partInstance.Instance
								end

								if partInstance.Sea == SeaIndex then
									return partInstance.CFrame, partInstance.Instance
								end
							end

							return
						end

						local getObjectPivotCFrameCurrent = getObjectPivotCFrame(partInstance)
						if getObjectPivotCFrameCurrent then
							collectedItemsPrimary[primaryArg] = {
								Instance = partInstance,
								CFrame = getObjectPivotCFrameCurrent,
								Sea = SeaIndex,
								Source = "legacy",
								UpdatedAt = os.clock(),
							}
							return getObjectPivotCFrameCurrent, partInstance
						end
						return
					end
				end

				local function locateLiveMeleeTrainerNpc(meleeStyleName, secondaryArg)
					local meleeNPCEntry = MeleeNPCMap[meleeStyleName]

					if meleeNPCEntry then
						local npcsFolder = workspace:FindFirstChild("NPCs")
						local storeMeleeTrainerCacheCurrent, storeMeleeTrainerCacheTarget = storeMeleeTrainerCache(
							meleeStyleName,
							npcsFolder and npcsFolder:FindFirstChild(meleeNPCEntry),
							"workspace"
						)
						if storeMeleeTrainerCacheCurrent then
							return storeMeleeTrainerCacheCurrent, storeMeleeTrainerCacheTarget
						end

						if secondaryArg then
							local npcsFolderCurrent = game:GetService("ReplicatedStorage"):FindFirstChild("NPCs")
							local resolvedCondition

							if npcsFolderCurrent then
								resolvedCondition = npcsFolderCurrent:FindFirstChild(meleeNPCEntry)
									or game:GetService("ReplicatedStorage"):FindFirstChild(meleeNPCEntry)
							else
								resolvedCondition = game:GetService("ReplicatedStorage"):FindFirstChild(meleeNPCEntry)
							end

							local storeMeleeTrainerCachePrimary, storeMeleeTrainerCacheFallback =
								storeMeleeTrainerCache(meleeStyleName, resolvedCondition, "replicated")
							if storeMeleeTrainerCachePrimary then
								return storeMeleeTrainerCachePrimary, storeMeleeTrainerCacheFallback
							end
						end

						return
					end
				end

				local function isMeleeTrainerKnownInSea(primaryArg)
					if locateLiveMeleeTrainerNpc(primaryArg, isMeleeSoldInSea(primaryArg, SeaIndex)) then
						return true
					end

					if readMeleeTrainerCache(primaryArg, true) then
						return true
					end
					return false
				end

				resolveMeleeTrainerCFrame = function(meleeStyleName)
					local isMeleeSoldInSeaCurrent = isMeleeSoldInSea(meleeStyleName, SeaIndex)
					local locateLiveMeleeTrainerNpcCurrent, locateLiveMeleeTrainerNpcTarget =
						locateLiveMeleeTrainerNpc(meleeStyleName, isMeleeSoldInSeaCurrent)
					if locateLiveMeleeTrainerNpcCurrent then
						return locateLiveMeleeTrainerNpcCurrent, locateLiveMeleeTrainerNpcTarget
					end
					local readMeleeTrainerCacheCurrent, readMeleeTrainerCacheTarget =
						readMeleeTrainerCache(meleeStyleName, true)
					if readMeleeTrainerCacheCurrent then
						return readMeleeTrainerCacheCurrent, readMeleeTrainerCacheTarget
					end

					if isMeleeSoldInSeaCurrent then
						if meleeStyleName == "Electro" then
							if SeaIndex ~= 1 then
								return
							end
						end

						return MeleeNPCCFrameFallbacks[meleeStyleName], readMeleeTrainerCacheTarget
					end
				end

				scanWorldOriginLocations = function()
					local worldOrigin = workspace:FindFirstChild("_WorldOrigin")

					if worldOrigin then
						worldOrigin = worldOrigin:FindFirstChild("Locations")
						worldOrigin = worldOrigin and worldOrigin:FindFirstChild("Mansion")
					end

					local getObjectPivotCFrameCurrent = getObjectPivotCFrame(worldOrigin)
					if getObjectPivotCFrameCurrent then
						return getObjectPivotCFrameCurrent
					end
					local map = workspace:FindFirstChild("Map")

					if map then
						map = map:FindFirstChild("Turtle")

						if map then
							map = map:FindFirstChild("IslandModel")
							map = map and map:FindFirstChild("Mansion")
						end
					end

					local getObjectPivotCFrameTarget = getObjectPivotCFrame(map)
					if getObjectPivotCFrameTarget then
						return getObjectPivotCFrameTarget
					end
					return ElectricClawMansionCFrame
				end

				local function refreshMeleeTrainerLocations()
					for k, trainerNpcName in pairs(MeleeNPCMap) do
						local npcsFolder = workspace:FindFirstChild("NPCs")
							and workspace.NPCs:FindFirstChild(trainerNpcName)
						local resolvedCondition

						if game.ReplicatedStorage:FindFirstChild("NPCs") then
							resolvedCondition = game.ReplicatedStorage.NPCs:FindFirstChild(trainerNpcName)
								or game.ReplicatedStorage:FindFirstChild(trainerNpcName)
						else
							resolvedCondition = game.ReplicatedStorage:FindFirstChild(trainerNpcName)
						end

						storeMeleeTrainerCache(k, resolvedCondition, "replicated")
						storeMeleeTrainerCache(k, npcsFolder, "workspace")
					end
				end

				local npcsFolderTarget = game.ReplicatedStorage:FindFirstChild("NPCs")
				local npcsFolderPrimary = workspace:FindFirstChild("NPCs")

				if npcsFolderTarget then
					npcsFolderTarget.ChildAdded:Connect(function(child)
						for k, trainerNpcName in pairs(MeleeNPCMap) do
							if child.Name == trainerNpcName then
								storeMeleeTrainerCache(k, child, "replicated")
							end
						end
					end)

					if npcsFolderPrimary then
						npcsFolderPrimary.ChildAdded:Connect(function(child)
							for k, trainerNpcName in pairs(MeleeNPCMap) do
								if child.Name == trainerNpcName then
									storeMeleeTrainerCache(k, child, "workspace")
								end
							end
						end)
					end
				elseif npcsFolderPrimary then
					npcsFolderPrimary.ChildAdded:Connect(function(child)
						for k, trainerNpcName in pairs(MeleeNPCMap) do
							if child.Name == trainerNpcName then
								storeMeleeTrainerCache(k, child, "workspace")
							end
						end
					end)
				end

				refreshMeleeTrainerLocations()

				local function resolveCrossSeaMeleeDestination(meleeStyleName)
					local isCheckPassed = meleeStyleName == "Death Step"
					local clockStamp, crossSeaMeleeCooldownEntry

					if isCheckPassed then
						if SeaIndex ~= 2 then
							clockStamp = os.clock()
							crossSeaMeleeCooldownEntry = crossSeaMeleeCooldowns[meleeStyleName]

							if crossSeaMeleeCooldownEntry then
								if clockStamp < crossSeaMeleeCooldownEntry then
									return true
								end
							elseif clockStamp < 0 then
								return true
							end

							crossSeaMeleeCooldowns[meleeStyleName] = os.clock() + 10
						elseif isMeleeTrainerKnownInSea(meleeStyleName) then
							return false
						end
					else
						isCheckPassed = meleeStyleName == "Sharkman Karate"

						if isCheckPassed then
							if SeaIndex ~= 2 then
								clockStamp = os.clock()
								crossSeaMeleeCooldownEntry = crossSeaMeleeCooldowns[meleeStyleName]

								if crossSeaMeleeCooldownEntry then
									if clockStamp < crossSeaMeleeCooldownEntry then
										return true
									end
								elseif clockStamp < 0 then
									return true
								end

								crossSeaMeleeCooldowns[meleeStyleName] = os.clock() + 10
							elseif isMeleeTrainerKnownInSea(meleeStyleName) then
								return false
							end
						elseif isMeleeTrainerKnownInSea(meleeStyleName) then
							return false
						end
					end

					local findAlternateSeaForMeleeCurrent = findAlternateSeaForMelee(meleeStyleName)
					local seaIndexeEntry

					if isCheckPassed then
						if SeaIndex ~= 2 then
							findAlternateSeaForMeleeCurrent = 2

							if findAlternateSeaForMeleeCurrent ~= SeaIndex then
								seaIndexeEntry = SeaIndexes[findAlternateSeaForMeleeCurrent]

								if seaIndexeEntry then
									SetTask(
										"MainTask",
										"Sea Travel | Melee "
											.. (
												tostring(meleeStyleName)
												.. (" | Travelling to Sea " .. findAlternateSeaForMeleeCurrent)
											)
									)
									Remotes.CommF_:InvokeServer("Travel" .. seaIndexeEntry)
									return true
								end

								return false
							end

							return false
						end

						if findAlternateSeaForMeleeCurrent then
							if findAlternateSeaForMeleeCurrent ~= SeaIndex then
								seaIndexeEntry = SeaIndexes[findAlternateSeaForMeleeCurrent]

								if seaIndexeEntry then
									SetTask(
										"MainTask",
										"Sea Travel | Melee "
											.. (
												tostring(meleeStyleName)
												.. (" | Travelling to Sea " .. findAlternateSeaForMeleeCurrent)
											)
									)
									Remotes.CommF_:InvokeServer("Travel" .. seaIndexeEntry)
									return true
								end

								return false
							end

							return false
						end
					elseif findAlternateSeaForMeleeCurrent then
						if findAlternateSeaForMeleeCurrent ~= SeaIndex then
							seaIndexeEntry = SeaIndexes[findAlternateSeaForMeleeCurrent]

							if seaIndexeEntry then
								SetTask(
									"MainTask",
									"Sea Travel | Melee "
										.. (
											tostring(meleeStyleName)
											.. (" | Travelling to Sea " .. findAlternateSeaForMeleeCurrent)
										)
								)
								Remotes.CommF_:InvokeServer("Travel" .. seaIndexeEntry)
								return true
							end

							return false
						end

						return false
					end

					return false
				end

				hasOwnedOrMasteredMelee = function(childName)
					local initialCounterCurrent = tonumber(ScriptStorage.Melees[childName]) or 0
					local childNameCurrent

					if NormalizeMeleeName then
						childNameCurrent = NormalizeMeleeName(childName) or childName
					else
						childNameCurrent = childName
					end

					local backpack = LocalPlayer:FindFirstChild("Backpack")
					local meleesOwnedEntry = ScriptStorage.MeleesOwned[childName]

					if not meleesOwnedEntry then
						meleesOwnedEntry = ScriptStorage.MeleesOwned[childNameCurrent]

						if not meleesOwnedEntry then
							meleesOwnedEntry = initialCounterCurrent > 0

							if not meleesOwnedEntry then
								meleesOwnedEntry = ScriptStorage.Tools[childName]

								if not meleesOwnedEntry then
									if backpack then
										meleesOwnedEntry = backpack:FindFirstChild(childName)

										if not meleesOwnedEntry then
											meleesOwnedEntry = backpack:FindFirstChild(childNameCurrent)

											if not meleesOwnedEntry then
												meleesOwnedEntry = LocalPlayer.Character

												if meleesOwnedEntry then
													meleesOwnedEntry = LocalPlayer.Character:FindFirstChild(childName)
													if not meleesOwnedEntry then
														local character = LocalPlayer.Character
														return (character:FindFirstChild(childNameCurrent))
													end
												end
											end
										end
									else
										meleesOwnedEntry = LocalPlayer.Character

										if meleesOwnedEntry then
											meleesOwnedEntry = LocalPlayer.Character:FindFirstChild(childName)
											if not meleesOwnedEntry then
												return (LocalPlayer.Character:FindFirstChild(childNameCurrent))
											end
										end
									end
								end
							end
						end
					end

					return meleesOwnedEntry
				end

				local function hasEnoughCurrencyForMelee(meleeStyleName)
					local meleeEntry = MeleePrices[meleeStyleName]

					if meleeEntry then
						if meleeEntry.Price then
							for k, requiredAmount in pairs(meleeEntry.Price) do
								local playerDataEntry = ScriptStorage.PlayerData[k]

								if playerDataEntry then
									if playerDataEntry < requiredAmount then
										return false
									end
									continue
								end

								if requiredAmount > 0 then
									return false
								end
							end

							return true
						end

						return false
					end

					return false
				end

				local function findNextMeleeInCurrentSea()
					local collectedItemsFallback = collectedItemsCurrent[SeaIndex] or {}

					for _, meleeStyleName in ipairs(collectedItemsFallback) do
						local meleeEntry = MeleePrices[meleeStyleName]
						local initialCounterCurrent = tonumber(ScriptStorage.Melees[meleeStyleName]) or 0

						if hasOwnedOrMasteredMelee(meleeStyleName) then
							if meleeEntry then
								if initialCounterCurrent < meleeEntry.NextLevelRequirement then
									return meleeStyleName, "Mastery", initialCounterCurrent, meleeEntry
								end
								continue
							end

							continue
						end

						return meleeStyleName, "Buy", initialCounterCurrent, meleeEntry
					end

					return nil, "Complete"
				end

				chooseNextMeleeAction = function()
					local findNextMeleeInCurrentSeaCurrent, findNextMeleeInCurrentSeaTarget =
						findNextMeleeInCurrentSea()

					if findNextMeleeInCurrentSeaTarget == "Buy" then
						if findNextMeleeInCurrentSeaCurrent then
							return findNextMeleeInCurrentSeaCurrent
						end
					end

					return nil
				end

				local function hasRequiredGodhumanMaterials()
					for k, materialReq in pairs(GodhumanMaterials) do
						if (ScriptStorage.Backpack[k] or { Count = 0 }).Count < materialReq[1] then
							return false
						end
					end

					return true
				end

				local function canPurchaseMeleeNow(meleeStyleName)
					local meleeEntry = MeleePrices[meleeStyleName]

					if meleeEntry then
						if hasEnoughCurrencyForMelee(meleeStyleName) then
							if MeleeBuyRetryAfter[meleeStyleName] then
								local meleeBuyRetryAfterEntry = MeleeBuyRetryAfter[meleeStyleName]
								if os.clock() < meleeBuyRetryAfterEntry then
									return false
								end
							end

							if meleeStyleName == "Dragon Talon" then
								if not ScriptStorage.Tools["Fire Essence"] then
									if not IsFireEssenceGave then
										return false
									end
								end
							end

							if meleeStyleName == "Godhuman" then
								if GodHumanFlag then
									if not hasRequiredGodhumanMaterials() then
										return false
									end
								end
							end

							local isCheckPassed = meleeStyleName == "Electro"

							if not isCheckPassed then
								local requirements = meleeEntry.Requirements
								isCheckPassed = not requirements
								if requirements then
									return (meleeEntry.Requirements())
								end
							end

							return isCheckPassed
						end

						return false
					end

					return false
				end

				local function markMeleePurchaseSucceeded(meleeStyleName)
					ScriptStorage.MeleesOwned[meleeStyleName] = true
					ScriptStorage.Melees[meleeStyleName] = tonumber(ScriptStorage.Melees[meleeStyleName]) or 0
					clearPendingMeleeRecord(meleeStyleName)
					if meleeStyleName ~= "Dragon Talon" then
						return
					end
					IsFireEssenceGave = true
				end

				local configRecord = {
					["Death Step"] = true,
					["Sharkman Karate"] = true,
					["Electric Claw"] = true,
					["Dragon Talon"] = true,
					Godhuman = true,
				}

				local function requiresMeleeUnlockPuzzle(meleeStyleName)
					if meleeStyleName == "Electro" then
						if not HasLightningBolt(true) then
							if not hasOwnedOrMasteredMelee("Electro") then
								return true
							end
						end
					end

					return configRecord[meleeStyleName] == true
				end

				local function recordPendingMeleePurchase(result)
					if result then
						if hasOwnedOrMasteredMelee(result) then
							return
						end
						MeleeBuyPendingName = result
						local getSharedPendingMeleeRecordCurrent = getSharedPendingMeleeRecord()
						getSharedPendingMeleeRecordCurrent.Name = result
						getSharedPendingMeleeRecordCurrent.At = os.clock()
						MeleeBuyRefreshCache.CheckedAt = 0
						MeleeBuyRefreshCache.Result = result
						return
					end
				end

				local function handleMeleeUnlockPrerequisite(meleeStyleName)
					if requiresMeleeUnlockPuzzle(meleeStyleName) then
						if meleeStyleName ~= "Electro" then
							if meleeStyleName ~= "Sharkman Karate" then
								if meleeStyleName ~= "Death Step" then
									if meleeStyleName ~= "Electric Claw" then
										if meleeStyleName ~= "Dragon Talon" then
											if meleeStyleName ~= "Godhuman" then
												return false
											end

											if hasRequiredGodhumanMaterials() then
												return false
											end
											GodHumanFlag = true
											SetTask("MainTask", "Godhuman - Checking materials")
											return true
										end

										if SeaIndex ~= 3 then
											return false
										end

										if ScriptStorage.Tools["Fire Essence"] then
											if not IsFireEssenceGave then
												FunctionsHandler.UtillyItemsActivitation:Set(
													"CurrentProgressLevel",
													"Uzoth Essence"
												)
												SetTask("MainTask", "Dragon Talon - Giving Fire Essence to Uzoth")
												if FunctionsHandler.UtillyItemsActivitation.Methods.Start then
													FunctionsHandler.UtillyItemsActivitation.Methods.Start:Call()
													return true
												end
												return true
											end
										end

										return false
									end

									if SeaIndex ~= 3 then
										return false
									end

									local ok, result = pcall(function()
										return Remotes.CommF_:InvokeServer("BuyElectricClaw", true)
									end)

									if ok then
										if result ~= 4 then
											if result ~= nil then
												return false
											end
										end
									end

									FunctionsHandler.UtillyItemsActivitation:Set(
										"CurrentProgressLevel",
										"Previous Hero"
									)
									SetTask("MainTask", "Electric Claw - Queued Previous Hero")
									if FunctionsHandler.UtillyItemsActivitation.Methods.Start then
										FunctionsHandler.UtillyItemsActivitation.Methods.Start:Call()
										return true
									end
									return true
								end
							end

							if SeaIndex ~= 2 then
								return false
							end
							local toolName = ((meleeStyleName ~= "Sharkman Karate") and "Library Key") or "Water Key"
							local clockStamp = os.clock()
							local meleeBuyAttemptCountEntry = meleeBuyAttemptCounts[meleeStyleName]

							if meleeBuyAttemptCountEntry then
								if clockStamp < meleeBuyAttemptCountEntry then
									return true
								end
							elseif clockStamp < 0 then
								return true
							end

							local ok, result = pcall(function()
								if meleeStyleName ~= "Sharkman Karate" then
									return Remotes.CommF_:InvokeServer("OpenLibrary")
								end
								return Remotes.CommF_:InvokeServer("BuySharkmanKarate", true)
							end)

							if ok then
								if meleeStyleName ~= "Sharkman Karate" then
									if result == true then
										return false
									end

									if result then
										SetTask("SideTask", "Melee | Waiting for " .. (toolName .. " status"))
										meleeBuyAttemptCounts[meleeStyleName] = os.clock() + 2
										return true
									end
								elseif typeof(result) ~= "string" then
									return false
								end

								if ScriptStorage.Tools[toolName] then
									FunctionsHandler.UtillyItemsActivitation:Set("CurrentProgressLevel", toolName)

									if FunctionsHandler.UtillyItemsActivitation.Methods.Start then
										FunctionsHandler.UtillyItemsActivitation.Methods.Start:Call()
									end

									meleeBuyAttemptCounts[meleeStyleName] = os.clock() + 1
									return true
								end

								local enemyName = ((meleeStyleName ~= "Sharkman Karate") and "Awakened Ice Admiral")
									or "Tide Keeper"
								local enemieEntry = ScriptStorage.Enemies[enemyName]

								if enemieEntry then
									local humanoid = enemieEntry:FindFirstChild("Humanoid")

									if humanoid then
										if humanoid.Health > 0 then
											SetTask(
												"SideTask",
												"Melee | Waiting for " .. (toolName .. (" from " .. enemyName))
											)
											FunctionsHandler.BossesTask.Methods.Start:Call(enemieEntry)
											meleeBuyAttemptCounts[meleeStyleName] = os.clock() + 1
											return true
										end
									end
								end

								SetTask("MainTask", "Melee | Hopping for " .. (enemyName .. (" to get " .. toolName)))
								meleeBuyAttemptCounts[meleeStyleName] = os.clock() + 5
								Hop(8)
								return true
							end

							SetTask("SideTask", "Melee | Checking " .. (toolName .. (" for " .. meleeStyleName)))
							meleeBuyAttemptCounts[meleeStyleName] = os.clock() + 2
							return true
						end

						if not HasLightningBolt(true) then
							if not hasOwnedOrMasteredMelee("Electro") then
								if SeaIndex ~= 1 then
									SetTask("MainTask", "Sea Travel | Electro Quest | Travelling to Sea 1")
									Remotes.CommF_:InvokeServer("TravelMain")
									return true
								end

								FunctionsHandler.UtillyItemsActivitation:Set(
									"CurrentProgressLevel",
									"Mad Scientist Task"
								)
								SetTask("MainTask", "Electro - Queued Mad Scientist Task")
								if FunctionsHandler.UtillyItemsActivitation.Methods.Start then
									FunctionsHandler.UtillyItemsActivitation.Methods.Start:Call()
									return true
								end
								return true
							end
						end

						return false
					end

					return false
				end

				local function getReadyToBuyMeleeName()
					local meleeStyleName = chooseNextMeleeAction()
					DragonTalonNeedsFireEssence = (meleeStyleName == "Dragon Talon") and not IsFireEssenceGave

					if canPurchaseMeleeNow(meleeStyleName) then
						if meleeStyleName then
							return meleeStyleName
						end
					end

					return nil
				end

				ShouldPreemptForMeleeBuy = function()
					if FunctionsHandler.RaidController then
						if FunctionsHandler.RaidController.Initalized then
							if FunctionsHandler.RaidController.Methods.IsLocked then
								if FunctionsHandler.RaidController.Methods.IsLocked:Call() then
									return false
								end
							end
						end
					end

					if MeleeEquipBusyName then
						return true
					end
					local getReadyToBuyMeleeNameCurrent = getReadyToBuyMeleeName()

					if getReadyToBuyMeleeNameCurrent then
						if GetMeleeBuyPending() ~= getReadyToBuyMeleeNameCurrent then
							clearPendingMeleeRecord()
							recordPendingMeleePurchase(getReadyToBuyMeleeNameCurrent)
							return true
						end

						return true
					end

					clearPendingMeleeRecord()
					return false
				end

				local function invokeMeleeBuyRemote(meleeStyleName)
					local meleeEntry = MeleePrices[meleeStyleName]

					if meleeEntry then
						if meleeEntry.Buy then
							if hasOwnedOrMasteredMelee(meleeStyleName) then
								return hasOwnedOrMasteredMelee(meleeStyleName)
							end
							local ok, result

							if meleeStyleName ~= "Electro" then
								if meleeStyleName == "Godhuman" then
									pcall(meleeEntry.Buy, true)
								end
								ok, result = pcall(meleeEntry.Buy)
								task.wait(0.4)
								SyncLiveMeleeTools()
								if hasOwnedOrMasteredMelee(meleeStyleName) then
									markMeleePurchaseSucceeded(meleeStyleName)
									return true, result
								end
								return false, result
							end

							local fetchElectroQuestProgressCurrent = fetchElectroQuestProgress()

							if fetchElectroQuestProgressCurrent ~= 4 then
								if fetchElectroQuestProgressCurrent == 5 then
									markMeleePurchaseSucceeded(meleeStyleName)
									return true, fetchElectroQuestProgressCurrent
								end

								if fetchElectroQuestProgressCurrent ~= 3 then
									if fetchElectroQuestProgressCurrent ~= 2 then
										return false, fetchElectroQuestProgressCurrent
									end
									ok, result = pcall(meleeEntry.Buy)
									task.wait(0.4)

									if meleeStyleName == "Electro" then
										resetElectroQuestCache()
										pcall(RefreshInventory)
									end

									SyncLiveMeleeTools()
									if hasOwnedOrMasteredMelee(meleeStyleName) then
										markMeleePurchaseSucceeded(meleeStyleName)
										return true, result
									end

									if meleeStyleName == "Electro" then
										if ok then
											if result == 1 then
												markMeleePurchaseSucceeded(meleeStyleName)
												return true, result
											end
										end
									end

									return false, result
								end

								SetTask("MainTask", "Electro | Delivering Lightning Bolt")

								local callSucceeded, executionResult = pcall(function()
									return Remotes.CommF_:InvokeServer("DeliverLightningBolt")
								end)

								if callSucceeded then
									if executionResult ~= 1 then
										if fetchElectroQuestProgress() ~= 2 then
											return false, executionResult
										end
									end
								elseif fetchElectroQuestProgress() ~= 2 then
									return false, executionResult
								end

								ok, result = pcall(meleeEntry.Buy)
								task.wait(0.4)

								if meleeStyleName == "Electro" then
									resetElectroQuestCache()
									pcall(RefreshInventory)
								end

								SyncLiveMeleeTools()
								if hasOwnedOrMasteredMelee(meleeStyleName) then
									markMeleePurchaseSucceeded(meleeStyleName)
									return true, result
								end

								if meleeStyleName == "Electro" then
									if ok then
										if result == 1 then
											markMeleePurchaseSucceeded(meleeStyleName)
											return true, result
										end
									end
								end

								return false, result
							end

							markMeleePurchaseSucceeded(meleeStyleName)
							return true, fetchElectroQuestProgressCurrent
						end

						return hasOwnedOrMasteredMelee(meleeStyleName)
					end

					return hasOwnedOrMasteredMelee(meleeStyleName)
				end

				FunctionsHandler.MeleeBuyController:RegisterMethod("Refresh", function()
					if CurrentTask ~= "BossesTask" then
						if CurrentTask ~= "SpecialBossesTask" then
							if FunctionsHandler.RaidController then
								if FunctionsHandler.RaidController.Initalized then
									if FunctionsHandler.RaidController.Methods.IsLocked then
										if FunctionsHandler.RaidController.Methods.IsLocked:Call() then
											return
										end
									end
								end
							end

							SyncLiveMeleeTools()
							local meleeBuyPending = GetMeleeBuyPending()

							if meleeBuyPending then
								if hasOwnedOrMasteredMelee(meleeBuyPending) then
									clearPendingMeleeRecord(meleeBuyPending)
									meleeBuyPending = nil
								end
							end

							if MeleeBuyBusy then
								return meleeBuyPending
							end
							local result = getReadyToBuyMeleeName()

							if meleeBuyPending then
								if meleeBuyPending ~= result then
									clearPendingMeleeRecord(meleeBuyPending)

									if result then
										recordPendingMeleePurchase(result)
										MeleeBuyRefreshCache.Result = result
										return result
									end
								elseif result then
									recordPendingMeleePurchase(result)
									MeleeBuyRefreshCache.Result = result
									return result
								end
							elseif result then
								recordPendingMeleePurchase(result)
								MeleeBuyRefreshCache.Result = result
								return result
							end

							return
						end

						return
					end
				end)

				local initialCounterTarget = 0

				FunctionsHandler.CannonBuyController:RegisterMethod("Refresh", function()
					if SeaIndex ~= 2 then
						return
					end

					if CurrentTask ~= "BossesTask" then
						if CurrentTask ~= "SpecialBossesTask" then
							local playerLevelNum = tonumber(ScriptStorage.PlayerData.Level)

							if playerLevelNum then
								if playerLevelNum < 800 then
									return
								end
								local playerBeliNum = tonumber(ScriptStorage.PlayerData.Beli)

								if playerBeliNum then
									if playerBeliNum < 100000 then
										return
									end

									if ScriptStorage.Backpack.Cannon then
										return
									end

									if ScriptStorage.Tools.Cannon then
										return
									end

									if os.clock() < initialCounterTarget then
										return
									end
									return "Cannon"
								end

								return
							end

							return
						end

						return
					end
				end)

				FunctionsHandler.CannonBuyController:RegisterMethod("Start", function(primaryArg)
					if primaryArg ~= "Cannon" then
						return
					end

					if SeaIndex ~= 2 then
						return
					end
					local playerLevelNum = tonumber(ScriptStorage.PlayerData.Level)

					if playerLevelNum then
						if playerLevelNum < 800 then
							return
						end
						local playerBeliNum = tonumber(ScriptStorage.PlayerData.Beli)

						if playerBeliNum then
							if playerBeliNum < 100000 then
								return
							end

							if ScriptStorage.Backpack.Cannon then
								return
							end

							if ScriptStorage.Tools.Cannon then
								return
							end
							initialCounterTarget = os.clock() + 60
							SetTask("MainTask", "Auto Weapon Buy | Cannon")

							pcall(function()
								Remotes.CommF_:InvokeServer("BuyItem", "Cannon")
							end)

							task.wait(0.4)
							pcall(RefreshInventory)
							if ScriptStorage.Backpack.Cannon then
								SetTask("MainTask", "Auto Weapon Buy | Cannon | Done")
								return
							end

							if ScriptStorage.Tools.Cannon then
								SetTask("MainTask", "Auto Weapon Buy | Cannon | Done")
								return
							end
							SetTask("SideTask", "Cannon | Buy not confirmed; retrying later")
							return
						end

						return
					end
				end)

				FunctionsHandler.MeleeBuyController:RegisterMethod("Start", function(primaryArg)
					local meleeStyleName, measuredValue, setTask, scopedValue, clockStamp, meleeBuyBusyAt, finishMeleePurchaseAttempt, fetchElectroQuestProgressCurrent, targetLocation, initialCounterCurrent, clockStampCurrent, targetDistance, invokeMeleeBuyRemoteCurrent, fetchElectroQuestProgressTarget, checkPassed, setTaskCurrent, scopedValueCurrent, meleeBuyPending
					meleeStyleName = primaryArg

					if CurrentTask ~= "BossesTask" then
						if CurrentTask ~= "SpecialBossesTask" then
							if
								not meleeStyleName
								or (
									(meleeStyleName ~= chooseNextMeleeAction())
									or not canPurchaseMeleeNow(meleeStyleName)
								)
							then
								clearPendingMeleeRecord()
							else
								recordPendingMeleePurchase(meleeStyleName)

								if FunctionsHandler.RaidController then
									if FunctionsHandler.RaidController.Initalized then
										if FunctionsHandler.RaidController.Methods.IsLocked then
											if FunctionsHandler.RaidController.Methods.IsLocked:Call() then
												SetTask(
													"SideTask",
													"Melee | Waiting raid before buy " .. tostring(meleeStyleName)
												)
												return
											end
										end
									end
								end

								if MeleeBuyBusy then
									clockStamp = os.clock()
									meleeBuyBusyAt = MeleeBuyBusyAt

									if not meleeBuyBusyAt then
										meleeBuyBusyAt = 0
									end

									if (clockStamp - meleeBuyBusyAt) < 20 then
										setTaskCurrent = SetTask
										scopedValueCurrent = tostring
										meleeBuyPending = GetMeleeBuyPending()

										if not meleeBuyPending then
											meleeBuyPending = meleeStyleName
										end

										setTaskCurrent(
											"MainTask",
											"Auto Melee Buy | Waiting for " .. scopedValueCurrent(meleeBuyPending)
										)
										return
									end
								end

								MeleeBuyBusy = true
								MeleeBuyBusyAt = os.clock()

								finishMeleePurchaseAttempt = function()
									MeleeBuyBusy = false
									MeleeBuyRefreshCache.CheckedAt = 0
									MeleeBuyRefreshCache.Result = GetMeleeBuyPending()
									RefreshMelees()
								end

								SyncLiveMeleeTools()

								if hasOwnedOrMasteredMelee(meleeStyleName) then
									markMeleePurchaseSucceeded(meleeStyleName)
								else
									if meleeStyleName == "Electro" then
										fetchElectroQuestProgressCurrent = fetchElectroQuestProgress()

										if
											not (
												(fetchElectroQuestProgressCurrent ~= 4)
												and (fetchElectroQuestProgressCurrent ~= 5)
											)
										then
											markMeleePurchaseSucceeded(meleeStyleName)
											finishMeleePurchaseAttempt()
											return
										end
									end

									if not resolveCrossSeaMeleeDestination(meleeStyleName) then
										if not handleMeleeUnlockPrerequisite(meleeStyleName) then
											if MeleeNPCMap[meleeStyleName] then
												targetLocation = resolveMeleeTrainerCFrame(meleeStyleName)

												if not targetLocation then
													refreshMeleeTrainerLocations()
													targetLocation = resolveMeleeTrainerCFrame(meleeStyleName)

													if not targetLocation then
														local combinedText = "MeleeBuy: NPC '"
															.. (
																tostring(MeleeNPCMap[meleeStyleName])
																.. (
																	"' for "
																	.. (
																		tostring(meleeStyleName)
																		.. " not found (workspace.NPCs nor ReplicatedStorage.NPCs)"
																	)
																)
															)
														Report(combinedText)
														SetTask("SideTask", combinedText)

														if meleeStyleName == "Electro" then
															MeleeBuyRetryAfter[meleeStyleName] = os.clock() + 5
														end

														finishMeleePurchaseAttempt()
														return
													end
												end

												SetTask(
													"MainTask",
													"Auto Melee Buy | "
														.. (
															meleeStyleName
															.. (" | Travelling to " .. MeleeNPCMap[meleeStyleName])
														)
												)

												if meleeStyleName ~= "Electro" then
													initialCounterCurrent = 55
												else
													initialCounterCurrent = 8
												end

												TweenController.Create(targetLocation + Vector3.new(0, 5, 3))
												clockStampCurrent = os.clock()

												while
													(initialCounterCurrent < CaculateDistance(targetLocation))
													and ((os.clock() - clockStampCurrent) < 25)
												do
													if FunctionsHandler.RaidController then
														if FunctionsHandler.RaidController.Methods.IsLocked then
															if
																FunctionsHandler.RaidController.Methods.IsLocked:Call()
															then
																finishMeleePurchaseAttempt()
																return
															end
														end
													end

													if not TweenController.Playing then
														if initialCounterCurrent < CaculateDistance(targetLocation) then
															TweenController.Create(
																targetLocation + Vector3.new(0, 5, 3)
															)
														end
													end

													task.wait(0.1)
												end

												targetDistance = CaculateDistance(targetLocation)

												if meleeStyleName ~= "Electro" then
													if targetDistance > 60 then
														finishMeleePurchaseAttempt()
														return
													end
												elseif targetDistance > 8 then
													finishMeleePurchaseAttempt()
													return
												end

												SetTask(
													"MainTask",
													"Auto Melee Buy | " .. (meleeStyleName .. " | Firing Buy")
												)
												local invokeMeleeBuyRemoteTarget
												invokeMeleeBuyRemoteTarget, invokeMeleeBuyRemoteCurrent =
													invokeMeleeBuyRemote(meleeStyleName)

												if invokeMeleeBuyRemoteTarget then
													SetTask(
														"MainTask",
														"Auto Melee Buy | " .. (meleeStyleName .. " | Done")
													)

													pcall(function()
														FunctionsHandler.MeleesController.Methods.Start:Call()
													end)
												else
													warn(
														"failed",
														meleeStyleName,
														"response=",
														invokeMeleeBuyRemoteCurrent
													)

													resetElectroQuestCache()
													pcall(RefreshInventory)
													fetchElectroQuestProgressTarget = fetchElectroQuestProgress()
													electroQuestCheckTick = os.clock()
													cachedElectroQuestReady = (fetchElectroQuestProgressTarget == 2)
														or (fetchElectroQuestProgressTarget == 3)
														or (fetchElectroQuestProgressTarget == 4)

													if
														fetchElectroQuestProgressTarget ~= 4
														and fetchElectroQuestProgressTarget ~= 5
													then
														if cachedElectroQuestReady or HasLightningBolt(false) then
															SetTask(
																"SideTask",
																"Electro | Buy rejected; cooldown before retry"
															)
															MeleeBuyRetryAfter[meleeStyleName] = os.clock() + 60
														else
															FunctionsHandler.UtillyItemsActivitation:Set(
																"CurrentProgressLevel",
																"Mad Scientist Task"
															)
															SetTask(
																"SideTask",
																"Electro | Buy rejected; returning to Lightning Bolt quest"
															)
															MeleeBuyRetryAfter[meleeStyleName] = os.clock() + 3
														end
													else
														markMeleePurchaseSucceeded(meleeStyleName)
													end

													clearPendingMeleeRecord(meleeStyleName)
												end
											else
												local combinedText = "MeleeBuy: no NPC map for "
													.. tostring(meleeStyleName)
												Report(combinedText)
												SetTask("SideTask", combinedText)
											end
										end
									end
								end

								finishMeleePurchaseAttempt()
							end

							return
						end
					end

					setTask = SetTask
					scopedValue = tostring

					if not meleeStyleName then
						meleeStyleName = ""
					end

					setTask("SideTask", "Melee | Waiting for boss before buying " .. scopedValue(meleeStyleName))
					return
				end)

				FunctionsHandler.MeleesController:RegisterMethod("Start", function()
					if FunctionsHandler.RaidController then
						if FunctionsHandler.RaidController.Initalized then
							if FunctionsHandler.RaidController.Methods.IsLocked then
								if FunctionsHandler.RaidController.Methods.IsLocked:Call() then
									return
								end
							end
						end
					end

					SyncLiveMeleeTools()

					if ScriptStorage.MeleesLiveScanDone then
						local function getEquippedMeleeToolInfo()
							local character = LocalPlayer.Character
							local tool

							if character then
								tool = character:FindFirstChildOfClass("Tool")

								if tool then
									if tool.ToolTip == "Melee" then
										return tool, NormalizeMeleeName(tool.Name)
									end
								end
							end
						end

						local function equipOrPurchaseTargetMelee(primaryArg, secondaryArg)
							local meleeEquipBusyName, meleeDefinition, getEquippedMeleeToolInfoCurrent, toolCandidate, meleeEntryNum, meleeIdByName, clockStamp, targetLocation, clockStampCurrent, targetDistance, targetDistanceCurrent, clockStampTarget, character
							meleeEquipBusyName = primaryArg
							meleeDefinition = secondaryArg
							local getEquippedMeleeToolInfoTarget
							getEquippedMeleeToolInfoCurrent, getEquippedMeleeToolInfoTarget = getEquippedMeleeToolInfo()

							if getEquippedMeleeToolInfoTarget ~= meleeEquipBusyName then
								if not ((CurrentTask ~= "BossesTask") and (CurrentTask ~= "SpecialBossesTask")) then
									if not MeleeEquipBusyName then
										SetTask(
											"SideTask",
											"Melee | Waiting for boss before loading " .. meleeEquipBusyName
										)
										return false, getEquippedMeleeToolInfoCurrent
									end
								end

								MeleeEquipBusyName = meleeEquipBusyName
								FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call(meleeEquipBusyName)
								task.wait(0.15)
								local getEquippedMeleeToolInfoPrimary
								toolCandidate, getEquippedMeleeToolInfoPrimary = getEquippedMeleeToolInfo()

								if getEquippedMeleeToolInfoPrimary ~= meleeEquipBusyName then
									if not ScriptStorage.MeleesOwned[meleeEquipBusyName] then
										meleeEntryNum = tonumber(ScriptStorage.Melees[meleeEquipBusyName])

										if not (meleeEntryNum and (meleeEntryNum > 0)) then
											if not hasOwnedOrMasteredMelee(meleeEquipBusyName) then
												MeleeEquipBusyName = nil
												return false, toolCandidate
											end
										end
									end

									if meleeEquipBusyName ~= "Electro" then
										if meleeDefinition and meleeDefinition.Buy then
											pcall(meleeDefinition.Buy)
											task.wait(0.1)
											pcall(meleeDefinition.Buy)
										else
											meleeIdByName = GetMeleeIdByName(meleeEquipBusyName)

											if meleeIdByName then
												pcall(function()
													Remotes.CommF_:InvokeServer("Buy" .. meleeIdByName)
												end)

												task.wait(0.1)

												pcall(function()
													Remotes.CommF_:InvokeServer("Buy" .. meleeIdByName, true)
												end)
											end
										end
									end

									clockStamp = os.clock()

									while true do
										if (os.clock() - clockStamp) >= 2 then
											targetLocation = resolveMeleeTrainerCFrame(meleeEquipBusyName)

											if targetLocation then
												SetTask(
													"MainTask",
													"Melee | Loading "
														.. (
															meleeEquipBusyName
															.. (" from " .. tostring(MeleeNPCMap[meleeEquipBusyName]))
														)
												)
												TweenController.Create(targetLocation + Vector3.new(0, 5, 3))
												clockStampCurrent = os.clock()

												while true do
													targetDistance = CaculateDistance(targetLocation)

													if
														(
															((meleeEquipBusyName == "Electro") and (targetDistance > 8))
															or (
																(meleeEquipBusyName ~= "Electro")
																and (targetDistance > 55)
															)
														) and ((os.clock() - clockStampCurrent) < 25)
													then
														character = LocalPlayer.Character

														if character then
															character =
																LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
														end

														if not character or (character.Health <= 0) then
															MeleeEquipBusyName = nil
															TweenController.ClearGhost()
															return false
														end

														if not TweenController.Playing then
															TweenController.Create(
																targetLocation + Vector3.new(0, 5, 3)
															)
														end

														task.wait(0.1)
														continue
													else
														break
													end
												end

												targetDistanceCurrent = CaculateDistance(targetLocation)

												if
													(
														(meleeEquipBusyName ~= "Electro")
														and (targetDistanceCurrent <= 60)
													)
													or (
														(meleeEquipBusyName == "Electro")
														and (targetDistanceCurrent <= 8)
													)
												then
													pcall(meleeDefinition.Buy)
													clockStampTarget = os.clock()

													while (os.clock() - clockStampTarget) < 3 do
														FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call(
															meleeEquipBusyName
														)
														task.wait(0.1)
														local getEquippedMeleeToolInfoFallback
														toolCandidate, getEquippedMeleeToolInfoFallback =
															getEquippedMeleeToolInfo()

														if getEquippedMeleeToolInfoFallback == meleeEquipBusyName then
															MeleeEquipBusyName = nil
															MeleeCheck(toolCandidate)
															return true, toolCandidate
														end
													end
												end
											end

											MeleeEquipBusyName = nil
											return false, toolCandidate
										end

										SyncLiveMeleeTools()
										FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call(
											meleeEquipBusyName
										)
										task.wait(0.1)
										local getEquippedMeleeToolInfoCandidate
										toolCandidate, getEquippedMeleeToolInfoCandidate = getEquippedMeleeToolInfo()

										if getEquippedMeleeToolInfoCandidate == meleeEquipBusyName then
											MeleeEquipBusyName = nil
											MeleeCheck(toolCandidate)
											return true, toolCandidate
										end
									end
								else
									MeleeEquipBusyName = nil
									MeleeCheck(toolCandidate)
									return true, toolCandidate
								end
							else
								return true, getEquippedMeleeToolInfoCurrent
							end
						end

						local targetMelee, findNextMeleeInCurrentSeaCurrent, value, meleeDefinitionCurrent =
							findNextMeleeInCurrentSea()

						if findNextMeleeInCurrentSeaCurrent ~= "Buy" then
							if findNextMeleeInCurrentSeaCurrent ~= "Mastery" then
								ScriptStorage.TargetMelee = nil
								local forceToUseSword = nil

								for _, backpackItem in pairs(ScriptStorage.Backpack) do
									if backpackItem.Type ~= "Sword" then
										forceToUseSword = nil
									else
										if backpackItem.Name == "Yama" then
											MasteryRequirement = 350
										elseif backpackItem.Name == "Tushita" then
											MasteryRequirement = 350
										else
											MasteryRequirement = 0
											if type(backpackItem.Skill) == "table" then
												for _, skillItem in pairs(backpackItem.Skill) do
													MasteryRequirement =
														math.max(MasteryRequirement, tonumber(skillItem) or 0)
												end
											end
										end

										if backpackItem.Mastery < MasteryRequirement then
											if backpackItem.Name ~= "Yama" then
												if backpackItem.Name ~= "Tushita" then
													forceToUseSword = nil
												else
													forceToUseSword =
														{ backpackItem.Name, backpackItem.Mastery, MasteryRequirement }
													break
												end
											else
												forceToUseSword =
													{ backpackItem.Name, backpackItem.Mastery, MasteryRequirement }
												break
											end
										else
											forceToUseSword = nil
										end
									end
								end

								ScriptStorage.ForceToUseSword = forceToUseSword

								if forceToUseSword then
									SetTask(
										"SideTask",
										"Farming mastery for "
											.. (
												forceToUseSword[1]
												.. (
													" ( "
													.. (forceToUseSword[2] .. (" / " .. (forceToUseSword[3] .. " )")))
												)
											)
									)
									if not ScriptStorage.Tools[forceToUseSword[1]] then
										Remotes.CommF_:InvokeServer("LoadItem", forceToUseSword[1])
										return
									end
								end

								return
							end

							ScriptStorage.TargetMelee = targetMelee
							ScriptStorage.ForceToUseSword = nil
							local equipOrPurchaseTargetMeleeCurrent, equipOrPurchaseTargetMeleeTarget =
								equipOrPurchaseTargetMelee(targetMelee, meleeDefinitionCurrent)

							if equipOrPurchaseTargetMeleeCurrent then
								if equipOrPurchaseTargetMeleeTarget then
									if equipOrPurchaseTargetMeleeTarget:FindFirstChild("Level") then
										value = equipOrPurchaseTargetMeleeTarget.Level.Value
										ScriptStorage.Melees[targetMelee] = value
									end
								end

								SetTask(
									"SideTask",
									"Farming Until Enough Mastery For "
										.. (
											targetMelee
											.. (
												" ( "
												.. (
													value
													.. (" / " .. (meleeDefinitionCurrent.NextLevelRequirement .. " )."))
												)
											)
										)
								)
								return
							end

							if CurrentTask ~= "BossesTask" then
								if CurrentTask ~= "SpecialBossesTask" then
									SetTask("SideTask", "Switching melee to " .. (targetMelee .. " for mastery."))
									return
								end
								SetTask("SideTask", "Melee | Waiting for boss before loading " .. targetMelee)
								return
							end

							SetTask("SideTask", "Melee | Waiting for boss before loading " .. targetMelee)
							return
						end

						ScriptStorage.TargetMelee = nil
						ScriptStorage.ForceToUseSword = nil
						local combinedText = nil
						local flowStep = nil

						for k, requiredAmount in pairs(meleeDefinitionCurrent.Price) do
							local playerDataEntry = ScriptStorage.PlayerData[k]
							if
								(not playerDataEntry and requiredAmount > 0)
								or (playerDataEntry and playerDataEntry < requiredAmount)
							then
								combinedText = k
									.. " ( "
									.. tostring(playerDataEntry or 0)
									.. " / "
									.. requiredAmount
									.. " )"
								break
							end
						end

						local setTask = SetTask
						local combinedTextCurrent

						if combinedText then
							combinedTextCurrent = (
								"Farming Until Enough " .. (combinedText .. (" For " .. targetMelee))
							) or ("Melee | Waiting requirements for " .. targetMelee)
						else
							combinedTextCurrent = "Melee | Waiting requirements for " .. targetMelee
							setTask("SideTask", combinedTextCurrent)
							return
						end

						setTask("SideTask", combinedTextCurrent)
						return
					end

					SetTask("SideTask", "Melee | Waiting for live tool data")
				end)
			end

			FunctionsHandler.SecondSeaPuzzle:RegisterMethod("Refresh", function()
				if ScriptStorage.PlayerData.Level < 700 then
					return
				end

				if SeaIndex ~= 1 then
					return
				end

				if FunctionsHandler.SecondSeaPuzzle:Get("IsCompleted") then
					return
				end

				local progress = Remotes.CommF_:InvokeServer("DressrosaQuestProgress")
				if type(progress) ~= "table" then
					return
				end

				if progress.TalkedDetective and progress.KilledIceBoss then
					Remotes.CommF_:InvokeServer("TravelDressrosa")
					return
				elseif progress.TalkedDetective and progress.UsedKey then
					SetTask("MainTask", "Second Sea Puzzle - Defeating Ice Admiral")
					if
						not workspace.Enemies:FindFirstChild("Ice Admiral")
						and CaculateDistance(CFrame.new(1345, 37, -1325)) > 15
					then
						TweenController.Create(CFrame.new(1345, 37, -1325))
						return
					end
					CombatController.Attack("Ice Admiral")
					return
				elseif progress.TalkedDetective and not progress.UsedKey then
					SetTask("MainTask", "Second Sea Puzzle - Unlocking Ice Door")
					FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call("Key")
					if CaculateDistance(CFrame.new(1345, 37, -1325)) > 8 then
						TweenController.Create(CFrame.new(1345, 37, -1325))
					end
					return
				else
					SetTask("MainTask", "Second Sea Puzzle - Talking to Military Detective")
					if CaculateDistance(CFrame.new(4849, 5, 719)) > 10 then
						TweenController.Create(CFrame.new(4849, 5, 719))
						return
					end
					Remotes.CommF_:InvokeServer("DressrosaQuestProgress", "Detective")
					return
				end
			end)

			FunctionsHandler.ColosseumPuzzle:RegisterMethod("Refresh", function()
				if SeaIndex ~= 2 then
					return
				end
				local playerBackpack = LocalPlayer and LocalPlayer:FindFirstChild("Backpack")
				local playerChar = LocalPlayer and LocalPlayer.Character
				local warriorHelmet = (playerBackpack and playerBackpack:FindFirstChild("Warrior Helmet"))
					or (playerChar and playerChar:FindFirstChild("Warrior Helmet"))
					or (ScriptStorage.Backpack and ScriptStorage.Backpack["Warrior Helmet"])

				if ScriptStorage.PlayerData.Level >= 850 then
					if not warriorHelmet then
						local response = Remotes.CommF_:InvokeServer("BartiloQuestProgress")

						if response then
							if response.DidPlates then
								if response.KilledBandits then
									if response.KilledSpring then
										FunctionsHandler.ColosseumPuzzle:Set("CurrentProgressLevel", nil)
										return
									end
								end
							end

							local initialCounterCurrent

							if response.KilledBandits then
								if response.KilledSpring then
									initialCounterCurrent = nil

									if not response.DidPlates then
										initialCounterCurrent = 3
									end
								else
									initialCounterCurrent = nil

									if ScriptStorage.Enemies.Jeremy then
										initialCounterCurrent = 2
									end
								end
							else
								initialCounterCurrent = 1
							end

							FunctionsHandler.ColosseumPuzzle:Set("CurrentProgressLevel", initialCounterCurrent)
							FunctionsHandler.ColosseumPuzzle:Set("LastestRefreshSenque", os.time())
							return initialCounterCurrent
						end

						FunctionsHandler.ColosseumPuzzle:Set("CurrentProgressLevel", nil)
						return
					end
				end

				FunctionsHandler.ColosseumPuzzle:Set("CurrentProgressLevel", nil)
			end)

			FunctionsHandler.ColosseumPuzzle:RegisterMethod("Start", function()
				local CurrentProgressLevel = FunctionsHandler.ColosseumPuzzle:Get("CurrentProgressLevel")
				FunctionsHandler.ColosseumPuzzle:Get("LastestRefreshSenque")
				FunctionsHandler.ColosseumPuzzle:Set("CurrentProgressLevel", nil)

				if CurrentProgressLevel then
					if CurrentProgressLevel ~= 1 then
						if CurrentProgressLevel ~= 2 then
							if CurrentProgressLevel ~= 3 then
								return
							end
							SetTask("MainTask", "Auto Bartilo Quest - Doing Puzzle")

							if
								CaculateDistance(
									CFrame.new(
										-1837.46155,
										44.2921753,
										1656.1987,
										0.999881566,
										-0,
										-0.0153914848,
										0,
										1,
										0,
										0.0153914848,
										-0,
										0.999881566
									)
								) > 10
							then
								TweenController.Create(
									CFrame.new(
										-1837.46155,
										44.2921753,
										1656.1987,
										0.999881566,
										-0,
										-0.0153914848,
										0,
										1,
										0,
										0.0153914848,
										-0,
										0.999881566
									)
								)
							else
								LocalPlayer = game.Players.LocalPlayer
								local character = LocalPlayer.Character
								TweenController.ClearGhost()

								pcall(function()
									local humanoid = character and character:FindFirstChildOfClass("Humanoid")
									local humanoidRootPart = character

									if character then
										humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

										if humanoid then
											humanoid.Sit = false
											humanoid.PlatformStand = false

											if humanoidRootPart then
												humanoidRootPart.Anchored = false
												humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
												humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
											end
										elseif humanoidRootPart then
											humanoidRootPart.Anchored = false
											humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
											humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
											pcall(function()
												setscriptable(LocalPlayer, "SimulationRadius", true)
												sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
											end)
											return
										end
									elseif humanoid then
										humanoid.Sit = false
										humanoid.PlatformStand = false

										if humanoidRootPart then
											humanoidRootPart.Anchored = false
											humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
											humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
											pcall(function()
												setscriptable(LocalPlayer, "SimulationRadius", true)
												sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
											end)
											return
										end
									elseif humanoidRootPart then
										humanoidRootPart.Anchored = false
										humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
										humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
										pcall(function()
											setscriptable(LocalPlayer, "SimulationRadius", true)
											sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
										end)
										return
									end

									pcall(function()
										setscriptable(LocalPlayer, "SimulationRadius", true)
										sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
									end)
								end)

								task.wait(0.05)
								local colosseumPlateSequence = {
									{ CFrame.new(-1836, 11, 1714), 0.5 },
									{ CFrame.new(-1850.49329, 13.1789551, 1750.89685), 1 },
									{ CFrame.new(-1858.87305, 19.3777466, 1712.01807), 1 },
									{ CFrame.new(-1803.94324, 16.5789185, 1750.89685), 1 },
									{ CFrame.new(-1858.55835, 16.8604317, 1724.79541), 1 },
									{ CFrame.new(-1869.54224, 15.987854, 1681.00659), 1 },
									{ CFrame.new(-1800.0979, 16.4978027, 1684.52368), 1 },
									{ CFrame.new(-1819.26343, 14.795166, 1717.90625), 1 },
									{ CFrame.new(-1813.51843, 14.8604736, 1724.79541), 0 },
								}
								for _, stepInfo in ipairs(colosseumPlateSequence) do
									if not isSessionActive() then
										return
									end
									local activeChar = LocalPlayer.Character
									local activeRoot = activeChar and activeChar:FindFirstChild("HumanoidRootPart")
									if not activeRoot then
										return
									end
									activeRoot.CFrame = stepInfo[1]
									if stepInfo[2] > 0 then
										task.wait(stepInfo[2])
									end
								end

								return
							end

							return
						end

						SetTask("MainTask", "Auto Bartilo Quest - Defeating Jeremy")
						CombatController.Attack("Jeremy")
						return
					end

					SetTask("MainTask", "Auto Bartilo Quest - Defeating 50x Swan Pirate")
					local currentClaimQuest, rawQuestHeader = QuestController:GetCurrentClaimQuest()

					if currentClaimQuest then
						if string.find(rawQuestHeader, "50") then
							CombatController.Attack("Swan Pirate")
							return
						end
						QuestController.AbandonQuest()
						return
					end

					QuestController.StartQuest("BartiloQuest", 1)
					return
				end

				if FunctionsHandler.ColosseumPuzzle.Methods.Refresh:Call() then
					return FunctionsHandler.ColosseumPuzzle.Methods.Start:Call()
				end
			end)

			do
				local function canEngageBossByName(bossName)
					if bossName == "Deandre" or bossName == "Urban" or bossName == "Diablo" then
						if ScriptStorage.Backpack.Yama then
							return false
						end
						local eliteKillCount = tonumber(FunctionsHandler.Yama:Get("EliteCount"))
						if eliteKillCount and eliteKillCount >= 30 then
							return false
						end
						return true
					end

					if bossName == "Tide Keeper" then
						return Remotes.CommF_:InvokeServer("BuySharkmanKarate", true)
							== "I lost my house keys, could you help me find them? Thanks."
					end

					if bossName == "Awakened Ice Admiral" then
						if SeaIndex ~= 2 then
							return false
						end
						local mapFolder = Services.Workspace:FindFirstChild("Map")
						local iceCastle = mapFolder and mapFolder:FindFirstChild("IceCastle")
						local castleHall = iceCastle and iceCastle:FindFirstChild("Hall")
						local libraryDoor = castleHall and castleHall:FindFirstChild("LibraryDoor")
						if libraryDoor then
							return libraryDoor:FindFirstChild("PhoeyuDoor") ~= nil
						end
						return true
					end

					return true
				end

				local function hasAlreadyObtainedBossDrop(bossName)
					if bossName == "Cake Prince" then
						local hasTrident = ScriptStorage.Backpack["Spikey Trident"]
							or ScriptStorage.Tools["Spikey Trident"]
						local hasScarf = ScriptStorage.Backpack["Pale Scarf"] or ScriptStorage.Tools["Pale Scarf"]
						return (hasTrident and hasScarf) ~= nil
					end
					if bossName == "Dough King" then
						return (ScriptStorage.Backpack["Mirror Fractal"] or ScriptStorage.Tools["Mirror Fractal"])
							~= nil
					end
					return false
				end

				FunctionsHandler.BossesTask:RegisterMethod("Refresh", function()
					local raidController = FunctionsHandler.RaidController

					if raidController then
						if raidController.Initalized then
							if raidController.Methods.IsLocked then
								local ok, result = pcall(function()
									local methods = raidController.Methods
									return methods.IsLocked:Call()
								end)

								if ok then
									if result then
										return nil
									end
								end
							end
						end
					end

					local selectedBoss = nil
					for _, bossName in ipairs(BossesOrder) do
						if BossesOrderLevel[bossName] <= (ScriptStorage.PlayerData.Level or 0) then
							local bossInst = ScriptStorage.Enemies[bossName]
							if bossInst and bossInst:FindFirstChild("Humanoid") and bossInst.Humanoid.Health > 0 then
								if not hasAlreadyObtainedBossDrop(bossName) and canEngageBossByName(bossName) then
									selectedBoss = bossInst
								end
							end
						end
					end

					if selectedBoss then
						local bossRoot = selectedBoss:FindFirstChild("HumanoidRootPart")
						local bossDist = bossRoot and CaculateDistance(bossRoot.CFrame) or math.huge
						if SeaIndex ~= 2 then
							if bossDist < 5000 then
								return selectedBoss
							end
						elseif bossDist < 3000 then
							return selectedBoss
						end

						if BossesOrderWL[tostring(selectedBoss)] then
							return selectedBoss
						end
						if ScriptStorage.PlayerData.Level == MaxLevel then
							return selectedBoss
						end
					end
					return nil
				end)

				local function attackTargetBossModel(primaryArg)
					local raidController = FunctionsHandler.RaidController

					if raidController then
						if raidController.Initalized then
							if raidController.Methods.IsLocked then
								if raidController.Methods.IsLocked:Call() then
									return
								end
							end
						end
					end

					if CombatController.IsRaidActive() then
						return
					end

					if primaryArg then
						if hasAlreadyObtainedBossDrop(primaryArg.Name) then
							return
						end
						SetTask("MainTask", "Auto Farm Boss - Defeating " .. primaryArg.Name)
						local scopedValue = nil
						local scopedValueCurrent = nil

						local function resetSpecialItemsState()
							SpecialItems = nil
						end

						CombatController.Attack(
							tostring(primaryArg),
							scopedValue,
							scopedValueCurrent,
							resetSpecialItemsState
						)
						SpecialItems = nil
						TweenController.Hovering = false
						TweenController.HoverCFrame = nil
						return
					end
				end

				FunctionsHandler.BossesTask:RegisterMethod("Start", attackTargetBossModel)

				FunctionsHandler.SpecialBossesTask:RegisterMethod("Refresh", function()
					local raidController = FunctionsHandler.RaidController

					if raidController then
						if raidController.Initalized then
							if raidController.Methods.IsLocked then
								local ok, result = pcall(function()
									return raidController.Methods.IsLocked:Call()
								end)

								if ok then
									if result then
										return nil
									end
								end
							end
						end
					end

					local enemieEntryCopy = nil

					for k, specialBossesOrderItem in pairs(SpecialBossesOrder) do
						if specialBossesOrderItem <= ScriptStorage.PlayerData.Level then
							local enemieEntry = ScriptStorage.Enemies[k]

							if enemieEntry then
								if enemieEntry:FindFirstChild("Humanoid") then
									if enemieEntry.Humanoid.Health > 0 then
										if not hasAlreadyObtainedBossDrop(k) then
											enemieEntryCopy = enemieEntry
										end
									end
								end
							end
						end
					end

					return enemieEntryCopy
				end)

				FunctionsHandler.SpecialBossesTask:RegisterMethod("Start", function(primaryArg)
					local raidController = FunctionsHandler.RaidController

					if raidController then
						if raidController.Initalized then
							if raidController.Methods.IsLocked then
								if raidController.Methods.IsLocked:Call() then
									return
								end
							end
						end
					end

					if CombatController.IsRaidActive() then
						return
					end

					if primaryArg then
						if hasAlreadyObtainedBossDrop(primaryArg.Name) then
							return
						end
						SetTask("MainTask", "Auto Farm Boss - Defeating " .. primaryArg.Name)
						CombatController.Attack(tostring(primaryArg))
						return
					end
				end)
			end

			local isRaidCurrentlyFighting
			isRaidCurrentlyFighting = false
			local hasEnteredRaidDimension
			hasEnteredRaidDimension = false
			local isRaidFinishedFlag
			isRaidFinishedFlag = false
			local raidCompletedCount
			raidCompletedCount = 0
			local lastRaidStateCheckTime
			lastRaidStateCheckTime = 0
			local executeRaidHighHpInstaKill, ensureRaidVelocityLoop

			do
				local initialCounterCurrent = 0
				local isActiveState = false
				local collectedItemsCurrent = {}

				executeRaidHighHpInstaKill = function(raidIslandName)
					if raidIslandName ~= "Island 4" then
						if raidIslandName ~= "Island 5" then
							return
						end
					end

					if os.clock() < initialCounterCurrent then
						return
					end
					initialCounterCurrent = os.clock() + 12
					local enemies = workspace:FindFirstChild("Enemies")

					if enemies then
						local collectedItemsPrimary = {}

						for _, child in ipairs(enemies:GetChildren()) do
							local humanoid = child:FindFirstChildOfClass("Humanoid")

							if humanoid then
								if humanoid.Health > 0 then
									table.insert(
										collectedItemsPrimary,
										{ Humanoid = humanoid, MaxHealth = humanoid.MaxHealth }
									)
								end
							end
						end

						local function sortRaidMobsByMaxHealthDesc(humanoidComp, humanoidCompCurrent)
							return humanoidComp.MaxHealth > humanoidCompCurrent.MaxHealth
						end

						table.sort(collectedItemsPrimary, sortRaidMobsByMaxHealthDesc)

						local killLimit = math.min(3, #collectedItemsPrimary)
						for idx = 1, killLimit do
							local enemyHum = collectedItemsPrimary[idx].Humanoid
							if enemyHum and enemyHum.Parent and enemyHum.Health > 0 then
								pcall(function()
									enemyHum:ChangeState(Enum.HumanoidStateType.Dead)
								end)
							end
						end
						return
					end
				end

				local function updateRaidAntiFlingVelocity(containerFolder, secondaryArg)
					if not containerFolder or not secondaryArg then
						for k in pairs(collectedItemsCurrent) do
							if k.Parent then
								local raidVelocity = k:FindFirstChild("RaidVelocity")

								if raidVelocity then
									raidVelocity:Destroy()
								end
							end

							collectedItemsCurrent[k] = nil
						end

						return
					end

					for _, child in ipairs(containerFolder:GetChildren()) do
						local humanoidRootPart = child:IsA("Model")
							and (child:FindFirstChild("HumanoidRootPart") or child.PrimaryPart)
						local humanoid = child:IsA("Model") and child:FindFirstChildOfClass("Humanoid")

						if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
							local raidVelocity = humanoidRootPart:FindFirstChild("RaidVelocity")
							local farOut = (math.abs(humanoidRootPart.Position.X) > 40000)
								or (math.abs(humanoidRootPart.Position.Z) > 40000)

							if (farOut and humanoid) and (humanoid.Health > 0) then
								humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
								humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

								if not raidVelocity then
									raidVelocity = Instance.new("BodyVelocity")
									raidVelocity.Name = "RaidVelocity"
									raidVelocity.Parent = humanoidRootPart
								end

								raidVelocity.MaxForce = Vector3.new(1000000, 1000000, 1000000)
								raidVelocity.Velocity = Vector3.new(0, 0, 0)
								collectedItemsCurrent[humanoidRootPart] = true
							elseif raidVelocity then
								raidVelocity:Destroy()
								collectedItemsCurrent[humanoidRootPart] = nil
							end
						end
					end
				end

				ensureRaidVelocityLoop = function()
					if isActiveState then
						return
					end
					isActiveState = true

					task.spawn(function()
						local clockStamp = os.clock()

						while not _G.Stop do
							if CombatController.IsRaidActive() then
								clockStamp = os.clock()
								pcall(updateRaidAntiFlingVelocity, workspace:FindFirstChild("Enemies"), true)
								task.wait()
								continue
							elseif (os.clock() - clockStamp) <= 5 then
								pcall(updateRaidAntiFlingVelocity, workspace:FindFirstChild("Enemies"), false)
								task.wait(0.1)
								continue
							end

							break
						end

						pcall(updateRaidAntiFlingVelocity, workspace:FindFirstChild("Enemies"), false)
						isActiveState = false
					end)
				end
			end

			local remotes = Services.ReplicatedStorage:FindFirstChild("Remotes")

			if remotes then
				local raids = remotes:FindFirstChild("Raids")

				if raids then
					if raids:IsA("RemoteEvent") then
						raids.OnClientEvent:Connect(function(primaryArg)
							if primaryArg == "StartTimer" then
								if isRaidFinishedFlag then
									isRaidCurrentlyFighting = true
									hasEnteredRaidDimension = false
									lastRaidStateCheckTime = 0
									isRaidFinishedFlag = false
									return
								end
							end
						end)
					end
				end
			end

			local isRaidLockCurrentlyActive

			isRaidLockCurrentlyActive = function(primaryArg)
				local missingHasEnteredRaidDimensionCopy = not hasEnteredRaidDimension

				if not hasEnteredRaidDimension then
					missingHasEnteredRaidDimensionCopy = isRaidCurrentlyFighting

					if not isRaidCurrentlyFighting then
						missingHasEnteredRaidDimensionCopy = primaryArg ~= nil
						if not missingHasEnteredRaidDimensionCopy then
							return (CombatController.IsRaidActive())
						end
					end
				end

				return missingHasEnteredRaidDimensionCopy
			end

			FunctionsHandler.RaidController:RegisterMethod("RefreshRaidType", function()
				local raids = require(game.ReplicatedStorage.Raids).raids
				local statusMessageText = tostring(ScriptStorage.PlayerData.DevilFruit or "")

				if statusMessageText ~= "" then
					if statusMessageText ~= "None" then
						for _, raid in ipairs(raids) do
							if string.find(statusMessageText, raid) then
								FunctionsHandler.RaidController:Set("CurrentChip", raid)
								return
							end
						end
					end
				end

				for _, raid in ipairs(raids) do
					if string.lower(tostring(raid)) ~= "ice" then
						continue
					end
					FunctionsHandler.RaidController:Set("CurrentChip", raid)
					return
				end

				FunctionsHandler.RaidController:Set("CurrentChip", "Ice")
			end)

			FunctionsHandler.RaidController:RegisterMethod("GetRaidableFruit", function()
				local scopedValue, scopedValueCurrent, scopedValueTarget = pairs(ScriptStorage.Backpack or {})
				local huge = math.huge

				local bestFruitEntry = nil
				for _, itemData in scopedValue, scopedValueCurrent, scopedValueTarget do
					if type(itemData) == "table" and itemData.Name then
						local count = tonumber(itemData.Count) or tonumber(itemData.Amount) or 0
						local price = tonumber(itemData.Price)
							or tonumber(itemData.Value)
							or getReplicatedFruitPrice(itemData.Name)
						local itemType = itemData.Type
						local isFruitCandidate = (itemType == "Blox Fruit")
							or (itemType == "PhysicalMoveset")
							or (itemType == "Tool" and getReplicatedFruitPrice(itemData.Name) > 1)

						if
							isFruitCandidate
							and count > 0
							and price
							and price > 1
							and price < 1000000
							and price < huge
						then
							huge = price
							bestFruitEntry = itemData
						end
					end
				end
				local bestFruitEntryCopy = bestFruitEntry

				return bestFruitEntryCopy
			end)

			FunctionsHandler.RaidController:RegisterMethod("GetCurrentRaidIsland", function()
				if SeaIndex ~= 1 then
					if hasEnteredRaidDimension then
						return nil
					end
					local character = LocalPlayer.Character

					if character then
						local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

						if humanoidRootPart then
							local collectedItemsCurrent = { {}, {}, {}, {}, {} }
							local isCheckPassed = (math.abs(humanoidRootPart.Position.X) > 40000)
								or (math.abs(humanoidRootPart.Position.Z) > 40000)
							local locations = workspace:FindFirstChild("_WorldOrigin")
								and workspace._WorldOrigin:FindFirstChild("Locations")
							local childCopy = nil

							if locations then
								local magnitudeCopy = nil
								childCopy = nil

								for _, child in ipairs(locations:GetChildren()) do
									if string.find(child.Name, "Island ") then
										if (child.Position - Vector3.new(0, 0, 0)).Magnitude > 7000 then
											local processedText = string.match(child.Name, "%d+")
											local parsedAmount = tonumber(processedText)

											if parsedAmount then
												if collectedItemsCurrent[parsedAmount] then
													table.insert(collectedItemsCurrent[parsedAmount], child)
												end
											end

											local magnitude = (child.Position - humanoidRootPart.Position).Magnitude

											if magnitudeCopy then
												if magnitude < magnitudeCopy then
													magnitudeCopy = magnitude
													childCopy = child
												end
											else
												magnitudeCopy = magnitude
												childCopy = child
											end
										end
									end
								end
							end

							for i = 5, 1, -1 do
								for _, spatialTarget in ipairs(collectedItemsCurrent[i]) do
									if (spatialTarget.Position - humanoidRootPart.Position).Magnitude < 3000 then
										return spatialTarget
									end
								end
							end

							if isCheckPassed then
								if childCopy then
									return childCopy
								end
							end

							return nil
						end
					end

					return nil
				end

				return nil
			end)

			local function isToolSpecialMicrochip(targetInstance)
				if targetInstance then
					if targetInstance:IsA("Tool") then
						local processedText = string.lower(tostring(targetInstance.Name))
						local isCheckPassed = processedText == "special microchip"
						if isCheckPassed then
							return isCheckPassed
						end
						return processedText:find("microchip", 1, true) ~= nil
					end

					return false
				end

				return false
			end

			CheckSpecialMicrochip = function(primaryArg)
				local collectedItemsCurrent = {}

				if LocalPlayer.Character then
					table.insert(collectedItemsCurrent, LocalPlayer.Character:GetChildren())
				end

				if LocalPlayer.Backpack then
					table.insert(collectedItemsCurrent, LocalPlayer.Backpack:GetChildren())
				end

				for _, iteratedElement in ipairs(collectedItemsCurrent) do
					for _, iteratedElementCurrent in ipairs(iteratedElement) do
						if isToolSpecialMicrochip(iteratedElementCurrent) then
							if primaryArg then
								if iteratedElementCurrent.Parent ~= LocalPlayer.Character then
									continue
								end
								return iteratedElementCurrent
							end

							return iteratedElementCurrent
						end
					end
				end
			end

			local markRaidDimensionEntered

			do
				local function waitForSpecialMicrochip(primaryArg, secondaryArg)
					local clockStamp = os.clock()

					while true do
						local microchipTool = CheckSpecialMicrochip(secondaryArg)

						if microchipTool then
							return microchipTool
						else
							task.wait(0.15)
							local elapsedDuration = os.clock() - clockStamp

							if primaryArg then
								if primaryArg < elapsedDuration then
									return
								end
								continue
							end

							if elapsedDuration > 3 then
								break
							end
						end
					end
				end

				local function equipSpecialMicrochip()
					local clockStamp = os.clock()
					local microchipTool = waitForSpecialMicrochip(0.5)
					if not microchipTool then
						return nil
					end

					while (os.clock() - clockStamp) < 2 do
						if microchipTool then
							if microchipTool.Parent == LocalPlayer.Character then
								return microchipTool
							end
						end

						if microchipTool then
							if microchipTool:IsA("Tool") then
								if LocalPlayer.Character then
									local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

									if humanoid then
										pcall(function()
											humanoid:EquipTool(microchipTool)
										end)
									end
								end
							else
								pcall(function()
									FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call("Special Microchip")
								end)

								microchipTool = waitForSpecialMicrochip(0.25)
							end
						else
							pcall(function()
								FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call("Special Microchip")
							end)

							microchipTool = waitForSpecialMicrochip(0.25)
						end

						local waitForSpecialMicrochipCurrent = waitForSpecialMicrochip(0.25, true)
						if waitForSpecialMicrochipCurrent then
							return waitForSpecialMicrochipCurrent
						end
						microchipTool = CheckSpecialMicrochip()
						task.wait(0.1)
					end

					return CheckSpecialMicrochip(true)
				end

				local function findRaidLabModel(childName)
					local map = workspace:FindFirstChild("Map")

					if map then
						local firstChild = map:FindFirstChild(childName)
						if firstChild then
							return firstChild
						end
					end

					return (workspace:FindFirstChild(childName))
				end

				local function extractRaidPartCFrame(partInstance)
					if partInstance then
						if partInstance:IsA("BasePart") then
							return partInstance.CFrame
						end

						if partInstance:IsA("Model") then
							return partInstance:GetModelCFrame()
						end
						local humanoidRootPart = partInstance:FindFirstChild("HumanoidRootPart")

						if not humanoidRootPart then
							humanoidRootPart = partInstance:FindFirstChildWhichIsA("BasePart", true)
							if not humanoidRootPart then
								return humanoidRootPart
							end
						end

						return humanoidRootPart.CFrame
					end
				end

				local function findRaidSummonInWorkspace(primaryArg)
					local findRaidLabModelCurrent = findRaidLabModel(primaryArg)
					local spatialTarget = extractRaidPartCFrame(findRaidLabModelCurrent)
					local descendantCopy = nil

					for _, descendant in ipairs(workspace:GetDescendants()) do
						local initialCounterCurrent = nil

						if (descendant.Name == "RaidSummon2") or (descendant.Name == "RaidSummon") then
							if spatialTarget then
								initialCounterCurrent = 1
							elseif not descendantCopy then
								descendantCopy = descendant
							end
						end

						if initialCounterCurrent == 1 then
							local spatialTargetCurrent = extractRaidPartCFrame(descendant)

							if spatialTargetCurrent then
								if (spatialTargetCurrent.Position - spatialTarget.Position).Magnitude < 2500 then
									return findRaidLabModelCurrent, descendant
								end
								continue
							end

							continue
						end

						if initialCounterCurrent == 2 then
							break
						end
					end

					return findRaidLabModelCurrent, descendantCopy
				end

				local function resolveRaidSummonPad(primaryArg)
					local findRaidLabModelCurrent = findRaidLabModel(primaryArg)
					local raidSummon, findRaidSummonInWorkspaceCurrent

					if findRaidLabModelCurrent then
						raidSummon = findRaidLabModelCurrent:FindFirstChild("RaidSummon2", true)

						if not raidSummon then
							local findRaidSummonInWorkspaceTarget
							findRaidSummonInWorkspaceCurrent, findRaidSummonInWorkspaceTarget =
								findRaidSummonInWorkspace(primaryArg)
							raidSummon = findRaidSummonInWorkspaceTarget
							if not findRaidLabModelCurrent then
								return findRaidSummonInWorkspaceCurrent, raidSummon
							end
						end
					else
						findRaidSummonInWorkspaceCurrent, raidSummon = findRaidSummonInWorkspace(primaryArg)
						if not findRaidLabModelCurrent then
							return findRaidSummonInWorkspaceCurrent, raidSummon
						end
					end

					return findRaidLabModelCurrent, raidSummon
				end

				local function resolveRaidSummonButton(primaryArg)
					local resolveRaidSummonPadCurrent, resolveRaidSummonPadTarget = resolveRaidSummonPad(primaryArg)
					local button, clickDetector

					if resolveRaidSummonPadTarget then
						button = resolveRaidSummonPadTarget:FindFirstChild("Button", true)

						if button then
							clickDetector = button:FindFirstChildWhichIsA("ClickDetector", true)

							if not button:IsA("BasePart") then
								button = button:FindFirstChildWhichIsA("BasePart", true)
							end
						else
							button = resolveRaidSummonPadTarget:FindFirstChild("Main", true)

							if button then
								clickDetector = button:FindFirstChildWhichIsA("ClickDetector", true)

								if not button:IsA("BasePart") then
									button = button:FindFirstChildWhichIsA("BasePart", true)
								end
							else
								clickDetector = button
							end
						end
					else
						button = resolveRaidSummonPadTarget
						clickDetector = button
						return resolveRaidSummonPadCurrent, resolveRaidSummonPadTarget, clickDetector, button
					end

					return resolveRaidSummonPadCurrent, resolveRaidSummonPadTarget, clickDetector, button
				end

				local function moveNearRaidSummonStation(primaryArg, secondaryArg, tertiaryArg)
					local extractRaidPartCFrameCurrent = extractRaidPartCFrame(tertiaryArg)

					if not extractRaidPartCFrameCurrent then
						extractRaidPartCFrameCurrent = extractRaidPartCFrame(secondaryArg)

						if not extractRaidPartCFrameCurrent then
							extractRaidPartCFrameCurrent = extractRaidPartCFrame(primaryArg)
							if not extractRaidPartCFrameCurrent then
								return
							end
						end
					end

					return extractRaidPartCFrameCurrent + Vector3.new(0, 5, 3)
				end

				local function triggerRaidSummonButton(clickDetector, secondaryArg)
					local isActiveState = false

					if clickDetector then
						pcall(function()
							fireclickdetector(clickDetector)
							isActiveState = true
						end)
					end

					local character = LocalPlayer.Character

					if character then
						character = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

						if secondaryArg then
							if character then
								pcall(function()
									firetouchinterest(character, secondaryArg, 0)
									task.wait()
									firetouchinterest(character, secondaryArg, 1)
									isActiveState = true
								end)

								return isActiveState
							end
						end
					elseif secondaryArg then
						if character then
							pcall(function()
								firetouchinterest(character, secondaryArg, 0)
								task.wait()
								firetouchinterest(character, secondaryArg, 1)
								isActiveState = true
							end)

							return isActiveState
						end
					end

					return isActiveState
				end

				local configRecord = {
					["Boat Castle"] = CFrame.new(-5050, 322, -2960),
					CircleIsland = CFrame.new(-6440, 250, -4500),
					["Circle Island"] = CFrame.new(-6440, 250, -4500),
				}

				local function cancelActiveTweenForRaid(primaryArg)
					warn("TweenClear", primaryArg or "?")

					pcall(function()
						local tweenInstance = ActiveSecondaryTween
						if tweenInstance then
							return (ActiveSecondaryTween:Cancel())
						end
						return tweenInstance
					end)

					TweenController.ClearGhost()

					pcall(function()
						local character = LocalPlayer.Character

						if character then
							local humanoid = character:FindFirstChildOfClass("Humanoid")

							if humanoid then
								humanoid.Sit = false
								humanoid.PlatformStand = false
							end

							local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

							if humanoidRootPart then
								humanoidRootPart.Anchored = false
								humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
								humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
							end

							pcall(function()
								setscriptable(LocalPlayer, "SimulationRadius", true)
								sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
							end)
							return
						end
					end)

					task.wait(0.05)
				end

				local stateSignatureCopy = nil
				local initialCounterTarget = 0
				local scopedValue = nil
				local initialCounterPrimary = 0
				local initialCounterResolved = 0
				local initialCounterUpdated = 30
				local initialCounterNext = 120

				local function setRaidCommitLock(primaryArg)
					if FunctionsHandler.RaidController:Get("RaidCommitted") then
						if scopedValue ~= primaryArg then
							warn("Lock on:", primaryArg)
						end
					else
						warn("Lock on:", primaryArg)
					end

					initialCounterTarget = os.time()
					scopedValue = primaryArg
					FunctionsHandler.RaidController:Set("RaidCommitted", true)
				end

				local function clearRaidCommitLock(primaryArg)
					if FunctionsHandler.RaidController:Get("RaidCommitted") then
						warn("Lock off:", primaryArg or "unknown")
					end

					initialCounterTarget = 0
					scopedValue = nil
					FunctionsHandler.RaidController:Set("RaidCommitted", false)
				end

				markRaidDimensionEntered = function()
					isRaidCurrentlyFighting = false
					hasEnteredRaidDimension = true
					isRaidFinishedFlag = false
					raidCompletedCount += 1
					lastRaidStateCheckTime = os.clock() + 5
					LastRaidAlert = 0
					LastRaidSecondaryAlert = 0
					stateSignatureCopy = nil
					FunctionsHandler.RaidController:Set("CurrentProgressLevel", nil)
					clearRaidCommitLock("raid_completed")
					TweenDebounce = false

					pcall(function()
						if TweenInstance then
							TweenInstance:Cancel()
						end

						if ActiveSecondaryTween then
							ActiveSecondaryTween:Cancel()
							return
						end
					end)

					cancelActiveTweenForRaid("raid_completed_clear_state")
					warn("Completed -> cleared all raid state")
				end

				FunctionsHandler.RaidController:RegisterMethod("IsLocked", function()
					if SeaIndex == 1 then
						return nil
					end

					if os.clock() < lastRaidStateCheckTime then
						return true
					end

					if hasEnteredRaidDimension then
						if CombatController.IsRaidActive() then
							return true
						end
					end

					local ok, result = pcall(function()
						return FunctionsHandler.RaidController.Methods.GetCurrentRaidIsland:Call()
					end)

					if ok then
						result = result or nil
					else
						result = nil
					end

					if isRaidLockCurrentlyActive(result) then
						setRaidCommitLock("in_raid_dimension")
						if result then
							return result
						end
						return true
					end

					if FunctionsHandler.RaidController:Get("RaidCommitted") then
						if scopedValue == "in_raid_dimension" then
							if initialCounterTarget > 0 then
								if (os.time() - initialCounterTarget) <= initialCounterNext then
									return true
								end
							end

							clearRaidCommitLock("raid_dimension_expired")
						end
					end

					local microchipTool = CheckSpecialMicrochip()
					if microchipTool then
						setRaidCommitLock("special_microchip")
						return microchipTool
					end

					if FunctionsHandler.RaidController:Get("RaidCommitted") then
						if initialCounterTarget > 0 then
							if (os.time() - initialCounterTarget) <= initialCounterNext then
								return true
							end
						end

						clearRaidCommitLock("prep_expired")
						return nil
					end

					return nil
				end)

				FunctionsHandler.RaidController:RegisterMethod("Refresh", function()
					local call = FunctionsHandler.RaidController.Methods.IsLocked:Call()
					if call then
						return call
					end
					local level = ScriptStorage.PlayerData.Level
					local fragments = ScriptStorage.PlayerData.Fragments
					if level < 1300 then
						return
					end

					if SeaIndex ~= 1 then
						if level < 1500 then
							if fragments > 2000 then
								return
							end
						end

						if level < MaxLevel then
							if fragments > 5000 then
								return
							end
						elseif fragments > 10000 then
							return
						end

						local callCurrent = FunctionsHandler.RaidController.Methods.GetRaidableFruit:Call()
						local isCheckPassed = (initialCounterResolved == 0)
							or ((os.clock() - initialCounterResolved) >= initialCounterUpdated)
						local isCheckPassedCurrent = (tonumber(ScriptStorage.PlayerData.Beli) or 0) >= 100000

						if isCheckPassedCurrent then
							isCheckPassedCurrent = (os.time() - initialCounterPrimary) > 7200
						end

						if not callCurrent then
							if isCheckPassedCurrent then
								FunctionsHandler.RaidController:Set("CurrentProgressLevel", "Beli")
								return "Beli"
							end
							return nil
						end

						if isCheckPassed then
							FunctionsHandler.RaidController:Set("CurrentProgressLevel", callCurrent)
							return callCurrent
						end

						if isCheckPassedCurrent then
							FunctionsHandler.RaidController:Set("CurrentProgressLevel", "Beli")
							return "Beli"
						end
						return nil
					end
				end)

				FunctionsHandler.RaidController:RegisterMethod("Start", function()
					local start = FunctionsHandler.RaidController.Methods.Start
					if start.Busy then
						return
					end
					start.Busy = true

					local ok, result = xpcall(function()
						local clockStamp = os.clock()
						if clockStamp < lastRaidStateCheckTime then
							SetTask("MainTask", "Auto Raid - Waiting After Completion")
							return
						end

						if hasEnteredRaidDimension then
							if CombatController.IsRaidActive() then
								SetTask("MainTask", "Auto Raid - Waiting for server return")
								return
							end
						end

						if not FunctionsHandler.RaidController:Get("CurrentChip") then
							FunctionsHandler.RaidController.Methods.RefreshRaidType:Call()
						end

						if SeaIndex ~= 1 then
							local ok, result = pcall(function()
								return FunctionsHandler.RaidController.Methods.GetCurrentRaidIsland:Call()
							end)

							local currentRaidIsland = ok and result or nil
							local isInRaid = isRaidLockCurrentlyActive(currentRaidIsland)
							local preRefreshEpoch = raidCompletedCount
							RefreshInventory()

							if preRefreshEpoch ~= raidCompletedCount then
								local statusMsg = CombatController.IsRaidActive()
										and "Auto Raid - Waiting for server return"
									or "Auto Raid - Waiting After Completion"
								SetTask("MainTask", statusMsg)
								return
							end

							FunctionsHandler.RaidController:Set("CurrentProgressLevel", nil)
							local currentChipName = FunctionsHandler.RaidController:Get("CurrentChip")

							if currentRaidIsland or isInRaid then
								setRaidCommitLock("in_raid_dimension")
							end

							local islandTag = (currentRaidIsland and currentRaidIsland.Name)
								or (isInRaid and "in_dimension")
								or "nil"
							local stateSignature = string.format(
								"%s|%s|%s",
								tostring(islandTag),
								tostring(SeaIndex),
								isInRaid and "raid" or "prep"
							)
							if stateSignature ~= stateSignatureCopy then
								stateSignatureCopy = stateSignature
								warn("Start chip=", currentChipName, "sea=", SeaIndex, "island=", islandTag)
							end

							if isInRaid then
								if typeof(currentRaidIsland) ~= "Instance" then
									currentRaidIsland =
										FunctionsHandler.RaidController.Methods.GetCurrentRaidIsland:Call()
								end

								if currentRaidIsland then
									local islandName = currentRaidIsland.Name or "Raid Island"
									local islandPos = nil
									if currentRaidIsland:IsA("BasePart") then
										islandPos = currentRaidIsland.Position
									else
										local okPivot, pivotCf = pcall(function()
											return currentRaidIsland:GetPivot()
										end)
										if okPivot and pivotCf then
											islandPos = pivotCf.Position
										end
									end

									SetTask("MainTask", "Auto Raid - " .. tostring(islandName) .. " / 5")
									ensureRaidVelocityLoop()
									executeRaidHighHpInstaKill(islandName)

									local enemiesFolder = workspace:FindFirstChild("Enemies")
									local nearestRaidEnemy = nil
									local nearestRaidDist = nil
									if enemiesFolder then
										for _, enemyModel in ipairs(enemiesFolder:GetChildren()) do
											local hum = enemyModel:FindFirstChildOfClass("Humanoid")
											local root = enemyModel:FindFirstChild("HumanoidRootPart")
											if hum and hum.Health > 0 and root then
												local dist = CaculateDistance(root.Position)
												if dist <= 400 and (not nearestRaidDist or dist < nearestRaidDist) then
													nearestRaidDist = dist
													nearestRaidEnemy = enemyModel
												end
											end
										end
									end

									if nearestRaidEnemy then
										local engageStart = os.time()
										while
											isSessionActive()
											and nearestRaidEnemy.Parent
											and enemiesFolder
											and nearestRaidEnemy:IsDescendantOf(enemiesFolder)
											and (os.time() - engageStart) < 45
										do
											task.wait(0.05)
											executeRaidHighHpInstaKill(islandName)
											local hum = nearestRaidEnemy:FindFirstChildOfClass("Humanoid")
											local root = nearestRaidEnemy:FindFirstChild("HumanoidRootPart")
											if
												not hum
												or hum.Health <= 0
												or not root
												or CaculateDistance(root.Position) > 400
											then
												return
											end
											CombatController.Attack(nearestRaidEnemy.Name, nil, nil, nil, {
												AllowBring = false,
												TargetInstance = nearestRaidEnemy,
											})
										end
										return
									end

									if islandPos then
										local xOffset = (islandName == "Island 2" and currentChipName == "Phoenix")
												and 300
											or 0
										local hoverTarget = islandPos + Vector3.new(xOffset, 60, 0)
										if not TweenController.Playing then
											if TweenController.Hovering then
												stopTween(false)
											end
											if CaculateDistance(hoverTarget) > 8 then
												TweenController.Create(hoverTarget, false, true)
											end
										end
										return
									end
								end

								SetTask("MainTask", "Auto Raid - Waiting for island")
								return
							else
								if
									scopedValue == "in_raid_dimension"
									and initialCounterTarget > 0
									and (os.time() - initialCounterTarget) <= initialCounterNext
								then
									SetTask("MainTask", "Auto Raid - Waiting for raid state")
									return
								end

								if not CheckSpecialMicrochip() then
									SetTask("MainTask", "Auto Raid - Buying Chip - " .. tostring(currentChipName))
									local raidFruit = FunctionsHandler.RaidController.Methods.GetRaidableFruit:Call()
									local playerBeli = tonumber(ScriptStorage.PlayerData.Beli) or 0

									if
										raidFruit
										and (
											initialCounterResolved == 0
											or (os.clock() - initialCounterResolved) >= initialCounterUpdated
										)
									then
										initialCounterResolved = os.clock()
										warn("Prep LoadFruit", raidFruit.Name)
										setRaidCommitLock("buying_chip")
										table.insert(ScriptStorage.IgnoreStoreFruits, raidFruit.Name)

										pcall(function()
											Remotes.CommF_:InvokeServer("LoadFruit", raidFruit.Name)
										end)

										local displayFruitName = FruitIdToName and FruitIdToName(raidFruit.Name) or nil
										local waitDeadline = os.clock() + 1.8
										local loadedFruitOk = false

										while os.clock() < waitDeadline do
											pcall(RefreshInventory)
											if
												ScriptStorage.Tools[raidFruit.Name]
												or (displayFruitName and ScriptStorage.Tools[displayFruitName])
												or (
													LocalPlayer.Backpack
													and (
														LocalPlayer.Backpack:FindFirstChild(raidFruit.Name)
														or (
															displayFruitName
															and LocalPlayer.Backpack:FindFirstChild(displayFruitName)
														)
													)
												)
											then
												loadedFruitOk = true
												break
											end
											task.wait(0.1)
										end

										if not loadedFruitOk then
											clearRaidCommitLock("raid_fruit_load_failed")
											warn("Raid fruit did not load", raidFruit.Name)
											return
										end

										pcall(function()
											Remotes.CommF_:InvokeServer("RaidsNpc", "Select", currentChipName)
										end)
										waitForSpecialMicrochip(1.5)
									elseif playerBeli >= 100000 and (os.time() - initialCounterPrimary) > 7200 then
										warn("Prep BuyChip with 100k Beli")
										setRaidCommitLock("buying_chip_beli")
										pcall(function()
											Remotes.CommF_:InvokeServer("RaidsNpc", "Select", currentChipName)
										end)
										waitForSpecialMicrochip(1.5)
									else
										clearRaidCommitLock("no_fruit_or_beli_cooldown")
										return
									end

									if not CheckSpecialMicrochip() and not waitForSpecialMicrochip(1) then
										initialCounterPrimary = os.time()
										clearRaidCommitLock("buy_chip_failed")
										warn("Prep buy chip failed or cooldown active")
										return
									end
								end

								setRaidCommitLock("special_microchip")
								local raidRoomName = ({ nil, "CircleIsland", "Boat Castle" })[SeaIndex]
								local labIsland, labMap, labButton, labClickDetector =
									resolveRaidSummonButton(raidRoomName)

								if labButton or labClickDetector then
									SetTask("MainTask", "Auto Raid - Starting Raid")
									local clickStartClock = os.clock()
									local chipConsumedOrStarted = false

									while isSessionActive() do
										if not CheckSpecialMicrochip() or isRaidLockCurrentlyActive() then
											chipConsumedOrStarted = true
											break
										end
										if (os.clock() - clickStartClock) > 30 then
											break
										end
										equipSpecialMicrochip()
										isRaidFinishedFlag = true
										triggerRaidSummonButton(labButton, labClickDetector)
										stopTween(false)
										task.wait(0.25)
									end

									if not chipConsumedOrStarted then
										warn("Prep timeout 30s inserting chip -> resetting character")
										isRaidFinishedFlag = false
										clearRaidCommitLock("insert_timeout_reset")
										local hum = LocalPlayer.Character
											and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
										if hum then
											hum:ChangeState(15)
											task.wait(1.5)
										end
										return
									end

									SetTask("MainTask", "Auto Raid - Waiting Until Raid Is Started")
									stopTween(false)
									local startWaitUnix = os.time()
									while isSessionActive() and not isRaidLockCurrentlyActive() do
										if (os.time() - startWaitUnix) > 30 then
											warn("Timeout 30s waiting for raid to start")
											break
										end
										task.wait(0.5)
									end
									isRaidFinishedFlag = false
									return
								else
									local roomTargetCFrame = moveNearRaidSummonStation(
										labIsland,
										labMap,
										labClickDetector
									) or configRecord[raidRoomName]
									if not roomTargetCFrame then
										return
									end
									SetTask("MainTask", "Auto Raid - Loading Raid Room - " .. tostring(raidRoomName))
									if
										not TweenController.Hovering
										or not TweenController.HoverCFrame
										or (TweenController.HoverCFrame.Position - roomTargetCFrame.Position).Magnitude
											> 8
									then
										TweenController.Create(roomTargetCFrame)
									end
									return
								end
							end
						end
					end, debug.traceback)

					start.Busy = false
					if ok then
						return
					end
					Report(result)
				end)
			end

			FunctionsHandler.CollectDrops:RegisterMethod("Refresh", function()
				if ShouldPreemptForMeleeBuy then
					if ShouldPreemptForMeleeBuy() then
						return
					end
				end

				if FunctionsHandler.RaidController then
					if FunctionsHandler.RaidController.Initalized then
						if FunctionsHandler.RaidController.Methods.IsLocked then
							if FunctionsHandler.RaidController.Methods.IsLocked:Call() then
								FunctionsHandler.CollectDrops:Set("CurrentProgressLevel", nil)
								return
							end
						end
					end
				end

				local initialCounterCurrent = tonumber(ScriptStorage.PlayerData.Level) or 0
				local CurrentProgressLevel = FunctionsHandler.CollectDrops:Get("CurrentProgressLevel")

				if CurrentProgressLevel then
					if CurrentProgressLevel:IsDescendantOf(workspace) then
						if CurrentProgressLevel:FindFirstChild("Handle") then
							if initialCounterCurrent >= 1000 then
								return CurrentProgressLevel
							end

							if not isSubmergedPos(CurrentProgressLevel:GetModelCFrame().Position) then
								return CurrentProgressLevel
							end
						end
					end
				end

				local ignoredFruits = {}
				for _, rawFruitName in ipairs(ScriptStorage.IgnoreStoreFruits or {}) do
					ignoredFruits[tostring(rawFruitName)] = true
					if FruitIdToName then
						local okName, mapped = pcall(FruitIdToName, rawFruitName)
						if okName and mapped then
							ignoredFruits[tostring(mapped)] = true
						end
					end
				end

				for _, child in ipairs(workspace:GetChildren()) do
					if
						string.find(child.Name, "Fruit")
						and not PlayersService:FindFirstChild(child.Name)
						and child:FindFirstChild("Handle")
					then
						local fruitDisplayName = tostring(child)
						if
							not ignoredFruits[fruitDisplayName]
							and not ScriptStorage.Backpack[FruitNameToId(fruitDisplayName)]
						then
							if initialCounterCurrent >= 1000 or not isSubmergedPos(child:GetModelCFrame().Position) then
								FunctionsHandler.CollectDrops:Set("CurrentProgressLevel", child)
								return child
							end
						end
					end
				end
			end)

			FunctionsHandler.CollectDrops:RegisterMethod("Start", function()
				if ShouldPreemptForMeleeBuy then
					if ShouldPreemptForMeleeBuy() then
						return
					end
				end

				if FunctionsHandler.RaidController then
					if FunctionsHandler.RaidController.Initalized then
						if FunctionsHandler.RaidController.Methods.IsLocked then
							if FunctionsHandler.RaidController.Methods.IsLocked:Call() then
								FunctionsHandler.CollectDrops:Set("CurrentProgressLevel", nil)
								return
							end
						end
					end
				end

				local CurrentProgressLevel = FunctionsHandler.CollectDrops:Get("CurrentProgressLevel")

				if CurrentProgressLevel then
					if CurrentProgressLevel:IsDescendantOf(workspace) then
						local modelCFrame = CurrentProgressLevel:GetModelCFrame()
						SetTask("MainTask", "Auto Collect Drop Items - " .. tostring(CurrentProgressLevel))

						if CaculateDistance(modelCFrame.Position) > 10 then
							if TweenController.Playing then
								return
							end
							TweenController.Create(modelCFrame)
							return
						end

						FunctionsHandler.CollectDrops:Set("CurrentProgressLevel", nil)
						return
					end
				end

				FunctionsHandler.CollectDrops:Set("CurrentProgressLevel", nil)
			end)

			do
				local initialCounterCurrent = 0

				local function checkElectricClawQuestState()
					if os.time() < initialCounterCurrent then
						return nil
					end

					local ok, result = pcall(function()
						return Remotes.CommF_:InvokeServer("BuyElectricClaw", true)
					end)

					if ok then
						return result
					end
					return nil
				end

				FunctionsHandler.UtillyItemsActivitation:RegisterMethod("Refresh", function()
					if FunctionsHandler.RaidController then
						if FunctionsHandler.RaidController.Initalized then
							if FunctionsHandler.RaidController.Methods.IsLocked then
								if FunctionsHandler.RaidController.Methods.IsLocked:Call() then
									return
								end
							end
						end
					end

					if (os.time() - unixTimestamp) < 20 then
						return
					end

					if not SpecialItems then
						SpecialItems = {}
						local collectedItemsCurrent = {}
						IceAdmiralPassed = true
						local getValueNum = tonumber(FunctionsHandler.Yama:Get("EliteCount"))

						if SeaIndex == 3 then
							if not ScriptStorage.Backpack.Yama then
								local ok, result = pcall(function()
									return Remotes.CommF_:InvokeServer("EliteHunter", "Progress")
								end)

								if ok then
									local resultCopyNum = tonumber(result)

									if resultCopyNum then
										getValueNum = resultCopyNum
										FunctionsHandler.Yama:Set("EliteCount", getValueNum)
									elseif getValueNum then
										FunctionsHandler.Yama:Set("EliteCount", getValueNum)
									end
								elseif getValueNum then
									FunctionsHandler.Yama:Set("EliteCount", getValueNum)
								end
							end
						end

						if ScriptStorage.Tools["Hidden Key"] then
							table.insert(SpecialItems, "Hidden Key")
						end

						if SeaIndex == 2 then
							if Services.Workspace.Map.IceCastle.Hall.LibraryDoor:FindFirstChild("PhoeyuDoor") then
								table.insert(SpecialItems, "Library Key")
								IceAdmiralPassed = false
							end
						end

						if IceAdmiralPassed then
							table.insert(collectedItemsCurrent, "Awakened Ice Admiral")
						end

						local sharkmanKarate = ScriptStorage.Melees["Sharkman Karate"]
						local missingSharkmanKarateCopy = not sharkmanKarate

						if not sharkmanKarate then
							missingSharkmanKarateCopy = Remotes.CommF_:InvokeServer("BuySharkmanKarate", true)
						end

						SharkmanPassed = typeof(missingSharkmanKarateCopy) == "string"

						if typeof(missingSharkmanKarateCopy) ~= "string" then
							TidePassed = true
							table.insert(collectedItemsCurrent, "Tide Keeper")
						else
							table.insert(SpecialItems, "Water Key")
						end

						if ScriptStorage.Backpack.Yama then
							table.insert(collectedItemsCurrent, "Deandre")
							table.insert(collectedItemsCurrent, "Urban")
							table.insert(collectedItemsCurrent, "Diablo")
						elseif getValueNum then
							if getValueNum >= 30 then
								table.insert(collectedItemsCurrent, "Deandre")
								table.insert(collectedItemsCurrent, "Urban")
								table.insert(collectedItemsCurrent, "Diablo")
							end
						end

						local function prioritizeSpecialBossOrder()
							local collectedItemsPrimary = {}

							for _, bossName in ipairs(BossesOrder) do
								local isActiveState = true

								for _, iteratedElement in ipairs(collectedItemsCurrent) do
									if iteratedElement == bossName then
										isActiveState = false
									end
								end

								if isActiveState then
									table.insert(collectedItemsPrimary, bossName)
								end
							end

							table.sort(collectedItemsPrimary, function(bossA, bossB)
								local lvlA = BossesOrderWL[bossA] or 0
								local lvlB = BossesOrderWL[bossB] or 0
								if lvlA ~= lvlB then
									return lvlA > lvlB
								end
								return tostring(bossA) < tostring(bossB)
							end)

							return collectedItemsPrimary
						end

						BossesOrder = prioritizeSpecialBossOrder()

						if FunctionsHandler.Trevor:Get("IsCompleted") then
							if not Storage:Get("SwanDefeated") then
								BossesOrderLevel["Don Swan"] = 1100
								table.insert(BossesOrder, "Don Swan")

								if SeaIndex == 2 then
									if ScriptStorage.PlayerData.Level > 1500 then
										if not ScriptStorage.Enemies["Don Swan"] then
											Hop("Hop for don swan")
										end
									end
								end
							end
						end
					end

					for _, specialItemItem in pairs(SpecialItems) do
						if ScriptStorage.Tools[specialItemItem] then
							if specialItemItem ~= "Water Key" then
								FunctionsHandler.UtillyItemsActivitation:Set("CurrentProgressLevel", specialItemItem)
								return specialItemItem
							end

							if chooseNextMeleeAction() == "Sharkman Karate" then
								FunctionsHandler.UtillyItemsActivitation:Set("CurrentProgressLevel", specialItemItem)
								return specialItemItem
							end
						end
					end

					if SeaIndex == 1 then
						local level = ScriptStorage.PlayerData.Level

						if level then
							if level >= 150 then
								if not HasLightningBolt(true) then
									if not hasOwnedOrMasteredMelee("Electro") then
										FunctionsHandler.UtillyItemsActivitation:Set(
											"CurrentProgressLevel",
											"Mad Scientist Task"
										)
										return "Mad Scientist Task"
									end
								end
							end
						end
					end

					if ScriptStorage.Tools["Red Key"] then
						FunctionsHandler.UtillyItemsActivitation:Set("CurrentProgressLevel", "Red Key")
						return "Red Key"
					end

					if SeaIndex == 3 then
						if ScriptStorage.Tools["Fire Essence"] then
							if not IsFireEssenceGave then
								FunctionsHandler.UtillyItemsActivitation:Set("CurrentProgressLevel", "Uzoth Essence")
								return "Uzoth Essence"
							end
						end
					end
				end)

				FunctionsHandler.UtillyItemsActivitation:RegisterMethod("Start", function()
					if FunctionsHandler.RaidController then
						if FunctionsHandler.RaidController.Initalized then
							if FunctionsHandler.RaidController.Methods.IsLocked then
								if FunctionsHandler.RaidController.Methods.IsLocked:Call() then
									return
								end
							end
						end
					end

					local CurrentProgressLevel = FunctionsHandler.UtillyItemsActivitation:Get("CurrentProgressLevel")

					if CurrentProgressLevel ~= "Hidden Key" then
						if CurrentProgressLevel ~= "Water Key" then
							if CurrentProgressLevel ~= "Library Key" then
								if CurrentProgressLevel ~= "Red Key" then
									if CurrentProgressLevel ~= "Previous Hero" then
										if CurrentProgressLevel ~= "Uzoth Essence" then
											if CurrentProgressLevel ~= "Mad Scientist Task" then
												return
											end
											SetTask("MainTask", "Electro - Mad Scientist Quest")
											local fetchElectroQuestProgressCurrent = fetchElectroQuestProgress()

											if fetchElectroQuestProgressCurrent ~= 0 then
												if fetchElectroQuestProgressCurrent ~= 5 then
													if fetchElectroQuestProgressCurrent ~= nil then
														if not HasLightningBolt(true) then
															local targetLocation

															if workspace:FindFirstChild("Map") then
																local sky = workspace.Map:FindFirstChild("Sky")

																if sky then
																	targetLocation = (
																		sky:GetPivot() + Vector3.new(0, 350, 0)
																	)
																		or CFrame.new(-4450, 1000, -500)
																else
																	targetLocation = CFrame.new(-4450, 1000, -500)
																end
															else
																targetLocation = CFrame.new(-4450, 1000, -500)
															end

															local clockStamp = os.clock()
															local initialCounterTarget = nil

															while true do
																if HasLightningBolt(true) then
																	initialCounterTarget = 1
																else
																	if (os.clock() - clockStamp) < 120 then
																		local humanoid = LocalPlayer.Character
																			and LocalPlayer.Character:FindFirstChildOfClass(
																				"Humanoid"
																			)

																		if humanoid then
																			if humanoid.Health <= 0 then
																				initialCounterTarget = 2
																				break
																			else
																				local spatialTarget =
																					collectElectroLightningParts()[1]

																				if spatialTarget then
																					local position =
																						spatialTarget.Position
																					local targetLocationCurrent = spatialTarget.CFrame
																						+ Vector3.new(0, 3, 0)
																					SetTask(
																						"MainTask",
																						"Electro - Flying to Electric Cloud"
																					)
																					TweenController.Create(
																						targetLocationCurrent,
																						true
																					)
																					local clockStampCurrent = os.clock()

																					while
																						CaculateDistance(
																							targetLocationCurrent
																						) > 18
																					do
																						if
																							(
																								os.clock()
																								- clockStampCurrent
																							)
																							< 20
																						then
																							if
																								not TweenController.Playing
																							then
																								if
																									CaculateDistance(
																										targetLocationCurrent
																									)
																									> 18
																								then
																									TweenController.Create(
																										targetLocationCurrent,
																										true
																									)
																								end
																							end

																							task.wait(0.1)
																							continue
																						end

																						break
																					end

																					SetTask(
																						"MainTask",
																						"Electro - Attacking Electric Cloud"
																					)
																					local clockStampTarget = os.clock()
																					local startedClock = nil

																					while
																						not HasLightningBolt(true)
																						and (
																							(
																								os.clock()
																								- clockStampTarget
																							)
																							< 10
																						)
																					do
																						local humanoidComp = LocalPlayer.Character
																							and LocalPlayer.Character:FindFirstChildOfClass(
																								"Humanoid"
																							)
																						if
																							not humanoidComp
																							or (
																								humanoidComp.Health
																								<= 0
																							)
																						then
																							break
																						end

																						if spatialTarget.Parent then
																							position =
																								spatialTarget.Position
																						end

																						local parent = (
																							spatialTarget.Parent
																							and spatialTarget
																						)
																							or nil
																						local cloudPieces =
																							workspace:FindFirstChild(
																								"CloudPieces"
																							)

																						if cloudPieces then
																							for _, child in
																								ipairs(
																									cloudPieces:GetChildren()
																								)
																							do
																								if
																									(
																										(
																											child:IsA(
																												"BasePart"
																											)
																											and child.Parent
																										)
																										and (
																											(
																												child.Position
																												- position
																											).Magnitude
																											<= 180
																										)
																									)
																									and not parent
																								then
																									parent = child
																								end
																							end
																						end

																						if parent then
																							TweenController.Hovering =
																								true
																							TweenController.HoverCFrame =
																								CFrame.new(
																									position
																										+ Vector3.new(
																											0,
																											3,
																											0
																										)
																								)

																							pcall(function()
																								FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call(
																									"Melee"
																								)
																								VirtualInputMgr:SendMouseButtonEvent(
																									0,
																									0,
																									0,
																									true,
																									game,
																									1
																								)
																								task.wait(0.04)
																								VirtualInputMgr:SendMouseButtonEvent(
																									0,
																									0,
																									0,
																									false,
																									game,
																									1
																								)
																							end)

																							task.wait(0.08)
																							startedClock = nil
																						else
																							startedClock = startedClock
																								or os.clock()
																							if
																								(
																									os.clock()
																									- startedClock
																								)
																								> 1
																							then
																								break
																							end
																							task.wait(0.1)
																						end
																					end

																					TweenController.Hovering = false
																					TweenController.HoverCFrame = nil
																					task.wait(0.2)
																				else
																					if
																						CaculateDistance(targetLocation)
																						> 250
																					then
																						SetTask(
																							"MainTask",
																							"Electro - Travelling to Charged Cloud Area"
																						)
																						TweenController.Create(
																							targetLocation,
																							true
																						)
																					else
																						SetTask(
																							"MainTask",
																							"Electro - Waiting for Charged Cloud"
																						)
																					end

																					task.wait(0.5)
																				end

																				continue
																			end
																		else
																			initialCounterTarget = 2
																			break
																		end
																	else
																		initialCounterTarget = 1
																		break
																	end
																end

																break
															end

															if initialCounterTarget ~= 1 then
																if initialCounterTarget == 2 then
																	TweenController.ClearGhost()
																	return
																end
																TweenController.ClearGhost()
																return
															end
														end

														if HasLightningBolt(true) then
															pcall(RefreshInventory)
														end

														FunctionsHandler.UtillyItemsActivitation:Set(
															"CurrentProgressLevel",
															nil
														)
														return
													end
												end
											end

											local Electro = resolveMeleeTrainerCFrame("Electro")

											if not Electro then
												Electro = MeleeNPCCFrameFallbacks.Electro
												if not Electro then
													SetTask("SideTask", "Electro | Mad Scientist not found")
													return
												end
											end

											SetTask("MainTask", "Electro - Travelling to Mad Scientist")
											TweenController.Create(Electro + Vector3.new(0, 5, 3))
											local clockStampPrimary = os.clock()

											while CaculateDistance(Electro) > 8 do
												if (os.clock() - clockStampPrimary) < 25 then
													if LocalPlayer.Character then
														local humanoid =
															LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

														if humanoid then
															if humanoid.Health <= 0 then
																TweenController.ClearGhost()
																return
															end

															if not TweenController.Playing then
																if CaculateDistance(Electro) > 8 then
																	TweenController.Create(
																		Electro + Vector3.new(0, 5, 3)
																	)
																end
															end

															task.wait(0.1)
															continue
														end

														TweenController.ClearGhost()
														return
													end

													TweenController.ClearGhost()
													return
												end

												break
											end

											if CaculateDistance(Electro) > 8 then
												SetTask("SideTask", "Electro | Mad Scientist out of reach")
												return
											end
											Remotes.CommF_:InvokeServer("AcceptElectroQuest")
											return
										end

										local dragonTalon = resolveMeleeTrainerCFrame("Dragon Talon")

										if dragonTalon then
											SetTask("MainTask", "Dragon Talon - Giving Fire Essence to Uzoth")
											TweenController.Create(dragonTalon + Vector3.new(0, 5, 3))
											local clockStamp = os.clock()

											while CaculateDistance(dragonTalon) > 45 do
												if (os.clock() - clockStamp) < 25 then
													if LocalPlayer.Character then
														local humanoid =
															LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

														if humanoid then
															if humanoid.Health <= 0 then
																TweenController.ClearGhost()
																return
															end

															if not TweenController.Playing then
																if CaculateDistance(dragonTalon) > 45 then
																	TweenController.Create(
																		dragonTalon + Vector3.new(0, 5, 3)
																	)
																end
															end

															task.wait(0.1)
															continue
														end

														TweenController.ClearGhost()
														return
													end

													TweenController.ClearGhost()
													return
												end

												break
											end
										end

										pcall(function()
											FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call(
												"Fire Essence"
											)
										end)

										local ok, result = pcall(function()
											return Remotes.CommF_:InvokeServer("BuyDragonTalon", true)
										end)

										task.wait(0.5)
										pcall(RefreshInventory)
										warn("DragonTalon essence check ok=", ok, "response=", result)

										local stillHasFireEssence = (ScriptStorage.Tools["Fire Essence"] ~= nil)
											or (LocalPlayer.Backpack ~= nil and LocalPlayer.Backpack:FindFirstChild(
												"Fire Essence"
											) ~= nil)
											or (
												LocalPlayer.Character ~= nil
												and LocalPlayer.Character:FindFirstChild("Fire Essence") ~= nil
											)

										if
											not stillHasFireEssence
											or (ok and result ~= nil and typeof(result) ~= "string")
										then
											IsFireEssenceGave = true
											DragonTalonNeedsFireEssence = false
											Report("Fire Essence Used")
										end

										FunctionsHandler.UtillyItemsActivitation:Set("CurrentProgressLevel", nil)
										return
									end

									local electricClaw = resolveMeleeTrainerCFrame("Electric Claw")
									local clockStampFallback, humanoid

									if electricClaw then
										SetTask("MainTask", "Electric Claw - Travelling to Previous Hero")
										TweenController.Create(electricClaw + Vector3.new(0, 5, 3))
										clockStampFallback = os.clock()

										while CaculateDistance(electricClaw) > 45 do
											if (os.clock() - clockStampFallback) < 25 then
												if LocalPlayer.Character then
													humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

													if humanoid then
														if humanoid.Health <= 0 then
															TweenController.ClearGhost()
															return
														end

														if not TweenController.Playing then
															if CaculateDistance(electricClaw) > 45 then
																TweenController.Create(
																	electricClaw + Vector3.new(0, 5, 3)
																)
															end
														end

														task.wait(0.1)
														continue
													end

													TweenController.ClearGhost()
													return
												end

												TweenController.ClearGhost()
												return
											end

											break
										end
									else
										electricClaw = MeleeNPCCFrameFallbacks["Electric Claw"]

										if electricClaw then
											SetTask("MainTask", "Electric Claw - Travelling to Previous Hero")
											TweenController.Create(electricClaw + Vector3.new(0, 5, 3))
											clockStampFallback = os.clock()

											while CaculateDistance(electricClaw) > 45 do
												if (os.clock() - clockStampFallback) < 25 then
													if LocalPlayer.Character then
														humanoid =
															LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

														if humanoid then
															if humanoid.Health <= 0 then
																TweenController.ClearGhost()
																return
															end

															if not TweenController.Playing then
																if CaculateDistance(electricClaw) > 45 then
																	TweenController.Create(
																		electricClaw + Vector3.new(0, 5, 3)
																	)
																end
															end

															task.wait(0.1)
															continue
														end

														TweenController.ClearGhost()
														return
													end

													TweenController.ClearGhost()
													return
												end

												break
											end
										end
									end

									local checkElectricClawQuestStateCurrent = checkElectricClawQuestState()
									warn("ElectricClaw state near npc=", checkElectricClawQuestStateCurrent)

									if
										checkElectricClawQuestStateCurrent ~= 1
										and checkElectricClawQuestStateCurrent ~= 2
									then
										local okStart, startRes = pcall(function()
											return Remotes.CommF_:InvokeServer("BuyElectricClaw", "Start")
										end)
										warn("ElectricClaw start ok=", okStart, "response=", startRes)
										SetTask("MainTask", "Electric Claw - Running to Mansion")

										local runStartClock = os.clock()
										TweenController.Create(ElectricClawMansionCFrame)
										while
											isSessionActive()
											and CaculateDistance(ElectricClawMansionCFrame) > 15
											and (os.clock() - runStartClock) < 28
										do
											local hum = LocalPlayer.Character
												and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
											if not hum or hum.Health <= 0 then
												TweenController.ClearGhost()
												return
											end
											if not TweenController.Playing then
												TweenController.Create(ElectricClawMansionCFrame)
											end
											task.wait(0.1)
										end

										task.wait(0.5)
										checkElectricClawQuestStateCurrent = scanWorldOriginLocations()
										warn("ElectricClaw state after mansion=", checkElectricClawQuestStateCurrent)

										if
											checkElectricClawQuestStateCurrent ~= 1
											and checkElectricClawQuestStateCurrent ~= 2
										then
											initialCounterCurrent = os.time() + 120
											FunctionsHandler.UtillyItemsActivitation:Set("CurrentProgressLevel", nil)
											SetTask("MainTask", "Electric Claw quest unavailable; continuing farm")
											return
										end
									end

									FunctionsHandler.UtillyItemsActivitation:Set("CurrentProgressLevel", nil)
									SetTask("MainTask", "Electric Claw quest completed; waiting for MeleeBuyController")
									return
								end

								Remotes.CommF_:InvokeServer("CakeScientist", "Check")
								ScriptStorage.Tools["Red Key"]:Destroy()
								return
							end

							local function requestOpenIceCastleLibrary()
								Remotes.CommF_:InvokeServer("OpenLibrary")
							end

							if pcall(requestOpenIceCastleLibrary) then
								local map = Services.Workspace:FindFirstChild("Map")

								if map then
									local iceCastle = map:FindFirstChild("IceCastle")

									if iceCastle then
										local hall = iceCastle:FindFirstChild("Hall")

										if hall then
											local libraryDoor = hall:FindFirstChild("LibraryDoor")

											if libraryDoor then
												local phoeyuDoor = libraryDoor:FindFirstChild("PhoeyuDoor")

												if phoeyuDoor then
													phoeyuDoor:Destroy()
												end
											end
										end
									end
								end

								task.wait(0.5)
								pcall(RefreshInventory)
								FunctionsHandler.UtillyItemsActivitation:Set("CurrentProgressLevel", nil)
								return
							end

							return
						end

						FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call("Water Key")

						pcall(function()
							Remotes.CommF_:InvokeServer("BuySharkmanKarate", true)
						end)

						task.wait(0.5)
						pcall(RefreshInventory)
						FunctionsHandler.UtillyItemsActivitation:Set("CurrentProgressLevel", nil)
						return
					end

					Remotes.CommF_:InvokeServer("OpenRengoku")
				end)
			end

			FunctionsHandler.Trevor:RegisterMethod("GetFruit", function()
				for _, backpackItem in pairs(ScriptStorage.Backpack) do
					if string.find(FruitIdToName(backpackItem.Name), " Fruit") then
						if backpackItem.Value then
							if backpackItem.Value > 1000000 then
								if backpackItem.Value < 2500000 then
									return backpackItem
								end
								continue
							end
						end
					end
				end
			end)

			local trevorLastCheckUnix = 0

			FunctionsHandler.Trevor:RegisterMethod("Refresh", function()
				if FunctionsHandler.Trevor:Get("IsCompleted") then
					return
				end
				if (os.time() - trevorLastCheckUnix) < 2 then
					return
				end
				if (ScriptStorage.PlayerData.Level or 0) < 1100 then
					return
				end

				trevorLastCheckUnix = os.time()
				local candidateFruit = FunctionsHandler.Trevor.Methods.GetFruit:Call()
				if candidateFruit then
					FunctionsHandler.Trevor:Set("Fruit", candidateFruit)
				end

				if not FunctionsHandler.Trevor:Get("IsCompleted") then
					local okTalk, talkRes = pcall(function()
						return Remotes.CommF_:InvokeServer("TalkTrevor", "1")
					end)
					if okTalk and talkRes == 0 then
						FunctionsHandler.Trevor:Set("IsCompleted", true)
					end
				end

				if FunctionsHandler.Trevor:Get("IsCompleted") then
					return false
				end
				return candidateFruit
			end)

			FunctionsHandler.Trevor:RegisterMethod("Start", function()
				local targetFruit = FunctionsHandler.Trevor:Get("Fruit")
				if not targetFruit or not targetFruit.Name then
					return
				end
				FunctionsHandler.Trevor:Set("Fruit", nil)
				table.insert(ScriptStorage.IgnoreStoreFruits, targetFruit.Name)
				Remotes.CommF_:InvokeServer("LoadFruit", targetFruit.Name)
				task.wait(0.2)
				FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call(FruitIdToName(targetFruit.Name))
				Remotes.CommF_:InvokeServer("TalkTrevor", "1")
				Remotes.CommF_:InvokeServer("TalkTrevor", "2")
				Remotes.CommF_:InvokeServer("TalkTrevor", "3")
				task.wait(1)
				FunctionsHandler.Trevor:Set("IsCompleted", true)
			end)

			FunctionsHandler.ThirdSeaPuzzle:RegisterMethod("Refresh", function()
				if (ScriptStorage.PlayerData.Level or 0) < 1500 or SeaIndex ~= 2 then
					return
				end
				if FunctionsHandler.ThirdSeaPuzzle:Get("State") == nil then
					local zProgress = Remotes.CommF_:InvokeServer("ZQuestProgress", "Check")
					FunctionsHandler.ThirdSeaPuzzle:Set("State", zProgress == 0)
				end
				return FunctionsHandler.ThirdSeaPuzzle:Get("State")
			end)

			FunctionsHandler.ThirdSeaPuzzle:RegisterMethod("Start", function()
				if not FunctionsHandler.ThirdSeaPuzzle:Get("State") then
					return
				end
				repeat
					task.wait(1)
					Remotes.CommF_:InvokeServer("ZQuestProgress", "Begin")
				until CaculateDistance(Vector3.new(0, 0, 0)) > 20000 or not isSessionActive()

				local battleStart = os.clock()
				while isSessionActive() and (os.clock() - battleStart) < 45 do
					CombatController.Attack("rip_indra")
					local okCheck, checkState = pcall(function()
						return Remotes.CommF_:InvokeServer("ZQuestProgress", "Check")
					end)
					if okCheck and checkState == 1 then
						pcall(function()
							Remotes.CommF_:InvokeServer("TravelZou")
						end)
						return
					end
					task.wait(0.2)
				end
				pcall(function()
					Remotes.CommF_:InvokeServer("TravelZou")
				end)
			end)

			FunctionsHandler.Yama:RegisterMethod("Refresh", function()
				if SeaIndex ~= 3 then
					return
				end

				if ScriptStorage.Backpack.Yama then
					return
				end

				if not FunctionsHandler.Yama:Get("EliteCount") then
					FunctionsHandler.Yama:Set("EliteCount", Remotes.CommF_:InvokeServer("EliteHunter", "Progress"))
				end

				if FunctionsHandler.Yama:Get("EliteCount") >= 30 then
					return true
				end
			end)

			FunctionsHandler.Yama:RegisterMethod("Start", function()
				if game:GetService("ReplicatedStorage"):FindFirstChild("FakeIslands") then
					local waterfall = game:GetService("ReplicatedStorage").FakeIslands:FindFirstChild("Waterfall")

					if waterfall then
						TweenController.Create(waterfall:GetModelCFrame())
					end
				end

				local clockStamp = os.clock()

				while true do
					if
						not (
							workspace.Map:FindFirstChild("Waterfall")
							and workspace.Map.Waterfall:FindFirstChild("SealedKatana")
						)
					then
						if (os.clock() - clockStamp) < 25 then
							task.wait(0.1)
							continue
						end
					end

					break
				end

				if workspace.Map:FindFirstChild("Waterfall") then
					if workspace.Map.Waterfall:FindFirstChild("SealedKatana") then
						if workspace.Map.Waterfall.SealedKatana:FindFirstChild("Hitbox") then
							if workspace.Map.Waterfall.SealedKatana.Hitbox:FindFirstChild("ClickDetector") then
								fireclickdetector(workspace.Map.Waterfall.SealedKatana.Hitbox.ClickDetector)
								return
							end
						end
					end
				end
			end)

			FunctionsHandler.PirateRaid:RegisterMethod("Refresh", function()
				local Senque = FunctionsHandler.PirateRaid:Get("Senque")

				if Senque then
					if (os.time() - Senque) >= 500 then
						return false
					end
					local enemies = workspace:FindFirstChild("Enemies")
					local isActiveState = false

					if enemies then
						for _, child in ipairs(enemies:GetChildren()) do
							local humanoidRootPart = child:FindFirstChild("HumanoidRootPart")
							local humanoid = child:FindFirstChild("Humanoid")

							if humanoidRootPart then
								if humanoid then
									if humanoid.Health > 0 then
										if
											(humanoidRootPart.Position - Vector3.new(
												-5543.53271484375,
												313.8006286621094,
												-2964.258544921875
											)).Magnitude <= 600
										then
											isActiveState = true
											break
										end
									end
								end
							end
						end
					end

					if (os.time() - Senque) > 25 then
						if not isActiveState then
							FunctionsHandler.PirateRaid:Set("Senque", 0)
							return false
						end
					end

					return true
				end

				return false
			end)

			FunctionsHandler.PirateRaid:RegisterMethod("Start", function()
				SetTask("MainTask", "Pirate Raid / Defending Castle on the Sea")
				local scopedValue = nil

				for _, iteratedElement in ipairs(GetMonAsSortedRange()) do
					local humanoidRootPart = iteratedElement:FindFirstChild("HumanoidRootPart")
					local humanoid = iteratedElement:FindFirstChild("Humanoid")

					if humanoidRootPart then
						if humanoid then
							if humanoid.Health > 0 then
								if
									(humanoidRootPart.Position - Vector3.new(
										-5543.53271484375,
										313.8006286621094,
										-2964.258544921875
									)).Magnitude <= 600
								then
									scopedValue = iteratedElement
									break
								else
									scopedValue = nil
								end
							else
								scopedValue = nil
							end
						else
							scopedValue = nil
						end
					else
						scopedValue = nil
					end
				end

				if scopedValue then
					CombatController.Attack(scopedValue.Name)
					return
				end

				if CaculateDistance(Vector3.new(-5543.53271484375, 313.8006286621094, -2964.258544921875)) > 100 then
					TweenController.Create(Vector3.new(-5543.53271484375, 313.8006286621094, -2964.258544921875))
					local clockStamp = os.clock()

					while
						CaculateDistance(Vector3.new(-5543.53271484375, 313.8006286621094, -2964.258544921875)) > 100
					do
						if (os.clock() - clockStamp) < 20 then
							if LocalPlayer.Character then
								local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

								if humanoid then
									if humanoid.Health <= 0 then
										TweenController.ClearGhost()
										return
									end

									if not TweenController.Playing then
										if
											CaculateDistance(
												Vector3.new(-5543.53271484375, 313.8006286621094, -2964.258544921875)
											) > 100
										then
											TweenController.Create(
												Vector3.new(-5543.53271484375, 313.8006286621094, -2964.258544921875)
											)
										end
									end

									task.wait(0.1)
									continue
								end

								TweenController.ClearGhost()
								return
							end

							TweenController.ClearGhost()
							return
						end

						break
					end
				else
					task.wait(1)
					local Senque = FunctionsHandler.PirateRaid:Get("Senque")

					if Senque then
						if (os.time() - Senque) > 25 then
							FunctionsHandler.PirateRaid:Set("Senque", 0)
						end

						return
					end
				end
			end)

			CheckFullMoon = function(primaryArg)
				if Lighting.Sky.MoonTextureId ~= "http://www.roblox.com/asset/?id=9709149431" then
					return
				end

				if primaryArg then
					return true
				end
				local isCheckPassed = Lighting.ClockTime > 18
				if isCheckPassed then
					return isCheckPassed
				end
				return Lighting.ClockTime < 5
			end

			FunctionsHandler.SoulGuitar:RegisterMethod("Refresh", function()
				if Config.SoulGuitar then
					if ScriptStorage.PlayerData.Level < MaxLevel then
						return
					end

					if not ScriptStorage.MeleesOwned.Godhuman then
						if not ScriptStorage.Backpack.Godhuman then
							if not ScriptStorage.Tools.Godhuman then
								local godhuman = ScriptStorage.Melees.Godhuman
								if not godhuman then
									return
								end

								if godhuman <= 0 then
									return
								end
							end
						end
					end

					if ScriptStorage.Backpack["Skull Guitar"] then
						return
					end

					if ScriptStorage.PlayerData.Level < 2300 then
						return
					end
					local count = (ScriptStorage.Backpack.Ectoplasm or { Count = 0 }).Count
					local countCurrent = (ScriptStorage.Backpack.Bones or { Count = 0 }).Count
					if count < 250 then
						return 1
					end

					if ScriptStorage.Backpack["Dark Fragment"] then
						if SeaIndex ~= 3 then
							return
						end
						SoulGuitarProcess = Remotes.CommF_:InvokeServer("GuitarPuzzleProgress", "Check")

						if SoulGuitarProcess then
							if SoulGuitarProcess.Swamp then
								if SoulGuitarProcess.Gravestones then
									if SoulGuitarProcess.Ghost then
										if SoulGuitarProcess.Trophies then
											if SoulGuitarProcess.Pipes then
												if countCurrent >= 500 then
													if not ScriptStorage.Backpack["Skull Guitar"] then
														return 8
													end
												end

												return
											end

											return 6
										end

										return 5
									end

									return 4
								end

								return 3
							end

							return 2
						end

						Remotes.CommF_:InvokeServer("gravestoneEvent", 2)
						if CheckFullMoon() then
							return 7
						end
						SetTask("MainTask", "Hopping for full moon ( soul guitar )")
						Hop("Moon")
						return 7
					end

					return 9
				end
			end)

			FunctionsHandler.SoulGuitar:RegisterMethod("Start", function(primaryArg)
				if primaryArg ~= 7 then
					if primaryArg ~= 1 then
						if primaryArg ~= 9 then
							if primaryArg ~= 2 then
								if primaryArg == 3 then
									local hauntedCastle_ = workspace.Map["Haunted Castle"]
									local targetCFrame = CFrame.new(-8800, 178, 6033)
									SetTask("MainTask", "Soul Guitar task 2 / 5: completing placards")
									TweenController.Create(targetCFrame)
									local clockStamp = os.clock()

									while CaculateDistance(targetCFrame) > 10 do
										if (os.clock() - clockStamp) < 20 then
											task.wait(0.1)
											continue
										end
										break
									end

									for k, child in pairs(hauntedCastle_:GetChildren()) do
										fireclickdetector(hauntedCastle_[k][child].ClickDetector)
									end
								elseif primaryArg ~= 4 then
									if primaryArg ~= 5 then
										if primaryArg ~= 6 then
											if primaryArg == 8 then
												Remotes.CommF_:InvokeServer("soulGuitarBuy")
											end
										else
											for k, pipeItem in pairs(Pipes) do
												pcall(function()
													local colorPart =
														workspace.Map["Haunted Castle"]["Lab Puzzle"].ColorFloor.Model[k]
													if
														colorPart
														and colorPart:FindFirstChild("ClickDetector")
														and colorPart.BrickColor.Name ~= pipeItem
													then
														local clickStart = os.clock()
														while
															isSessionActive()
															and colorPart.Parent
															and colorPart.BrickColor.Name ~= pipeItem
															and (os.clock() - clickStart) < 10
														do
															fireclickdetector(colorPart.ClickDetector)
															task.wait(0.12)
														end
													end
												end)
											end

											Remotes.CommF_:InvokeServer("soulGuitarBuy")
										end
									elseif
										CaculateDistance(
											CFrame.new(-9530.0126953125, 6.104853630065918, 6054.83349609375)
										) > 30
									then
										TweenController.Create(
											CFrame.new(-9530.0126953125, 6.104853630065918, 6054.83349609375)
										)
									else
										local tablet = workspace.Map["Haunted Castle"]:FindFirstChild("Tablet")
										if tablet then
											for _, segmentName in ipairs(BlankTablets) do
												local segmentObj = tablet:FindFirstChild(segmentName)
												if
													segmentObj
													and segmentObj:FindFirstChild("Line")
													and segmentObj:FindFirstChild("ClickDetector")
												then
													local alignStart = os.clock()
													while
														isSessionActive()
														and segmentObj.Line.Rotation.Z ~= 0
														and (os.clock() - alignStart) < 10
													do
														fireclickdetector(segmentObj.ClickDetector)
														task.wait(0.15)
													end
												end
											end

											for slotKey, trophyName in pairs(Trophy) do
												local trophyObj =
													workspace.Map["Haunted Castle"].Trophies.Quest:FindFirstChild(
														trophyName
													)
												local trophyHandle = trophyObj and trophyObj:FindFirstChild("Handle")
												local tabletSlot = tablet:FindFirstChild(slotKey)
												if
													trophyHandle
													and tabletSlot
													and tabletSlot:FindFirstChild("Line")
													and tabletSlot:FindFirstChild("ClickDetector")
												then
													local rotMatrixEntry = tostring(trophyHandle.CFrame):split(", ")[4]
													local expectedAngle = (
														rotMatrixEntry == "1" or rotMatrixEntry == "-1"
													)
															and "90"
														or "180"
													local rotateStart = os.clock()
													while
														isSessionActive()
														and not string.find(
															tostring(tabletSlot.Line.Rotation.Z),
															expectedAngle
														)
														and (os.clock() - rotateStart) < 12
													do
														fireclickdetector(tabletSlot.ClickDetector)
														task.wait(0.15)
													end
												end
											end
										end
									end
								else
									Remotes.CommF_:InvokeServer("GuitarPuzzleProgress", "Ghost")
								end

								return
							end

							SoulGuitarStageTTL = SoulGuitarStageTTL or 0
							local lastestTime = SoulGuitarLastTick

							if os.time() ~= lastestTime then
								SoulGuitarStageTTL = SoulGuitarStageTTL + 1
								SoulGuitarLastTick = os.time()
							end

							if SoulGuitarStageTTL > 60 then
								return Hop("LOMGGGGGGGG SG 1")
							end
							local collectedItemsCurrent = {}

							for _, childInst in Services.Workspace.Enemies:GetChildren() do
								if childInst.name == "Living Zombie" then
									table.insert(collectedItemsCurrent, childInst)
								end
							end

							if #collectedItemsCurrent < 6 then
								SetTask("MainTask", "Soul Guitar task 1 / 5: waiting until entity spawn")
								TweenController.Create(
									ScriptStorage.MobRegions["Living Zombie"][1] + Vector3.new(0, 30, 0)
								)
								return
							end

							local unixTimestampCurrent = os.time()

							for k, characterModel in pairs(collectedItemsCurrent) do
								while task.wait() do
									if characterModel.Humanoid.Health > 7000 then
										SetTask("MainTask", "Soul Guitar task 1 / 5: Hit mob " .. (k .. " / 6"))
										FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call("Melee")

										if (os.time() - unixTimestampCurrent) > 60 then
											Hop("So long nerds")
										end

										TweenController.Create(
											characterModel.HumanoidRootPart.CFrame + Vector3.new(0, 50, 0)
										)
										FastAttack:Attack()
										continue
									end

									break
								end
							end

							SetTask("MainTask", "Soul Guitar task 1 / 5: Attack")

							while workspace.Enemies:FindFirstChild("Living Zombie") do
								if task.wait() then
									if (os.time() - unixTimestampCurrent) > 60 then
										Hop("So long nerds")
									end

									CombatController.Attack("Living Zombie")
									continue
								end

								break
							end

							return
						end

						if SeaIndex ~= 2 then
							SetTask("MainTask", "Teleport to second sea to farm ectoplasm")
							return Remotes.CommF_:InvokeServer("TravelDressrosa")
						end
						SetTask("MainTask", "Sea 2 | Get DarkFragments")
						return
					end

					if SeaIndex ~= 2 then
						SetTask("MainTask", "Teleport to second sea to farm ectoplasm")
						return Remotes.CommF_:InvokeServer("TravelDressrosa")
					end
					SetTask("MainTask", "Farming ectoplasms for soul guitar")
					CombatController.Attack({ "Ship Deckhand", "Ship Engineer", "Ship Steward", "Ship Officer" })
					return
				end

				local targetCFrameCurrent = CFrame.new(-8654, 140, 6167)
				TweenController.Create(targetCFrameCurrent)
				local clockStampCurrent = os.clock()

				while CaculateDistance(targetCFrameCurrent) > 5 do
					if (os.clock() - clockStampCurrent) < 20 then
						task.wait(0.1)
						continue
					end
					break
				end

				SoulGuitarProcess = Remotes.CommF_:InvokeServer("gravestoneEvent", 2, true)
			end)

			FunctionsHandler.Tushita:RegisterMethod("Refresh", function()
				if ScriptStorage.Backpack.Tushita then
					return
				end

				if ScriptStorage.PlayerData.Level < 2000 then
					return
				end

				if SeaIndex ~= 3 then
					return
				end
				TushitaProgress = TushitaProgress or Remotes.CommF_:InvokeServer("TushitaProgress")

				if TushitaProgress.OpenedDoor then
					if ScriptStorage.Enemies.Longma then
						TushitaProgress = nil
						return 2
					end
				elseif ScriptStorage.Enemies["rip_indra True Form"] then
					TushitaProgress = nil
					return 1
				end
			end)

			FunctionsHandler.Tushita:RegisterMethod("Start", function(primaryArg)
				if primaryArg ~= 1 then
					if primaryArg ~= 2 then
						return
					end
					CombatController.Attack("Longma")
					return
				end

				if ScriptStorage.Tools["Holy Torch"] then
					local questTorches = workspace.Map.Turtle.QuestTorches

					for i = 1, 5 do
						local firstChild = questTorches:FindFirstChild("Torch" .. i)

						if firstChild then
							TweenController.Create(firstChild.CFrame)
							local clockStamp = os.clock()

							while firstChild.Parent do
								if
									not (
										(
											firstChild:FindFirstChild("Particles")
											and firstChild.Particles:FindFirstChild("Main")
										) and firstChild.Particles.Main.Enabled
									)
								then
									if (os.clock() - clockStamp) < 15 then
										task.wait(0.1)
										continue
									end
								end

								break
							end
						end
					end

					return
				end

				FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call("Holy Torch")
				if TweenController.Playing then
					return
				end
				TweenController.Create(CFrame.new(5714, 20, 256))
			end)

			FunctionsHandler.CursedDualKatana:RegisterMethod("Refresh", function()
				if Config.CursedDualKatana then
					if ScriptStorage.PlayerData.Level < MaxLevel then
						return
					end

					if not ScriptStorage.MeleesOwned.Godhuman then
						if not ScriptStorage.Backpack.Godhuman then
							if not ScriptStorage.Tools.Godhuman then
								local godhuman = ScriptStorage.Melees.Godhuman
								if not godhuman then
									return
								end

								if godhuman <= 0 then
									return
								end
							end
						end
					end

					local backpack = ScriptStorage.Backpack
					if ScriptStorage.PlayerData.Level < 2200 then
						return
					end

					if backpack["Cursed Dual Katana"] then
						return
					end

					if backpack.Tushita then
						if backpack.Tushita.Mastery < 350 then
							return
						end

						if backpack.Yama then
							if backpack.Yama.Mastery < 350 then
								return
							end

							if SeaIndex ~= 3 then
								return
							end
							local response = (CdkQuestProgress or Remotes.CommF_:InvokeServer("CDKQuest", "Progress"))
								or "uwu"

							if response ~= "uwu" then
								if workspace.Map.Turtle.Cursed:FindFirstChild("Breakable") then
									return { "break" }
								end
								local configRecord = { Good = "Tushita", Evil = "Yama" }

								if response.Good == 4 then
									if response.Evil == 4 then
										return { "burn 2" }
									end
								end

								if response.Good ~= 3 then
									if response.Evil ~= 3 then
										if response.Opened then
											for _, trialType in ipairs({ "Good", "Evil" }) do
												local trialStage = response[trialType]
												if trialStage ~= -2 and trialStage ~= 3 and configRecord[trialType] then
													Remotes.CommF_:InvokeServer("LoadItem", configRecord[trialType])
													Remotes.CommF_:InvokeServer("CDKQuest", "StartTrial", trialType)
													SetTask(
														"MainTask",
														"Cursed Dual Katana - "
															.. tostring(configRecord[trialType])
															.. " "
															.. tostring(trialType)
													)
													break
												end
											end
										end

										local cdkCache = ScriptStorage.CdkCache

										if cdkCache then
											local questBranch = cdkCache[1]
											local questStep = cdkCache[2]
											if questBranch == "Good" then
												if questStep == 2 then
													SetTask("SideTask", "CDK Quest / Waiting until pirate raid started")
													return
												elseif questStep == 3 and not ScriptStorage.Enemies["Cake Queen"] then
													Hop("Cake Queen Find")
													SetTask(
														"SideTask",
														"CDK Quest / Waiting until Cake Queen boss spawned"
													)
													return
												end
											elseif questBranch == "Evil" then
												if questStep == 3 and not ScriptStorage.Enemies["Soul Reaper"] then
													ForceToRollBone = true
													return
												end
											end
											return cdkCache
										end

										return
									end
								end

								return { "burn" }
							end

							return
						end

						return
					end

					return
				end
			end)

			FunctionsHandler.CursedDualKatana:RegisterMethod("GetHazeMon", function()
				local collectedItemsCurrent = {}

				for _, childInst in LocalPlayer.QuestHaze:GetChildren() do
					if childInst.Value > 0 then
						table.insert(collectedItemsCurrent, childInst)
					end
				end

				table.sort(collectedItemsCurrent, function(leftItem, rightItem)
					return CaculateDistance(leftItem:GetAttribute("Position"))
						< CaculateDistance(rightItem:GetAttribute("Position"))
				end)

				return tostring(collectedItemsCurrent[1])
			end)

			do
				local cursedDualKatana = FunctionsHandler.CursedDualKatana
				local registerMethod = cursedDualKatana.RegisterMethod

				local function igniteHellDimensionTorches(primaryArg)
					local childName = string.gsub(primaryArg, " ", "")
					local unixTimestampCurrent = os.time()

					while true do
						local torchEnabledTime = TorchEnabledTime

						if (os.time() - torchEnabledTime) >= 10 then
							if (os.time() - unixTimestampCurrent) <= 60 then
								task.wait(0.2)
								continue
							end
						end

						break
					end

					while true do
						task.wait()
						local containerFolder = workspace.Map:WaitForChild(childName, 10)

						if containerFolder then
							for _, childInst in containerFolder:GetChildren() do
								if childInst and string.find(childInst.Name, "Torch") then
									local prompt = childInst:FindFirstChild("ProximityPrompt")
									local activeChar = LocalPlayer.Character
									local activeRoot = activeChar and activeChar:FindFirstChild("HumanoidRootPart")
									if prompt and prompt.Enabled and activeRoot then
										activeRoot.CFrame = childInst.CFrame
										prompt.HoldDuration = 0
										task.wait(1)
										local virtualInput = game:GetService("VirtualInputManager")
										virtualInput:SendKeyEvent(true, "E", 0, game)
										virtualInput:SendKeyEvent(false, "E", 0, game)
										if prompt.Parent then
											fireproximityprompt(prompt)
										end
									end
								end

								for _, childInstCurrent in workspace.Enemies:GetChildren() do
									local humanoidRootPart = childInstCurrent:FindFirstChild("HumanoidRootPart")
									local humanoid = childInstCurrent:FindFirstChild("Humanoid")

									if humanoidRootPart then
										if humanoid then
											if CaculateDistance(humanoidRootPart.CFrame) < 1000 then
												CombatController.Attack(childInstCurrent.Name)
											end
										end
									end
								end
							end

							ExitDoor = containerFolder:FindFirstChild("Exit")

							if ExitDoor then
								PortalBrick = tostring(ExitDoor.BrickColor)
							end
						else
						end

						if PortalBrick ~= "Olivine" then
							if PortalBrick ~= "Cloudy grey" then
								continue
							end
						end

						break
					end

					if ExitDoor then
						TweenController.Create(ExitDoor.CFrame + Vector3.new(0, 3, 0))
					end

					while true do
						local doneCdkTick = DoneCdkTick

						if (os.time() - doneCdkTick) > 15 then
							task.wait(0.2)
						else
							break
						end
					end

					Hop("Rejoin")
				end

				registerMethod(cursedDualKatana, "DoDimension", igniteHellDimensionTorches)
			end

			FunctionsHandler.CursedDualKatana:RegisterMethod("Start", function(primaryArg)
				if primaryArg[1] ~= "break" then
					if primaryArg[1] ~= "burn 2" then
						if primaryArg[1] ~= "burn" then
							if primaryArg[1] ~= "Evil" then
								if primaryArg[2] ~= 1 then
									if primaryArg[2] ~= 3 then
										return
									end

									while true do
										task.wait()
										CombatController.Attack("Cake Queen")
										local torchEnabledTime = TorchEnabledTime

										if (os.time() - torchEnabledTime) < 10 then
											break
										elseif not ScriptStorage.Enemies["Cake Queen"] then
											break
										end
									end
									local activeChar = LocalPlayer.Character
									local activeRoot = activeChar and activeChar:FindFirstChild("HumanoidRootPart")
									if activeRoot then
										TweenController.Create(activeRoot.CFrame)
									end
									Report("Cake Queen")
									FunctionsHandler.CursedDualKatana.Methods.DoDimension.Callback("Heavenly Dimension")
									CdkQuestProgress = nil
									return
								end

								for _, childInst in game.ReplicatedStorage.NPCs:GetChildren() do
									if childInst.Name == "Luxury Boat Dealer" then
										while isSessionActive() do
											task.wait()
											if (os.time() - DoneCdkTick) < 15 then
												return
											else
												local dealerChar = LocalPlayer.Character
												local dealerRoot = dealerChar
													and dealerChar:FindFirstChild("HumanoidRootPart")
												if dealerRoot then
													dealerRoot.CFrame = childInst:GetModelCFrame()
												end
												RealNPC = nil

												for _, childInstCurrent in workspace.NPCs:GetChildren() do
													local getModelCFrame = childInst.GetModelCFrame
													if
														CaculateDistance(
															childInstCurrent:GetModelCFrame(),
															getModelCFrame(childInst)
														) < 20
													then
														RealNPC = childInstCurrent
														break
													end
												end

												if CaculateDistance(childInst:GetModelCFrame()) < 5 then
													if RealNPC then
														break
													end
												end
											end
										end

										Remotes.CommF_:InvokeServer("CDKQuest", "BoatQuest", RealNPC)
										CdkQuestProgress = nil
										return
									end
								end

								CdkQuestProgress = nil
								return
							end

							if primaryArg[2] ~= 1 then
								if primaryArg[2] ~= 2 then
									if primaryArg[2] == 3 then
										Report("found cdk yama 3")
										local soulReaper = ScriptStorage.Enemies["Soul Reaper"]

										if soulReaper then
											TweenController.Create(soulReaper:GetModelCFrame())
										end

										local clockStamp = os.clock()

										if soulReaper then
											while soulReaper.Parent do
												local torchEnabledTime = TorchEnabledTime

												if (os.time() - torchEnabledTime) >= 100 then
													if (os.clock() - clockStamp) < 30 then
														if
															FunctionsHandler.RaidController.Methods.GetCurrentRaidIsland:Call()
														then
															pcall(function()
																LocalPlayer.Character.Humanoid.Health = 0
															end)
														end

														task.wait(0.1)
														continue
													end
												end

												break
											end
										end

										if not ScriptStorage.Enemies["Soul Reaper"] then
											return
										end
										FunctionsHandler.CursedDualKatana.Methods.DoDimension.Callback("Hell Dimension")
										CdkQuestProgress = nil
									end
								else
									CombatController.Attack(FunctionsHandler.CursedDualKatana.Methods.GetHazeMon:Call())
									CdkQuestProgress = nil
								end
							else
								local forestPirate = ScriptStorage.Enemies["Forest Pirate"]
								local create = TweenController.Create
								local cFrame

								if forestPirate then
									cFrame = forestPirate.HumanoidRootPart.CFrame
										or ScriptStorage.MobRegions["Forest Pirate"][0]
								else
									cFrame = ScriptStorage.MobRegions["Forest Pirate"][0]
									create(cFrame)
									CdkQuestProgress = nil
									return
								end

								create(cFrame)
								CdkQuestProgress = nil
							end

							return
						end

						for i = 1, 3 do
							local firstChild = workspace.Map.Turtle.Cursed:FindFirstChild("Pedestal" .. i)

							if firstChild then
								if firstChild:FindFirstChild("ProximityPrompt") then
									if firstChild.ProximityPrompt.Enabled then
										TweenController.Create(firstChild.CFrame)
										local clockStamp = os.clock()

										while CaculateDistance(firstChild.CFrame) >= 5 do
											if (os.clock() - clockStamp) < 15 then
												task.wait(0.1)
												continue
											end
											break
										end

										fireproximityprompt(firstChild.ProximityPrompt)
										task.wait(3)

										local function forceCharacterRespawnForCdk()
											local character = LocalPlayer.Character
											character.Humanoid.Health = 0
										end

										pcall(forceCharacterRespawnForCdk)
									end
								end
							end

							CdkQuestProgress = nil
						end

						return
					end

					if workspace.Map.Turtle.Cursed.Pedestal3.ProximityPrompt.Enabled then
						fireproximityprompt(workspace.Map.Turtle.Cursed.Pedestal3.ProximityPrompt)
						task.wait(1)

						pcall(function()
							LocalPlayer.Character.Humanoid.Health = 0
						end)

						task.wait(10)
						return
					end

					CDKAttempts = (CDKAttempts or 0) + 1
					TweenController.Create(CFrame.new(-12341.66796875, 603.3455810546875, -6550.6064453125))
					task.wait(5)

					pcall(function()
						LocalPlayer.Character.Humanoid.Health = 0
					end)

					task.wait(5)

					if CDKAttempts > 5 then
						Hop("CDK Stuck")
					end

					CdkQuestProgress = nil
					return
				end

				TweenController.Create(workspace.Map.Turtle.Cursed.Breakable.CFrame)
				Remotes.CommF_:InvokeServer("CDKQuest", "OpenDoor")
				Remotes.CommF_:InvokeServer("CDKQuest", "OpenDoor", true)
				workspace.Map.Turtle.Cursed.Breakable:Destroy()
				CdkQuestProgress = nil
			end)

			do
				local notificationRegistry = { Listeners = {} }
				TorchEnabledTime = 0
				DoneCdkTick = 0

				local function notificationCallBack(primaryArg)
					for k, listenerItem in pairs(notificationRegistry.Listeners) do
						if string.find(string.lower(primaryArg), string.lower(k)) then
							listenerItem(primaryArg)
						end
					end
				end

				getgenv().NotificationCallBack = notificationCallBack

				notificationRegistry.RegisterNotifyListener = function(primaryArg, secondaryArg, tertiaryArg)
					notificationRegistry.Listeners[secondaryArg] = tertiaryArg
				end

				notificationRegistry:RegisterNotifyListener("go!", function()
					LastRaidAlert = os.time()
				end)

				notificationRegistry:RegisterNotifyListener("raid", function()
					LastRaidSecondaryAlert = os.time()
				end)

				notificationRegistry:RegisterNotifyListener("been spotted approaching", function()
					FunctionsHandler.PirateRaid:Set("Senque", os.time())
				end)

				notificationRegistry:RegisterNotifyListener("job", function()
					FunctionsHandler.PirateRaid:Set("Senque", 0)
				end)

				notificationRegistry:RegisterNotifyListener("level", function()
					AddPoint()
				end)

				notificationRegistry:RegisterNotifyListener("torch", function()
					TorchEnabledTime = os.time()
				end)

				notificationRegistry:RegisterNotifyListener("scroll reacts", function()
					DoneCdkTick = os.time()
				end)

				notificationRegistry:RegisterNotifyListener("elite", function()
					FunctionsHandler.Yama:Set("EliteCount", Remotes.CommF_:InvokeServer("EliteHunter", "Progress"))
				end)

				notificationRegistry:RegisterNotifyListener("the raid with", function()
					stopTween(false)
					TweenController.Hovering = false
					TweenController.HoverCFrame = nil
					markRaidDimensionEntered()
					if ScriptStorage.PlayerData.Level < MaxLevel then
						return
					end
					Remotes.CommF_:InvokeServer("Awakener", "Awaken")
				end)

				notificationRegistry:RegisterNotifyListener("quest completed", function()
					QuestController:RefreshQuest()
					task.wait()
					if QuestController:GetCurrentClaimQuest() then
						return
					end
					QuestController:MarkAsCompleted()
				end)

				if type(hookfunction) == "function" then
					pcall(function()
						local notificationModule = require(ReplicatedStorage:WaitForChild("Notification", 5))
						if
							notificationModule
							and type(notificationModule.new) == "function"
							and not _G.BananaNotificationHookInstalled
						then
							_G.BananaNotificationHookInstalled = true
							local originalNotificationNew
							originalNotificationNew = hookfunction(notificationModule.new, function(partA, partB, ...)
								local combinedMessage = tostring(partA or "") .. tostring(partB or "")
								if type(globalEnv.NotificationCallBack) == "function" then
									task.spawn(globalEnv.NotificationCallBack, combinedMessage)
								end
								return originalNotificationNew(partA, partB, ...)
							end)
						end
					end)
				end

				IfTableHaveIndex = function(targetTable)
					return (type(targetTable) == "table") and (next(targetTable) ~= nil)
				end

				ServerList = {}

				GetServers = function()
					if not httpRequest then
						return {}
					end
					local okResp, resp = pcall(httpRequest, {
						Url = string.format(
							"https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",
							game.PlaceId
						),
						Method = "GET",
					})
					if not okResp or type(resp) ~= "table" or not resp.Body then
						return {}
					end
					local okJson, parsed = pcall(HttpService.JSONDecode, HttpService, resp.Body)
					if not okJson or type(parsed) ~= "table" or type(parsed.data) ~= "table" then
						return {}
					end

					local freshServers = {}
					for _, srv in ipairs(parsed.data) do
						local jobId = srv and srv.id
						local playing = tonumber(srv.playing) or 0
						local maxPlayers = tonumber(srv.maxPlayers) or 12
						if
							jobId
							and tostring(jobId) ~= tostring(game.JobId)
							and playing > 0
							and playing < maxPlayers
						then
							freshServers[tostring(jobId)] = playing
						end
					end
					ServerList = freshServers
					return freshServers
				end

				task.spawn(function()
					while isSessionActive() do
						pcall(GetServers)
						task.wait(15)
					end
				end)

				Hop = function(maxPlayerThreshold)
					local maxAllowedPlayers = tonumber(maxPlayerThreshold) or 9
					if not next(ServerList) then
						pcall(GetServers)
					end

					for serverJobId, playerCount in pairs(ServerList) do
						if
							tostring(serverJobId) ~= tostring(game.JobId)
							and tonumber(playerCount)
							and tonumber(playerCount) <= maxAllowedPlayers
						then
							ServerList[serverJobId] = nil
							pcall(function()
								TeleportService:TeleportToPlaceInstance(game.PlaceId, serverJobId, LocalPlayer)
							end)
							task.wait(2.5)
						end
					end

					pcall(GetServers)
					for serverJobId in pairs(ServerList) do
						if tostring(serverJobId) ~= tostring(game.JobId) then
							pcall(function()
								TeleportService:TeleportToPlaceInstance(game.PlaceId, serverJobId, LocalPlayer)
							end)
							task.wait(2.5)
						end
					end
				end

				if Config.BlockAcc then
					local currentUserId = LocalPlayer.UserId
					local markerPartName = "ChuoiCon"
					local blockAccFolder = "BananaCatHubKaitunGodMax/BlockAcc"
					local blockAccFile = blockAccFolder .. "/servers.json"
					local consecutiveConflictTicks = 0
					local lastConflictHopUnix = 0

					ensureDirectoryPath("BananaCatHubKaitunGodMax")
					ensureDirectoryPath(blockAccFolder)

					local function syncCharacterBlockMarker()
						local char = LocalPlayer.Character
						if not char then
							return
						end
						local marker = char:FindFirstChild(markerPartName)
						if marker and not marker:IsA("BasePart") then
							marker:Destroy()
							marker = nil
						end
						if not marker then
							marker = Instance.new("Part")
							marker.Name = markerPartName
							marker.Size = Vector3.new(0.15, 0.15, 0.15)
							marker.Transparency = 1
							marker.Anchored = false
							marker.CanCollide = false
							marker.CanTouch = false
							marker.CanQuery = false
							marker.Massless = true
							marker.Parent = char
						end

						marker:SetAttribute("BananaCatBlockAcc", true)
						marker:SetAttribute("UserId", currentUserId)
						marker:SetAttribute("UserName", LocalPlayer.Name)
						marker:SetAttribute("JobId", game.JobId)
						marker:SetAttribute("UpdatedAt", os.time())

						local root = char:FindFirstChild("HumanoidRootPart")
						if root then
							marker.CFrame = root.CFrame
							local weld = marker:FindFirstChild("BananaCatBlockAccWeld")
							if not weld then
								weld = Instance.new("WeldConstraint")
								weld.Name = "BananaCatBlockAccWeld"
								weld.Parent = marker
							end
							if weld.Part0 ~= root or weld.Part1 ~= marker then
								weld.Part0 = root
								weld.Part1 = marker
							end
						end
					end

					local function writeAccountHeartbeatToFile()
						pcall(function()
							ensureDirectoryPath(blockAccFolder)
							local nowUnix = os.time()
							local stateTable = {}
							if isfile(blockAccFile) then
								local okRead, decoded = pcall(function()
									return HttpService:JSONDecode(readfile(blockAccFile))
								end)
								if okRead and type(decoded) == "table" then
									stateTable = decoded
								end
							end

							local accountsMap = (type(stateTable.Accounts) == "table") and stateTable.Accounts or {}
							for uidKey, entry in pairs(accountsMap) do
								if type(entry) ~= "table" or (nowUnix - (tonumber(entry.UpdatedAt) or 0)) > 25 then
									accountsMap[uidKey] = nil
								end
							end

							accountsMap[tostring(currentUserId)] = {
								UserId = currentUserId,
								UserName = LocalPlayer.Name,
								JobId = game.JobId,
								PlaceId = game.PlaceId,
								UpdatedAt = nowUnix,
							}
							writefile(
								blockAccFile,
								HttpService:JSONEncode({ UpdatedAt = nowUnix, Accounts = accountsMap })
							)
						end)
					end

					local function removeAccountFromFile()
						pcall(function()
							if isfile(blockAccFile) then
								local okRead, decoded = pcall(function()
									return HttpService:JSONDecode(readfile(blockAccFile))
								end)
								if okRead and type(decoded) == "table" and type(decoded.Accounts) == "table" then
									decoded.Accounts[tostring(currentUserId)] = nil
									writefile(blockAccFile, HttpService:JSONEncode(decoded))
								end
							end
						end)
					end

					local function hasInWorldAccountConflict()
						for _, otherPlayer in ipairs(Players:GetPlayers()) do
							if otherPlayer ~= LocalPlayer and otherPlayer.Character then
								local marker = otherPlayer.Character:FindFirstChild(markerPartName)
								if marker and marker:GetAttribute("BananaCatBlockAcc") == true then
									local otherId = tonumber(marker:GetAttribute("UserId"))
									local updatedUnix = tonumber(marker:GetAttribute("UpdatedAt")) or 0
									if
										otherId
										and otherId ~= currentUserId
										and (os.time() - updatedUnix) <= 25
										and otherId < currentUserId
									then
										return true
									end
								end
							end
						end
						return false
					end

					local function hasFileAccountConflict()
						local conflictDetected = false
						pcall(function()
							if isfile(blockAccFile) then
								local okRead, decoded = pcall(function()
									return HttpService:JSONDecode(readfile(blockAccFile))
								end)
								if okRead and type(decoded) == "table" and type(decoded.Accounts) == "table" then
									local nowUnix = os.time()
									for _, entry in pairs(decoded.Accounts) do
										if type(entry) == "table" then
											local otherId = tonumber(entry.UserId)
											if
												otherId
												and otherId ~= currentUserId
												and entry.JobId == game.JobId
												and entry.PlaceId == game.PlaceId
												and (nowUnix - (tonumber(entry.UpdatedAt) or 0)) <= 25
												and otherId < currentUserId
											then
												conflictDetected = true
												return
											end
										end
									end
								end
							end
						end)
						return conflictDetected
					end

					registerCleanupCallback(removeAccountFromFile)

					task.spawn(function()
						while isSessionActive() do
							pcall(syncCharacterBlockMarker)
							pcall(writeAccountHeartbeatToFile)
							task.wait(4)
						end
					end)

					task.spawn(function()
						while isSessionActive() do
							local hasConflict = false
							pcall(function()
								hasConflict = hasInWorldAccountConflict() or hasFileAccountConflict()
								if hasConflict then
									consecutiveConflictTicks += 1
								else
									consecutiveConflictTicks = 0
								end
							end)

							if
								hasConflict
								and consecutiveConflictTicks >= 2
								and (os.time() - lastConflictHopUnix) > 20
							then
								lastConflictHopUnix = os.time()
								SetTask(
									"MainTask",
									"Hop Server - BlockAcc detected duplicate account (yielding to lower UserId)"
								)
								removeAccountFromFile()
								Hop(8)
								task.wait(8)
							end
							task.wait(4)
						end
					end)
				end

				Storage = { WRITE_DELAY = 1, Data = {}, Dirty = false }
				local storageFilePath = "BananaCatHubKaitunGodMax/.storage_u_" .. tostring(LocalPlayer.Name)

				Decode = function(jsonText)
					return HttpService:JSONDecode(jsonText)
				end

				Encode = function(luaTable)
					return HttpService:JSONEncode(luaTable)
				end

				Storage.Set = function(self, key, value)
					if self.Data[key] ~= value then
						self.Data[key] = value
						self.Dirty = true
					end
				end

				Storage.Get = function(self, key)
					return self.Data[key]
				end

				Storage.Save = function(self)
					if self.Dirty then
						ensureDirectoryPath("BananaCatHubKaitunGodMax")
						writefile(storageFilePath, Encode(self.Data))
						self.Dirty = false
					end
				end

				ensureDirectoryPath("BananaCatHubKaitunGodMax")
				if not isfile(storageFilePath) then
					pcall(writefile, storageFilePath, "{}")
				end
				pcall(function()
					local decoded = Decode(readfile(storageFilePath) or "{}")
					if type(decoded) == "table" then
						Storage.Data = decoded
					end
				end)

				task.spawn(function()
					while isSessionActive() do
						if Storage.Dirty then
							pcall(Storage.Save, Storage)
						end
						task.wait(Storage.WRITE_DELAY)
					end
				end)

				CreateTraceback("Initalize", "Initalizing script...")

				task.spawn(function()
					pcall(function()
						local pg = LocalPlayer:FindFirstChild("PlayerGui")
						local mainGui = pg and pg:FindFirstChild("Main")
						local settingsFrame = mainGui and mainGui:FindFirstChild("Settings")
						local buttons = settingsFrame and settingsFrame:FindFirstChild("Buttons")
						local fastModeBtn = buttons and buttons:FindFirstChild("FastModeButton")
						if fastModeBtn then
							for _, conn in ipairs(getconnections(fastModeBtn.Activated)) do
								pcall(conn.Function)
							end
						end
					end)
				end)

				local missingTaskLogged = {}
				SetTask("MainTask", "n/a")
				SetTask("SideTask", "n/a")
				ParsingTimes = 101

				local function dispatchTaskModule(moduleKey, taskPayload)
					if CurrentTask ~= moduleKey then
						TweenController.Hovering = false
						TweenController.HoverCFrame = nil
					end
					CurrentTask = moduleKey

					pcall(function()
						ScriptStorage.Interface.SetText("DebugLine", moduleKey)
					end)

					local okRun, errTrace = xpcall(function()
						FunctionsHandler[moduleKey].Methods.Start:Call(taskPayload)
					end, debug.traceback)

					if not okRun then
						Report(errTrace)
					end
				end

				RefreshTasksData = function()
					if not isSessionActive() then
						return
					end

					local activeRaidInWorld = (SeaIndex ~= 1) and CombatController.IsRaidActive()
					local raidController = FunctionsHandler.RaidController
					local isRaidControllerLocked = false

					if
						SeaIndex ~= 1
						and raidController
						and raidController.Initalized
						and raidController.Methods.IsLocked
					then
						local okLock, lockRes = pcall(function()
							return raidController.Methods.IsLocked:Call()
						end)
						if okLock and lockRes then
							isRaidControllerLocked = true
						end
					end

					if activeRaidInWorld or isRaidControllerLocked then
						dispatchTaskModule("RaidController", isRaidControllerLocked or true)
						return
					end

					if CurrentTask == "BossesTask" or CurrentTask == "SpecialBossesTask" then
						local activeMod = FunctionsHandler[CurrentTask]
						local refreshMethod = activeMod and activeMod.Methods and activeMod.Methods.Refresh
						local startMethod = activeMod and activeMod.Methods and activeMod.Methods.Start
						if refreshMethod and startMethod then
							local keepBossPayload = refreshMethod:Call(false)
							if keepBossPayload then
								dispatchTaskModule(CurrentTask, keepBossPayload)
								return
							end
						end
					end

					for _, moduleName in ipairs(TasksOrder) do
						local mod = FunctionsHandler[moduleName]
						if not mod then
							missingTaskLogged[moduleName] = true
						elseif mod.Initalized then
							local refreshMethod = mod.Methods.Refresh
							local startMethod = mod.Methods.Start
							if refreshMethod and startMethod then
								local taskPayload = refreshMethod:Call(false)
								if taskPayload then
									dispatchTaskModule(moduleName, taskPayload)
									return
								end
							end
						end
					end
				end

				task.spawn(function()
					pcall(AddPoint)
					pcall(RefreshRace)
				end)

				pcall(function()
					QuestController:RefreshQuest()
				end)
				pcall(RefreshInventory)

				trackSessionConnection(Remotes.CommE.OnClientEvent:Connect(function(eventTag)
					if eventTag and string.find(tostring(eventTag), "Item") then
						pcall(RefreshInventory)
					end
				end))

				trackSessionConnection(LocalPlayer.Idled:Connect(function()
					Services.VirtualUser:CaptureController()
					Services.VirtualUser:ClickButton2(Vector2.new())
				end))

				local NOTABLE_WEAPONS = {
					["Cursed Dual Katana"] = true,
					["Yama"] = true,
					["Tushita"] = true,
					["Skull Guitar"] = true,
					["Soul Guitar"] = true,
				}

				local function sendDiscordWebhookSummary()
					if not Config.WebhookEnabled or type(Config.WebhookUrl) ~= "string" or #Config.WebhookUrl < 10 then
						return
					end
					if not httpRequest then
						warn("[Webhook] Executor không hỗ trợ hàm gửi HTTP request")
						return
					end

					local okWebhook, webhookErr = pcall(function()
						RefreshInventory()
						SyncLiveMeleeTools()

						local dataFolder = LocalPlayer:FindFirstChild("Data")
						local char = LocalPlayer.Character
						local raceName = (dataFolder and dataFolder:FindFirstChild("Race") and dataFolder.Race.Value)
							or "Unknown"

						local raceTier = "V1"
						if char and char:FindFirstChild("RaceTransformed") then
							raceTier = "V4"
						else
							local remoteSucceeded, resV = safeInvokeRemote(Remotes.CommF_, 3, "Wenlocktoad", "1")
							if remoteSucceeded and resV == -2 then
								raceTier = "V3"
							else
								local remoteSucceededCurrent, resVCurrent =
									safeInvokeRemote(Remotes.CommF_, 3, "Alchemist", "1")
								if remoteSucceededCurrent and resVCurrent == -2 then
									raceTier = "V2"
								end
							end
						end

						local devilFruitObj = dataFolder and dataFolder:FindFirstChild("DevilFruit")
						local equippedFruitRaw = tostring((devilFruitObj and devilFruitObj.Value) or "None")
						if equippedFruitRaw == "" then
							equippedFruitRaw = "None"
						end
						local equippedFruitShort = equippedFruitRaw:match("^(T%-Rex)")
							or equippedFruitRaw:match("^([^%-]+)")
							or equippedFruitRaw

						local fruitMastery = 0
						local fruitTool = (
							LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild(equippedFruitRaw)
						) or (char and char:FindFirstChild(equippedFruitRaw))
						if fruitTool and fruitTool:FindFirstChild("Level") then
							fruitMastery = tonumber(fruitTool.Level.Value) or 0
						end

						local meleeSummaries = {}
						for meleeName, isOwned in pairs(ScriptStorage.MeleesOwned) do
							local mastery = tonumber(ScriptStorage.Melees[meleeName]) or 0
							if isOwned and mastery > 0 then
								table.insert(meleeSummaries, string.format("%s [%d]", meleeName, mastery))
							end
						end

						local fruitInventoryList = {}
						local seenFruits = {}
						local gearInventoryList = {}
						local seenGear = {}

						for itemKey, itemEntry in pairs(ScriptStorage.Backpack) do
							local itemName = tostring(itemEntry.Name or itemKey)
							if itemEntry.Type == "Blox Fruit" then
								local shortFruit = itemName:match("^(T%-Rex)")
									or itemName:match("^([^%-]+)")
									or itemName
								if not seenFruits[shortFruit] then
									seenFruits[shortFruit] = true
									table.insert(fruitInventoryList, shortFruit)
								end
							elseif itemEntry.Type == "Accessory" or NOTABLE_WEAPONS[itemName] then
								if not seenGear[itemName] then
									seenGear[itemName] = true
									table.insert(gearInventoryList, itemName)
								end
							end
						end

						table.sort(meleeSummaries)
						table.sort(fruitInventoryList)
						table.sort(gearInventoryList)

						local function formatCodeBlockList(items)
							local joined = (#items > 0) and table.concat(items, ", ") or "None"
							if #joined > 992 then
								joined = joined:sub(1, 989) .. "..."
							end
							return "```\n" .. joined .. "\n```"
						end

						local playerLevel = (
							dataFolder
							and dataFolder:FindFirstChild("Level")
							and tonumber(dataFolder.Level.Value)
						) or 0
						local fruitStatus = (equippedFruitRaw ~= "None")
								and string.format("%s [%d]", equippedFruitShort, fruitMastery)
							or "None"
						local profileDesc = string.format(
							"Username : ||%s||\nLevel : %d\nRace : %s [%s]\nFruits : %s",
							tostring(LocalPlayer.Name),
							playerLevel,
							tostring(raceName),
							raceTier,
							fruitStatus
						)

						local avatarIcon = "https://i.pinimg.com/736x/ce/78/92/ce7892480524e44c32992af6dc894f44.jpg"
						local payload = {
							username = "Chan Chan HUB",
							avatar_url = avatarIcon,
							allowed_mentions = { parse = {} },
							embeds = {
								{
									author = { name = "Chan  HUB  •  PLAYER PROFILE", icon_url = avatarIcon },
									title = "Account Overview",
									description = profileDesc,
									color = 16776960,
									fields = {
										{ name = "Melee", value = formatCodeBlockList(meleeSummaries), inline = false },
										{
											name = "Inventory Fruit",
											value = formatCodeBlockList(fruitInventoryList),
											inline = false,
										},
										{
											name = "Inventory",
											value = formatCodeBlockList(gearInventoryList),
											inline = false,
										},
									},
									footer = { text = " chan HUB  •  Player Stats", icon_url = avatarIcon },
									timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
								},
							},
						}

						httpRequest({
							Url = Config.WebhookUrl,
							Method = "POST",
							Headers = { ["Content-Type"] = "application/json" },
							Body = HttpService:JSONEncode(payload),
						})
					end)

					if not okWebhook then
						warn("[Webhook] " .. tostring(webhookErr))
					end
				end

				task.spawn(function()
					task.wait(15)
					while isSessionActive() do
						if
							Config.WebhookEnabled
							and type(Config.WebhookUrl) == "string"
							and #Config.WebhookUrl >= 10
						then
							sendDiscordWebhookSummary()
							local waitSeconds = math.max(1, tonumber(Config.WebhookIntervalMinutes) or 5) * 60
							task.wait(waitSeconds)
						else
							task.wait(10)
						end
					end
				end)

				local function cleanupTransientVisualEffects()
					pcall(function()
						local worldOrigin = workspace:FindFirstChild("_WorldOrigin")
						if worldOrigin then
							for _, transientName in ipairs({ "Foam", "DamageCounter", "Sounds" }) do
								local folder = worldOrigin:FindFirstChild(transientName)
								if folder then
									for _, child in ipairs(folder:GetChildren()) do
										pcall(child.Destroy, child)
									end
								end
							end
						end
					end)
				end

				task.spawn(function()
					local lastMeleeCheckUnix = 0
					local lastDlcBoxCheckUnix = 0
					local lastVfxCleanupUnix = 0

					while isSessionActive() do
						local okMaint, maintErr = xpcall(function()
							local pg = LocalPlayer:FindFirstChild("PlayerGui")
							local spinnerWindow = pg and pg:FindFirstChild("SpinnerWindow")
							if spinnerWindow then
								local closeBtn = spinnerWindow:FindFirstChild("CloseButton", true)
								if closeBtn then
									for _, conn in ipairs(getconnections(closeBtn.MouseButton1Click)) do
										pcall(function()
											conn:Fire()
										end)
									end
									for _, conn in ipairs(getconnections(closeBtn.Activated)) do
										pcall(function()
											conn:Fire()
										end)
									end
								end
							end

							local currentChar = LocalPlayer.Character
							local currentHum = currentChar and currentChar:FindFirstChildOfClass("Humanoid")
							if currentHum and currentHum.Sit then
								currentHum:ChangeState(Enum.HumanoidStateType.Jumping)
							end

							RefreshPlayerData()
							if runtimeUI and runtimeUI.SyncRuntimeUI then
								pcall(runtimeUI.SyncRuntimeUI)
							end

							local raidCtrl = FunctionsHandler.RaidController
							local isRaidBusy = raidCtrl
								and raidCtrl.Initalized
								and raidCtrl.Methods.IsLocked
								and raidCtrl.Methods.IsLocked:Call()

							if not isRaidBusy and (os.time() - lastMeleeCheckUnix) > 3 then
								lastMeleeCheckUnix = os.time()
								FunctionsHandler.MeleesController.Methods.Start:Call()
							end

							if (os.time() - lastDlcBoxCheckUnix) > 60 then
								lastDlcBoxCheckUnix = os.time()
								if Remotes.CommF_:InvokeServer("Cousin", "CheckTime", "DLCBoxData") == true then
									Remotes.CommF_:InvokeServer("Cousin", "DLCBoxData")
								end
							end

							if (os.time() - lastVfxCleanupUnix) >= 30 then
								lastVfxCleanupUnix = os.time()
								cleanupTransientVisualEffects()
							end
						end, debug.traceback)

						if not okMaint then
							Report(maintErr)
						end
						task.wait(1)
					end
				end)

				task.spawn(function()
					pcall(RefreshTasksData)
				end)

				while isSessionActive() do
					if Config.HopWhenIdle and (os.time() - lastIdleTick) > 180 then
						SetTask("MainTask", "Rejoining due idle in 3 min")
						UnifiedReconnect("Rejoining due to idle in 3 min")
						while isSessionActive() do
							task.wait(1)
						end
						break
					end

					if Config.AutoHop ~= false and (tick() - StartTick) > 1800 then
						SetTask("MainTask", "Hop Server - 30 min")
						Hop("30 min server hop")
						task.wait(5)
					end

					local okTick, tickErr = xpcall(RefreshTasksData, debug.traceback)
					if not okTick then
						Report(tickErr)
					end
					task.wait(0.25)
				end
			end
		end
	end
end

local engineOk, engineError = xpcall(startKaitunEngine, debug.traceback)
if not engineOk then
	globalEnv.BananaCat = nil
	warn("[Banana Cat Kaitun Error]: " .. tostring(engineError))
end
