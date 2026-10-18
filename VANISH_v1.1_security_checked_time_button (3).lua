--[[
════════════════════════════════════════════════════════════════════
  V A N I S H   v1.1  —  VISUAL EDITION
════════════════════════════════════════════════════════════════════
  Visuals • Crosshair • Watermark • Fullbright • Config Save/Load
  ESP options • Keybind Overlay • Movement utilities
════════════════════════════════════════════════════════════════════
]]
 
-- ╔══════════════════════════════════════════╗
-- ║        [1]  SERVICES & SETUP            ║
-- ╚══════════════════════════════════════════╝
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local HttpService        = game:GetService("HttpService")
local Lighting           = game:GetService("Lighting")
local Workspace          = game:GetService("Workspace")
local CoreGui            = game:GetService("CoreGui")
local Camera             = Workspace.CurrentCamera
local LocalPlayer        = Players.LocalPlayer
local Mouse              = LocalPlayer:GetMouse()
 
local function GetSafeGUI()
    local ok, r = pcall(function() return gethui() end)
    if ok and r then return r end
    return CoreGui
end
 
if getgenv().VanishCleanup then
    pcall(getgenv().VanishCleanup)
    task.wait(0.2)
end
 
local SetFullbright
 
-- ╔══════════════════════════════════════════╗
-- ║        [2]  CONFIGURATION               ║
-- ╚══════════════════════════════════════════╝
local CONFIG_FILE = "vanish_config.json"
 
local Config = {
    Rage = {
        HitboxExpander = false,
        FullBodyHitbox = false,
        HeadSize = 5,
        BodySize = 3,
        Transparency = 0.7,
        HitboxColor = Color3.fromRGB(255, 255, 255),
    },
    Visuals = {
        Enabled            = true,
        ToggleBind         = Enum.KeyCode.V,
        TeamCheck          = true,
        HighlightESP       = true,
        HighlightTransp    = 0.5,
        BoxESP             = false,
        NameESP            = true,
        HealthBar          = false,
        DistanceESP        = false,
        Tracers            = false,
        TracerOrigin       = "Bottom",
        Skeleton           = false,
        WallCheck          = true,
        IgnoreTransparency = 0.5,
        ColorVisible       = Color3.fromRGB(65, 170, 255),
        ColorHidden        = Color3.fromRGB(100, 190, 255),
        MaxDistance         = 1000,
    },
    Crosshair = {
        Enabled   = false,
        Size      = 8,
        Gap       = 4,
        Thickness = 1,
        Dot       = true,
        DotSize   = 2,
        Color     = Color3.fromRGB(55, 145, 255),
    },
    Combat = {
        RapidFire    = false,
        FireDelay    = 0.05,
        AutoShoot    = false,
        NoRecoil     = false,
    },
    Misc = {
        AntiAFK        = true,
        AntiKick       = false,
        Watermark      = true,
        Time           = false,
        Fullbright     = false,
        InfiniteJump   = false,
        KeybindOverlay = true,
        SpeedHack      = false,
        SpeedValue     = 16,
        Noclip         = false,
    },
    UI = {
        OpenKey = Enum.KeyCode.RightShift,
    },
}
 
-- ╔══════════════════════════════════════════╗
-- ║     [3]  CONFIG SAVE / LOAD SYSTEM      ║
-- ╚══════════════════════════════════════════╝
local function SerializeValue(v)
    local t = typeof(v)
    if t == "boolean" or t == "number" or t == "string" then return v end
    if t == "Color3" then
        return {_t = "c3", r = math.floor(v.R * 255), g = math.floor(v.G * 255), b = math.floor(v.B * 255)}
    end
    if t == "EnumItem" then
        return {_t = "enum", e = tostring(v.EnumType), n = v.Name}
    end
    return nil
end
 
local function DeserializeValue(v)
    if type(v) ~= "table" then return v end
    if v._t == "c3" then
        return Color3.fromRGB(v.r or 255, v.g or 255, v.b or 255)
    elseif v._t == "enum" then
        local ok, res = pcall(function() return Enum[v.e][v.n] end)
        if ok then return res end
    end
    return nil
end
 
local function SaveConfig()
    local data = {}
    for section, values in pairs(Config) do
        if type(values) == "table" then
            data[section] = {}
            for key, value in pairs(values) do
                local s = SerializeValue(value)
                if s ~= nil then data[section][key] = s end
            end
        end
    end
    pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(data))
    end)
end
 
local function LoadConfig()
    local ok, content = pcall(function()
        if isfile and isfile(CONFIG_FILE) then return readfile(CONFIG_FILE) end
        return nil
    end)
    if not ok or not content then return false end
    local ok2, data = pcall(function() return HttpService:JSONDecode(content) end)
    if not ok2 or type(data) ~= "table" then return false end
    for section, values in pairs(data) do
        if Config[section] and type(values) == "table" then
            for key, value in pairs(values) do
                if Config[section][key] ~= nil then
                    local d = DeserializeValue(value)
                    if d ~= nil then Config[section][key] = d end
                end
            end
        end
    end
    return true
end
 
local configLoaded = LoadConfig()
 
-- ╔══════════════════════════════════════════╗
-- ║     [4]  STATE & CONNECTION TRACKER     ║
-- ╚══════════════════════════════════════════╝
local State = {
    MenuOpen          = true,
    Running           = true,
    FrameCount        = 0,
    CurrentFPS        = 0,
    LastFPSUpdate     = tick(),
    OriginalWalkSpeed = 16,
}
 
local Connections    = {}
local OriginalSizes = {}
local OriginalColors = {}
local ESPCache       = {}
local OldHook        = nil
local OriginalLight  = {}
local LastShotTime   = 0
local AutoClickerConnection = nil
 
local function TrackConnection(conn)
    table.insert(Connections, conn)
    return conn
end
 
-- ╔══════════════════════════════════════════╗
-- ║       [5]  INPUT / BIND HELPERS         ║
-- ╚══════════════════════════════════════════╝
local InputManager = {}
function InputManager.Press()
    if mouse1press then
        mouse1press()
    elseif Input and Input.LeftDown then
        Input.LeftDown()
    else
        pcall(function()
            game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, true, game, 1)
        end)
    end
end
function InputManager.Release()
    if mouse1release then
        mouse1release()
    elseif Input and Input.LeftUp then
        Input.LeftUp()
    else
        pcall(function()
            game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, false, game, 1)
        end)
    end
end
 
local function DoesInputMatch(input, bind)
    if not bind or typeof(bind) ~= "EnumItem" then return false end
    if bind.EnumType == Enum.KeyCode then return input.KeyCode == bind end
    if bind.EnumType == Enum.UserInputType then return input.UserInputType == bind end
    return false
end
 
local function BindName(bind)
    if not bind then return "None" end
    if bind == Enum.UserInputType.MouseButton1 then return "Mouse1" end
    if bind == Enum.UserInputType.MouseButton2 then return "Mouse2" end
    if bind == Enum.UserInputType.MouseButton3 then return "Mouse3" end
    return bind.Name
end
 
-- ╔══════════════════════════════════════════╗
-- ║       [6]  UTILITY FUNCTIONS            ║
-- ╚══════════════════════════════════════════╝
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.IgnoreWater = true
 
local function IsAlive(plr)
    if not plr or plr == LocalPlayer then return false end
    local c = plr.Character
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return false end
    if not c:FindFirstChild("HumanoidRootPart") then return false end
    if not c:FindFirstChild("Head") then return false end
    return true
end
 
local function IsEnemyFor(plr, module)
    local tc = false
    if module == "ESP" then
        tc = Config.Visuals.TeamCheck
    end
    if not tc then return true end
    if not plr.Team or not LocalPlayer.Team then return true end
    return plr.Team ~= LocalPlayer.Team
end
 
local function CheckVisibility(character, forceCheck)
    if not forceCheck and not Config.Visuals.WallCheck then return true end
    local lc = LocalPlayer.Character
    if not lc then return true end
    local origin = Camera.CFrame.Position
    local head = character:FindFirstChild("Head")
    if not head then return false end
    local dir = head.Position - origin
    local ignore = {lc, Camera}
    for _ = 1, 5 do
        RayParams.FilterDescendantsInstances = ignore
        local res = Workspace:Raycast(origin, dir, RayParams)
        if not res then return true end
        if res.Instance:IsDescendantOf(character) then return true end
        if res.Instance.Transparency >= Config.Visuals.IgnoreTransparency
           or not res.Instance.CanCollide then
            table.insert(ignore, res.Instance)
        else
            return false
        end
    end
    return false
end
 
local function IsInRange(plr, maxDist)
    if not maxDist or maxDist <= 0 then return true end
    local char = plr.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    return (Camera.CFrame.Position - root.Position).Magnitude <= maxDist
end
 
local function GetBone(character, boneName)
    if boneName == "Head" then
        return character:FindFirstChild("Head")
    elseif boneName == "Torso" then
        return character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")
    elseif boneName == "Closest" then
        local mousePos = UserInputService:GetMouseLocation()
        local best, bestDist = nil, math.huge
        for _, part in ipairs(character:GetChildren()) do
            if part:IsA("BasePart") then
                local pos, vis = Camera:WorldToViewportPoint(part.Position)
                if vis then
                    local d = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                    if d < bestDist then bestDist = d; best = part end
                end
            end
        end
        return best or character:FindFirstChild("Head")
    end
    return character:FindFirstChild("Head")
end
 
local R15Bones = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}
local R6Bones = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
}
local function GetBoneConnections(char)
    return char:FindFirstChild("UpperTorso") and R15Bones or R6Bones
end
 
-- ╔══════════════════════════════════════════╗
-- ║       [7]  DRAWING OBJECTS              ║
-- ╚══════════════════════════════════════════╝
local CrossLines = {}
for i = 1, 4 do
    CrossLines[i] = Drawing.new("Line")
    CrossLines[i].Thickness = 1
    CrossLines[i].Color = Color3.fromRGB(55, 145, 255)
    CrossLines[i].Visible = false
end
local CrossDot = Drawing.new("Circle")
CrossDot.Thickness = 0; CrossDot.NumSides = 12; CrossDot.Filled = true
CrossDot.Visible = false; CrossDot.Color = Color3.fromRGB(55, 145, 255)
 
local WatermarkText = Drawing.new("Text")
WatermarkText.Size = 14; WatermarkText.Outline = true
WatermarkText.Color = Color3.fromRGB(70, 160, 255)
WatermarkText.Position = Vector2.new(10, 10); WatermarkText.Visible = false

local TimeText = Drawing.new("Text")
TimeText.Size = 14; TimeText.Outline = true
TimeText.Color = Color3.fromRGB(70, 160, 255)
TimeText.Position = Vector2.new(10, 30); TimeText.Visible = false
 
-- Keybind Overlay
local OverlayLines = {}
for i = 1, 11 do
    OverlayLines[i] = Drawing.new("Text")
    OverlayLines[i].Size = 13
    OverlayLines[i].Font = 2
    OverlayLines[i].Outline = true
    OverlayLines[i].Visible = false
end
 
-- ╔══════════════════════════════════════════╗
-- ║       [8]  ESP DRAWING CACHE            ║
-- ╚══════════════════════════════════════════╝
local MAX_SKELETON = 14
 
local function CreateESPObjects()
    local o = {}
    o.BoxLines = {}
    for i = 1, 4 do
        local l = Drawing.new("Line"); l.Thickness = 1; l.Visible = false
        o.BoxLines[i] = l
    end
    o.Name = Drawing.new("Text")
    o.Name.Size = 13; o.Name.Center = true; o.Name.Outline = true; o.Name.Visible = false
    o.Distance = Drawing.new("Text")
    o.Distance.Size = 12; o.Distance.Center = true; o.Distance.Outline = true; o.Distance.Visible = false
    o.HealthBg = Drawing.new("Line"); o.HealthBg.Thickness = 4; o.HealthBg.Visible = false
    o.HealthBg.Color = Color3.fromRGB(15, 15, 15)
    o.HealthFill = Drawing.new("Line"); o.HealthFill.Thickness = 2; o.HealthFill.Visible = false
    o.Tracer = Drawing.new("Line"); o.Tracer.Thickness = 1; o.Tracer.Visible = false
    o.SkeletonLines = {}
    for i = 1, MAX_SKELETON do
        local l = Drawing.new("Line"); l.Thickness = 1; l.Visible = false
        o.SkeletonLines[i] = l
    end
    return o
end
 
local function DestroyESPObjects(o)
    if not o then return end
    for _, l in ipairs(o.BoxLines) do pcall(function() l:Remove() end) end
    pcall(function() o.Name:Remove() end)
    pcall(function() o.Distance:Remove() end)
    pcall(function() o.HealthBg:Remove() end)
    pcall(function() o.HealthFill:Remove() end)
    pcall(function() o.Tracer:Remove() end)
    for _, l in ipairs(o.SkeletonLines) do pcall(function() l:Remove() end) end
end
 
local function HideESPObjects(o)
    if not o then return end
    for _, l in ipairs(o.BoxLines) do l.Visible = false end
    o.Name.Visible = false; o.Distance.Visible = false
    o.HealthBg.Visible = false; o.HealthFill.Visible = false
    o.Tracer.Visible = false
    for _, l in ipairs(o.SkeletonLines) do l.Visible = false end
end
 
local function GetESP(plr)
    if not ESPCache[plr] then ESPCache[plr] = CreateESPObjects() end
    return ESPCache[plr]
end
 
local function RemoveESP(plr)
    DestroyESPObjects(ESPCache[plr])
    ESPCache[plr] = nil
end
 
-- ╔══════════════════════════════════════════╗
-- ║    [9]  CENTRALIZED SLIDER SYSTEM       ║
-- ╚══════════════════════════════════════════╝
local ActiveSlider = nil
 
TrackConnection(UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        ActiveSlider = nil
    end
end))
 
TrackConnection(UserInputService.InputChanged:Connect(function(i)
    if ActiveSlider and i.UserInputType == Enum.UserInputType.MouseMovement then
        ActiveSlider(i.Position.X)
    end
end))
 
-- ╔══════════════════════════════════════════╗
-- ║       [10]  GUI LIBRARY                 ║
-- ╚══════════════════════════════════════════╝
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VanishSuite_v11"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() ScreenGui.Parent = GetSafeGUI() end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
 
local NotifContainer = Instance.new("Frame")
NotifContainer.Name = "Notifs"
NotifContainer.Size = UDim2.new(0, 260, 1, -20)
NotifContainer.Position = UDim2.new(1, -270, 0, 10)
NotifContainer.BackgroundTransparency = 1
NotifContainer.Parent = ScreenGui
local NotifLayout = Instance.new("UIListLayout", NotifContainer)
NotifLayout.Padding = UDim.new(0, 4)
NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
NotifLayout.SortOrder = Enum.SortOrder.LayoutOrder
 
local function Notify(text, duration, color)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 30)
    f.BackgroundColor3 = color or Color3.fromRGB(30, 30, 40)
    f.BackgroundTransparency = 0.15
    f.BorderSizePixel = 0
    f.Parent = NotifContainer
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local t = Instance.new("TextLabel", f)
    t.Size = UDim2.new(1, -10, 1, 0)
    t.Position = UDim2.new(0, 5, 0, 0)
    t.BackgroundTransparency = 1
    t.TextColor3 = Color3.fromRGB(220, 220, 220)
    t.Font = Enum.Font.GothamMedium
    t.TextSize = 12
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Text = text
    local bar = Instance.new("Frame", f)
    bar.Size = UDim2.new(0, 3, 1, -6)
    bar.Position = UDim2.new(0, 0, 0, 3)
    bar.BackgroundColor3 = Color3.fromRGB(40, 135, 255)
    bar.BorderSizePixel = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 2)
    task.delay(duration or 3, function()
        local tw1 = TweenService:Create(f, TweenInfo.new(0.4), {BackgroundTransparency = 1})
        local tw2 = TweenService:Create(t, TweenInfo.new(0.4), {TextTransparency = 1})
        tw1:Play(); tw2:Play()
        tw1.Completed:Wait()
        f:Destroy()
    end)
end
 
local Library = {}
local OrderCounter = 0
local function GetOrder() OrderCounter = OrderCounter + 1; return OrderCounter end
 
function Library:Window()
    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Size = UDim2.fromOffset(540, 580)
    Main.Position = UDim2.fromScale(0.5, 0.5)
    Main.AnchorPoint = Vector2.new(0.5, 0.5)
    Main.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    Main.Active = true
    Main.Draggable = true
    Main.Parent = ScreenGui
    Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
    local stroke = Instance.new("UIStroke", Main)
    stroke.Color = Color3.fromRGB(35, 105, 190)
    stroke.Thickness = 1
 
    local Title = Instance.new("TextLabel", Main)
    Title.Text = "VANISH  v1.1"
    Title.Size = UDim2.new(1, -20, 0, 38)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.TextColor3 = Color3.fromRGB(70, 160, 255)
    Title.Font = Enum.Font.GothamBlack
    Title.TextSize = 16
    Title.TextXAlignment = Enum.TextXAlignment.Left
 
    local TabBar = Instance.new("Frame", Main)
    TabBar.Size = UDim2.new(1, -20, 0, 30)
    TabBar.Position = UDim2.new(0, 10, 0, 40)
    TabBar.BackgroundTransparency = 1
    local TabLayout = Instance.new("UIListLayout", TabBar)
    TabLayout.FillDirection = Enum.FillDirection.Horizontal
    TabLayout.Padding = UDim.new(0, 4)
    TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
 
    local ContentFrame = Instance.new("Frame", Main)
    ContentFrame.Size = UDim2.new(1, -20, 1, -80)
    ContentFrame.Position = UDim2.new(0, 10, 0, 75)
    ContentFrame.BackgroundTransparency = 1
 
    local TabFrames, TabButtons, ActiveTab = {}, {}, nil
 
    local function SwitchTab(name)
        ActiveTab = name
        for n, frame in pairs(TabFrames) do frame.Visible = (n == name) end
        for n, btn in pairs(TabButtons) do
            btn.BackgroundColor3 = (n == name) and Color3.fromRGB(35, 105, 190) or Color3.fromRGB(22, 38, 60)
            btn.TextColor3 = (n == name) and Color3.fromRGB(170, 215, 255) or Color3.fromRGB(145, 190, 230)
        end
    end
 
    local W = {}
    function W:Tab(name)
        local btn = Instance.new("TextButton", TabBar)
        btn.Text = name
        btn.Size = UDim2.new(0, 80, 1, 0)
        btn.BackgroundColor3 = Color3.fromRGB(22, 38, 60)
        btn.TextColor3 = Color3.fromRGB(145, 190, 230)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.AutoButtonColor = false
        btn.LayoutOrder = GetOrder()
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
 
        local scroll = Instance.new("ScrollingFrame", ContentFrame)
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.BackgroundTransparency = 1
        scroll.ScrollBarThickness = 4
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.Visible = false
        scroll.ScrollingDirection = Enum.ScrollingDirection.Y
        local layout = Instance.new("UIListLayout", scroll)
        layout.Padding = UDim.new(0, 5)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
 
        TabFrames[name] = scroll
        TabButtons[name] = btn
        btn.MouseButton1Click:Connect(function() SwitchTab(name) end)
        if not ActiveTab then SwitchTab(name) end
        return scroll
    end
    return W
end
 
function Library:Section(parent, text)
    local l = Instance.new("TextLabel", parent)
    l.Text = " ─── " .. text .. " ───"
    l.Size = UDim2.new(1, 0, 0, 25)
    l.BackgroundTransparency = 1
    l.TextColor3 = Color3.fromRGB(90, 150, 210)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.LayoutOrder = GetOrder()
end
 
function Library:Toggle(parent, text, default, callback)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1, -6, 0, 34)
    btn.BackgroundColor3 = Color3.fromRGB(18, 30, 48)
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.LayoutOrder = GetOrder()
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local lab = Instance.new("TextLabel", btn)
    lab.Text = text
    lab.Size = UDim2.new(0.75, 0, 1, 0)
    lab.Position = UDim2.new(0, 10, 0, 0)
    lab.BackgroundTransparency = 1
    lab.TextColor3 = Color3.fromRGB(210, 210, 220)
    lab.Font = Enum.Font.GothamMedium
    lab.TextSize = 13
    lab.TextXAlignment = Enum.TextXAlignment.Left
    local ind = Instance.new("Frame", btn)
    ind.Size = UDim2.fromOffset(10, 10)
    ind.Position = UDim2.new(1, -22, 0.5, -5)
    ind.BackgroundColor3 = default and Color3.fromRGB(65, 170, 255) or Color3.fromRGB(55, 55, 65)
    Instance.new("UICorner", ind).CornerRadius = UDim.new(1, 0)
    local on = default
    btn.MouseButton1Click:Connect(function()
        on = not on
        ind.BackgroundColor3 = on and Color3.fromRGB(65, 170, 255) or Color3.fromRGB(55, 55, 65)
        callback(on)
    end)
    return {
        SetValue = function(_, v)
            on = v
            ind.BackgroundColor3 = v and Color3.fromRGB(65, 170, 255) or Color3.fromRGB(55, 55, 65)
            callback(v)
        end,
    }
end
 
function Library:Slider(parent, text, min, max, default, step, callback)
    step = step or 1
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, -6, 0, 46)
    f.BackgroundColor3 = Color3.fromRGB(18, 30, 48)
    f.LayoutOrder = GetOrder()
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local lab = Instance.new("TextLabel", f)
    lab.Text = text
    lab.Size = UDim2.new(1, 0, 0, 22)
    lab.Position = UDim2.new(0, 10, 0, 2)
    lab.BackgroundTransparency = 1
    lab.TextColor3 = Color3.fromRGB(210, 210, 220)
    lab.Font = Enum.Font.GothamMedium
    lab.TextSize = 13
    lab.TextXAlignment = Enum.TextXAlignment.Left
    local val = Instance.new("TextLabel", f)
    val.Text = tostring(default)
    val.Size = UDim2.new(0, 50, 0, 22)
    val.Position = UDim2.new(1, -58, 0, 2)
    val.BackgroundTransparency = 1
    val.TextColor3 = Color3.fromRGB(70, 170, 255)
    val.Font = Enum.Font.GothamBold
    val.TextSize = 13
    local sbar = Instance.new("TextButton", f)
    sbar.Text = ""
    sbar.Size = UDim2.new(1, -20, 0, 5)
    sbar.Position = UDim2.new(0, 10, 0, 32)
    sbar.BackgroundColor3 = Color3.fromRGB(25, 45, 70)
    sbar.AutoButtonColor = false
    Instance.new("UICorner", sbar).CornerRadius = UDim.new(1, 0)
    local fill = Instance.new("Frame", sbar)
    fill.Size = UDim2.new(math.clamp((default - min) / (max - min), 0, 1), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(35, 105, 200)
    fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
 
    local function upd(x)
        local p = math.clamp((x - sbar.AbsolutePosition.X) / sbar.AbsoluteSize.X, 0, 1)
        local raw = min + (max - min) * p
        local v = math.floor(raw / step + 0.5) * step
        v = math.clamp(v, min, max)
        if step < 1 then v = math.floor(v * 1000 + 0.5) / 1000 end
        fill.Size = UDim2.new(math.clamp((v - min) / (max - min), 0, 1), 0, 1, 0)
        val.Text = tostring(v)
        callback(v)
    end
 
    sbar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            ActiveSlider = upd
            upd(i.Position.X)
        end
    end)
end
 
function Library:Bind(parent, text, default, callback)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, -6, 0, 34)
    f.BackgroundColor3 = Color3.fromRGB(18, 30, 48)
    f.LayoutOrder = GetOrder()
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local lab = Instance.new("TextLabel", f)
    lab.Text = text
    lab.Size = UDim2.new(0.6, 0, 1, 0)
    lab.Position = UDim2.new(0, 10, 0, 0)
    lab.BackgroundTransparency = 1
    lab.TextColor3 = Color3.fromRGB(210, 210, 220)
    lab.Font = Enum.Font.GothamMedium
    lab.TextSize = 13
    lab.TextXAlignment = Enum.TextXAlignment.Left
    local btn = Instance.new("TextButton", f)
    btn.Size = UDim2.new(0, 85, 0, 22)
    btn.Position = UDim2.new(1, -95, 0.5, -11)
    btn.BackgroundColor3 = Color3.fromRGB(25, 45, 70)
    btn.Text = BindName(default)
    btn.TextColor3 = Color3.fromRGB(145, 190, 230)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    local listening = false
    btn.MouseButton1Click:Connect(function() listening = true; btn.Text = "..." end)
    TrackConnection(UserInputService.InputBegan:Connect(function(i)
        if not listening then return end
        if i.UserInputType == Enum.UserInputType.Keyboard then
            listening = false; btn.Text = BindName(i.KeyCode); callback(i.KeyCode)
        elseif i.UserInputType.Name:match("Mouse") then
            listening = false; btn.Text = BindName(i.UserInputType); callback(i.UserInputType)
        end
    end))
end
 
function Library:Dropdown(parent, text, options, default, callback)
    local idx = table.find(options, default) or 1
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1, -6, 0, 34)
    btn.BackgroundColor3 = Color3.fromRGB(18, 30, 48)
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.LayoutOrder = GetOrder()
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local lab = Instance.new("TextLabel", btn)
    lab.Text = text .. ": " .. options[idx]
    lab.Size = UDim2.new(1, -15, 1, 0)
    lab.Position = UDim2.new(0, 10, 0, 0)
    lab.BackgroundTransparency = 1
    lab.TextColor3 = Color3.fromRGB(210, 210, 220)
    lab.Font = Enum.Font.GothamMedium
    lab.TextSize = 13
    lab.TextXAlignment = Enum.TextXAlignment.Left
    btn.MouseButton1Click:Connect(function()
        idx = idx + 1
        if idx > #options then idx = 1 end
        lab.Text = text .. ": " .. options[idx]
        callback(options[idx])
    end)
end
 
function Library:Button(parent, text, color, callback)
    local btn = Instance.new("TextButton", parent)
    btn.Text = text
    btn.Size = UDim2.new(1, -6, 0, 34)
    btn.BackgroundColor3 = color or Color3.fromRGB(50, 50, 70)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.LayoutOrder = GetOrder()
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(callback)
end
 
-- ╔══════════════════════════════════════════╗
-- ║       [11]  BUILD MENU                  ║
-- ╚══════════════════════════════════════════╝
local Win = Library:Window()
 
local RageTab = Win:Tab("Hitboxes")
Library:Section(RageTab, "Hitbox Expander")
Library:Toggle(RageTab, "Enable Hitbox Expander", Config.Rage.HitboxExpander, function(v)
    Config.Rage.HitboxExpander = v
    if not v then
        for p, s in pairs(OriginalSizes) do
            pcall(function()
                if p.Character and p.Character:FindFirstChild("Head") then
                    p.Character.Head.Size = s
                    p.Character.Head.Transparency = 0
                    p.Character.Head.CanCollide = true
                    if OriginalColors[p] and OriginalColors[p].Head then
                        p.Character.Head.Color = OriginalColors[p].Head
                    end
                end
            end)
        end
        OriginalSizes = {}
        OriginalColors = {}
    end
    Notify(v and "Hitbox Expander ON" or "Hitbox Expander OFF", 2)
end)
Library:Toggle(RageTab, "Full Body Hitbox", Config.Rage.FullBodyHitbox, function(v)
    Config.Rage.FullBodyHitbox = v
    if not v then
        for p, _ in pairs(OriginalSizes) do
            pcall(function()
                if p.Character then
                    for _, part in ipairs(p.Character:GetChildren()) do
                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                            if OriginalSizes[p] and OriginalSizes[p][part.Name] then
                                part.Size = OriginalSizes[p][part.Name]
                            end
                            part.Transparency = 0
                            part.CanCollide = true
                            if OriginalColors[p] and OriginalColors[p][part.Name] then
                                part.Color = OriginalColors[p][part.Name]
                            end
                        end
                    end
                end
            end)
        end
        OriginalSizes = {}
        OriginalColors = {}
    end
    Notify(v and "Full Body Hitbox ON" or "Full Body Hitbox OFF", 2)
end)
Library:Slider(RageTab, "Head Size", 1, 15, Config.Rage.HeadSize, 0.5, function(v) Config.Rage.HeadSize = v end)
Library:Slider(RageTab, "Body Size", 1, 10, Config.Rage.BodySize, 0.5, function(v) Config.Rage.BodySize = v end)
Library:Slider(RageTab, "Hitbox Transparency", 0, 1, Config.Rage.Transparency, 0.05, function(v) Config.Rage.Transparency = v end)
 
local VisTab = Win:Tab("Visuals")
Library:Section(VisTab, "Hitbox Color")
local HitboxColorOptions = {
    ["Белый (Default)"] = Color3.fromRGB(255, 255, 255),
    ["Синий"] = Color3.fromRGB(65, 170, 255),
    ["Красный"] = Color3.fromRGB(255, 65, 65),
    ["Жёлтый"] = Color3.fromRGB(255, 220, 55),
    ["Зелёный"] = Color3.fromRGB(65, 220, 100),
}
local HitboxColorNames = {"Белый (Default)", "Синий", "Красный", "Жёлтый", "Зелёный"}
local currentHitboxColor = "Белый (Default)"
for name, color in pairs(HitboxColorOptions) do
    if color == Config.Rage.HitboxColor then currentHitboxColor = name; break end
end
Library:Dropdown(VisTab, "Hitbox Color", HitboxColorNames, currentHitboxColor, function(name)
    Config.Rage.HitboxColor = HitboxColorOptions[name]
end)
Library:Button(VisTab, "В разработке", Color3.fromRGB(35, 65, 95), function() end)

local MiscTab = Win:Tab("Misc")
Library:Section(MiscTab, "Utility")
Library:Toggle(MiscTab, "Anti-AFK", Config.Misc.AntiAFK, function(v)
    Config.Misc.AntiAFK = v
    Notify(v and "Anti-AFK ON" or "Anti-AFK OFF", 2)
end)
Library:Toggle(MiscTab, "Anti-Kick", Config.Misc.AntiKick, function(v)
    Config.Misc.AntiKick = v
    if v then
        pcall(function()
            if hookmetamethod and not OldHook then
                OldHook = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
                    if getnamecallmethod() == "Kick" and self == LocalPlayer then return end
                    return OldHook(self, ...)
                end))
            end
        end)
    else
        if OldHook then
            pcall(function() hookmetamethod(game, "__namecall", OldHook) end)
            OldHook = nil
        end
    end
    Notify(v and "Anti-Kick ON" or "Anti-Kick OFF", 2)
end)
Library:Toggle(MiscTab, "Watermark", Config.Misc.Watermark, function(v) Config.Misc.Watermark = v end)
Library:Toggle(MiscTab, "Time", Config.Misc.Time, function(v) Config.Misc.Time = v; TimeText.Visible = v end)
Library:Toggle(MiscTab, "Keybind Overlay", Config.Misc.KeybindOverlay, function(v) Config.Misc.KeybindOverlay = v end)
Library:Toggle(MiscTab, "Fullbright", Config.Misc.Fullbright, function(v)
    Config.Misc.Fullbright = v
    SetFullbright(v)
    Notify(v and "Fullbright ON" or "Fullbright OFF", 2)
end)
Library:Toggle(MiscTab, "Infinite Jump [DETECT]", Config.Misc.InfiniteJump, function(v)
    Config.Misc.InfiniteJump = v
    Notify(v and "Infinite Jump ON" or "Infinite Jump OFF", 2)
end)
Library:Toggle(MiscTab, "Speed Hack [DETECT]", Config.Misc.SpeedHack, function(v)
    Config.Misc.SpeedHack = v
    if v then
        local char = LocalPlayer.Character
        if char then
            local h = char:FindFirstChildOfClass("Humanoid")
            if h then State.OriginalWalkSpeed = h.WalkSpeed end
        end
    else
        local char = LocalPlayer.Character
        if char then
            local h = char:FindFirstChildOfClass("Humanoid")
            if h and State.OriginalWalkSpeed then h.WalkSpeed = State.OriginalWalkSpeed end
        end
    end
    Notify(v and "Speed Hack ON" or "Speed Hack OFF", 2)
end)
Library:Slider(MiscTab, "Speed Value", 16, 200, Config.Misc.SpeedValue, 1, function(v) Config.Misc.SpeedValue = v end)
Library:Toggle(MiscTab, "Noclip [UNDETECT]", Config.Misc.Noclip, function(v)
    Config.Misc.Noclip = v
    Notify(v and "Noclip ON" or "Noclip OFF", 2)
end)
 
Library:Section(MiscTab, "Config System")
Library:Button(MiscTab, "SAVE CONFIG", Color3.fromRGB(40, 80, 40), function()
    SaveConfig()
    Notify("Config saved!", 2, Color3.fromRGB(30, 50, 30))
end)
Library:Button(MiscTab, "RESET CONFIG", Color3.fromRGB(120, 80, 20), function()
    pcall(function()
        if isfile and isfile(CONFIG_FILE) then delfile(CONFIG_FILE) end
    end)
    Notify("Config reset! Re-execute to apply defaults.", 4, Color3.fromRGB(60, 50, 20))
end)
 
Library:Section(MiscTab, "Settings")
Library:Bind(MiscTab, "Menu Key", Config.UI.OpenKey, function(v) Config.UI.OpenKey = v end)
Library:Button(MiscTab, "UNLOAD SCRIPT", Color3.fromRGB(160, 35, 35), function()
    if getgenv().VanishCleanup then getgenv().VanishCleanup() end
end)
 
-- ╔══════════════════════════════════════════╗
-- ║     [12]  CORE: HITBOX EXPANDER         ║
-- ╚══════════════════════════════════════════╝
local function GetBodyParts(char)
    local parts = {}
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            table.insert(parts, part)
        end
    end
    return parts
end
 
local function UpdateHitboxes()
    if not Config.Rage.HitboxExpander and not Config.Rage.FullBodyHitbox then return end
 
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and IsAlive(plr) and IsEnemyFor(plr, "ESP") then
            local char = plr.Character
            if not char then continue end
 
            if Config.Rage.FullBodyHitbox then
                if not OriginalSizes[plr] then OriginalSizes[plr] = {} end
                for _, part in ipairs(GetBodyParts(char)) do
                    if not OriginalSizes[plr][part.Name] then
                        OriginalSizes[plr][part.Name] = part.Size
                    end
                    if not OriginalColors[plr] then OriginalColors[plr] = {} end
                    if not OriginalColors[plr][part.Name] then
                        OriginalColors[plr][part.Name] = part.Color
                    end
                    part.Color = Config.Rage.HitboxColor or Color3.fromRGB(255, 255, 255)
                    local size = Config.Rage.BodySize
                    if part.Name == "Head" then size = Config.Rage.HeadSize end
                    part.Size = Vector3.new(size, size, size)
                    part.Transparency = Config.Rage.Transparency
                    part.CanCollide = false
                end
            elseif Config.Rage.HitboxExpander then
                local head = char.Head
                if not OriginalSizes[plr] then
                    OriginalSizes[plr] = head.Size
                end
                if not OriginalColors[plr] then OriginalColors[plr] = {} end
                if not OriginalColors[plr].Head then OriginalColors[plr].Head = head.Color end
                head.Color = Config.Rage.HitboxColor or Color3.fromRGB(255, 255, 255)
                local s = Config.Rage.HeadSize
                if head.Size.X ~= s then
                    head.Size = Vector3.new(s, s, s)
                    head.Transparency = Config.Rage.Transparency
                    head.CanCollide = false
                end
            end
        end
    end
end
 
-- ╔══════════════════════════════════════════╗
-- ║     [13]  CORE: RAPID FIRE              ║
-- ╚══════════════════════════════════════════╝
-- Более безопасная эмуляция клика через VirtualUser
local function SafeClick()
    pcall(function()
        local VirtualUser = game:GetService("VirtualUser")
        VirtualUser:CaptureController()
        -- Эмулируем клик в центре экрана (менее заметно)
        local center = Camera.ViewportSize / 2
        VirtualUser:ClickButton1(center, game)
    end)
end
 
-- Auto Clicker для Rapid Fire (более надёжный чем hook)
local function StartAutoClicker()
    if AutoClickerConnection then
        AutoClickerConnection:Disconnect()
        AutoClickerConnection = nil
    end
 
    if not Config.Combat.RapidFire then return end
 
    AutoClickerConnection = RunService.RenderStepped:Connect(function()
        if not Config.Combat.RapidFire then return end
 
        local char = LocalPlayer.Character
        if not char then return end
 
        local tool = char:FindFirstChildOfClass("Tool")
        if not tool then return end
 
        -- Проверяем, зажата ли левая кнопка мыши
        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            local now = tick()
            if now - LastShotTime >= Config.Combat.FireDelay then
                LastShotTime = now
                SafeClick()
            end
        end
    end)
end
 
local function StopAutoClicker()
    if AutoClickerConnection then
        AutoClickerConnection:Disconnect()
        AutoClickerConnection = nil
    end
end
 
local function ResetRapidFire()
    StopAutoClicker()
end
 
-- ╔══════════════════════════════════════════╗
-- ║     [15]  CORE: HIGHLIGHT ESP           ║
-- ╚══════════════════════════════════════════╝
local function UpdateHighlightESP()
    if not Config.Visuals.Enabled or not Config.Visuals.HighlightESP then
        for _, p in pairs(Players:GetPlayers()) do
            pcall(function()
                if p.Character and p.Character:FindFirstChild("VanishHL") then
                    p.Character.VanishHL:Destroy()
                end
            end)
        end
        return
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            if IsEnemyFor(plr, "ESP") and IsAlive(plr) and IsInRange(plr, Config.Visuals.MaxDistance) then
                local hl = plr.Character:FindFirstChild("VanishHL")
                if not hl then
                    hl = Instance.new("Highlight")
                    hl.Name = "VanishHL"
                    hl.Adornee = plr.Character
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent = plr.Character
                end
                hl.Enabled = true
                hl.OutlineTransparency = 1
                hl.FillTransparency = Config.Visuals.HighlightTransp
                hl.FillColor = CheckVisibility(plr.Character)
                    and Config.Visuals.ColorVisible or Config.Visuals.ColorHidden
            else
                pcall(function()
                    if plr.Character:FindFirstChild("VanishHL") then
                        plr.Character.VanishHL:Destroy()
                    end
                end)
            end
        end
    end
end
 
-- ╔══════════════════════════════════════════╗
-- ║     [16]  CORE: DRAWING ESP             ║
-- ╚══════════════════════════════════════════╝
local function UpdateDrawingESP()
    local viewport = Camera.ViewportSize
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local o = GetESP(plr)
            local char = plr.Character
            local show = Config.Visuals.Enabled and char and IsAlive(plr) and IsEnemyFor(plr, "ESP") and IsInRange(plr, Config.Visuals.MaxDistance)
 
            if not show then
                HideESPObjects(o)
            else
                local root = char:FindFirstChild("HumanoidRootPart")
                local head = char:FindFirstChild("Head")
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if not (root and head and humanoid) then
                    HideESPObjects(o)
                else
                    local _, rootVis = Camera:WorldToViewportPoint(root.Position)
                    if not rootVis then
                        HideESPObjects(o)
                    else
                        local vis = CheckVisibility(char)
                        local col = vis and Config.Visuals.ColorVisible or Config.Visuals.ColorHidden
 
                        local headTop = head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.5, 0)
                        local feet = root.Position - Vector3.new(0, 3, 0)
                        local tp = Camera:WorldToViewportPoint(headTop)
                        local bp = Camera:WorldToViewportPoint(feet)
                        local boxH = math.abs(bp.Y - tp.Y)
                        local boxW = boxH * 0.55
                        local cx = tp.X
 
                        if Config.Visuals.BoxESP then
                            local x1, y1 = cx - boxW / 2, tp.Y
                            local x2, y2 = cx + boxW / 2, bp.Y
                            o.BoxLines[1].From = Vector2.new(x1, y1); o.BoxLines[1].To = Vector2.new(x2, y1)
                            o.BoxLines[2].From = Vector2.new(x2, y1); o.BoxLines[2].To = Vector2.new(x2, y2)
                            o.BoxLines[3].From = Vector2.new(x2, y2); o.BoxLines[3].To = Vector2.new(x1, y2)
                            o.BoxLines[4].From = Vector2.new(x1, y2); o.BoxLines[4].To = Vector2.new(x1, y1)
                            for i = 1, 4 do o.BoxLines[i].Color = col; o.BoxLines[i].Visible = true end
                        else
                            for i = 1, 4 do o.BoxLines[i].Visible = false end
                        end
 
                        if Config.Visuals.NameESP then
                            o.Name.Text = plr.DisplayName
                            o.Name.Position = Vector2.new(cx, tp.Y - 16)
                            o.Name.Color = col; o.Name.Visible = true
                        else
                            o.Name.Visible = false
                        end
 
                        if Config.Visuals.DistanceESP then
                            local dist = math.floor((Camera.CFrame.Position - root.Position).Magnitude)
                            o.Distance.Text = dist .. "m"
                            o.Distance.Position = Vector2.new(cx, bp.Y + 3)
                            o.Distance.Color = col; o.Distance.Visible = true
                        else
                            o.Distance.Visible = false
                        end
 
                        if Config.Visuals.HealthBar then
                            local x = cx - boxW / 2 - 6
                            local hp = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                            o.HealthBg.From = Vector2.new(x, tp.Y)
                            o.HealthBg.To = Vector2.new(x, bp.Y)
                            o.HealthBg.Visible = true
                            local fillBot = bp.Y - (bp.Y - tp.Y) * hp
                            o.HealthFill.From = Vector2.new(x, bp.Y)
                            o.HealthFill.To = Vector2.new(x, fillBot)
                            o.HealthFill.Color = Color3.fromRGB(255 * (1 - hp), 255 * hp, 0)
                            o.HealthFill.Visible = true
                        else
                            o.HealthBg.Visible = false; o.HealthFill.Visible = false
                        end
 
                        if Config.Visuals.Tracers then
                            local origin
                            if Config.Visuals.TracerOrigin == "Bottom" then
                                origin = Vector2.new(viewport.X / 2, viewport.Y)
                            elseif Config.Visuals.TracerOrigin == "Center" then
                                origin = Vector2.new(viewport.X / 2, viewport.Y / 2)
                            else
                                origin = UserInputService:GetMouseLocation()
                            end
                            o.Tracer.From = origin
                            o.Tracer.To = Vector2.new(cx, bp.Y)
                            o.Tracer.Color = col; o.Tracer.Visible = true
                        else
                            o.Tracer.Visible = false
                        end
 
                        if Config.Visuals.Skeleton then
                            local bones = GetBoneConnections(char)
                            for i, conn in ipairs(bones) do
                                local line = o.SkeletonLines[i]
                                if line then
                                    local p1 = char:FindFirstChild(conn[1])
                                    local p2 = char:FindFirstChild(conn[2])
                                    if p1 and p2 then
                                        local s1, v1 = Camera:WorldToViewportPoint(p1.Position)
                                        local s2, v2 = Camera:WorldToViewportPoint(p2.Position)
                                        if v1 and v2 then
                                            line.From = Vector2.new(s1.X, s1.Y)
                                            line.To = Vector2.new(s2.X, s2.Y)
                                            line.Color = col; line.Visible = true
                                        else
                                            line.Visible = false
                                        end
                                    else
                                        line.Visible = false
                                    end
                                end
                            end
                            for i = #bones + 1, MAX_SKELETON do
                                if o.SkeletonLines[i] then o.SkeletonLines[i].Visible = false end
                            end
                        else
                            for i = 1, MAX_SKELETON do
                                if o.SkeletonLines[i] then o.SkeletonLines[i].Visible = false end
                            end
                        end
                    end
                end
            end
        end
    end
    for plr, _ in pairs(ESPCache) do
        if not plr.Parent then RemoveESP(plr) end
    end
end
 
-- ╔══════════════════════════════════════════╗
-- ║     [17]  CORE: CROSSHAIR              ║
-- ╚══��══════════���════════════════════════════╝
local function UpdateCrosshair()
    if not Config.Crosshair.Enabled then
        for i = 1, 4 do CrossLines[i].Visible = false end
        CrossDot.Visible = false
        return
    end
    local center = Camera.ViewportSize / 2
    local cx, cy = center.X, center.Y
    local sz = Config.Crosshair.Size
    local gap = Config.Crosshair.Gap
    local col = Config.Crosshair.Color
    local thick = Config.Crosshair.Thickness
 
    for i = 1, 4 do CrossLines[i].Thickness = thick; CrossLines[i].Color = col end
 
    CrossLines[1].From = Vector2.new(cx, cy - gap)
    CrossLines[1].To = Vector2.new(cx, cy - gap - sz); CrossLines[1].Visible = true
    CrossLines[2].From = Vector2.new(cx, cy + gap)
    CrossLines[2].To = Vector2.new(cx, cy + gap + sz); CrossLines[2].Visible = true
    CrossLines[3].From = Vector2.new(cx - gap, cy)
    CrossLines[3].To = Vector2.new(cx - gap - sz, cy); CrossLines[3].Visible = true
    CrossLines[4].From = Vector2.new(cx + gap, cy)
    CrossLines[4].To = Vector2.new(cx + gap + sz, cy); CrossLines[4].Visible = true
 
    CrossDot.Position = Vector2.new(cx, cy)
    CrossDot.Radius = Config.Crosshair.DotSize
    CrossDot.Color = col
    CrossDot.Visible = Config.Crosshair.Dot
end
 
-- ╔══════════════════════════════════════════╗
-- ║     [18]  CORE: WATERMARK               ║
-- ╚══════════════════════════════════════════╝
local function UpdateWatermark()
    if not Config.Misc.Watermark then
        WatermarkText.Visible = false
        return
    end
    State.FrameCount = State.FrameCount + 1
    local now = tick()
    if now - State.LastFPSUpdate >= 0.5 then
        State.CurrentFPS = math.floor(State.FrameCount / (now - State.LastFPSUpdate))
        State.FrameCount = 0
        State.LastFPSUpdate = now
    end
    local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
    WatermarkText.Text = string.format("Vanish v1.1 | FPS: %d | Ping: %dms",
        State.CurrentFPS, ping)
    WatermarkText.Visible = true
end

local function UpdateTime()
    if not Config.Misc.Time then
        TimeText.Visible = false
        return
    end
    TimeText.Text = os.date("%H:%M:%S")
    TimeText.Visible = true
end

-- ╔══════════════════════════════════════════╗
-- ║     [20]  CORE: KEYBIND OVERLAY         ║
-- ╚══════════════════════════════════════════╝
local function UpdateKeybindOverlay()
    if not Config.Misc.KeybindOverlay then
        for i = 1, 11 do OverlayLines[i].Visible = false end
        return
    end
 
    local baseX = 10
    local baseY = 32
    local step = 16
    local green = Color3.fromRGB(65, 170, 255)
    local gray = Color3.fromRGB(90, 90, 100)
    local accent = Color3.fromRGB(70, 160, 255)
    local dim = Color3.fromRGB(35, 105, 190)
 
    OverlayLines[1].Text = "VANISH v7.3"
    OverlayLines[1].Color = accent
    OverlayLines[1].Size = 14
    OverlayLines[1].Position = Vector2.new(baseX, baseY)
    OverlayLines[1].Visible = true
 
    OverlayLines[2].Text = "────────────────"
    OverlayLines[2].Color = dim
    OverlayLines[2].Size = 10
    OverlayLines[2].Position = Vector2.new(baseX, baseY + step)
    OverlayLines[2].Visible = true
 
    local modules = {
        {name = "ESP",        on = Config.Visuals.Enabled,       bind = Config.Visuals.ToggleBind},
        {name = "Hitbox",     on = Config.Rage.HitboxExpander,   bind = nil},
        {name = "Full Body",  on = Config.Rage.FullBodyHitbox,   bind = nil},
        {name = "Fullbright", on = Config.Misc.Fullbright,       bind = nil},
        {name = "Inf. Jump",  on = Config.Misc.InfiniteJump,    bind = nil},
        {name = "Speed",      on = Config.Misc.SpeedHack,       bind = nil},
        {name = "Noclip",     on = Config.Misc.Noclip,          bind = nil},
    }
 
    for i, mod in ipairs(modules) do
        local lineIdx = i + 2
        local symbol = mod.on and "●" or "○"
        local bindStr = ""
        if mod.bind then
            bindStr = "  [" .. BindName(mod.bind) .. "]"
        end
        OverlayLines[lineIdx].Text = symbol .. " " .. mod.name .. bindStr
        OverlayLines[lineIdx].Color = mod.on and green or gray
        OverlayLines[lineIdx].Size = 13
        OverlayLines[lineIdx].Position = Vector2.new(baseX, baseY + step * i + step)
        OverlayLines[lineIdx].Visible = true
    end
    -- Hide any leftover rows from a previous update.
    for lineIdx = #modules + 3, 11 do
        OverlayLines[lineIdx].Visible = false
    end
end
 
-- ╔══════════════════════════════════════════╗
-- ║     [21]  CORE: FULLBRIGHT              ║
-- ╚══════════════════════════════════════════╝
SetFullbright = function(enabled)
    if enabled then
        OriginalLight.Ambient = Lighting.Ambient
        OriginalLight.Brightness = Lighting.Brightness
        OriginalLight.FogEnd = Lighting.FogEnd
        OriginalLight.FogStart = Lighting.FogStart
        OriginalLight.GlobalShadows = Lighting.GlobalShadows
        OriginalLight.OutdoorAmbient = Lighting.OutdoorAmbient
 
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.Brightness = 2
        Lighting.FogEnd = 1e9
        Lighting.FogStart = 1e9
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
 
        for _, v in ipairs(Lighting:GetDescendants()) do
            if v:IsA("Atmosphere") or v:IsA("BloomEffect") or v:IsA("BlurEffect")
               or v:IsA("ColorCorrectionEffect") or v:IsA("SunRaysEffect")
               or v:IsA("DepthOfFieldEffect") then
                if not v:GetAttribute("_NebHid") then
                    v:SetAttribute("_NebHid", true)
                    v:SetAttribute("_NebOrig", v.Enabled)
                    v.Enabled = false
                end
            end
        end
    else
        if OriginalLight.Ambient then
            Lighting.Ambient = OriginalLight.Ambient
            Lighting.Brightness = OriginalLight.Brightness
            Lighting.FogEnd = OriginalLight.FogEnd
            Lighting.FogStart = OriginalLight.FogStart
            Lighting.GlobalShadows = OriginalLight.GlobalShadows
            Lighting.OutdoorAmbient = OriginalLight.OutdoorAmbient
        end
        for _, v in ipairs(Lighting:GetDescendants()) do
            if v:GetAttribute("_NebHid") then
                v.Enabled = v:GetAttribute("_NebOrig") ~= false
                v:SetAttribute("_NebHid", nil)
                v:SetAttribute("_NebOrig", nil)
            end
        end
    end
end
 
if Config.Misc.Fullbright then SetFullbright(true) end
 
-- ╔══════════════════════════════════════════╗
-- ║     [22]  ANTI-AFK                      ║
-- ╚══════════════════════════════════════════╝
TrackConnection(LocalPlayer.Idled:Connect(function()
    if Config.Misc.AntiAFK then
        pcall(function()
            local VU = game:GetService("VirtualUser")
            VU:CaptureController()
            VU:ClickButton2(Vector2.new())
        end)
    end
end))
 
-- ╔══════════════════════════════════════════╗
-- ║   [23]  CHARACTER HANDLING (RESPAWN)     ║
-- ╚══════════════════════════════════════════╝
local function OnCharacterAdded(plr, char)
    if plr == LocalPlayer then return end
    task.delay(1, function()
        if not State.Running then return end
        if Config.Rage.FullBodyHitbox and IsAlive(plr) then
            if not OriginalSizes[plr] then OriginalSizes[plr] = {} end
            for _, part in ipairs(GetBodyParts(char)) do
                if not OriginalSizes[plr][part.Name] then
                    OriginalSizes[plr][part.Name] = part.Size
                end
                if not OriginalColors[plr] then OriginalColors[plr] = {} end
                if not OriginalColors[plr][part.Name] then
                    OriginalColors[plr][part.Name] = part.Color
                end
                part.Color = Config.Rage.HitboxColor or Color3.fromRGB(255, 255, 255)
                local size = Config.Rage.BodySize
                if part.Name == "Head" then size = Config.Rage.HeadSize end
                part.Size = Vector3.new(size, size, size)
                part.Transparency = Config.Rage.Transparency
                part.CanCollide = false
            end
        elseif Config.Rage.HitboxExpander and IsAlive(plr) then
            local head = plr.Character and plr.Character:FindFirstChild("Head")
            if head then
                OriginalSizes[plr] = head.Size
                if not OriginalColors[plr] then OriginalColors[plr] = {} end
                if not OriginalColors[plr].Head then OriginalColors[plr].Head = head.Color end
                head.Color = Config.Rage.HitboxColor or Color3.fromRGB(255, 255, 255)
                head.Size = Vector3.new(Config.Rage.HeadSize, Config.Rage.HeadSize, Config.Rage.HeadSize)
                head.Transparency = Config.Rage.Transparency
                head.CanCollide = false
            end
        end
        if Config.Visuals.Enabled and Config.Visuals.HighlightESP and IsAlive(plr)
           and IsEnemyFor(plr, "ESP") then
            pcall(function()
                if plr.Character:FindFirstChild("VanishHL") then
                    plr.Character.VanishHL:Destroy()
                end
                local hl = Instance.new("Highlight")
                hl.Name = "VanishHL"
                hl.Adornee = plr.Character
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = plr.Character
            end)
        end
    end)
end
 
local function SetupPlayer(plr)
    if plr == LocalPlayer then return end
    if plr.Character then OnCharacterAdded(plr, plr.Character) end
    TrackConnection(plr.CharacterAdded:Connect(function(char)
        OnCharacterAdded(plr, char)
    end))
end
 
for _, plr in ipairs(Players:GetPlayers()) do SetupPlayer(plr) end
TrackConnection(Players.PlayerAdded:Connect(SetupPlayer))
 
TrackConnection(Players.PlayerRemoving:Connect(function(plr)
    RemoveESP(plr)
    OriginalSizes[plr] = nil
end))
 
-- Очищаем Rapid Fire при смене персонажа
LocalPlayer.CharacterAdded:Connect(function()
    ResetRapidFire()
end)
 
-- ╔══════════════════════════════════════════╗
-- ║     [24]  MAIN LOOPS                    ║
-- ╚══════════════════════════════════════════╝
TrackConnection(RunService.RenderStepped:Connect(function()
    if not State.Running then return end
    Camera = Workspace.CurrentCamera
 
    pcall(UpdateHitboxes)
    pcall(UpdateDrawingESP)
    pcall(UpdateCrosshair)
    pcall(UpdateWatermark)
    pcall(UpdateTime)
    pcall(UpdateKeybindOverlay)
 
    -- Speed Hack
    if Config.Misc.SpeedHack then
        local char = LocalPlayer.Character
        if char then
            local h = char:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed = Config.Misc.SpeedValue end
        end
    end
 
    -- Noclip
    if Config.Misc.Noclip then
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end
end))
 
task.spawn(function()
    while State.Running do
        pcall(UpdateHighlightESP)
        task.wait(0.1)
    end
end)
 
-- ╔══════════════════════════════════════════╗
-- ║     [25]  INPUT HANDLING                ║
-- ╚══════════════════════════════════════════╝
TrackConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if Config.Misc.InfiniteJump and input.KeyCode == Enum.KeyCode.Space then
        local char = LocalPlayer.Character
        if char then
            local h = char:FindFirstChildOfClass("Humanoid")
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end
 
    if gameProcessed then return end
 
    if input.KeyCode == Config.UI.OpenKey then
        State.MenuOpen = not State.MenuOpen
        ScreenGui.Enabled = State.MenuOpen
    end
 
    if DoesInputMatch(input, Config.Visuals.ToggleBind) then
        Config.Visuals.Enabled = not Config.Visuals.Enabled
        if not Config.Visuals.Enabled then
            for _, p in pairs(Players:GetPlayers()) do
                pcall(function()
                    if p.Character and p.Character:FindFirstChild("VanishHL") then
                        p.Character.VanishHL:Destroy()
                    end
                end)
                HideESPObjects(ESPCache[p])
            end
        end
        Notify(Config.Visuals.Enabled and "ESP ON" or "ESP OFF", 2)
    end
end))
 
 
-- ╔══════════════════════════════════════════╗
-- ║     [26]  CLEANUP FUNCTION              ║
-- ╚══════════════════════════════════════════╝
getgenv().VanishCleanup = function()
    State.Running = false
 
    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    Connections = {}
 
 
    pcall(function() ScreenGui:Destroy() end)
 
    pcall(function() WatermarkText:Remove() end)
    pcall(function() TimeText:Remove() end)
    pcall(function() CrossDot:Remove() end)
    for i = 1, 4 do pcall(function() CrossLines[i]:Remove() end) end
    for i = 1, 11 do pcall(function() OverlayLines[i]:Remove() end) end
 
    for plr, _ in pairs(ESPCache) do RemoveESP(plr) end
 
    for plr, sizes in pairs(OriginalSizes) do
        pcall(function()
            if plr.Character then
                if type(sizes) == "table" then
                    for name, size in pairs(sizes) do
                        local part = plr.Character:FindFirstChild(name)
                        if part and part:IsA("BasePart") then
                            part.Size = size
                            part.Transparency = 0
                            part.CanCollide = true
                        end
                    end
                elseif plr.Character:FindFirstChild("Head") then
                    plr.Character.Head.Size = sizes
                    plr.Character.Head.Transparency = 0
                    plr.Character.Head.CanCollide = true
                end
            end
        end)
    end
    for plr, colors in pairs(OriginalColors) do
        pcall(function()
            if plr.Character then
                for name, color in pairs(colors) do
                    local part = plr.Character:FindFirstChild(name)
                    if part and part:IsA("BasePart") then part.Color = color end
                end
            end
        end)
    end
    OriginalSizes = {}
    OriginalColors = {}
 
    for _, p in ipairs(Players:GetPlayers()) do
        pcall(function()
            if p.Character and p.Character:FindFirstChild("VanishHL") then
                p.Character.VanishHL:Destroy()
            end
        end)
    end
 
    if Config.Misc.Fullbright then SetFullbright(false) end
 
    if State.OriginalWalkSpeed then
        local char = LocalPlayer.Character
        if char then
            local h = char:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed = State.OriginalWalkSpeed end
        end
    end
 
    if OldHook then
        pcall(function() hookmetamethod(game, "__namecall", OldHook) end)
        OldHook = nil
    end
 
    -- Сброс Rapid Fire
    ResetRapidFire()
 
    getgenv().VanishCleanup = nil
end
 
-- ╔══════════════════════════════════════════╗
-- ║     [27]  STARTUP                        ║
-- ╚══════════════════════════════════════════╝
Notify("Vanish v1.1 loaded", 4, Color3.fromRGB(25, 30, 45))
if configLoaded then
    Notify("Config loaded from file", 3, Color3.fromRGB(30, 50, 30))
end
Notify("Press [" .. BindName(Config.UI.OpenKey) .. "] to toggle menu", 4)