--[[
  ============================================================
   VXEZE KILL AURA PRO — Blox Fruits
   Built by: Tình 1 đêm (AI) — Vxeze Hub
   Feature: đánh nhanh không delay, đánh xa (hitbox mở rộng),
   damage THẬT qua remotes RegisterAttack/RegisterHit
   Core payload da duoc kiem chung in-game (credit: Skibata deobf)
  ============================================================
]]

-- ================= CORE PAYLOAD (verified) =================
local J = game:GetService("Players").LocalPlayer

local W=require(game:GetService('ReplicatedStorage').Modules.CombatUtil);

function GetAllChildAttack()local s=workspace:WaitForChild('Enemies'):GetChildren();
local R=workspace:WaitForChild('Characters'):GetChildren();
local R={};for D,D in pairs(s)do table.insert(R,D);
end;return R;
end;
local s=game:GetService("ReplicatedStorage").Modules.Net:WaitForChild("RE/RegisterAttack");
local R=require(game:GetService("ReplicatedStorage").Modules.Net):RemoteEvent("RegisterHit",true);
local function D(V,I,q)local n={};for A,A in pairs(V:GetChildren())do if A:IsA("BasePart")and(A.Position-I).Magnitude<=q then table.insert(n,A);
end;end;return n;
end;
local function V(I)local I={};for q,q in pairs(game:GetService("Workspace"):WaitForChild('Enemies'):GetChildren())do table.insert(I,q);
end;return I;
end;
local I=game:GetService("Players");
local q=game:GetService("ReplicatedStorage");
local q=game:GetService('VirtualInputManager');
getgenv().getBladeHits=function(q,n,A,a)local Q={};for b,b in pairs(V(a))do if b:IsDescendantOf(Workspace)and b~=q and b:FindFirstChild('HumanoidRootPart')then local V=b.HumanoidRootPart;
local q=I:GetPlayerFromCharacter(b)and(A/1.5)or A;
local A={V.Position};if V.Size.Y>5 then table.insert(A,(V.CFrame*CFrame.new(0,-V.Size.Y*1.5+3,0)).Position);
end;for a,a in pairs(A)do if(a-n[1].Position).Magnitude<10+q+V.Size.X/2 then for A,A in pairs(D(b,n[1].Position,q+V.Size.X/2))do table.insert(Q,A);
end;break;
end;end;
end;end;return Q;
end;
local D={RightUpperArm=true,RightLowerArm=true,RightHand=true,RightUpperLeg=true,RightLowerLeg=true,RightFoot=true,LeftUpperArm=true,LeftLowerArm=true,LeftHand=true,LeftUpperLeg=true,LeftLowerLeg=true,LeftFoot=true,UpperTorso=true,LowerTorso=true,Head=true};

function AttackAOE(V,q)local n={};
local A={};for a,a in
getgenv().getBladeHits(J.Character,{J.Character.HumanoidRootPart},V or 80,q)do local V=W:GetRigOfHitPart(a);if V and not A[V]and D[a.Name]and W:IsVulnerable(V)then local W=V:FindFirstChild("Summoner");
local D=J.Character:FindFirstChild('Summoner');if V~=J.Character and(not D or V~=D.Value.Character)and(not I:GetPlayerFromCharacter(J.Character)or not W or W.Value~=I:GetPlayerFromCharacter(J.Character))then table.insert(n,{V,a});A[V]=true;
end;end;
end;return#n>0 and n or nil;
end;

function AttackFunction(W)local D=J.Character;if not D or(D:FindFirstChild("Stun")and D.Stun.Value~=0)then return;
end;
local D=AttackAOE(W,false);if not D then return;
end;s:FireServer(0);R:FireServer(table.remove(D,1)[2],D);
end;
-- ================= CONFIG =================
getgenv().KA = {
        ["Kill Aura"] = false,
        ["Range"] = 80,          -- tầm đánh xa (stud) — 40 = gần, 80 = xa, 120+ = cực xa
        ["Delay"] = 0.08,        -- nhịp đánh — càng nhỏ càng nhanh (0.05 = max speed)
        ["PvP Mode"] = false,    -- TRUE = đánh cả người chơi gần (workspace.Characters)
        ["Spam Gun"] = false,
        ["Auto Equip"] = true,
        ["Auto Haki"] = true,
        ["GUI"] = true,
}
local Config = getgenv().KA

if writefile and isfile and isfile("vxeze_killaura.json") then
        pcall(function()
                local saved = game:GetService("HttpService"):JSONDecode(readfile("vxeze_killaura.json"))
                for k, v in pairs(saved) do Config[k] = v end
        end)
end
local function SaveConfig()
        if writefile then
                pcall(function()
                        writefile("vxeze_killaura.json", game:GetService("HttpService"):JSONEncode(Config))
                end)
        end
end

-- ================= HELPERS =================
local function GetChar() return J.Character or J.CharacterAdded:Wait() end

local function EquipWeapon()
        if not Config["Auto Equip"] then return end
        local c = GetChar()
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if not c:FindFirstChildOfClass("Tool") then
                for _, t in pairs(J.Backpack:GetChildren()) do
                        if t:IsA("Tool") and t:FindFirstChild("Handle") then
                                local n = t.Name:lower()
                                if not n:find("fruit") then
                                        hum:EquipTool(t)
                                        break
                                end
                        end
                end
        end
end

-- Haki Buso cho damage khí đen
task.spawn(function()
        while true do
                if Config["Kill Aura"] and Config["Auto Haki"] then
                        pcall(function()
                                game:GetService("ReplicatedStorage"):WaitForChild("Remotes").CommF_:InvokeServer("Buso")
                        end)
                end
                task.wait(2)
        end
end)

-- ================= KILL AURA LOOP (FAST — NO ANIM WAIT) =================
-- Nguoi choi gan (cho PvP mode)
local function NearestPlayerChar()
        local hrp = GetChar():FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end
        local best, bd = nil, math.huge
        for _, p in pairs(game:GetService("Players"):GetPlayers()) do
                if p ~= J and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                        and p.Character:FindFirstChildOfClass("Humanoid")
                        and p.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                        local d = (p.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
                        if d < bd and d <= (Config["Range"] + 60) then best, bd = p.Character, d end
                end
        end
        return best
end

-- ================= PVP ATTACK (danh nguoi choi — damage that) =================
local BODY = {
        Head = true, UpperTorso = true, LowerTorso = true,
        RightUpperArm = true, RightLowerArm = true, RightHand = true,
        LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
        RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
        LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
}

local function PlayerAttack()
        local char = GetChar()
        local ihrp = char:FindFirstChild("HumanoidRootPart")
        if not ihrp then return end
        local myPos = ihrp.Position
        local hitPairs = {}
        for _, p in pairs(game:GetService("Players"):GetPlayers()) do
                if p ~= J and p.Character then
                        local h = p.Character:FindFirstChildOfClass("Humanoid")
                        local phrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if h and phrp and h.Health > 0 and (phrp.Position - myPos).Magnitude <= Config["Range"] then
                                local okV, vul = pcall(function() return W:IsVulnerable(p.Character) end)
                                if okV and vul then
                                        local count = 0
                                        for _, part in pairs(p.Character:GetChildren()) do
                                                if part:IsA("BasePart") and BODY[part.Name] and count < 6 then
                                                        table.insert(hitPairs, { p.Character, part })
                                                        count = count + 1
                                                end
                                        end
                                end
                        end
                end
        end
        if #hitPairs > 0 then
                s:FireServer(0)
                R:FireServer(table.remove(hitPairs, 1)[2], hitPairs)
        end
end

task.spawn(function()
        while true do
                if Config["Kill Aura"] then
                        local ok, err = pcall(function()
                                local myPos = GetChar():FindFirstChild("HumanoidRootPart") and GetChar().HumanoidRootPart.Position
                                if not myPos then return end
                                local inRange = 0
                                -- Dem quai trong tam danh
                                for _, mob in pairs(workspace:WaitForChild("Enemies"):GetChildren()) do
                                        local m = mob:FindFirstChild("HumanoidRootPart")
                                        local h = mob:FindFirstChild("Humanoid")
                                        if m and h and h.Health > 0 and (m.Position - myPos).Magnitude <= Config["Range"] + 40 then
                                                inRange = inRange + 1
                                        end
                                end
                                -- PvP mode: cong ca nguoi choi vao tam
                                if Config["PvP Mode"] then
                                        local pc = NearestPlayerChar()
                                        if pc then
                                                -- Dua player vao pham vi bang cach chinh position ban than
                                                local ihrp = GetChar().HumanoidRootPart
                                                local d = (pc.HumanoidRootPart.Position - ihrp.Position).Magnitude
                                                if d > Config["Range"] then
                                                        ihrp.CFrame = pc.HumanoidRootPart.CFrame * CFrame.new(0, 8, 0)
                                                end
                                        end
                                end
                                EquipWeapon()
                                if inRange > 0 or (Config["PvP Mode"] and NearestPlayerChar()) then
                                        AttackFunction(Config["Range"])
                                end
                                if Config["PvP Mode"] then
                                        PlayerAttack()
                                end
                        end)
                        if not ok then warn("[Vxeze KA] " .. tostring(err)) end
                        task.wait(Config["Delay"] or 0.08)
                else
                        task.wait(0.3)
                end
        end
end)

-- ================= SPAM GUN (optional — can gun tren nguoi) =================
getgenv().SpamGun=function(W)local s=require(game:GetService("ReplicatedStorage").Controllers.CombatController);
local R=getupvalues(s.Attack)[9];
local s=debug.getupvalue(R,15);
local D=debug.getupvalue(R,13);
local V=debug.getupvalue(R,16);
local I=debug.getupvalue(R,17);
local q=debug.getupvalue(R,14);
local n=debug.getupvalue(R,12);
local A=debug.getupvalue(R,18);
local a=n*D;
local Q=(q*D+n*s)%V;
local function b()Q=(Q*V+a)%I;q=math.floor(Q/V);n=Q-q*V;
end;Q=(Q*V+a)%I;q=math.floor(Q/V);n=Q-q*V;A=A+1;debug.setupvalue(R,15,s);debug.setupvalue(R,13,D);debug.setupvalue(R,16,V);debug.setupvalue(R,17,I);debug.setupvalue(R,14,q);debug.setupvalue(R,12,n);debug.setupvalue(R,18,A);game.ReplicatedStorage.Remotes.Validator2:FireServer(math.floor(Q/I*16777215),A);
local s={[1]=W.Position,[2]={[1]=W}};game:GetService('ReplicatedStorage').Modules.Net:FindFirstChild('RE/ShootGunEvent'):FireServer(unpack(s));
end;

task.spawn(function()
        while true do
                if Config["Kill Aura"] and Config["Spam Gun"] then
                        local ok, err = pcall(function()
                                local target = nil
                                for _, mob in pairs(workspace:WaitForChild("Enemies"):GetChildren()) do
                                        local h = mob:FindFirstChild("Humanoid")
                                        local m = mob:FindFirstChild("HumanoidRootPart")
                                        if h and m and h.Health > 0 then target = m break end
                                end
                                if target and J.Character and J.Character:FindFirstChild("HumanoidRootPart") then
                                        if (target.Position - J.Character.HumanoidRootPart.Position).Magnitude <= Config["Range"] + 100 then
                                                SpamGun(target)
                                        end
                                end
                        end)
                        if not ok then warn("[Vxeze KA gun] " .. tostring(err)) end
                        task.wait(0.15)
                else
                        task.wait(0.5)
                end
        end
end)

-- ================= GUI =================
if Config["GUI"] then
        local gui = Instance.new("ScreenGui")
        gui.Name = "VxezeKA"
        gui.ResetOnSpawn = false
        pcall(function() gui.Parent = J:WaitForChild("PlayerGui") end)
        if not gui.Parent then gui.Parent = game:GetService("CoreGui") end

        local main = Instance.new("Frame")
        main.Size = UDim2.new(0, 240, 0, 240)
        main.Position = UDim2.new(0, 15, 0.55, 0)
        main.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
        main.BorderSizePixel = 0
        main.Active = true
        main.Draggable = true
        main.Parent = gui

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 32)
        title.BackgroundColor3 = Color3.fromRGB(28, 34, 50)
        title.BorderSizePixel = 0
        title.Text = "VXEZE KILL AURA PRO"
        title.TextColor3 = Color3.fromRGB(255, 80, 80)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 14
        title.Parent = main

        local listY = 38
        local function AddToggle(label, key)
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, -12, 0, 25)
                btn.Position = UDim2.new(0, 6, 0, listY)
                listY = listY + 28
                btn.BackgroundColor3 = Color3.fromRGB(34, 40, 58)
                btn.BorderSizePixel = 0
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 12
                btn.Parent = main
                local function refresh()
                        btn.Text = (Config[key] and "ON  |  " or "OFF |  ") .. label
                        btn.TextColor3 = Config[key] and Color3.fromRGB(0, 255, 140) or Color3.fromRGB(170, 175, 190)
                end
                refresh()
                btn.MouseButton1Click:Connect(function()
                        Config[key] = not Config[key]
                        refresh()
                        SaveConfig()
                end)
        end

        local rangeLabel = Instance.new("TextLabel")
        rangeLabel.Size = UDim2.new(1, -12, 0, 25)
        rangeLabel.Position = UDim2.new(0, 6, 0, listY)
        listY = listY + 28
        rangeLabel.BackgroundColor3 = Color3.fromRGB(34, 40, 58)
        rangeLabel.BorderSizePixel = 0
        rangeLabel.Font = Enum.Font.Gotham
        rangeLabel.TextSize = 12
        rangeLabel.TextColor3 = Color3.fromRGB(255, 210, 80)
        rangeLabel.Parent = main
        local function refreshRange()
                rangeLabel.Text = "Tầm đánh: " .. tostring(Config["Range"]) .. " studs"
        end
        refreshRange()

        local rowFrame = Instance.new("Frame")
        rowFrame.Size = UDim2.new(1, -12, 0, 25)
        rowFrame.Position = UDim2.new(0, 6, 0, listY)
        listY = listY + 28
        rowFrame.BackgroundTransparency = 1
        rowFrame.Parent = main

        local minusBtn = Instance.new("TextButton")
        minusBtn.Size = UDim2.new(0.5, -4, 1, 0)
        minusBtn.BackgroundColor3 = Color3.fromRGB(34, 40, 58)
        minusBtn.BorderSizePixel = 0
        minusBtn.Text = "- 10"
        minusBtn.TextColor3 = Color3.fromRGB(230, 230, 240)
        minusBtn.Font = Enum.Font.GothamBold
        minusBtn.TextSize = 12
        minusBtn.Parent = rowFrame

        local plusBtn = Instance.new("TextButton")
        plusBtn.Size = UDim2.new(0.5, 4, 1, 0)
        plusBtn.Position = UDim2.new(0.5, 0, 0, 0)
        plusBtn.BackgroundColor3 = Color3.fromRGB(34, 40, 58)
        plusBtn.BorderSizePixel = 0
        plusBtn.Text = "+ 10"
        plusBtn.TextColor3 = Color3.fromRGB(230, 230, 240)
        plusBtn.Font = Enum.Font.GothamBold
        plusBtn.TextSize = 12
        plusBtn.Parent = rowFrame

        minusBtn.MouseButton1Click:Connect(function()
                Config["Range"] = math.max(30, Config["Range"] - 10)
                refreshRange()
                SaveConfig()
        end)
        plusBtn.MouseButton1Click:Connect(function()
                Config["Range"] = math.min(200, Config["Range"] + 10)
                refreshRange()
                SaveConfig()
        end)

        AddToggle("Kill Aura", "Kill Aura")
        AddToggle("PvP Mode (đánh người)", "PvP Mode")
        AddToggle("Spam Gun", "Spam Gun")

        task.spawn(function()
                game:GetService("StarterGui"):SetCore("SendNotification", {
                        Title = "Vxeze Kill Aura Pro",
                        Text = "Loaded! Bật Kill Aura trong GUI",
                        Duration = 5
                })
        end)
end

SaveConfig()
