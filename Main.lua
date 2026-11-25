local base = "https://raw.githubusercontent.com/xthubz/Xt-Hub-Anime-Adventures/main/"

local Loader = loadstring(game:HttpGet(base .. "loader_ui.lua"))()
local ui = Loader.new({ Game = "Anime Adventures", Version = "v0.6.7" })
ui:Log("Loader opened", "info")

-- Step 1: character
ui:SetStep(1)
local r = ui:Log("Waiting for your character to spawn", "run")
if not game:IsLoaded() then game.Loaded:Wait() end
local lp = game:GetService("Players").LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
char:WaitForChild("HumanoidRootPart")
r:Complete()

-- Step 2: assets
ui:SetStep(2)
r = ui:Log("Preloading game assets", "run")
pcall(function()
    game:GetService("ContentProvider"):PreloadAsync({ workspace })
end)
r:Complete()

-- Step 3: your actual script
ui:SetStep(3)
r = ui:Log("Setting up Anime Adventures", "run")
local failed
task.spawn(function()
    local ok, err = pcall(function()
        loadstring(game:HttpGet("https://cdn.sourceb.in/bins/0LSjzkaLSh/0"))()
    end)
    if not ok then failed = err end
end)
task.wait(3) -- give the script time to initialise
r:Complete()

if failed then
    ui:SetStatus("Failed to load")
    ui:Log(tostring(failed), "info")
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
