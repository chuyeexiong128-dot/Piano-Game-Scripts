local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PianoUI = ReplicatedStorage.PianoModules.PianoUI

local UIUtils = require(PianoUI:WaitForChild("UIUtils"))
local GenreModal = require(script:WaitForChild("GenreModal"))

local GenreManager = {}
GenreManager.__index = GenreManager

local function GetActiveThemeColors(activeTheme)
	local theme = (type(activeTheme) == "table" and activeTheme) or {}

	if type(theme.Colors) == "table" then
		theme = theme.Colors
	end

	return {
		MainBg = theme.MainBg or theme.MainBackground or theme.BG_DARK or theme.Background or theme.BG or theme.WindowBg or theme.WindowColor or theme.PanelColor or theme.BG_COLOR or Color3.fromRGB(30, 30, 38),
		PanelBg = theme.PanelBg or theme.PANEL_BG or theme.SecondaryBackground or theme.SecondaryBg or theme.SidePanelColor or theme.ContainerBg or theme.ContentBg or Color3.fromRGB(38, 40, 48),
		CardBg = theme.CardBg or theme.CARD_BG or theme.SecondaryBackground or theme.SecondaryBg or theme.ButtonBackground or theme.ItemBg or Color3.fromRGB(44, 46, 56),
		CardSelect = theme.CardSelect or theme.CARD_SELECT or theme.Highlight or theme.AccentColor or theme.Accent or Color3.fromRGB(60, 64, 80),
		InputBg = theme.InputBg or theme.INPUT_BG or theme.TextBoxBg or Color3.fromRGB(24, 25, 30),
		TextMain = theme.TextMain or theme.TEXT_MAIN or theme.TextColor or theme.Text or theme.PrimaryText or Color3.fromRGB(230, 230, 240),
		TextMuted = theme.TextMuted or theme.TEXT_MUTED or theme.SubTextColor or theme.SecondaryText or Color3.fromRGB(150, 150, 160),
		Accent = theme.Accent or theme.ACCENT or theme.AccentColor or theme.Highlight or Color3.fromRGB(46, 204, 113),
		AccentGreen = theme.AccentGreen or theme.ACCENT_GREEN or theme.Success or Color3.fromRGB(46, 204, 113),
		CloseRed = theme.CloseRed or theme.CLOSE_RED or theme.Danger or theme.Error or Color3.fromRGB(231, 76, 60),
	}
end

function GenreManager.new(genreBar, service, uiUtils, isOwnerOrAuthorCheck, onGenreSelectedCallback, activeTheme)
	local self = setmetatable({}, GenreManager)
	self.GenreBar = genreBar
	self.Service = service
	self.UIUtils = uiUtils or UIUtils
	self.IsOwnerOrAuthor = isOwnerOrAuthorCheck
	self.OnGenreSelected = onGenreSelectedCallback
	self.ActiveTheme = (type(activeTheme) == "table") and activeTheme or nil
	self.ActiveGenre = "All"
	self.CustomGenres = {}
	self.DisabledGenres = {}
	self.CustomOrder = {}
	self.GenrePillsMap = {}
	self.ActiveModal = nil

	return self
end

function GenreManager:GetAvailableGenres(includeAll)
	local fetched = (self.Service and type(self.Service.FetchGenres) == "function" and self.Service.FetchGenres()) or {}
	local genreSet = { ["All"] = true, ["Uncategorized"] = true }
	local middleGenres = {}

	for _, gName in ipairs(self.CustomOrder or {}) do
		if not genreSet[gName] then
			genreSet[gName] = true
			table.insert(middleGenres, gName)
		end
	end

	for _, gName in ipairs(fetched) do
		if not genreSet[gName] then
			genreSet[gName] = true
			table.insert(middleGenres, gName)
		end
	end

	for _, gName in ipairs(self.CustomGenres or {}) do
		if not genreSet[gName] then
			genreSet[gName] = true
			table.insert(middleGenres, gName)
		end
	end

	local result = {}
	if includeAll then
		table.insert(result, "All")
	end

	for _, gName in ipairs(middleGenres) do
		if not (self.DisabledGenres and self.DisabledGenres[gName]) then
			table.insert(result, gName)
		end
	end

	table.insert(result, "Uncategorized")
	return result
end

function GenreManager:ApplyTheme(themeOverride)
	if type(themeOverride) == "table" then
		self.ActiveTheme = themeOverride
	end

	local C = GetActiveThemeColors(self.ActiveTheme)
	self:UpdatePillHighlights(C)

	if self.GenreBar then
		local devAddBtn = self.GenreBar:FindFirstChild("DevAddGenreBtn")
		if devAddBtn then
			devAddBtn.BackgroundColor3 = C.AccentGreen
		end
	end

	if self.ActiveModal and self.ActiveModal.Parent then
		self.ActiveModal.BackgroundColor3 = C.MainBg
		local stroke = self.ActiveModal:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = C.CardSelect or C.TextMuted
		end
		local header = self.ActiveModal:FindFirstChild("Header")
		if header then
			header.BackgroundColor3 = C.PanelBg
			local title = header:FindFirstChild("HeaderTitle")
			if title then title.TextColor3 = C.TextMain end
		end
	end
end

GenreManager.UpdateTheme = GenreManager.ApplyTheme
GenreManager.RefreshTheme = GenreManager.ApplyTheme

function GenreManager:UpdatePillHighlights(activeThemeColors)
	if type(activeThemeColors) == "table" then
		self.ActiveTheme = activeThemeColors
	end
	local C = GetActiveThemeColors(self.ActiveTheme)

	for gName, gPill in pairs(self.GenrePillsMap) do
		if gPill and gPill.Parent then
			local selected = (gName == self.ActiveGenre)
			gPill.BackgroundColor3 = selected and C.Accent or C.CardBg
			gPill.TextColor3 = selected and Color3.fromRGB(255, 255, 255) or C.TextMain
		end
	end
end

function GenreManager:Refresh(activeThemeColors)
	if type(activeThemeColors) == "table" then
		self.ActiveTheme = activeThemeColors
	end

	local C = GetActiveThemeColors(self.ActiveTheme)
	local makeElement = self.UIUtils.makeElement

	local listLayout = self.GenreBar:FindFirstChildOfClass("UIListLayout")
	if listLayout then
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	end

	for _, child in ipairs(self.GenreBar:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	self.GenrePillsMap = {}

	local availableGenres = self:GetAvailableGenres(true)
	local startOrder = 1

	local canEdit = false
	if type(self.IsOwnerOrAuthor) == "function" then
		canEdit = self.IsOwnerOrAuthor()
	elseif type(self.IsOwnerOrAuthor) == "boolean" then
		canEdit = self.IsOwnerOrAuthor
	end

	if canEdit then
		local addBtn = makeElement("TextButton", {
			Name = "DevAddGenreBtn",
			Size = UDim2.new(0, 26, 1, 0),
			BackgroundColor3 = C.AccentGreen,
			Text = "+",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 14,
			Font = Enum.Font.GothamBold,
			LayoutOrder = 1,
			Parent = self.GenreBar
		}, 4)

		addBtn.Activated:Connect(function()
			self:OpenGenreManagerModal(C)
		end)
		startOrder = 2
	end

	for idx, genreName in ipairs(availableGenres) do
		local isActive = (self.ActiveGenre == genreName)
		local pill = makeElement("TextButton", {
			Name = "GenrePill_" .. genreName,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundColor3 = isActive and C.Accent or C.CardBg,
			Text = genreName,
			TextColor3 = isActive and Color3.fromRGB(255, 255, 255) or C.TextMain,
			TextSize = 11,
			Font = Enum.Font.GothamBold,
			LayoutOrder = startOrder + idx - 1,
			Parent = self.GenreBar
		}, 4, {0, 10, 0, 10})

		self.GenrePillsMap[genreName] = pill

		pill.Activated:Connect(function()
			self.ActiveGenre = genreName
			self:UpdatePillHighlights(C)
			if self.OnGenreSelected then
				self.OnGenreSelected(genreName)
			end
		end)
	end
end

function GenreManager:OpenGenreManagerModal(activeThemeColors)
	if type(activeThemeColors) == "table" then
		self.ActiveTheme = activeThemeColors
	end
	GenreModal.Open(self, GetActiveThemeColors(self.ActiveTheme))
end

GenreManager.PromptAddGenreModal = GenreManager.OpenGenreManagerModal

function GenreManager:AddGenre(genreName, activeThemeColors)
	if type(genreName) ~= "string" or genreName == "" or genreName == "All" or genreName == "Uncategorized" then return end
	if not table.find(self.CustomGenres, genreName) then
		table.insert(self.CustomGenres, genreName)
		table.insert(self.CustomOrder, genreName)
	end
	self.DisabledGenres[genreName] = nil

	if self.Service and type(self.Service.AddGenre) == "function" then
		pcall(function() self.Service.AddGenre(genreName) end)
	end

	self:Refresh(activeThemeColors)
end

function GenreManager:RemoveGenre(genreName, activeThemeColors)
	if type(genreName) ~= "string" or genreName == "All" or genreName == "Uncategorized" then return end
	self.DisabledGenres[genreName] = true
	if self.ActiveGenre == genreName then
		self.ActiveGenre = "All"
	end

	if self.Service and type(self.Service.RemoveGenre) == "function" then
		pcall(function() self.Service.RemoveGenre(genreName) end)
	end

	self:Refresh(activeThemeColors)
end

function GenreManager:RestoreGenre(genreName, activeThemeColors)
	if type(genreName) ~= "string" or genreName == "All" or genreName == "Uncategorized" then return end
	self.DisabledGenres[genreName] = nil

	if self.Service and type(self.Service.RestoreGenre) == "function" then
		pcall(function() self.Service.RestoreGenre(genreName) end)
	end

	self:Refresh(activeThemeColors)
end

function GenreManager:DeleteGenre(genreName, activeThemeColors)
	if type(genreName) ~= "string" or genreName == "All" or genreName == "Uncategorized" then return end

	if self.CustomGenres then
		for idx, name in ipairs(self.CustomGenres) do
			if name == genreName then
				table.remove(self.CustomGenres, idx)
				break
			end
		end
	end

	if self.CustomOrder then
		for idx, name in ipairs(self.CustomOrder) do
			if name == genreName then
				table.remove(self.CustomOrder, idx)
				break
			end
		end
	end

	if self.ActiveGenre == genreName then
		self.ActiveGenre = "All"
	end
	self.DisabledGenres[genreName] = true

	if self.Service and type(self.Service.DeleteGenre) == "function" then
		pcall(function() self.Service.DeleteGenre(genreName) end)
	end

	self:Refresh(activeThemeColors)
end

return GenreManager