local ReverbPanel = {}

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local UIUtils = require(script.Parent:WaitForChild("UIUtils"))
local LocalPlayer = Players.LocalPlayer

local reverbButton = nil
local reverbWindow = nil
local headerFrame = nil
local headerTitleLabel = nil
local closeButton = nil
local presetsContainer = nil
local toggleRowFrame = nil
local toggleLabelText = nil
local enableButton = nil
local saveModalFrame = nil
local modalInputBox = nil
local confirmSaveBtn = nil
local cancelSaveBtn = nil
local addPresetBtn = nil

local isOpen = false
local isEnabled = false
local onChangeCallback = nil
local sliderUpdaters = {}
local currentTheme = nil

-- Current Slider Settings Tracker
local currentSettings = {
	Priority = 0,
	DecayTime = 1.5,
	Density = 1.0,
	Diffusion = 1.0,
	DryLevel = 0,
	WetLevel = -6
}

local PRESETS = {
	Room = { DecayTime = 1.2, Density = 0.6, Diffusion = 0.7, DryLevel = 0, WetLevel = -12 },
	Hall = { DecayTime = 3.5, Density = 0.85, Diffusion = 0.9, DryLevel = 0, WetLevel = -3 },
	Cathedral = { DecayTime = 10.0, Density = 1.0, Diffusion = 1.0, DryLevel = 0, WetLevel = 4 },
}

local customPresets = {}

-- Safe Remote Retrieval
local remotes = ReplicatedStorage:WaitForChild("PianoRemotes", 5)
local saveRemote = remotes and remotes:WaitForChild("SaveReverbPreset", 5)
local getFunc = remotes and remotes:WaitForChild("GetReverbPresets", 5)
local deleteRemote = remotes and remotes:WaitForChild("DeleteReverbPreset", 5)

local function getResolvedColors()
	local C = UIUtils.C or UIUtils.Colors or {}
	local bg = currentTheme and (currentTheme.CardBackground or currentTheme.BG_COLOR) or C.COLOR_OFF or Color3.fromRGB(30, 30, 35)
	local secBg = currentTheme and (currentTheme.SecondaryBackground or currentTheme.ButtonBackground) or C.COLOR_BTN or Color3.fromRGB(40, 40, 48)
	local btnBg = currentTheme and (currentTheme.ButtonBackground or currentTheme.SecondaryBackground) or C.COLOR_BTN or Color3.fromRGB(40, 40, 48)
	local accent = currentTheme and (currentTheme.AccentColor or currentTheme.Accent) or C.COLOR_ON or Color3.fromRGB(70, 140, 240)
	local text = currentTheme and currentTheme.TextColor or C.TEXT_ON or Color3.fromRGB(240, 240, 250)
	local textMuted = currentTheme and (currentTheme.TextMuted or currentTheme.TextColor) or C.TEXT_OFF or Color3.fromRGB(160, 160, 170)
	local stroke = currentTheme and (currentTheme.STROKE_COLOR or currentTheme.CardSelect) or C.STROKE_COLOR or Color3.fromRGB(70, 75, 85)

	return {
		bg = bg,
		secBg = secBg,
		btnBg = btnBg,
		accent = accent,
		text = text,
		textMuted = textMuted,
		stroke = stroke
	}
end

local function setEnableState(state)
	isEnabled = state
	if not enableButton then return end

	local cols = getResolvedColors()
	enableButton.Text = isEnabled and "ON" or "OFF"
	enableButton.BackgroundColor3 = isEnabled and cols.accent or cols.bg
	enableButton.TextColor3 = isEnabled and cols.text or cols.textMuted

	if onChangeCallback then
		onChangeCallback("Enabled", isEnabled)
	end
end

function ReverbPanel.Init(screenGui, parentContainer, callback)
	if reverbButton then return end
	onChangeCallback = callback

	local cols = getResolvedColors()

	-- 1. Main Toggle Button
	reverbButton = Instance.new("TextButton")
	reverbButton.Name = "ReverbButton"
	reverbButton.Size = UDim2.new(1, 0, 0, 40)
	reverbButton.Position = UDim2.new(0, 0, 0, 0)
	reverbButton.BackgroundColor3 = cols.bg
	reverbButton.Text = "REVERB"
	reverbButton.TextColor3 = cols.textMuted
	reverbButton.Font = Enum.Font.GothamBold
	reverbButton.TextSize = 13
	reverbButton.AutoButtonColor = false
	reverbButton:SetAttribute("ThemeRole", "ButtonBackground")
	reverbButton.Parent = parentContainer
	if UIUtils.CreateCorner then UIUtils.CreateCorner(reverbButton, 8) end
	if UIUtils.CreateStroke then UIUtils.CreateStroke(reverbButton) end

	reverbButton.MouseButton1Click:Connect(function()
		ReverbPanel.ToggleMenu()
	end)

	-- 2. Pop-out Window
	reverbWindow = Instance.new("Frame")
	reverbWindow.Name = "ReverbWindow"
	reverbWindow.Size = UDim2.new(0, 220, 0, 440)
	reverbWindow.Position = UDim2.new(0, 180, 0.5, -220)
	reverbWindow.BackgroundColor3 = cols.bg
	reverbWindow.Visible = false
	reverbWindow:SetAttribute("ThemeRole", "CardBackground")
	reverbWindow.Parent = screenGui
	if UIUtils.CreateCorner then UIUtils.CreateCorner(reverbWindow, 8) end
	if UIUtils.CreateStroke then UIUtils.CreateStroke(reverbWindow) end

	headerFrame = Instance.new("Frame")
	headerFrame.Name = "Header"
	headerFrame.Size = UDim2.new(1, 0, 0, 30)
	headerFrame.BackgroundColor3 = cols.secBg
	headerFrame:SetAttribute("ThemeRole", "SecondaryBackground")
	headerFrame.Parent = reverbWindow
	if UIUtils.CreateCorner then UIUtils.CreateCorner(headerFrame, 8) end

	headerTitleLabel = Instance.new("TextLabel")
	headerTitleLabel.Size = UDim2.new(1, -30, 1, 0)
	headerTitleLabel.Position = UDim2.new(0, 10, 0, 0)
	headerTitleLabel.BackgroundTransparency = 1
	headerTitleLabel.Text = "Reverb Settings"
	headerTitleLabel.TextColor3 = cols.text
	headerTitleLabel.Font = Enum.Font.GothamBold
	headerTitleLabel.TextSize = 12
	headerTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	headerTitleLabel:SetAttribute("ThemeRole", "TextColor")
	headerTitleLabel.Parent = headerFrame

	closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0, 20, 0, 20)
	closeButton.Position = UDim2.new(1, -25, 0, 5)
	closeButton.BackgroundTransparency = 1
	closeButton.Text = "X"
	closeButton.TextColor3 = cols.textMuted
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 12
	closeButton:SetAttribute("ThemeRole", "TextColor")
	closeButton.Parent = headerFrame

	closeButton.MouseButton1Click:Connect(function()
		ReverbPanel.ToggleMenu(false)
	end)

	if UIUtils.MakeDraggable then
		UIUtils.MakeDraggable(reverbWindow, headerFrame)
	end

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -12, 1, -38)
	scroll.Position = UDim2.new(0, 6, 0, 34)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = cols.secBg
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.Parent = reverbWindow

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scroll

	-- Presets Container
	presetsContainer = Instance.new("Frame")
	presetsContainer.Name = "PresetsFrame"
	presetsContainer.Size = UDim2.new(1, 0, 0, 0)
	presetsContainer.AutomaticSize = Enum.AutomaticSize.Y
	presetsContainer.BackgroundColor3 = cols.secBg
	presetsContainer:SetAttribute("ThemeRole", "SecondaryBackground")
	presetsContainer.Parent = scroll
	if UIUtils.CreateCorner then UIUtils.CreateCorner(presetsContainer, 6) end

	local presetGrid = Instance.new("UIGridLayout")
	presetGrid.CellSize = UDim2.new(0, 64, 0, 24)
	presetGrid.CellPadding = UDim2.new(0, 4, 0, 4)
	presetGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	presetGrid.Parent = presetsContainer

	local presetPadding = Instance.new("UIPadding")
	presetPadding.PaddingTop = UDim.new(0, 4)
	presetPadding.PaddingBottom = UDim.new(0, 4)
	presetPadding.PaddingLeft = UDim.new(0, 4)
	presetPadding.PaddingRight = UDim.new(0, 4)
	presetPadding.Parent = presetsContainer

	-- Enable Toggle Row
	toggleRowFrame = Instance.new("Frame")
	toggleRowFrame.Size = UDim2.new(1, 0, 0, 32)
	toggleRowFrame.BackgroundColor3 = cols.secBg
	toggleRowFrame:SetAttribute("ThemeRole", "SecondaryBackground")
	toggleRowFrame.Parent = scroll
	if UIUtils.CreateCorner then UIUtils.CreateCorner(toggleRowFrame, 6) end

	toggleLabelText = Instance.new("TextLabel")
	toggleLabelText.Size = UDim2.new(0.6, 0, 1, 0)
	toggleLabelText.Position = UDim2.new(0, 8, 0, 0)
	toggleLabelText.BackgroundTransparency = 1
	toggleLabelText.Text = "enabled"
	toggleLabelText.TextColor3 = cols.text
	toggleLabelText.Font = Enum.Font.GothamBold
	toggleLabelText.TextSize = 11
	toggleLabelText.TextXAlignment = Enum.TextXAlignment.Left
	toggleLabelText:SetAttribute("ThemeRole", "TextColor")
	toggleLabelText.Parent = toggleRowFrame

	enableButton = Instance.new("TextButton")
	enableButton.Size = UDim2.new(0, 40, 0, 20)
	enableButton.Position = UDim2.new(1, -46, 0.5, -10)
	enableButton.BackgroundColor3 = cols.bg
	enableButton.Text = "OFF"
	enableButton.TextColor3 = cols.textMuted
	enableButton.Font = Enum.Font.GothamBold
	enableButton.TextSize = 10
	enableButton:SetAttribute("ThemeRole", "ButtonBackground")
	enableButton.Parent = toggleRowFrame
	if UIUtils.CreateCorner then UIUtils.CreateCorner(enableButton, 10) end

	enableButton.MouseButton1Click:Connect(function()
		setEnableState(not isEnabled)
	end)

	local function handleSliderChange(prop, val)
		currentSettings[prop] = val
		if onChangeCallback then
			onChangeCallback(prop, val)
		end
	end

	-- Create Sliders
	sliderUpdaters["Priority"]  = UIUtils.CreateSliderRow(scroll, "Priority", "priority", 0, 10, currentSettings.Priority, false, function(_, val) handleSliderChange("Priority", val) end)
	sliderUpdaters["DecayTime"] = UIUtils.CreateSliderRow(scroll, "DecayTime", "decay", 0.1, 20, currentSettings.DecayTime, true, function(_, val) handleSliderChange("DecayTime", val) end)
	sliderUpdaters["Density"]   = UIUtils.CreateSliderRow(scroll, "Density", "density", 0, 1, currentSettings.Density, true, function(_, val) handleSliderChange("Density", val) end)
	sliderUpdaters["Diffusion"] = UIUtils.CreateSliderRow(scroll, "Diffusion", "diffusion", 0, 1, currentSettings.Diffusion, true, function(_, val) handleSliderChange("Diffusion", val) end)
	sliderUpdaters["DryLevel"]  = UIUtils.CreateSliderRow(scroll, "DryLevel", "dryness", -80, 20, currentSettings.DryLevel, true, function(_, val) handleSliderChange("DryLevel", val) end)
	sliderUpdaters["WetLevel"]  = UIUtils.CreateSliderRow(scroll, "WetLevel", "wetness", -80, 20, currentSettings.WetLevel, true, function(_, val) handleSliderChange("WetLevel", val) end)

	-- Apply Preset Data across controls
	local function applyPreset(presetData)
		if not isEnabled then setEnableState(true) end
		for propName, val in pairs(presetData) do
			if sliderUpdaters[propName] then
				sliderUpdaters[propName](val, true)
				currentSettings[propName] = val
				if onChangeCallback then
					onChangeCallback(propName, val)
				end
			end
		end
	end

	-- Populate Static Preset Buttons
	for _, pName in ipairs({ "Room", "Hall", "Cathedral" }) do
		local btn = Instance.new("TextButton")
		btn.Name = pName .. "PresetBtn"
		btn.BackgroundColor3 = cols.bg
		btn.Text = pName
		btn.TextColor3 = cols.text
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 10
		btn:SetAttribute("ThemeRole", "ButtonBackground")
		btn.Parent = presetsContainer
		if UIUtils.CreateCorner then UIUtils.CreateCorner(btn, 4) end

		btn.MouseButton1Click:Connect(function()
			applyPreset(PRESETS[pName])
		end)
	end

	-- Custom Preset Card with Deletion
	local function createCustomPresetButton(pName, pData)
		local btn = Instance.new("TextButton")
		btn.Name = "CustomPreset_" .. pName
		btn.BackgroundColor3 = cols.bg
		btn.Text = pName
		btn.TextColor3 = Color3.fromRGB(241, 196, 15)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 9
		btn.TextTruncate = Enum.TextTruncate.AtEnd
		btn:SetAttribute("ThemeRole", "ButtonBackground")
		btn.Parent = presetsContainer
		if UIUtils.CreateCorner then UIUtils.CreateCorner(btn, 4) end

		btn.MouseButton1Click:Connect(function()
			applyPreset(pData)
		end)

		local deleteBtn = Instance.new("TextButton")
		deleteBtn.Name = "DeleteBtn"
		deleteBtn.Size = UDim2.new(0, 12, 0, 12)
		deleteBtn.Position = UDim2.new(1, -13, 0, 1)
		deleteBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
		deleteBtn.Text = "x"
		deleteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		deleteBtn.Font = Enum.Font.GothamBold
		deleteBtn.TextSize = 8
		deleteBtn.Parent = btn
		if UIUtils.CreateCorner then UIUtils.CreateCorner(deleteBtn, 3) end

		deleteBtn.MouseButton1Click:Connect(function()
			customPresets[pName] = nil
			btn:Destroy()
			if deleteRemote then
				deleteRemote:FireServer(pName)
			end
		end)
	end

	-- Save (+) Button
	addPresetBtn = Instance.new("TextButton")
	addPresetBtn.Name = "AddPresetBtn"
	addPresetBtn.BackgroundColor3 = cols.accent
	addPresetBtn.Text = "+"
	addPresetBtn.TextColor3 = cols.text
	addPresetBtn.Font = Enum.Font.GothamBold
	addPresetBtn.TextSize = 14
	addPresetBtn.Parent = presetsContainer
	if UIUtils.CreateCorner then UIUtils.CreateCorner(addPresetBtn, 4) end

	-- Save Modal Dialog
	saveModalFrame = Instance.new("Frame")
	saveModalFrame.Name = "SavePresetModal"
	saveModalFrame.Size = UDim2.new(0, 170, 0, 90)
	saveModalFrame.Position = UDim2.new(0.5, -85, 0.5, -45)
	saveModalFrame.BackgroundColor3 = cols.bg
	saveModalFrame.Visible = false
	saveModalFrame:SetAttribute("ThemeRole", "CardBackground")
	saveModalFrame.Parent = reverbWindow
	if UIUtils.CreateCorner then UIUtils.CreateCorner(saveModalFrame, 6) end
	if UIUtils.CreateStroke then UIUtils.CreateStroke(saveModalFrame) end

	modalInputBox = Instance.new("TextBox")
	modalInputBox.Size = UDim2.new(1, -16, 0, 26)
	modalInputBox.Position = UDim2.new(0, 8, 0, 12)
	modalInputBox.BackgroundColor3 = cols.secBg
	modalInputBox.PlaceholderText = "Preset Name..."
	modalInputBox.Text = ""
	modalInputBox.TextColor3 = cols.text
	modalInputBox.Font = Enum.Font.GothamBold
	modalInputBox.TextSize = 11
	modalInputBox:SetAttribute("ThemeRole", "SecondaryBackground")
	modalInputBox.Parent = saveModalFrame
	if UIUtils.CreateCorner then UIUtils.CreateCorner(modalInputBox, 4) end

	confirmSaveBtn = Instance.new("TextButton")
	confirmSaveBtn.Size = UDim2.new(0.45, 0, 0, 24)
	confirmSaveBtn.Position = UDim2.new(0.05, 0, 1, -30)
	confirmSaveBtn.BackgroundColor3 = cols.accent
	confirmSaveBtn.Text = "Save"
	confirmSaveBtn.TextColor3 = cols.text
	confirmSaveBtn.Font = Enum.Font.GothamBold
	confirmSaveBtn.TextSize = 10
	confirmSaveBtn.Parent = saveModalFrame
	if UIUtils.CreateCorner then UIUtils.CreateCorner(confirmSaveBtn, 4) end

	cancelSaveBtn = Instance.new("TextButton")
	cancelSaveBtn.Size = UDim2.new(0.45, 0, 0, 24)
	cancelSaveBtn.Position = UDim2.new(0.5, 0, 1, -30)
	cancelSaveBtn.BackgroundColor3 = cols.bg
	cancelSaveBtn.Text = "Cancel"
	cancelSaveBtn.TextColor3 = cols.textMuted
	cancelSaveBtn.Font = Enum.Font.GothamBold
	cancelSaveBtn.TextSize = 10
	cancelSaveBtn:SetAttribute("ThemeRole", "ButtonBackground")
	cancelSaveBtn.Parent = saveModalFrame
	if UIUtils.CreateCorner then UIUtils.CreateCorner(cancelSaveBtn, 4) end

	addPresetBtn.MouseButton1Click:Connect(function()
		saveModalFrame.Visible = true
		modalInputBox.Text = ""
		modalInputBox:CaptureFocus()
	end)

	cancelSaveBtn.MouseButton1Click:Connect(function()
		saveModalFrame.Visible = false
	end)

	confirmSaveBtn.MouseButton1Click:Connect(function()
		local name = modalInputBox.Text:gsub("%s+", "")
		if #name > 0 and #name <= 10 then
			local presetData = {}
			for k, v in pairs(currentSettings) do presetData[k] = v end

			local existing = presetsContainer:FindFirstChild("CustomPreset_" .. name)
			if existing then existing:Destroy() end

			customPresets[name] = presetData
			createCustomPresetButton(name, presetData)

			addPresetBtn.Parent = nil
			addPresetBtn.Parent = presetsContainer

			if saveRemote then
				saveRemote:FireServer(name, presetData)
			end
			saveModalFrame.Visible = false
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
				addPresetBtn.Parent = nil
				addPresetBtn.Parent = presetsContainer
			end
		end)
	end

	ReverbPanel.ApplyTheme()
end

-- Toggles visibility of the pop-out window
function ReverbPanel.ToggleMenu(overrideState)
	isOpen = (overrideState ~= nil) and overrideState or not isOpen
	if reverbWindow then
		reverbWindow.Visible = isOpen
	end
	if not isOpen and saveModalFrame then
		saveModalFrame.Visible = false
	end

	if reverbButton then
		local cols = getResolvedColors()
		local targetColor = isOpen and cols.accent or cols.bg
		local targetTextColor = isOpen and cols.text or cols.textMuted

		TweenService:Create(reverbButton, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = targetColor,
			TextColor3 = targetTextColor
		}):Play()
	end
end

-- ============================================================================
-- Dynamic Theme Engine Integration
-- ============================================================================

function ReverbPanel.ApplyTheme(theme)
	if type(theme) == "table" then
		currentTheme = theme
	end

	local cols = getResolvedColors()

	if reverbButton and not isOpen then
		reverbButton.BackgroundColor3 = cols.bg
		reverbButton.TextColor3 = cols.textMuted
	elseif reverbButton and isOpen then
		reverbButton.BackgroundColor3 = cols.accent
		reverbButton.TextColor3 = cols.text
	end

	if reverbWindow then
		reverbWindow.BackgroundColor3 = cols.bg
		local stroke = reverbWindow:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Color = cols.stroke end
	end

	if headerFrame then headerFrame.BackgroundColor3 = cols.secBg end
	if headerTitleLabel then headerTitleLabel.TextColor3 = cols.text end
	if closeButton then closeButton.TextColor3 = cols.textMuted end
	if presetsContainer then presetsContainer.BackgroundColor3 = cols.secBg end
	if toggleRowFrame then toggleRowFrame.BackgroundColor3 = cols.secBg end
	if toggleLabelText then toggleLabelText.TextColor3 = cols.text end

	setEnableState(isEnabled)

	if presetsContainer then
		for _, child in ipairs(presetsContainer:GetChildren()) do
			if child:IsA("TextButton") then
				if child.Name:find("PresetBtn") and not child.Name:find("CustomPreset") then
					child.BackgroundColor3 = cols.bg
					child.TextColor3 = cols.text
				elseif child.Name:find("CustomPreset") then
					child.BackgroundColor3 = cols.bg
				end
			end
		end
	end

	if addPresetBtn then
		addPresetBtn.BackgroundColor3 = cols.accent
		addPresetBtn.TextColor3 = cols.text
	end

	if saveModalFrame then
		saveModalFrame.BackgroundColor3 = cols.bg
		local modalStroke = saveModalFrame:FindFirstChildOfClass("UIStroke")
		if modalStroke then modalStroke.Color = cols.stroke end
	end

	if modalInputBox then
		modalInputBox.BackgroundColor3 = cols.secBg
		modalInputBox.TextColor3 = cols.text
	end

	if confirmSaveBtn then
		confirmSaveBtn.BackgroundColor3 = cols.accent
		confirmSaveBtn.TextColor3 = cols.text
	end

	if cancelSaveBtn then
		cancelSaveBtn.BackgroundColor3 = cols.bg
		cancelSaveBtn.TextColor3 = cols.textMuted
	end
end

ReverbPanel.UpdateTheme = ReverbPanel.ApplyTheme
ReverbPanel.RefreshTheme = ReverbPanel.ApplyTheme

return ReverbPanel