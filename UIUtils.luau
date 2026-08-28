local UIUtils = {}

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

--------------------------------------------------------------------------------
-- BASE COLOR PALETTE & ALIASES
--------------------------------------------------------------------------------
local baseColors = {
	COLOR_OFF          = Color3.fromRGB(35, 37, 42),
	COLOR_ON           = Color3.fromRGB(46, 204, 113),
	COLOR_BTN          = Color3.fromRGB(50, 53, 60),
	TEXT_OFF           = Color3.fromRGB(150, 150, 150),
	TEXT_ON            = Color3.fromRGB(255, 255, 255),

	-- Theme Colors
	BG_DARK            = Color3.fromRGB(30, 30, 38),
	PANEL_BG           = Color3.fromRGB(24, 24, 30),
	CARD_BG            = Color3.fromRGB(36, 36, 46),
	CARD_SELECT        = Color3.fromRGB(50, 50, 70),
	INPUT_BG           = Color3.fromRGB(18, 18, 24),
	ACCENT             = Color3.fromRGB(80, 120, 240),
	ACCENT_GREEN       = Color3.fromRGB(46, 204, 113),
	CLOSE_RED          = Color3.fromRGB(220, 60, 60),
	TEXT_MAIN          = Color3.fromRGB(255, 255, 255),
	TEXT_MUTED         = Color3.fromRGB(160, 160, 175),
	TEXT_LIGHT         = Color3.fromRGB(255, 255, 255),
	TEXT_DARK          = Color3.fromRGB(30, 30, 38),
	STROKE_DEFAULT     = Color3.fromRGB(70, 75, 85),
	DIFFICULTY_YELLOW  = Color3.fromRGB(241, 196, 15),
	WHITE              = Color3.fromRGB(255, 255, 255),
	BLACK              = Color3.fromRGB(0, 0, 0),
}

-- Mapped property keys
local keyMap = {
	MainBg              = "BG_DARK",
	MAIN_BG             = "BG_DARK",
	PanelBg             = "PANEL_BG",
	PanelBackground     = "PANEL_BG",
	CardBg              = "CARD_BG",
	CardBackground      = "CARD_BG",
	CardSelect          = "CARD_SELECT",
	InputBg             = "INPUT_BG",
	InputBackground     = "INPUT_BG",
	FieldBg             = "INPUT_BG",
	SecondaryBg         = "BG_DARK",
	SecondaryBackground = "BG_DARK",
	ButtonBg            = "COLOR_BTN",
	ButtonBackground    = "COLOR_BTN",
	TextMain            = "TEXT_MAIN",
	TextColor           = "TEXT_MAIN",
	TextMuted           = "TEXT_MUTED",
	SubTextColor        = "TEXT_MUTED",
	TextLight           = "TEXT_LIGHT",
	TextDark            = "TEXT_DARK",
	Border              = "STROKE_DEFAULT",
	BORDER              = "STROKE_DEFAULT",
	StrokeColor         = "STROKE_DEFAULT",
	STROKE_COLOR        = "STROKE_DEFAULT",
	Accent              = "ACCENT",
	AccentGreen         = "ACCENT_GREEN",
	CloseRed            = "CLOSE_RED",
	DifficultyYellow    = "DIFFICULTY_YELLOW",
	White               = "WHITE",
	Black               = "BLACK",
}

for aliasKey, targetKey in pairs(keyMap) do
	if baseColors[targetKey] and not baseColors[aliasKey] then
		baseColors[aliasKey] = baseColors[targetKey]
	end
end

--------------------------------------------------------------------------------
-- SILENT METATABLE & ANCESTRY FILTER
--------------------------------------------------------------------------------
local colorsMetatable = {
	__index = function(tbl, key)
		if type(key) ~= "string" then
			return Color3.fromRGB(255, 255, 255)
		end

		local mapped = keyMap[key]
		if mapped and rawget(tbl, mapped) then
			return rawget(tbl, mapped)
		end

		local cleanKey = key:gsub("_", ""):lower()
		for rawKey, val in pairs(tbl) do
			if type(rawKey) == "string" and rawKey:gsub("_", ""):lower() == cleanKey then
				return val
			end
		end

		return Color3.fromRGB(255, 255, 255)
	end
}

UIUtils.Colors = setmetatable(baseColors, colorsMetatable)
UIUtils.C = UIUtils.Colors

local function isInsidePianoUI(inst)
	if not inst then return false end
	if inst:GetAttribute("PianoUIElement") == true then return true end
	return inst.Name == "PianoUI" or inst:FindFirstAncestor("PianoUI") ~= nil
end

--------------------------------------------------------------------------------
-- THEME ACCESSOR HELPERS
--------------------------------------------------------------------------------
function UIUtils.GetActiveThemeColors(themeOverride)
	if type(themeOverride) == "table" and next(themeOverride) then
		return setmetatable(themeOverride, {
			__index = function(tbl, key)
				return UIUtils.Colors[key]
			end
		})
	end
	return UIUtils.Colors
end

UIUtils.GetTheme = UIUtils.GetActiveThemeColors
UIUtils.GetColors = UIUtils.GetActiveThemeColors

--------------------------------------------------------------------------------
-- INSTANCE THEMING
--------------------------------------------------------------------------------
function UIUtils.ApplyThemeToInstance(inst)
	if not inst or not inst:IsA("GuiObject") then return end
	if inst:GetAttribute("IgnoreTheme") == true then return end
	if not isInsidePianoUI(inst) then return end

	local C = UIUtils.Colors
	local role = inst:GetAttribute("ThemeRole")

	if role == "CardBackground" or role == "CardBg" then
		inst.BackgroundColor3 = C.CARD_BG
	elseif role == "PanelBackground" or role == "PanelBg" or role == "MainBg" then
		inst.BackgroundColor3 = C.PANEL_BG
	elseif role == "SecondaryBackground" or role == "SecondaryBg" then
		inst.BackgroundColor3 = C.BG_DARK
	elseif role == "ButtonBackground" or role == "ButtonBg" then
		inst.BackgroundColor3 = C.COLOR_BTN
	elseif role == "InputBackground" or role == "FieldBg" then
		inst.BackgroundColor3 = C.INPUT_BG
	elseif role == "TextColor" or role == "TextMain" then
		if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
			inst.TextColor3 = C.TEXT_MAIN
		end
	elseif role == "SubTextColor" or role == "TextMuted" then
		if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
			inst.TextColor3 = C.TEXT_MUTED
		end
	elseif role == "StrokeColor" or role == "STROKE_COLOR" then
		if inst:IsA("UIStroke") then
			inst.Color = C.STROKE_DEFAULT
		end
	else
		if inst:IsA("UIStroke") then
			inst.Color = C.STROKE_DEFAULT
		elseif inst:IsA("TextBox") then
			inst.BackgroundColor3 = C.INPUT_BG
			inst.TextColor3 = C.TEXT_MAIN
		elseif inst:IsA("TextButton") then
			if inst.AutoButtonColor ~= false and not inst.Name:lower():find("tab") then
				inst.BackgroundColor3 = C.COLOR_BTN
			end
			inst.TextColor3 = C.TEXT_MAIN
		elseif inst:IsA("TextLabel") then
			local nameLower = inst.Name:lower()
			if nameLower:find("sub") or nameLower:find("muted") or nameLower:find("desc") then
				inst.TextColor3 = C.TEXT_MUTED
			else
				inst.TextColor3 = C.TEXT_MAIN
			end
		elseif inst:IsA("ScrollingFrame") then
			inst.BackgroundColor3 = C.INPUT_BG
			if inst.ScrollBarImageColor3 then
				inst.ScrollBarImageColor3 = C.ACCENT
			end
		elseif inst:IsA("Frame") then
			local nameLower = inst.Name:lower()
			if nameLower:find("header") or nameLower:find("bar") or nameLower:find("tab") then
				inst.BackgroundColor3 = C.BG_DARK
			elseif nameLower:find("panel") or nameLower:find("window") or nameLower:find("card") then
				inst.BackgroundColor3 = C.CARD_BG
			else
				if inst.BackgroundTransparency < 1 then
					inst.BackgroundColor3 = C.CARD_BG
				end
			end
		end
	end
end

function UIUtils.ApplyTheme(theme)
	if type(theme) ~= "table" then return end

	for key, color in pairs(theme) do
		if typeof(color) == "Color3" then
			UIUtils.Colors[key] = color
			local mapped = keyMap[key]
			if mapped then
				UIUtils.Colors[mapped] = color
			end
		end
	end

	UIUtils.C = UIUtils.Colors

	local player = Players.LocalPlayer
	if player then
		local playerGui = player:FindFirstChild("PlayerGui")
		if playerGui then
			for _, desc in ipairs(playerGui:GetDescendants()) do
				UIUtils.ApplyThemeToInstance(desc)
			end
		end
	end
end

local function watchPlayerGui(player)
	local playerGui = player:WaitForChild("PlayerGui", 10)
	if playerGui then
		playerGui.DescendantAdded:Connect(function(descendant)
			task.defer(function()
				if descendant and descendant.Parent then
					UIUtils.ApplyThemeToInstance(descendant)
				end
			end)
		end)

		for _, desc in ipairs(playerGui:GetDescendants()) do
			UIUtils.ApplyThemeToInstance(desc)
		end
	end
end

if Players.LocalPlayer then
	task.spawn(function() watchPlayerGui(Players.LocalPlayer) end)
else
	Players.PlayerAdded:Connect(function(player)
		if player == Players.LocalPlayer then
			watchPlayerGui(player)
		end
	end)
end

function UIUtils.BindThemeManager(ThemeManager)
	if not ThemeManager then return end

	local currentTheme = (type(ThemeManager.GetTheme) == "function" and ThemeManager:GetTheme())
		or ThemeManager.CurrentTheme
		or ThemeManager.Theme

	if currentTheme then
		UIUtils.ApplyTheme(currentTheme)
	end

	if ThemeManager.ThemeChanged then
		if typeof(ThemeManager.ThemeChanged) == "RBXScriptSignal" or type(ThemeManager.ThemeChanged.Connect) == "function" then
			ThemeManager.ThemeChanged:Connect(function(newTheme)
				UIUtils.ApplyTheme(newTheme)
			end)
		end
	elseif type(ThemeManager.OnThemeChanged) == "function" then
		ThemeManager.OnThemeChanged(function(newTheme)
			UIUtils.ApplyTheme(newTheme)
		end)
	end
end

--------------------------------------------------------------------------------
-- ELEMENT CREATION & UTILITIES
--------------------------------------------------------------------------------
function UIUtils.makeElement(className, props, cornerRadius, padding)
	local inst = Instance.new(className)
	inst:SetAttribute("PianoUIElement", true)

	if inst:IsA("GuiObject") then
		inst.BorderSizePixel = 0
		if className == "Frame" then
			inst.BackgroundTransparency = 1
		end
	end

	for prop, val in pairs(props or {}) do
		pcall(function()
			inst[prop] = val
		end)
	end

	if cornerRadius then
		UIUtils.CreateCorner(inst, cornerRadius)
	end

	if padding and type(padding) == "table" then
		local uiPadding = Instance.new("UIPadding")
		uiPadding.PaddingTop = UDim.new(0, padding[1] or 0)
		uiPadding.PaddingRight = UDim.new(0, padding[2] or 0)
		uiPadding.PaddingBottom = UDim.new(0, padding[3] or 0)
		uiPadding.PaddingLeft = UDim.new(0, padding[4] or 0)
		uiPadding.Parent = inst
	end

	UIUtils.ApplyThemeToInstance(inst)

	return inst
end

UIUtils.MakeElement = UIUtils.makeElement

function UIUtils.getDifficultyColor(diff)
	if diff == "Easy" then
		return Color3.fromRGB(46, 204, 113)
	elseif diff == "Hard" then
		return Color3.fromRGB(231, 76, 60)
	else
		return Color3.fromRGB(241, 196, 15)
	end
end

function UIUtils.CreateCorner(instance, radius)
	local corner = instance:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 6)
	corner.Parent = instance
	return corner
end

function UIUtils.CreateStroke(instance, color, thickness)
	local stroke = instance:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Color = color or UIUtils.Colors.STROKE_DEFAULT
	stroke.Thickness = thickness or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
	return stroke
end

function UIUtils.SetButtonState(button, isOn, activeText, inactiveText)
	local C = UIUtils.Colors
	button.BackgroundColor3 = isOn and C.COLOR_ON or C.COLOR_BTN
	button.TextColor3 = isOn and C.TEXT_ON or C.TEXT_OFF

	if activeText and inactiveText then
		button.Text = isOn and activeText or inactiveText
	elseif activeText then
		button.Text = activeText
	end

	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = isOn and C.COLOR_ON or C.STROKE_DEFAULT
	end
end

UIUtils.SetToggleState = UIUtils.SetButtonState

function UIUtils.MakeDraggable(frame, handle)
	handle = handle or frame
	local dragging = false
	local dragInput, dragStart, startPos

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	handle.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

function UIUtils.CreateSliderRow(parent, name, labelText, minVal, maxVal, defaultVal, isFloat, callback)
	local C = UIUtils.Colors

	local row = Instance.new("Frame")
	row.Name = name .. "Row"
	row.Size = UDim2.new(1, 0, 0, 40)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(0, 120, 0, 18)
	label.Position = UDim2.new(0, 4, 0, 0)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Text = labelText
	label.TextColor3 = C.TEXT_ON
	label.Font = Enum.Font.GothamBold
	label.TextSize = 10
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row

	local box = Instance.new("TextBox")
	box.Name = "ValueBox"
	box.Size = UDim2.new(0, 44, 0, 18)
	box.Position = UDim2.new(1, -48, 0, 0)
	box.BackgroundColor3 = C.INPUT_BG
	box.BorderSizePixel = 0
	box.TextColor3 = C.TEXT_ON
	box.Font = Enum.Font.GothamBold
	box.TextSize = 10
	box.Parent = row
	UIUtils.CreateCorner(box, 4)

	local trackBg = Instance.new("TextButton")
	trackBg.Name = "TrackBg"
	trackBg.Size = UDim2.new(1, -8, 0, 6)
	trackBg.Position = UDim2.new(0, 4, 0, 25)
	trackBg.BackgroundColor3 = C.INPUT_BG
	trackBg.BorderSizePixel = 0
	trackBg.AutoButtonColor = false
	trackBg.Text = ""
	trackBg.Parent = row
	UIUtils.CreateCorner(trackBg, 3)

	local trackFill = Instance.new("Frame")
	trackFill.Name = "TrackFill"
	trackFill.Size = UDim2.new(0.5, 0, 1, 0)
	trackFill.BackgroundColor3 = C.COLOR_ON
	trackFill.BorderSizePixel = 0
	trackFill.Parent = trackBg
	UIUtils.CreateCorner(trackFill, 3)

	local thumb = Instance.new("Frame")
	thumb.Name = "Thumb"
	thumb.Size = UDim2.new(0, 14, 0, 14)
	thumb.AnchorPoint = Vector2.new(0.5, 0.5)
	thumb.Position = UDim2.new(0.5, 0, 0.5, 0)
	thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	thumb.BorderSizePixel = 0
	thumb.ZIndex = 3
	thumb.Parent = trackBg
	UIUtils.CreateCorner(thumb, 7)

	local currentVal = defaultVal or minVal

	local function updateDisplay(val, skipCallback)
		val = math.clamp(val, minVal, maxVal)
		if not isFloat then
			val = math.floor(val + 0.5)
		else
			val = math.floor(val * 100 + 0.5) / 100
		end
		currentVal = val

		local alpha = (currentVal - minVal) / (maxVal - minVal)
		trackFill.Size = UDim2.new(alpha, 0, 1, 0)
		thumb.Position = UDim2.new(alpha, 0, 0.5, 0)

		if isFloat then
			box.Text = string.format("%.2f", currentVal)
		else
			box.Text = tostring(currentVal)
		end

		if callback and not skipCallback then
			callback(name, currentVal)
		end
	end

	local isDragging = false

	local function setValueFromMouse(input)
		local absPos = trackBg.AbsolutePosition.X
		local absSize = trackBg.AbsoluteSize.X
		local mouseX = input.Position.X
		local alpha = math.clamp((mouseX - absPos) / absSize, 0, 1)
		local val = minVal + alpha * (maxVal - minVal)
		updateDisplay(val, false)
	end

	local function startDragging(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = true
			setValueFromMouse(input)
		end
	end

	trackBg.InputBegan:Connect(startDragging)
	thumb.InputBegan:Connect(startDragging)

	UserInputService.InputChanged:Connect(function(input)
		if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setValueFromMouse(input)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = false
		end
	end)

	box.FocusLost:Connect(function()
		local num = tonumber(box.Text)
		if num then
			updateDisplay(num, false)
		else
			updateDisplay(currentVal, true)
		end
	end)

	updateDisplay(currentVal, true)

	return function(newVal, skipCallback)
		updateDisplay(newVal, skipCallback)
	end
end

return UIUtils