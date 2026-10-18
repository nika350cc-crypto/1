--[[
  ============================================================
   VXEZE FARM PRO v2 — Blox Fruits Auto Farm Level 1 → Max
   Built by: Tình 1 đêm (AI) — Vxeze Hub | Delta Mobile + PC
   Moi: quest data table 3 sea, tu nhan quest qua remote +
   VERIFY UI that, thanh tien do kill, anti-stall, respawn-safe
  ============================================================
   GIOI HAN THAT (noi that, khong gia lap):
   - Nhan quest qua remote tu xa; neu server tu choi -> fallback
     farm nearest (van XP, thieu bonus hoan thanh quest)
   - Bang quest lay tu kien thuc public: entry co tag --guess
     se duoc VERIFY sau khi nhan (UI quest phai chua ten mob);
     sai -> tu chuyen nearest, khong bao farm thanh cong ao
   - Di chuyen GIUA CAC SEA phai tu di cua trong game
   - EXP can de len cap khong duoc expose -> bar = tien do kill
  ============================================================
]]

-- ================= SERVICES =================
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")

local CommF_ = function(...)
	local ok, r = pcall(function()
		return RS:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer(...)
	end)
	return ok and r or nil
end

-- Remote danh chinh (verified tu PvP hub) — dung cho Fast Attack
local NetOK, AttackRemote, HitRemote = pcall(function()
	local net = RS:WaitForChild("Modules"):WaitForChild("Net")
	return net:WaitForChild("RE/RegisterAttack"),
		require(RS:WaitForChild("Modules"):WaitForChild("Net")):RemoteEvent("RegisterHit", true)
end)
if NetOK then
	AttackRemote = RS.Modules.Net:WaitForChild("RE/RegisterAttack")
	HitRemote = require(RS.Modules.Net):RemoteEvent("RegisterHit", true)
else
	AttackRemote, HitRemote = nil, nil
end

-- ================= CONFIG =================
getgenv().Vxeze = {
	["Team"] = "Marines",
	["FPS Boost"] = true,
	["FPS Cap"] = 60,
	["Auto Farm Quest"] = false,
	["Auto Accept Quest"] = true,
	["Auto Farm Nearest"] = false,
	["Fast Attack"] = true,
	["Bring Mobs"] = true,
	["Farm Height"] = 22,
	["Auto Chest"] = false,
	["Auto Berry"] = false,
	["Auto Bone"] = false,
	["Mastery Farm"] = false,
	["Mastery Weapons"] = { "Sword", "Gun" },
	["Boss Farm"] = false,
	["Fruit Sniper"] = false,
	["Eat Fruit"] = "",
	["Auto Stats"] = "", -- "" | "All" | Melee/Defense/Sword/Gun/Blox Fruit
	["Hop Player Near"] = false,
	["Hop Distance"] = 350,
	["Auto Haki"] = true,
	["GUI"] = true,
}

local Config = getgenv().Vxeze

if writefile and isfile and isfile("vxeze_farm_pro_v2.json") then
	pcall(function()
		local saved = HttpService:JSONDecode(readfile("vxeze_farm_pro_v2.json"))
		for k, v in pairs(saved) do Config[k] = v end
	end)
end

local function SaveConfig()
	if writefile then
		pcall(function()
			writefile("vxeze_farm_pro_v2.json", HttpService:JSONEncode(Config))
		end)
	end
end

-- ================= HELPERS =================
local function Chat(msg)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "Vxeze Farm Pro v2", Text = msg, Duration = 4
		})
	end)
end

local function GetChar()
	return LP.Character or LP.CharacterAdded:Wait()
end

local function GetHRP()
	local c = GetChar()
	return c:FindFirstChild("HumanoidRootPart") or c:WaitForChild("HumanoidRootPart", 3)
end

local function GetHum()
	local c = GetChar()
	return c:FindFirstChildOfClass("Humanoid")
end

local function TP(cf)
	local hrp = GetHRP()
	if hrp then hrp.CFrame = cf end
end

local function GetLevel()
	local ok, r = pcall(function()
		return LP.Data.Level.Value
	end)
	return ok and r or 1
end

local function GetExp()
	local ok, r = pcall(function()
		return LP.Data.Exp.Value
	end)
	return ok and r or 0
end

local function GetSea()
	local l = GetLevel()
	if l >= 1500 then return 3 elseif l >= 700 then return 2 else return 1 end
end

-- Chọn Team khi vào lần đầu
task.spawn(function()
	pcall(function()
		if LP.Data.Level.Value == 1 then
			CommF_("SetTeam", Config["Team"])
		end
	end)
end)

-- Anti AFK
LP.Idled:Connect(function()
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end)

-- ================= FPS BOOST =================
if Config["FPS Boost"] then
	pcall(function()
		setfpscap(Config["FPS Cap"] or 60)
	end)
	pcall(function()
		Lighting.GlobalShadows = false
		Lighting.FogEnd = 1e6
		Lighting.Brightness = 1
		for _, e in pairs(Lighting:GetChildren()) do
			if e:IsA("PostEffect") then e.Enabled = false end
		end
	end)
	pcall(function()
		settings().Rendering.QualityLevel = 1
	end)
end

-- ================= WEAPON =================
local function EquipWeapon()
	local c = GetChar()
	local hum = GetHum()
	if not (c and hum) then return end
	if c:FindFirstChild("Haki") == nil and Config["Auto Haki"] then
		pcall(function() CommF_("Buso") end)
	end
	for _, t in pairs(LP.Backpack:GetChildren()) do
		if t:IsA("Tool") and t:FindFirstChild("Handle") then
			local n = t.Name:lower()
			if not n:find("fruit") then
				hum:EquipTool(t)
				return t
			end
		end
	end
	for _, t in pairs(c:GetChildren()) do
		if t:IsA("Tool") and t:FindFirstChild("Handle") then
			return t
		end
	end
	return nil
end

-- Auto chia điểm stat
local STAT_ALL = { "Melee", "Defense", "Sword", "Gun", "Blox Fruit" }
task.spawn(function()
	while true do
		local mode = Config["Auto Stats"]
		if mode == "All" then
			pcall(function()
				for _, s in ipairs(STAT_ALL) do
					CommF_("AddPoint", s, 1)
				end
			end)
		elseif mode ~= "" and mode then
			pcall(function()
				CommF_("AddPoint", tostring(mode), 1)
			end)
		end
		task.wait(1)
	end
end)

-- ================= DATA 1: MOB THEO LEVEL (fallback nearest) =================
local MOB_MAP = {
	-- First Sea
	{ lvl = 5,    name = "Bandit" },
	{ lvl = 14,   name = "Monkey" },
	{ lvl = 25,   name = "Gorilla" },
	{ lvl = 35,   name = "Pirate" },
	{ lvl = 45,   name = "Brute" },
	{ lvl = 60,   name = "Desert Bandit" },
	{ lvl = 75,   name = "Desert Officer" },
	{ lvl = 90,   name = "Snow Bandit" },
	{ lvl = 100,  name = "Snowman" },
	{ lvl = 120,  name = "Chief Petty Officer" },
	{ lvl = 150,  name = "Sky Bandit" },
	{ lvl = 175,  name = "Dark Master" },
	{ lvl = 190,  name = "Prisoner" },
	{ lvl = 210,  name = "Dangerous Prisoner" },
	{ lvl = 225,  name = "Toga Warrior" },
	{ lvl = 250,  name = "Military Soldier" },
	{ lvl = 275,  name = "Galactic Pirate" },
	{ lvl = 300,  name = "God's Guard" },
	{ lvl = 325,  name = "Snow Trooper" },
	{ lvl = 350,  name = "Winter Warrior" },
	{ lvl = 375,  name = "Lab Subordinate" },
	{ lvl = 400,  name = "Fishman Warrior" },
	{ lvl = 425,  name = "Fishman Commando" },
	{ lvl = 475,  name = "Shanda" },
	{ lvl = 500,  name = "Royal Squad" },
	{ lvl = 525,  name = "Royal Soldier" },
	{ lvl = 550,  name = "Galley Pirate" },
	{ lvl = 575,  name = "Galley Captain" },
	-- Second Sea
	{ lvl = 700,  name = "Raider" },
	{ lvl = 725,  name = "Mercenary" },
	{ lvl = 775,  name = "Swan Pirate" },
	{ lvl = 800,  name = "Factory Staff" },
	{ lvl = 875,  name = "Marine Lieutenant" },
	{ lvl = 900,  name = "Marine Captain" },
	{ lvl = 925,  name = "Zombie" },
	{ lvl = 975,  name = "Vampire" },
	{ lvl = 1000, name = "Snow Trooper" },
	{ lvl = 1050, name = "Winter Warrior" },
	{ lvl = 1100, name = "Lab Subordinate" },
	{ lvl = 1150, name = "Fishman Warrior" },
	{ lvl = 1175, name = "Fishman Commando" },
	{ lvl = 1200, name = "Sea Soldier" },
	{ lvl = 1250, name = "Water Fighter" },
	{ lvl = 1275, name = "Elemental Battler" },
	-- Third Sea
	{ lvl = 1500, name = "Pirate Millionaire" },
	{ lvl = 1575, name = "Dragon Crew Warrior" },
	{ lvl = 1600, name = "Dragon Crew Archer" },
	{ lvl = 1675, name = "Female Islander" },
	{ lvl = 1700, name = "Giant Islander" },
	{ lvl = 1725, name = "Island Empress" },
	{ lvl = 1775, name = "Fishman Raider" },
	{ lvl = 1800, name = "Fishman Captain" },
	{ lvl = 1825, name = "Forest Pirate" },
	{ lvl = 1850, name = "Mythological Pirate" },
	{ lvl = 1875, name = "Jungle Pirate" },
	{ lvl = 1900, name = "Musketeer Pirate" },
	{ lvl = 1975, name = "Ship Deckhand" },
	{ lvl = 2000, name = "Ship Officer" },
	{ lvl = 2100, name = "Cherry Bandit" },
	{ lvl = 2175, name = "Cherry Captain" },
	{ lvl = 2225, name = "Candy Pirate" },
	{ lvl = 2275, name = "Candy Rebel" },
	{ lvl = 2325, name = "Cocoa Warrior" },
}

-- ================= DATA 2: QUEST TABLE (nhan qua remote + verify) =================
-- q = ten quest gui StartQuest (nil = khong nhan quest, farm nearest)
-- idx = chi so quest tai NPC (1 hoac 2)
-- mob = chuoi ten mob trong quest
-- Tag: --confirmed = kien thuc on dinh | --guess = se VERIFY UI sau khi nhan
local QUESTS = {
	{ lv = 1,   q = "BanditQuest1",    idx = 1, mob = "Bandit" },              -- confirmed
	{ lv = 10,  q = "MonkeyQuest",     idx = 1, mob = "Monkey" },              -- confirmed
	{ lv = 25,  q = "MonkeyQuest",     idx = 2, mob = "Gorilla" },             -- confirmed
	{ lv = 35,  q = "BuggyQuest1",     idx = 1, mob = "Pirate" },              -- confirmed
	{ lv = 45,  q = "BuggyQuest1",     idx = 2, mob = "Brute" },               -- confirmed
	{ lv = 60,  q = "DesertQuest",     idx = 1, mob = "Desert Bandit" },       -- confirmed
	{ lv = 75,  q = "DesertQuest",     idx = 2, mob = "Desert Officer" },      -- confirmed
	{ lv = 90,  q = "SnowQuest",       idx = 1, mob = "Snow Bandit" },         -- confirmed
	{ lv = 100, q = "SnowQuest",       idx = 2, mob = "Snowman" },             -- confirmed
	{ lv = 120, q = "MarineQuest2",    idx = 1, mob = "Chief Petty Officer" }, -- confirmed
	{ lv = 150, q = "SkyQuest",        idx = 1, mob = "Sky Bandit" },          -- confirmed
	{ lv = 175, q = "SkyQuest",        idx = 2, mob = "Dark Master" },         -- confirmed
	{ lv = 190, q = "PrisonQuest",     idx = 1, mob = "Prisoner" },            -- confirmed
	{ lv = 210, q = "PrisonQuest",     idx = 2, mob = "Dangerous Prisoner" },  -- confirmed
	{ lv = 225, q = "ColosseumQuest",  idx = 1, mob = "Toga Warrior" },        -- confirmed
	{ lv = 250, q = "ColosseumQuest",  idx = 2, mob = "Military Soldier" },    -- guess
	{ lv = 275, q = nil, mob = "Galactic Pirate" },
	{ lv = 300, q = "GodGuardQuest",   idx = 1, mob = "God's Guard" },         -- guess
	{ lv = 325, q = nil, mob = "Snow Trooper" },
	{ lv = 350, q = nil, mob = "Winter Warrior" },
	{ lv = 375, q = nil, mob = "Lab Subordinate" },
	{ lv = 400, q = "FishmanQuest",    idx = 1, mob = "Fishman Warrior" },     -- guess
	{ lv = 425, q = "FishmanQuest",    idx = 2, mob = "Fishman Commando" },    -- guess
	{ lv = 475, q = nil, mob = "Shanda" },
	{ lv = 500, q = "RoyalQuest",      idx = 1, mob = "Royal Squad" },         -- guess
	{ lv = 525, q = "RoyalQuest",      idx = 2, mob = "Royal Soldier" },       -- guess
	{ lv = 550, q = "GalleyQuest",     idx = 1, mob = "Galley Pirate" },       -- guess
	{ lv = 575, q = "GalleyQuest",     idx = 2, mob = "Galley Captain" },      -- guess
	-- Sea 2
	{ lv = 700,  q = "Area1Quest", idx = 1, mob = "Raider" },                      -- guess
	{ lv = 725,  q = "Area2Quest", idx = 1, mob = "Mercenary" },                   -- guess
	{ lv = 775,  q = nil, mob = "Swan Pirate" },
	{ lv = 800,  q = nil, mob = "Factory Staff" },
	{ lv = 875,  q = nil, mob = "Marine Lieutenant" },
	{ lv = 900,  q = nil, mob = "Marine Captain" },
	{ lv = 925,  q = nil, mob = "Zombie" },
	{ lv = 975,  q = nil, mob = "Vampire" },
	{ lv = 1000, q = nil, mob = "Snow Trooper" },
	{ lv = 1050, q = nil, mob = "Winter Warrior" },
	{ lv = 1100, q = nil, mob = "Lab Subordinate" },
	{ lv = 1150, q = nil, mob = "Fishman Warrior" },
	{ lv = 1175, q = nil, mob = "Fishman Commando" },
	{ lv = 1200, q = nil, mob = "Sea Soldier" },
	{ lv = 1250, q = nil, mob = "Water Fighter" },
	{ lv = 1275, q = nil, mob = "Elemental Battler" },
	-- Sea 3
	{ lv = 1500, q = nil, mob = "Pirate Millionaire" },
	{ lv = 1575, q = nil, mob = "Dragon Crew Warrior" },
	{ lv = 1600, q = nil, mob = "Dragon Crew Archer" },
	{ lv = 1675, q = nil, mob = "Female Islander" },
	{ lv = 1700, q = nil, mob = "Giant Islander" },
	{ lv = 1725, q = nil, mob = "Island Empress" },
	{ lv = 1775, q = nil, mob = "Fishman Raider" },
	{ lv = 1800, q = nil, mob = "Fishman Captain" },
	{ lv = 1825, q = nil, mob = "Forest Pirate" },
	{ lv = 1850, q = nil, mob = "Mythological Pirate" },
	{ lv = 1875, q = nil, mob = "Jungle Pirate" },
	{ lv = 1900, q = nil, mob = "Musketeer Pirate" },
	{ lv = 1975, q = nil, mob = "Ship Deckhand" },
	{ lv = 2000, q = nil, mob = "Ship Officer" },
	{ lv = 2100, q = nil, mob = "Cherry Bandit" },
	{ lv = 2175, q = nil, mob = "Cherry Captain" },
	{ lv = 2225, q = nil, mob = "Candy Pirate" },
	{ lv = 2275, q = nil, mob = "Candy Rebel" },
	{ lv = 2325, q = nil, mob = "Cocoa Warrior" },
}

-- ================= TARGET ENGINE =================
local EnemiesFolder = workspace:WaitForChild("Enemies", 30)

local function MobLevel(mobName)
	local lv = mobName:match("%[Lv%.%s*(%d+)%]")
	return lv and tonumber(lv) or 0
end

-- Mob gan level mong muon nhat (tranh "Prisoner" khop voi "Dangerous Prisoner")
local function FindMobByName(partName, wantLv)
	local best, bestDiff = nil, math.huge
	if not EnemiesFolder then return nil end
	for _, mob in pairs(EnemiesFolder:GetChildren()) do
		if mob.Name:find(partName, 1, true) and mob:FindFirstChild("Humanoid")
			and mob:FindFirstChild("HumanoidRootPart") and mob.Humanoid.Health > 0 then
			if wantLv then
				local diff = math.abs(MobLevel(mob.Name) - wantLv)
				if diff < bestDiff then best, bestDiff = mob, diff end
			else
				return mob
			end
		end
	end
	return best
end

-- Nearest mob bat ky (fallback) — uu tien level sat minh
local function FindTargetMob()
	if not EnemiesFolder then return nil end
	local myLv = GetLevel()
	local best, bestDiff = nil, math.huge
	for _, mob in pairs(EnemiesFolder:GetChildren()) do
		if mob:FindFirstChild("Humanoid") and mob:FindFirstChild("HumanoidRootPart")
			and mob.Humanoid.Health > 0 then
			local diff = math.abs(MobLevel(mob.Name) - myLv)
			if diff < bestDiff then
				best, bestDiff = mob, diff
			end
		end
	end
	return best
end

-- Chon quest theo level: entry co lv <= minh va gan nhat
local function PickQuest()
	local myLv = GetLevel()
	local pick = nil
	for _, e in ipairs(QUESTS) do
		if e.lv <= myLv and (pick == nil or e.lv > pick.lv) then
			pick = e
		end
	end
	return pick
end

-- Dồn mob về điểm farm
local function BringMobs(targetName, wantLv)
	local hrp = GetHRP()
	if not hrp then return end
	local farmPos = hrp.CFrame
	if not EnemiesFolder then return end
	for _, mob in pairs(EnemiesFolder:GetChildren()) do
		if targetName == nil or mob.Name:find(targetName, 1, true) then
			local h = mob:FindFirstChild("Humanoid")
			local m = mob:FindFirstChild("HumanoidRootPart")
			if h and m and h.Health > 0 and (m.Position - farmPos.Position).Magnitude < 2500 then
				if wantLv then
					local diff = math.abs(MobLevel(mob.Name) - wantLv)
					if diff <= 40 then
						m.CFrame = farmPos * CFrame.new(math.random(-6, 6), 0, math.random(-6, 6))
						m.Velocity = Vector3.new()
					end
				else
					m.CFrame = farmPos * CFrame.new(math.random(-6, 6), 0, math.random(-6, 6))
					m.Velocity = Vector3.new()
				end
			end
		end
	end
end

-- ================= QUEST ENGINE (verify UI that) =================
local QuestGui = nil
pcall(function()
	local main = LP:WaitForChild("PlayerGui"):WaitForChild("Main", 10)
	if main then QuestGui = main:FindFirstChild("Quest") end
end)

local function QuestVisible()
	local ok, v = pcall(function()
		return QuestGui ~= nil and QuestGui.Visible
	end)
	return ok and v or false
end

-- Doc toan bo text trong UI quest (khoi cai cau truc con)
local function QuestTexts()
	local out = {}
	if not QuestGui then return out end
	pcall(function()
		for _, d in pairs(QuestGui:GetDescendants()) do
			if d:IsA("TextLabel") and d.Text and #d.Text > 0 then
				table.insert(out, d.Text)
			end
		end
	end)
	return out
end

-- UI quest co thuc su tro den mob mong muon?
local function QuestMatches(mobName)
	if not QuestVisible() then return false end
	for _, t in pairs(QuestTexts()) do
		if t:find(mobName, 1, true) then return true end
	end
	return false
end

-- Tien do kill "x/y" tu UI quest — tra ve x, y hoac nil
local function KillProgress()
	if not QuestVisible() then return nil end
	local found = nil
	pcall(function()
		for _, t in pairs(QuestTexts()) do
			local x, y = t:match("%((%d+)%s*/%s*(%d+)%)")
			if x and y then found = { tonumber(x), tonumber(y) } break end
		end
	end)
	return found
end

-- Cooldown accept: ten quest -> time toi thieu cho lan thu tiep
local QuestCooldown = {}
local function AcceptQuest(entry)
	if not entry.q then return false end
	local now = os.clock()
	if QuestCooldown[entry.q] and now < QuestCooldown[entry.q] then return false end
	local okCall = CommF_("StartQuest", entry.q, entry.idx or 1)
	task.wait(0.6)
	local matched = QuestMatches(entry.mob)
	if matched then
		QuestCooldown[entry.q] = nil
		return true
	else
		-- That bai verify -> cho 120s truoc khi thu lai, khong loop vo han
		QuestCooldown[entry.q] = now + 120
		return false
	end
end

-- ================= ATTACK ENGINE =================
local function FastHit(mob)
	if not (NetOK and AttackRemote and HitRemote) then return end
	pcall(function()
		local mh = mob:FindFirstChild("HumanoidRootPart")
		if not mh then return end
		AttackRemote:FireServer(0)
		local pairs_ = {}
		for _, part in pairs(mob:GetChildren()) do
			if part:IsA("BasePart") and #pairs_ < 6 then
				table.insert(pairs_, { mob, part })
			end
		end
		if #pairs_ > 0 then
			HitRemote:FireServer(pairs_[1][2], pairs_)
		end
	end)
end

local function AttackMob(mob)
	local hum = GetHum()
	local hrp = GetHRP()
	if not (hum and hrp) then return end
	local mh = mob:FindFirstChild("HumanoidRootPart")
	if mh then
		hrp.CFrame = mh.CFrame * CFrame.new(0, Config["Farm Height"] or 22, 0)
	end
	if Config["Fast Attack"] then
		FastHit(mob)
	end
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton1(Vector2.new())
	end)
	local tool = GetChar():FindFirstChildOfClass("Tool")
	if tool then
		pcall(function() tool:Activate() end)
	end
end

-- Camera nhin ve phia mob de click duoc
task.spawn(function()
	RunService.RenderStepped:Connect(function()
		if (Config["Auto Farm Quest"] or Config["Auto Farm Nearest"] or Config["Boss Farm"]) then
			pcall(function()
				local hrp = GetHRP()
				local cam = workspace.CurrentCamera
				if hrp and cam and EnemiesFolder then
					local target = EnemiesFolder:FindFirstChildOfClass("Model")
					if target and target:FindFirstChild("HumanoidRootPart") then
						local look = CFrame.lookAt(hrp.Position, target.HumanoidRootPart.Position)
						cam.CFrame = cam.CFrame:Lerp(look, 0.2)
					end
				end
			end)
		end
	end)
end)

-- ================= FARM LOOP (quest -> nearest, anti-stall) =================
local FarmBusy = false
local CurrentQuestMob = nil
local StallState = { lastKill = -1, lastChange = os.clock() }

-- Respawn: chet -> don dep state, loop tu chay lai khi hoi sinh
LP.CharacterAdded:Connect(function()
	task.wait(1)
	FarmBusy = false
	CurrentQuestMob = nil
	StallState.lastKill = -1
	StallState.lastChange = os.clock()
	Chat("Da hoi sinh — farm chay lai")
end)

task.spawn(function()
	while true do
		if Config["Auto Farm Quest"] or Config["Auto Farm Nearest"] then
			local ok, err = pcall(function()
				local myLv = GetLevel()
				local mob, entry = nil, nil
				if Config["Auto Farm Quest"] then
					entry = PickQuest()
					if entry then
						-- Quest dang mo va DUNG mob -> farm tiep
						if QuestMatches(entry.mob) then
							CurrentQuestMob = entry.mob
						else
							CurrentQuestMob = nil
							if Config["Auto Accept Quest"] then
								AcceptQuest(entry)
								if QuestMatches(entry.mob) then
									CurrentQuestMob = entry.mob
								end
							end
						end
					end
					if CurrentQuestMob then
						mob = FindMobByName(CurrentQuestMob, myLv)
					end
				end
				if not mob then
					mob = FindTargetMob() -- fallback: khong bao gap ao
				end
				if mob then
					if Config["Bring Mobs"] then
						BringMobs(CurrentQuestMob, CurrentQuestMob and myLv or nil)
					end
					EquipWeapon()
					AttackMob(mob)
				end
				-- ANTI-STALL: kill progress khong doi 90s -> don cooldown, doi quest
				local p = KillProgress()
				local k = p and p[1] or -1
				if k ~= StallState.lastKill then
					StallState.lastKill = k
					StallState.lastChange = os.clock()
				elseif os.clock() - StallState.lastChange > 90 then
					QuestCooldown = {}
					CurrentQuestMob = nil
					StallState.lastChange = os.clock()
					local hrp = GetHRP()
					if hrp then
						hrp.CFrame = hrp.CFrame * CFrame.new(0, 5, 0)
					end
				end
			end)
			if not ok then warn("[Vxeze Farm v2] " .. tostring(err)) end
			task.wait(0.1)
		else
			task.wait(0.5)
		end
	end
end)

-- ================= MASTERY FARM =================
task.spawn(function()
	local idx = 1
	while true do
		if Config["Mastery Farm"] and (Config["Auto Farm Quest"] or Config["Auto Farm Nearest"]) then
			local weapons = Config["Mastery Weapons"] or {}
			local want = weapons[idx]
			if want then
				local all = {}
				for _, t in pairs(LP.Backpack:GetChildren()) do
					if t:IsA("Tool") then
						local tn = t.Name
						local isGun = tn:lower():find("gun") or tn:lower():find("rifle") or tn:lower():find("pistol")
						local isSword = tn:lower():find("sword") or tn:lower():find("katana") or tn:lower():find("blade")
						if (want == "Gun" and isGun) or (want == "Sword" and isSword) then
							table.insert(all, t)
						end
					end
				end
				local pick = all[math.random(1, math.max(1, #all))]
				if pick and GetHum() then
					GetHum():EquipTool(pick)
				end
				idx = idx % math.max(1, #weapons) + 1
			end
		end
		task.wait(8)
	end
end)

-- ================= BOSS FARM =================
local BOSS_LIST = {
	"The Gorilla King", "Bobby", "Yeti", "Mob Leader", "Vice Admiral",
	"Saber Expert", "Warden", "Chief Warden", "Swan", "Magma Admiral",
	"Fishman Lord", "Wysper", "Thunder God", "Cyborg", "Greybeard",
	"Diamond", "Jeremy", "Fajita", "Don Swan", "Smoke Admiral",
	"Cursed Captain", "Darkbeard", "Order", "Tide Keeper", "Stone",
	"Island Empress", "Kilo Admiral", "Captain Elephant", "Beautiful Pirate",
	"Dough King", "rip_indra True Form", "Cake Queen",
}

local function FindBoss()
	for _, b in pairs(BOSS_LIST) do
		local mob = FindMobByName(b)
		if mob then return mob, b end
	end
	return nil
end

task.spawn(function()
	while true do
		if Config["Boss Farm"] then
			local ok, err = pcall(function()
				local boss, bname = FindBoss()
				if boss then
					BringMobs(bname)
					EquipWeapon()
					AttackMob(boss)
				end
			end)
			if not ok then warn("[Vxeze Farm v2] boss: " .. tostring(err)) end
			task.wait(0.1)
		else
			task.wait(1)
		end
	end
end)

-- ================= COLLECT: CHEST / BERRY / FRUIT =================
local function CollectByKeyword(keywords)
	local hrp = GetHRP()
	if not hrp then return false end
	for _, obj in pairs(workspace:GetDescendants()) do
		for _, kw in ipairs(keywords) do
			if obj.Name:lower():find(kw, 1, true) and (obj:IsA("BasePart") or obj:IsA("Model")) then
				local pos = obj:IsA("Model") and obj:GetModelCFrame() or obj.CFrame
				TP(pos + Vector3.new(0, 3, 0))
				return true
			end
		end
	end
	return false
end

task.spawn(function()
	while true do
		if Config["Auto Chest"] then
			pcall(function()
				if not CollectByKeyword({ "chest" }) then
					task.wait(1)
				end
			end)
			task.wait(0.3)
		else
			task.wait(1)
		end
	end
end)

task.spawn(function()
	while true do
		if Config["Auto Berry"] then
			pcall(function()
				CollectByKeyword({ "berry", "fruit_berry" })
			end)
			task.wait(1)
		else
			task.wait(2)
		end
	end
end)

task.spawn(function()
	while true do
		if Config["Fruit Sniper"] then
			pcall(function()
				for _, obj in pairs(workspace:GetChildren()) do
					if obj:IsA("Tool") and obj.Name:find("Fruit") and not obj.Name:find("Berry") then
						if obj:FindFirstChild("Handle") then
							local hpos = obj.Handle.Position
							local hrp = GetHRP()
							if hrp and (hpos - hrp.Position).Magnitude < 3000 then
								TP(CFrame.new(hpos + Vector3.new(0, 3, 0)))
								if Config["Eat Fruit"] ~= "" and obj.Name:find(Config["Eat Fruit"], 1, true) then
									if GetHum() then GetHum():EquipTool(obj) end
									Chat("Da nhat trai muon an: " .. obj.Name)
								else
									Chat("Sniper: thay " .. obj.Name .. " — da toi nhat")
								end
								break
							end
						end
					end
				end
			end)
			task.wait(2)
		else
			task.wait(3)
		end
	end
end)

-- ================= HOP PLAYER NEAR =================
local function HopServer()
	pcall(function()
		local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
		local body = game:HttpGet(url)
		local data = HttpService:JSONDecode(body)
		local jobs = {}
		for _, s in pairs(data.data or {}) do
			if s.id and s.playing and s.maxPlayers and s.playing < s.maxPlayers and s.id ~= game.JobId then
				table.insert(jobs, s.id)
			end
		end
		if #jobs > 0 then
			TeleportService:TeleportToPlaceInstance(game.PlaceId, jobs[math.random(1, #jobs)], LP)
		end
	end)
end

task.spawn(function()
	while true do
		if Config["Hop Player Near"] then
			local hrp = GetHRP()
			local dist = Config["Hop Distance"] or 350
			local danger = false
			if hrp then
				for _, p in pairs(Players:GetPlayers()) do
					if p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
						if (p.Character.HumanoidRootPart.Position - hrp.Position).Magnitude < dist then
							danger = true
							break
						end
					end
				end
			end
			if danger then
				Chat("Co nguoi gan — hop server!")
				HopServer()
				task.wait(10)
			end
		end
		task.wait(2)
	end
end)

-- ================= GUI v2 (mobile + PC, khong che man hinh) =================
local RunFlag = true
local HU = (gethui and gethui()) or game.CoreGui
pcall(function() HU.VxezeFarmProV2:Destroy() end)
local gui = Instance.new("ScreenGui")
gui.Name = "VxezeFarmProV2"
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
pcall(function() gui.Parent = HU end)

local function mk(c, t, pa)
	local o = Instance.new(c) o.BorderSizePixel = 0
	for k, v in pairs(t) do o[k] = v end
	o.Parent = pa return o
end
local function cor(o, r)
	mk("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o)
end

local C3 = Color3.fromRGB
local BG = C3(15, 17, 24) local PN = C3(24, 27, 38) local PN2 = C3(36, 40, 56)
local ACC = C3(0, 255, 140) local WT = C3(235, 238, 245) local GY = C3(150, 155, 170)

-- Panel ke ben phai man hinh — khong che vung choi tren dien thoai
local main = mk("Frame", {
	Size = UDim2.new(0, 288, 0, 408),
	Position = UDim2.new(1, -10, 0.5, -204),
	AnchorPoint = Vector2.new(1, 0),
	BackgroundColor3 = BG, Active = true, Draggable = true,
}, gui)
cor(main, 12)
mk("UIStroke", { Thickness = 1.5, Color = ACC, Transparency = 0.5 }, main)

local hdr = mk("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = PN }, main)
cor(hdr, 12)
mk("TextLabel", {
	Size = UDim2.new(1, -64, 1, 0), Position = UDim2.new(0, 10, 0, 0),
	BackgroundTransparency = 1, Text = "VXEZE FARM PRO v2",
	TextColor3 = ACC, TextXAlignment = Enum.TextXAlignment.Left,
	Font = Enum.Font.GothamBold, TextSize = 13,
}, hdr)
local miniBtn = mk("TextButton", {
	Size = UDim2.new(0, 26, 1, 0), Position = UDim2.new(1, -56, 0, 0),
	BackgroundTransparency = 1, Text = "_", TextColor3 = WT,
	Font = Enum.Font.GothamBold, TextSize = 16,
}, hdr)
local closeBtn = mk("TextButton", {
	Size = UDim2.new(0, 26, 1, 0), Position = UDim2.new(1, -28, 0, 0),
	BackgroundTransparency = 1, Text = "X", TextColor3 = C3(255, 90, 90),
	Font = Enum.Font.GothamBold, TextSize = 14,
}, hdr)

local flo = mk("TextButton", {
	Size = UDim2.new(0, 48, 0, 48), Position = UDim2.new(1, -60, 0.5, 0),
	Text = "FP", BackgroundColor3 = PN2, TextColor3 = ACC,
	Font = Enum.Font.GothamBold, TextSize = 15, Visible = false, Draggable = true,
}, gui)
cor(flo, 24)
mk("UIStroke", { Thickness = 1.5, Color = ACC, Transparency = 0.5 }, flo)
miniBtn.MouseButton1Click:Connect(function() main.Visible = false flo.Visible = true end)
flo.MouseButton1Click:Connect(function() main.Visible = true flo.Visible = false end)
closeBtn.MouseButton1Click:Connect(function()
	RunFlag = false
	Config["Auto Farm Quest"] = false
	Config["Auto Farm Nearest"] = false
	gui:Destroy()
	Chat("Da tat Farm Pro v2")
end)

-- Thong tin Level / EXP
local infoLbl = mk("TextLabel", {
	Size = UDim2.new(1, -16, 0, 22), Position = UDim2.new(0, 8, 0, 40),
	BackgroundTransparency = 1, Text = "Lv ... | Sea ... | EXP ...",
	TextColor3 = WT, TextXAlignment = Enum.TextXAlignment.Left,
	Font = Enum.Font.Gotham, TextSize = 11,
}, main)

-- Thanh tien do kill quest
local barBG = mk("Frame", {
	Size = UDim2.new(1, -16, 0, 18), Position = UDim2.new(0, 8, 0, 64),
	BackgroundColor3 = PN,
}, main)
cor(barBG, 6)
local barFill = mk("Frame", {
	Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = ACC,
}, barBG)
cor(barFill, 6)
local barLbl = mk("TextLabel", {
	Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
	Text = "Quest: Idle", TextColor3 = WT, Font = Enum.Font.GothamBold, TextSize = 10,
}, barBG)

-- Trang thai
local statusLbl = mk("TextLabel", {
	Size = UDim2.new(1, -16, 0, 18), Position = UDim2.new(0, 8, 0, 86),
	BackgroundTransparency = 1, Text = "> San sang",
	TextColor3 = GY, TextXAlignment = Enum.TextXAlignment.Left,
	Font = Enum.Font.Gotham, TextSize = 10,
}, main)

local sc = mk("ScrollingFrame", {
	Size = UDim2.new(1, -12, 1, -148), Position = UDim2.new(0, 6, 0, 108),
	BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 3, ScrollBarImageColor3 = ACC,
	CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, main)
mk("UIListLayout", { Padding = UDim2.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, sc)

local ord = 0
local function AddToggle(label, key)
	ord = ord + 1
	local btn = mk("TextButton", {
		Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = PN2,
		Text = "", TextSize = 11, Font = Enum.Font.Gotham, LayoutOrder = ord,
	}, sc)
	cor(btn, 6)
	local function refresh()
		btn.Text = (Config[key] and "ON  |  " or "OFF |  ") .. label
		btn.TextColor3 = Config[key] and ACC or GY
		btn.BackgroundColor3 = Config[key] and C3(24, 48, 36) or PN2
	end
	refresh()
	btn.MouseButton1Click:Connect(function()
		Config[key] = not Config[key]
		refresh()
		SaveConfig()
	end)
end

local function AddButton(label, fn)
	ord = ord + 1
	local btn = mk("TextButton", {
		Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = PN2, Text = label,
		TextColor3 = WT, TextSize = 11, Font = Enum.Font.GothamBold, LayoutOrder = ord,
	}, sc)
	cor(btn, 6)
	btn.MouseButton1Click:Connect(function()
		task.spawn(fn)
	end)
end

AddToggle("Auto Farm Quest (1->Max)", "Auto Farm Quest")
AddToggle("Auto Nhan Quest", "Auto Accept Quest")
AddToggle("Auto Farm Nearest", "Auto Farm Nearest")
AddToggle("Fast Attack (remote)", "Fast Attack")
AddToggle("Bring Mobs", "Bring Mobs")
AddToggle("Auto Haki", "Auto Haki")
AddToggle("Auto Chest", "Auto Chest")
AddToggle("Auto Berry", "Auto Berry")
AddToggle("Boss Farm", "Boss Farm")
AddToggle("Fruit Sniper", "Fruit Sniper")
AddToggle("Mastery Farm", "Mastery Farm")
AddToggle("Hop khi co nguoi gan", "Hop Player Near")

-- Nut chuyen doi Auto Stats: OFF -> All -> Melee -> ...
local statBtn = mk("TextButton", {
	Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = PN2, Text = "",
	TextColor3 = GY, TextSize = 11, Font = Enum.Font.Gotham,
}, sc)
cor(statBtn, 6)
local statStates = { "", "All", "Melee", "Defense", "Sword", "Gun", "Blox Fruit" }
local function refreshStat()
	local cur = tostring(Config["Auto Stats"])
	statBtn.Text = "Auto Stats: " .. (cur == "" and "OFF" or cur)
	statBtn.TextColor3 = (cur ~= "") and ACC or GY
end
refreshStat()
statBtn.MouseButton1Click:Connect(function()
	local cur = tostring(Config["Auto Stats"])
	local nextIdx = 1
	for i, s in ipairs(statStates) do
		if s == cur then nextIdx = (i % #statStates) + 1 break end
	end
	Config["Auto Stats"] = statStates[nextIdx]
	refreshStat()
	SaveConfig()
end)

AddButton("STOP TAT CA FARM", function()
	Config["Auto Farm Quest"] = false
	Config["Auto Farm Nearest"] = false
	Config["Boss Farm"] = false
	Chat("Da STOP tat ca farm")
end)

-- Cap nhat UI 1s/lam: Level/EXP + thanh tien do kill that tu UI quest
task.spawn(function()
	while RunFlag and gui.Parent do
		pcall(function()
			infoLbl.Text = "Lv " .. GetLevel() .. " | Sea " .. GetSea() .. " | EXP " .. GetExp()
			local p = KillProgress()
			if p then
				local frac = math.clamp(p[1] / math.max(1, p[2]), 0, 1)
				barFill.Size = UDim2.new(frac, 0, 1, 0)
				barLbl.Text = "Quest: " .. p[1] .. "/" .. p[2]
			else
				barFill.Size = UDim2.new(0, 0, 1, 0)
				barLbl.Text = "Quest: " .. (CurrentQuestMob and ("dang farm " .. CurrentQuestMob) or "Idle")
			end
			local qm = CurrentQuestMob or (PickQuest() and PickQuest().mob) or "nearest"
			statusLbl.Text = "> Muc tieu: " .. qm .. (QuestCooldown and "" or "")
		end)
		task.wait(1)
	end
end)

Chat("Vxeze Farm Pro v2 loaded — bat Auto Farm Quest de farm 1->Max!")
SaveConfig()
