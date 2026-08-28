local SoundfontPanel = {}

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIUtils = require(script.Parent:WaitForChild("UIUtils"))

-- UI References
local menuFrame = nil
local headerFrame = nil
local titleLabel = nil
local closeWindowBtn = nil
local scrollFrame = nil
local listLayout = nil

-- Module State
local activeTheme = nil
local activeFontName = "Salamander Grand"
local hasUserSelected = false
local buttonMap = {}
local isOpen = false
local onSoundfontChangedCallback = nil
local targetSoundsFolder = nil

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
		MainBg = C.MainBg or C.BG_DARK or Color3.fromRGB(30, 30, 35),
		SecondaryBg = C.SecondaryBg or C.PANEL_BG or Color3.fromRGB(24, 24, 30),
		ButtonBg = C.ButtonBg or C.COLOR_BTN or C.InputBg or Color3.fromRGB(50, 53, 60),
		AccentColor = C.AccentColor or C.ACCENT or Color3.fromRGB(80, 120, 240),
		TextColor = C.TextColor or C.TEXT_ON or Color3.fromRGB(255, 255, 255),
		SubTextColor = C.SubTextColor or C.TEXT_MUTED or Color3.fromRGB(160, 160, 175),
		StrokeColor = C.StrokeColor or C.STROKE_DEFAULT or Color3.fromRGB(70, 75, 85),
	}
end

-- Dynamic Soundfont List Builder
local function RefreshSoundfontList()
	if not targetSoundsFolder or not scrollFrame then return end
	local C = getThemeColors(activeTheme)

	for _, fontFolder in ipairs(targetSoundsFolder:GetChildren()) do
		if fontFolder:IsA("Folder") and not buttonMap[fontFolder.Name] then
			local btn = Instance.new("TextButton")
			btn.Name = fontFolder.Name
			btn.Size = UDim2.new(1, 0, 0, 30)
			btn.AutoButtonColor = false
			btn.Text = fontFolder.Name
			btn.Font = Enum.Font.GothamBold
			btn.TextSize = 10
			btn.BackgroundColor3 = C.ButtonBg
			btn.TextColor3 = C.TextColor
			btn:SetAttribute("ThemeRole", "ButtonBackground")
			btn.Parent = scrollFrame

			if UIUtils.CreateCorner then UIUtils.CreateCorner(btn, 6) end
			if UIUtils.CreateStroke then UIUtils.CreateStroke(btn) end

			buttonMap[fontFolder.Name] = btn

			btn.Activated:Connect(function()
				SoundfontPanel.SelectSoundfont(fontFolder.Name)
				local cb = onSoundfontChangedCallback or SoundfontPanel.OnSoundfontChanged
				if cb then
					cb(fontFolder.Name)
				end
			end)
		end
	end

	SoundfontPanel.ApplyTheme()
end

function SoundfontPanel.Init(screenGui, parentContainer, pianoSoundsFolder, onSoundfontChanged)
	if menuFrame then return end

	targetSoundsFolder = pianoSoundsFolder
	onSoundfontChangedCallback = onSoundfontChanged
	local C = getThemeColors(activeTheme)

	-- Main Soundfont Panel Frame
	menuFrame = Instance.new("Frame")
	menuFrame.Name = "SoundfontPanel"
	menuFrame.Size = UDim2.new(0, 180, 0, 240)
	menuFrame.Position = UDim2.new(0, 180, 0.5, -120)
	menuFrame.BackgroundColor3 = C.MainBg
	menuFrame.Visible = false
	menuFrame.Active = true
	menuFrame:SetAttribute("ThemeRole", "CardBackground")
	menuFrame.Parent = screenGui or parentContainer

	if UIUtils.CreateCorner then UIUtils.CreateCorner(menuFrame, 8) end
	if UIUtils.CreateStroke then UIUtils.CreateStroke(menuFrame) end

	-- Standardized Header Bar
	headerFrame = Instance.new("Frame")
	headerFrame.Name = "Header"
	headerFrame.Size = UDim2.new(1, 0, 0, 30)
	headerFrame.BackgroundColor3 = C.SecondaryBg
	headerFrame:SetAttribute("ThemeRole", "SecondaryBackground")
	headerFrame.Parent = menuFrame

	if UIUtils.CreateCorner then UIUtils.CreateCorner(headerFrame, 8) end

	titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -30, 1, 0)
	titleLabel.Position = UDim2.new(0, 10, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "SOUNDFONTS"
	titleLabel.TextColor3 = C.TextColor
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 11
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel:SetAttribute("ThemeRole", "TextColor")
	titleLabel.Parent = headerFrame

	closeWindowBtn = Instance.new("TextButton")
	closeWindowBtn.Name = "CloseBtn"
	closeWindowBtn.Size = UDim2.new(0, 20, 0, 20)
	closeWindowBtn.Position = UDim2.new(1, -25, 0, 5)
	closeWindowBtn.BackgroundTransparency = 1
	closeWindowBtn.Text = "X"
	closeWindowBtn.TextColor3 = C.SubTextColor
	closeWindowBtn.Font = Enum.Font.GothamBold
	closeWindowBtn.TextSize = 12
	closeWindowBtn:SetAttribute("ThemeRole", "TextColor")
	closeWindowBtn.Parent = headerFrame

	closeWindowBtn.Activated:Connect(function()
		SoundfontPanel.ToggleMenu(false)
	end)

	if UIUtils.MakeDraggable then
		UIUtils.MakeDraggable(menuFrame, headerFrame)
	end

	-- Scrollable List Container
	scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "SoundfontList"
	scrollFrame.Size = UDim2.new(1, -12, 1, -38)
	scrollFrame.Position = UDim2.new(0, 6, 0, 34)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 4
	scrollFrame.ScrollBarImageColor3 = C.SecondaryBg
	scrollFrame.Parent = menuFrame

	listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.Name
	listLayout.Padding = UDim.new(0, 4)
	listLayout.Parent = scrollFrame

	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 6)
	end)

	RefreshSoundfontList()

	if targetSoundsFolder then
		targetSoundsFolder.ChildAdded:Connect(RefreshSoundfontList)
		targetSoundsFolder.ChildRemoved:Connect(function(child)
			if buttonMap[child.Name] then
				buttonMap[child.Name]:Destroy()
				buttonMap[child.Name] = nil
			end
		end)
	end
end

-- Dynamic Theme Engine Integration
function SoundfontPanel.ApplyTheme(themeOverride)
	if not menuFrame then return end
	if type(themeOverride) == "table" then
		activeTheme = themeOverride
	end

	local C = getThemeColors(activeTheme)

	menuFrame.BackgroundColor3 = C.MainBg
	local mainStroke = menuFrame:FindFirstChildOfClass("UIStroke")
	if mainStroke then mainStroke.Color = C.StrokeColor end

	if headerFrame then headerFrame.BackgroundColor3 = C.SecondaryBg end
	if titleLabel then titleLabel.TextColor3 = C.TextColor end
	if closeWindowBtn then closeWindowBtn.TextColor3 = C.SubTextColor end
	if scrollFrame then scrollFrame.ScrollBarImageColor3 = C.SecondaryBg end

	for name, btn in pairs(buttonMap) do
		local isSelected = hasUserSelected and (name == activeFontName)
		btn.BackgroundColor3 = isSelected and C.AccentColor or C.ButtonBg
		btn.TextColor3 = C.TextColor

		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = isSelected and C.AccentColor or C.StrokeColor
		end
	end
end

SoundfontPanel.UpdateTheme = SoundfontPanel.ApplyTheme
SoundfontPanel.RefreshTheme = SoundfontPanel.ApplyTheme
SoundfontPanel.SetTheme = SoundfontPanel.ApplyTheme

-- Core Logic & State Management
function SoundfontPanel.SelectSoundfont(fontName)
	activeFontName = fontName
	hasUserSelected = true
	SoundfontPanel.ApplyTheme()
end

function SoundfontPanel.GetActiveSoundfont()
	return activeFontName
end

function SoundfontPanel.ToggleMenu(overrideState)
	if not menuFrame then return end
	isOpen = (overrideState ~= nil) and overrideState or not isOpen
	menuFrame.Visible = isOpen
end

function SoundfontPanel.IsOpen()
	return isOpen
end

function SoundfontPanel.SetSoundfontCallback(callback)
	onSoundfontChangedCallback = callback
	SoundfontPanel.OnSoundfontChanged = callback
end

return SoundfontPanel