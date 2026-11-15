-- language: Lua, file: bloxfruit_sea1_full.lua, runtime: Roblox Executor
-- Full Sea 1: 24 nhiệm vụ, kill-tracking fallback, debug UI

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local commF = remotes:WaitForChild("CommF_")

_G.AutoFarm = true
local FarmSpeed = 300

task.spawn(function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/thnww/bloxfruit/refs/heads/main/Blox_Fruit/Fast-attack.lua"))()
    end)
end)

-- ============================================================
-- DATA 24 NHIỆM VỤ SEA 1
-- NpcPos từ Lv30+ là ước lượng, cần verify bằng debug
-- KillCount là số quái cần giết (ước lượng, có thể chênh)
-- ============================================================
local QuestData = {
    [1] = {
        Level = 1, QuestName = "BanditQuest1", QuestIndex = 1, MobName = "Bandit", KillCount = 5,
        NpcPos = CFrame.new(1051.7979, 14.5119, 1557.7426),
        MobPositions = {
            CFrame.new(1147.2271, 13.1856, 1676.8046),
            CFrame.new(1210.0192, 13.1856, 1673.5321),
            CFrame.new(1254.7184, 13.1853, 1623.0574),
            CFrame.new(1203.5729, 13.1857, 1563.3494),
            CFrame.new(1114.2612, 13.1856, 1590.1833),
        }
    },
    [10] = {
        Level = 10, QuestName = "JungleQuest", QuestIndex = 1, MobName = "Monkey", KillCount = 8,
        NpcPos = CFrame.new(-1679.7632, 48.7400, 175.6400),
        MobPositions = {
            CFrame.new(-1601.0857, 29.6221, 364.4406),
            CFrame.new(-1866.3134, 29.6221, 21.588%),
            CFrame.new(-1758.7128, 29.6221, -31.8809),
            CFrame.new(-1637.5544, 29.6221, 19.6397),
            CFrame.new(-1450.6414, 29.6221, 306.1212),
            CFrame.new(-1299.4274, 17.5869, 81.4219),
        }
    },
    [15] = {
        Level = 15, QuestName = "JungleQuest", QuestIndex = 2, MobName = "Gorilla", KillCount = 10,
        NpcPos = CFrame.new(-1679.7632, 48.7400, 175.6400),
        MobPositions = {
            CFrame.new(-1176.3092, 15.8106, -668.1966),
            CFrame.new(-1266.5652, 14.4667, -462.0237),
            CFrame.new(-1401.0885, 25.8104, -463.9572),
            CFrame.new(-1387.3287, 13.0840, -577.8001),
        }
    },
    [30] = {
        Level = 30, QuestName = "PirateQuest", QuestIndex = 1, MobName = "Pirate", KillCount = 8,
        NpcPos = CFrame.new(1050, 14, 3800),
        MobPositions = {
            CFrame.new(1100, 12, 3850),
            CFrame.new(1150, 12, 3900),
            CFrame.new(1050, 12, 3920),
            CFrame.new(1000, 12, 3860),
        }
    },
    [40] = {
        Level = 40, QuestName = "MarineQuest", QuestIndex = 1, MobName = "Marine", KillCount = 8,
        NpcPos = CFrame.new(-620, 30, 3700),
        MobPositions = {
            CFrame.new(-550, 15, 3800),
            CFrame.new(-650, 15, 3750),
            CFrame.new(-500, 15, 3850),
            CFrame.new(-700, 15, 3800),
        }
    },
    [60] = {
        Level = 60, QuestName = "DesertQuest", QuestIndex = 1, MobName = "Desert Bandit", KillCount = 10,
        NpcPos = CFrame.new(1400, 15, 4400),
        MobPositions = {
            CFrame.new(1420, 15, 4450),
            CFrame.new(1380, 15, 4500),
            CFrame.new(1450, 15, 4480),
            CFrame.new(1350, 15, 4550),
        }
    },
    [75] = {
        Level = 75, QuestName = "DesertQuest", QuestIndex = 2, MobName = "Desert Officer", KillCount = 10,
        NpcPos = CFrame.new(1400, 15, 4400),
        MobPositions = {
            CFrame.new(1450, 15, 4550),
            CFrame.new(1500, 15, 4600),
            CFrame.new(1400, 15, 4650),
        }
    },
    [90] = {
        Level = 90, QuestName = "SnowQuest", QuestIndex = 1, MobName = "Snow Bandit", KillCount = 8,
        NpcPos = CFrame.new(1380, 100, -1300),
        MobPositions = {
            CFrame.new(1350, 100, -1400),
            CFrame.new(1400, 100, -1450),
            CFrame.new(1300, 100, -1350),
            CFrame.new(1450, 100, -1420),
        }
    },
    [110] = {
        Level = 110, QuestName = "SnowQuest", QuestIndex = 2, MobName = "Snowman", KillCount = 8,
        NpcPos = CFrame.new(1380, 100, -1300),
        MobPositions = {
            CFrame.new(1300, 100, -1500),
            CFrame.new(1350, 100, -1550),
            CFrame.new(1250, 100, -1450),
            CFrame.new(1400, 100, -1520),
        }
    },
    [125] = {
        Level = 125, QuestName = "SnowQuest", QuestIndex = 3, MobName = "Yeti", KillCount = 8,
        NpcPos = CFrame.new(1380, 100, -1300),
        MobPositions = {
            CFrame.new(1200, 100, -1600),
            CFrame.new(1150, 100, -1650),
            CFrame.new(1250, 100, -1580),
            CFrame.new(1100, 100, -1550),
        }
    },
    [150] = {
        Level = 150, QuestName = "MarineQuest", QuestIndex = 2, MobName = "Marine", KillCount = 8,
        NpcPos = CFrame.new(-690, 300, 5400),
        MobPositions = {
            CFrame.new(-700, 300, 5500),
            CFrame.new(-650, 300, 5450),
            CFrame.new(-750, 300, 5550),
            CFrame.new(-680, 300, 5480),
        }
    },
    [175] = {
        Level = 175, QuestName = "SkyQuest", QuestIndex = 1, MobName = "Sky Bandit", KillCount = 8,
        NpcPos = CFrame.new(1200, 400, 800),
        MobPositions = {
            CFrame.new(1250, 400, 850),
            CFrame.new(1150, 400, 900),
            CFrame.new(1300, 400, 750),
            CFrame.new(1180, 400, 820),
        }
    },
    [190] = {
        Level = 190, QuestName = "SkyQuest", QuestIndex = 2, MobName = "Dark Master", KillCount = 8,
        NpcPos = CFrame.new(1200, 400, 800),
        MobPositions = {
            CFrame.new(1250, 400, 950),
            CFrame.new(1300, 400, 900),
            CFrame.new(1200, 400, 1000),
            CFrame.new(1280, 400, 920),
        }
    },
    [210] = {
        Level = 210, QuestName = "PrisonQuest", QuestIndex = 1, MobName = "Prisoner", KillCount = 8,
        NpcPos = CFrame.new(-1570, 100, -2500),
        MobPositions = {
            CFrame.new(-1600, 100, -2600),
            CFrame.new(-1550, 100, -2550),
            CFrame.new(-1650, 100, -2650),
            CFrame.new(-1620, 100, -2580),
        }
    },
    [225] = {
        Level = 225, QuestName = "PrisonQuest", QuestIndex = 2, MobName = "Dangerous Prisoner", KillCount = 8,
        NpcPos = CFrame.new(-1570, 100, -2500),
        MobPositions = {
            CFrame.new(-1700, 100, -2700),
            CFrame.new(-1650, 100, -2750),
            CFrame.new(-1750, 100, -2650),
            CFrame.new(-1680, 100, -2720),
        }
    },
    [245] = {
        Level = 245, QuestName = "MagmaQuest", QuestIndex = 1, MobName = "Military Soldier", KillCount = 8,
        NpcPos = CFrame.new(-5000, 100, -5000),
        MobPositions = {
            CFrame.new(-5100, 100, -5050),
            CFrame.new(-5050, 100, -5100),
            CFrame.new(-5150, 100, -5000),
            CFrame.new(-5080, 100, -5030),
        }
    },
    [300] = {
        Level = 300, QuestName = "MagmaQuest", QuestIndex = 2, MobName = "Military Spy", KillCount = 8,
        NpcPos = CFrame.new(-5000, 100, -5000),
        MobPositions = {
            CFrame.new(-5200, 100, -5100),
            CFrame.new(-5150, 100, -5150),
            CFrame.new(-5250, 100, -5050),
            CFrame.new(-5180, 100, -5080),
        }
    },
    [375] = {
        Level = 375, QuestName = "CursedShipQuest", QuestIndex = 1, MobName = "Living Zombie", KillCount = 8,
        NpcPos = CFrame.new(2500, 100, 3000),
        MobPositions = {
            CFrame.new(2550, 100, 3050),
            CFrame.new(2600, 100, 3100),
            CFrame.new(2450, 100, 3050),
            CFrame.new(2530, 100, 3080),
        }
    },
    [400] = {
        Level = 400, QuestName = "CursedShipQuest", QuestIndex = 2, MobName = "Demonic Soul", KillCount = 8,
        NpcPos = CFrame.new(2500, 100, 3000),
        MobPositions = {
            CFrame.new(2700, 100, 3200),
            CFrame.new(2650, 100, 3250),
            CFrame.new(2750, 100, 3150),
            CFrame.new(2680, 100, 3180),
        }
    },
    [450] = {
        Level = 450, QuestName = "IceCastleQuest", QuestIndex = 1, MobName = "Arctic Warrior", KillCount = 8,
        NpcPos = CFrame.new(-5500, 100, -5500),
        MobPositions = {
            CFrame.new(-5600, 100, -5550),
            CFrame.new(-5550, 100, -5600),
            CFrame.new(-5650, 100, -5500),
            CFrame.new(-5580, 100, -5530),
        }
    },
    [625] = {
        Level = 625, QuestName = "IceCastleQuest", QuestIndex = 2, MobName = "Snow Trooper", KillCount = 8,
        NpcPos = CFrame.new(-5500, 100, -5500),
        MobPositions = {
            CFrame.new(-5700, 100, -5600),
            CFrame.new(-5650, 100, -5650),
            CFrame.new(-5750, 100, -5550),
            CFrame.new(-5680, 100, -5580),
        }
    },
    [650] = {
        Level = 650, QuestName = "IceCastleQuest", QuestIndex = 3, MobName = "Winter Warrior", KillCount = 8,
        NpcPos = CFrame.new(-5500, 100, -5500),
        MobPositions = {
            CFrame.new(-5800, 100, -5700),
            CFrame.new(-5750, 100, -5750),
            CFrame.new(-5850, 100, -5650),
            CFrame.new(-5780, 100, -5680),
        }
    },
    [700] = {
        Level = 700, QuestName = "IceCastleQuest", QuestIndex = 4, MobName = "Winter Archer", KillCount = 8,
        NpcPos = CFrame.new(-5500, 100, -5500),
        MobPositions = {
            CFrame.new(-5900, 100, -5800),
            CFrame.new(-5850, 100, -5850),
            CFrame.new(-5950, 100, -5750),
            CFrame.new(-5880, 100, -5780),
        }
    },
    [725] = {
        Level = 725, QuestName = "IceCastleQuest", QuestIndex = 5, MobName = "Ice Legend", KillCount = 8,
        NpcPos = CFrame.new(-5500, 100, -5500),
        MobPositions = {
            CFrame.new(-6000, 100, -5900),
            CFrame.new(-5950, 100, -5950),
            CFrame.new(-6050, 100, -5850),
            CFrame.new(-5980, 100, -5880),
        }
    },
}

-- GUI
local statusGui = Instance.new("ScreenGui")
statusGui.Name = "NamHubStatus"
statusGui.ResetOnSpawn = false
statusGui.Parent = player:WaitForChild("PlayerGui")

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.fromOffset(380, 32)
statusLabel.Position = UDim2.new(0.5, -190, 0, 10)
statusLabel.BackgroundColor3 = Color3.fromRGB(20, 23, 35)
statusLabel.TextColor3 = Color3.fromRGB(0, 255, 170)
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 13
statusLabel.Text = "Trạng thái: Đang khởi động..."
statusLabel.Parent = statusGui
Instance.new("UICorner", statusLabel).CornerRadius = UDim.new(0, 8)

local TargetCFrame = nil

RunService.Heartbeat:Connect(function(dt)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if _G.AutoFarm then
        local bv = hrp:FindFirstChild("NamHubAntiFall")
        if not bv then
            bv = Instance.new("BodyVelocity")
            bv.Name = "NamHubAntiFall"
            bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            bv.Velocity = Vector3.zero
            bv.Parent = hrp
        end

        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end

        if TargetCFrame then
            local currentPos = hrp.Position
            local targetPos = TargetCFrame.Position
            local diff = targetPos - currentPos
            local dist = diff.Magnitude
            if dist <= FarmSpeed * dt or dist <= 4 then
                hrp.CFrame = CFrame.new(targetPos) * (TargetCFrame - TargetCFrame.Position)
            else
                local step = diff.Unit * (FarmSpeed * dt)
                hrp.CFrame = CFrame.new(currentPos + step) * (TargetCFrame - TargetCFrame.Position)
            end
        end
    else
        if hrp and hrp:FindFirstChild("NamHubAntiFall") then
            hrp.NamHubAntiFall:Destroy()
        end
    end
end)

local function getBestQuest()
    local data = player:FindFirstChild("Data")
    local lvl = data and data:FindFirstChild("Level") and tonumber(data.Level.Value) or 1
    local best, maxLvl = nil, -1
    for reqLvl, info in pairs(QuestData) do
        if type(reqLvl) == "number" and lvl >= reqLvl and reqLvl > maxLvl then
            maxLvl = reqLvl
            best = info
        end
    end
    return best
end

-- DÒ UI: Tìm chữ báo hiệu quest đang active hoặc đã xong
local function scanUIForQuestState()
    local pGui = player:FindFirstChild("PlayerGui")
    if not pGui then return nil end
    for _, gui in ipairs(pGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            for _, desc in ipairs(gui:GetDescendants()) do
                if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Visible then
                    local t = tostring(desc.Text or "")
                    if t:find("Return", 1, true) or t:find("Complete", 1, true) 
                       or t:find("Hoàn thành", 1, true) or t:find("Quay về", 1, true) then
                        return "completed"
                    end
                    if t:find("Defeat", 1, true) or t:find("Kill", 1, true) 
                       or t:find("Hạ gục", 1, true) or t:find("Tiêu diệt", 1, true) then
                        return "active"
                    end
                    -- dạng "5/5 Bandit" hoặc "Bandit: 5/5"
                    local cur, max = t:match("(%d+)%s*/%s*(%d+)")
                    if cur and max then
                        if tonumber(cur) >= tonumber(max) then
                            return "completed"
                        else
                            return "active"
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- ĐẾM KILL LOCAL (fallback khi không dò được UI)
local lastTargetMob = nil
local killsThisQuest = 0
local lastQuestId = nil

local function resetKillCounter(questId)
    if lastQuestId ~= questId then
        lastQuestId = questId
        killsThisQuest = 0
        lastTargetMob = nil
    end
end

local function updateKillCount(mob)
    -- Kiểm tra target cũ đã chết chưa
    if lastTargetMob and lastTargetMob ~= mob then
        local hum = lastTargetMob:FindFirstChild("Humanoid")
        if not lastTargetMob.Parent or not hum or hum.Health <= 0 then
            killsThisQuest = killsThisQuest + 1
        end
    end
    if mob then
        lastTargetMob = mob
    end
end

local function mobNameMatches(name, keyword)
    if name == keyword then return true end
    local pattern = "%f[%w]" .. keyword:gsub("%W", "%%%0") .. "%f[%W]"
    return name:find(pattern) ~= nil
end

local function findTargetMob(mobKeyword, myPos)
    local closest, shortest = nil, math.huge
    local searchFolders = { Workspace:FindFirstChild("Enemies"), Workspace }
    for _, folder in ipairs(searchFolders) do
        if folder then
            for _, obj in ipairs(folder:GetChildren()) do
                if obj:IsA("Model")
                    and mobNameMatches(obj.Name, mobKeyword)
                    and obj:FindFirstChild("HumanoidRootPart")
                    and obj:FindFirstChild("Humanoid")
                    and obj.Humanoid.Health > 0 then
                    local d = (myPos - obj.HumanoidRootPart.Position).Magnitude
                    if d < shortest then
                        shortest = d
                        closest = obj
                    end
                end
            end
        end
        if closest then break end
    end
    return closest
end

-- TRẠNG THÁI CHÍNH
local spotIndex = 1
local lastSpotSwitch = tick()
local currentQuestId = nil
local lastQuestInvoke = 0
local waitAfterInvoke = 0

task.spawn(function()
    while task.wait(0.15) do
        if _G.AutoFarm then
            pcall(function()
                local quest = getBestQuest()
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not quest or not hrp then return end

                local questId = quest.QuestName .. ":" .. tostring(quest.QuestIndex)
                if currentQuestId ~= questId then
                    currentQuestId = questId
                    spotIndex = 1
                    lastSpotSwitch = tick()
                    lastQuestInvoke = 0
                    waitAfterInvoke = 0
                end
                resetKillCounter(questId)

                -- Xác định trạng thái quest
                local uiState = scanUIForQuestState()
                local killDone = killsThisQuest >= quest.KillCount
                local inGrace = tick() - waitAfterInvoke < 5

                local state
                if uiState == "completed" or killDone then
                    state = "completed"
                elseif uiState == "active" then
                    state = "active"
                elseif inGrace then
                    state = "active"  -- vừa invoke, tạm tin là đã nhận
                else
                    state = "none"
                end

                if state == "completed" or state == "none" then
                    -- Quay về NPC
                    local npcPos = quest.NpcPos * CFrame.new(0, 3, 0)
                    TargetCFrame = npcPos
                    local dist = (hrp.Position - npcPos.Position).Magnitude

                    if dist > 15 then
                        statusLabel.Text = string.format("[%s] Bay tới NPC (còn %d studs)", state, math.floor(dist))
                    else
                        if state == "completed" then
                            statusLabel.Text = "Đang trả nhiệm vụ..."
                        else
                            statusLabel.Text = "Đang nhận nhiệm vụ..."
                        end

                        if tick() - lastQuestInvoke > 3 then
                            lastQuestInvoke = tick()
                            local ok, err = pcall(function()
                                commF:InvokeServer("StartQuest", quest.QuestName, quest.QuestIndex)
                            end)
                            if ok then
                                waitAfterInvoke = tick()
                                killsThisQuest = 0
                                lastTargetMob = nil
                                print("[Gru] StartQuest OK:", quest.QuestName, quest.QuestIndex)
                            else
                                print("[Gru] StartQuest FAIL:", tostring(err))
                            end
                        end
                    end

                else
                    -- Farm
                    local mob = findTargetMob(quest.MobName, hrp.Position)
                    updateKillCount(mob)

                    if mob then
                        statusLabel.Text = string.format("Đánh %s (giết %d/%d)", mob.Name, killsThisQuest, quest.KillCount)
                        local mobPos = mob.HumanoidRootPart.Position
                        TargetCFrame = CFrame.new(mobPos + Vector3.new(0, 15, 0)) * CFrame.Angles(math.rad(-90), 0, 0)
                        if not char:FindFirstChild("HasBuso") then
                            pcall(function() commF:InvokeServer("Buso") end)
                        end
                    else
                        lastTargetMob = nil
                        local spots = quest.MobPositions
                        if spots and #spots > 0 then
                            if spotIndex > #spots then spotIndex = 1 end
                            local spot = spots[spotIndex] * CFrame.new(0, 15, 0)
                            TargetCFrame = spot
                            statusLabel.Text = string.format("Tìm %s (điểm %d/%d, giết %d/%d)",
                                quest.MobName, spotIndex, #spots, killsThisQuest, quest.KillCount)
                            if (hrp.Position - spot.Position).Magnitude < 12 or (tick() - lastSpotSwitch > 3) then
                                spotIndex = spotIndex % #spots + 1
                                lastSpotSwitch = tick()
                            end
                        else
                            statusLabel.Text = "Quest thiếu tọa độ quái"
                        end
                    end
                end
            end)
        else
            TargetCFrame = nil
            statusLabel.Text = "Đã tắt Auto Farm"
        end
    end
end)

-- DEBUG: In Data và UI khi cần
_G.DebugQuest = function()
    print("=== DATA ===")
    local data = player:FindFirstChild("Data")
    if data then
        for _, v in ipairs(data:GetChildren()) do
            print(v.Name, v.ClassName, v.Value)
        end
    end
    print("=== UI QUEST TEXT ===")
    local pGui = player:FindFirstChild("PlayerGui")
    if pGui then
        for _, gui in ipairs(pGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled then
                for _, desc in ipairs(gui:GetDescendants()) do
                    if (desc:IsA("TextLabel") or desc:IsA("TextButton")) 
                       and desc.Visible and #tostring(desc.Text) > 0 then
                        print(gui.Name, ">", desc:GetFullName(), "=", desc.Text)
                    end
                end
            end
        end
    end
end