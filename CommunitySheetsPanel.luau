local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

-- Helper to safely find and require modules whether they are children or siblings inside PianoUI
local function getModule(name)
	local found = script:FindFirstChild(name) or (script.Parent and script.Parent:FindFirstChild(name))
	if not found then
		found = script:WaitForChild(name, 3) or (script.Parent and script.Parent:WaitForChild(name, 3))
	end
	if not found then
		error(string.format("[CommunitySheetsPanel] Failed to find module '%s'", tostring(name)))
	end
	return require(found)
end

local UIUtils = getModule("UIUtils")
local Service = getModule("CommunitySheetsService")
local PreviewPanel = getModule("SheetPreviewPanel")
local UploadModal = getModule("UploadModal")
local GenreManager = getModule("GenreManager")

local ThemeManager
pcall(function()
	ThemeManager = require(ReplicatedStorage:WaitForChild("PianoModules", 3):WaitForChild("ThemeManager", 3))
end)

local CommunitySheetsPanel = {}
CommunitySheetsPanel.__index = CommunitySheetsPanel

local DIFFICULTY_RANKS = { Easy = 1, Medium = 2, Hard = 3 }

local function AddOrUpdateBorder(parent, color, thickness)
	if not parent or not color then return end
	local stroke = parent:FindFirstChild("BorderStroke")
	if not stroke then
		stroke = UIUtils.makeElement("UIStroke", {
			Name = "BorderStroke",
			Color = color,
			Thickness = thickness or 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = parent
		})
	else
		stroke.Color = color
		if thickness then stroke.Thickness = thickness end
	end
	return stroke
end

-- Strictly checks both naming schemes (PascalCase & SCREAMING_SNAKE_CASE) and routes to UIUtils
local function GetActiveThemeColors(activeTheme)
	local rawC = {}
	if type(activeTheme) == "table" and next(activeTheme) then
		rawC = activeTheme
	elseif type(UIUtils) == "table" then
		if type(UIUtils.GetActiveThemeColors) == "function" then
			rawC = UIUtils.GetActiveThemeColors(activeTheme) or {}
		elseif type(UIUtils.GetTheme) == "function" then
			rawC = UIUtils.GetTheme(activeTheme) or {}
		elseif type(UIUtils.GetColors) == "function" then
			rawC = UIUtils.GetColors(activeTheme) or {}
		else
			rawC = UIUtils.Theme or UIUtils.Colors or UIUtils.C or {}
		end
	end

	local U = (type(UIUtils) == "table" and (UIUtils.Colors or UIUtils.C or UIUtils.Theme)) or {}

	return {
		MainBg           = rawC.MainBg or rawC.MAIN_BG or U.MAIN_BG or U.BG_DARK or U.CARD_BG,
		PanelBg          = rawC.PanelBg or rawC.PANEL_BG or U.PANEL_BG or U.CARD_BG or U.MAIN_BG,
		CardBg           = rawC.CardBg or rawC.CARD_BG or U.CARD_BG or U.PANEL_BG or U.MAIN_BG,
		CardSelect       = rawC.CardSelect or rawC.CARD_SELECT or rawC.Selected or U.CARD_SELECT or U.ACCENT,
		InputBg          = rawC.InputBg or rawC.INPUT_BG or U.INPUT_BG or U.BG_DARK or U.CARD_BG,
		TextMain         = rawC.TextMain or rawC.TEXT_MAIN or rawC.TextColor or U.TEXT_MAIN or U.TEXT_ON,
		TextMuted        = rawC.TextMuted or rawC.TEXT_MUTED or U.TEXT_MUTED or U.TEXT_SUB or U.TEXT_MAIN,
		TextLight        = rawC.TextLight or rawC.TEXT_LIGHT or U.TEXT_LIGHT or U.TEXT_MAIN,
		TextDark         = rawC.TextDark or rawC.TEXT_DARK or U.TEXT_DARK or U.TEXT_MAIN,
		Border           = rawC.Border or rawC.BORDER or rawC.StrokeColor or rawC.STROKE_DEFAULT or U.BORDER or U.STROKE_DEFAULT,
		Accent           = rawC.Accent or rawC.ACCENT or U.ACCENT,
		AccentGreen      = rawC.AccentGreen or rawC.ACCENT_GREEN or rawC.Green or U.ACCENT_GREEN or U.ACCENT,
		CloseRed         = rawC.CloseRed or rawC.CLOSE_RED or rawC.Red or U.CLOSE_RED or U.ACCENT,
		DifficultyYellow = rawC.DifficultyYellow or rawC.DIFFICULTY_YELLOW or rawC.Yellow or U.DIFFICULTY_YELLOW or U.ACCENT,
		White            = rawC.White or rawC.WHITE or U.WHITE or U.TEXT_MAIN,
	}
end

local function isOwnerOrAuthor(authorId)
	if not LocalPlayer then return false end

	local numericAuthor = tonumber(authorId)
	if numericAuthor and numericAuthor == LocalPlayer.UserId then return true end

	local success, result = pcall(function()
		if game.CreatorType == Enum.CreatorType.Group then
			return game.CreatorId > 0 and LocalPlayer:GetRankInGroup(game.CreatorId) == 255
		end
		return LocalPlayer.UserId == game.CreatorId
	end)
	return success and result == true
end

function CommunitySheetsPanel.new(parentGui, onLoadToTabCallback, activeTheme)
	local self = setmetatable({}, CommunitySheetsPanel)
	self.ActiveSortMode = "Newest"
	self.AllFetchedSheets = {}
	self.OnLoadToTab = onLoadToTabCallback
	self.ActiveTheme = activeTheme
	self.CardPool = {}
	self.CardSheetMap = {}
	self._cardConnections = {}
	self._searchThread = nil

	local C = GetActiveThemeColors(self.ActiveTheme)
	local makeElement = UIUtils.makeElement

	-- Window
	local window = makeElement("Frame", {
		Name = "CommunitySheetsWindow",
		Size = UDim2.new(0, 800, 0, 560),
		Position = UDim2.new(0.5, -400, 0.5, -280),
		BackgroundColor3 = C.MainBg,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Visible = false,
		Parent = parentGui
	}, 8)
	window:SetAttribute("ForceSolid", true)
	self.Window = window
	AddOrUpdateBorder(window, C.Border, 1.5)

	-- Top Bar
	local topBar = makeElement("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = C.PanelBg,
		BorderSizePixel = 0,
		Parent = window
	}, 8)
	self.TopBar = topBar
	AddOrUpdateBorder(topBar, C.Border, 1)
	UIUtils.MakeDraggable(window, topBar)

	self.HeaderTitleLabel = makeElement("TextLabel", {
		Name = "HeaderTitleLabel",
		Size = UDim2.new(0, 170, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		BackgroundTransparency = 1,
		Text = "Community Sheets",
		TextColor3 = C.TextMain,
		TextSize = 15,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = topBar
	})

	local searchBox = makeElement("TextBox", {
		Name = "SearchBox",
		Size = UDim2.new(0, 220, 0, 28),
		Position = UDim2.new(0, 185, 0.5, -14),
		BackgroundColor3 = C.InputBg,
		Text = "",
		TextColor3 = C.TextMain,
		PlaceholderText = "Search title, artist, author...",
		PlaceholderColor3 = C.TextMuted,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		ClearTextOnFocus = false,
		Parent = topBar
	}, 4, {0, 8, 0, 8})
	self.SearchBox = searchBox
	AddOrUpdateBorder(searchBox, C.Border, 1)

	local sortBtn = makeElement("TextButton", {
		Name = "SortButton",
		Size = UDim2.new(0, 105, 0, 28),
		Position = UDim2.new(0, 412, 0.5, -14),
		BackgroundColor3 = C.CardBg,
		Text = "Sort: Newest",
		TextColor3 = C.TextMain,
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		Parent = topBar
	}, 4)
	self.SortBtn = sortBtn
	AddOrUpdateBorder(sortBtn, C.Border, 1)

	local uploadBtn = makeElement("TextButton", {
		Name = "UploadButton",
		Size = UDim2.new(0, 110, 0, 28),
		Position = UDim2.new(1, -152, 0.5, -14),
		BackgroundColor3 = C.AccentGreen,
		Text = "+ Upload Sheet",
		TextColor3 = C.TextLight or C.White,
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		Parent = topBar
	}, 4)
	self.UploadBtn = uploadBtn
	AddOrUpdateBorder(uploadBtn, C.Border, 1)

	local closeBtn = makeElement("TextButton", {
		Name = "CloseButton",
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(1, -36, 0.5, -14),
		BackgroundColor3 = C.CloseRed,
		Text = "X",
		TextColor3 = C.TextLight or C.White,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		Parent = topBar
	}, 4)
	self.CloseBtn = closeBtn
	AddOrUpdateBorder(closeBtn, C.Border, 1)

	-- Genre Bar
	local genreBar = makeElement("ScrollingFrame", {
		Name = "GenreBar",
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.new(0, 10, 0, 50),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness = 2,
		BackgroundTransparency = 1,
		Parent = window
	})
	self.GenreBar = genreBar

	local genreLayout = makeElement("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		Parent = genreBar
	})

	genreLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		genreBar.CanvasSize = UDim2.new(0, genreLayout.AbsoluteContentSize.X + 10, 0, 0)
	end)

	-- Body Split Container
	local bodyFrame = makeElement("Frame", {
		Name = "BodyFrame",
		Size = UDim2.new(1, -20, 1, -94),
		Position = UDim2.new(0, 10, 0, 86),
		BackgroundTransparency = 1,
		Parent = window
	})
	self.BodyFrame = bodyFrame

	local listContainer = makeElement("ScrollingFrame", {
		Name = "CommunitySheetsList",
		Size = UDim2.new(0, 330, 1, 0),
		BackgroundColor3 = C.PanelBg,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.TextMuted,
		Parent = bodyFrame
	}, 6, {6, 6, 6, 6})
	listContainer:SetAttribute("ForceSolid", true)
	self.ListContainer = listContainer
	AddOrUpdateBorder(listContainer, C.Border, 1)

	local listLayout = makeElement("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = listContainer
	})

	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		listContainer.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 12)
	end)

	-- Initialize Sub-Modules
	self.Preview = PreviewPanel.new(
		bodyFrame,
		UIUtils,
		Service,
		isOwnerOrAuthor,
		function(sheet)
			local callback = self.OnLoadToTab or onLoadToTabCallback
			if callback then
				callback(sheet)
				window.Visible = false
			end
		end,
		nil,
		C
	)

	self.GenreManager = GenreManager.new(
		genreBar,
		Service,
		UIUtils,
		function(authorId)
			return isOwnerOrAuthor(authorId)
		end,
		function(selectedGenre)
			if self.Preview and type(self.Preview.Clear) == "function" then
				self.Preview:Clear()
			end
			self:ApplyFiltersAndRender()
		end,
		C
	)

	self.UploadModal = UploadModal.new(
		window,
		UIUtils,
		Service,
		function(newUploadedSheet)
			if newUploadedSheet and type(newUploadedSheet) == "table" then
				table.insert(self.AllFetchedSheets, 1, newUploadedSheet)
				self:ApplyFiltersAndRender()
			else
				self:FetchSheets()
			end
		end,
		self.GenreManager,
		C
	)

	-- Bind Delete Action
	if self.Preview and self.Preview.DeleteBtn then
		self.Preview.DeleteBtn.Activated:Connect(function()
			if not self.Preview.SelectedSheet then return end
			local targetSheet = self.Preview.SelectedSheet
			self.Preview.DeleteBtn.Active = false
			self.Preview.DeleteBtn.Text = "..."

			local pcallSuccess, serverSuccess = pcall(function()
				if type(Service.DeleteSheet) == "function" then
					return Service:DeleteSheet(targetSheet.Id or targetSheet.Title)
				elseif type(Service.deleteSheet) == "function" then
					return Service:deleteSheet(targetSheet.Id or targetSheet.Title)
				end
			end)

			self.Preview.DeleteBtn.Active = true
			self.Preview.DeleteBtn.Text = "Delete"

			if pcallSuccess and serverSuccess then
				self.Preview:Clear()
				if self.GenreManager then
					self.GenreManager:Refresh(GetActiveThemeColors(self.ActiveTheme))
				end
				self:FetchSheets()
			end
		end)
	end

	-- Trailing Debounced Search Input
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		if self._searchThread then
			task.cancel(self._searchThread)
		end
		self._searchThread = task.delay(0.15, function()
			self._searchThread = nil
			self:ApplyFiltersAndRender()
		end)
	end)

	sortBtn.Activated:Connect(function()
		if self.ActiveSortMode == "Newest" then
			self.ActiveSortMode = "Most Liked"
		elseif self.ActiveSortMode == "Most Liked" then
			self.ActiveSortMode = "Difficulty"
		else
			self.ActiveSortMode = "Newest"
		end
		sortBtn.Text = "Sort: " .. self.ActiveSortMode
		self:ApplyFiltersAndRender()
	end)

	uploadBtn.Activated:Connect(function()
		if self.UploadModal then self.UploadModal:Open(self.GenreManager) end
	end)

	closeBtn.Activated:Connect(function()
		window.Visible = false
	end)

	-- Listen for dynamic ThemeManager changes
	self:ApplyTheme(self.ActiveTheme)
	return self
end

--------------------------------------------------------------------------------
-- CLASS PROTOTYPE METHODS
--------------------------------------------------------------------------------

function CommunitySheetsPanel:UpdateSheetCardsTheme(activeColors)
	local C = activeColors or GetActiveThemeColors(self.ActiveTheme)

	if self.CardPool then
		for _, card in ipairs(self.CardPool) do
			if card and card.Visible then
				local sheet = self.CardSheetMap and self.CardSheetMap[card]
				local isSelected = (self.Preview and self.Preview.SelectedSheet and self.Preview.SelectedSheet == sheet)
				card.BackgroundColor3 = isSelected and C.CardSelect or C.CardBg
				AddOrUpdateBorder(card, isSelected and C.Accent or C.Border, 1)

				local titleLbl = card:FindFirstChild("CardTitle")
				if titleLbl then titleLbl.TextColor3 = C.TextMain end

				local metaLbl = card:FindFirstChild("CardMeta")
				if metaLbl then metaLbl.TextColor3 = C.TextMuted end
			end
		end
	end

	if self.ListContainer then
		local noSheetsLabel = self.ListContainer:FindFirstChild("NoSheetsLabel")
		if noSheetsLabel then
			noSheetsLabel.TextColor3 = C.TextMuted
		end
	end
end

function CommunitySheetsPanel:GetCardFromPool(index)
	self.CardPool = self.CardPool or {}
	if self.CardPool[index] then
		self.CardPool[index].Visible = true
		return self.CardPool[index]
	end

	local C = GetActiveThemeColors(self.ActiveTheme)

	local card = UIUtils.makeElement("TextButton", {
		Name = "SheetCard_" .. index,
		Size = UDim2.new(1, -6, 0, 52),
		BackgroundColor3 = C.CardBg,
		Text = "",
		AutoButtonColor = false,
		Parent = self.ListContainer
	}, 6)

	UIUtils.makeElement("TextLabel", {
		Name = "CardTitle",
		Size = UDim2.new(1, -70, 0, 20),
		Position = UDim2.new(0, 8, 0, 6),
		BackgroundTransparency = 1,
		Text = "Untitled",
		TextColor3 = C.TextMain,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card
	})

	UIUtils.makeElement("TextLabel", {
		Name = "CardMeta",
		Size = UDim2.new(1, -70, 0, 18),
		Position = UDim2.new(0, 8, 0, 26),
		BackgroundTransparency = 1,
		Text = "Unknown",
		TextColor3 = C.TextMuted,
		TextSize = 10,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card
	})

	UIUtils.makeElement("TextLabel", {
		Name = "DifficultyBadge",
		Size = UDim2.new(0, 50, 0, 20),
		Position = UDim2.new(1, -56, 0, 6),
		BackgroundColor3 = C.DifficultyYellow or C.Accent,
		Text = "Medium",
		TextColor3 = C.TextDark or C.MainBg,
		TextSize = 9,
		Font = Enum.Font.GothamBold,
		Parent = card
	}, 4)

	AddOrUpdateBorder(card, C.Border, 1)

	self.CardPool[index] = card
	return card
end

function CommunitySheetsPanel:ApplyFiltersAndRender()
	local activeColors = GetActiveThemeColors(self.ActiveTheme)

	-- Disconnect all previous card listeners to avoid duplicate connections
	if self._cardConnections then
		for card, conn in pairs(self._cardConnections) do
			if conn and conn.Connected then
				conn:Disconnect()
			end
		end
		table.clear(self._cardConnections)
	else
		self._cardConnections = {}
	end

	-- Reset pooled cards and mappings
	for _, card in ipairs(self.CardPool) do
		card.Visible = false
		if self.CardSheetMap then
			self.CardSheetMap[card] = nil
		end
	end

	local noSheetsLabel = self.ListContainer:FindFirstChild("NoSheetsLabel")
	if noSheetsLabel then
		noSheetsLabel.Visible = false
	end

	local query = self.SearchBox.Text:lower()
	local activeGenre = self.GenreManager and self.GenreManager.ActiveGenre or "All"
	local filtered = {}

	for _, sheet in ipairs(self.AllFetchedSheets) do
		local matchesGenre = (activeGenre == "All" or activeGenre == "" or sheet.Genre == activeGenre)
		local matchesSearch = (query == ""
			or (sheet.Title and sheet.Title:lower():find(query, 1, true))
			or (sheet.Artist and sheet.Artist:lower():find(query, 1, true))
			or (sheet.Author and sheet.Author:lower():find(query, 1, true)))

		if matchesGenre and matchesSearch then
			table.insert(filtered, sheet)
		end
	end

	table.sort(filtered, function(a, b)
		if self.ActiveSortMode == "Most Liked" then
			return (a.Likes or 0) > (b.Likes or 0)
		elseif self.ActiveSortMode == "Difficulty" then
			local rankA = DIFFICULTY_RANKS[a.Difficulty] or 2
			local rankB = DIFFICULTY_RANKS[b.Difficulty] or 2
			return rankA < rankB
		else
			return (a.CreatedAt or 0) > (b.CreatedAt or 0)
		end
	end)

	if #filtered == 0 then
		if not noSheetsLabel then
			noSheetsLabel = UIUtils.makeElement("TextLabel", {
				Name = "NoSheetsLabel",
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundTransparency = 1,
				Text = "No community sheets found.",
				TextColor3 = activeColors.TextMuted,
				TextSize = 12,
				Font = Enum.Font.Gotham,
				Parent = self.ListContainer
			})
		end
		noSheetsLabel.TextColor3 = activeColors.TextMuted
		noSheetsLabel.Visible = true
		return
	end

	for index, sheet in ipairs(filtered) do
		local card = self:GetCardFromPool(index)
		self.CardSheetMap[card] = sheet
		local isSelected = (self.Preview and self.Preview.SelectedSheet == sheet)

		card.Name = "SheetCard_" .. (sheet.Title or "Item")
		card.BackgroundColor3 = isSelected and activeColors.CardSelect or activeColors.CardBg
		card.LayoutOrder = index
		AddOrUpdateBorder(card, isSelected and activeColors.Accent or activeColors.Border, 1)

		local titleLbl = card:FindFirstChild("CardTitle")
		if titleLbl then
			titleLbl.Text = sheet.Title or "Untitled"
			titleLbl.TextColor3 = activeColors.TextMain
		end

		local tagDiff = sheet.Difficulty or "Medium"
		local diffColor = (UIUtils.getDifficultyColor and UIUtils.getDifficultyColor(tagDiff)) or activeColors.DifficultyYellow or activeColors.Accent
		local diffBadge = card:FindFirstChild("DifficultyBadge")
		if diffBadge then
			diffBadge.Text = tagDiff
			diffBadge.BackgroundColor3 = diffColor
		end

		local genreTag = (sheet.Genre and sheet.Genre ~= "") and (" [" .. sheet.Genre .. "]") or ""
		local likesTag = " • ?? " .. (sheet.Likes or 0)
		local metaLbl = card:FindFirstChild("CardMeta")
		if metaLbl then
			metaLbl.Text = (sheet.Artist or "Unknown") .. genreTag .. likesTag .. " • By " .. (sheet.Author or "Anon")
			metaLbl.TextColor3 = activeColors.TextMuted
		end

		self._cardConnections[card] = card.Activated:Connect(function()
			local currentColors = GetActiveThemeColors(self.ActiveTheme)
			if self.Preview then
				self.Preview:DisplaySheet(sheet, isOwnerOrAuthor(sheet.AuthorId))
			end
			for _, pooledCard in ipairs(self.CardPool) do
				if pooledCard.Visible then
					local pooledSelected = (self.CardSheetMap[pooledCard] == sheet)
					pooledCard.BackgroundColor3 = pooledSelected and currentColors.CardSelect or currentColors.CardBg
					AddOrUpdateBorder(pooledCard, pooledSelected and currentColors.Accent or currentColors.Border, 1)
				end
			end
		end)
	end
end

function CommunitySheetsPanel:FetchSheets()
	local sheets
	if type(Service) == "table" then
		local success, result = pcall(function()
			if type(Service.FetchAllSheets) == "function" then
				return Service:FetchAllSheets()
			elseif type(Service.fetchAllSheets) == "function" then
				return Service:fetchAllSheets()
			end
		end)
		if success and type(result) == "table" then sheets = result end
	end
	self.AllFetchedSheets = sheets or {}
	self:ApplyFiltersAndRender()
end

function CommunitySheetsPanel:AddGenre(genreName)
	if self.GenreManager then
		self.GenreManager:AddGenre(genreName, GetActiveThemeColors(self.ActiveTheme))
	end
end

function CommunitySheetsPanel:RemoveGenre(genreName)
	if self.GenreManager then
		self.GenreManager:RemoveGenre(genreName, GetActiveThemeColors(self.ActiveTheme))
	end
end

function CommunitySheetsPanel:ApplyTheme(themeOverride)
	if type(themeOverride) == "table" then
		self.ActiveTheme = themeOverride
	else
		self.ActiveTheme = nil
	end

	local C = GetActiveThemeColors(self.ActiveTheme)

	if ThemeManager and ThemeManager.CurrentTheme and self.Window and type(ThemeManager.ApplyToInstance) == "function" then
		ThemeManager.ApplyToInstance(self.Window, ThemeManager.CurrentTheme)
	end

	if self.Window then
		self.Window.BackgroundColor3 = C.MainBg
		AddOrUpdateBorder(self.Window, C.Border, 1.5)
	end
	if self.TopBar then
		self.TopBar.BackgroundColor3 = C.PanelBg
		AddOrUpdateBorder(self.TopBar, C.Border, 1)
	end
	if self.HeaderTitleLabel then self.HeaderTitleLabel.TextColor3 = C.TextMain end
	if self.SearchBox then
		self.SearchBox.BackgroundColor3 = C.InputBg
		self.SearchBox.TextColor3 = C.TextMain
		self.SearchBox.PlaceholderColor3 = C.TextMuted
		AddOrUpdateBorder(self.SearchBox, C.Border, 1)
	end
	if self.SortBtn then
		self.SortBtn.BackgroundColor3 = C.CardBg
		self.SortBtn.TextColor3 = C.TextMain
		AddOrUpdateBorder(self.SortBtn, C.Border, 1)
	end
	if self.UploadBtn then
		self.UploadBtn.BackgroundColor3 = C.AccentGreen
		self.UploadBtn.TextColor3 = C.TextLight or C.White
		AddOrUpdateBorder(self.UploadBtn, C.Border, 1)
	end
	if self.CloseBtn then
		self.CloseBtn.BackgroundColor3 = C.CloseRed
		self.CloseBtn.TextColor3 = C.TextLight or C.White
		AddOrUpdateBorder(self.CloseBtn, C.Border, 1)
	end
	if self.ListContainer then
		self.ListContainer.BackgroundColor3 = C.PanelBg
		self.ListContainer.ScrollBarImageColor3 = C.TextMuted
		AddOrUpdateBorder(self.ListContainer, C.Border, 1)
	end

	if self.GenreManager and type(self.GenreManager.ApplyTheme) == "function" then
		self.GenreManager:ApplyTheme(C)
	end

	if typeof(self.UpdateSheetCardsTheme) == "function" then
		self:UpdateSheetCardsTheme(C)
	end

	if self.Preview and type(self.Preview.ApplyTheme) == "function" then
		self.Preview:ApplyTheme(C)
	end
	if self.UploadModal and type(self.UploadModal.ApplyTheme) == "function" then
		self.UploadModal:ApplyTheme(C)
	end
end

CommunitySheetsPanel.UpdateTheme = CommunitySheetsPanel.ApplyTheme
CommunitySheetsPanel.RefreshTheme = CommunitySheetsPanel.ApplyTheme

function CommunitySheetsPanel:SetVisible(visible)
	if not self or type(self) ~= "table" or not self.Window then
		warn("[CommunitySheetsPanel] SetVisible was called on an uninitialized panel!")
		return
	end

	self.Window.Visible = visible
	if visible then
		task.spawn(function()
			if self.GenreManager then
				self.GenreManager:Refresh(GetActiveThemeColors(self.ActiveTheme))
			end
			self:FetchSheets()
		end)
	end
end

function CommunitySheetsPanel:ToggleMenu(overrideState)
	if not self or typeof(self) ~= "table" or not self.Window then
		warn("[CommunitySheetsPanel] ToggleMenu was called without a valid panel instance!")
		return
	end

	local newState = (overrideState ~= nil and type(overrideState) == "boolean") and overrideState or not self.Window.Visible
	self:SetVisible(newState)
end

function CommunitySheetsPanel:SetLoadCallback(callback)
	self.OnLoadToTab = callback
end

CommunitySheetsPanel.Init = CommunitySheetsPanel.new

return CommunitySheetsPanel