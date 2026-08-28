local SustainButton = {}

local TweenService = game:GetService("TweenService")
local UIUtils = require(script.Parent.UIUtils)

local button = nil
local isActive = false
local onToggleCallback = nil
local currentTheme = nil

local function getTargetColors()
	local C = UIUtils.Colors
	if isActive then
		local activeBg = currentTheme and (currentTheme.AccentColor or currentTheme.Accent or currentTheme.Success) or C.COLOR_ON
		local activeText = currentTheme and currentTheme.TextColor or C.TEXT_ON
		return activeBg, activeText
	else
		local inactiveBg = currentTheme and (currentTheme.ButtonBackground or currentTheme.SecondaryBackground or currentTheme.BG_COLOR) or C.COLOR_OFF
		local inactiveText = currentTheme and (currentTheme.TextMuted or currentTheme.TextColor) or C.TEXT_OFF
		return inactiveBg, inactiveText
	end
end

function SustainButton.Init(parentContainer, callback)
	if button then return end
	onToggleCallback = callback

	local targetBg, targetText = getTargetColors()

	button = Instance.new("TextButton")
	button.Name = "SustainButton"
	button.Size = UDim2.new(1, 0, 0, 40)
	button.Position = UDim2.new(0, 0, 0, 48)
	button.BackgroundColor3 = targetBg
	button.Text = "SUSTAIN: OFF"
	button.TextColor3 = targetText
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.AutoButtonColor = false
	button:SetAttribute("ThemeRole", "ButtonBackground")
	button.Parent = parentContainer

	UIUtils.CreateCorner(button, 8)
	UIUtils.CreateStroke(button)

	button.Activated:Connect(function()
		SustainButton.Toggle()
	end)

	SustainButton.ApplyTheme()
end

-- ============================================================================
-- Dynamic Theme Engine Integration
-- ============================================================================

function SustainButton.ApplyTheme(theme)
	if type(theme) == "table" then
		currentTheme = theme
	end
	if not button then return end

	local targetBg, targetText = getTargetColors()
	button.BackgroundColor3 = targetBg
	button.TextColor3 = targetText

	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = currentTheme and (currentTheme.STROKE_COLOR or currentTheme.CardSelect) or UIUtils.Colors.STROKE_COLOR or Color3.fromRGB(70, 75, 85)
	end
end

SustainButton.UpdateTheme = SustainButton.ApplyTheme
SustainButton.RefreshTheme = SustainButton.ApplyTheme

-- ============================================================================
-- Core Logic & State Management
-- ============================================================================

function SustainButton.SetState(enabled, suppressCallback)
	isActive = enabled
	if not button then return end

	local targetBg, targetText = getTargetColors()
	button.Text = isActive and "SUSTAIN: ON" or "SUSTAIN: OFF"

	TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = targetBg,
		TextColor3 = targetText
	}):Play()

	if not suppressCallback then
		local cb = onToggleCallback or SustainButton.OnToggle or SustainButton.Callback
		if cb then
			cb(isActive)
		end
	end
end

function SustainButton.Toggle()
	SustainButton.SetState(not isActive)
end

function SustainButton.IsActive()
	return isActive
end

function SustainButton.SetCallback(callback)
	onToggleCallback = callback
	SustainButton.OnToggle = callback
	SustainButton.Callback = callback
end

return SustainButton