--[[
    XT Loader UI  (UI only - no game logic)
    Recreates the "Opening <Game>" loader window with a 4-step progress bar
    and a live activity log.

    USAGE
        local Loader = loadstring(game:HttpGet("YOUR_RAW_URL/loader_ui.lua"))()
        -- or paste this file above your script and use `Loader` directly

        local ui = Loader.new({
            Game    = "Anime Adventures",
            Version = "v0.6.7",
            Steps   = { "Character", "Assets", "Setup", "Start" },
            Logo    = "rbxassetid://0",   -- your logo asset id (optional)
        })

        ui:SetStep(1)                                  -- Character = active
        local a = ui:Log("Waiting for your character to spawn", "run")
        -- ... your code ...
        a:Complete()                                   -- turns the row into a check
        ui:SetStep(2)                                  -- Character done, Assets active
        ...
        ui:Finish("Ready - game started")              -- all steps done
        task.wait(1.5)
        ui:Destroy()

    API
        ui:SetStatus(text)
        ui:SetStep(n)            -- steps < n = done, step n = active, rest = idle
        ui:Log(text, kind)       -- kind: "info" | "run" | "ok"   -> returns row
        row:Complete([newText])  -- "run" -> "ok" and stamps the elapsed time
        ui:Finish([text])
        ui:Destroy()
]]

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")

local Loader = {}
Loader.__index = Loader

-- Theme -----------------------------------------------------------------
local C = {
    Card1  = Color3.fromRGB(36, 28, 110),
    Card2  = Color3.fromRGB(20, 15, 61),
    Border = Color3.fromRGB(74, 63, 208),
    Panel  = Color3.fromRGB(42, 47, 134),
    Ink    = Color3.fromRGB(255, 255, 255),
    Mute   = Color3.fromRGB(170, 176, 255),
    Ok     = Color3.fromRGB(57, 255, 122),
    OkDim  = Color3.fromRGB(27, 143, 74),
    Idle   = Color3.fromRGB(70, 74, 150),
    Line   = Color3.fromRGB(122, 60, 255),
}

-- Helpers ---------------------------------------------------------------
local function getParent()
    local ok, h = pcall(function() return gethui and gethui() end)
    if ok and h then return h end
    ok, h = pcall(function() return game:GetService("CoreGui") end)
    if ok and h then return h end
    return Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function new(class, props, children)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = o end
    return o
end

local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r) }) end
local function stroke(col, th, tr)
    return new("UIStroke", { Color = col, Thickness = th or 1, Transparency = tr or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function tween(o, t, goal, style, dir, rep, rev)
    local info = TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out,
        rep or 0, rev or false)
    local tw = TweenService:Create(o, info, goal)
    tw:Play()
    return tw
end
local function makeDraggable(handle, target)
    local dragging, startPos, startInput
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startInput, startPos = true, i.Position, target.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startInput
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- Constructor -----------------------------------------------------------
function Loader.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Loader)

    self.Game    = opts.Game or "Game"
    self.Version = opts.Version or "v1.0.0"
    self.Names   = opts.Steps or { "Character", "Assets", "Setup", "Start" }
    self.T0      = os.clock()
    self.Rows    = {}
    self.Dots    = {}
    self.Bars    = {}
    self.Spinners = {}

    -- ScreenGui
    local gui = new("ScreenGui", {
        Name = "XTLoader", ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    gui.Parent = getParent()
    self.Gui = gui

    -- Window
    local win = new("Frame", {
        Name = "Window", Size = UDim2.fromOffset(560, 430),
        Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = C.Card1, BorderSizePixel = 0, Parent = gui,
    }, {
        corner(18), stroke(C.Border, 2),
        new("UIGradient", { Rotation = 60, Color = ColorSequence.new(C.Card1, C.Card2) }),
    })
    self.Window = win

    -- Scale the window down on short screens (phones / small windows)
    local scale = new("UIScale", { Scale = 1, Parent = win })
    local function fit()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local vp = cam.ViewportSize
        scale.Scale = math.clamp(math.min((vp.Y - 90) / 430, (vp.X - 30) / 560), 0.4, 1)
    end
    fit()
    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
    end

    -- Header
    local top = new("Frame", { Name = "Top", Size = UDim2.new(1, 0, 0, 66),
        BackgroundTransparency = 1, Parent = win })
    new("TextLabel", {
        Text = "XT", Font = Enum.Font.GothamBlack, TextSize = 34, TextColor3 = C.Ink,
        BackgroundTransparency = 1, Size = UDim2.fromOffset(60, 40),
        Position = UDim2.fromOffset(18, 13), TextXAlignment = Enum.TextXAlignment.Left, Parent = top,
    })
    new("TextLabel", {
        Text = self.Game, Font = Enum.Font.GothamBold, TextSize = 20, TextColor3 = C.Ink,
        BackgroundTransparency = 1, Size = UDim2.fromOffset(300, 24),
        Position = UDim2.fromOffset(84, 14), TextXAlignment = Enum.TextXAlignment.Left, Parent = top,
    })
    new("TextLabel", {
        Text = "Loader " .. self.Version, Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = C.Mute,
        BackgroundTransparency = 1, Size = UDim2.fromOffset(300, 18),
        Position = UDim2.fromOffset(84, 38), TextXAlignment = Enum.TextXAlignment.Left, Parent = top,
    })
    new("Frame", { Name = "Divider", Size = UDim2.new(1, -36, 0, 2), Position = UDim2.new(0, 18, 1, 0),
        BackgroundColor3 = C.Line, BorderSizePixel = 0, Parent = top }, {
        new("UIGradient", { Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }),
    })
    makeDraggable(top, win)

    -- Logo + title
    local logo = new("Frame", { Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(18, 86),
        BackgroundColor3 = Color3.fromRGB(58, 93, 176), BorderSizePixel = 0, Parent = win },
        { corner(14), stroke(Color3.fromRGB(82, 184, 255), 3) })
    if opts.Logo then
        new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            Image = opts.Logo, ScaleType = Enum.ScaleType.Fit, Parent = logo })
    else
        new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            Text = "XT", Font = Enum.Font.GothamBlack, TextSize = 26, TextColor3 = C.Ink, Parent = logo })
    end

    new("TextLabel", {
        Text = "Opening " .. self.Game, Font = Enum.Font.GothamBold, TextSize = 24, TextColor3 = C.Ink,
        BackgroundTransparency = 1, Size = UDim2.new(1, -110, 0, 30),
        Position = UDim2.fromOffset(94, 88), TextXAlignment = Enum.TextXAlignment.Left, Parent = win,
    })
    self.StatusLabel = new("TextLabel", {
        Text = "Getting things ready...", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = C.Ok,
        BackgroundTransparency = 1, Size = UDim2.new(1, -110, 0, 22),
        Position = UDim2.fromOffset(94, 120), TextXAlignment = Enum.TextXAlignment.Left, Parent = win,
    })

    -- Stepper
    local n = #self.Names
    local stepper = new("Frame", { Size = UDim2.new(1, -40, 0, 80), Position = UDim2.fromOffset(20, 166),
        BackgroundTransparency = 1, Parent = win })
    self.Stepper = stepper

    for i, name in ipairs(self.Names) do
        local cx = (i - 0.5) / n -- centre as a scale of stepper width

        if i < n then
            local nx = (i + 0.5) / n
            local bg = new("Frame", {
                Size = UDim2.new(nx - cx, -48, 0, 3), Position = UDim2.new(cx, 24, 0, 19),
                BackgroundColor3 = C.Idle, BorderSizePixel = 0, Parent = stepper }, { corner(2) })
            local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Ok,
                BorderSizePixel = 0, Parent = bg }, { corner(2) })
            self.Bars[i] = fill
        end

        local dot = new("Frame", {
            Size = UDim2.fromOffset(38, 38), Position = UDim2.new(cx, -19, 0, 0),
            BackgroundColor3 = C.OkDim, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = stepper })
        local st = stroke(C.Idle, 3)
        st.Parent = dot
        corner(19).Parent = dot
        local mark = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            Text = "", Font = Enum.Font.GothamBlack, TextSize = 20, TextColor3 = C.Ok, Parent = dot })
        new("TextLabel", {
            Text = name, Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = C.Ink,
            BackgroundTransparency = 1, Size = UDim2.fromOffset(90, 18),
            Position = UDim2.new(cx, -45, 0, 46), Parent = stepper })
        self.Dots[i] = { Frame = dot, Stroke = st, Mark = mark }
    end

    -- Activity panel
    local panel = new("Frame", { Size = UDim2.new(1, -36, 0, 168), Position = UDim2.new(0, 18, 1, -186),
        BackgroundColor3 = C.Panel, BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = win },
        { corner(14) })
    new("TextLabel", { Text = "ACTIVITY", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.Mute,
        BackgroundTransparency = 1, Size = UDim2.new(1, -28, 0, 18), Position = UDim2.fromOffset(16, 10),
        TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
    local list = new("Frame", { Size = UDim2.new(1, -28, 1, -36), Position = UDim2.fromOffset(14, 32),
        BackgroundTransparency = 1, Parent = panel }, {
        new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }) })
    self.List = list

    self:SetStep(0)
    return self
end

-- Status / steps --------------------------------------------------------
function Loader:SetStatus(text)
    self.StatusLabel.Text = text
end

function Loader:SetStep(active)
    for i, d in ipairs(self.Dots) do
        if d.Pulse then d.Pulse:Cancel(); d.Pulse = nil end
        if i < active then            -- done
            d.Mark.Text = utf8.char(0x2713)
            tween(d.Stroke, 0.25, { Color = C.Ok })
            tween(d.Frame, 0.25, { BackgroundTransparency = 0.6 })
            if self.Bars[i] then tween(self.Bars[i], 0.5, { Size = UDim2.fromScale(1, 1) }) end
        elseif i == active then       -- active
            d.Mark.Text = ""
            d.Stroke.Color = C.Ok
            d.Frame.BackgroundTransparency = 1
            d.Pulse = tween(d.Stroke, 0.8, { Transparency = 0.7 },
                Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
        else                          -- idle
            d.Mark.Text = ""
            d.Stroke.Color = C.Idle
            d.Stroke.Transparency = 0
            d.Frame.BackgroundTransparency = 1
            if self.Bars[i] then self.Bars[i].Size = UDim2.fromScale(0, 1) end
        end
    end
end

-- Activity log ----------------------------------------------------------
local ICONS = { info = utf8.char(0x24D8), run = utf8.char(0x25C7), ok = utf8.char(0x2713) }

function Loader:Log(text, kind)
    kind = kind or "ok"
    local ui = self
    local row = new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1,
        LayoutOrder = #self.Rows + 1, Parent = self.List })
    local icon = new("TextLabel", { Size = UDim2.fromOffset(22, 24), BackgroundTransparency = 1,
        Text = ICONS[kind], Font = Enum.Font.GothamBlack, TextSize = 16,
        TextColor3 = (kind == "info") and C.Ink or C.Ok, Parent = row })
    local label = new("TextLabel", { Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(32, 0),
        BackgroundTransparency = 1, Text = text, Font = Enum.Font.GothamMedium, TextSize = 15,
        TextColor3 = C.Ink, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row })
    local time = new("TextLabel", { Size = UDim2.fromOffset(70, 24), Position = UDim2.new(1, -70, 0, 0),
        BackgroundTransparency = 1, Text = "", Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = C.Mute,
        TextXAlignment = Enum.TextXAlignment.Right, Parent = row })

    local function stamp() time.Text = string.format("+%.1fs", os.clock() - ui.T0) end
    local spin
    local obj = {}

    if kind == "run" then
        spin = tween(icon, 1, { Rotation = 360 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1)
    else
        stamp()
    end

    function obj:Complete(newText)
        if spin then spin:Cancel(); spin = nil end
        icon.Rotation = 0
        icon.Text = ICONS.ok
        icon.TextColor3 = C.Ok
        if newText then label.Text = newText end
        stamp()
    end

    table.insert(self.Rows, obj)
    return obj
end

function Loader:Finish(text)
    self:SetStep(#self.Names + 1)
    self:SetStatus(text or "Ready")
end

function Loader:Destroy()
    for _, d in ipairs(self.Dots) do if d.Pulse then d.Pulse:Cancel() end end
    if self.Gui then self.Gui:Destroy() end
end

-- DEMO ------------------------------------------------------------------
-- Delete or comment this block out when you use the UI in your real script.
local DEMO = false
if DEMO then
    task.spawn(function()
        local ui = Loader.new({ Game = "Anime Adventures", Version = "v0.6.7" })
        ui:Log("Loader opened", "info")
        ui:SetStep(1)

        local r = ui:Log("Waiting for your character to spawn", "run")
        task.wait(2); r:Complete()
        ui:SetStep(2)

        r = ui:Log("Preloading game assets", "run")
        task.wait(2); r:Complete()
        ui:SetStep(3)

        r = ui:Log("Setting up " .. ui.Game, "run")
        task.wait(2); r:Complete()
        ui:SetStep(4)

        r = ui:Log("Starting " .. ui.Game, "run")
        task.wait(2); r:Complete()
        ui:Finish("Ready - game started")
        task.wait(2)
        ui:Destroy()
    end)
end

return Loader
