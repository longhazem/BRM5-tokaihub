--[[
    BRM5 Movement Menu - Standalone
    Fly + WalkSpeed + Sprint Speed + Infinite Stamina
    Tách riêng, không cần UI library
    Phím T = toggle Fly | Phím RightShift = ẩn/hiện menu
--]]

-- ─── Cleanup instance cũ ──────────────────────────────────────────────────────
if getgenv().BRM5_Move_Cleanup then
    pcall(getgenv().BRM5_Move_Cleanup)
end

local _conns = {}
local function addConn(c) table.insert(_conns, c) end

getgenv().BRM5_Move_Cleanup = function()
    for _, c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
    table.clear(_conns)
    if getgenv().BRM5_MoveGui then
        pcall(function() getgenv().BRM5_MoveGui:Destroy() end)
        getgenv().BRM5_MoveGui = nil
    end
    if getgenv().OldMoveCharUpdate then
        -- restore hook jika ada
        getgenv().OldMoveCharUpdate = nil
    end
    getgenv().BRM5_Move_Settings = nil
end

-- ─── Services ─────────────────────────────────────────────────────────────────
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService   = game:GetService("TweenService")
local lp             = Players.LocalPlayer

-- ─── Settings ─────────────────────────────────────────────────────────────────
local S = {
    FlyEnabled    = false,
    FlySpeed      = 50,
    WalkMult      = 1,
    SprintMult    = 1,
    InfStamina    = false,
}
getgenv().BRM5_Move_Settings = S

-- ─── Helpers ──────────────────────────────────────────────────────────────────
local Vector3_new = Vector3.new
local CFrame_new  = CFrame.new
local camera      = workspace.CurrentCamera

addConn(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    camera = workspace.CurrentCamera
end))

local _getgc_cache = { t = 0, v = nil }
local function cached_getgc()
    local now = tick()
    if _getgc_cache.v and (now - _getgc_cache.t) < 5 then return _getgc_cache.v end
    local ok, res = pcall(getgc, true)
    res = ok and res or {}
    _getgc_cache.v = res
    _getgc_cache.t = now
    return res
end

local function findModule(name)
    local rf = game:GetService("ReplicatedFirst")
    local RS = game:GetService("ReplicatedStorage")
    local function search(parent)
        if not parent then return end
        for _, child in ipairs(parent:GetChildren()) do
            if (child.Name:find(name, 1, true) or child.Name:lower():find(name:lower(), 1, true))
                and child:IsA("ModuleScript") then
                return child
            end
            local found = search(child)
            if found then return found end
        end
    end
    return search(rf) or search(RS)
end

local function getActor(self)
    return self._localActor or self._actor or self._character or self._charActor
end
local function getPos(self)
    return self._position or self._pos or self._charPosition
end
local function setPos(self, p)
    if self._position       ~= nil then self._position       = p end
    if self._pos            ~= nil then self._pos            = p end
    if self._charPosition   ~= nil then self._charPosition   = p end
    if self._lastSafePosition ~= nil then self._lastSafePosition = p end
    if self._safePosition   ~= nil then self._safePosition   = p end
end
local function getWM(self)
    return self._weightMulti or self._speedMulti or self._moveMulti or self._speedFactor or 1
end
local function setWM(self, v)
    if self._weightMulti ~= nil then self._weightMulti = v end
    if self._speedMulti  ~= nil then self._speedMulti  = v end
    if self._moveMulti   ~= nil then self._moveMulti   = v end
    if self._speedFactor ~= nil then self._speedFactor = v end
end

-- ─── Hook CharacterController ─────────────────────────────────────────────────
task.spawn(function()
    local function tryFind()
        local names = {"CharacterController","CharController","Movement","CharMovement","PlayerMovement","LocomotionController"}
        for _, name in ipairs(names) do
            local mod = findModule(name)
            if mod then
                local ok, res = pcall(require, mod)
                if ok and res and (res.Update or res.update) then return res end
            end
        end
        -- GC fallback
        for _, v in pairs(cached_getgc()) do
            if type(v) == "table" then
                local hasUpdate = type(rawget(v,"Update")) == "function"
                local hasActor  = rawget(v,"_localActor") ~= nil or rawget(v,"_actor") ~= nil
                local hasPos    = rawget(v,"_position")   ~= nil or rawget(v,"_pos")   ~= nil
                if hasUpdate and hasActor and hasPos then return v end
            end
        end
    end

    local CC = nil
    while not CC do
        task.wait(2)
        CC = tryFind()
    end

    -- Lưu original
    if not getgenv().OldMoveCharUpdate then
        getgenv().OldMoveCharUpdate = CC.Update or CC.update
    end

    local function newUpdate(self, inputVector, deltaTime)
        local actor = getActor(self)
        if not self or not actor then
            return getgenv().OldMoveCharUpdate(self, inputVector, deltaTime)
        end

        -- Infinite Stamina
        if S.InfStamina then
            if self._exhaustStart ~= nil then self._exhaustStart = tick() end
            if self._exhausted    ~= nil then self._exhausted    = tick() + 1 end
            if self._stamina      ~= nil then self._stamina      = self._maxStamina or self._stamina end
        end

        -- Speed Multipliers
        local baseWM = getWM(self)
        local isSprinting = self.IsSprinting or self._sprinting or self._isSprinting or false
        local activeMult  = isSprinting and S.SprintMult or S.WalkMult
        setWM(self, baseWM * activeMult)
        if self._walkSpeed ~= nil then
            if self._baseWalkSpeed == nil then self._baseWalkSpeed = self._walkSpeed end
            self._walkSpeed = self._baseWalkSpeed * S.WalkMult
        end
        if self._runSpeed ~= nil then
            if self._baseRunSpeed == nil then self._baseRunSpeed = self._runSpeed end
            self._runSpeed = self._baseRunSpeed * S.SprintMult
        end

        -- Fly
        if S.FlyEnabled then
            if self.VelocityGravity ~= nil then self.VelocityGravity = 0 end
            if self.Gravity         ~= nil then self.Gravity         = 0 end
            if self._gravity        ~= nil then self._gravity        = 0 end
            if self.HeightState     ~= nil then self.HeightState     = 0 end
            if self.IsGrounded      ~= nil then self.IsGrounded      = true end
            if self._grounded       ~= nil then self._grounded       = true end

            local camCF = camera.CFrame
            local dir   = Vector3_new(0,0,0)
            if inputVector.Magnitude > 0 then
                dir = dir + (camCF.LookVector * -inputVector.Y) + (camCF.RightVector * inputVector.X)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space)       then dir = dir + Vector3_new(0,1,0)  end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)  then dir = dir - Vector3_new(0,1,0)  end

            local curPos = getPos(self)
            if curPos and dir.Magnitude > 0 then
                local spd   = tonumber(S.FlySpeed) or 50
                local boost = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 2.5 or 1
                local nPos  = curPos + (dir.Unit * spd * boost * deltaTime)
                setPos(self, nPos)
                if actor.SimulatedPosition ~= nil then actor.SimulatedPosition = nPos end
                if actor.Position          ~= nil then actor.Position          = nPos end
                if actor.Grounded          ~= nil then actor.Grounded          = true end
                if actor.Sprinting         ~= nil then actor.Sprinting         = false end
            end

            -- CFrame character
            local char = (actor and (actor.Character or actor._model or actor._char))
                      or (lp and lp.Character)
            if char and getPos(self) then
                local root = char:FindFirstChild("HumanoidRootPart")
                          or char:FindFirstChild("Root")
                          or char.PrimaryPart
                if root then
                    pcall(function()
                        root.AssemblyLinearVelocity = Vector3_new(0,0,0)
                        root.CFrame = CFrame_new(getPos(self), getPos(self) + camCF.LookVector)
                    end)
                end
            end

            setWM(self, baseWM)
            return
        end

        local res = getgenv().OldMoveCharUpdate(self, inputVector, deltaTime)
        setWM(self, baseWM)
        if self._walkSpeed ~= nil and self._baseWalkSpeed then self._walkSpeed = self._baseWalkSpeed end
        if self._runSpeed  ~= nil and self._baseRunSpeed  then self._runSpeed  = self._baseRunSpeed  end
        return res
    end

    if CC.Update then CC.Update = newUpdate end
    if CC.update then CC.update = newUpdate end

    -- Exhaust hook
    if not getgenv().OldMoveCharExhaust then
        getgenv().OldMoveCharExhaust = CC._exhaust or CC.exhaust
    end
    if getgenv().OldMoveCharExhaust then
        local function newExhaust(self, ...)
            if S.InfStamina then return true end
            return getgenv().OldMoveCharExhaust(self, ...)
        end
        if CC._exhaust then CC._exhaust = newExhaust end
        if CC.exhaust  then CC.exhaust  = newExhaust end
    end

    print("[BRM5 Move] ✓ Hook thành công!")
end)

-- ─── GUI ─────────────────────────────────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name            = "BRM5_MoveMenu"
sg.ResetOnSpawn    = false
sg.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
sg.IgnoreGuiInset  = true
sg.Parent          = (gethui and gethui()) or lp:WaitForChild("PlayerGui")
getgenv().BRM5_MoveGui = sg

-- Màu sắc
local C = {
    BG      = Color3.fromRGB(15, 15, 20),
    Header  = Color3.fromRGB(22, 22, 30),
    Accent  = Color3.fromRGB(80, 140, 255),
    AccentD = Color3.fromRGB(50, 100, 210),
    Text    = Color3.fromRGB(220, 220, 230),
    SubText = Color3.fromRGB(130, 130, 150),
    ON      = Color3.fromRGB(60, 200, 100),
    OFF     = Color3.fromRGB(60, 60, 75),
    Row     = Color3.fromRGB(28, 28, 38),
    RowH    = Color3.fromRGB(35, 35, 50),
    Border  = Color3.fromRGB(50, 50, 70),
}

-- Frame chính
local main = Instance.new("Frame")
main.Size           = UDim2.new(0, 290, 0, 370)
main.Position       = UDim2.new(0.5, -145, 0.5, -185)
main.BackgroundColor3 = C.BG
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent         = sg

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke", main)
stroke.Color     = C.Border
stroke.Thickness = 1.2

-- Shadow
local shadow = Instance.new("ImageLabel")
shadow.Size             = UDim2.new(1, 30, 1, 30)
shadow.Position         = UDim2.new(0, -15, 0, -15)
shadow.BackgroundTransparency = 1
shadow.Image            = "rbxassetid://5028857084"
shadow.ImageColor3      = Color3.fromRGB(0,0,0)
shadow.ImageTransparency = 0.5
shadow.ZIndex           = 0
shadow.Parent           = main

-- Header
local header = Instance.new("Frame")
header.Size             = UDim2.new(1, 0, 0, 42)
header.BackgroundColor3 = C.Header
header.BorderSizePixel  = 0
header.Parent           = main

Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

-- Patch bottom corners of header
local hpatch = Instance.new("Frame")
hpatch.Size             = UDim2.new(1, 0, 0, 10)
hpatch.Position         = UDim2.new(0, 0, 1, -10)
hpatch.BackgroundColor3 = C.Header
hpatch.BorderSizePixel  = 0
hpatch.Parent           = header

-- Accent line
local accentLine = Instance.new("Frame")
accentLine.Size             = UDim2.new(0, 3, 0, 22)
accentLine.Position         = UDim2.new(0, 12, 0.5, -11)
accentLine.BackgroundColor3 = C.Accent
accentLine.BorderSizePixel  = 0
accentLine.Parent           = header
Instance.new("UICorner", accentLine).CornerRadius = UDim.new(1, 0)

local title = Instance.new("TextLabel")
title.Size               = UDim2.new(1, -80, 1, 0)
title.Position           = UDim2.new(0, 24, 0, 0)
title.BackgroundTransparency = 1
title.Text               = "BRM5 Movement"
title.Font               = Enum.Font.GothamBold
title.TextSize           = 14
title.TextColor3         = C.Text
title.TextXAlignment     = Enum.TextXAlignment.Left
title.Parent             = header

local subtitle = Instance.new("TextLabel")
subtitle.Size                = UDim2.new(1, -80, 0, 14)
subtitle.Position            = UDim2.new(0, 24, 1, -14)
subtitle.BackgroundTransparency = 1
subtitle.Text                = "Fly & Speed"
subtitle.Font                = Enum.Font.Gotham
subtitle.TextSize            = 11
subtitle.TextColor3          = C.SubText
subtitle.TextXAlignment      = Enum.TextXAlignment.Left
subtitle.Parent              = header

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size               = UDim2.new(0, 28, 0, 28)
closeBtn.Position           = UDim2.new(1, -36, 0.5, -14)
closeBtn.BackgroundColor3   = Color3.fromRGB(200, 60, 60)
closeBtn.Text               = "✕"
closeBtn.Font               = Enum.Font.GothamBold
closeBtn.TextSize           = 13
closeBtn.TextColor3         = Color3.fromRGB(255,255,255)
closeBtn.BorderSizePixel    = 0
closeBtn.Parent             = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

closeBtn.MouseButton1Click:Connect(function()
    TweenService:Create(main, TweenInfo.new(0.2), {Size = UDim2.new(0,290,0,0), Position = UDim2.new(0.5,-145,0.5,0)}):Play()
    task.wait(0.2)
    main.Visible = false
end)

-- Scroll content
local scroll = Instance.new("ScrollingFrame")
scroll.Size                   = UDim2.new(1, 0, 1, -42)
scroll.Position               = UDim2.new(0, 0, 0, 42)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel        = 0
scroll.ScrollBarThickness     = 3
scroll.ScrollBarImageColor3   = C.Accent
scroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
scroll.Parent                 = main

local listLayout = Instance.new("UIListLayout", scroll)
listLayout.Padding            = UDim.new(0, 0)
listLayout.SortOrder          = Enum.SortOrder.LayoutOrder

local padding = Instance.new("UIPadding", scroll)
padding.PaddingLeft   = UDim.new(0, 10)
padding.PaddingRight  = UDim.new(0, 10)
padding.PaddingTop    = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)

-- ─── Widget builders ──────────────────────────────────────────────────────────

local function SectionLabel(text)
    local lbl = Instance.new("TextLabel")
    lbl.Size                 = UDim2.new(1, 0, 0, 24)
    lbl.BackgroundTransparency = 1
    lbl.Text                 = text:upper()
    lbl.Font                 = Enum.Font.GothamBold
    lbl.TextSize             = 10
    lbl.TextColor3           = C.Accent
    lbl.TextXAlignment       = Enum.TextXAlignment.Left
    lbl.LayoutOrder          = 0
    lbl.Parent               = scroll
end

local function Toggle(label, hint, defaultVal, onChange)
    local state = defaultVal or false

    local row = Instance.new("Frame")
    row.Size                = UDim2.new(1, 0, 0, 48)
    row.BackgroundColor3    = C.Row
    row.BorderSizePixel     = 0
    row.Parent              = scroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size                = UDim2.new(1, -60, 0, 20)
    lbl.Position            = UDim2.new(0, 12, 0, 8)
    lbl.BackgroundTransparency = 1
    lbl.Text                = label
    lbl.Font                = Enum.Font.GothamSemibold
    lbl.TextSize            = 13
    lbl.TextColor3          = C.Text
    lbl.TextXAlignment      = Enum.TextXAlignment.Left
    lbl.Parent              = row

    if hint then
        local sub = Instance.new("TextLabel")
        sub.Size                = UDim2.new(1, -60, 0, 14)
        sub.Position            = UDim2.new(0, 12, 0, 28)
        sub.BackgroundTransparency = 1
        sub.Text                = hint
        sub.Font                = Enum.Font.Gotham
        sub.TextSize            = 10
        sub.TextColor3          = C.SubText
        sub.TextXAlignment      = Enum.TextXAlignment.Left
        sub.Parent              = row
    end

    -- Pill toggle
    local pill = Instance.new("Frame")
    pill.Size               = UDim2.new(0, 40, 0, 20)
    pill.Position           = UDim2.new(1, -52, 0.5, -10)
    pill.BackgroundColor3   = state and C.ON or C.OFF
    pill.BorderSizePixel    = 0
    pill.Parent             = row
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

    local dot = Instance.new("Frame")
    dot.Size                = UDim2.new(0, 14, 0, 14)
    dot.Position            = state and UDim2.new(0, 23, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
    dot.BackgroundColor3    = Color3.fromRGB(255,255,255)
    dot.BorderSizePixel     = 0
    dot.Parent              = pill
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local function setState(v)
        state = v
        TweenService:Create(pill, TweenInfo.new(0.15), {BackgroundColor3 = v and C.ON or C.OFF}):Play()
        TweenService:Create(dot,  TweenInfo.new(0.15), {Position = v and UDim2.new(0,23,0.5,-7) or UDim2.new(0,3,0.5,-7)}):Play()
        onChange(v)
    end

    local btn = Instance.new("TextButton")
    btn.Size                = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text                = ""
    btn.Parent              = row
    btn.MouseButton1Click:Connect(function() setState(not state) end)

    -- Hover
    btn.MouseEnter:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.1), {BackgroundColor3 = C.RowH}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.1), {BackgroundColor3 = C.Row}):Play()
    end)

    return setState  -- returns setter so external code can change it
end

local spacer = Instance.new("Frame")
spacer.Size               = UDim2.new(1, 0, 0, 4)
spacer.BackgroundTransparency = 1
spacer.LayoutOrder        = 0

local function Slider(label, hint, min, max, default, decimals, onChange)
    local val = default or min
    decimals  = decimals or 0

    local row = Instance.new("Frame")
    row.Size                = UDim2.new(1, 0, 0, 60)
    row.BackgroundColor3    = C.Row
    row.BorderSizePixel     = 0
    row.Parent              = scroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size                = UDim2.new(1, -70, 0, 18)
    lbl.Position            = UDim2.new(0, 12, 0, 7)
    lbl.BackgroundTransparency = 1
    lbl.Text                = label
    lbl.Font                = Enum.Font.GothamSemibold
    lbl.TextSize            = 13
    lbl.TextColor3          = C.Text
    lbl.TextXAlignment      = Enum.TextXAlignment.Left
    lbl.Parent              = row

    local valLbl = Instance.new("TextLabel")
    valLbl.Size             = UDim2.new(0, 55, 0, 18)
    valLbl.Position         = UDim2.new(1, -65, 0, 7)
    valLbl.BackgroundTransparency = 1
    valLbl.Text             = tostring(math.floor(val * 10^decimals) / 10^decimals)
    valLbl.Font             = Enum.Font.GothamBold
    valLbl.TextSize         = 13
    valLbl.TextColor3       = C.Accent
    valLbl.TextXAlignment   = Enum.TextXAlignment.Right
    valLbl.Parent           = row

    if hint then
        local sub = Instance.new("TextLabel")
        sub.Size                = UDim2.new(1, -12, 0, 13)
        sub.Position            = UDim2.new(0, 12, 0, 24)
        sub.BackgroundTransparency = 1
        sub.Text                = hint
        sub.Font                = Enum.Font.Gotham
        sub.TextSize            = 10
        sub.TextColor3          = C.SubText
        sub.TextXAlignment      = Enum.TextXAlignment.Left
        sub.Parent              = row
    end

    -- Track
    local track = Instance.new("Frame")
    track.Size              = UDim2.new(1, -24, 0, 5)
    track.Position          = UDim2.new(0, 12, 1, -16)
    track.BackgroundColor3  = C.OFF
    track.BorderSizePixel   = 0
    track.Parent            = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size               = UDim2.new((val - min)/(max - min), 0, 1, 0)
    fill.BackgroundColor3   = C.Accent
    fill.BorderSizePixel    = 0
    fill.Parent             = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local handle = Instance.new("Frame")
    handle.Size             = UDim2.new(0, 13, 0, 13)
    handle.AnchorPoint      = Vector2.new(0.5, 0.5)
    handle.Position         = UDim2.new((val - min)/(max - min), 0, 0.5, 0)
    handle.BackgroundColor3 = Color3.fromRGB(255,255,255)
    handle.BorderSizePixel  = 0
    handle.Parent           = track
    Instance.new("UICorner", handle).CornerRadius = UDim.new(1, 0)

    local dragging = false

    local function updateSlider(absX)
        local trackPos  = track.AbsolutePosition.X
        local trackSize = track.AbsoluteSize.X
        local ratio     = math.clamp((absX - trackPos) / trackSize, 0, 1)
        val = math.floor((min + ratio*(max-min)) * 10^decimals) / 10^decimals
        local r = (val - min)/(max - min)
        fill.Size           = UDim2.new(r, 0, 1, 0)
        handle.Position     = UDim2.new(r, 0, 0.5, 0)
        valLbl.Text         = tostring(val)
        onChange(val)
    end

    local sliderBtn = Instance.new("TextButton")
    sliderBtn.Size              = UDim2.new(1, 0, 1, 0)
    sliderBtn.BackgroundTransparency = 1
    sliderBtn.Text              = ""
    sliderBtn.Parent            = row

    sliderBtn.MouseButton1Down:Connect(function(x, y)
        dragging = true
        updateSlider(x)
    end)

    addConn(UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            updateSlider(inp.Position.X)
        end
    end))

    addConn(UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))

    sliderBtn.MouseEnter:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.1), {BackgroundColor3 = C.RowH}):Play()
    end)
    sliderBtn.MouseLeave:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.1), {BackgroundColor3 = C.Row}):Play()
    end)
end

local function Gap()
    local f = Instance.new("Frame")
    f.Size                    = UDim2.new(1, 0, 0, 6)
    f.BackgroundTransparency  = 1
    f.Parent                  = scroll
end

-- ─── Build UI ─────────────────────────────────────────────────────────────────

SectionLabel("  FLY")
Gap()

local setFlyToggle = Toggle("Fly", "Phím T để toggle nhanh", false, function(v)
    S.FlyEnabled = v
end)

Gap()
Slider("Fly Speed", "Tốc độ bay (Shift = x2.5)", 10, 500, 50, 0, function(v)
    S.FlySpeed = v
end)

Gap()
SectionLabel("  TỐC ĐỘ")
Gap()

Slider("WalkSpeed Multiplier", "Nhân tốc độ đi bộ", 1, 20, 1, 1, function(v)
    S.WalkMult = v
end)

Gap()
Slider("Sprint Multiplier", "Nhân tốc độ chạy", 1, 20, 1, 1, function(v)
    S.SprintMult = v
end)

Gap()
SectionLabel("  KHÁC")
Gap()

Toggle("Infinite Stamina", "Không bao giờ hết stamina", false, function(v)
    S.InfStamina = v
end)

Gap()

-- ─── Drag ─────────────────────────────────────────────────────────────────────
do
    local dragging, dragStart, startPos = false, nil, nil
    header.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = inp.Position
            startPos  = main.Position
        end
    end)
    addConn(UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = inp.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))
    addConn(UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))
end

-- ─── Phím tắt ─────────────────────────────────────────────────────────────────
addConn(UserInputService.InputBegan:Connect(function(inp, typing)
    if typing then return end
    -- T = toggle fly
    if inp.KeyCode == Enum.KeyCode.T then
        setFlyToggle(not S.FlyEnabled)
    end
    -- RightShift = ẩn/hiện menu
    if inp.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
    end
end))

-- ─── Entrance animation ───────────────────────────────────────────────────────
main.Size = UDim2.new(0, 290, 0, 0)
TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Size = UDim2.new(0, 290, 0, 370)}):Play()

print("[BRM5 Move] Menu đã tải! T = Fly | RightShift = ẩn/hiện menu")
