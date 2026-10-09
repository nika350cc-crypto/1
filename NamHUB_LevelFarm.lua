-- Nam HUB - Level Farm Helper (Roblox Studio)
-- Use only in your own Roblox experience / authorized test place.
-- This script selects a level-appropriate NPC, computes a position 25 studs above it,
-- and optionally cycles through Gun/Sword tools. It does NOT exploit another game,
-- invoke combat remotes, or move NPCs by force.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LP = Players.LocalPlayer
if not LP then
    warn("[Nam HUB] Run this as a LocalScript.")
    return
end

-- ================= CONFIG =================
local Config = {
    ["Auto Farm Level"] = true,
    ["Mastery Farm"] = false,
    ["Above Mob Height"] = 25,
    ["Farm Radius"] = 450,
    ["Mastery Weapons"] = {"Gun", "Sword"},
    ["Mastery Switch Delay"] = 8,
    ["Target Refresh Delay"] = 0.5,
}

-- ================= DATA: MOB BY LEVEL =================
local MOB_MAP = {
    {lvl=5, name="Bandit"},
    {lvl=14, name="Monkey"},
    {lvl=25, name="Gorilla"},
    {lvl=35, name="Pirate"},
    {lvl=45, name="Brute"},
    {lvl=60, name="Desert Bandit"},
    {lvl=75, name="Desert Officer"},
    {lvl=90, name="Snow Bandit"},
    {lvl=100, name="Snowman"},
    {lvl=120, name="Chief Petty Officer"},
    {lvl=150, name="Sky Bandit"},
    {lvl=175, name="Dark Master"},
    {lvl=190, name="Prisoner"},
    {lvl=210, name="Dangerous Prisoner"},
    {lvl=225, name="Toga Warrior"},
    {lvl=250, name="Military Soldier"},
    {lvl=275, name="Galactic Pirate"},
    {lvl=300, name="God's Guard"},
    {lvl=325, name="Snow Trooper"},
    {lvl=350, name="Winter Warrior"},
    {lvl=375, name="Lab Subordinate"},
    {lvl=400, name="Fishman Warrior"},
    {lvl=425, name="Fishman Commando"},
    {lvl=450, name="God's Guard"},
    {lvl=475, name="Shanda"},
    {lvl=500, name="Royal Squad"},
    {lvl=525, name="Royal Soldier"},
    {lvl=550, name="Galley Pirate"},
    {lvl=575, name="Galley Captain"},
    {lvl=700, name="Raider"},
    {lvl=725, name="Mercenary"},
    {lvl=775, name="Swan Pirate"},
    {lvl=800, name="Factory Staff"},
    {lvl=875, name="Marine Lieutenant"},
    {lvl=900, name="Marine Captain"},
    {lvl=925, name="Zombie"},
    {lvl=975, name="Vampire"},
    {lvl=1000, name="Snow Trooper"},
    {lvl=1050, name="Winter Warrior"},
    {lvl=1100, name="Lab Subordinate"},
    {lvl=1150, name="Fishman Warrior"},
    {lvl=1175, name="Fishman Commando"},
    {lvl=1200, name="Sea Soldier"},
    {lvl=1250, name="Water Fighter"},
    {lvl=1275, name="Elemental Battler"},
    {lvl=1500, name="Pirate Millionaire"},
    {lvl=1575, name="Dragon Crew Warrior"},
    {lvl=1600, name="Dragon Crew Archer"},
    {lvl=1675, name="Female Islander"},
    {lvl=1700, name="Giant Islander"},
    {lvl=1725, name="Island Empress"},
    {lvl=1775, name="Fishman Raider"},
    {lvl=1800, name="Fishman Captain"},
    {lvl=1825, name="Forest Pirate"},
    {lvl=1850, name="Mythological Pirate"},
    {lvl=1875, name="Jungle Pirate"},
    {lvl=1900, name="Musketeer Pirate"},
    {lvl=1975, name="Ship Deckhand"},
    {lvl=2000, name="Ship Officer"},
    {lvl=2100, name="Cherry Bandit"},
    {lvl=2175, name="Cherry Captain"},
    {lvl=2225, name="Candy Pirate"},
    {lvl=2275, name="Candy Rebel"},
    {lvl=2325, name="Cocoa Warrior"},
}

-- ================= CHARACTER / LEVEL =================
local function GetLevel()
    -- Adjust this function to match the data layout in YOUR game.
    local data = LP:FindFirstChild("Data")
    local level = data and data:FindFirstChild("Level")
    if level and (level:IsA("IntValue") or level:IsA("NumberValue")) then
        return level.Value
    end
    return 1
end

local function GetCharacterParts()
    local character = LP.Character
    if not character then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health <= 0 or not root then return nil end
    return character, humanoid, root
end

local function GetEnemyFolder()
    -- In your own place, create Workspace.Enemies and put NPC models in it.
    return workspace:FindFirstChild("Enemies")
end

local function GetMappedEntry(level)
    local selected
    for _, entry in ipairs(MOB_MAP) do
        if entry.lvl <= level and (not selected or entry.lvl > selected.lvl) then
            selected = entry
        end
    end
    return selected
end

local function FindNearestMappedMob()
    local character, _, root = GetCharacterParts()
    local folder = GetEnemyFolder()
    if not character or not folder then return nil end

    local entry = GetMappedEntry(GetLevel())
    if not entry then return nil end

    local best, bestDistance
    for _, mob in ipairs(folder:GetChildren()) do
        local hum = mob:FindFirstChildOfClass("Humanoid")
        local mobRoot = mob:FindFirstChild("HumanoidRootPart")
        if mob ~= character and mob.Name:find(entry.name, 1, true)
            and hum and hum.Health > 0 and mobRoot then
            local distance = (mobRoot.Position - root.Position).Magnitude
            if distance <= Config["Farm Radius"]
                and (not bestDistance or distance < bestDistance) then
                best, bestDistance = mob, distance
            end
        end
    end
    return best, entry
end

local function GetFarmPosition(mob)
    local mobRoot = mob and mob:FindFirstChild("HumanoidRootPart")
    if not mobRoot then return nil end
    return mobRoot.Position + Vector3.new(0, Config["Above Mob Height"], 0)
end

-- ================= MASTERY TOOL HELPERS =================
local function ClassifyTool(tool)
    local name = tool.Name:lower()
    if name:find("gun", 1, true) or name:find("rifle", 1, true)
        or name:find("pistol", 1, true) or name:find("musket", 1, true) then
        return "Gun"
    end
    if name:find("sword", 1, true) or name:find("katana", 1, true)
        or name:find("blade", 1, true) or name:find("saber", 1, true) then
        return "Sword"
    end
    return nil
end

local function FindToolForCategory(category)
    local backpack = LP:FindFirstChildOfClass("Backpack")
    local character = LP.Character

    -- Prefer an already equipped matching tool.
    if character then
        for _, item in ipairs(character:GetChildren()) do
            if item:IsA("Tool") and ClassifyTool(item) == category then
                return item
            end
        end
    end

    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and ClassifyTool(item) == category then
                return item
            end
        end
    end
    return nil
end

local function EquipTool(tool)
    local character, humanoid = GetCharacterParts()
    if not character or not humanoid or not tool then return false end
    if tool.Parent == character then return true end
    if tool.Parent ~= LP:FindFirstChildOfClass("Backpack") then return false end
    humanoid:EquipTool(tool)
    return true
end

-- ================= SAFE CONTROL LOOP =================
-- This helper reports target + desired height and can cycle tools.
-- It intentionally does not teleport the player, force-move NPCs, or attack.
local running = true
local currentTarget = nil
local currentTargetEntry = nil
local masteryIndex = 1
local lastMasterySwitch = 0
local lastRefresh = 0

local function GetStatus()
    local mob, entry = FindNearestMappedMob()
    return {
        enabled = Config["Auto Farm Level"],
        level = GetLevel(),
        target = mob and mob.Name or "No target found",
        mappedMob = entry and entry.name or "No mapped mob",
        targetPosition = mob and GetFarmPosition(mob) or nil,
        masteryEnabled = Config["Mastery Farm"],
    }
end

task.spawn(function()
    while running do
        local now = os.clock()

        if Config["Auto Farm Level"] and now - lastRefresh >= Config["Target Refresh Delay"] then
            currentTarget, currentTargetEntry = FindNearestMappedMob()
            lastRefresh = now
            if currentTarget and currentTarget.Parent == nil then
                currentTarget = nil
                currentTargetEntry = nil
            end
        end

        if Config["Mastery Farm"] and now - lastMasterySwitch >= Config["Mastery Switch Delay"] then
            local categories = Config["Mastery Weapons"]
            if #categories > 0 then
                local category = categories[masteryIndex]
                local tool = category and FindToolForCategory(category)
                if tool then
                    EquipTool(tool)
                end
                masteryIndex = (masteryIndex % #categories) + 1
            end
            lastMasterySwitch = now
        end

        task.wait(0.15)
    end
end)

-- Print status periodically for Studio testing.
task.spawn(function()
    while running do
        local status = GetStatus()
        print(string.format(
            "[Nam HUB] Level=%s | Target=%s | Mapped=%s | Mastery=%s",
            tostring(status.level),
            tostring(status.target),
            tostring(status.mappedMob),
            tostring(status.masteryEnabled)
        ))
        task.wait(3)
    end
end)

-- You can change these settings while testing:
-- Config["Auto Farm Level"] = false
-- Config["Mastery Farm"] = true
-- Config["Above Mob Height"] = 25
-- Config["Farm Radius"] = 450

-- Expose helpers for additional Studio code in the same script.
_G.NamHubLevelFarm = {
    Config = Config,
    MobMap = MOB_MAP,
    FindNearestMappedMob = FindNearestMappedMob,
    GetFarmPosition = GetFarmPosition,
    FindToolForCategory = FindToolForCategory,
    GetStatus = GetStatus,
    Stop = function()
        running = false
    end,
}

print("[Nam HUB] Level Farm Helper loaded.")
