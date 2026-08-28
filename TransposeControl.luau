local TransposeControl = {}

local UIUtils = require(script.Parent:WaitForChild("UIUtils"))

-- UI & State References
local frame = nil
local displayLabel = nil
local downBtn = nil
local upBtn = nil

local currentTranspose = 0
local onChangeCallback = nil
local currentTheme = nil

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
		FrameBg = C.CardBackground or C.SecondaryBackground or C.COLOR_OFF or C.BG_COLOR or Color3.fromRGB(30, 30, 35),
		ButtonBg = C.ButtonBg or C.ButtonBackground or C.CardBackground or C.COLOR_BTN or Color3.fromRGB(50, 53, 60),
		TextColor = C.TextColor or C.TEXT_ON or Color3.fromRGB(255, 255, 255),
		StrokeColor = C.StrokeColor or C.STROKE_COLOR or C.STROKE_DEFAULT or C.CardSelect or Color3.fromRGB(70, 75, 85),
	}
end

function TransposeControl.Init(parentContainer, callback)
	if frame then return end
	onChangeCallback = callback

	local C = getThemeColors(currentTheme)

	frame = Instance.new("Frame")
	frame.Name = "TransposeFrame"
	frame.Size = UDim2.new(1, 0, 0, 42)
	frame.Position = UDim2.new(0, 0, 0, 96)
	frame.BackgroundColor3 = C.FrameBg
	frame:SetAttribute("ThemeRole", "CardBackground")
	frame.Parent = parentContainer

	if UIUtils.CreateCorner then UIUtils.CreateCorner(frame, 8) end
	if UIUtils.CreateStroke then UIUtils.CreateStroke(frame) end

	downBtn = Instance.new("TextButton")
	downBtn.Name = "TransposeDown"
	downBtn.Size = UDim2.new(0, 36, 1, -8)
	downBtn.Position = UDim2.new(0, 4, 0, 4)
	downBtn.BackgroundColor3 = C.ButtonBg
	downBtn.Text = "- ]"
	downBtn.Font = Enum.Font.GothamBold
	downBtn.TextSize = 13
	downBtn.TextColor3 = C.TextColor
	downBtn.AutoButtonColor = false
	downBtn:SetAttribute("ThemeRole", "ButtonBackground")
	downBtn.Parent = frame

	if UIUtils.CreateCorner then UIUtils.CreateCorner(downBtn, 6) end

	downBtn.Activated:Connect(function()
		TransposeControl.Change(-1)
	end)

	displayLabel = Instance.new("TextLabel")
	displayLabel.Name = "TransposeDisplay"
	displayLabel.Size = UDim2.new(1, -88, 1, 0)
	displayLabel.Position = UDim2.new(0, 44, 0, 0)
	displayLabel.BackgroundTransparency = 1
	displayLabel.Text = "TRANS: 0"
	displayLabel.TextColor3 = C.TextColor
	displayLabel.Font = Enum.Font.GothamBold
	displayLabel.TextSize = 11
	displayLabel:SetAttribute("ThemeRole", "TextColor")
	displayLabel.Parent = frame

	upBtn = Instance.new("TextButton")
	upBtn.Name = "TransposeUp"
	upBtn.Size = UDim2.new(0, 36, 1, -8)
	upBtn.Position = UDim2.new(1, -40, 0, 4)
	upBtn.BackgroundColor3 = C.ButtonBg
	upBtn.Text = "+ ["
	upBtn.Font = Enum.Font.GothamBold
	upBtn.TextSize = 13
	upBtn.TextColor3 = C.TextColor
	upBtn.AutoButtonColor = false
	upBtn:SetAttribute("ThemeRole", "ButtonBackground")
	upBtn.Parent = frame

	if UIUtils.CreateCorner then UIUtils.CreateCorner(upBtn, 6) end

	upBtn.Activated:Connect(function()
		TransposeControl.Change(1)
	end)

	TransposeControl.ApplyTheme()
end

-- ============================================================================
-- Dynamic Theme Engine Integration
-- ============================================================================

function TransposeControl.ApplyTheme(theme)
	if type(theme) == "table" then
		currentTheme = theme
	end
	if not frame then return end

	local C = getThemeColors(currentTheme)

	frame.BackgroundColor3 = C.FrameBg

	if displayLabel then
		displayLabel.TextColor3 = C.TextColor
	end

	if downBtn then
		downBtn.BackgroundColor3 = C.ButtonBg
		downBtn.TextColor3 = C.TextColor
	end

	if upBtn then
		upBtn.BackgroundColor3 = C.ButtonBg
		upBtn.TextColor3 = C.TextColor
	end

	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = C.StrokeColor
	end
end

TransposeControl.UpdateTheme = TransposeControl.ApplyTheme
TransposeControl.RefreshTheme = TransposeControl.ApplyTheme
TransposeControl.SetTheme = TransposeControl.ApplyTheme

-- ============================================================================
-- Core Logic & State Functions
-- ============================================================================

function TransposeControl.Set(shift, suppressCallback)
	local newTranspose = math.clamp(shift, -28, 28)
	local valueChanged = (newTranspose ~= currentTranspose)
	currentTranspose = newTranspose

	local textValue = currentTranspose > 0 and ("+" .. tostring(currentTranspose)) or tostring(currentTranspose)
	if displayLabel then
		displayLabel.Text = "TRANS: " .. textValue
	end

	if valueChanged and not suppressCallback then
		local cb = onChangeCallback or TransposeControl.OnChange or TransposeControl.Callback
		if cb then
			cb(currentTranspose)
		end
	end
end

function TransposeControl.Change(delta, suppressCallback)
	TransposeControl.Set(currentTranspose + delta, suppressCallback)
end

function TransposeControl.Get()
	return currentTranspose
end

function TransposeControl.SetCallback(callback)
	onChangeCallback = callback
	TransposeControl.OnChange = callback
	TransposeControl.Callback = callback
end

return TransposeControl