-- ============================================================
-- SPARK PLUGIN v2.1 — website-six-bay-23.vercel.app
-- Right-click > Save as Local Plugin
-- ============================================================
local toolbar   = plugin:CreateToolbar("Spark")
local toggleBtn = toolbar:CreateButton("Spark","Open Spark","")
local widgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 520, 175, 520, 175)
local widget    = plugin:CreateDockWidgetPluginGui("SparkV2", widgetInfo)
widget.Title    = "Spark"
widget.Enabled  = false

toggleBtn.Click:Connect(function()
	widget.Enabled = not widget.Enabled
	toggleBtn:SetActive(widget.Enabled)
end)

local Http = game:GetService("HttpService")
local CHS  = game:GetService("ChangeHistoryService")
local SES  = game:GetService("ScriptEditorService")
local SSS  = game:GetService("ServerScriptService")

local BACKEND        = "https://alert-harmony-production.up.railway.app"
local VERSION        = "v2.1.0"
local POLL_INTERVAL  = 4   -- seconds between action polls
local CTX_INTERVAL   = 10  -- seconds between context pushes

local sessionToken   = ""
local isConnected    = false
local pollLoop       = nil
local contextLoop    = nil

local function loadToken()
	local ok, v = pcall(function() return plugin:GetSetting("sparkToken") end)
	return (ok and type(v)=="string") and v or ""
end
local function saveToken(t)
	pcall(function() plugin:SetSetting("sparkToken", t) end)
end
sessionToken = loadToken()

-- ============================================================
-- UI COLORS
-- ============================================================
local C = {
	bg      = Color3.fromRGB(10, 10, 16),
	surface = Color3.fromRGB(16, 16, 26),
	border  = Color3.fromRGB(28, 28, 46),
	accent  = Color3.fromRGB(245, 200, 66),
	text    = Color3.fromRGB(220, 220, 240),
	muted   = Color3.fromRGB(90, 90, 120),
	success = Color3.fromRGB(62, 207, 142),
	err     = Color3.fromRGB(255, 77, 109),
	info    = Color3.fromRGB(106, 176, 255),
}

local function uiCorner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = p
end

-- ============================================================
-- UI BUILD
-- ============================================================
local main = Instance.new("Frame")
main.Size = UDim2.new(1,0,1,0)
main.BackgroundColor3 = C.bg
main.BorderSizePixel = 0
main.Parent = widget

-- Top bar
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1,0,0,44)
topBar.BackgroundColor3 = C.surface
topBar.BorderSizePixel = 0
topBar.Parent = main

local logo = Instance.new("TextLabel")
logo.Size = UDim2.new(0,160,1,0)
logo.Position = UDim2.new(0,14,0,0)
logo.BackgroundTransparency = 1
logo.Text = "⚡ Spark  " .. VERSION
logo.TextColor3 = C.accent
logo.TextSize = 14
logo.Font = Enum.Font.GothamBold
logo.TextXAlignment = Enum.TextXAlignment.Left
logo.Parent = topBar

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0,8,0,8)
statusDot.Position = UDim2.new(0.5,-55,0.5,-4)
statusDot.BackgroundColor3 = C.muted
statusDot.BorderSizePixel = 0
statusDot.Parent = topBar
uiCorner(statusDot, 99)

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(0,110,1,0)
statusLbl.Position = UDim2.new(0.5,-43,0,0)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "Disconnected"
statusLbl.TextColor3 = C.muted
statusLbl.TextSize = 12
statusLbl.Font = Enum.Font.GothamBold
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Parent = topBar

local connectBtn = Instance.new("TextButton")
connectBtn.Size = UDim2.new(0,96,0,28)
connectBtn.Position = UDim2.new(1,-110,0.5,-14)
connectBtn.BackgroundColor3 = C.accent
connectBtn.TextColor3 = Color3.fromRGB(12,12,12)
connectBtn.Text = "Connect"
connectBtn.TextSize = 12
connectBtn.Font = Enum.Font.GothamBold
connectBtn.BorderSizePixel = 0
connectBtn.Parent = topBar
uiCorner(connectBtn, 6)

-- Body
local body = Instance.new("Frame")
body.Size = UDim2.new(1,-24,1,-52)
body.Position = UDim2.new(0,12,0,50)
body.BackgroundTransparency = 1
body.Parent = main

-- Token label
local tokenLbl = Instance.new("TextLabel")
tokenLbl.Size = UDim2.new(1,0,0,14)
tokenLbl.BackgroundTransparency = 1
tokenLbl.Text = "Session Token — get this from website-six-bay-23.vercel.app"
tokenLbl.TextColor3 = C.muted
tokenLbl.TextSize = 10
tokenLbl.Font = Enum.Font.Gotham
tokenLbl.TextXAlignment = Enum.TextXAlignment.Left
tokenLbl.Parent = body

-- Token input
local tokenInput = Instance.new("TextBox")
tokenInput.Size = UDim2.new(1,-88,0,30)
tokenInput.Position = UDim2.new(0,0,0,17)
tokenInput.BackgroundColor3 = C.surface
tokenInput.TextColor3 = C.accent
tokenInput.PlaceholderText = "Paste session token (spk_...)"
tokenInput.PlaceholderColor3 = C.muted
tokenInput.TextSize = 11
tokenInput.Font = Enum.Font.Code
tokenInput.Text = sessionToken
tokenInput.ClearTextOnFocus = false
tokenInput.BorderSizePixel = 0
tokenInput.Parent = body
uiCorner(tokenInput, 6)
local tp = Instance.new("UIPadding")
tp.PaddingLeft = UDim.new(0,10) tp.Parent = tokenInput

-- Website button
local webBtn = Instance.new("TextButton")
webBtn.Size = UDim2.new(0,80,0,30)
webBtn.Position = UDim2.new(1,-80,0,17)
webBtn.BackgroundColor3 = C.surface
webBtn.TextColor3 = C.text
webBtn.Text = "🌐 Website"
webBtn.TextSize = 10
webBtn.Font = Enum.Font.GothamBold
webBtn.BorderSizePixel = 0
webBtn.Parent = body
uiCorner(webBtn,6)
local ws = Instance.new("UIStroke")
ws.Color = C.border ws.Thickness = 1 ws.Parent = webBtn

-- Context status bar
local ctxBar = Instance.new("Frame")
ctxBar.Size = UDim2.new(1,0,0,22)
ctxBar.Position = UDim2.new(0,0,0,52)
ctxBar.BackgroundColor3 = Color3.fromRGB(14,14,22)
ctxBar.BorderSizePixel = 0
ctxBar.Parent = body
uiCorner(ctxBar, 5)

local ctxDot = Instance.new("Frame")
ctxDot.Size = UDim2.new(0,6,0,6)
ctxDot.Position = UDim2.new(0,10,0.5,-3)
ctxDot.BackgroundColor3 = C.muted
ctxDot.BorderSizePixel = 0
ctxDot.Parent = ctxBar
uiCorner(ctxDot, 99)

local ctxLbl = Instance.new("TextLabel")
ctxLbl.Size = UDim2.new(1,-24,1,0)
ctxLbl.Position = UDim2.new(0,22,0,0)
ctxLbl.BackgroundTransparency = 1
ctxLbl.Text = "Context: not synced"
ctxLbl.TextColor3 = C.muted
ctxLbl.TextSize = 10
ctxLbl.Font = Enum.Font.Gotham
ctxLbl.TextXAlignment = Enum.TextXAlignment.Left
ctxLbl.Parent = ctxBar

-- Log label
local logLbl = Instance.new("TextLabel")
logLbl.Size = UDim2.new(1,0,0,18)
logLbl.Position = UDim2.new(0,0,0,78)
logLbl.BackgroundTransparency = 1
logLbl.Text = "Open website-six-bay-23.vercel.app, sign in, paste token, click Connect."
logLbl.TextColor3 = C.muted
logLbl.TextSize = 10
logLbl.Font = Enum.Font.Gotham
logLbl.TextXAlignment = Enum.TextXAlignment.Left
logLbl.TextTruncate = Enum.TextTruncate.AtEnd
logLbl.Parent = body

-- ============================================================
-- STATUS HELPERS
-- ============================================================
local function setStatus(connected, msg)
	isConnected = connected
	if connected then
		statusDot.BackgroundColor3 = C.success
		statusLbl.TextColor3 = C.success
		statusLbl.Text = "Connected"
		connectBtn.Text = "Disconnect"
		connectBtn.BackgroundColor3 = Color3.fromRGB(50,50,70)
		connectBtn.TextColor3 = C.text
	else
		statusDot.BackgroundColor3 = C.muted
		statusLbl.TextColor3 = C.muted
		statusLbl.Text = "Disconnected"
		connectBtn.Text = "Connect"
		connectBtn.BackgroundColor3 = C.accent
		connectBtn.TextColor3 = Color3.fromRGB(12,12,12)
		ctxDot.BackgroundColor3 = C.muted
		ctxLbl.Text = "Context: not synced"
		ctxLbl.TextColor3 = C.muted
	end
	if msg then logLbl.Text = msg end
end

local function setCtxStatus(chars)
	ctxDot.BackgroundColor3 = C.success
	ctxLbl.TextColor3 = C.success
	ctxLbl.Text = "Context synced — " .. math.floor(chars/1000) .. "k chars (" .. os.date("%H:%M:%S") .. ")"
end

-- ============================================================
-- GAME CONTEXT BUILDER
-- Full scan: workspace tree + all script sources
-- ============================================================
local function buildContext()
	local parts = {}

	-- Workspace tree
	table.insert(parts, "=== WORKSPACE ===")
	local function scanInst(inst, depth)
		if depth > 6 then return end
		local prefix = string.rep("  ", depth)
		for _, child in ipairs(inst:GetChildren()) do
			if not child:IsA("Camera") and not child:IsA("Terrain") then
				table.insert(parts, prefix .. child.ClassName .. " : " .. child.Name)
				if #child:GetChildren() > 0 then
					scanInst(child, depth + 1)
				end
			end
		end
	end
	scanInst(game.Workspace, 0)

	-- Other services
	local services = {
		"ServerScriptService","StarterGui","StarterPack",
		"StarterPlayer","ReplicatedStorage","ServerStorage",
		"Lighting","Teams","SoundService"
	}
	for _, svcName in ipairs(services) do
		local svc = game:FindService(svcName)
		if svc and #svc:GetChildren() > 0 then
			table.insert(parts, "\n=== " .. svcName .. " ===")
			local function scanSvc(inst, depth)
				if depth > 4 then return end
				local prefix = string.rep("  ", depth)
				for _, child in ipairs(inst:GetChildren()) do
					table.insert(parts, prefix .. child.ClassName .. " : " .. child.Name)
					if #child:GetChildren() > 0 then
						scanSvc(child, depth + 1)
					end
				end
			end
			scanSvc(svc, 1)
		end
	end

	-- Full script sources
	table.insert(parts, "\n=== SCRIPTS (FULL SOURCE) ===")
	for _, obj in ipairs(game:GetDescendants()) do
		if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
			if obj ~= script then
				table.insert(parts, "\n--- PATH: " .. obj:GetFullName() .. " [" .. obj.ClassName .. "] ---")
				local src = obj.Source
				if #src == 0 then
					table.insert(parts, "-- (empty script)")
				elseif #src > 5000 then
					-- For very long scripts, include first 5000 chars
					table.insert(parts, src:sub(1, 5000) .. "\n-- [TRUNCATED at 5000 chars, total: " .. #src .. "]")
				else
					table.insert(parts, src)
				end
			end
		end
	end

	-- Game properties
	table.insert(parts, "\n=== GAME INFO ===")
	table.insert(parts, "PlaceId: " .. tostring(game.PlaceId))
	table.insert(parts, "GameId: " .. tostring(game.GameId))
	pcall(function()
		table.insert(parts, "Studio Version: Roblox Studio")
	end)

	return table.concat(parts, "\n")
end

-- ============================================================
-- CONTEXT PUSH LOOP
-- ============================================================
local function pushContext()
	if not isConnected or sessionToken == "" then return end

	ctxDot.BackgroundColor3 = C.info
	ctxLbl.TextColor3 = C.info
	ctxLbl.Text = "Syncing context..."

	local ok, err = pcall(function()
		local ctx = buildContext()
		local r = Http:RequestAsync({
			Url = BACKEND .. "/context",
			Method = "POST",
			Headers = {["Content-Type"] = "application/json"},
			Body = Http:JSONEncode({
				sessionToken = sessionToken,
				context = ctx
			})
		})
		if r.Success then
			local data = Http:JSONDecode(r.Body)
			setCtxStatus(data.chars or #ctx)
		else
			ctxDot.BackgroundColor3 = C.err
			ctxLbl.TextColor3 = C.err
			ctxLbl.Text = "Context sync failed: " .. r.StatusCode
		end
	end)

	if not ok then
		ctxDot.BackgroundColor3 = C.err
		ctxLbl.TextColor3 = C.err
		ctxLbl.Text = "Context error: " .. tostring(err):sub(1,40)
	end
end

local function startContextLoop()
	if contextLoop then task.cancel(contextLoop) end
	contextLoop = task.spawn(function()
		while isConnected do
			pushContext()
			task.wait(CTX_INTERVAL)
		end
	end)
end

local function stopContextLoop()
	if contextLoop then task.cancel(contextLoop) contextLoop = nil end
end

-- ============================================================
-- ACTION EXECUTOR
-- ============================================================
local function resolveParent(path)
	if not path or path == "" then return SSS end
	local cur = game
	for _, p in ipairs(string.split(path, ".")) do
		if p == "game" then cur = game
		else
			local found = cur:FindFirstChild(p)
			if not found then pcall(function() found = game:GetService(p) end) end
			if found then cur = found else return nil end
		end
	end
	return cur
end

local function executeActions(actions)
	if not actions or #actions == 0 then return 0 end
	CHS:SetWaypoint("Spark_Before")
	local count = 0
	for _, a in ipairs(actions) do
		local aType = a.type or ""
		pcall(function()
			if aType == "create_script" then
				local parent = resolveParent(a.parent) or SSS
				local s = Instance.new(a.scriptType or "Script")
				s.Name = a.name or "SparkScript"
				s.Source = a.source or ""
				s.Parent = parent
				count = count + 1

			elseif aType == "edit_script" then
				local target = a.path and resolveParent(a.path)
				if target and target:IsA("LuaSourceContainer") then
					local doc = SES:FindScriptDocument(target)
					if doc then
						local lc = doc:GetLineCount()
						local ll = doc:GetLine(lc)
						doc:EditTextAsync(a.source or "", 1, 0, lc, #ll)
					else
						target.Source = a.source or ""
					end
					count = count + 1
				end

			elseif aType == "create_instance" then
				local parent = resolveParent(a.parent) or game.Workspace
				local inst = Instance.new(a.className)
				inst.Name = a.name or a.className
				if a.properties then
					for k, v in pairs(a.properties) do
						pcall(function()
							if type(v) == "table" and #v == 3 then
								inst[k] = k:match("[Cc]olor") and Color3.fromRGB(v[1],v[2],v[3]) or Vector3.new(v[1],v[2],v[3])
							elseif k == "BrickColor" then inst[k] = BrickColor.new(v)
							elseif k == "Material" then inst[k] = Enum.Material[v] or inst[k]
							else inst[k] = v end
						end)
					end
				end
				inst.Parent = parent
				count = count + 1

			elseif aType == "delete_instance" then
				local target = a.path and resolveParent(a.path)
				if target then target:Destroy() count = count + 1 end

			elseif aType == "set_property" then
				local target = a.path and resolveParent(a.path)
				if target then target[a.property] = a.value count = count + 1 end
			end
		end)
	end
	CHS:SetWaypoint("Spark_After")
	return count
end

-- ============================================================
-- POLL LOOP — checks for pending actions from website
-- ============================================================
local function startPolling()
	if pollLoop then task.cancel(pollLoop) end
	pollLoop = task.spawn(function()
		while isConnected do
			local ok, result = pcall(function()
				local r = Http:RequestAsync({
					Url = BACKEND .. "/poll?token=" .. Http:UrlEncode(sessionToken),
					Method = "GET"
				})
				if r.Success then return Http:JSONDecode(r.Body) end
				return nil
			end)

			if ok and result then
				local actions = result.actions or {}
				if #actions > 0 then
					local count = executeActions(actions)
					logLbl.Text = "✅ Applied " .. count .. " change" .. (count==1 and "" or "s") .. " from Spark"
					-- push fresh context after changes
					task.delay(1, pushContext)
				end
			elseif not ok then
				setStatus(false, "⚠️ Connection lost. Click Connect to retry.")
				break
			end
			task.wait(POLL_INTERVAL)
		end
	end)
end

local function stopPolling()
	if pollLoop then task.cancel(pollLoop) pollLoop = nil end
end

-- ============================================================
-- CONNECT / DISCONNECT
-- ============================================================
local function connect()
	local tok = tokenInput.Text:gsub("%s","")
	if tok == "" then
		logLbl.Text = "⚠️ Paste your token from website-six-bay-23.vercel.app first."
		return
	end
	sessionToken = tok
	saveToken(tok)
	connectBtn.Text = "..."
	connectBtn.BackgroundColor3 = C.muted

	local ok, result = pcall(function()
		local r = Http:RequestAsync({
			Url = BACKEND .. "/auth/validate",
			Method = "POST",
			Headers = {["Content-Type"]="application/json"},
			Body = Http:JSONEncode({ sessionToken = tok })
		})
		return Http:JSONDecode(r.Body)
	end)

	if ok and result and result.valid then
		local name = result.user and result.user.username or "user"
		setStatus(true, "✅ Connected as " .. name .. " · Syncing game every " .. CTX_INTERVAL .. "s")
		startPolling()
		startContextLoop() -- start pushing context immediately
	else
		setStatus(false, "❌ Invalid token. Sign in at website-six-bay-23.vercel.app and copy your token.")
	end
end

local function disconnect()
	stopPolling()
	stopContextLoop()
	setStatus(false, "Disconnected. Click Connect to reconnect.")
end

-- ============================================================
-- WIRE UP BUTTONS
-- ============================================================
connectBtn.MouseButton1Click:Connect(function()
	if isConnected then disconnect() else connect() end
end)

tokenInput.FocusLost:Connect(function(enter)
	if enter then connect() end
end)

webBtn.MouseButton1Click:Connect(function()
	logLbl.Text = "🌐 Visit: website-six-bay-23.vercel.app — sign in and copy your token"
end)

-- Auto-connect if token saved
if sessionToken ~= "" then
	task.delay(1, connect)
end

print("⚡ Spark Plugin v2.1 loaded!")
print("   Context pushed every " .. CTX_INTERVAL .. "s | Actions polled every " .. POLL_INTERVAL .. "s")
print("   Visit website-six-bay-23.vercel.app")
