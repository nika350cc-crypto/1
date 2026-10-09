--[[
  ============================================================
   VXEZE FARM PRO v1 — Blox Fruits Auto Farm (Standalone)
   Built by: Tình 1 đêm (AI) — Vxeze Hub
   Context: full engine thay cho file config "God 2800"
   (config chỉ là bảng setting — bản này là engine thật)
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

-- ================= CONFIG (superset config "God 2800") =================
getgenv().Vxeze = {
        ["Team"] = "Marines",
        ["FPS Boost"] = true,
        ["FPS Cap"] = 60,
        ["Auto Farm Quest"] = false,
        ["Auto Farm Nearest"] = false,
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

-- Load config từ file nếu có
if writefile and isfile and isfile("vxeze_farm_pro.json") then
        pcall(function()
                local saved = HttpService:JSONDecode(readfile("vxeze_farm_pro.json"))
                for k, v in pairs(saved) do Config[k] = v end
        end)
end

local function SaveConfig()
        if writefile then
                pcall(function()
                        writefile("vxeze_farm_pro.json", HttpService:JSONEncode(Config))
                end)
        end
end

-- ================= HELPERS =================
local function Chat(msg)
        game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Vxeze Farm Pro", Text = msg, Duration = 4
        })
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

local function GetSea()
        local l = GetLevel()
        if l >= 1500 then return 3 elseif l >= 700 then return 2 else return 1 end
end

-- Chọn Team khi vào lần đầu
task.spawn(function()
        pcall(function()
                if LP.Data.Level.Value == 1 and not LP.Data:FindFirstChild("TeamChosen") then
                        CommF_("SetTeam", Config["Team"])
                end
        end)
end)

-- Anti AFK
LP.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
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

-- Auto chia điểm stat ("All" = phân đều 5 chỉ số)
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

-- ================= DATA: MOB THEO LEVEL =================
-- {name = chuỗi trong tên mob, sea = biển} — mob không có trong workspace sẽ bị bỏ qua (fallback an toàn)
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
        { lvl = 450,  name = "God's Guard" },
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
-- ================= TARGET ENGINE =================
local EnemiesFolder = workspace:WaitForChild("Enemies")

local function MobLevel(mobName)
        local lv = mobName:match("%[Lv%.%s*(%d+)%]")
        return lv and tonumber(lv) or 0
end

-- Tìm mob tốt nhất theo level hiện tại
local function FindTargetMob()
        local myLv = GetLevel()
        local best, bestDiff = nil, math.huge
        for _, mob in pairs(EnemiesFolder:GetChildren()) do
                if mob:FindFirstChild("Humanoid") and mob:FindFirstChild("HumanoidRootPart")
                        and mob.Humanoid.Health > 0 then
                        local mlv = MobLevel(mob.Name)
                        local diff = math.abs(mlv - myLv)
                        -- Ưu tiên mob có level sát mình nhất, cộng thêm điểm nếu cùng biển
                        if diff < bestDiff then
                                best, bestDiff = mob, diff
                        end
                end
        end
        return best
end

-- Tìm theo tên cụ thể (mục tiêu từ MOB_MAP)
local function FindMobByName(partName)
        for _, mob in pairs(EnemiesFolder:GetChildren()) do
                if mob.Name:find(partName, 1, true) and mob:FindFirstChild("Humanoid")
                        and mob:FindFirstChild("HumanoidRootPart") and mob.Humanoid.Health > 0 then
                        return mob
                end
        end
        return nil
end

-- Chọn mục tiêu từ map (entry có level <= mình, gần nhất) rồi tìm mob thật
local function PickMappedMob()
        local myLv = GetLevel()
        local candidates = {}
        for _, e in pairs(MOB_MAP) do
                if e.lvl <= myLv + 30 then
                        table.insert(candidates, e)
                end
        end
        table.sort(candidates, function(a, b) return a.lvl > b.lvl end)
        for _, e in ipairs(candidates) do
                local mob = FindMobByName(e.name)
                if mob then return mob, e end
        end
        return nil
end

-- Dồn mob về điểm farm
local function BringMobs(targetName)
        local hrp = GetHRP()
        if not hrp then return end
        local farmPos = hrp.CFrame
        for _, mob in pairs(EnemiesFolder:GetChildren()) do
                if targetName == nil or mob.Name:find(targetName, 1, true) then
                        local h = mob:FindFirstChild("Humanoid")
                        local m = mob:FindFirstChild("HumanoidRootPart")
                        if h and m and h.Health > 0 and (m.Position - farmPos.Position).Magnitude < 2500 then
                                m.CFrame = farmPos * CFrame.new(math.random(-6, 6), 0, math.random(-6, 6))
                                m.Velocity = Vector3.new()
                        end
                end
        end
end

-- ================= ATTACK ENGINE =================
local function AttackMob(mob)
        local hum = GetHum()
        local hrp = GetHRP()
        if not (hum and hrp) then return end
        -- Bay lên trên mob, giữ khoảng cách an toàn
        local mh = mob:FindFirstChild("HumanoidRootPart")
        if mh then
                hrp.CFrame = mh.CFrame * CFrame.new(0, Config["Farm Height"] or 22, 0)
        end
        -- Đánh liên tục
        pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton1(Vector2.new())
        end)
        local tool = GetChar():FindFirstChildOfClass("Tool")
        if tool then
                pcall(function() tool:Activate() end)
        end
end

-- Nghiện hướng: xoay camera nhìn xuống mob
task.spawn(function()
        RunService.RenderStepped:Connect(function()
                if (Config["Auto Farm Quest"] or Config["Auto Farm Nearest"] or Config["Boss Farm"]) then
                        pcall(function()
                                local hrp = GetHRP()
                                local cam = workspace.CurrentCamera
                                local target = EnemiesFolder:FindFirstChildOfClass("Model")
                                if hrp and cam and target and target:FindFirstChild("HumanoidRootPart") then
                                        local look = CFrame.lookAt(hrp.Position, target.HumanoidRootPart.Position)
                                        cam.CFrame = cam.CFrame:Lerp(look, 0.2)
                                end
                        end)
                end
        end)
end)

-- ================= FARM LOOPS =================
local FarmBusy = false

task.spawn(function()
        while true do
                if Config["Auto Farm Quest"] or Config["Auto Farm Nearest"] then
                        local ok, err = pcall(function()
                                local mob, entry
                                if Config["Auto Farm Quest"] then
                                        mob, entry = PickMappedMob()
                                end
                                if not mob then
                                        mob = FindTargetMob()
                                end
                                if mob then
                                        BringMobs(Config["Auto Farm Quest"] and entry and entry.name or nil)
                                        EquipWeapon()
                                        AttackMob(mob)
                                end
                        end)
                        if not ok then warn("[Vxeze Farm] " .. tostring(err)) end
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
                                                local cls = t:FindFirstChildOfClass("StringValue") or t
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
                        if not ok then warn("[Vxeze Farm] boss: " .. tostring(err)) end
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

-- Fruit Sniper: phát hiện trái rơi → nhặt; nếu trùng Eat Fruit → báo
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
                                                                        Chat("Đã nhặt trái muốn ăn: " .. obj.Name)
                                                                else
                                                                        Chat("Sniper: thấy " .. obj.Name .. " — đã tới nhặt")
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
                                Chat("Có người gần — hop server!")
                                HopServer()
                                task.wait(10)
                        end
                end
                task.wait(2)
        end
end)

-- ================= GUI =================
if Config["GUI"] then
        local gui = Instance.new("ScreenGui")
        gui.Name = "VxezeFarmPro"
        gui.ResetOnSpawn = false
        pcall(function() gui.Parent = LP:WaitForChild("PlayerGui") end)
        if not gui.Parent then gui.Parent = game:GetService("CoreGui") end

        local main = Instance.new("Frame")
        main.Size = UDim2.new(0, 250, 0, 400)
        main.Position = UDim2.new(0, 15, 0.3, 0)
        main.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
        main.BorderSizePixel = 0
        main.Active = true
        main.Draggable = true
        main.Parent = gui

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 34)
        title.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
        title.BorderSizePixel = 0
        title.Text = "VXEZE FARM PRO"
        title.TextColor3 = Color3.fromRGB(0, 255, 140)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 15
        title.Parent = main

        local status = Instance.new("TextLabel")
        status.Size = UDim2.new(1, 0, 0, 22)
        status.Position = UDim2.new(0, 0, 0, 34)
        status.BackgroundTransparency = 1
        status.Text = "Lv: ... | Sea: ..."
        status.TextColor3 = Color3.fromRGB(200, 200, 210)
        status.Font = Enum.Font.Gotham
        status.TextSize = 12
        status.Parent = main

        local listY = 60
        local function AddToggle(label, key)
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, -12, 0, 26)
                btn.Position = UDim2.new(0, 6, 0, listY)
                listY = listY + 30
                btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
                btn.BorderSizePixel = 0
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 12
                btn.Parent = main
                local function refresh()
                        btn.Text = (Config[key] and "ON  |  " or "OFF |  ") .. label
                        btn.TextColor3 = Config[key] and Color3.fromRGB(0, 255, 140) or Color3.fromRGB(180, 180, 190)
                end
                refresh()
                btn.MouseButton1Click:Connect(function()
                        Config[key] = not Config[key]
                        refresh()
                        SaveConfig()
                end)
                return btn
        end

        AddToggle("Auto Farm Quest", "Auto Farm Quest")
        AddToggle("Auto Farm Nearest", "Auto Farm Nearest")
        AddToggle("Auto Chest", "Auto Chest")
        AddToggle("Auto Berry", "Auto Berry")
        AddToggle("Boss Farm", "Boss Farm")
        AddToggle("Fruit Sniper", "Fruit Sniper")
        AddToggle("Mastery Farm", "Mastery Farm")
        AddToggle("Bring Mobs", "Bring Mobs")
        AddToggle("Hop Player Near", "Hop Player Near")
        -- Nut rieng Auto Stats: bam chuyen OFF -> Melee -> Defense
        local statBtn = Instance.new("TextButton")
        statBtn.Size = UDim2.new(1, -12, 0, 26)
        statBtn.Position = UDim2.new(0, 6, 0, listY)
        listY = listY + 30
        statBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
        statBtn.BorderSizePixel = 0
        statBtn.Font = Enum.Font.Gotham
        statBtn.TextSize = 12
        statBtn.Parent = main
        local statStates = { "", "All", "Melee", "Defense", "Sword", "Gun", "Blox Fruit" }
        local function refreshStat()
            local cur = tostring(Config["Auto Stats"])
            statBtn.Text = "Auto Stats: " .. (cur == "" and "OFF" or cur)
            statBtn.TextColor3 = (cur ~= "") and Color3.fromRGB(0, 255, 140) or Color3.fromRGB(180, 180, 190)
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

        task.spawn(function()
                while gui.Parent do
                        pcall(function()
                                status.Text = "Lv " .. GetLevel() .. " | Sea " .. GetSea()
                                        .. (Config["Auto Stats"] ~= "" and (" | +" .. Config["Auto Stats"]) or "")
                        end)
                        task.wait(1)
                end
        end)
end

Chat("Vxeze Farm Pro loaded — bật toggle trong GUI để chạy!")
SaveConfig()
