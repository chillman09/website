-- ============================================================
-- SPARK PLUGIN v2.0 — website-six-bay-23.vercel.app
-- Install: Plugins → Manage Plugins → Install from file
-- ============================================================
local toolbar   = plugin:CreateToolbar("Spark")
local toggleBtn = toolbar:CreateButton("Spark","Open Spark","")
local widgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 520, 160, 520, 160)
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

local BACKEND = "https://alert-harmony-production.up.railway.app"
local VERSION = "v2.0.0"
local POLL_INTERVAL = 4 -- seconds

-- State
local sessionToken = ""
local isConnected  = false
local pollLoop     = nil

-- Load saved token
local function loadToken()
	local ok, v = pcall(function() return plugin:GetSetting("sparkToken") end)
	return (ok and type(v)=="string") and v or ""
end
local function saveToken(t)
	pcall(function() plugin:SetSetting("sparkToken", t) end)
end

sessionToken = loadToken()

-- ============================================================
-- UI
-- ============================================================
local C = {
	bg      = Color3.fromRGB(10, 10, 16),
	surface = Color3.fromRGB(16, 16, 26),
	border  = Color3.fromRGB(28, 28, 46),
	accent  = Color3.fromRGB(245, 200, 66),
	text    = Color3.fromRGB(220, 220, 240),
	muted   = Color3.fromRGB(90, 90, 120),
	success = Color3.fromRGB(62, 207, 142),
	error   = Color3.fromRGB(255, 77, 109),
}

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

local function uiCorner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = p
end

-- Logo area
local logo = Instance.new("TextLabel")
logo.Size = UDim2.new(0, 120, 1, 0)
logo.Position = UDim2.new(0, 14, 0, 0)
logo.BackgroundTransparency = 1
logo.Text = "⚡ Spark  " .. VERSION
logo.TextColor3 = C.accent
logo.TextSize = 14
logo.Font = Enum.Font.GothamBold
logo.TextXAlignment = Enum.TextXAlignment.Left
logo.Parent = topBar

-- Status dot + label
local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0,8,0,8)
statusDot.Position = UDim2.new(0.5,-60,0.5,-4)
statusDot.BackgroundColor3 = C.muted
statusDot.BorderSizePixel = 0
statusDot.Parent = topBar
uiCorner(statusDot, 99)

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(0,120,1,0)
statusLbl.Position = UDim2.new(0.5,-48,0,0)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "Disconnected"
statusLbl.TextColor3 = C.muted
statusLbl.TextSize = 12
statusLbl.Font = Enum.Font.GothamBold
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Parent = topBar

-- Connect / Disconnect button
local connectBtn = Instance.new("TextButton")
connectBtn.Size = UDim2.new(0, 96, 0, 28)
connectBtn.Position = UDim2.new(1,-114,0.5,-14)
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
body.Size = UDim2.new(1,-24,1,-60)
body.Position = UDim2.new(0,12,0,52)
body.BackgroundTransparency = 1
body.Parent = main

-- Token input label
local tokenLbl = Instance.new("TextLabel")
tokenLbl.Size = UDim2.new(1,0,0,16)
tokenLbl.BackgroundTransparency = 1
tokenLbl.Text = "Session Token — get this from website-six-bay-23.vercel.app"
tokenLbl.TextColor3 = C.muted
tokenLbl.TextSize = 11
tokenLbl.Font = Enum.Font.Gotham
tokenLbl.TextXAlignment = Enum.TextXAlignment.Left
tokenLbl.Parent = body

-- Token input
local tokenInput = Instance.new("TextBox")
tokenInput.Size = UDim2.new(1,-90,0,32)
tokenInput.Position = UDim2.new(0,0,0,20)
tokenInput.BackgroundColor3 = C.surface
tokenInput.TextColor3 = C.accent
tokenInput.PlaceholderText = "Paste your session token here (spk_...)"
tokenInput.PlaceholderColor3 = C.muted
tokenInput.TextSize = 11
tokenInput.Font = Enum.Font.Code
tokenInput.Text = sessionToken
tokenInput.ClearTextOnFocus = false
tokenInput.BorderSizePixel = 0
tokenInput.Parent = body
uiCorner(tokenInput, 6)
local tokenPad = Instance.new("UIPadding") tokenPad.PaddingLeft = UDim.new(0,10) tokenPad.Parent = tokenInput

-- Open website button
local webBtn = Instance.new("TextButton")
webBtn.Size = UDim2.new(0,80,0,32)
webBtn.Position = UDim2.new(1,-80,0,20)
webBtn.BackgroundColor3 = C.surface
webBtn.TextColor3 = C.text
webBtn.Text = "🌐 Website"
webBtn.TextSize = 10
webBtn.Font = Enum.Font.GothamBold
webBtn.BorderSizePixel = 0
webBtn.Parent = body
uiCorner(webBtn,6)

local webBorderStroke = Instance.new("UIStroke")
webBorderStroke.Color = C.border webBorderStroke.Thickness = 1 webBorderStroke.Parent = webBtn

-- Activity log
local logLbl = Instance.new("TextLabel")
logLbl.Size = UDim2.new(1,0,0,20)
logLbl.Position = UDim2.new(0,0,0,58)
logLbl.BackgroundTransparency = 1
logLbl.Text = "Open website-six-bay-23.vercel.app in your browser, then press Connect."
logLbl.TextColor3 = C.muted
logLbl.TextSize = 11
logLbl.Font = Enum.Font.Gotham
logLbl.TextXAlignment = Enum.TextXAlignment.Left
logLbl.TextTruncate = Enum.TextTruncate.AtEnd
logLbl.Parent = body

-- ============================================================
-- STATUS
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
	end
	if msg then logLbl.Text = msg end
end

local function setLog(msg)
	logLbl.Text = msg
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
-- POLLING LOOP
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
					setLog("✅ Executed " .. count .. " change" .. (count==1 and "" or "s") .. " from Spark website")
				end
			elseif not ok then
				-- connection lost
				setStatus(false, "⚠️ Connection lost. Check your internet and try reconnecting.")
				break
			end

			task.wait(POLL_INTERVAL)
		end
	end)
end

local function stopPolling()
	if pollLoop then
		task.cancel(pollLoop)
		pollLoop = nil
	end
end

-- ============================================================
-- CONNECT / DISCONNECT
-- ============================================================
local function connect()
	local token = tokenInput.Text:gsub("%s","")
	if token == "" then
		setLog("⚠️ Please paste your session token first.")
		return
	end
	sessionToken = token
	saveToken(token)

	connectBtn.Text = "..." connectBtn.BackgroundColor3 = C.muted

	-- Validate token with backend
	local ok, result = pcall(function()
		local r = Http:RequestAsync({
			Url = BACKEND .. "/auth/validate",
			Method = "POST",
			Headers = {["Content-Type"] = "application/json"},
			Body = Http:JSONEncode({ sessionToken = token })
		})
		return Http:JSONDecode(r.Body)
	end)

	if ok and result and result.valid then
		setStatus(true, "✅ Connected as " .. (result.user and result.user.username or "user") .. " — chat at website-six-bay-23.vercel.app")
		startPolling()
	else
		setStatus(false, "❌ Invalid token. Get yours at website-six-bay-23.vercel.app")
	end
end

local function disconnect()
	stopPolling()
	setStatus(false, "Disconnected. Press Connect to reconnect.")
end

connectBtn.MouseButton1Click:Connect(function()
	if isConnected then disconnect() else connect() end
end)

tokenInput.FocusLost:Connect(function(enter)
	if enter then connect() end
end)

webBtn.MouseButton1Click:Connect(function()
	-- Can't open URLs from plugins directly, show the URL
	setLog("🌐 Visit: website-six-bay-23.vercel.app to chat with AI")
end)

-- ============================================================
-- AUTO-CONNECT on load if token saved
-- ============================================================
if sessionToken ~= "" then
	task.delay(1, connect)
end

-- ============================================================
-- STARTUP
-- ============================================================
print("⚡ Spark Plugin " .. VERSION .. " loaded!")
print("   Visit website-six-bay-23.vercel.app to get started")
