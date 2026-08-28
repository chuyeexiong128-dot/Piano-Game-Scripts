local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local EconomyFolder = ReplicatedStorage:WaitForChild("Economy")
local ShopData = ReplicatedStorage:WaitForChild("Economy"):WaitForChild("ShopData")
local CustomizationData = require(ShopData:WaitForChild("CustomizationData"))

local pianoModules = ReplicatedStorage:WaitForChild("PianoModules")
local pianoRemotes = ReplicatedStorage:WaitForChild("PianoRemotes")
local PianoNoteEvent = pianoRemotes:WaitForChild("PianoNoteEvent")
local pianoSounds = ReplicatedStorage:WaitForChild("PianoSounds")
local MultiTransposeController = require(pianoModules:WaitForChild("MultiTransposeController"))

local economyRemotes = ReplicatedStorage:WaitForChild("EconomyRemotes")
local EarnCurrencyRemote = economyRemotes:WaitForChild("EarnCurrencyRemote")

local PianoConfig = require(pianoModules:WaitForChild("PianoConfig"))
local AudioEngine = require(pianoModules:WaitForChild("AudioEngine"))
local SeatManager = require(pianoModules:WaitForChild("SeatManager"))
local VisualEffectsManager = require(pianoModules:WaitForChild("VisualEffectsManager"))

local pianoUIFolder = pianoModules:WaitForChild("PianoUI")
local PianoUI = require(pianoUIFolder)
local sheetMusicFolder = pianoUIFolder:WaitForChild("SheetMusicPanel")
local SheetMusicPanel = require(sheetMusicFolder)

local PianoController = {}

function PianoController.Init()
	-- Modifiers & Input State
	local isCtrlHeld = false
	local isShiftHeld = false
	local currentPianoModel = nil
	local physicallyPressedKeys = {}
	local activeNotesByKeyCode = {}

	-- Track keys sunk by ContextActionService for Piano Shortcuts
	local lastSunkTime = 0
	local lastSunkKeyCode = nil

	-- Real-time modifier state checker
	local function checkIsCtrlHeld()
		return isCtrlHeld 
			or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) 
			or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
	end

	local function checkIsShiftHeld()
		return isShiftHeld 
			or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) 
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	end

	-- Dynamic Theme Highlight State
	local currentThemeHighlight = {
		PressedWhite = Color3.fromRGB(180, 210, 255),
		PressedBlack = Color3.fromRGB(80, 120, 200),
	}

	-- Helper to extract colors regardless of attribute naming
	local function extractColorsFromTheme(themeData)
		if not themeData then return nil, nil end

		local whiteColor = themeData.PressedWhite 
			or themeData.WhiteKeyHighlight 
			or themeData.WhiteKeyColor 
			or themeData.WhiteKey 
			or themeData.White 
			or themeData.Primary 
			or themeData.Color

		local blackColor = themeData.PressedBlack 
			or themeData.BlackKeyHighlight 
			or themeData.BlackKeyColor 
			or themeData.BlackKey 
			or themeData.Black 
			or themeData.Secondary

		return whiteColor, blackColor
	end

	-- Helper to fetch theme data with fallbacks
	local function getEquippedThemeData()
		local equippedId = player:GetAttribute("EquippedKeyColor") 
			or player:GetAttribute("EquippedPianoTheme") 
			or player:GetAttribute("EquippedColorTheme") 
			or player:GetAttribute("EquippedTheme")
			or "Black&White"

		local themeData = CustomizationData.GetItemData("Piano Color Themes!", equippedId)

		if not themeData then
			local cleanId = tostring(equippedId):gsub("^Highl_", ""):gsub("([a-z])([A-Z])", "%1 %2")
			themeData = CustomizationData.GetItemData("Piano Color Themes!", cleanId)
		end

		return themeData
	end

	-- Update key highlight colors from CustomizationData
	local function updateActiveThemeColors()
		local themeData = getEquippedThemeData()

		if themeData then
			local white, black = extractColorsFromTheme(themeData)
			if white then currentThemeHighlight.PressedWhite = white end
			if black then currentThemeHighlight.PressedBlack = black end
		end

		if typeof(PianoUI.SetHighlightColors) == "function" then
			PianoUI.SetHighlightColors(currentThemeHighlight.PressedWhite, currentThemeHighlight.PressedBlack)
		end

		if currentPianoModel then
			currentPianoModel:SetAttribute("PressedWhite", currentThemeHighlight.PressedWhite)
			currentPianoModel:SetAttribute("PressedBlack", currentThemeHighlight.PressedBlack)
		end
	end

	-- Listen for theme equipping in real-time
	player:GetAttributeChangedSignal("EquippedKeyColor"):Connect(updateActiveThemeColors)
	player:GetAttributeChangedSignal("EquippedPianoTheme"):Connect(updateActiveThemeColors)
	player:GetAttributeChangedSignal("EquippedColorTheme"):Connect(updateActiveThemeColors)
	player:GetAttributeChangedSignal("EquippedTheme"):Connect(updateActiveThemeColors)

	-- Live UI Theme listener for ThemeManager integration
	local ThemeManager = ReplicatedStorage:FindFirstChild("ThemeManager") and require(ReplicatedStorage.ThemeManager)

	local function updateUITheme()
		local uiPreset = player:GetAttribute("EquippedUIPreset") or "Default"
		local themeData = CustomizationData.GetItemData("UI Themes", uiPreset)
		local mainGui = playerGui:FindFirstChild("PianoScreenGui")

		if themeData and mainGui and ThemeManager then
			ThemeManager.ApplyTheme(mainGui, themeData)
		end
	end

	player:GetAttributeChangedSignal("EquippedUIPreset"):Connect(updateUITheme)

	task.defer(function()
		updateActiveThemeColors()
		updateUITheme()
	end)

	-- Currency Batcher System
	local pendingNotes = 0

	local function trackNotePlayed()
		if SeatManager.IsSeated() then
			pendingNotes = pendingNotes + 1
		end
	end

	task.spawn(function()
		while true do
			task.wait(1)
			if pendingNotes > 0 then
				local countToSend = pendingNotes
				pendingNotes = 0
				pcall(function()
					EarnCurrencyRemote:FireServer(countToSend)
				end)
			end
		end
	end)

	-- Build unified list of keys to sink (Normal, Ctrl, Overrides, & Modifiers)
	local mappedKeysToSink = {}
	local registeredKeys = {}

	local function registerKeysFromTable(t)
		if not t then return end
		for keyCode, _ in pairs(t) do
			if not registeredKeys[keyCode] then
				registeredKeys[keyCode] = true
				table.insert(mappedKeysToSink, keyCode)
			end
		end
	end

	registerKeysFromTable(PianoConfig.KEY_MAP_NORMAL)
	registerKeysFromTable(PianoConfig.KEY_MAP_CTRL)

	if PianoConfig.OVERRIDE_KEYS then
		for _, keyCode in ipairs(PianoConfig.OVERRIDE_KEYS) do
			if not registeredKeys[keyCode] then
				registeredKeys[keyCode] = true
				table.insert(mappedKeysToSink, keyCode)
			end
		end
	end

	local extraKeys = {
		Enum.KeyCode.Tab, Enum.KeyCode.CapsLock,
		Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl,
		Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift
	}
	for _, k in ipairs(extraKeys) do
		if not registeredKeys[k] then
			registeredKeys[k] = true
			table.insert(mappedKeysToSink, k)
		end
	end

	local function SinkEngineShortcuts(actionName, inputState, inputObject)
		if UserInputService:GetFocusedTextBox() ~= nil then
			return Enum.ContextActionResult.Pass
		end
		if inputState == Enum.UserInputState.Begin then
			lastSunkTime = os.clock()
			lastSunkKeyCode = inputObject.KeyCode
		end
		return Enum.ContextActionResult.Sink
	end

	-- Initialize UI & Callbacks
	PianoUI.Init(
		function(isSustain) end,
		function(transposeValue)
			AudioEngine.SetTranspose(transposeValue)
			if currentPianoModel then
				PianoNoteEvent:FireServer(currentPianoModel, 5, transposeValue)
			end
		end,
		function(property, value)
			AudioEngine.UpdateReverbProperty(property, value)
			if currentPianoModel then
				PianoNoteEvent:FireServer(currentPianoModel, 4, property, value)
			end
		end,
		function(noteIndex, isPressed)
			local keyId = "UI_Note_" .. noteIndex
			if isPressed then
				trackNotePlayed()
				local calculatedVolume = PianoUI.ProcessNoteStrike(noteIndex) or 0.65
				AudioEngine.PlayNote(keyId, noteIndex, calculatedVolume)
				VisualEffectsManager.PlayNoteEffect(noteIndex, calculatedVolume)
				if currentPianoModel then
					PianoNoteEvent:FireServer(currentPianoModel, 1, noteIndex, calculatedVolume)
				end
			else
				AudioEngine.ReleaseKey(keyId, PianoUI.IsSustainOn())
				VisualEffectsManager.StopNoteEffect(noteIndex)
				if currentPianoModel then
					PianoNoteEvent:FireServer(currentPianoModel, 2, noteIndex, PianoUI.IsSustainOn())
				end
			end
		end,
		pianoSounds,
		function(selectedFontName)
			AudioEngine.SetSoundfont(selectedFontName)
			if currentPianoModel then
				PianoNoteEvent:FireServer(currentPianoModel, 6, selectedFontName)
			end
		end
	)

	-- Hook MultiTransposeController change callback to the UI and AudioEngine
	MultiTransposeController.OnTransposeChanged = function(activeValue)
		PianoUI.SetTranspose(activeValue)
	end

	-- Initialize Seat Manager Listener
	SeatManager.Init(function(isSeated, pianoModel)
		if isSeated and pianoModel then
			currentPianoModel = pianoModel:IsA("Model") and pianoModel or pianoModel:FindFirstAncestorOfClass("Model")
			updateActiveThemeColors()
			AudioEngine.SetReverbEnabled(false)
		else
			currentPianoModel = nil
			AudioEngine.SetReverbEnabled(false)
		end

		local uiSuccess, err = pcall(function()
			PianoUI.SetVisible(isSeated)
		end)
		if not uiSuccess then
			warn("[PianoController] Error setting PianoUI visibility:", err)
		end

		if isSeated then
			pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
			end)

			-- Enable Multi-Transpose keybinds
			MultiTransposeController.EnableBinds()

			-- Bound at priority 10000 so studio tool shortcuts (Ctrl+1, etc.) are overridden cleanly
			ContextActionService:BindActionAtPriority(
				"BlockEnginePianoShortcuts",
				SinkEngineShortcuts,
				false,
				10000,
				table.unpack(mappedKeysToSink)
			)
		else
			ContextActionService:UnbindAction("BlockEnginePianoShortcuts")

			-- Disable Multi-Transpose keybinds & Reset Sequence
			MultiTransposeController.DisableBinds()
			MultiTransposeController.Reset()

			PianoUI.SetSustainState(false)
			PianoUI.SetTranspose(0)
			AudioEngine.DampenAllNotes()

			for _, noteData in pairs(activeNotesByKeyCode) do
				local actualNoteIndex = typeof(noteData) == "table" and noteData.actualNote or noteData
				PianoUI.SetKeyVisualState(actualNoteIndex, false)
				VisualEffectsManager.StopNoteEffect(actualNoteIndex)
			end
			isCtrlHeld = false
			isShiftHeld = false
			table.clear(physicallyPressedKeys)
			table.clear(activeNotesByKeyCode)
		end
	end)

	-- Key Press Input
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
			isCtrlHeld = true
		elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			isShiftHeld = true
		end

		-- Ignore inputs consumed by UI/Chat unless explicitly sunk by our piano shortcut binder
		local wasSunkByPiano = (os.clock() - lastSunkTime < 0.05) and (lastSunkKeyCode == input.KeyCode)
		if gameProcessed and not wasSunkByPiano then
			return
		end

		if input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt then
			PianoUI.ProcessAltScroll()
			return
		end

		if UserInputService:GetFocusedTextBox() ~= nil then return end
		if not SeatManager.IsSeated() then return end

		if input.KeyCode == Enum.KeyCode.Backspace then
			SeatManager.ExitSeat()
			return
		end

		if input.KeyCode == Enum.KeyCode.RightBracket then
			PianoUI.ChangeTranspose(-1)
			return
		elseif input.KeyCode == Enum.KeyCode.LeftBracket then
			PianoUI.ChangeTranspose(1)
			return
		end

		-- Tab & CapsLock are handled directly inside MultiTransposeController

		if input.KeyCode == Enum.KeyCode.Space then
			if PianoUI.IsSustainOn() then
				AudioEngine.DampenUnheldNotes()
				if currentPianoModel then
					PianoNoteEvent:FireServer(currentPianoModel, 3, "dampen")
				end
			else
				PianoUI.SetSustainState(true)
				AudioEngine.DampenLoudRingingNotes(0.28)
				if currentPianoModel then
					PianoNoteEvent:FireServer(currentPianoModel, 3, true)
				end
			end
			return
		end

		if physicallyPressedKeys[input.KeyCode] then return end

		local ctrlActive = checkIsCtrlHeld()
		local shiftActive = checkIsShiftHeld()

		local keyData = nil
		if ctrlActive and PianoConfig.KEY_MAP_CTRL and PianoConfig.KEY_MAP_CTRL[input.KeyCode] then
			keyData = PianoConfig.KEY_MAP_CTRL[input.KeyCode]
		elseif PianoConfig.KEY_MAP_NORMAL then
			keyData = PianoConfig.KEY_MAP_NORMAL[input.KeyCode]
		end

		if keyData then
			physicallyPressedKeys[input.KeyCode] = true

			-- Rapid tap cleanup to prevent stuck visual keys
			if activeNotesByKeyCode[input.KeyCode] then
				local prevNote = activeNotesByKeyCode[input.KeyCode]
				local prevActual = typeof(prevNote) == "table" and prevNote.actualNote or prevNote
				PianoUI.SetKeyVisualState(prevActual, false, currentThemeHighlight)
				AudioEngine.ReleaseKey(input.KeyCode, PianoUI.IsSustainOn())
				VisualEffectsManager.StopNoteEffect(prevActual)
				activeNotesByKeyCode[input.KeyCode] = nil
			end

			local baseNoteIndex = nil
			if typeof(keyData) == "number" then
				baseNoteIndex = keyData
			elseif typeof(keyData) == "table" then
				if shiftActive and keyData.shift then
					baseNoteIndex = keyData.shift
				else
					baseNoteIndex = keyData.normal or keyData[1]
				end
			end

			if baseNoteIndex then
				trackNotePlayed()
				local calculatedVolume = PianoUI.ProcessNoteStrike(baseNoteIndex) or 0.65
				AudioEngine.PlayNote(input.KeyCode, baseNoteIndex, calculatedVolume)

				if currentPianoModel then
					PianoNoteEvent:FireServer(currentPianoModel, 1, baseNoteIndex, calculatedVolume)
				end

				local actualNoteIndex = baseNoteIndex + PianoUI.GetTranspose()
				VisualEffectsManager.PlayNoteEffect(actualNoteIndex, calculatedVolume)

				activeNotesByKeyCode[input.KeyCode] = {
					baseNote = baseNoteIndex,
					actualNote = actualNoteIndex
				}
				PianoUI.SetKeyVisualState(actualNoteIndex, true, currentThemeHighlight)
			end
		end
	end)

	-- Key Release Handler
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
			isCtrlHeld = false
		elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			isShiftHeld = false
		end

		physicallyPressedKeys[input.KeyCode] = nil

		local noteData = activeNotesByKeyCode[input.KeyCode]
		if noteData then
			local baseNoteIndex = typeof(noteData) == "table" and noteData.baseNote or noteData
			local actualNoteIndex = typeof(noteData) == "table" and noteData.actualNote or (baseNoteIndex + PianoUI.GetTranspose())

			PianoUI.SetKeyVisualState(actualNoteIndex, false, currentThemeHighlight)
			VisualEffectsManager.StopNoteEffect(actualNoteIndex)
			activeNotesByKeyCode[input.KeyCode] = nil

			if currentPianoModel then
				PianoNoteEvent:FireServer(currentPianoModel, 2, baseNoteIndex, PianoUI.IsSustainOn())
			end
		end

		AudioEngine.ReleaseKey(input.KeyCode, PianoUI.IsSustainOn())
	end)

	-- Window Focus Released
	UserInputService.WindowFocusReleased:Connect(function()
		isCtrlHeld = false
		isShiftHeld = false

		for _, noteData in pairs(activeNotesByKeyCode) do
			local actualNoteIndex = typeof(noteData) == "table" and noteData.actualNote or noteData
			PianoUI.SetKeyVisualState(actualNoteIndex, false, currentThemeHighlight)
			VisualEffectsManager.StopNoteEffect(actualNoteIndex)
		end
		table.clear(physicallyPressedKeys)
		table.clear(activeNotesByKeyCode)
	end)
end

return PianoController