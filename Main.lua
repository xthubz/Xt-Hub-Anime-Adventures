local base = "https://raw.githubusercontent.com/xthubz/Xt-Hub-Anime-Adventures/main/"
local hubUrl = "https://cdn.sourceb.in/bins/KjbnmFRyLG/0"

-- 1) Run the main hub script first
local hubOk, hubErr = pcall(function()
	local src = game:HttpGet(hubUrl)
	local fn, loadErr = loadstring(src)
	assert(fn, loadErr)
	fn()
end)

if not hubOk then
	warn("[XT Hub] Main script failed to run:", hubErr)
end

-- 2) Open the loader UI after the main script runs
local Loader = loadstring(game:HttpGet(base .. "loader_ui.lua"))()
local ui = Loader.new({ Game = "Anime Adventures", Version = "v0.6.7" })
ui:Log("Main script executed", hubOk and "ok" or "info")
ui:SetStep(1)

local r = ui:Log("Waiting for character to finish loading", "run")

local function waitUntil(cond, timeout)
	local t = os.clock()
	while not cond() and os.clock() - t < timeout do
		task.wait(0.1)
	end
	return cond()
end

-- 3) Longer character wait (up to 60s + stabilization wait)
task.spawn(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	local lp = game:GetService("Players").LocalPlayer
	local char = lp.Character or lp.CharacterAdded:Wait()

	-- Wait up to 60 seconds for core character parts to load
	local loaded = waitUntil(function()
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		return hrp ~= nil and hum ~= nil and hum.Parent ~= nil
	end, 60)

	-- Extra pause so character appearance/rig finishes settling
	task.wait(3)

	if loaded then
		r:Complete("Character loaded")
	else
		r:Complete("Character wait timed out")
	end

	-- Step 2: assets
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

	-- Step 3: setup
	ui:SetStep(3)
	r = ui:Log("Setting up Anime Adventures", "run")
	task.wait(1)
	r:Complete()

	-- Step 4: start
	ui:SetStep(4)
	r = ui:Log("Starting Anime Adventures", "run")
	task.wait(1)
	r:Complete()

	if not hubOk then
		ui:SetStatus("Main script had an error")
		ui:Log(tostring(hubErr), "info")
		task.wait(5)
	else
		ui:Finish("Ready - game started")
		task.wait(1.5)
	end

	ui:Destroy()
end)
