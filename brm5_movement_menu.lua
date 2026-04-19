--[[
    BRM5 Movement Menu v3
    Fly dùng BodyVelocity + BodyGyro (không cần hook module)
    WalkSpeed override liên tục qua Heartbeat
    T = toggle Fly | RightShift = ẩn/hiện menu
--]]

-- ─── Dọn dẹp instance cũ ─────────────────────────────────────────────────────
if getgenv().BRM5_Move_Cleanup then
    pcall(getgenv().BRM5_Move_Cleanup)
end

local _conns = {}
local function addConn(c) table.insert(_conns, c) return c end
local _flyObjs = {}

getgenv().BRM5_Move_Cleanup = function()
    for _, c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
    table.clear(_conns)
    for _, obj in pairs(_flyObjs) do pcall(function() obj:Destroy() end) end
    table.clear(_flyObjs)
    if getgenv().BRM5_MoveGui then
        pcall(function() getgenv().BRM5_MoveGui:Destroy() end)
        getgenv().BRM5_MoveGui = nil
    end
    local lp = game:GetService("Players").LocalPlayer
    local char = lp and lp.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum.WalkSpeed = 16 end) end
end

-- ─── Services ────────────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local lp               = Players.LocalPlayer

-- ─── Settings ────────────────────────────────────────────────────────────────
local S = { FlyEnabled = false, FlySpeed = 50, WalkMult = 1 }
getgenv().BRM5_Move_Settings = S

local BASE_WS = 16

-- ─── Helpers ─────────────────────────────────────────────────────────────────
local camera = workspace.CurrentCamera
addConn(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    camera = workspace.CurrentCamera
end))

local function getHum()
    local c = lp and lp.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
    local c = lp and lp.Character
    return c and (c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart)
end

-- ─── WalkSpeed loop (override liên tục vì BRM5 reset mỗi frame) ─────────────
addConn(RunService.Heartbeat:Connect(function()
    if S.FlyEnabled then return end
    local hum = getHum()
    if not hum then return end
    local target = BASE_WS * S.WalkMult
    if math.abs(hum.WalkSpeed - target) > 0.5 then
        pcall(function() hum.WalkSpeed = target end)
    end
end))

-- ─── Fly System (BodyVelocity + BodyGyro) ────────────────────────────────────
local bv, bg

local function createFly(root)
    if bv then pcall(function() bv:Destroy() end) end
    if bg then pcall(function() bg:Destroy() end) end

    bv = Instance.new("BodyVelocity")
    bv.Velocity  = Vector3.new(0,0,0)
    bv.MaxForce  = Vector3.new(1e5,1e5,1e5)
    bv.P         = 1e4
    bv.Parent    = root

    bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e5,1e5,1e5)
    bg.P         = 1e4
    bg.D         = 500
    bg.CFrame    = root.CFrame
    bg.Parent    = root

    _flyObjs.bv = bv
    _flyObjs.bg = bg
end

local function destroyFly()
    if bv then pcall(function() bv:Destroy() end); bv = nil end
    if bg then pcall(function() bg:Destroy() end); bg = nil end
    _flyObjs.bv = nil; _flyObjs.bg = nil
end

addConn(RunService.Heartbeat:Connect(function()
    if not S.FlyEnabled then return end
    local root = getRoot()
    local hum  = getHum()
    if not root then return end

    if not bv or not bv.Parent then createFly(root) end
    if not bv then return end

    if hum then
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Swimming) end)
        pcall(function() hum.WalkSpeed = 0 end)
    end

    local camCF = camera.CFrame
    local dir   = Vector3.new(0,0,0)

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + camCF.LookVector  end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - camCF.LookVector  end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - camCF.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + camCF.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space)       then dir = dir + Vector3.new(0,1,0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0,1,0) end

    local boost = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 2.5 or 1

    bv.Velocity = dir.Magnitude > 0 and (dir.Unit * S.FlySpeed * boost) or Vector3.new(0,0,0)
    bg.CFrame   = CFrame.new(root.Position, root.Position + camCF.LookVector)
end))

local flyToggleSetter  -- gán sau khi build UI

local function setFly(v)
    S.FlyEnabled = v
    if not v then
        destroyFly()
        local hum = getHum()
        if hum then
            pcall(function()
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                hum.WalkSpeed = BASE_WS * S.WalkMult
            end)
        end
    end
    if flyToggleSetter then flyToggleSetter(v) end
end

addConn(lp.CharacterAdded:Connect(function()
    S.FlyEnabled = false
    destroyFly()
    if flyToggleSetter then flyToggleSetter(false) end
end))

-- ─── GUI ─────────────────────────────────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name           = "BRM5_MoveMenu"
sg.ResetOnSpawn   = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.IgnoreGuiInset = true
sg.Parent         = (gethui and gethui()) or lp:WaitForChild("PlayerGui")
getgenv().BRM5_MoveGui = sg

local C = {
    BG     = Color3.fromRGB(13,13,18),
    Header = Color3.fromRGB(20,20,28),
    Accent = Color3.fromRGB(85,145,255),
    Text   = Color3.fromRGB(220,220,230),
    Sub    = Color3.fromRGB(115,115,140),
    ON     = Color3.fromRGB(55,195,95),
    OFF    = Color3.fromRGB(50,50,68),
    Row    = Color3.fromRGB(24,24,34),
    RowH   = Color3.fromRGB(32,32,46),
    Border = Color3.fromRGB(42,42,62),
}

local MENU_H = 330

local main = Instance.new("Frame")
main.Size             = UDim2.new(0,275,0,0)
main.Position         = UDim2.new(0.5,-137,0.5,-(MENU_H/2))
main.BackgroundColor3 = C.BG
main.BorderSizePixel  = 0
main.ClipsDescendants = true
main.Parent           = sg
Instance.new("UICorner",main).CornerRadius = UDim.new(0,10)
local ms = Instance.new("UIStroke",main); ms.Color=C.Border; ms.Thickness=1.2

-- Header
local hdr = Instance.new("Frame")
hdr.Size             = UDim2.new(1,0,0,44)
hdr.BackgroundColor3 = C.Header
hdr.BorderSizePixel  = 0
hdr.Parent           = main
Instance.new("UICorner",hdr).CornerRadius = UDim.new(0,10)
local hp = Instance.new("Frame")
hp.Size=UDim2.new(1,0,0,10); hp.Position=UDim2.new(0,0,1,-10)
hp.BackgroundColor3=C.Header; hp.BorderSizePixel=0; hp.Parent=hdr

local al = Instance.new("Frame")
al.Size=UDim2.new(0,3,0,20); al.Position=UDim2.new(0,12,0.5,-10)
al.BackgroundColor3=C.Accent; al.BorderSizePixel=0; al.Parent=hdr
Instance.new("UICorner",al).CornerRadius=UDim.new(1,0)

local function lbl(p,txt,sz,font,col,xa,pos,size)
    local l=Instance.new("TextLabel"); l.Size=size; l.Position=pos
    l.BackgroundTransparency=1; l.Text=txt; l.Font=font
    l.TextSize=sz; l.TextColor3=col; l.TextXAlignment=xa; l.Parent=p; return l
end
lbl(hdr,"BRM5 Movement",14,Enum.Font.GothamBold,C.Text,
    Enum.TextXAlignment.Left,UDim2.new(0,22,0,5),UDim2.new(1,-80,0,20))
lbl(hdr,"Fly + Speed  |  v3",10,Enum.Font.Gotham,C.Sub,
    Enum.TextXAlignment.Left,UDim2.new(0,22,0,25),UDim2.new(1,-80,0,14))

local xb=Instance.new("TextButton")
xb.Size=UDim2.new(0,26,0,26); xb.Position=UDim2.new(1,-34,0.5,-13)
xb.BackgroundColor3=Color3.fromRGB(185,50,50); xb.Text="✕"
xb.Font=Enum.Font.GothamBold; xb.TextSize=12
xb.TextColor3=Color3.fromRGB(255,255,255); xb.BorderSizePixel=0; xb.Parent=hdr
Instance.new("UICorner",xb).CornerRadius=UDim.new(0,6)
xb.MouseButton1Click:Connect(function()
    TweenService:Create(main,TweenInfo.new(0.18),{Size=UDim2.new(0,275,0,0)}):Play()
    task.wait(0.19); main.Visible=false
end)

-- Scroll
local sc=Instance.new("ScrollingFrame")
sc.Size=UDim2.new(1,0,1,-44); sc.Position=UDim2.new(0,0,0,44)
sc.BackgroundTransparency=1; sc.BorderSizePixel=0
sc.ScrollBarThickness=3; sc.ScrollBarImageColor3=C.Accent
sc.AutomaticCanvasSize=Enum.AutomaticSize.Y
sc.CanvasSize=UDim2.new(0,0,0,0); sc.Parent=main
local ll=Instance.new("UIListLayout",sc); ll.Padding=UDim.new(0,0)
local pad=Instance.new("UIPadding",sc)
pad.PaddingLeft=UDim.new(0,9); pad.PaddingRight=UDim.new(0,9)
pad.PaddingTop=UDim.new(0,8);  pad.PaddingBottom=UDim.new(0,8)

local function Gap(h)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,h or 5)
    f.BackgroundTransparency=1; f.Parent=sc
end
local function SecLabel(t)
    local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,0,0,20)
    l.BackgroundTransparency=1; l.Text=t:upper()
    l.Font=Enum.Font.GothamBold; l.TextSize=10
    l.TextColor3=C.Accent; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=sc
end

local function Toggle(label, hint, default, onChange)
    local state = default or false
    local h = hint and 50 or 40
    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,h); row.BackgroundColor3=C.Row
    row.BorderSizePixel=0; row.Parent=sc
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,8)

    lbl(row,label,13,Enum.Font.GothamSemibold,C.Text,
        Enum.TextXAlignment.Left,UDim2.new(0,12,0,hint and 7 or 0),
        UDim2.new(1,-58,0,hint and 20 or h))
    if hint then lbl(row,hint,10,Enum.Font.Gotham,C.Sub,
        Enum.TextXAlignment.Left,UDim2.new(0,12,0,27),UDim2.new(1,-58,0,14)) end

    local pill=Instance.new("Frame")
    pill.Size=UDim2.new(0,38,0,20); pill.Position=UDim2.new(1,-46,0.5,-10)
    pill.BackgroundColor3=state and C.ON or C.OFF
    pill.BorderSizePixel=0; pill.Parent=row
    Instance.new("UICorner",pill).CornerRadius=UDim.new(1,0)

    local dot=Instance.new("Frame")
    dot.Size=UDim2.new(0,14,0,14); dot.AnchorPoint=Vector2.new(0,0.5)
    dot.Position=state and UDim2.new(0,21,0.5,0) or UDim2.new(0,3,0.5,0)
    dot.BackgroundColor3=Color3.fromRGB(255,255,255)
    dot.BorderSizePixel=0; dot.Parent=pill
    Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)

    local function set(v)
        state=v
        TweenService:Create(pill,TweenInfo.new(0.13),{BackgroundColor3=v and C.ON or C.OFF}):Play()
        TweenService:Create(dot,TweenInfo.new(0.13),{Position=v and UDim2.new(0,21,0.5,0) or UDim2.new(0,3,0.5,0)}):Play()
        onChange(v)
    end

    local btn=Instance.new("TextButton")
    btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""; btn.Parent=row
    btn.MouseButton1Click:Connect(function() set(not state) end)
    btn.MouseEnter:Connect(function() TweenService:Create(row,TweenInfo.new(0.1),{BackgroundColor3=C.RowH}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(row,TweenInfo.new(0.1),{BackgroundColor3=C.Row}):Play() end)
    return set
end

local function Slider(label, hint, min, max, default, decimals, onChange)
    local val=default; decimals=decimals or 0
    local fmt = decimals>0 and ("%."..decimals.."f") or "%d"
    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,62); row.BackgroundColor3=C.Row
    row.BorderSizePixel=0; row.Parent=sc
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,8)

    lbl(row,label,13,Enum.Font.GothamSemibold,C.Text,
        Enum.TextXAlignment.Left,UDim2.new(0,12,0,7),UDim2.new(1,-72,0,18))
    local vl=lbl(row,string.format(fmt,val),13,Enum.Font.GothamBold,C.Accent,
        Enum.TextXAlignment.Right,UDim2.new(1,-66,0,7),UDim2.new(0,56,0,18))
    if hint then lbl(row,hint,10,Enum.Font.Gotham,C.Sub,
        Enum.TextXAlignment.Left,UDim2.new(0,12,0,24),UDim2.new(1,-12,0,13)) end

    local trk=Instance.new("Frame")
    trk.Size=UDim2.new(1,-22,0,5); trk.Position=UDim2.new(0,11,1,-14)
    trk.BackgroundColor3=C.OFF; trk.BorderSizePixel=0; trk.Parent=row
    Instance.new("UICorner",trk).CornerRadius=UDim.new(1,0)

    local fill=Instance.new("Frame")
    fill.Size=UDim2.new((val-min)/(max-min),0,1,0)
    fill.BackgroundColor3=C.Accent; fill.BorderSizePixel=0; fill.Parent=trk
    Instance.new("UICorner",fill).CornerRadius=UDim.new(1,0)

    local hdl=Instance.new("Frame")
    hdl.Size=UDim2.new(0,13,0,13); hdl.AnchorPoint=Vector2.new(0.5,0.5)
    hdl.Position=UDim2.new((val-min)/(max-min),0,0.5,0)
    hdl.BackgroundColor3=Color3.fromRGB(255,255,255); hdl.BorderSizePixel=0; hdl.Parent=trk
    Instance.new("UICorner",hdl).CornerRadius=UDim.new(1,0)

    local drag=false
    local function upd(ax)
        local r=math.clamp((ax-trk.AbsolutePosition.X)/trk.AbsoluteSize.X,0,1)
        val=math.floor((min+r*(max-min))*10^decimals+0.5)/10^decimals
        local rv=(val-min)/(max-min)
        fill.Size=UDim2.new(rv,0,1,0); hdl.Position=UDim2.new(rv,0,0.5,0)
        vl.Text=string.format(fmt,val); onChange(val)
    end
    local sb=Instance.new("TextButton")
    sb.Size=UDim2.new(1,0,1,0); sb.BackgroundTransparency=1; sb.Text=""; sb.Parent=row
    sb.MouseButton1Down:Connect(function(x) drag=true; upd(x) end)
    sb.MouseEnter:Connect(function() TweenService:Create(row,TweenInfo.new(0.1),{BackgroundColor3=C.RowH}):Play() end)
    sb.MouseLeave:Connect(function() TweenService:Create(row,TweenInfo.new(0.1),{BackgroundColor3=C.Row}):Play() end)
    addConn(UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType==Enum.UserInputType.MouseMovement then upd(i.Position.X) end
    end))
    addConn(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
    end))
end

-- ─── Build content ───────────────────────────────────────────────────────────
SecLabel("  fly")
Gap()

flyToggleSetter = Toggle("Fly","T = bật/tắt  |  Shift = tăng tốc x2.5",false,function(v)
    -- gọi setFly nhưng không gọi lại flyToggleSetter (tránh loop)
    S.FlyEnabled = v
    if not v then
        destroyFly()
        local hum=getHum()
        if hum then
            pcall(function()
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                hum.WalkSpeed=BASE_WS*S.WalkMult
            end)
        end
    end
end)

Gap()
Slider("Fly Speed","Tốc độ bay cơ bản",10,500,50,0,function(v) S.FlySpeed=v end)
Gap(8)
SecLabel("  tốc độ")
Gap()
Slider("WalkSpeed Multiplier","x1 = bình thường, x5 = nhanh hơn 5 lần",1,15,1,1,function(v)
    S.WalkMult=v
    if not S.FlyEnabled then
        local hum=getHum()
        if hum then pcall(function() hum.WalkSpeed=BASE_WS*v end) end
    end
end)
Gap(8)

-- Info box
local ir=Instance.new("Frame")
ir.Size=UDim2.new(1,0,0,70); ir.BackgroundColor3=C.Row
ir.BorderSizePixel=0; ir.Parent=sc
Instance.new("UICorner",ir).CornerRadius=UDim.new(0,8)
local it=Instance.new("TextLabel")
it.Size=UDim2.new(1,-16,1,0); it.Position=UDim2.new(0,10,0,0)
it.BackgroundTransparency=1
it.Text="T → Fly bật/tắt\nRightShift → Ẩn/hiện menu\nWASD + Space/Ctrl khi bay\nShift (khi fly) = tăng tốc x2.5"
it.Font=Enum.Font.Gotham; it.TextSize=11; it.TextColor3=C.Sub
it.TextXAlignment=Enum.TextXAlignment.Left
it.TextYAlignment=Enum.TextYAlignment.Center; it.Parent=ir
Gap()

-- ─── Drag menu ───────────────────────────────────────────────────────────────
do
    local drag,ds,dp=false,nil,nil
    hdr.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            drag=true; ds=i.Position; dp=main.Position
        end
    end)
    addConn(UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d=i.Position-ds
            main.Position=UDim2.new(dp.X.Scale,dp.X.Offset+d.X,dp.Y.Scale,dp.Y.Offset+d.Y)
        end
    end))
    addConn(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
    end))
end

-- ─── Phím tắt ────────────────────────────────────────────────────────────────
addConn(UserInputService.InputBegan:Connect(function(inp,typing)
    if typing then return end
    if inp.KeyCode==Enum.KeyCode.T then
        -- Toggle fly
        local newVal = not S.FlyEnabled
        flyToggleSetter(newVal)  -- update UI pill
        -- trigger logic
        S.FlyEnabled = newVal
        if not newVal then
            destroyFly()
            local hum=getHum()
            if hum then
                pcall(function()
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                    hum.WalkSpeed=BASE_WS*S.WalkMult
                end)
            end
        end
    end
    if inp.KeyCode==Enum.KeyCode.RightShift then
        if main.Visible then
            main.Visible=false
        else
            main.Visible=true; main.Size=UDim2.new(0,275,0,0)
            TweenService:Create(main,TweenInfo.new(0.2,Enum.EasingStyle.Back),
                {Size=UDim2.new(0,275,0,MENU_H)}):Play()
        end
    end
end))

-- ─── Entrance ────────────────────────────────────────────────────────────────
TweenService:Create(main,TweenInfo.new(0.22,Enum.EasingStyle.Back),
    {Size=UDim2.new(0,275,0,MENU_H)}):Play()

print("[BRM5 Move v3] Loaded — T=Fly | RightShift=menu")
