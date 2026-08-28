local SheetMusicPanel = {}

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local pianoUIFolder = script.Parent
local pianoModulesFolder = script.Parent.Parent
local MultiTransposeController = require(pianoModulesFolder:WaitForChild("MultiTransposeController"))

-- Unified Sibling Requires
local parentFolder = script.Parent
local UIUtils = require(parentFolder:WaitForChild("UIUtils"))
local CommunitySheetsPanel = require(parentFolder:WaitForChild("CommunitySheetsPanel"))
local MultiTransposePanel = require(parentFolder:WaitForChild("MultiTransposePanel"))

-- UI References
local sheetWindow = nil
local headerFrame = nil
local headerTitleLabel = nil
local closeWindowBtn = nil
local tabContainer = nil
local addTabButton = nil
local sidePanelFrame = nil
local scrollFrame = nil
local sheetTextBox = nil
local altScrollBtn = nil
local communityBtn = nil
local multiTransposeBtn = nil

-- Panel State
local activeTheme = nil
local communityPanelInstance = nil
local isOpen = false
local isAltScrollEnabled = false
local currentTextSize = 13

local onMultiTransposeRequested = nil
local onCommunityRequested = nil

-- Internal Tab Management State
local tabs = {}
local activeTabIndex = 1
local isSwitchingTab = false

-- Theme Helpers
local function getThemeColors(theme)
	local C = (type(UIUtils.GetActiveThemeColors) == "function" and UIUtils.GetActiveThemeColors(theme))
		or UIUtils.Theme 
		or UIUtils.Colors 
		or UIUtils.C 
		or {}

	return {
		MainBg = C.MainBg or C.CardBg or C.PanelBg or Color3.fromRGB(30, 30, 35),
		SecondaryBg = C.SecondaryBg or C.HeaderBg or C.CardBg or Color3.fromRGB(40, 40, 48),
		InputBg = C.InputBg or C.FieldBg or C.MainBg or Color3.fromRGB(22, 22, 26),
		TextColor = C.TextColor or C.TextMain or C.Text or Color3.fromRGB(255, 255, 255),
		SubTextColor = C.SubTextColor or C.TextSub or C.TextMuted or Color3.fromRGB(160, 160, 170),
		AccentColor = C.AccentColor or C.Accent or C.Highlight or Color3.fromRGB(80, 120, 200),
		StrokeColor = C.StrokeColor or C.Border or C.Stroke or Color3.fromRGB(50, 50, 60),
	}
end

-- Tab Helpers
local function ApplyTabThemes()
	local C = getThemeColors(activeTheme)
	for i, tab in ipairs(tabs) do
		if tab.Frame and tab.Frame.Parent then
			if i == activeTabIndex then
				tab.Frame.BackgroundColor3 = C.SecondaryBg
				tab.Button.TextColor3 = C.TextColor
				tab.CloseButton.TextColor3 = C.TextColor
				tab.Frame:SetAttribute("ThemeRole", "SecondaryBackground")
			else
				tab.Frame.BackgroundColor3 = C.InputBg
				tab.Button.TextColor3 = C.SubTextColor
				tab.CloseButton.TextColor3 = C.SubTextColor
				tab.Frame:SetAttribute("ThemeRole", "CardBackground")
			end

			local tabStroke = tab.Frame:FindFirstChildOfClass("UIStroke")
			if tabStroke then
				tabStroke.Color = C.StrokeColor
			end
		end
	end
end

local function SwitchTab(index)
	if not tabs[index] then return end
	activeTabIndex = index

	ApplyTabThemes()

	if sheetTextBox then
		isSwitchingTab = true
		sheetTextBox.Text = tabs[index].Content or ""
		isSwitchingTab = false
	end
end

local function CreateTab(titleText, initialContent)
	local C = getThemeColors(activeTheme)

	local tabFrame = Instance.new("Frame")
	tabFrame.Name = "TabFrame"
	tabFrame.Size = UDim2.new(0, 80, 0, 24)
	tabFrame.BackgroundColor3 = C.InputBg
	tabFrame:SetAttribute("ThemeRole", "CardBackground")
	tabFrame.Parent = tabContainer
	if UIUtils.CreateCorner then UIUtils.CreateCorner(tabFrame, 4) end

	local tabBtn = Instance.new("TextButton")
	tabBtn.Name = "TabButton"
	tabBtn.Size = UDim2.new(1, -18, 1, 0)
	tabBtn.BackgroundTransparency = 1
	tabBtn.Text = titleText
	tabBtn.TextColor3 = C.SubTextColor
	tabBtn.Font = Enum.Font.GothamBold
	tabBtn.TextSize = 10
	tabBtn:SetAttribute("ThemeRole", "TextColor")
	tabBtn.Parent = tabFrame

	local closeX = Instance.new("TextButton")
	closeX.Name = "CloseBtn"
	closeX.Size = UDim2.new(0, 14, 0, 14)
	closeX.Position = UDim2.new(1, -16, 0.5, -7)
	closeX.BackgroundTransparency = 1
	closeX.Text = "X"
	closeX.TextColor3 = C.SubTextColor
	closeX.Font = Enum.Font.GothamBold
	closeX.TextSize = 9
	closeX:SetAttribute("ThemeRole", "TextColor")
	closeX.Parent = tabFrame

	local tabData = {
		Title = titleText,
		Content = initialContent or "",
		Frame = tabFrame,
		Button = tabBtn,
		CloseButton = closeX
	}

	table.insert(tabs, tabData)
	local tabIdx = #tabs

	tabBtn.Activated:Connect(function()
		for i, t in ipairs(tabs) do
			if t == tabData then
				SwitchTab(i)
				break
			end
		end
	end)

	closeX.Activated:Connect(function()
		local removeIndex = nil
		for i, tab in ipairs(tabs) do
			if tab == tabData then
				removeIndex = i
				break
			end
		end
		if not removeIndex then return end

		tabData.Frame:Destroy()
		table.remove(tabs, removeIndex)

		if #tabs == 0 then
			CreateTab("Tab 1", "")
			return
		end

		local nextActive = math.clamp(activeTabIndex, 1, #tabs)
		if activeTabIndex > #tabs or activeTabIndex == removeIndex then
			nextActive = math.clamp(removeIndex - 1, 1, #tabs)
		end

		SwitchTab(nextActive)
	end)

	SwitchTab(tabIdx)
end

-- External Handlers Registration
function SheetMusicPanel.SetMultiTransposeCallback(callback)
	onMultiTransposeRequested = callback
end

function SheetMusicPanel.SetCommunityCallback(callback)
	onCommunityRequested = callback
end

function SheetMusicPanel.Init(screenGui, communityCallback)
	if sheetWindow then return end

	if communityCallback then
		onCommunityRequested = communityCallback
	end

	if CommunitySheetsPanel and type(CommunitySheetsPanel.Init) == "function" and not communityPanelInstance then
		communityPanelInstance = CommunitySheetsPanel.Init(screenGui, function(sheetTitle, sheetContent)
			SheetMusicPanel.LoadSheet(sheetTitle, sheetContent)
		end, activeTheme)
	end

	if MultiTransposePanel and type(MultiTransposePanel.Init) == "function" then
		MultiTransposePanel.Init(screenGui, function() return getThemeColors(activeTheme) end)

		if type(MultiTransposePanel.ToggleMenu) == "function" then
			MultiTransposePanel.ToggleMenu(false)
		elseif type(MultiTransposePanel.SetVisible) == "function" then
			MultiTransposePanel.SetVisible(false)
		end
	end

	local C = getThemeColors(activeTheme)

	sheetWindow = Instance.new("Frame")
	sheetWindow.Name = "SheetMusicWindow"
	sheetWindow.Size = UDim2.new(0, 480, 0, 360)
	sheetWindow.Position = UDim2.new(0.5, -240, 0.5, -180)
	sheetWindow.BackgroundColor3 = C.MainBg
	sheetWindow.ZIndex = 10
	sheetWindow.Visible = false
	sheetWindow:SetAttribute("ThemeRole", "CardBackground")
	sheetWindow.Parent = screenGui
	if UIUtils.CreateCorner then UIUtils.CreateCorner(sheetWindow, 8) end
	if UIUtils.CreateStroke then UIUtils.CreateStroke(sheetWindow) end

	headerFrame = Instance.new("Frame")
	headerFrame.Name = "Header"
	headerFrame.Size = UDim2.new(1, 0, 0, 30)
	headerFrame.BackgroundColor3 = C.MainBg
	headerFrame.ZIndex = 11
	headerFrame:SetAttribute("ThemeRole", "SecondaryBackground")
	headerFrame.Parent = sheetWindow
	if UIUtils.CreateCorner then UIUtils.CreateCorner(headerFrame, 8) end

	headerTitleLabel = Instance.new("TextLabel")
	headerTitleLabel.Size = UDim2.new(1, -30, 1, 0)
	headerTitleLabel.Position = UDim2.new(0, 10, 0, 0)
	headerTitleLabel.BackgroundTransparency = 1
	headerTitleLabel.Text = "QWERTY Sheets"
	headerTitleLabel.TextColor3 = C.TextColor
	headerTitleLabel.Font = Enum.Font.GothamBold
	headerTitleLabel.TextSize = 12
	headerTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	headerTitleLabel.ZIndex = 12
	headerTitleLabel:SetAttribute("ThemeRole", "TextColor")
	headerTitleLabel.Parent = headerFrame

	closeWindowBtn = Instance.new("TextButton")
	closeWindowBtn.Size = UDim2.new(0, 20, 0, 20)
	closeWindowBtn.Position = UDim2.new(1, -25, 0, 5)
	closeWindowBtn.BackgroundTransparency = 1
	closeWindowBtn.Text = "X"
	closeWindowBtn.TextColor3 = C.SubTextColor
	closeWindowBtn.Font = Enum.Font.GothamBold
	closeWindowBtn.TextSize = 12
	closeWindowBtn.ZIndex = 12
	closeWindowBtn:SetAttribute("ThemeRole", "TextColor")
	closeWindowBtn.Parent = headerFrame
	closeWindowBtn.Activated:Connect(function() SheetMusicPanel.ToggleMenu(false) end)

	if UIUtils.MakeDraggable then
		UIUtils.MakeDraggable(sheetWindow, headerFrame)
	end

	tabContainer = Instance.new("Frame")
	tabContainer.Name = "TabContainer"
	tabContainer.Size = UDim2.new(1, -60, 0, 26)
	tabContainer.Position = UDim2.new(0, 6, 0, 34)
	tabContainer.BackgroundTransparency = 1
	tabContainer.ZIndex = 11
	tabContainer.Parent = sheetWindow

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 4)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabContainer

	addTabButton = Instance.new("TextButton")
	addTabButton.Name = "AddTabBtn"
	addTabButton.Size = UDim2.new(0, 26, 0, 24)
	addTabButton.BackgroundColor3 = C.SecondaryBg
	addTabButton.Text = "+"
	addTabButton.TextColor3 = C.TextColor
	addTabButton.Font = Enum.Font.GothamBold
	addTabButton.TextSize = 14
	addTabButton.LayoutOrder = 999
	addTabButton.ZIndex = 12
	addTabButton:SetAttribute("ThemeRole", "ButtonBackground")
	addTabButton.Parent = tabContainer
	if UIUtils.CreateCorner then UIUtils.CreateCorner(addTabButton, 4) end
	addTabButton.Activated:Connect(function()
		CreateTab("Tab " .. (#tabs + 1), "")
	end)

	scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "SheetScrollFrame"
	scrollFrame.Size = UDim2.new(1, -60, 1, -96)
	scrollFrame.Position = UDim2.new(0, 6, 0, 64)
	scrollFrame.BackgroundColor3 = C.InputBg
	scrollFrame.ScrollBarImageColor3 = C.AccentColor
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.ZIndex = 11
	scrollFrame:SetAttribute("ThemeRole", "CardBackground")
	scrollFrame.Parent = sheetWindow
	if UIUtils.CreateCorner then UIUtils.CreateCorner(scrollFrame, 6) end

	sheetTextBox = Instance.new("TextBox")
	sheetTextBox.Name = "SheetTextBox"
	sheetTextBox.Size = UDim2.new(1, -12, 1, 0)
	sheetTextBox.Position = UDim2.new(0, 6, 0, 0)
	sheetTextBox.BackgroundTransparency = 1
	sheetTextBox.MultiLine = true
	sheetTextBox.ClearTextOnFocus = false
	sheetTextBox.TextWrapped = true
	sheetTextBox.TextColor3 = C.TextColor
	sheetTextBox.Font = Enum.Font.RobotoMono
	sheetTextBox.TextSize = currentTextSize
	sheetTextBox.TextXAlignment = Enum.TextXAlignment.Left
	sheetTextBox.TextYAlignment = Enum.TextYAlignment.Top
	sheetTextBox.PlaceholderText = "Paste or type QWERTY sheet music here..."
	sheetTextBox.ZIndex = 12
	sheetTextBox:SetAttribute("ThemeRole", "TextColor")
	sheetTextBox.Parent = scrollFrame

	sheetTextBox:GetPropertyChangedSignal("TextBounds"):Connect(function()
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, sheetTextBox.TextBounds.Y + 20)
	end)
	sheetTextBox:GetPropertyChangedSignal("Text"):Connect(function()
		if not isSwitchingTab and tabs[activeTabIndex] then
			tabs[activeTabIndex].Content = sheetTextBox.Text
		end
	end)

	sidePanelFrame = Instance.new("Frame")
	sidePanelFrame.Name = "SidePanel"
	sidePanelFrame.Size = UDim2.new(0, 42, 1, -68)
	sidePanelFrame.Position = UDim2.new(1, -48, 0, 64)
	sidePanelFrame.BackgroundColor3 = C.SecondaryBg
	sidePanelFrame.ZIndex = 11
	sidePanelFrame:SetAttribute("ThemeRole", "SecondaryBackground")
	sidePanelFrame.Parent = sheetWindow
	if UIUtils.CreateCorner then UIUtils.CreateCorner(sidePanelFrame, 6) end

	local sideLayout = Instance.new("UIListLayout")
	sideLayout.Padding = UDim.new(0, 6)
	sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sideLayout.Parent = sidePanelFrame

	altScrollBtn = Instance.new("TextButton")
	altScrollBtn.Name = "AltScrollBtn"
	altScrollBtn.Size = UDim2.new(0, 34, 0, 34)
	altScrollBtn.BackgroundColor3 = isAltScrollEnabled and C.AccentColor or C.SecondaryBg
	altScrollBtn.Text = "ALT\nSCR"
	altScrollBtn.TextColor3 = isAltScrollEnabled and C.TextColor or C.SubTextColor
	altScrollBtn.Font = Enum.Font.GothamBold
	altScrollBtn.TextSize = 8
	altScrollBtn.ZIndex = 12
	altScrollBtn:SetAttribute("ThemeRole", "ButtonBackground")
	altScrollBtn.Parent = sidePanelFrame
	if UIUtils.CreateCorner then UIUtils.CreateCorner(altScrollBtn, 6) end
	altScrollBtn.Activated:Connect(function()
		isAltScrollEnabled = not isAltScrollEnabled
		SheetMusicPanel.ApplyTheme()
	end)

	communityBtn = Instance.new("TextButton")
	communityBtn.Name = "CommunityBtn"
	communityBtn.Size = UDim2.new(0, 34, 0, 34)
	communityBtn.BackgroundColor3 = C.SecondaryBg
	communityBtn.Text = "COMM\nSHEETS"
	communityBtn.TextColor3 = C.SubTextColor
	communityBtn.Font = Enum.Font.GothamBold
	communityBtn.TextSize = 8
	communityBtn.ZIndex = 12
	communityBtn:SetAttribute("ThemeRole", "ButtonBackground")
	communityBtn.Parent = sidePanelFrame
	if UIUtils.CreateCorner then UIUtils.CreateCorner(communityBtn, 6) end

	communityBtn.Activated:Connect(function()
		if onCommunityRequested then
			onCommunityRequested()
		elseif communityPanelInstance then
			if type(communityPanelInstance.ToggleMenu) == "function" then
				communityPanelInstance:ToggleMenu()
			elseif type(communityPanelInstance.SetVisible) == "function" then
				local isCommOpen = (type(communityPanelInstance.IsOpen) == "function" and communityPanelInstance:IsOpen()) or false
				communityPanelInstance:SetVisible(not isCommOpen)
			end
		end
	end)

	multiTransposeBtn = Instance.new("TextButton")
	multiTransposeBtn.Name = "MultiTransposeBtn"
	multiTransposeBtn.Size = UDim2.new(0, 34, 0, 34)
	local isMTOpen = MultiTransposePanel and type(MultiTransposePanel.IsOpen) == "function" and MultiTransposePanel.IsOpen() or false
	multiTransposeBtn.BackgroundColor3 = isMTOpen and C.AccentColor or C.SecondaryBg
	multiTransposeBtn.Text = "MULTI\nTRSP"
	multiTransposeBtn.TextColor3 = isMTOpen and C.TextColor or C.SubTextColor
	multiTransposeBtn.Font = Enum.Font.GothamBold
	multiTransposeBtn.TextSize = 8
	multiTransposeBtn.ZIndex = 12
	multiTransposeBtn:SetAttribute("ThemeRole", "ButtonBackground")
	multiTransposeBtn.Parent = sidePanelFrame
	if UIUtils.CreateCorner then UIUtils.CreateCorner(multiTransposeBtn, 6) end
	multiTransposeBtn.Activated:Connect(function()
		if onMultiTransposeRequested then
			onMultiTransposeRequested()
		else
			SheetMusicPanel.ToggleMultiTranspose()
		end
	end)

	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt then
			SheetMusicPanel.ProcessAltScroll()
		end
	end)

	CreateTab("Tab 1", "")

	isOpen = false
	sheetWindow.Visible = false
	if MultiTransposePanel then
		if type(MultiTransposePanel.ToggleMenu) == "function" then
			MultiTransposePanel.ToggleMenu(false)
		elseif type(MultiTransposePanel.SetVisible) == "function" then
			MultiTransposePanel.SetVisible(false)
		end
	end

	SheetMusicPanel.ApplyTheme()
end

function SheetMusicPanel.ApplyTheme(themeOverride)
	if not sheetWindow then return end
	if type(themeOverride) == "table" then
		activeTheme = themeOverride
	end

	local C = getThemeColors(activeTheme)

	sheetWindow.BackgroundColor3 = C.MainBg
	local windowStroke = sheetWindow:FindFirstChildOfClass("UIStroke")
	if windowStroke then windowStroke.Color = C.StrokeColor end

	if headerFrame then headerFrame.BackgroundColor3 = C.MainBg end
	if headerTitleLabel then headerTitleLabel.TextColor3 = C.TextColor end
	if closeWindowBtn then closeWindowBtn.TextColor3 = C.SubTextColor end
	if addTabButton then
		addTabButton.BackgroundColor3 = C.SecondaryBg
		addTabButton.TextColor3 = C.TextColor
	end
	if sidePanelFrame then sidePanelFrame.BackgroundColor3 = C.SecondaryBg end
	if altScrollBtn then
		altScrollBtn.BackgroundColor3 = isAltScrollEnabled and C.AccentColor or C.SecondaryBg
		altScrollBtn.TextColor3 = isAltScrollEnabled and C.TextColor or C.SubTextColor
	end
	if communityBtn then
		local isCommOpen = communityPanelInstance and type(communityPanelInstance.IsOpen) == "function" and communityPanelInstance:IsOpen() or false
		communityBtn.BackgroundColor3 = isCommOpen and C.AccentColor or C.SecondaryBg
		communityBtn.TextColor3 = isCommOpen and C.TextColor or C.SubTextColor
	end
	if multiTransposeBtn then
		local isMTOpen = MultiTransposePanel and type(MultiTransposePanel.IsOpen) == "function" and MultiTransposePanel.IsOpen() or false
		multiTransposeBtn.BackgroundColor3 = isMTOpen and C.AccentColor or C.SecondaryBg
		multiTransposeBtn.TextColor3 = isMTOpen and C.TextColor or C.SubTextColor
	end
	if scrollFrame then
		scrollFrame.BackgroundColor3 = C.InputBg
		scrollFrame.ScrollBarImageColor3 = C.AccentColor
	end
	if sheetTextBox then sheetTextBox.TextColor3 = C.TextColor end

	ApplyTabThemes()

	if MultiTransposePanel and type(MultiTransposePanel.ApplyTheme) == "function" then
		MultiTransposePanel.ApplyTheme(C)
	end

	if communityPanelInstance and type(communityPanelInstance.ApplyTheme) == "function" then
		communityPanelInstance:ApplyTheme(activeTheme or C)
	elseif CommunitySheetsPanel and type(CommunitySheetsPanel.ApplyTheme) == "function" then
		CommunitySheetsPanel.ApplyTheme(activeTheme or C)
	end
end

SheetMusicPanel.UpdateTheme = SheetMusicPanel.ApplyTheme
SheetMusicPanel.RefreshTheme = SheetMusicPanel.ApplyTheme
SheetMusicPanel.SetTheme = SheetMusicPanel.ApplyTheme

function SheetMusicPanel.IsOpen()
	return isOpen
end

function SheetMusicPanel.SetVisible(visible)
	SheetMusicPanel.ToggleMenu(visible)
end

function SheetMusicPanel.ProcessAltScroll()
	if not isOpen or not isAltScrollEnabled or not scrollFrame then return end
	local currentY = scrollFrame.CanvasPosition.Y
	local maxY = math.max(0, scrollFrame.CanvasSize.Y.Offset - scrollFrame.AbsoluteWindowSize.Y)
	local newY = math.clamp(currentY + 45, 0, maxY)

	TweenService:Create(
		scrollFrame,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CanvasPosition = Vector2.new(0, newY) }
	):Play()
end

function SheetMusicPanel.ToggleMenu(overrideState)
	isOpen = (overrideState ~= nil) and overrideState or not isOpen
	sheetWindow.Visible = isOpen

	-- Automatically clean up sub-panels when closing sheet window
	if not isOpen then
		if MultiTransposePanel then
			if type(MultiTransposePanel.ToggleMenu) == "function" then
				MultiTransposePanel.ToggleMenu(false)
			elseif type(MultiTransposePanel.SetVisible) == "function" then
				MultiTransposePanel.SetVisible(false)
			end
		end

		if communityPanelInstance then
			if type(communityPanelInstance.ToggleMenu) == "function" then
				communityPanelInstance:ToggleMenu(false)
			elseif type(communityPanelInstance.SetVisible) == "function" then
				communityPanelInstance:SetVisible(false)
			end
		end
	end

	SheetMusicPanel.ApplyTheme()
end

function SheetMusicPanel.LoadSheet(title, content)
	local activeTab = tabs[activeTabIndex]
	if activeTab and (activeTab.Content == "" or activeTab.Content == nil) then
		activeTab.Title = title or activeTab.Title
		activeTab.Button.Text = activeTab.Title
		activeTab.Content = content or ""
		if sheetTextBox then
			sheetTextBox.Text = activeTab.Content
		end
	else
		CreateTab(title or ("Tab " .. (#tabs + 1)), content or "")
	end
end

function SheetMusicPanel.ToggleMultiTranspose(overrideState)
	if MultiTransposePanel then
		if type(MultiTransposePanel.ToggleMenu) == "function" then
			MultiTransposePanel.ToggleMenu(overrideState)
		elseif type(MultiTransposePanel.SetVisible) == "function" then
			local currentState = type(MultiTransposePanel.IsOpen) == "function" and MultiTransposePanel.IsOpen() or false
			local newState = (overrideState ~= nil) and overrideState or not currentState
			MultiTransposePanel.SetVisible(newState)
		end
	end
	SheetMusicPanel.ApplyTheme()
end

function SheetMusicPanel.SetTransposeSequence(seq)
	if MultiTransposeController and type(MultiTransposeController.SetSequence) == "function" then
		MultiTransposeController.SetSequence(seq)
	elseif MultiTransposePanel and type(MultiTransposePanel.SetSequence) == "function" then
		MultiTransposePanel.SetSequence(seq)
	end
end

function SheetMusicPanel.NextTranspose()
	if MultiTransposeController and type(MultiTransposeController.Next) == "function" then
		MultiTransposeController.Next()
	elseif MultiTransposePanel and type(MultiTransposePanel.Next) == "function" then
		MultiTransposePanel.Next()
	end
end

function SheetMusicPanel.PrevTranspose()
	if MultiTransposeController and type(MultiTransposeController.Previous) == "function" then
		MultiTransposeController.Previous()
	elseif MultiTransposePanel and type(MultiTransposePanel.Previous) == "function" then
		MultiTransposePanel.Previous()
	end
end

function SheetMusicPanel.SetOnTransposeChanged(cb)
	if MultiTransposeController and type(MultiTransposeController.SetOnTransposeChanged) == "function" then
		MultiTransposeController.SetOnTransposeChanged(cb)
	elseif MultiTransposePanel and type(MultiTransposePanel.SetOnTransposeChanged) == "function" then
		MultiTransposePanel.SetOnTransposeChanged(cb)
	end
end

return SheetMusicPanel