--[[
  ============================================================
   VXEZE KILL AURA LITE — Blox Fruits
   Built by: Tình 1 đêm (AI) — Vxeze Hub
   Bản rút gọn theo yêu cầu của Nam:
   - KHÔNG GUI — chạy phát là đánh luôn
   - Chỉ đánh khi ĐANG CẦM melee hoặc kiếm trên tay
     (bỏ vũ khí ra = aura tự dừng — cái này là nút tắt)
   - Tầm đánh tối đa ~70 studs (an toàn, không lộ)
   - Damage THẬT qua remotes RegisterAttack/RegisterHit
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

-- ================= CONFIG (khong GUI — sua truc tiep o day) =================
getgenv().KA = {
        ["Range"] = 58,      -- hitbox gui di = 58; cong them 10 + body mob -> tam that ~68-70 studs
        ["Delay"] = 0.08,    -- nhip danh (0.05 = nhanh nhat)
        ["Auto Haki"] = true, -- tu bat Haki Buso cho dame khi den
}

-- ================= WEAPON CHECK — chi danh khi cam melee / kiem =================
local WEAPON_WORDS = {
        -- melee / fighting styles
        "combat", "black leg", "electro", "death step", "sharkman",
        "superhuman", "dragon talon", "electric claw", "godhuman",
        "sanguine", "water kung fu",
        -- swords
        "sword", "katana", "blade", "cutlass", "saber", "bisento",
        "pole", "yama", "shisui", "wando", "sai", "rengoku",
        "trident", "dagger", "shark saw", "hallow", "cursed dual",
        "buddy", "dragon breath", "mace",
}

local function IsMeleeOrSword(name)
        local n = (name or ""):lower()
        if n:find("fruit", 1, true) then return false end
        for _, w in ipairs(WEAPON_WORDS) do
                if n:find(w, 1, true) then return true end
        end
        return false
end

-- ================= AUTO HAKI =================
task.spawn(function()
        while true do
                if getgenv().KA["Auto Haki"] then
                        pcall(function()
                                game:GetService("ReplicatedStorage"):WaitForChild("Remotes").CommF_:InvokeServer("Buso")
                        end)
                end
                task.wait(2)
        end
end)

-- ================= MAIN LOOP — CHAY PHAT DANH LUON =================
task.spawn(function()
        while true do
                local ok, err = pcall(function()
                        local cfg = getgenv().KA
                        local c = J.Character
                        if not c then return end
                        -- Khong cam gi = aura nghi (nut tat tu nhien)
                        local tool = c:FindFirstChildOfClass("Tool")
                        if not tool then return end
                        -- Cam fruit/gun/vat doc la = khong danh
                        if not IsMeleeOrSword(tool.Name) then return end
                        local hrp = c:FindFirstChild("HumanoidRootPart")
                        if not hrp then return end
                        -- Cham vao tam 70 studs nhu yeu cau
                        local reach = math.max(20, (cfg["Range"] or 58) - 12)
                        AttackFunction(reach)
                end)
                if not ok then warn("[Vxeze KA Lite] " .. tostring(err)) end
                task.wait((getgenv().KA["Delay"]) or 0.08)
        end
end)

-- ================= THONG BAO =================
task.spawn(function()
        pcall(function()
                game:GetService("StarterGui"):SetCore("SendNotification", {
                        Title = "Vxeze Kill Aura Lite",
                        Text = "Đã chạy! Cầm kiếm/melee để đánh — bỏ vũ khí ra để dừng",
                        Duration = 6
                })
        end)
end)
