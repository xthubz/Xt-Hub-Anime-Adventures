local base = "https://raw.githubusercontent.com/xthubz/Xt-Hub-Anime-Adventures/main/"

-- 1) Start your hub immediately, in the background
local hubDone, hubErr = false, nil
task.spawn(function()
    local ok, err = pcall(function()
        loadstring(game:HttpGet("https://cdn.sourceb.in/bins/0LSjzkaLSh/0"))()
    end)
    if not ok then hubErr = err end
    hubDone = true
end)

-- 2) Run the loader visuals at the same time
task.spawn(function()
    local Loader = loadstring(game:HttpGet(base .. "loader_ui.lua"))()
    local ui = Loader.new({ Game = "Anime Adventures", Version = "v0.6.7" })
    ui:Log("Loader opened", "info")

    -- waits until cond() is true, or timeout seconds pass
    local function waitUntil(cond, timeout)
        local t = os.clock()
        while not cond() and os.clock() - t < timeout do task.wait(0.1) end
    end

    -- Step 1: character
    ui:SetStep(1)
    local r = ui:Log("Waiting for your character to spawn", "run")
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

    -- Step 3: setup (waits for your hub, max 8 seconds)
    ui:SetStep(3)
    r = ui:Log("Setting up Anime Adventures", "run")
    waitUntil(function() return hubDone end, 8)
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
