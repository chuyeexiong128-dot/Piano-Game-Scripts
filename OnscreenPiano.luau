local OnscreenPiano = {}

local TweenService = game:GetService("TweenService")
local UIUtils = require(script.Parent:WaitForChild("UIUtils"))

local pianoFrame = nil
local toggleTab = nil
local keyElements = {}
local isExpanded = true
local activePressedKeys = {}

local function GetActiveThemeColors(activeTheme)
	if type(activeTheme) == "table" and next(activeTheme) then
		return activeTheme
	end
	if type(UIUtils.GetActiveThemeColors) == "function" then
		return UIUtils.GetActiveThemeColors(activeTheme)
	elseif type(UIUtils.GetTheme) == "function" then
		return UIUtils.GetTheme(activeTheme)
	elseif type(UIUtils.GetColors) == "function" then
		return UIUtils.GetColors(activeTheme)
	end
	return UIUtils.Theme or UIUtils.Colors or UIUtils.C or {}
end

-- Strictly checks theme overrides first, then maps directly to UIUtils.Colors keys
local function getThemeColors(activeTheme)
	local C = GetActiveThemeColors(activeTheme)
	local U = UIUtils.Colors or UIUtils.C or {}

	return {
		WhiteKeyColor   = C.WhiteKeyColor or C.WhiteKey or U.TEXT_MAIN or U.TEXT_ON,
		BlackKeyColor   = C.BlackKeyColor or C.BlackKey or U.INPUT_BG or U.BG_DARK,
		WhiteKeyPressed = C.WhiteKeyPressed or C.Accent or C.ACCENT or U.ACCENT,
		BlackKeyPressed = C.BlackKeyPressed or C.Accent or C.ACCENT or U.ACCENT,
		CardBg          = C.CardBg or C.CARD_BG or C.PanelBg or C.PANEL_BG or U.CARD_BG,
		TextMain        = C.TextMain or C.TEXT_MAIN or C.TextColor or U.TEXT_MAIN,
		StrokeColor     = C.StrokeColor or C.STROKE_DEFAULT or C.Border or U.STROKE_DEFAULT,
	}
end

local currentKeyPreset = {
	WhiteKeyColor = nil,
	BlackKeyColor = nil,
	WhiteKeyPressed = nil,
	BlackKeyPressed = nil,
}

-- Compact Frame Dimensions
local FRAME_WIDTH = 850
local FRAME_HEIGHT = 95
local TAB_HEIGHT = 22

-- Centered Bottom Placement
local POS_EXPANDED = UDim2.new(0.5, 0, 1, -10)
local POS_COLLAPSED = UDim2.new(0.5, 0, 1, FRAME_HEIGHT - TAB_HEIGHT - 10)

-- 88-Key Pattern Mapping (A0 = 1, C8 = 88)
local OCTAVE_BLACK_PATTERN = { false, true, false, true, false, false, true, false, true, false, true, false }
local IS_BLACK_KEY = { false, true, false }

for i = 4, 88 do
	local patternIndex = ((i - 4) % 12) + 1
	IS_BLACK_KEY[i] = OCTAVE_BLACK_PATTERN[patternIndex]
end

function OnscreenPiano.Init(parentGui, onNoteTriggered)
	if pianoFrame then 
		pianoFrame.Visible = true
		return pianoFrame 
	end

	local theme = getThemeColors()

	-- Initialize default preset keys from UIUtils theme directly
	currentKeyPreset.WhiteKeyColor = theme.WhiteKeyColor
	currentKeyPreset.BlackKeyColor = theme.BlackKeyColor
	currentKeyPreset.WhiteKeyPressed = theme.WhiteKeyPressed
	currentKeyPreset.BlackKeyPressed = theme.BlackKeyPressed

	-- Main Piano Frame Container
	pianoFrame = Instance.new("Frame")
	pianoFrame.Name = "OnscreenPianoFrame"
	pianoFrame.AnchorPoint = Vector2.new(0.5, 1)
	pianoFrame.Size = UDim2.new(0, FRAME_WIDTH, 0, FRAME_HEIGHT)
	pianoFrame.Position = POS_EXPANDED

	pianoFrame:SetAttribute("ThemeRole", "CardBackground")

	pianoFrame.BackgroundColor3 = theme.CardBg
	pianoFrame.BackgroundTransparency = 0
	pianoFrame.BorderSizePixel = 0
	pianoFrame.Active = true
	pianoFrame.Visible = true
	pianoFrame.ZIndex = 20
	pianoFrame.ClipsDescendants = false
	pianoFrame.Parent = parentGui

	if UIUtils.CreateCorner then 
		UIUtils.CreateCorner(pianoFrame, 8) 
	end

	-- Border for Piano Frame
	local frameStroke = Instance.new("UIStroke")
	frameStroke.Name = "PianoBorder"
	frameStroke.Thickness = 1.5
	frameStroke.Color = theme.StrokeColor
	frameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	frameStroke.Parent = pianoFrame
	frameStroke:SetAttribute("ThemeRole", "STROKE_COLOR")

	-- Top Pull-Tab
	toggleTab = Instance.new("TextButton")
	toggleTab.Name = "ToggleTab"
	toggleTab.Size = UDim2.new(0, 95, 0, TAB_HEIGHT)
	toggleTab.Position = UDim2.new(0.5, -47, 0, -TAB_HEIGHT + 2)
	toggleTab.BackgroundColor3 = theme.CardBg
	toggleTab.BackgroundTransparency = 0
	toggleTab.Text = "? PIANO"
	toggleTab.TextColor3 = theme.TextMain
	toggleTab.Font = Enum.Font.GothamBold
	toggleTab.TextSize = 10
	toggleTab.ZIndex = 25
	toggleTab.Parent = pianoFrame
	toggleTab:SetAttribute("ThemeRole", "ButtonBackground")
	if UIUtils.CreateCorner then UIUtils.CreateCorner(toggleTab, 6) end

	-- Border for Pull-Tab
	local tabStroke = Instance.new("UIStroke")
	tabStroke.Name = "TabBorder"
	tabStroke.Thickness = 1.5
	tabStroke.Color = theme.StrokeColor
	tabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	tabStroke.Parent = toggleTab
	tabStroke:SetAttribute("ThemeRole", "STROKE_COLOR")

	toggleTab.MouseButton1Click:Connect(function()
		OnscreenPiano.ToggleExpanded()
	end)

	-- Container Frame for Keys
	local keysContainer = Instance.new("Frame")
	keysContainer.Name = "KeysContainer"
	keysContainer.Size = UDim2.new(1, -16, 1, -16)
	keysContainer.Position = UDim2.new(0, 8, 0, 8)
	keysContainer.BackgroundTransparency = 1
	keysContainer.ZIndex = 21
	keysContainer.Parent = pianoFrame

	local TOTAL_WHITE_KEYS = 52
	local whiteKeyWidthScale = 1 / TOTAL_WHITE_KEYS
	local currentWhiteIndex = 0

	-- Pass 1: Render White Keys
	for noteIndex = 1, 88 do
		if not IS_BLACK_KEY[noteIndex] then
			local keyBtn = Instance.new("TextButton")
			keyBtn.Name = "Key_" .. noteIndex
			keyBtn.Size = UDim2.new(whiteKeyWidthScale, -1, 1, 0)
			keyBtn.Position = UDim2.new(currentWhiteIndex * whiteKeyWidthScale, 0, 0, 0)
			keyBtn.BackgroundColor3 = currentKeyPreset.WhiteKeyColor
			keyBtn.BackgroundTransparency = 0
			keyBtn.Text = ""
			keyBtn.ZIndex = 21
			keyBtn.Parent = keysContainer
			keyBtn:SetAttribute("IgnoreTheme", true)
			if UIUtils.CreateCorner then UIUtils.CreateCorner(keyBtn, 3) end

			keyElements[noteIndex] = {
				Object = keyBtn,
				IsBlack = false,
				DefaultColor = currentKeyPreset.WhiteKeyColor,
				PressColor = currentKeyPreset.WhiteKeyPressed,
			}

			keyBtn.MouseButton1Down:Connect(function()
				if onNoteTriggered then onNoteTriggered(noteIndex, true) end
			end)

			keyBtn.MouseButton1Up:Connect(function()
				if onNoteTriggered then onNoteTriggered(noteIndex, false) end
			end)

			keyBtn.MouseLeave:Connect(function()
				if onNoteTriggered and activePressedKeys[noteIndex] then
					onNoteTriggered(noteIndex, false)
				end
			end)

			currentWhiteIndex = currentWhiteIndex + 1
		end
	end

	-- Pass 2: Render Black Keys Overlaid
	currentWhiteIndex = 0
	for noteIndex = 1, 88 do
		if IS_BLACK_KEY[noteIndex] then
			local keyBtn = Instance.new("TextButton")
			keyBtn.Name = "Key_" .. noteIndex
			keyBtn.Size = UDim2.new(whiteKeyWidthScale * 0.62, 0, 0.58, 0)
			keyBtn.Position = UDim2.new(currentWhiteIndex * whiteKeyWidthScale - (whiteKeyWidthScale * 0.31), 0, 0, 0)
			keyBtn.BackgroundColor3 = currentKeyPreset.BlackKeyColor
			keyBtn.BackgroundTransparency = 0
			keyBtn.Text = ""
			keyBtn.ZIndex = 22
			keyBtn.Parent = keysContainer
			keyBtn:SetAttribute("IgnoreTheme", true)
			if UIUtils.CreateCorner then UIUtils.CreateCorner(keyBtn, 2) end

			keyElements[noteIndex] = {
				Object = keyBtn,
				IsBlack = true,
				DefaultColor = currentKeyPreset.BlackKeyColor,
				PressColor = currentKeyPreset.BlackKeyPressed,
			}

			keyBtn.MouseButton1Down:Connect(function()
				if onNoteTriggered then onNoteTriggered(noteIndex, true) end
			end)

			keyBtn.MouseButton1Up:Connect(function()
				if onNoteTriggered then onNoteTriggered(noteIndex, false) end
			end)

			keyBtn.MouseLeave:Connect(function()
				if onNoteTriggered and activePressedKeys[noteIndex] then
					onNoteTriggered(noteIndex, false)
				end
			end)
		else
			currentWhiteIndex = currentWhiteIndex + 1
		end
	end

	return pianoFrame
end

function OnscreenPiano.ToggleExpanded(overrideState)
	if not pianoFrame or not toggleTab then return end

	if overrideState ~= nil then
		isExpanded = overrideState
	else
		isExpanded = not isExpanded
	end

	local targetPos = isExpanded and POS_EXPANDED or POS_COLLAPSED
	toggleTab.Text = isExpanded and "? PIANO" or "? PIANO"

	local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(pianoFrame, tweenInfo, { Position = targetPos }):Play()
end

function OnscreenPiano.SetKeyVisualState(noteIndex, isPressed)
	local keyData = keyElements[noteIndex]
	if not keyData then return end

	activePressedKeys[noteIndex] = isPressed or nil
	keyData.Object.BackgroundColor3 = isPressed and keyData.PressColor or keyData.DefaultColor
end

function OnscreenPiano.SetKeyPreset(presetTable)
	if type(presetTable) ~= "table" then return end

	local whitePressed = presetTable.WhiteKeyPressed or presetTable.PressedWhite
	local blackPressed = presetTable.BlackKeyPressed or presetTable.PressedBlack
	local whiteDefault = presetTable.WhiteKeyColor or presetTable.DefaultWhite
	local blackDefault = presetTable.BlackKeyColor or presetTable.DefaultBlack

	if whiteDefault then currentKeyPreset.WhiteKeyColor = whiteDefault end
	if blackDefault then currentKeyPreset.BlackKeyColor = blackDefault end
	if whitePressed then currentKeyPreset.WhiteKeyPressed = whitePressed end
	if blackPressed then currentKeyPreset.BlackKeyPressed = blackPressed end

	for noteIndex, keyData in pairs(keyElements) do
		if keyData.IsBlack then
			keyData.DefaultColor = currentKeyPreset.BlackKeyColor or keyData.DefaultColor
			keyData.PressColor = currentKeyPreset.BlackKeyPressed or keyData.PressColor
		else
			keyData.DefaultColor = currentKeyPreset.WhiteKeyColor or keyData.DefaultColor
			keyData.PressColor = currentKeyPreset.WhiteKeyPressed or keyData.PressColor
		end

		local isCurrentlyPressed = activePressedKeys[noteIndex] == true
		keyData.Object.BackgroundColor3 = isCurrentlyPressed and keyData.PressColor or keyData.DefaultColor
	end
end

function OnscreenPiano.SetHighlightColors(whitePressed, blackPressed)
	OnscreenPiano.SetKeyPreset({
		WhiteKeyPressed = whitePressed,
		BlackKeyPressed = blackPressed,
	})
end

function OnscreenPiano.UpdateBackground(panelColor, tabColor)
	local theme = getThemeColors()
	local defaultBg = panelColor or theme.CardBg

	if pianoFrame then
		pianoFrame.BackgroundColor3 = defaultBg
	end
	if toggleTab then
		toggleTab.BackgroundColor3 = tabColor or defaultBg
	end
end

function OnscreenPiano.ApplyTheme(theme)
	if not pianoFrame then return end
	local t = getThemeColors(theme)

	pianoFrame.BackgroundColor3 = t.CardBg
	if toggleTab then
		toggleTab.BackgroundColor3 = t.CardBg
		toggleTab.TextColor3 = t.TextMain
	end

	local frameStroke = pianoFrame:FindFirstChild("PianoBorder")
	if frameStroke then frameStroke.Color = t.StrokeColor end

	local tabStroke = toggleTab and toggleTab:FindFirstChild("TabBorder")
	if tabStroke then tabStroke.Color = t.StrokeColor end

	if t.WhiteKeyPressed or t.BlackKeyPressed then
		OnscreenPiano.SetHighlightColors(t.WhiteKeyPressed, t.BlackKeyPressed)
	end
end

OnscreenPiano.UpdateTheme = OnscreenPiano.ApplyTheme
OnscreenPiano.RefreshTheme = OnscreenPiano.ApplyTheme

return OnscreenPiano