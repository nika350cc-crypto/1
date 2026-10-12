--============================================================
-- SI CÚT HUB - LIQUID GLASS + DYNAMIC ISLAND
-- UI ONLY / DEMO GUI - KHÔNG CÓ CHỨC NĂNG EXPLOIT
--
-- Tính năng:
-- • Liquid Glass phong cách giao diện iOS hiện đại: nhiều lớp kính, highlight, viền sáng
-- • Dynamic Island kiểu iPhone: capsule đen, camera giả lập, morph animation
-- • Kéo menu CHỈ bằng thanh đầu menu
-- • Bo 4 góc
-- • Settings
-- • Độ mờ kính
-- • Màu chữ: Trắng / Xanh / Xanh lá / Tím / Vàng / Đen
-- • Màu chữ Rainbow
-- • Dynamic Island nhỏ gọn, bấm giữ để mở rộng, nhả ra co lại đàn hồi và đếm thời gian
-- • Chỉ thay đổi giao diện; không chỉnh Humanoid/tốc độ/nhảy hay thuộc tính nhân vật
-- • Animation mở / thu nhỏ / xác nhận đóng
--============================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local scriptStartedAt = os.clock() -- Tính thời gian ngay từ đầu LocalScript.

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

--============================================================
-- CONFIG
--============================================================

local LOGO_ID = "rbxassetid://132011680945971"

local Config = {
    Theme = "Glass",
    GlassOpacity = 0.28,
    TextColor = Color3.fromRGB(240,247,255),
    Rainbow = false,
}

local C = {
    White = Color3.fromRGB(242,248,255),
    Black = Color3.fromRGB(12,16,22),
    Blue = Color3.fromRGB(80,180,255),
    BlueDark = Color3.fromRGB(28,105,175),
    Green = Color3.fromRGB(90,225,155),
    Purple = Color3.fromRGB(190,125,255),
    Yellow = Color3.fromRGB(255,215,90),
    Gray = Color3.fromRGB(150,170,190),
    Glass = Color3.fromRGB(43,63,82),
    GlassDark = Color3.fromRGB(12,25,39),
    Panel = Color3.fromRGB(7,20,35),
    Red = Color3.fromRGB(125,50,75),
}

local function tween(obj, time, props, style, direction)
    local info = TweenInfo.new(
        time or 0.35,
        style or Enum.EasingStyle.Quint,
        direction or Enum.EasingDirection.Out
    )
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

local function round(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 14)
    c.Parent = obj
    return c
end

local function stroke(obj, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or C.Blue
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = obj
    return s
end

local function label(parent, text, size, pos, font, color, textSize)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Size = size
    l.Position = pos
    l.Text = text
    l.Font = font or Enum.Font.Gotham
    l.TextColor3 = color or Config.TextColor
    l.TextSize = textSize or 14
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

-- Roblox BlurEffect làm mờ toàn bộ cảnh 3D, không riêng một khung GUI.
-- Vì vậy bản này dùng lớp kính trong suốt/gradient để tránh làm mờ cả game.

--============================================================
-- SCREEN GUI
--============================================================

local Gui = Instance.new("ScreenGui")
Gui.Name = "SiCut_LiquidGlass_V2"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = PlayerGui

local Scale = Instance.new("UIScale")
Scale.Parent = Gui

local Camera = workspace.CurrentCamera

local function updateScale()
    if Camera then
        Scale.Scale = math.clamp(Camera.ViewportSize.X / 1000, 0.58, 1)
    end
end

updateScale()

if Camera then
    Camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

--============================================================
-- MAIN
--============================================================

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0,900,0,555)
Main.Position = UDim2.new(0.5,-450,0.5,-277)
Main.BackgroundColor3 = Color3.fromRGB(112,166,205)
Main.BackgroundTransparency = Config.GlassOpacity
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = Gui
round(Main,22)

local MainStroke = stroke(Main, Color3.fromRGB(232,248,255), 1.35, 0.16)

-- Kính nhiều lớp
local GlassLayer = Instance.new("Frame")
GlassLayer.Size = UDim2.new(1,0,1,0)
GlassLayer.BackgroundColor3 = Color3.fromRGB(190,225,250)
GlassLayer.BackgroundTransparency = 0.86
GlassLayer.BorderSizePixel = 0
GlassLayer.ZIndex = 1
GlassLayer.Parent = Main
round(GlassLayer,22)

local GlassGradient = Instance.new("UIGradient")
GlassGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(222,242,255)),
    ColorSequenceKeypoint.new(0.28, Color3.fromRGB(112,158,190)),
    ColorSequenceKeypoint.new(0.62, Color3.fromRGB(34,61,83)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(155,205,235)),
})
GlassGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0,0.35),
    NumberSequenceKeypoint.new(0.45,0.86),
    NumberSequenceKeypoint.new(1,0.42),
})
GlassGradient.Rotation = 25
GlassGradient.Parent = GlassLayer

-- Các lớp phản chiếu mềm để tạo cảm giác kính nhiều chiều.
local GlassSheen = Instance.new("Frame")
GlassSheen.Name = "GlassSheen"
GlassSheen.Size = UDim2.new(1,0,0,155)
GlassSheen.Position = UDim2.new(0,0,0,0)
GlassSheen.BackgroundColor3 = Color3.fromRGB(235,248,255)
GlassSheen.BackgroundTransparency = 0.82
GlassSheen.BorderSizePixel = 0
GlassSheen.ZIndex = 2
GlassSheen.Parent = Main
round(GlassSheen,22)
local SheenGradient = Instance.new("UIGradient")
SheenGradient.Rotation = 90
SheenGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0,0.25),
    NumberSequenceKeypoint.new(0.5,0.78),
    NumberSequenceKeypoint.new(1,1),
})
SheenGradient.Parent = GlassSheen

local GlassEdge = Instance.new("Frame")
GlassEdge.Name = "InnerGlassEdge"
GlassEdge.Size = UDim2.new(1,-3,1,-3)
GlassEdge.Position = UDim2.new(0,1.5,0,1.5)
GlassEdge.BackgroundTransparency = 1
GlassEdge.BorderSizePixel = 0
GlassEdge.ZIndex = 4
GlassEdge.Parent = Main
round(GlassEdge,21)
local InnerStroke = stroke(GlassEdge,Color3.fromRGB(248,253,255),1,0.48)

local TopGlint = Instance.new("Frame")
TopGlint.Name = "TopGlint"
TopGlint.Size = UDim2.new(0.46,0,0,2)
TopGlint.Position = UDim2.new(0.08,0,0,1)
TopGlint.BackgroundColor3 = Color3.fromRGB(245,252,255)
TopGlint.BackgroundTransparency = 0.35
TopGlint.BorderSizePixel = 0
TopGlint.ZIndex = 5
TopGlint.Parent = Main
round(TopGlint,2)
local GlintGradient = Instance.new("UIGradient")
GlintGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0,1),
    NumberSequenceKeypoint.new(0.25,0.1),
    NumberSequenceKeypoint.new(0.75,0.1),
    NumberSequenceKeypoint.new(1,1),
})
GlintGradient.Parent = TopGlint

--============================================================
-- HEADER - CHỈ HEADER DÙNG ĐỂ KÉO
--============================================================

local HeaderBar = Instance.new("Frame")
HeaderBar.Name = "DragHeader"
HeaderBar.Size = UDim2.new(1,0,0,78)
HeaderBar.Position = UDim2.new(0,0,0,0)
HeaderBar.BackgroundTransparency = 1
HeaderBar.BorderSizePixel = 0
HeaderBar.ZIndex = 20
HeaderBar.Parent = Main

-- lớp bắt kéo trong header, không phủ lên nút
local DragArea = Instance.new("Frame")
DragArea.Name = "DragArea"
DragArea.Size = UDim2.new(1,-220,1,0)
DragArea.Position = UDim2.new(0,0,0,0)
DragArea.BackgroundTransparency = 1
DragArea.Active = true
DragArea.ZIndex = 21
DragArea.Parent = HeaderBar

--============================================================
-- SIDEBAR
--============================================================

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0,225,1,-78)
Sidebar.Position = UDim2.new(0,0,0,78)
Sidebar.BackgroundColor3 = C.GlassDark
Sidebar.BackgroundTransparency = math.min(Config.GlassOpacity+0.08,0.88)
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 5
Sidebar.Parent = Main
round(Sidebar,22)
stroke(Sidebar,Color3.fromRGB(160,215,255),1,0.72)

-- logo
local Logo = Instance.new("ImageLabel")
Logo.Size = UDim2.new(0,52,0,52)
Logo.Position = UDim2.new(0,18,0,13)
Logo.BackgroundTransparency = 1
Logo.Image = LOGO_ID
Logo.ScaleType = Enum.ScaleType.Fit
Logo.ZIndex = 23
Logo.Parent = HeaderBar

local Title = label(
    HeaderBar,
    "Si cút",
    UDim2.new(0,150,0,30),
    UDim2.new(0,82,0,17),
    Enum.Font.GothamBold,
    Config.TextColor,
    24
)
Title.ZIndex = 23

local Version = label(
    HeaderBar,
    "LIQUID GLASS • ELASTIC ISLAND",
    UDim2.new(0,200,0,20),
    UDim2.new(0,83,0,46),
    Enum.Font.GothamBold,
    C.Blue,
    10
)
Version.ZIndex = 23

--============================================================
-- TOP BUTTONS
--============================================================

local Minimize = Instance.new("TextButton")
Minimize.Size = UDim2.new(0,36,0,30)
Minimize.Position = UDim2.new(1,-84,0,20)
Minimize.BackgroundColor3 = Color3.fromRGB(55,80,105)
Minimize.BackgroundTransparency = 0.3
Minimize.BorderSizePixel = 0
Minimize.Text = "−"
Minimize.TextColor3 = Config.TextColor
Minimize.TextSize = 20
Minimize.Font = Enum.Font.GothamBold
Minimize.AutoButtonColor = false
Minimize.ZIndex = 30
Minimize.Parent = HeaderBar
round(Minimize,9)

local Close = Instance.new("TextButton")
Close.Size = UDim2.new(0,36,0,30)
Close.Position = UDim2.new(1,-42,0,20)
Close.BackgroundColor3 = C.Red
Close.BackgroundTransparency = 0.2
Close.BorderSizePixel = 0
Close.Text = "×"
Close.TextColor3 = C.White
Close.TextSize = 20
Close.Font = Enum.Font.GothamBold
Close.AutoButtonColor = false
Close.ZIndex = 30
Close.Parent = HeaderBar
round(Close,9)

local PercentButton = Instance.new("TextButton")
PercentButton.Name = "PercentButton"
PercentButton.Size = UDim2.new(0,36,0,30)
PercentButton.Position = UDim2.new(1,-126,0,20)
PercentButton.BackgroundColor3 = Color3.fromRGB(55,95,125)
PercentButton.BackgroundTransparency = 0.18
PercentButton.BorderSizePixel = 0
PercentButton.Text = "%"
PercentButton.TextColor3 = C.White
PercentButton.TextSize = 15
PercentButton.Font = Enum.Font.GothamBold
PercentButton.AutoButtonColor = false
PercentButton.ZIndex = 30
PercentButton.Parent = HeaderBar
round(PercentButton,9)

--============================================================
-- SIDEBAR CONTENT
--============================================================

local SettingsButton = Instance.new("TextButton")
SettingsButton.Size = UDim2.new(1,-24,0,46)
SettingsButton.Position = UDim2.new(0,12,0,18)
SettingsButton.BackgroundColor3 = Color3.fromRGB(70,125,165)
SettingsButton.BackgroundTransparency = 0.35
SettingsButton.BorderSizePixel = 0
SettingsButton.Text = ""
SettingsButton.AutoButtonColor = false
SettingsButton.ZIndex = 8
SettingsButton.Parent = Sidebar
round(SettingsButton,12)
stroke(SettingsButton,C.Blue,1,0.38)

local SettingsIcon = label(
    SettingsButton,
    "⚙",
    UDim2.new(0,40,1,0),
    UDim2.new(0,8,0,0),
    Enum.Font.GothamBold,
    C.Blue,
    20
)
SettingsIcon.TextXAlignment = Enum.TextXAlignment.Center
SettingsIcon.ZIndex = 9

local SettingsText = label(
    SettingsButton,
    "Settings",
    UDim2.new(1,-55,1,0),
    UDim2.new(0,52,0,0),
    Enum.Font.GothamMedium,
    Config.TextColor,
    14
)
SettingsText.ZIndex = 9

local PlayerAvatar = Instance.new("ImageLabel")
PlayerAvatar.Size = UDim2.new(0,44,0,44)
PlayerAvatar.Position = UDim2.new(0,16,1,-58)
PlayerAvatar.BackgroundColor3 = Color3.fromRGB(45,65,85)
PlayerAvatar.BackgroundTransparency = 0.2
PlayerAvatar.BorderSizePixel = 0
PlayerAvatar.ZIndex = 9
PlayerAvatar.Parent = Sidebar
round(PlayerAvatar,22)
stroke(PlayerAvatar,Color3.fromRGB(160,215,255),1,0.55)

pcall(function()
    local image = Players:GetUserThumbnailAsync(
        Player.UserId,
        Enum.ThumbnailType.HeadShot,
        Enum.ThumbnailSize.Size100x100
    )
    PlayerAvatar.Image = image
end)

local DisplayName = label(
    Sidebar,
    Player.DisplayName,
    UDim2.new(0,150,0,20),
    UDim2.new(0,69,1,-59),
    Enum.Font.GothamBold,
    Config.TextColor,
    13
)
DisplayName.ZIndex = 9

local Username = label(
    Sidebar,
    "@"..Player.Name,
    UDim2.new(0,150,0,18),
    UDim2.new(0,69,1,-39),
    Enum.Font.Gotham,
    C.Gray,
    10
)
Username.ZIndex = 9

--============================================================
-- CONTENT
--============================================================

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1,-225,1,-78)
Content.Position = UDim2.new(0,225,0,78)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ZIndex = 5
Content.Parent = Main

local Header = label(
    Content,
    "Settings",
    UDim2.new(1,-60,0,40),
    UDim2.new(0,30,0,25),
    Enum.Font.GothamBold,
    Config.TextColor,
    28
)
Header.ZIndex = 8

local Description = label(
    Content,
    "Tùy chỉnh Liquid Glass, độ mờ và màu chữ.",
    UDim2.new(1,-60,0,25),
    UDim2.new(0,30,0,64),
    Enum.Font.Gotham,
    C.Gray,
    13
)
Description.ZIndex = 8

--============================================================
-- THEME CARDS
--============================================================

local ThemeTitle = label(
    Content,
    "Giao diện",
    UDim2.new(1,-60,0,25),
    UDim2.new(0,30,0,101),
    Enum.Font.GothamBold,
    Config.TextColor,
    17
)
ThemeTitle.ZIndex = 8

local DefaultTheme = Instance.new("TextButton")
DefaultTheme.Size = UDim2.new(0,195,0,78)
DefaultTheme.Position = UDim2.new(0,30,0,134)
DefaultTheme.BackgroundColor3 = C.Panel
DefaultTheme.BackgroundTransparency = 0.12
DefaultTheme.BorderSizePixel = 0
DefaultTheme.Text = ""
DefaultTheme.AutoButtonColor = false
DefaultTheme.ZIndex = 8
DefaultTheme.Parent = Content
round(DefaultTheme,14)
stroke(DefaultTheme,C.Blue,1.2,0.3)

local DefaultTitle = label(DefaultTheme,"Mặc định",UDim2.new(1,-20,0,25),UDim2.new(0,12,0,11),Enum.Font.GothamBold,Config.TextColor,14)
DefaultTitle.ZIndex = 9

local DefaultDesc = label(DefaultTheme,"Xanh tối • rõ nét",UDim2.new(1,-20,0,25),UDim2.new(0,12,0,39),Enum.Font.Gotham,C.Gray,11)
DefaultDesc.ZIndex = 9

local GlassTheme = Instance.new("TextButton")
GlassTheme.Size = UDim2.new(0,195,0,78)
GlassTheme.Position = UDim2.new(0,240,0,134)
GlassTheme.BackgroundColor3 = Color3.fromRGB(80,135,175)
GlassTheme.BackgroundTransparency = 0.48
GlassTheme.BorderSizePixel = 0
GlassTheme.Text = ""
GlassTheme.AutoButtonColor = false
GlassTheme.ZIndex = 8
GlassTheme.Parent = Content
round(GlassTheme,14)
stroke(GlassTheme,Color3.fromRGB(165,220,255),1.4,0.1)

local GlassTitle = label(GlassTheme,"Kính lỏng",UDim2.new(1,-20,0,25),UDim2.new(0,12,0,11),Enum.Font.GothamBold,Config.TextColor,14)
GlassTitle.ZIndex = 9

local GlassDesc = label(GlassTheme,"Trong suốt • mờ nền • mượt",UDim2.new(1,-20,0,25),UDim2.new(0,12,0,39),Enum.Font.Gotham,C.Gray,11)
GlassDesc.ZIndex = 9

--============================================================
-- OPACITY
--============================================================

local OpacityTitle = label(Content,"Độ mờ kính",UDim2.new(1,-100,0,25),UDim2.new(0,30,0,232),Enum.Font.GothamBold,Config.TextColor,17)
OpacityTitle.ZIndex = 8

local OpacityValue = label(Content,"28%",UDim2.new(0,65,0,25),UDim2.new(1,-95,0,232),Enum.Font.GothamBold,C.Blue,14)
OpacityValue.TextXAlignment = Enum.TextXAlignment.Right
OpacityValue.ZIndex = 8

local Slider = Instance.new("Frame")
Slider.Size = UDim2.new(1,-60,0,8)
Slider.Position = UDim2.new(0,30,0,274)
Slider.BackgroundColor3 = Color3.fromRGB(40,60,80)
Slider.BackgroundTransparency = 0.2
Slider.BorderSizePixel = 0
Slider.ZIndex = 8
Slider.Parent = Content
round(Slider,8)

local Fill = Instance.new("Frame")
Fill.Size = UDim2.new(Config.GlassOpacity,0,1,0)
Fill.BackgroundColor3 = C.Blue
Fill.BorderSizePixel = 0
Fill.ZIndex = 9
Fill.Parent = Slider
round(Fill,8)

local Knob = Instance.new("TextButton")
Knob.Size = UDim2.new(0,22,0,22)
Knob.Position = UDim2.new(Config.GlassOpacity,-11,0.5,-11)
Knob.BackgroundColor3 = C.White
Knob.BorderSizePixel = 0
Knob.Text = ""
Knob.AutoButtonColor = false
Knob.ZIndex = 10
Knob.Parent = Slider
round(Knob,11)
stroke(Knob,C.Blue,2,0)

local OpacityDesc = label(Content,"Kéo thanh sang phải để kính trong hơn.",UDim2.new(1,-60,0,25),UDim2.new(0,30,0,291),Enum.Font.Gotham,C.Gray,11)
OpacityDesc.ZIndex = 8

--============================================================
-- TEXT COLOR
--============================================================

local ColorTitle = label(Content,"Màu chữ",UDim2.new(1,-60,0,25),UDim2.new(0,30,0,327),Enum.Font.GothamBold,Config.TextColor,17)
ColorTitle.ZIndex = 8

local ColorHolder = Instance.new("Frame")
ColorHolder.Size = UDim2.new(1,-60,0,42)
ColorHolder.Position = UDim2.new(0,30,0,360)
ColorHolder.BackgroundTransparency = 1
ColorHolder.ZIndex = 8
ColorHolder.Parent = Content

local Layout = Instance.new("UIListLayout")
Layout.FillDirection = Enum.FillDirection.Horizontal
Layout.Padding = UDim.new(0,9)
Layout.VerticalAlignment = Enum.VerticalAlignment.Center
Layout.Parent = ColorHolder

local setIslandText

local TextObjects = {
    Title, Header, ThemeTitle, OpacityTitle, ColorTitle,
    DefaultTitle, GlassTitle, SettingsText, DisplayName
}

local RainbowObjects = {
    Title, Header, ThemeTitle, OpacityTitle, ColorTitle,
    DefaultTitle, GlassTitle, SettingsText, DisplayName
}

local ConfirmTitle
local NoButton

local function setTextColor(color)
    Config.TextColor = color
    Config.Rainbow = false
    setIslandText("Màu chữ", "Đang chọn • Màu chữ")

    for _,obj in ipairs(TextObjects) do
        if obj and obj.Parent then
            obj.TextColor3 = color
        end
    end

    if ConfirmTitle then
        ConfirmTitle.TextColor3 = color
    end
    if NoButton then
        NoButton.TextColor3 = color
    end
end

local function createColor(name, color)
    local b = Instance.new("TextButton")
    b.Name = name
    b.Size = UDim2.new(0,42,0,38)
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Text = ""
    b.AutoButtonColor = false
    b.ZIndex = 10
    b.Parent = ColorHolder
    round(b,11)
    stroke(b,C.White,1,0.65)

    b.MouseButton1Click:Connect(function()
        setTextColor(color)
    end)

    return b
end

createColor("White",C.White)
createColor("Blue",C.Blue)
createColor("Green",C.Green)
createColor("Purple",C.Purple)
createColor("Yellow",C.Yellow)
createColor("Black",C.Black)

-- Rainbow button
local RainbowButton = Instance.new("TextButton")
RainbowButton.Size = UDim2.new(0,85,0,38)
RainbowButton.BackgroundColor3 = Color3.fromRGB(30,40,55)
RainbowButton.BackgroundTransparency = 0.1
RainbowButton.BorderSizePixel = 0
RainbowButton.Text = "RAINBOW"
RainbowButton.TextColor3 = C.White
RainbowButton.TextSize = 11
RainbowButton.Font = Enum.Font.GothamBold
RainbowButton.AutoButtonColor = false
RainbowButton.ZIndex = 10
RainbowButton.Parent = ColorHolder
round(RainbowButton,11)
stroke(RainbowButton,C.Blue,1,0.2)

RainbowButton.MouseButton1Click:Connect(function()
    Config.Rainbow = not Config.Rainbow
    if Config.Rainbow then
        RainbowButton.Text = "RAINBOW ✓"
        setIslandText("Rainbow", "Đang chọn • Màu chữ Rainbow")
    else
        RainbowButton.Text = "RAINBOW"
        setTextColor(Config.TextColor)
    end
end)

--============================================================
-- RAINBOW ANIMATION
--============================================================

local rainbowConnection

local rainbowElapsed = 0
rainbowConnection = RunService.RenderStepped:Connect(function(dt)
    rainbowElapsed += dt
    if rainbowElapsed < 0.05 then return end -- tối đa khoảng 20 lần/giây
    rainbowElapsed = 0

    if not Gui.Parent then
        rainbowConnection:Disconnect()
        return
    end

    if Config.Rainbow then
        local hue = (os.clock() * 0.22) % 1
        local color = Color3.fromHSV(hue,0.82,1)

        for _,obj in ipairs(RainbowObjects) do
            if obj and obj.Parent then
                obj.TextColor3 = color
            end
        end

        if ConfirmTitle and ConfirmTitle.Parent then
            ConfirmTitle.TextColor3 = color
        end

        if NoButton and NoButton.Parent then
            NoButton.TextColor3 = color
        end
    end
end)

--============================================================
-- STATUS
--============================================================

local Status = label(
    Content,
    "●  Kính lỏng đang bật",
    UDim2.new(1,-60,0,25),
    UDim2.new(0,30,1,-38),
    Enum.Font.GothamMedium,
    C.Green,
    12
)
Status.ZIndex = 8

--============================================================
-- APPLY THEMES
--============================================================

local function applyDefault()
    Config.Theme = "Default"

    tween(Main,0.45,{
        BackgroundColor3 = C.Panel,
        BackgroundTransparency = 0
    })

    tween(Sidebar,0.45,{
        BackgroundColor3 = C.Panel,
        BackgroundTransparency = 0
    })

    tween(GlassLayer,0.35,{
        BackgroundTransparency = 1
    })
    tween(GlassSheen,0.25,{BackgroundTransparency=1})
    InnerStroke.Transparency = 0.9

    MainStroke.Transparency = 0.18
    Status.Text = "●  Giao diện mặc định"
    setIslandText("Mặc định", "Đang chọn • Giao diện")
end

local function applyGlass()
    Config.Theme = "Glass"

    tween(Main,0.45,{
        BackgroundColor3 = C.Glass,
        BackgroundTransparency = Config.GlassOpacity
    })

    tween(Sidebar,0.45,{
        BackgroundColor3 = C.GlassDark,
        BackgroundTransparency = math.min(Config.GlassOpacity+0.08,0.88)
    })

    tween(GlassLayer,0.4,{
        BackgroundTransparency = 0.93
    })
    tween(GlassSheen,0.35,{BackgroundTransparency=0.91})
    InnerStroke.Transparency = 0.72

    MainStroke.Transparency = 0.07
    Status.Text = "●  Kính lỏng đang bật"
    setIslandText("Kính lỏng", "Đang chọn • Giao diện")
end

DefaultTheme.MouseButton1Click:Connect(applyDefault)
GlassTheme.MouseButton1Click:Connect(applyGlass)

--============================================================
-- OPACITY SLIDER
--============================================================

local draggingSlider = false

local function setOpacity(percent)
    percent = math.clamp(percent,0,90)
    local value = percent/100

    Config.GlassOpacity = value
    OpacityValue.Text = tostring(math.floor(percent)).."%"
    setIslandText("Độ mờ", "Đang chọn • Độ mờ " .. tostring(math.floor(percent)) .. "%")

    tween(Fill,0.12,{
        Size = UDim2.new(value,0,1,0)
    })

    tween(Knob,0.12,{
        Position = UDim2.new(value,-11,0.5,-11)
    })

    if Config.Theme == "Glass" then
        tween(Main,0.16,{
            BackgroundTransparency = value
        })

        tween(Sidebar,0.16,{
            BackgroundTransparency = math.min(value+0.08,0.88)
        })
    end
end

local function updateSlider(input)
    local x = input.Position.X
    local start = Slider.AbsolutePosition.X
    local width = Slider.AbsoluteSize.X
    local percent = ((x-start)/width)*90
    setOpacity(percent)
end

Slider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        draggingSlider = true
        updateSlider(input)
    end
end)

Knob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        draggingSlider = true
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not draggingSlider then return end

    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        updateSlider(input)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        draggingSlider = false
    end
end)

--============================================================
-- MINI LOGO
--============================================================

local MiniLogo = Instance.new("ImageButton")
MiniLogo.Size = UDim2.new(0,60,0,60)
MiniLogo.Position = UDim2.new(0,14,0.5,-30)
MiniLogo.BackgroundColor3 = C.GlassDark
MiniLogo.BackgroundTransparency = 0.1
MiniLogo.BorderSizePixel = 0
MiniLogo.Image = LOGO_ID
MiniLogo.ScaleType = Enum.ScaleType.Fit
MiniLogo.AutoButtonColor = false
MiniLogo.Visible = false
MiniLogo.ZIndex = 50
MiniLogo.Parent = Gui
round(MiniLogo,30)
stroke(MiniLogo,C.Blue,2,0)

-- Dynamic Island kiểu iPhone: viên thuốc đen, camera/sensor bên phải, nội dung bên trái.
local Island = Instance.new("TextButton")
Island.Name = "DynamicIsland"
Island.AnchorPoint = Vector2.new(0.5,0)
Island.Size = UDim2.new(0,96,0,30)
Island.Position = UDim2.new(0.5,0,0,8)
Island.BackgroundColor3 = Color3.fromRGB(2,3,6)
Island.BackgroundTransparency = 0
Island.BorderSizePixel = 0
Island.Text = ""
Island.AutoButtonColor = false
Island.Visible = false
Island.ClipsDescendants = true
Island.ZIndex = 80
Island.Parent = Gui
round(Island,30)
local IslandStroke = stroke(Island,Color3.fromRGB(65,76,91),1,0.38)

local IslandGradient = Instance.new("UIGradient")
IslandGradient.Rotation = 90
IslandGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(18,21,27)),
    ColorSequenceKeypoint.new(0.5,Color3.fromRGB(2,3,6)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(12,15,20)),
})
IslandGradient.Parent = Island

-- Highlight subtil en haut de la capsule, pas de halo néon.
local IslandShine = Instance.new("Frame")
IslandShine.Name = "MovingGlassHighlight"
IslandShine.Size = UDim2.new(0.28,0,1.6,0)
IslandShine.Position = UDim2.new(-0.4,0,-0.3,0)
IslandShine.BackgroundColor3 = Color3.fromRGB(235,246,255)
IslandShine.BackgroundTransparency = 0.9
IslandShine.BorderSizePixel = 0
IslandShine.Rotation = 15
IslandShine.ZIndex = 81
IslandShine.Parent = Island
round(IslandShine,20)
local IslandShineGradient = Instance.new("UIGradient")
IslandShineGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0,1),
    NumberSequenceKeypoint.new(0.5,0.22),
    NumberSequenceKeypoint.new(1,1),
})
IslandShineGradient.Parent = IslandShine

-- Icone d'activité à gauche.
local IslandIcon = Instance.new("ImageLabel")
IslandIcon.Name = "ActivityIcon"
IslandIcon.BackgroundTransparency = 1
IslandIcon.Image = LOGO_ID
IslandIcon.ScaleType = Enum.ScaleType.Fit
IslandIcon.Size = UDim2.new(0,17,0,17)
IslandIcon.Position = UDim2.new(0,8,0.5,-8.5)
IslandIcon.ZIndex = 83
IslandIcon.Parent = Island

-- Faux capteur caméra façon iPhone à droite.
local CameraLens = Instance.new("Frame")
CameraLens.Name = "CameraLens"
CameraLens.Size = UDim2.new(0,11,0,11)
CameraLens.Position = UDim2.new(1,-18,0.5,-5.5)
CameraLens.BackgroundColor3 = Color3.fromRGB(13,18,29)
CameraLens.BorderSizePixel = 0
CameraLens.ZIndex = 83
CameraLens.Parent = Island
round(CameraLens,12)
stroke(CameraLens,Color3.fromRGB(48,58,77),1,0.18)
local LensCore = Instance.new("Frame")
LensCore.Size = UDim2.new(0,5,0,5)
LensCore.Position = UDim2.new(0.5,-2.5,0.5,-2.5)
LensCore.BackgroundColor3 = Color3.fromRGB(39,56,91)
LensCore.BorderSizePixel = 0
LensCore.ZIndex = 84
LensCore.Parent = CameraLens
round(LensCore,8)
local LensGlint = Instance.new("Frame")
LensGlint.Size = UDim2.new(0,2,0,2)
LensGlint.Position = UDim2.new(0.25,0,0.2,0)
LensGlint.BackgroundColor3 = Color3.fromRGB(155,195,255)
LensGlint.BorderSizePixel = 0
LensGlint.ZIndex = 85
LensGlint.Parent = LensCore
round(LensGlint,4)

local IslandTitle = Instance.new("TextLabel")
IslandTitle.BackgroundTransparency = 1
IslandTitle.Position = UDim2.new(0,32,0,7)
IslandTitle.Size = UDim2.new(1,-60,0,15)
IslandTitle.Font = Enum.Font.GothamSemibold
IslandTitle.Text = "Si cút • Settings"
IslandTitle.TextColor3 = Color3.fromRGB(248,250,255)
IslandTitle.TextSize = 10
IslandTitle.TextXAlignment = Enum.TextXAlignment.Left
IslandTitle.TextTruncate = Enum.TextTruncate.AtEnd
IslandTitle.ZIndex = 82
IslandTitle.Parent = Island

local IslandSub = Instance.new("TextLabel")
IslandSub.BackgroundTransparency = 1
IslandSub.Position = UDim2.new(0,32,0,29)
IslandSub.Size = UDim2.new(1,-60,0,15)
IslandSub.Font = Enum.Font.Gotham
IslandSub.Text = "00:00 • Đang chạy"
IslandSub.TextColor3 = Color3.fromRGB(153,205,255)
IslandSub.TextSize = 10
IslandSub.TextXAlignment = Enum.TextXAlignment.Left
IslandSub.TextTruncate = Enum.TextTruncate.AtEnd
IslandSub.ZIndex = 82
IslandSub.Parent = Island

--============================================================
-- CONFIRM CLOSE
--============================================================

local Overlay = Instance.new("Frame")
Overlay.Size = UDim2.new(1,0,1,0)
Overlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
Overlay.BackgroundTransparency = 1
Overlay.BorderSizePixel = 0
Overlay.Visible = false
Overlay.ZIndex = 100
Overlay.Parent = Gui

local Confirm = Instance.new("Frame")
Confirm.Size = UDim2.new(0,390,0,205)
Confirm.Position = UDim2.new(0.5,-195,0.5,-102)
Confirm.BackgroundColor3 = C.Glass
Confirm.BackgroundTransparency = 0.12
Confirm.BorderSizePixel = 0
Confirm.ZIndex = 101
Confirm.Parent = Overlay
round(Confirm,18)
stroke(Confirm,C.Blue,1.5,0.08)

local ConfirmLogo = Instance.new("ImageLabel")
ConfirmLogo.Size = UDim2.new(0,50,0,50)
ConfirmLogo.Position = UDim2.new(0,20,0,20)
ConfirmLogo.BackgroundTransparency = 1
ConfirmLogo.Image = LOGO_ID
ConfirmLogo.ZIndex = 103
ConfirmLogo.Parent = Confirm

ConfirmTitle = label(
    Confirm,
    "Đóng Si cút?",
    UDim2.new(1,-90,0,32),
    UDim2.new(0,82,0,20),
    Enum.Font.GothamBold,
    Config.TextColor,
    21
)
ConfirmTitle.ZIndex = 103

local ConfirmText = label(
    Confirm,
    "Bạn có chắc muốn đóng menu không?",
    UDim2.new(1,-40,0,35),
    UDim2.new(0,20,0,82),
    Enum.Font.Gotham,
    C.Gray,
    13
)
ConfirmText.TextXAlignment = Enum.TextXAlignment.Center
ConfirmText.ZIndex = 103

NoButton = Instance.new("TextButton")
NoButton.Size = UDim2.new(0,130,0,40)
NoButton.Position = UDim2.new(0,45,1,-58)
NoButton.BackgroundColor3 = Color3.fromRGB(35,60,82)
NoButton.BackgroundTransparency = 0.15
NoButton.BorderSizePixel = 0
NoButton.Text = "Không"
NoButton.TextColor3 = Config.TextColor
NoButton.TextSize = 13
NoButton.Font = Enum.Font.GothamBold
NoButton.AutoButtonColor = false
NoButton.ZIndex = 103
NoButton.Parent = Confirm
round(NoButton,10)

local YesButton = Instance.new("TextButton")
YesButton.Size = UDim2.new(0,130,0,40)
YesButton.Position = UDim2.new(1,-175,1,-58)
YesButton.BackgroundColor3 = C.BlueDark
YesButton.BorderSizePixel = 0
YesButton.Text = "Có"
YesButton.TextColor3 = C.White
YesButton.TextSize = 13
YesButton.Font = Enum.Font.GothamBold
YesButton.AutoButtonColor = false
YesButton.ZIndex = 103
YesButton.Parent = Confirm
round(YesButton,10)

-- Vị trí/kích thước chuẩn của menu
local normalSize = UDim2.new(0,900,0,555)
local normalPos = UDim2.new(0.5,-450,0.5,-277)
local dynamicIslandMode = false
local transitionBusy = false

setIslandText = function(title, detail)
    IslandTitle.Text = "Si cút • " .. (title or "Settings")
    IslandSub.Text = detail or "Đang chọn • Cài đặt"
end

local islandShineRunning = false
local islandExpanded = false
local holdInput = nil
local compactSize = UDim2.new(0,96,0,30)
local expandedSize = UDim2.new(0,232,0,62)
local compactIconSize = UDim2.new(0,17,0,17)
local expandedIconSize = UDim2.new(0,25,0,25)

local function formatElapsed(seconds)
    seconds = math.max(0, math.floor(seconds))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    if hours > 0 then
        return string.format("%02d:%02d:%02d", hours, minutes, secs)
    end
    return string.format("%02d:%02d", minutes, secs)
end

local function refreshIslandTimer()
    do
        local elapsed = formatElapsed(os.clock() - scriptStartedAt)
        if islandExpanded then
            IslandTitle.Text = "Si cút • Dynamic Island"
            IslandSub.Text = "◷  " .. elapsed .. "  •  Đang hoạt động"
        else
            IslandTitle.Text = "◷ " .. elapsed
            IslandSub.Text = ""
        end
    end
end

local function animateIslandShine()
    if islandShineRunning then return end
    islandShineRunning = true
    task.spawn(function()
        while Gui.Parent and Island.Parent and Island.Visible do
            IslandShine.Position = UDim2.new(-0.45,0,-0.4,0)
            local shineTween = tween(IslandShine,1.0,{
                Position = UDim2.new(1.15,0,-0.4,0)
            },Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)
            shineTween.Completed:Wait()
            task.wait(1.8)
        end
        islandShineRunning = false
    end)
end

local function expandIsland()
    if not dynamicIslandMode or islandExpanded or transitionBusy then return end
    islandExpanded = true
    IslandTitle.Position = UDim2.new(0,32,0,7)
    IslandTitle.Size = UDim2.new(1,-60,0,15)
    IslandTitle.TextSize = 10
    refreshIslandTimer()
    tween(Island,0.38,{
        Size = expandedSize,
        Position = UDim2.new(0.5,0,0,8)
    },Enum.EasingStyle.Back,Enum.EasingDirection.Out)
    tween(IslandIcon,0.28,{Size=expandedIconSize,Position=UDim2.new(0,11,0.5,-12.5)},Enum.EasingStyle.Back)
    tween(CameraLens,0.28,{Size=UDim2.new(0,19,0,19),Position=UDim2.new(1,-29,0.5,-9)},Enum.EasingStyle.Back)
    tween(LensCore,0.22,{Size=UDim2.new(0,9,0,9),Position=UDim2.new(0.5,-4.5,0.5,-4.5)})
    tween(LensGlint,0.22,{Size=UDim2.new(0,3,0,3)})
    tween(IslandTitle,0.18,{TextTransparency=0})
    tween(IslandSub,0.22,{TextTransparency=0})
end

local function collapseIsland()
    if not dynamicIslandMode or not islandExpanded then return end
    islandExpanded = false
    refreshIslandTimer()
    tween(Island,0.42,{
        Size = compactSize,
        Position = UDim2.new(0.5,0,0,8)
    },Enum.EasingStyle.Elastic,Enum.EasingDirection.Out)
    tween(IslandIcon,0.28,{Size=compactIconSize,Position=UDim2.new(0,8,0.5,-8.5)},Enum.EasingStyle.Sine)
    tween(CameraLens,0.28,{Size=UDim2.new(0,11,0,11),Position=UDim2.new(1,-18,0.5,-5.5)},Enum.EasingStyle.Sine)
    tween(LensCore,0.22,{Size=UDim2.new(0,5,0,5),Position=UDim2.new(0.5,-2.5,0.5,-2.5)})
    tween(LensGlint,0.22,{Size=UDim2.new(0,2,0,2)})
    tween(IslandSub,0.12,{TextTransparency=1})
    task.delay(0.12,function()
        if dynamicIslandMode and not islandExpanded then
            IslandTitle.Text = "◷ " .. formatElapsed(os.clock() - scriptStartedAt)
            IslandTitle.Position = UDim2.new(0,31,0.5,-7)
            IslandTitle.Size = UDim2.new(1,-55,0,14)
            IslandTitle.TextSize = 10
            IslandSub.Text = ""
            IslandTitle.TextTransparency = 0
        end
    end)
end

local function enterDynamicIsland()
    if transitionBusy or dynamicIslandMode then return end
    transitionBusy = true
    dynamicIslandMode = true
    islandExpanded = false
    PercentButton.Active = false
    local out = tween(Main,0.25,{
        Size = UDim2.new(0,24,0,14),
        Position = UDim2.new(0.5,-12,0.5,-7),
        BackgroundTransparency = 1,
        Rotation = 1.5
    },Enum.EasingStyle.Quint,Enum.EasingDirection.In)
    out.Completed:Once(function()
        Main.Visible = false
        Main.Rotation = 0
        Island.Visible = true
        Island.BackgroundTransparency = 0
        refreshIslandTimer() -- Hiện đúng thời gian đã chạy, kể cả khi menu mở lâu.
        Island.Size = UDim2.new(0,8,0,8)
        Island.Position = UDim2.new(0.5,0,0,8)
        IslandTitle.Position = UDim2.new(0,31,0.5,-7)
        IslandTitle.Size = UDim2.new(1,-55,0,14)
        IslandTitle.TextSize = 10
        IslandTitle.TextTransparency = 1
        IslandSub.TextTransparency = 1
        IslandIcon.ImageTransparency = 0
        IslandIcon.Size = compactIconSize
        IslandIcon.Position = UDim2.new(0,8,0.5,-8.5)
        CameraLens.Size = UDim2.new(0,11,0,11)
        CameraLens.Position = UDim2.new(1,-18,0.5,-5.5)
        CameraLens.BackgroundTransparency = 0
        LensCore.BackgroundTransparency = 0
        LensGlint.BackgroundTransparency = 0
        tween(Island,0.42,{
            Size = compactSize,
            Position = UDim2.new(0.5,0,0,8)
        },Enum.EasingStyle.Elastic,Enum.EasingDirection.Out)
        refreshIslandTimer()
        tween(IslandTitle,0.24,{TextTransparency=0},Enum.EasingStyle.Sine)
        task.delay(0.48,function()
            transitionBusy = false
            PercentButton.Active = true
            if Island.Visible then animateIslandShine() end
        end)
    end)
end

local function leaveDynamicIsland()
    if transitionBusy or not dynamicIslandMode then return end
    transitionBusy = true
    tween(IslandTitle,0.1,{TextTransparency=1})
    tween(IslandSub,0.1,{TextTransparency=1})
    tween(IslandIcon,0.1,{ImageTransparency=1})
    tween(CameraLens,0.1,{BackgroundTransparency=1})
    tween(LensCore,0.1,{BackgroundTransparency=1})
    tween(LensGlint,0.1,{BackgroundTransparency=1})
    local out = tween(Island,0.25,{
        Size = UDim2.new(0,8,0,8),
        Position = UDim2.new(0.5,0,0,8),
        BackgroundTransparency = 1
    },Enum.EasingStyle.Back,Enum.EasingDirection.In)
    out.Completed:Once(function()
        Island.Visible = false
        Main.Visible = true
        Main.Size = UDim2.new(0,24,0,16)
        Main.Position = UDim2.new(0.5,-12,0.5,-8)
        Main.BackgroundTransparency = 1
        Main.Rotation = -1
        tween(Main,0.52,{
            Size = normalSize,
            Position = normalPos,
            BackgroundTransparency = Config.Theme == "Glass" and Config.GlassOpacity or 0,
            Rotation = 0
        },Enum.EasingStyle.Back,Enum.EasingDirection.Out)
        dynamicIslandMode = false
        islandExpanded = false
        task.delay(0.54,function() transitionBusy = false end)
    end)
end

PercentButton.MouseButton1Click:Connect(function()
    if dynamicIslandMode then
        leaveDynamicIsland()
    else
        setIslandText("Settings","Đang chọn • Cài đặt")
        enterDynamicIsland()
    end
end)

-- Tương tác kiểu iPhone:
-- • Chạm nhanh một lần: mở lại menu.
-- • Nhấn giữ: Island phóng to để xem đồng hồ/trạng thái; thả tay thì co đàn hồi.
local HOLD_THRESHOLD = 0.24
local holdTriggered = false
local holdToken = 0

Island.InputBegan:Connect(function(input)
    if not dynamicIslandMode or transitionBusy then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        holdInput = input
        holdTriggered = false
        holdToken += 1
        local thisToken = holdToken
        task.delay(HOLD_THRESHOLD, function()
            if holdInput and holdToken == thisToken and dynamicIslandMode and not transitionBusy then
                holdTriggered = true
                expandIsland()
            end
        end)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if not holdInput then return end
    local isRelease = input == holdInput
        or input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
    if not isRelease then return end

    holdInput = nil
    holdToken += 1 -- huỷ bộ đếm nhấn giữ nếu người dùng chạm nhanh
    if holdTriggered then
        collapseIsland()
    elseif dynamicIslandMode and not transitionBusy then
        leaveDynamicIsland()
    end
    holdTriggered = false
end)

-- Đồng hồ chỉ cập nhật một lần mỗi giây để giảm tải.
task.spawn(function()
    while Gui.Parent do
        if dynamicIslandMode then refreshIslandTimer() end
        task.wait(1)
    end
end)

SettingsButton.MouseButton1Click:Connect(function()
    setIslandText("Settings","Đang chọn • Cài đặt")
end)

--============================================================
-- OPEN / MINIMIZE ANIMATION
--============================================================


local function openMenu()
    Main.Visible = true
    Main.Size = UDim2.new(0,720,0,430)
    Main.Position = UDim2.new(0.5,-360,0.5,-215)
    Main.Rotation = -1

    tween(Main,0.55,{
        Size = normalSize,
        Position = normalPos,
        Rotation = 0
    },Enum.EasingStyle.Quint,Enum.EasingDirection.Out)
end

local function minimizeMenu()
    local t = tween(Main,0.42,{
        Size = UDim2.new(0,720,0,430),
        Position = UDim2.new(0.5,-360,0.5,-215),
        Rotation = 1
    },Enum.EasingStyle.Quint,Enum.EasingDirection.In)

    t.Completed:Connect(function()
        Main.Visible = false
        Main.Rotation = 0

        MiniLogo.Visible = true
        MiniLogo.Size = UDim2.new(0,5,0,5)

        tween(MiniLogo,0.45,{
            Size = UDim2.new(0,60,0,60)
        },Enum.EasingStyle.Back,Enum.EasingDirection.Out)
    end)
end

local function showConfirm()
    Overlay.Visible = true
    Overlay.BackgroundTransparency = 1

    tween(Overlay,0.25,{
        BackgroundTransparency = 0.32
    })

    Confirm.Size = UDim2.new(0,315,0,160)
    Confirm.Position = UDim2.new(0.5,-157,0.5,-80)

    tween(Confirm,0.38,{
        Size = UDim2.new(0,390,0,205),
        Position = UDim2.new(0.5,-195,0.5,-102)
    },Enum.EasingStyle.Back,Enum.EasingDirection.Out)
end

Minimize.MouseButton1Click:Connect(minimizeMenu)

MiniLogo.MouseButton1Click:Connect(function()
    MiniLogo.Visible = false
    openMenu()
end)

Close.MouseButton1Click:Connect(showConfirm)

NoButton.MouseButton1Click:Connect(function()
    tween(Overlay,0.2,{BackgroundTransparency=1})
    tween(Confirm,0.2,{Size=UDim2.new(0,315,0,160)})
    task.wait(0.2)
    Overlay.Visible = false
end)

YesButton.MouseButton1Click:Connect(function()
    tween(Overlay,0.2,{BackgroundTransparency=1})
    tween(Confirm,0.2,{Size=UDim2.new(0,315,0,160)})
    task.wait(0.2)

    Gui:Destroy()
end)

--============================================================
-- DRAG: CHỈ HEADER
--============================================================

local dragging = false
local dragStart
local startPos

DragArea.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPos = Main.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end

    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then

        local delta = input.Position - dragStart

        Main.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

--============================================================
-- HOVER
--============================================================

SettingsButton.MouseEnter:Connect(function()
    tween(SettingsButton,0.16,{BackgroundTransparency=0.12})
end)

SettingsButton.MouseLeave:Connect(function()
    tween(SettingsButton,0.16,{BackgroundTransparency=0.35})
end)

Minimize.MouseEnter:Connect(function()
    tween(Minimize,0.16,{BackgroundTransparency=0})
end)

Minimize.MouseLeave:Connect(function()
    tween(Minimize,0.16,{BackgroundTransparency=0.3})
end)

Close.MouseEnter:Connect(function()
    tween(Close,0.16,{
        BackgroundColor3=Color3.fromRGB(160,60,90),
        BackgroundTransparency=0
    })
end)

Close.MouseLeave:Connect(function()
    tween(Close,0.16,{
        BackgroundColor3=C.Red,
        BackgroundTransparency=0.2
    })
end)

--============================================================
-- START
--============================================================

setOpacity(Config.GlassOpacity * 100)
applyGlass()

print("Si Cut Liquid Glass UI loaded: tap Island to open, hold to expand.")
