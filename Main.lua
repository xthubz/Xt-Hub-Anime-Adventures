local base = "https://raw.githubusercontent.com/xthubz/Xt-Hub-Anime-Adventures/main/"

-- 1) Show the loader FIRST (small file, downloads fast)
local Loader = loadstring(game:HttpGet(base .. "loader_ui.lua"))()
local ui = Loader.new({ Game = "Anime Adventures", Version = "v0.6.7" })
ui:Log("Loader opened", "info")
ui:SetStep(1)
local r = ui:Log("Waiting for your character to spawn", "run")
task.wait(0.5) -- let the window draw before the hub download starts

-- 2) Start your hub in the background
local hubDone, hubErr = false, nil
task.spawn(function()
    local ok, err = pcall(function()
        loadstring(game:HttpGet("https://cdn.sourceb.in/bins/0LSjzkaLSh/0"))()
    end)
    if not ok then hubErr = err end
    hubDone = true
end)

-- 3) Loader steps keep running alongside the hub
task.spawn(function()
    -- waits until cond() is true, or timeout seconds pass
    local function waitUntil(cond, timeout)
        local t = os.clock()
        while not cond() and os.clock() - t < timeout do task.wait(0.1) end
    end

    -- Step 1: character
    if not game:IsLoaded() then game.Loaded:Wait() end
    local lp = game:GetService("Players").LocalPlayer
    local char = lp.Character or lp.CharacterAdded:Wait()
    waitUntil(function() return char:FindFirstChild("HumanoidRootPart") end, 10)
    r:Complete()

    -- Step 2: assets (max 6 seconds so it can never get stuck)
    ui:SetStep(2)
    r = ui:Log("Preloading game assets", "run")
    local preloaded = false
    task.spawn(function()
        pcall(function()
            game:GetService("ContentProvider"):PreloadAsync({ workspace })
        end)
        preloaded = true
    end)
    waitUntil(function() return preloaded end, 6)
    r:Complete()

    -- Step 3: setup (waits for your hub, max 20 seconds)
    ui:SetStep(3)
    r = ui:Log("Setting up Anime Adventures", "run")
    waitUntil(function() return hubDone end, 20)
    r:Complete()

    if hubErr then
        ui:SetStatus("Failed to load")
        ui:Log(tostring(hubErr), "info")
        task.wait(5)
        ui:Destroy()
        return
    end

    -- Step 4: start
    ui:SetStep(4)
    r = ui:Log("Starting Anime Adventures", "run")
    task.wait(1)
    r:Complete()
    ui:Finish("Ready - game started")
    task.wait(1.5)
    ui:Destroy()
end)
