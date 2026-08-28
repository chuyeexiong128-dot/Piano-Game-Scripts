local PianoUI = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyFolder = ReplicatedStorage:WaitForChild("Economy")
local ShopData = EconomyFolder:WaitForChild("ShopData")
local CustomizationData = require(ShopData:WaitForChild("CustomizationData"))
local SustainButton = require(script.SustainButton)
local TransposeControl = require(script.TransposeControl)
local ReverbPanel = require(script.ReverbPanel)
local VelocityControl = require(script.VelocityControl)
local SheetMusicPanel = require(script:WaitForChild("SheetMusicPanel"))
local CommunitySheetsPanel = require(script:WaitForChild("CommunitySheetsPanel"))

local pianoModulesFolder = script.Parent
local MultiTransposePanel = require(script:WaitForChild("MultiTransposePanel"))
local MultiTransposeController = require(pianoModulesFolder:WaitForChild("MultiTransposeController"))

local SoundfontPanel = require(script.SoundfontPanel)
local OnscreenPiano = require(script.OnscreenPiano)
local UIUtils = require(script.UIUtils)
local ThemeManager = require(script.Parent:WaitForChild("ThemeManager"))

local screenGui = nil
local communityPanel = nil
local highestZIndex = 20

local keyFramesByNoteIndex = {}
local currentTheme = nil
PianoUI.CurrentKeyTheme = CustomizationData.ColorThemes["Classic Black & White"]

local soundfontBtnRef = nil
local sheetsBtnRef = nil
local isSoundfontOpen = false
local isSheetsOpen = false

local function bringToFront(window)
	highestZIndex += 10
	window.ZIndex = highestZIndex
end

-- Tag single UI element dynamically
local function tagSingleElement(obj, rootGui)
	if obj:GetAttribute("ThemeRole") then return end

	if obj:IsA("TextLabel") or obj:IsA("TextBox") then
		obj:SetAttribute("ThemeRole", "TextColor")
	elseif obj:IsA("TextButton") or obj:IsA("ImageButton") then
		obj:SetAttribute("ThemeRole", "ButtonBackground")
	elseif obj:IsA("Frame") or obj:IsA("ScrollingFrame") then
		if obj.BackgroundTransparency < 1 then
			if obj.Parent == rootGui or obj.Name:find("Panel") or obj.Name:find("Container") or obj.Name:find("Window") then
				obj:SetAttribute("ThemeRole", "CardBackground")
			else
				obj:SetAttribute("ThemeRole", "SecondaryBackground")
			end
		end
	elseif obj:IsA("UIStroke") then
		obj:SetAttribute("ThemeRole", "STROKE_COLOR")
	end
end

local function tagPanelThemeRoles(rootGui)
	if not rootGui then return end
	for _, obj in ipairs(rootGui:GetDescendants()) do
		tagSingleElement(obj, rootGui)
	end
end

local function getButtonTargetColors(isOpen, isHovered)
	local C = UIUtils.Colors
	local baseOffColor = (currentTheme and (currentTheme.CardBackground or currentTheme.MainBackground or currentTheme.Background)) or C.COLOR_OFF
	local textColor = (currentTheme and currentTheme.TextColor) or C.TEXT_OFF

	if isOpen then
		local accent = currentTheme and (currentTheme.AccentColor or currentTheme.Accent)
		return accent or Color3.fromRGB(48, 48, 58), (currentTheme and currentTheme.TextColor) or C.TEXT_ON
	else
		return isHovered and Color3.fromRGB(52, 52, 64) or baseOffColor, textColor
	end
end

local function animateButtonVisual(btn, isOpen, isHovered, duration)
	if not btn then return end
	local targetBg, targetText = getButtonTargetColors(isOpen, isHovered)
	local animTime = (type(duration) == "number") and duration or 0.20
	local tweenInfo = TweenInfo.new(animTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(btn, tweenInfo, { BackgroundColor3 = targetBg, TextColor3 = targetText }):Play()
end

local function resolveUIPreset(presetName)
	if type(presetName) == "table" then
		return presetName
	end

	if not presetName or presetName == "" or presetName == "Default" or presetName == "None" then
		if CustomizationData and CustomizationData.UIPresets then
			return CustomizationData.UIPresets["Default"] or CustomizationData.UIPresets["Classic Black & White"]
		end
		return nil
	end

	if CustomizationData and CustomizationData.GetItemData then
		local item = CustomizationData.GetItemData("UIPresets", presetName)
		if item then return item end
	end

	if CustomizationData and CustomizationData.UIPresets then
		if CustomizationData.UIPresets[presetName] then
			return CustomizationData.UIPresets[presetName]
		end

		local cleanSearch = tostring(presetName):gsub("%s+", ""):lower()
		for key, data in pairs(CustomizationData.UIPresets) do
			local cleanKey = tostring(key):gsub("%s+", ""):lower()
			local cleanName = (type(data) == "table" and (data.Name or data.Id or data.PresetName) and tostring(data.Name or data.Id or data.PresetName):gsub("%s+", ""):lower()) or ""
			if cleanKey == cleanSearch or cleanName == cleanSearch then
				return data
			end
		end
	end

	return currentTheme
end

function PianoUI.ApplyTheme(presetName)
	local theme = resolveUIPreset(presetName)

	if theme then
		currentTheme = theme
	end

	if type(UIUtils.ApplyTheme) == "function" then
		pcall(function() UIUtils.ApplyTheme(currentTheme) end)
	end

	isSoundfontOpen = (SoundfontPanel.IsOpen and SoundfontPanel.IsOpen()) or isSoundfontOpen
	isSheetsOpen = (SheetMusicPanel.IsOpen and SheetMusicPanel.IsOpen()) or isSheetsOpen

	if soundfontBtnRef then
		animateButtonVisual(soundfontBtnRef, isSoundfontOpen, soundfontBtnRef:GetAttribute("IsHovered") or false, 0.15)
	end
	if sheetsBtnRef then
		animateButtonVisual(sheetsBtnRef, isSheetsOpen, sheetsBtnRef:GetAttribute("IsHovered") or false, 0.15)
	end
end

function PianoUI.ApplyKeyTheme(presetName)
	local keyTheme = nil
	if CustomizationData and CustomizationData.ColorThemes then
		keyTheme = CustomizationData.ColorThemes[presetName]
		if not keyTheme then
			local cleanSearch = tostring(presetName):gsub("%s+", ""):lower()
			for k, v in pairs(CustomizationData.ColorThemes) do
				if tostring(k):gsub("%s+", ""):lower() == cleanSearch then
					keyTheme = v
					break
				end
			end
		end
	end

	keyTheme = keyTheme or PianoUI.CurrentKeyTheme or CustomizationData.ColorThemes["Default"] or CustomizationData.ColorThemes["Classic Black & White"]

	if keyTheme then
		PianoUI.CurrentKeyTheme = keyTheme
		local white = keyTheme.PressedWhite or keyTheme.WhiteKeyPressed or keyTheme.WhiteKeyHighlight
		local black = keyTheme.PressedBlack or keyTheme.BlackKeyPressed or keyTheme.BlackKeyHighlight
		if white and black then
			PianoUI.SetHighlightColors(white, black)
		end
	end
end

function PianoUI.SetHighlightColors(whitePressed, blackPressed)
	if OnscreenPiano and OnscreenPiano.SetHighlightColors then
		OnscreenPiano.SetHighlightColors(whitePressed, blackPressed)
	end
end

function PianoUI.ApplyKeyHighlight(presetName)
	PianoUI.ApplyKeyTheme(presetName)
end

local function setupAttributeListeners()
	local lastAppliedPreset = nil

	local function handleThemeChange()
		local preset = player:GetAttribute("EquippedUIPreset") 
			or player:GetAttribute("EquippedUITheme") 
			or player:GetAttribute("EquippedTheme")

		if preset and preset ~= lastAppliedPreset then
			lastAppliedPreset = preset
			PianoUI.ApplyTheme(preset)
		end
	end

	local function handleKeyThemeChange()
		local keyTheme = player:GetAttribute("EquippedKeyColor")
		if keyTheme then
			PianoUI.ApplyKeyTheme(keyTheme)
		end
	end

	player.AttributeChanged:Connect(function(attributeName)
		if attributeName == "EquippedUIPreset" or attributeName == "EquippedUITheme" or attributeName == "EquippedTheme" then
			handleThemeChange()
		elseif attributeName == "EquippedKeyColor" then
			handleKeyThemeChange()
		end
	end)

	if ThemeManager then
		local themeSignal = ThemeManager.OnThemeChanged or ThemeManager.ThemeChanged
		if typeof(themeSignal) == "RBXScriptSignal" then
			themeSignal:Connect(function(newTheme)
				if newTheme and newTheme ~= lastAppliedPreset then
					lastAppliedPreset = newTheme
					PianoUI.ApplyTheme(newTheme)
				end
			end)
		end
	end

	handleThemeChange()
	handleKeyThemeChange()
end

local function setupFocusManager()
	UserInputService.InputBegan:Connect(function(input)
		if not screenGui then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local objects = playerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)
		for _, guiObj in ipairs(objects) do
			if guiObj:IsDescendantOf(screenGui) then
				local rootWindow = guiObj
				while rootWindow.Parent and rootWindow.Parent ~= screenGui do
					rootWindow = rootWindow.Parent
				end
				if rootWindow and rootWindow:IsA("GuiObject") and rootWindow.Name ~= "ControlContainer" then
					bringToFront(rootWindow)
					break
				end
			end
		end
	end)
end

local function setupToggleButtonAnimations(btn, getIsOpenState)
	btn.AutoButtonColor = false
	btn.MouseEnter:Connect(function()
		btn:SetAttribute("IsHovered", true)
		animateButtonVisual(btn, getIsOpenState(), true, 0.15)
	end)
	btn.MouseLeave:Connect(function()
		btn:SetAttribute("IsHovered", false)
		animateButtonVisual(btn, getIsOpenState(), false, 0.20)
	end)
	btn.MouseButton1Down:Connect(function()
		local tweenInfo = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(btn, tweenInfo, { BackgroundColor3 = Color3.fromRGB(65, 65, 80), TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
	end)
	btn.MouseButton1Up:Connect(function()
		animateButtonVisual(btn, getIsOpenState(), btn:GetAttribute("IsHovered") or false, 0.15)
	end)
end

function PianoUI.Init(sustainCallback, transposeCallback, reverbCallback, noteCallback, pianoSoundsFolder, soundfontCallback)
	if screenGui then
		screenGui.Enabled = true
		return
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PianoGui"
	screenGui:SetAttribute("IsPianoUI", true)
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	if ThemeManager then
		ThemeManager.CurrentGui = screenGui
	end

	screenGui.DescendantAdded:Connect(function(descendant)
		if currentTheme then
			tagSingleElement(descendant, screenGui)
			if ThemeManager and type(ThemeManager.ApplyTheme) == "function" then
				ThemeManager.ApplyTheme(descendant, currentTheme, true)
			end
		end
	end)

	setupFocusManager()

	local container = Instance.new("Frame")
	container.Name = "ControlContainer"
	container.Size = UDim2.new(0, 150, 0, 220)
	container.Position = UDim2.new(0, 20, 0.5, -110)
	container.BackgroundTransparency = 1
	container.Active = true
	container.ZIndex = 5
	container:SetAttribute("ThemeRole", "MainColor")
	container.Parent = screenGui

	ReverbPanel.Init(screenGui, container, reverbCallback)
	SustainButton.Init(container, sustainCallback)
	TransposeControl.Init(container, transposeCallback)
	VelocityControl.Init(screenGui)
	OnscreenPiano.Init(screenGui, noteCallback)
	SoundfontPanel.Init(screenGui, container, pianoSoundsFolder, soundfontCallback)

	-- MultiTranspose Integration & Sync
	MultiTransposePanel.Init(screenGui)

	local isSyncing = false

	MultiTransposePanel.SetOnTransposeChanged(function(activeValue)
		if isSyncing then return end
		isSyncing = true
		TransposeControl.Set(activeValue)
		isSyncing = false
	end)

	MultiTransposeController.OnTransposeChanged = function(activeValue, currentIndex, queue)
		if isSyncing then return end
		isSyncing = true

		TransposeControl.Set(activeValue)

		if #queue > 0 then
			MultiTransposePanel.SetTransposes(queue)
			for _ = 2, currentIndex do
				MultiTransposePanel.Next()
			end
		end

		isSyncing = false
	end

	local panelFrame = screenGui:FindFirstChild("MultiTransposePanel")
	if panelFrame then
		local textBox = panelFrame:FindFirstChild("SequenceInput")
		if textBox then
			textBox.FocusLost:Connect(function()
				MultiTransposeController.SetSequence(textBox.Text)
			end)
		end
	end

	if SheetMusicPanel.SetMultiTransposeCallback then
		SheetMusicPanel.SetMultiTransposeCallback(function()
			MultiTransposePanel.ToggleMenu()
		end)
	end

	-- Initialize SheetMusicPanel (which instantiates and manages CommunitySheetsPanel internally)
	SheetMusicPanel.Init(screenGui)

	if SheetMusicPanel.SetOnTransposeChanged then
		SheetMusicPanel.SetOnTransposeChanged(function(activeValue, index, sequenceTable)
			PianoUI.SetTranspose(activeValue)
			if sequenceTable and #sequenceTable > 0 then
				MultiTransposePanel.SetTransposes(sequenceTable)
				MultiTransposePanel.SetVisible(true)
				MultiTransposeController.SetSequence(table.concat(sequenceTable, ", "))
			end
		end)
	end

	local C = UIUtils.Colors

	soundfontBtnRef = Instance.new("TextButton")
	soundfontBtnRef.Name = "SoundfontButton"
	soundfontBtnRef.Size = UDim2.new(1, 0, 0, 32)
	soundfontBtnRef.Position = UDim2.new(0, 0, 1, -70)
	soundfontBtnRef.BackgroundColor3 = C.COLOR_OFF
	soundfontBtnRef.Text = "SOUNDFONT"
	soundfontBtnRef.TextColor3 = C.TEXT_OFF
	soundfontBtnRef.Font = Enum.Font.GothamBold
	soundfontBtnRef.TextSize = 12
	soundfontBtnRef:SetAttribute("ThemeRole", "ButtonBackground")
	soundfontBtnRef.Parent = container
	UIUtils.CreateCorner(soundfontBtnRef, 6)

	setupToggleButtonAnimations(soundfontBtnRef, function()
		return (SoundfontPanel.IsOpen and SoundfontPanel.IsOpen()) or isSoundfontOpen
	end)
	soundfontBtnRef.MouseButton1Click:Connect(function() PianoUI.ToggleSoundfontMenu() end)

	sheetsBtnRef = Instance.new("TextButton")
	sheetsBtnRef.Name = "SheetsButton"
	sheetsBtnRef.Size = UDim2.new(1, 0, 0, 32)
	sheetsBtnRef.Position = UDim2.new(0, 0, 1, -32)
	sheetsBtnRef.BackgroundColor3 = C.COLOR_OFF
	sheetsBtnRef.Text = "SHEETS"
	sheetsBtnRef.TextColor3 = C.TEXT_OFF
	sheetsBtnRef.Font = Enum.Font.GothamBold
	sheetsBtnRef.TextSize = 12
	sheetsBtnRef:SetAttribute("ThemeRole", "ButtonBackground")
	sheetsBtnRef.Parent = container
	UIUtils.CreateCorner(sheetsBtnRef, 6)

	setupToggleButtonAnimations(sheetsBtnRef, function()
		return (SheetMusicPanel.IsOpen and SheetMusicPanel.IsOpen()) or isSheetsOpen
	end)
	sheetsBtnRef.MouseButton1Click:Connect(function() PianoUI.ToggleSheetMenu() end)

	setupAttributeListeners()
end

function PianoUI.SetKeyVisualState(noteIndex, isPressed, customTheme)
	if OnscreenPiano and OnscreenPiano.SetKeyVisualState then
		OnscreenPiano.SetKeyVisualState(noteIndex, isPressed)
		return
	end

	local theme = customTheme or PianoUI.CurrentKeyTheme or {
		PressedWhite = Color3.fromRGB(180, 210, 255),
		PressedBlack = Color3.fromRGB(80, 120, 200)
	}

	local keyFrame = keyFramesByNoteIndex[noteIndex]
	if not keyFrame then
		if OnscreenPiano and OnscreenPiano.GetKeyFrame then
			keyFrame = OnscreenPiano.GetKeyFrame(noteIndex)
		elseif OnscreenPiano and OnscreenPiano.GetKey then
			keyFrame = OnscreenPiano.GetKey(noteIndex)
		else
			local activeGui = screenGui or playerGui:FindFirstChild("PianoGui")
			if activeGui then
				for _, child in ipairs(activeGui:GetDescendants()) do
					if child:GetAttribute("NoteIndex") == noteIndex or child.Name == "Key_" .. tostring(noteIndex) or child.Name == tostring(noteIndex) then
						keyFrame = child
						break
					end
				end
			end
		end

		if keyFrame then
			keyFramesByNoteIndex[noteIndex] = keyFrame
		end
	end

	if not keyFrame then return end

	local isBlackKey = keyFrame:GetAttribute("IsBlackKey") or (keyFrame.Name:find("#") ~= nil)
	if isPressed then
		keyFrame.BackgroundColor3 = isBlackKey and (theme.PressedBlack or Color3.fromRGB(80, 120, 200)) or (theme.PressedWhite or Color3.fromRGB(180, 210, 255))
	else
		keyFrame.BackgroundColor3 = isBlackKey and Color3.fromRGB(35, 35, 40) or Color3.fromRGB(255, 255, 255)
	end
end

function PianoUI.ToggleOnscreenPiano(overrideState) OnscreenPiano.ToggleExpanded(overrideState) end
function PianoUI.ProcessNoteStrike(noteIndex) return VelocityControl.ProcessNoteStrike(noteIndex) end

function PianoUI.ToggleSoundfontMenu(overrideState)
	local targetState = (overrideState ~= nil) and overrideState or not isSoundfontOpen
	if targetState then
		if SheetMusicPanel.IsOpen and SheetMusicPanel.IsOpen() then
			SheetMusicPanel.ToggleMenu(false)
			isSheetsOpen = false
			if sheetsBtnRef then
				animateButtonVisual(sheetsBtnRef, false, sheetsBtnRef:GetAttribute("IsHovered") or false, 0.20)
			end
		end
	end

	if type(SoundfontPanel.ToggleMenu) == "function" then
		SoundfontPanel.ToggleMenu(targetState)
	elseif type(SoundfontPanel.SetVisible) == "function" then
		SoundfontPanel.SetVisible(targetState)
	end

	isSoundfontOpen = (SoundfontPanel.IsOpen and SoundfontPanel.IsOpen()) or targetState
	if soundfontBtnRef then
		animateButtonVisual(soundfontBtnRef, isSoundfontOpen, soundfontBtnRef:GetAttribute("IsHovered") or false, 0.20)
	end
end

function PianoUI.ToggleSheetMenu(overrideState)
	local targetState = (overrideState ~= nil) and overrideState or not isSheetsOpen
	if targetState then
		if SoundfontPanel.IsOpen and SoundfontPanel.IsOpen() then
			SoundfontPanel.ToggleMenu(false)
			isSoundfontOpen = false
			if soundfontBtnRef then
				animateButtonVisual(soundfontBtnRef, false, soundfontBtnRef:GetAttribute("IsHovered") or false, 0.20)
			end
		end
	end

	SheetMusicPanel.ToggleMenu(targetState)
	isSheetsOpen = (SheetMusicPanel.IsOpen and SheetMusicPanel.IsOpen()) or targetState
	if sheetsBtnRef then
		animateButtonVisual(sheetsBtnRef, isSheetsOpen, sheetsBtnRef:GetAttribute("IsHovered") or false, 0.20)
	end
end

function PianoUI.ToggleMultiTranspose(overrideState)
	MultiTransposePanel.ToggleMenu(overrideState)
end
PianoUI.ToggleMultiTransposeManager = PianoUI.ToggleMultiTranspose

function PianoUI.ToggleReverbMenu(overrideState) ReverbPanel.ToggleMenu(overrideState) end
function PianoUI.ProcessAltScroll() SheetMusicPanel.ProcessAltScroll() end
function PianoUI.SetSustainState(enabled) SustainButton.SetState(enabled) end
function PianoUI.ToggleSustain() SustainButton.Toggle() end
function PianoUI.IsSustainOn() return SustainButton.IsActive() end
function PianoUI.SetTranspose(shift) TransposeControl.Set(shift) end
function PianoUI.ChangeTranspose(delta) TransposeControl.Change(delta) end
function PianoUI.GetTranspose() return TransposeControl.Get() end
function PianoUI.SetVisible(visible) if screenGui then screenGui.Enabled = visible end end

return PianoUI