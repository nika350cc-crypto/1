--[[
  ============================================================
   VXEZE RAPID AURA — Blox Fruits
   Built by: Tinh 1 dem (AI) — Vxeze Hub | Delta Mobile + PC
   ------------------------------------------------------------
   - Kill aura ban kinh 80 studs (chinh duoc 30-150)
   - Chay script xong la TU DANH luon, khong can bam nut M1
   - Damage dem THAT tu mau mat cua mob (health delta)
   - EXP doc THAT tu Data neu game cho doc; fallback:
     dem Kill + Level Up (that, khong gia lap)
   - Core verified: RegisterAttack + RegisterHit (RS.Modules.Net)
   - Chi danh MOB trong tam — KHONG danh nguoi choi
  ============================================================
]]

-- ================= GUARD ANTI-CONFLITO =================
if getgenv().VXEZE_RAPID_AURA then
    getgenv().VXEZE_RAPID_AURA = false
    task.wait(0.7)
end
getgenv().VXEZE_RAPID_AURA = true

local LP = game.Players.LocalPlayer
local WS = game.Workspace
local RS = game:GetService("ReplicatedStorage")
local VU = game:GetService("VirtualUser")
local HS = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local RunFlag = function() return getgenv().VXEZE_RAPID_AURA end

-- Remote danh chinh (verified: PvP hub / Farm Pro v2)
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

local function CommF_(...)
    local ok, r = pcall(function()
        return RS:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer(...)
    end)
    return ok and r or nil
end

-- ================= CONFIG + PERSIST =================
getgenv().RapidAuraConfig = {
    ["Auto Attack"] = true,  -- bat la danh luon (yeu cau cua Nam)
    ["Auto Equip"] = true,
    ["Radius"] = 80,
}
local Config = getgenv().RapidAuraConfig

if writefile and isfile and isfile("rapid_aura.json") then
    pcall(function()
        local saved = HS:JSONDecode(readfile("rapid_aura.json"))
        for k, v in pairs(saved) do Config[k] = v end
    end)
end
local function SaveConfig()
    if writefile then
        pcall(function()
            writefile("rapid_aura.json", HS:JSONEncode(Config))
        end)
    end
end

-- ================= STATS (that, khong gia lap) =================
local Stats = {
    Damage = 0,
    Kills = 0,
    LevelUps = 0,
    Exp = 0,
    HasRealExp = false,
}

local function tw(t) task.wait(t) end

local function getChar()
    return LP.Character or LP.CharacterAdded:Wait()
end

local function getHRP()
    local c = getChar()
    return c:FindFirstChild("HumanoidRootPart") or c:WaitForChild("HumanoidRootPart", 5)
end

local function getHum()
    local c = getChar()
    return c:FindFirstChildOfClass("Humanoid")
end

local function getLevel()
    local ok, r = pcall(function() return LP.Data.Level.Value end)
    return ok and r or 1
end

local function Notify(title, msg, dur)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title or "Vxeze Rapid Aura",
            Text = msg or "",
            Duration = dur or 4,
        })
    end)
end

-- ================= ATTACK CORE (verified payload) =================
local function fastHit(mob)
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

-- M1 ao tu dong (khong can user bam gi) — giu combat song server-side
local clickCount = 0
local function autoClick()
    pcall(function()
        VU:CaptureController()
        VU:ClickButton1(Vector2.new())
    end)
    local tool = getChar():FindFirstChildOfClass("Tool")
    if tool then pcall(function() tool:Activate() end) end
end

-- Auto equip vu khi tot nhat (khong can user lam gi)
local function autoEquip()
    local c = getChar()
    local hum = getHum()
    if not (c and hum) then return end
    if c:FindFirstChild("Haki") == nil then
        pcall(function() CommF_("Buso") end)
    end
    if c:FindFirstChildOfClass("Tool") then return end
    for _, t in pairs(LP.Backpack:GetChildren()) do
        if t:IsA("Tool") and t:FindFirstChild("Handle") then
            local n = t.Name:lower()
            if not n:find("fruit") then
                hum:EquipTool(t)
                return
            end
        end
    end
end

-- ================= DAMAGE TRACK (health delta THAT) =================
local tracked = {} -- [humanoid] = mau lan quet truoc

local function attachDamageTrack(mob)
    local h = mob:FindFirstChild("Humanoid")
    if h and not h:GetAttribute("VxRapidDmg") then
        h:SetAttribute("VxRapidDmg", true)
        tracked[h] = h.Health
        h:GetPropertyChangedSignal("Health"):Connect(function()
            local prev = tracked[h] or h.Health
            if h.Health < prev then
                Stats.Damage = Stats.Damage + (prev - h.Health)
            end
            tracked[h] = h.Health
        end)
    end
end

local function attachKillTrack(mob)
    local h = mob:FindFirstChild("Humanoid")
    if h and not h:GetAttribute("VxRapidKill") then
        h:SetAttribute("VxRapidKill", true)
        h.Died:Once(function()
            Stats.Kills = Stats.Kills + 1
        end)
    end
end

-- ================= EXP TRACK (doc THAT tu Data) =================
local realExp = nil
local lastExp = 0
pcall(function()
    for _, n in ipairs({ "Exp", "EXP", "XP", "Experience" }) do
        local v = LP.Data:FindFirstChild(n)
        if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then
            realExp = v
            break
        end
    end
end)
if realExp then
    Stats.HasRealExp = true
    lastExp = realExp.Value
    realExp:GetPropertyChangedSignal("Value"):Connect(function()
        local cur = realExp.Value
        if cur > lastExp then
            Stats.Exp = Stats.Exp + (cur - lastExp)
        end
        lastExp = cur
    end)
end

-- Level up THAT: Level tang → dem + thong bao
local lastLv = getLevel()
pcall(function()
    LP.Data.Level:GetPropertyChangedSignal("Value"):Connect(function()
        local lv = LP.Data.Level.Value
        if lv > lastLv then
            Stats.LevelUps = Stats.LevelUps + (lv - lastLv)
            Notify("Vxeze Rapid Aura", "LEVEL UP! Lv " .. lv, 4)
        end
        lastLv = lv
    end)
end)

-- ================= MOB COLLECTOR (mob trong tam, chan nguoi choi) =================
local function mobsInRadius()
    local hrp = getHRP()
    if not hrp then return {} end
    local out = {}
    local R = Config["Radius"] or 80
    -- 1) folder Enemies chuan cua game
    local enemies = WS:FindFirstChild("Enemies")
    if enemies then
        for _, mob in pairs(enemies:GetChildren()) do
            if mob:FindFirstChild("Humanoid") and mob:FindFirstChild("HumanoidRootPart")
                and mob.Humanoid.Health > 0 then
                if (mob.HumanoidRootPart.Position - hrp.Position).Magnitude <= R then
                    table.insert(out, mob)
                end
            end
        end
    end
    -- 2) boss/golem spawn ngoai folder (model co Humanoid, chan player + char minh)
    for _, obj in pairs(WS:GetChildren()) do
        if #out >= 20 then break end
        if obj:IsA("Model") and obj ~= getChar()
            and not game.Players:GetPlayerFromCharacter(obj)
            and obj:FindFirstChild("Humanoid") and obj:FindFirstChild("HumanoidRootPart")
            and obj.Humanoid.Health > 0 then
            if (obj.HumanoidRootPart.Position - hrp.Position).Magnitude <= R then
                local dup = false
                for _, m in ipairs(out) do
                    if m == obj then dup = true break end
                end
                if not dup then
                    table.insert(out, obj)
                end
            end
        end
    end
    return out
end

-- ================= AURA LOOP — bat la danh luon =================
LP.CharacterAdded:Connect(function()
    task.wait(1)
    tracked = {}
    Stats.LastEvent = "hoi sinh — danh tiep"
end)

Stats.LastEvent = "-"

task.spawn(function()
    tw(1.5) -- cho char load xong roi DANH LUON
    while true do
        if RunFlag() and Config["Auto Attack"] then
            local ok, err = pcall(function()
                if Config["Auto Equip"] then
                    autoEquip()
                end
                local list = mobsInRadius()
                if #list > 0 then
                    for _, mob in ipairs(list) do
                        attachDamageTrack(mob)
                        attachKillTrack(mob)
                        fastHit(mob)
                    end
                    Stats.LastEvent = "dang danh " .. #list .. " mob"
                else
                    Stats.LastEvent = "khong co mob trong " .. (Config["Radius"] or 80) .. " studs"
                end
                -- M1 ao giu nhieu — moi 5 quet 1 lan
                clickCount = clickCount + 1
                if clickCount >= 5 then
                    clickCount = 0
                    autoClick()
                end
            end)
            if not ok then warn("[Rapid Aura] " .. tostring(err)) end
            tw(0.1)
        else
            Stats.LastEvent = "TAM DUNG"
            tw(0.5)
        end
    end
end)

-- ================= ANTI-AFK =================
LP.Idled:Connect(function()
    VU:CaptureController()
    VU:ClickButton2(Vector2.new())
end)

-- ================= GUI NHỎ GỌN (vang den Vxeze) =================
local HU = (gethui and gethui()) or game.CoreGui
pcall(function() HU.VxezeRapidAuraGui:Destroy() end)
local gui = Instance.new("ScreenGui")
gui.Name = "VxezeRapidAuraGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 70
pcall(function() gui.Parent = HU end)

local C3 = Color3.fromRGB
local COL = {
    BG = C3(10, 12, 18), PN = C3(20, 24, 36), PN2 = C3(32, 38, 56),
    ACC = C3(255, 60, 60), WT = C3(240, 240, 245), GY = C3(150, 155, 170),
    OK = C3(0, 255, 140), ON = C3(44, 26, 26),
}

local function mk(class, props, parent)
    local o = Instance.new(class)
    o.BorderSizePixel = 0
    for k, v in pairs(props or {}) do o[k] = v end
    o.Parent = parent
    return o
end

local function cor(o, r)
    mk("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o)
end

local main = mk("Frame", {
    Size = UDim2.new(0, 268, 0, 268),
    Position = UDim2.new(0, 10, 0.5, -134),
    BackgroundColor3 = COL.BG, Active = true, Draggable = true,
}, gui)
cor(main, 12)
mk("UIStroke", { Thickness = 1.5, Color = COL.ACC, Transparency = 0.4 }, main)

local hdr = mk("Frame", {
    Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = COL.PN,
}, main)
cor(hdr, 12)
mk("TextLabel", {
    Size = UDim2.new(1, -56, 1, 0), Position = UDim2.new(0, 10, 0, 0),
    BackgroundTransparency = 1, Text = "VXEZE RAPID AURA",
    TextColor3 = COL.ACC, TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamBold, TextSize = 13,
}, hdr)
local closeBtn = mk("TextButton", {
    Size = UDim2.new(0, 26, 1, 0), Position = UDim2.new(1, -28, 0, 0),
    BackgroundTransparency = 1, Text = "X", TextColor3 = COL.ACC,
    Font = Enum.Font.GothamBold, TextSize = 14,
}, hdr)
closeBtn.MouseButton1Click:Connect(function()
    getgenv().VXEZE_RAPID_AURA = false
    SaveConfig()
    gui:Destroy()
end)

local statusLbl = mk("TextLabel", {
    Size = UDim2.new(1, -16, 0, 18), Position = UDim2.new(0, 8, 0, 38),
    BackgroundTransparency = 1, Text = "> ...",
    TextColor3 = COL.WT, TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.Gotham, TextSize = 10,
}, main)

local dmgLbl = mk("TextLabel", {
    Size = UDim2.new(1, -16, 0, 18), Position = UDim2.new(0, 8, 0, 56),
    BackgroundTransparency = 1, Text = "Damage: 0 | Kill: 0",
    TextColor3 = COL.OK, TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamBold, TextSize = 10,
}, main)

local expLbl = mk("TextLabel", {
    Size = UDim2.new(1, -16, 0, 18), Position = UDim2.new(0, 8, 0, 74),
    BackgroundTransparency = 1, Text = "Lv ? | EXP: ?",
    TextColor3 = COL.GY, TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.Gotham, TextSize = 10,
}, main)

local sc = mk("ScrollingFrame", {
    Size = UDim2.new(1, -12, 1, -90),
    Position = UDim2.new(0, 6, 0, 96),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 3, ScrollBarImageColor3 = COL.ACC,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, main)
mk("UIListLayout", {
    Padding = UDim2.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
}, sc)

local ord = 0
local function nextOrd()
    ord = ord + 1
    return ord
end

local Refreshers = {}

local function addToggle(label, key, onChange)
    local btn = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = COL.PN2,
        Text = "", TextSize = 11, Font = Enum.Font.Gotham,
        LayoutOrder = nextOrd(),
    }, sc)
    cor(btn, 6)
    local function refresh()
        btn.Text = (Config[key] and "ON  |  " or "OFF |  ") .. label
        btn.TextColor3 = Config[key] and COL.OK or COL.GY
        btn.BackgroundColor3 = Config[key] and COL.ON or COL.PN2
    end
    refresh()
    btn.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        refresh()
        if onChange then task.spawn(onChange, Config[key]) end
        SaveConfig()
    end)
    table.insert(Refreshers, refresh)
    return btn, refresh
end

local function addSlider(label, key, minV, maxV, step)
    local box = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = COL.PN,
        LayoutOrder = nextOrd(),
    }, sc)
    cor(box, 6)
    local lbl = mk("TextLabel", {
        Size = UDim2.new(1, -10, 1, 0), Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1, Text = "",
        TextColor3 = COL.WT, TextSize = 10, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, box)
    local function refresh()
        lbl.Text = label .. ": " .. tostring(Config[key])
    end
    refresh()
    box.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local rel = (input.Position.X - box.AbsolutePosition.X) / math.max(1, box.AbsoluteSize.X)
        local v = minV + (maxV - minV) * rel
        v = math.floor(v / step + 0.5) * step
        Config[key] = math.clamp(v, minV, maxV)
        refresh()
        SaveConfig()
    end)
end

addToggle("Auto Attack (bat la danh luon)", "Auto Attack")
addToggle("Auto Equip (cam vu khi tu dong)", "Auto Equip")
addSlider("Tam danh (studs)", "Radius", 30, 150, 5)

local stopBtn = mk("TextButton", {
    Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = C3(70, 26, 26),
    Text = "STOP — dung danh", TextColor3 = COL.WT, TextSize = 11,
    Font = Enum.Font.GothamBold, LayoutOrder = nextOrd(),
}, sc)
cor(stopBtn, 6)
stopBtn.MouseButton1Click:Connect(function()
    Config["Auto Attack"] = false
    for _, rf in ipairs(Refreshers) do pcall(rf) end
    SaveConfig()
    Notify("Vxeze Rapid Aura", "Da STOP", 3)
end)

mk("TextLabel", {
    Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1,
    Text = "Chi danh MOB trong tam (khong danh nguoi).\nDamage + EXP dem THAT tu game.",
    TextColor3 = COL.GY, TextSize = 9, Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
    LayoutOrder = nextOrd(),
}, sc)

-- Status updater 0.5s
task.spawn(function()
    while RunFlag() and gui.Parent do
        pcall(function()
            statusLbl.Text = "> " .. tostring(Stats.LastEvent or "-")
            dmgLbl.Text = "Damage: " .. math.floor(Stats.Damage) .. " | Kill: " .. Stats.Kills
            if Stats.HasRealExp then
                expLbl.Text = "Lv " .. getLevel() .. " (+" .. Stats.LevelUps .. ") | EXP: " .. math.floor(Stats.Exp)
            else
                expLbl.Text = "Lv " .. getLevel() .. " (+" .. Stats.LevelUps .. ") | EXP game khong cho doc — dem Kill"
            end
        end)
        tw(0.5)
    end
end)

Notify("Vxeze Rapid Aura", "Loaded! Dang tu dong danh mob trong 80 studs!", 5)
SaveConfig()
