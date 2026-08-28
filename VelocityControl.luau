local VelocityControl = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIUtils = require(script.Parent:WaitForChild("UIUtils"))

-- Component References
local meterContainer = nil
local settingsWindow = nil
local saveModal = nil
local toggleBtn = nil
local fillBar = nil
local settingsBtn = nil
local meterTrack = nil
local header = nil
local title = nil
local closeBtn = nil
local scroll = nil
local presetsFrame = nil
local addBtn = nil
local modalInput = nil
local confirmBtn = nil
local cancelBtn = nil

-- Module State
local isEnabled = false
local isSettingsOpen = false
local currentTheme = nil

-- Dynamic Velocity State
local currentEnergy = 0
local visualEnergy = 0
local settings = {
	Gain = 13.5,
	Decay = 3.2,
	Rate = 12.0,
	MinVel = 18,
	MaxVel = 128,
}

-- Dynamic Voicing Presets (Full 1-128 velocity scale)
local PRESETS = {
	Default = { Gain = 13.5, Decay = 3.2, Rate = 12.0, MinVel = 18, MaxVel = 128 },
	Light = { Gain = 10.0, Decay = 4.2, Rate = 9.0, MinVel = 15, MaxVel = 110 },
	Heavy = { Gain = 22.0, Decay = 2.0, Rate = 15.0, MinVel = 25, MaxVel = 128 },
	Horowitz = { Gain = 10.0, Decay = 4.5, Rate = 10.0, MinVel = 12, MaxVel = 90 },
}

local customPresets = {}

-- Remote Connections
local remotes = ReplicatedStorage:WaitForChild("PianoRemotes", 5)
local saveRemote = remotes and remotes:WaitForChild("SaveVelocityPreset", 5)
local getFunc = remotes and remotes:WaitForChild("GetVelocityPresets", 5)

-- Voicing & Timing Memory
local lastStrikeTime = 0
local lastNoteIndex = 40
local recentStrikes = {}

-- Dynamic Theme Resolution Helper
local function GetActiveThemeColors(theme)
	if type(UIUtils.GetActiveThemeColors) == "function" then
		return UIUtils.GetActiveThemeColors(theme)
	elseif type(UIUtils.GetThemeColors) == "function" then
		return UIUtils.GetThemeColors(theme)
	elseif type(UIUtils.GetTheme) == "function" then
		return UIUtils.GetTheme(theme)
	elseif type(UIUtils.GetColors) == "function" then
		return UIUtils.GetColors(theme)
	end
	return UIUtils.Theme or UIUtils.Colors or UIUtils.C or {}
end

local function getThemeColors(theme)
	local C = GetActiveThemeColors(theme)
	return {
		MainBg = C.CardBackground or C.BG_COLOR or C.COLOR_OFF or Color3.fromRGB(30, 30, 35),
		SecondaryBg = C.SecondaryBackground or C.ButtonBackground or C.COLOR_BTN or Color3.fromRGB(40, 40, 48),
		ButtonBg = C.ButtonBackground or C.SecondaryBackground or C.COLOR_BTN or Color3.fromRGB(40, 40, 48),
		AccentColor = C.AccentColor or C.Accent or C.COLOR_ON or Color3.fromRGB(70, 140, 240),
		TextColor = C.TextColor or C.TEXT_ON or Color3.fromRGB(240, 240, 250),
		SubTextColor = C.TextMuted or C.TextColor or C.TEXT_OFF or Color3.fromRGB(160, 160, 170),
		StrokeColor = C.StrokeColor or C.STROKE_COLOR or C.STROKE_DEFAULT or C.CardSelect or Color3.fromRGB(85, 95, 110),
	}
end

function VelocityControl.Init(screenGui)
	if meterContainer then return end

	local C = getThemeColors(currentTheme)

	-- Outer HUD Container
	meterContainer = Instance.new("Frame")
	meterContainer.Name = "VelocityHUD"
	meterContainer.Size = UDim2.new(0, 380, 0, 52)
	meterContainer.Position = UDim2.new(1, -20, 1, -20)
	meterContainer.AnchorPoint = Vector2.new(1, 1)
	meterContainer.BackgroundTransparency = 1
	meterContainer.Parent = screenGui

	-- Toolbar Buttons
	local toolbar = Instance.new("Frame")
	toolbar.Name = "Toolbar"
	toolbar.Size = UDim2.new(1, 0, 0, 22)
	toolbar.Position = UDim2.new(0, 0, 0, 0)
	toolbar.BackgroundTransparency = 1
	toolbar.Parent = meterContainer

	local toolLayout = Instance.new("UIListLayout")
	toolLayout.FillDirection = Enum.FillDirection.Horizontal
	toolLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	toolLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	toolLayout.Padding = UDim.new(0, 5)
	toolLayout.SortOrder = Enum.SortOrder.LayoutOrder
	toolLayout.Parent = toolbar

	settingsBtn = Instance.new("TextButton")
	settingsBtn.Name = "SettingsBtn"
	settingsBtn.LayoutOrder = 1
	settingsBtn.Size = UDim2.new(0, 28, 0, 22)
	settingsBtn.BackgroundColor3 = C.MainBg
	settingsBtn.BackgroundTransparency = 0.25
	settingsBtn.Text = "?"
	settingsBtn.TextColor3 = C.TextColor
	settingsBtn.Font = Enum.Font.GothamBold
	settingsBtn.TextSize = 12
	settingsBtn:SetAttribute("ThemeRole", "ButtonBackground")
	settingsBtn.Parent = toolbar

	if UIUtils.CreateCorner then UIUtils.CreateCorner(settingsBtn, 4) end
	if UIUtils.CreateStroke then UIUtils.CreateStroke(settingsBtn, C.StrokeColor, 1) end

	toggleBtn = Instance.new("TextButton")
	toggleBtn.Name = "ToggleBtn"
	toggleBtn.LayoutOrder = 2
	toggleBtn.Size = UDim2.new(0, 42, 0, 22)
	toggleBtn.BackgroundColor3 = C.MainBg
	toggleBtn.BackgroundTransparency = 0.25
	toggleBtn.Text = "OFF"
	toggleBtn.TextColor3 = C.SubTextColor
	toggleBtn.Font = Enum.Font.GothamBold
	toggleBtn.TextSize = 10
	toggleBtn:SetAttribute("ThemeRole", "ButtonBackground")
	toggleBtn.Parent = toolbar

	if UIUtils.CreateCorner then UIUtils.CreateCorner(toggleBtn, 4) end
	if UIUtils.CreateStroke then UIUtils.CreateStroke(toggleBtn, C.StrokeColor, 1) end

	-- Squared Meter Track
	meterTrack = Instance.new("Frame")
	meterTrack.Name = "MeterTrack"
	meterTrack.Size = UDim2.new(1, 0, 0, 24)
	meterTrack.Position = UDim2.new(0, 0, 1, 0)
	meterTrack.AnchorPoint = Vector2.new(0, 1)
	meterTrack.BackgroundColor3 = C.MainBg
	meterTrack.BackgroundTransparency = 0.25
	meterTrack.ClipsDescendants = true
	meterTrack:SetAttribute("ThemeRole", "CardBackground")
	meterTrack.Parent = meterContainer

	if UIUtils.CreateCorner then UIUtils.CreateCorner(meterTrack, 4) end
	if UIUtils.CreateStroke then UIUtils.CreateStroke(meterTrack, C.StrokeColor, 1) end

	-- Glowing Fill Bar
	fillBar = Instance.new("Frame")
	fillBar.Name = "FillBar"
	fillBar.Size = UDim2.new(0, 0, 1, 0)
	fillBar.Position = UDim2.new(0, 0, 0, 0)
	fillBar.BackgroundColor3 = C.AccentColor
	fillBar.BackgroundTransparency = 0.15
	fillBar.BorderSizePixel = 0
	fillBar.Parent = meterTrack

	if UIUtils.CreateCorner then UIUtils.CreateCorner(fillBar, 4) end

	-- Settings Window
	settingsWindow = Instance.new("Frame")
	settingsWindow.Name = "VelocitySettingsWindow"
	settingsWindow.Size = UDim2.new(0, 220, 0, 320)
	settingsWindow.Position = UDim2.new(1, -240, 1, -395)
	settingsWindow.BackgroundColor3 = C.MainBg
	settingsWindow.BackgroundTransparency = 0.15
	settingsWindow.Visible = false
	settingsWindow:SetAttribute("ThemeRole", "CardBackground")
	settingsWindow.Parent = screenGui

	if UIUtils.CreateCorner then UIUtils.CreateCorner(settingsWindow, 6) end
	if UIUtils.CreateStroke then UIUtils.CreateStroke(settingsWindow, C.StrokeColor, 1) end

	header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 28)
	header.BackgroundColor3 = C.SecondaryBg
	header:SetAttribute("ThemeRole", "SecondaryBackground")
	header.Parent = settingsWindow

	if UIUtils.CreateCorner then UIUtils.CreateCorner(header, 6) end

	title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -30, 1, 0)
	title.Position = UDim2.new(0, 8, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "Auto: NPS to Velocity"
	title.TextColor3 = C.TextColor
	title.Font = Enum.Font.GothamBold
	title.TextSize = 11
	title.TextXAlignment = Enum.TextXAlignment.Left
	title:SetAttribute("ThemeRole", "TextColor")
	title.Parent = header

	closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 20, 0, 20)
	closeBtn.Position = UDim2.new(1, -25, 0, 4)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Text = "X"
	closeBtn.TextColor3 = C.SubTextColor
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 11
	closeBtn:SetAttribute("ThemeRole", "TextColor")
	closeBtn.Parent = header

	closeBtn.MouseButton1Click:Connect(function()
		isSettingsOpen = false
		settingsWindow.Visible = false
		if saveModal then saveModal.Visible = false end
	end)

	if UIUtils.MakeDraggable then
		UIUtils.MakeDraggable(settingsWindow, header)
	end

	scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -12, 1, -34)
	scroll.Position = UDim2.new(0, 6, 0, 32)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = C.SecondaryBg
	scroll.Parent = settingsWindow

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 5)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scroll

	-- Presets Grid Container
	presetsFrame = Instance.new("Frame")
	presetsFrame.Name = "PresetsFrame"
	presetsFrame.Size = UDim2.new(1, 0, 0, 0)
	presetsFrame.AutomaticSize = Enum.AutomaticSize.Y
	presetsFrame.BackgroundColor3 = C.SecondaryBg
	presetsFrame.BackgroundTransparency = 0.2
	presetsFrame:SetAttribute("ThemeRole", "SecondaryBackground")
	presetsFrame.Parent = scroll

	if UIUtils.CreateCorner then UIUtils.CreateCorner(presetsFrame, 4) end

	local presetGrid = Instance.new("UIGridLayout")
	presetGrid.CellSize = UDim2.new(0, 64, 0, 24)
	presetGrid.CellPadding = UDim2.new(0, 4, 0, 4)
	presetGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	presetGrid.Parent = presetsFrame

	local presetPadding = Instance.new("UIPadding")
	presetPadding.PaddingTop = UDim.new(0, 4)
	presetPadding.PaddingBottom = UDim.new(0, 4)
	presetPadding.PaddingLeft = UDim.new(0, 4)
	presetPadding.PaddingRight = UDim.new(0, 4)
	presetPadding.Parent = presetsFrame

	-- Dynamic Sliders Initialization
	local sliderUpdaters = {}
	if UIUtils.CreateSliderRow then
		sliderUpdaters["Gain"]   = UIUtils.CreateSliderRow(scroll, "Gain", "gain", 1, 50, settings.Gain, true, function(_, val) settings.Gain = val end)
		sliderUpdaters["Decay"]  = UIUtils.CreateSliderRow(scroll, "Decay", "decay", 0.1, 10, settings.Decay, true, function(_, val) settings.Decay = val end)
		sliderUpdaters["Rate"]   = UIUtils.CreateSliderRow(scroll, "Rate", "rate", 1, 20, settings.Rate, true, function(_, val) settings.Rate = val end)
		sliderUpdaters["MinVel"] = UIUtils.CreateSliderRow(scroll, "MinVel", "velocity min", 1, 128, settings.MinVel, false, function(_, val) settings.MinVel = val end)
		sliderUpdaters["MaxVel"] = UIUtils.CreateSliderRow(scroll, "MaxVel", "velocity max", 1, 128, settings.MaxVel, false, function(_, val) settings.MaxVel = val end)
	end

	local function applyPreset(presetData)
		for propName, val in pairs(presetData) do
			if sliderUpdaters[propName] then
				sliderUpdaters[propName](val, true)
			end
			settings[propName] = val
		end
	end

	-- Static Presets
	for _, pName in ipairs({ "Default", "Light", "Heavy", "Horowitz" }) do
		local btn = Instance.new("TextButton")
		btn.Name = pName .. "PresetBtn"
		btn.BackgroundColor3 = C.MainBg
		btn.Text = pName
		btn.TextColor3 = C.TextColor
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 9
		btn:SetAttribute("ThemeRole", "ButtonBackground")
		btn.Parent = presetsFrame

		if UIUtils.CreateCorner then UIUtils.CreateCorner(btn, 4) end

		btn.MouseButton1Click:Connect(function()
			applyPreset(PRESETS[pName])
		end)
	end

	-- Custom Presets Generator Helper
	local function createCustomPresetButton(pName, pData)
		local btn = Instance.new("TextButton")
		btn.Name = "CustomPreset_" .. pName
		btn.BackgroundColor3 = C.MainBg
		btn.Text = pName
		btn.TextColor3 = Color3.fromRGB(241, 196, 15)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 9
		btn.TextTruncate = Enum.TextTruncate.AtEnd
		btn:SetAttribute("ThemeRole", "ButtonBackground")
		btn.Parent = presetsFrame

		if UIUtils.CreateCorner then UIUtils.CreateCorner(btn, 4) end

		btn.MouseButton1Click:Connect(function()
			applyPreset(pData)
		end)

		local deleteBtn = Instance.new("TextButton")
		deleteBtn.Name = "DeleteBtn"
		deleteBtn.Size = UDim2.new(0, 12, 0, 12)
		deleteBtn.Position = UDim2.new(1, -13, 0, 1)
		deleteBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
		deleteBtn.Text = "X"
		deleteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		deleteBtn.Font = Enum.Font.GothamBold
		deleteBtn.TextSize = 8
		deleteBtn.Parent = btn

		if UIUtils.CreateCorner then UIUtils.CreateCorner(deleteBtn, 3) end

		deleteBtn.MouseButton1Click:Connect(function()
			customPresets[pName] = nil
			btn:Destroy()
			local deleteRemote = remotes and remotes:FindFirstChild("DeleteVelocityPreset")
			if deleteRemote then
				deleteRemote:FireServer(pName)
			end
		end)
	end

	-- Add (+) Button
	addBtn = Instance.new("TextButton")
	addBtn.Name = "AddPresetBtn"
	addBtn.BackgroundColor3 = C.AccentColor
	addBtn.Text = "+"
	addBtn.TextColor3 = C.TextColor
	addBtn.Font = Enum.Font.GothamBold
	addBtn.TextSize = 14
	addBtn.Parent = presetsFrame

	if UIUtils.CreateCorner then UIUtils.CreateCorner(addBtn, 4) end

	-- Modal Window
	saveModal = Instance.new("Frame")
	saveModal.Name = "SavePresetModal"
	saveModal.Size = UDim2.new(0, 170, 0, 90)
	saveModal.Position = UDim2.new(0.5, -85, 0.5, -45)
	saveModal.BackgroundColor3 = C.MainBg
	saveModal.Visible = false
	saveModal:SetAttribute("ThemeRole", "CardBackground")
	saveModal.Parent = settingsWindow

	if UIUtils.CreateCorner then UIUtils.CreateCorner(saveModal, 4) end
	if UIUtils.CreateStroke then UIUtils.CreateStroke(saveModal, C.StrokeColor, 1) end

	modalInput = Instance.new("TextBox")
	modalInput.Size = UDim2.new(1, -16, 0, 26)
	modalInput.Position = UDim2.new(0, 8, 0, 12)
	modalInput.BackgroundColor3 = C.SecondaryBg
	modalInput.PlaceholderText = "Preset Name..."
	modalInput.Text = ""
	modalInput.TextColor3 = C.TextColor
	modalInput.Font = Enum.Font.GothamBold
	modalInput.TextSize = 11
	modalInput:SetAttribute("ThemeRole", "SecondaryBackground")
	modalInput.Parent = saveModal

	if UIUtils.CreateCorner then UIUtils.CreateCorner(modalInput, 4) end

	confirmBtn = Instance.new("TextButton")
	confirmBtn.Size = UDim2.new(0.45, 0, 0, 24)
	confirmBtn.Position = UDim2.new(0.05, 0, 1, -30)
	confirmBtn.BackgroundColor3 = C.AccentColor
	confirmBtn.Text = "Save"
	confirmBtn.TextColor3 = C.TextColor
	confirmBtn.Font = Enum.Font.GothamBold
	confirmBtn.TextSize = 10
	confirmBtn.Parent = saveModal

	if UIUtils.CreateCorner then UIUtils.CreateCorner(confirmBtn, 4) end

	cancelBtn = Instance.new("TextButton")
	cancelBtn.Size = UDim2.new(0.45, 0, 0, 24)
	cancelBtn.Position = UDim2.new(0.5, 0, 1, -30)
	cancelBtn.BackgroundColor3 = C.MainBg
	cancelBtn.Text = "Cancel"
	cancelBtn.TextColor3 = C.SubTextColor
	cancelBtn.Font = Enum.Font.GothamBold
	cancelBtn.TextSize = 10
	cancelBtn:SetAttribute("ThemeRole", "ButtonBackground")
	cancelBtn.Parent = saveModal

	if UIUtils.CreateCorner then UIUtils.CreateCorner(cancelBtn, 4) end

	addBtn.MouseButton1Click:Connect(function()
		saveModal.Visible = true
		modalInput.Text = ""
		modalInput:CaptureFocus()
	end)

	cancelBtn.MouseButton1Click:Connect(function()
		saveModal.Visible = false
	end)

	confirmBtn.MouseButton1Click:Connect(function()
		local name = modalInput.Text:gsub("%s+", "")
		if #name > 0 and #name <= 10 then
			local presetData = {}
			for k, v in pairs(settings) do presetData[k] = v end

			local existing = presetsFrame:FindFirstChild("CustomPreset_" .. name)
			if existing then existing:Destroy() end

			customPresets[name] = presetData
			createCustomPresetButton(name, presetData)

			addBtn.Parent = nil
			addBtn.Parent = presetsFrame

			if saveRemote then
				saveRemote:FireServer(name, presetData)
			end
			saveModal.Visible = false
		end
	end)

	if getFunc then
		task.spawn(function()
			local saved = getFunc:InvokeServer()
			if saved then
				for pName, pData in pairs(saved) do
					customPresets[pName] = pData
					createCustomPresetButton(pName, pData)
				end
				addBtn.Parent = nil
				addBtn.Parent = presetsFrame
			end
		end)
	end

	scroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
	end)

	toggleBtn.MouseButton1Click:Connect(function()
		VelocityControl.Toggle()
	end)

	settingsBtn.MouseButton1Click:Connect(function()
		isSettingsOpen = not isSettingsOpen
		settingsWindow.Visible = isSettingsOpen
		if not isSettingsOpen and saveModal then
			saveModal.Visible = false
		end
	end)

	-- Adaptive Exponential Decay Render Engine
	RunService.Heartbeat:Connect(function(dt)
		if currentEnergy > 0 then
			local dynamicDecayRate = settings.Decay * (1.0 + (currentEnergy * 2.5))
			currentEnergy = math.max(0, currentEnergy - (dynamicDecayRate * dt))
		end

		if currentEnergy > visualEnergy then
			visualEnergy = currentEnergy
		else
			local lerpSpeed = math.clamp(dt * settings.Rate * 2.0, 0, 1)
			visualEnergy = visualEnergy + (currentEnergy - visualEnergy) * lerpSpeed
		end

		local clampedVal = math.clamp(visualEnergy, 0, 1)
		fillBar.Size = UDim2.new(clampedVal, 0, 1, 0)

		local activeCols = getThemeColors(currentTheme)
		if clampedVal > 0.80 then
			local fillRatio = (clampedVal - 0.80) / 0.20
			fillBar.BackgroundColor3 = activeCols.AccentColor:Lerp(Color3.fromRGB(241, 196, 15), fillRatio)
		else
			fillBar.BackgroundColor3 = activeCols.AccentColor
		end
	end)

	VelocityControl.ApplyTheme()
end

function VelocityControl.SetState(state)
	isEnabled = state
	if not toggleBtn then return end

	local C = getThemeColors(currentTheme)
	toggleBtn.Text = isEnabled and "ON" or "OFF"
	toggleBtn.BackgroundColor3 = isEnabled and C.AccentColor or C.MainBg
	toggleBtn.BackgroundTransparency = isEnabled and 0.1 or 0.25
	toggleBtn.TextColor3 = isEnabled and C.TextColor or C.SubTextColor
end

function VelocityControl.Toggle()
	VelocityControl.SetState(not isEnabled)
end

-- Core Dynamic Velocity Calculation Engine
function VelocityControl.ProcessNoteStrike(noteIndex)
	if not isEnabled then
		return nil
	end

	local now = os.clock()
	local deltaTime = now - lastStrikeTime
	lastStrikeTime = now

	noteIndex = noteIndex or 40
	local pitchJump = math.abs(noteIndex - lastNoteIndex)
	lastNoteIndex = noteIndex

	table.insert(recentStrikes, now)
	for i = #recentStrikes, 1, -1 do
		if now - recentStrikes[i] > 0.08 then
			table.remove(recentStrikes, i)
		end
	end
	local chordSize = #recentStrikes

	if deltaTime > 0.28 then
		currentEnergy = 0.0
	end

	local gainFactor = (settings.Gain / 13.5)

	local energyBoost = 0
	if deltaTime <= 0.035 then
		energyBoost = (0.32 / math.max(1, chordSize * 0.65)) * gainFactor
	elseif deltaTime <= 0.07 then
		energyBoost = (0.16 / math.max(1, chordSize * 0.5)) * gainFactor
	elseif deltaTime <= 0.14 then
		energyBoost = 0.07 * gainFactor
	else
		energyBoost = 0.02 * gainFactor
	end

	local isOctave = (pitchJump >= 11 and pitchJump <= 13) or (pitchJump >= 23 and pitchJump <= 25)
	if isOctave then
		if deltaTime < 0.08 then
			energyBoost = energyBoost + (0.12 * gainFactor)
		elseif deltaTime < 0.25 then
			energyBoost = energyBoost + (0.06 * gainFactor)
		else
			energyBoost = energyBoost + (0.02 * gainFactor)
		end

		if noteIndex <= 36 then
			energyBoost = energyBoost + 0.03
		end
	end

	currentEnergy = math.clamp(currentEnergy + energyBoost, 0, 1.0)

	local baseVolume = math.pow(currentEnergy, 0.75)

	local accent = 0

	if noteIndex >= 58 then
		accent = accent + (((noteIndex - 58) / 30) * 0.05)
	elseif noteIndex <= 26 then
		accent = accent + (((26 - noteIndex) / 25) * 0.05)
	end

	if pitchJump >= 7 and not isOctave and deltaTime > 0.05 then
		accent = accent + 0.02
	end

	if chordSize >= 3 then
		accent = accent + 0.01
	end

	local rawDynamic = math.clamp(baseVolume + accent, 0, 1.0)

	local minVolumeScale = math.clamp(settings.MinVel / 128, 0.0078, 1.0)
	local maxVolumeScale = math.clamp(settings.MaxVel / 128, minVolumeScale, 1.0)

	local finalVolume = minVolumeScale + (rawDynamic * (maxVolumeScale - minVolumeScale))
	return math.clamp(finalVolume, 0.01, 1.0)
end

function VelocityControl.CalculateFilterCutoff(volume: number): number
	local norm = math.clamp((volume - 0.01) / 0.99, 0, 1)
	return 1500 + (20000 - 1500) * math.pow(norm, 1.5)
end

function VelocityControl.ApplyToSound(soundInstance: Sound, volume: number)
	soundInstance.Volume = math.clamp(volume, 0, 1)

	local lowPass = soundInstance:FindFirstChildOfClass("EqualizerSoundEffect") 
		or soundInstance:FindFirstChild("PianoLowPass")

	if lowPass then
		local norm = math.clamp((volume - 0.01) / 0.99, 0, 1)
		lowPass.HighGain = math.clamp((norm * 12) - 12, -12, 0)
	end
end

-- Dynamic Theme Engine Integration
function VelocityControl.ApplyTheme(theme)
	if type(theme) == "table" then
		currentTheme = theme
	end

	local C = getThemeColors(currentTheme)

	if settingsBtn then
		settingsBtn.BackgroundColor3 = C.MainBg
		settingsBtn.TextColor3 = C.TextColor
		local stroke = settingsBtn:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Color = C.StrokeColor end
	end

	VelocityControl.SetState(isEnabled)

	if meterTrack then
		meterTrack.BackgroundColor3 = C.MainBg
		local stroke = meterTrack:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Color = C.StrokeColor end
	end

	if fillBar and visualEnergy <= 0.80 then
		fillBar.BackgroundColor3 = C.AccentColor
	end

	if settingsWindow then
		settingsWindow.BackgroundColor3 = C.MainBg
		local stroke = settingsWindow:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Color = C.StrokeColor end
	end

	if header then header.BackgroundColor3 = C.SecondaryBg end
	if title then title.TextColor3 = C.TextColor end
	if closeBtn then closeBtn.TextColor3 = C.SubTextColor end
	if scroll then scroll.ScrollBarImageColor3 = C.SecondaryBg end
	if presetsFrame then presetsFrame.BackgroundColor3 = C.SecondaryBg end

	if presetsFrame then
		for _, child in ipairs(presetsFrame:GetChildren()) do
			if child:IsA("TextButton") then
				if child.Name:find("PresetBtn") and not child.Name:find("CustomPreset") then
					child.BackgroundColor3 = C.MainBg
					child.TextColor3 = C.TextColor
				elseif child.Name:find("CustomPreset") then
					child.BackgroundColor3 = C.MainBg
				end
			end
		end
	end

	if addBtn then
		addBtn.BackgroundColor3 = C.AccentColor
		addBtn.TextColor3 = C.TextColor
	end

	if saveModal then
		saveModal.BackgroundColor3 = C.MainBg
		local modalStroke = saveModal:FindFirstChildOfClass("UIStroke")
		if modalStroke then modalStroke.Color = C.StrokeColor end
	end

	if modalInput then
		modalInput.BackgroundColor3 = C.SecondaryBg
		modalInput.TextColor3 = C.TextColor
	end

	if confirmBtn then
		confirmBtn.BackgroundColor3 = C.AccentColor
		confirmBtn.TextColor3 = C.TextColor
	end

	if cancelBtn then
		cancelBtn.BackgroundColor3 = C.MainBg
		cancelBtn.TextColor3 = C.SubTextColor
	end
end

VelocityControl.UpdateTheme = VelocityControl.ApplyTheme
VelocityControl.RefreshTheme = VelocityControl.ApplyTheme
VelocityControl.SetTheme = VelocityControl.ApplyTheme

return VelocityControl