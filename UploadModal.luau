local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PianoUI = ReplicatedStorage:WaitForChild("PianoModules"):WaitForChild("PianoUI")

local UIUtils = require(PianoUI:WaitForChild("UIUtils"))

local UploadModal = {}
UploadModal.__index = UploadModal

-- Dynamic Theme Color Resolver delegating to UIUtils helpers
local function GetThemeColors(activeTheme, uiUtils)
	local util = uiUtils or UIUtils
	local C

	if type(util.GetActiveThemeColors) == "function" then
		C = util.GetActiveThemeColors(activeTheme)
	elseif type(util.GetThemeColors) == "function" then
		C = util.GetThemeColors(activeTheme)
	elseif type(util.GetTheme) == "function" then
		C = util.GetTheme(activeTheme)
	elseif type(util.GetColors) == "function" then
		C = util.GetColors(activeTheme)
	end

	if type(C) ~= "table" then
		C = (type(activeTheme) == "table" and activeTheme) or {}
	end
	if type(C.Colors) == "table" then
		C = C.Colors
	end

	return {
		MainBg = C.MainBg or C.MainBackground or C.BG_DARK or C.Background or Color3.fromRGB(30, 30, 38),
		PanelBg = C.PanelBg or C.PANEL_BG or C.SecondaryBackground or Color3.fromRGB(38, 40, 48),
		CardBg = C.CardBg or C.CARD_BG or C.SecondaryBackground or Color3.fromRGB(35, 40, 50),
		CardSelect = C.CardSelect or C.CARD_SELECT or C.Highlight or Color3.fromRGB(70, 75, 90),
		InputBg = C.InputBg or C.INPUT_BG or C.TextBoxBg or Color3.fromRGB(24, 25, 30),
		TextMain = C.TextMain or C.TEXT_MAIN or C.TextColor or Color3.fromRGB(255, 255, 255),
		TextMuted = C.TextMuted or C.TEXT_MUTED or C.SubTextColor or Color3.fromRGB(150, 155, 170),
		TextSelected = C.TextSelected or C.TEXT_SELECTED or C.TextMain or Color3.fromRGB(255, 255, 255),
		Accent = C.Accent or C.ACCENT or C.AccentColor or Color3.fromRGB(80, 140, 240),
		AccentGreen = C.AccentGreen or C.ACCENT_GREEN or C.Success or Color3.fromRGB(46, 204, 113),
		CloseRed = C.CloseRed or C.CLOSE_RED or C.Danger or Color3.fromRGB(231, 76, 60),
	}
end

function UploadModal.new(parentWindow, customUIUtils, service, onPublishedCallback, genreManagerInstance, initialTheme)
	local self = setmetatable({}, UploadModal)
	self.UIUtils = customUIUtils or UIUtils
	self.Service = service
	self.OnPublishedCallback = onPublishedCallback
	self.GenreManager = genreManagerInstance
	self.SelectedUploadGenre = "Uncategorized"
	self.SelectedUploadDifficulty = "Medium"
	self.IsPublishing = false
	self.ActiveTheme = (type(initialTheme) == "table") and initialTheme or nil

	local C = GetThemeColors(self.ActiveTheme, self.UIUtils)
	local makeElement = self.UIUtils.makeElement

	local modal = makeElement("Frame", {
		Name = "UploadModalWindow",
		Size = UDim2.new(0, 460, 0, 470),
		Position = UDim2.new(0.5, -230, 0.5, -235),
		BackgroundColor3 = C.MainBg,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 10,
		Parent = parentWindow
	}, 8, {14, 14, 14, 14})
	modal:SetAttribute("ForceSolid", true)
	self.Frame = modal

	-- Outer Border
	self.ModalBorder = makeElement("UIStroke", {
		Name = "ModalBorder",
		Color = C.CardSelect,
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = modal
	})

	self.TitleLabel = makeElement("TextLabel", {
		Name = "TitleLabel",
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Text = "Publish Community Sheet",
		TextColor3 = C.TextMain,
		TextSize = 15,
		Font = Enum.Font.GothamBold,
		ZIndex = 11,
		Parent = modal
	})

	-- Title Input (Restricted to 30 characters)
	self.TitleInput = makeElement("TextBox", {
		Name = "TitleInput",
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0, 0, 0, 26),
		BackgroundColor3 = C.InputBg,
		Text = "",
		TextColor3 = C.TextMain,
		PlaceholderText = "Song Title (e.g. Moonlight Sonata)",
		PlaceholderColor3 = C.TextMuted,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		ClipsDescendants = true,
		ZIndex = 11,
		Parent = modal
	}, 4, {0, 8, 0, 8})

	self.TitleConn = self.TitleInput:GetPropertyChangedSignal("Text"):Connect(function()
		if #self.TitleInput.Text > 30 then
			self.TitleInput.Text = string.sub(self.TitleInput.Text, 1, 30)
		end
	end)

	-- Artist Input (Restricted to 20 characters)
	self.ArtistInput = makeElement("TextBox", {
		Name = "ArtistInput",
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0, 0, 0, 56),
		BackgroundColor3 = C.InputBg,
		Text = "",
		TextColor3 = C.TextMain,
		PlaceholderText = "Artist / Composer",
		PlaceholderColor3 = C.TextMuted,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		ClipsDescendants = true,
		ZIndex = 11,
		Parent = modal
	}, 4, {0, 8, 0, 8})

	self.ArtistConn = self.ArtistInput:GetPropertyChangedSignal("Text"):Connect(function()
		if #self.ArtistInput.Text > 20 then
			self.ArtistInput.Text = string.sub(self.ArtistInput.Text, 1, 20)
		end
	end)

	-- Genre Header
	self.GenreHeaderLabel = makeElement("TextLabel", {
		Name = "GenreHeaderLabel",
		Size = UDim2.new(0, 60, 0, 24),
		Position = UDim2.new(0, 0, 0, 88),
		BackgroundTransparency = 1,
		Text = "Genre:",
		TextColor3 = C.TextMuted,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
		Parent = modal
	})

	-- Genre Container
	self.GenreContainer = makeElement("Frame", {
		Name = "GenreContainer",
		Size = UDim2.new(1, -60, 0, 52),
		Position = UDim2.new(0, 60, 0, 88),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 11,
		Parent = modal
	})

	makeElement("UIGridLayout", {
		CellSize = UDim2.new(0, 72, 0, 24),
		CellPadding = UDim2.new(0, 4, 0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = self.GenreContainer
	})

	-- Difficulty Header
	self.DiffHeaderLabel = makeElement("TextLabel", {
		Name = "DiffHeaderLabel",
		Size = UDim2.new(0, 60, 0, 26),
		Position = UDim2.new(0, 0, 0, 148),
		BackgroundTransparency = 1,
		Text = "Difficulty:",
		TextColor3 = C.TextMuted,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
		Parent = modal
	})

	-- Difficulty Container
	self.DiffContainer = makeElement("Frame", {
		Name = "DiffContainer",
		Size = UDim2.new(1, -60, 0, 26),
		Position = UDim2.new(0, 60, 0, 148),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = modal
	})

	makeElement("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = self.DiffContainer
	})

	self.DiffButtons = {}
	local diffList = { "Easy", "Medium", "Hard" }

	local function updateDiffStyles()
		local colors = GetThemeColors(self.ActiveTheme, self.UIUtils)
		for dName, dBtn in pairs(self.DiffButtons) do
			local selected = (dName == self.SelectedUploadDifficulty)
			dBtn.BackgroundColor3 = selected and colors.Accent or colors.CardBg
			dBtn.TextColor3 = selected and colors.TextSelected or colors.TextMain
			local stroke = dBtn:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = selected and colors.Accent or colors.CardSelect
			end
		end
	end
	self.UpdateDiffStyles = updateDiffStyles

	for idx, diff in ipairs(diffList) do
		local selected = (self.SelectedUploadDifficulty == diff)
		local btn = makeElement("TextButton", {
			Name = "DiffButton_" .. diff,
			Size = UDim2.new(0, 75, 1, 0),
			LayoutOrder = idx,
			BackgroundColor3 = selected and C.Accent or C.CardBg,
			Text = diff,
			TextColor3 = selected and C.TextSelected or C.TextMain,
			TextSize = 11,
			Font = Enum.Font.GothamBold,
			ZIndex = 12,
			Parent = self.DiffContainer
		}, 4)

		makeElement("UIStroke", {
			Name = "PillBorder",
			Color = selected and C.Accent or C.CardSelect,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = btn
		})

		self.DiffButtons[diff] = btn

		btn.Activated:Connect(function()
			self.SelectedUploadDifficulty = diff
			updateDiffStyles()
		end)
	end

	-- QWERTY Notation Input
	self.ContentScroll = makeElement("ScrollingFrame", {
		Name = "ContentScrollContainer",
		Size = UDim2.new(1, 0, 0, 180),
		Position = UDim2.new(0, 0, 0, 182),
		BackgroundColor3 = C.InputBg,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.TextMuted,
		ClipsDescendants = true,
		ZIndex = 11,
		Parent = modal
	}, 4)

	self.ContentInput = makeElement("TextBox", {
		Name = "ContentInput",
		Size = UDim2.new(1, -10, 1, 0),
		Position = UDim2.new(0, 5, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = C.TextMain,
		PlaceholderText = "Paste QWERTY Sheet notation here...",
		PlaceholderColor3 = C.TextMuted,
		TextSize = 11,
		Font = Enum.Font.RobotoMono,
		ClearTextOnFocus = false,
		MultiLine = true,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextXAlignment = Enum.TextXAlignment.Center,
		ClipsDescendants = true,
		ZIndex = 12,
		Parent = self.ContentScroll
	})

	self.StatusLabel = makeElement("TextLabel", {
		Name = "StatusLabel",
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 0, 368),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = C.TextMuted,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		ZIndex = 11,
		Parent = modal
	})

	self.SubmitBtn = makeElement("TextButton", {
		Name = "SubmitButton",
		Size = UDim2.new(0, 180, 0, 32),
		Position = UDim2.new(0, 0, 1, -34),
		BackgroundColor3 = C.AccentGreen,
		Text = "Publish",
		TextColor3 = C.TextSelected,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		ZIndex = 11,
		Parent = modal
	}, 4)

	self.CancelBtn = makeElement("TextButton", {
		Name = "CancelButton",
		Size = UDim2.new(0, 180, 0, 32),
		Position = UDim2.new(1, -180, 1, -34),
		BackgroundColor3 = C.CardBg,
		Text = "Cancel",
		TextColor3 = C.TextMain,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		ZIndex = 11,
		Parent = modal
	}, 4)

	self.CancelBtn.Activated:Connect(function()
		modal.Visible = false
	end)

	self.SubmitBtn.Activated:Connect(function()
		if self.IsPublishing then return end

		local t = self.TitleInput.Text
		local a = self.ArtistInput.Text
		local c = self.ContentInput.Text

		local activeColors = GetThemeColors(self.ActiveTheme, self.UIUtils)

		if #t < 2 then
			self.StatusLabel.Text = "Title is too short!"
			self.StatusLabel.TextColor3 = activeColors.CloseRed
			return
		end
		if #c < 5 then
			self.StatusLabel.Text = "Sheet notation is empty!"
			self.StatusLabel.TextColor3 = activeColors.CloseRed
			return
		end

		self.IsPublishing = true
		self.StatusLabel.Text = "Publishing..."
		self.StatusLabel.TextColor3 = activeColors.TextMuted

		task.spawn(function()
			local success, msg = false, nil
			if self.Service and type(self.Service.PublishSheet) == "function" then
				local pcallOk, errOrSuccess, errMsg = pcall(function()
					return self.Service.PublishSheet({
						Title = t,
						Artist = a,
						Genre = self.SelectedUploadGenre,
						Difficulty = self.SelectedUploadDifficulty,
						Content = c
					})
				end)

				if pcallOk then
					if type(errOrSuccess) == "boolean" then
						success = errOrSuccess
						msg = errMsg
					elseif type(errOrSuccess) == "table" then
						success = errOrSuccess.Success or errOrSuccess.success or true
						msg = errOrSuccess.Message or errOrSuccess.message
					else
						success = true
					end
				else
					msg = tostring(errOrSuccess)
				end
			end

			self.IsPublishing = false

			if not self.Frame or not self.Frame.Parent then return end

			if success then
				self.StatusLabel.Text = "Published!"
				self.StatusLabel.TextColor3 = activeColors.AccentGreen
				task.wait(0.6)
				if self.Frame and self.Frame.Parent then
					self.Frame.Visible = false
				end
				if self.OnPublishedCallback then
					self.OnPublishedCallback()
				end
			else
				self.StatusLabel.Text = msg or "Failed to publish."
				self.StatusLabel.TextColor3 = activeColors.CloseRed
			end
		end)
	end)

	self:PopulateGenres(nil, self.UIUtils)

	return self
end

function UploadModal:PopulateGenres(genres, customUIUtils)
	local util = customUIUtils or self.UIUtils
	local C = GetThemeColors(self.ActiveTheme, util)

	for _, child in ipairs(self.GenreContainer:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local sourceGenres = genres

	if not sourceGenres and self.GenreManager and type(self.GenreManager.GetAvailableGenres) == "function" then
		sourceGenres = self.GenreManager:GetAvailableGenres(false)
	end

	if not sourceGenres or #sourceGenres == 0 then
		sourceGenres = { "Pop", "Anime", "Classical", "Video Games", "Jazz", "Rock", "Uncategorized" }
	end

	local validGenres = {}
	for _, gName in ipairs(sourceGenres) do
		local nameStr = (type(gName) == "table" and gName.Name) or tostring(gName)
		if nameStr ~= "All" and nameStr ~= "+" then
			table.insert(validGenres, nameStr)
		end
	end

	if not table.find(validGenres, self.SelectedUploadGenre) and #validGenres > 0 then
		self.SelectedUploadGenre = validGenres[1]
	end

	local function updateGenrePillStyles()
		local colors = GetThemeColors(self.ActiveTheme, util)
		for _, child in ipairs(self.GenreContainer:GetChildren()) do
			if child:IsA("TextButton") then
				local selected = (child.Text == self.SelectedUploadGenre)
				child.BackgroundColor3 = selected and colors.Accent or colors.CardBg
				child.TextColor3 = selected and colors.TextSelected or colors.TextMain
				local stroke = child:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = selected and colors.Accent or colors.CardSelect
				end
			end
		end
	end
	self.UpdateGenrePillStyles = updateGenrePillStyles

	for idx, genreName in ipairs(validGenres) do
		local selected = (self.SelectedUploadGenre == genreName)
		local uPill = util.makeElement("TextButton", {
			Name = "GenrePill_" .. genreName,
			Size = UDim2.new(1, 0, 1, 0),
			LayoutOrder = idx,
			BackgroundColor3 = selected and C.Accent or C.CardBg,
			Text = genreName,
			TextColor3 = selected and C.TextSelected or C.TextMain,
			TextSize = 10,
			Font = Enum.Font.GothamBold,
			ZIndex = 12,
			Parent = self.GenreContainer
		}, 4)

		util.makeElement("UIStroke", {
			Name = "PillBorder",
			Color = selected and C.Accent or C.CardSelect,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = uPill
		})

		uPill.Activated:Connect(function()
			self.SelectedUploadGenre = genreName
			updateGenrePillStyles()
		end)
	end
end

function UploadModal:ApplyTheme(themeOverride)
	if type(themeOverride) == "table" then
		self.ActiveTheme = themeOverride
	end

	local C = GetThemeColors(self.ActiveTheme, self.UIUtils)

	if self.Frame then self.Frame.BackgroundColor3 = C.MainBg end
	if self.ModalBorder then self.ModalBorder.Color = C.CardSelect end
	if self.TitleLabel then self.TitleLabel.TextColor3 = C.TextMain end
	if self.TitleInput then
		self.TitleInput.BackgroundColor3 = C.InputBg
		self.TitleInput.TextColor3 = C.TextMain
		self.TitleInput.PlaceholderColor3 = C.TextMuted
	end
	if self.ArtistInput then
		self.ArtistInput.BackgroundColor3 = C.InputBg
		self.ArtistInput.TextColor3 = C.TextMain
		self.ArtistInput.PlaceholderColor3 = C.TextMuted
	end
	if self.GenreHeaderLabel then self.GenreHeaderLabel.TextColor3 = C.TextMuted end
	if self.DiffHeaderLabel then self.DiffHeaderLabel.TextColor3 = C.TextMuted end
	if self.ContentScroll then
		self.ContentScroll.BackgroundColor3 = C.InputBg
		self.ContentScroll.ScrollBarImageColor3 = C.TextMuted
	end
	if self.ContentInput then
		self.ContentInput.TextColor3 = C.TextMain
		self.ContentInput.PlaceholderColor3 = C.TextMuted
	end
	if self.StatusLabel then self.StatusLabel.TextColor3 = C.TextMuted end
	if self.SubmitBtn then
		self.SubmitBtn.BackgroundColor3 = C.AccentGreen
		self.SubmitBtn.TextColor3 = C.TextSelected
	end
	if self.CancelBtn then
		self.CancelBtn.BackgroundColor3 = C.CardBg
		self.CancelBtn.TextColor3 = C.TextMain
	end

	if self.UpdateGenrePillStyles then self.UpdateGenrePillStyles() end
	if self.UpdateDiffStyles then self.UpdateDiffStyles() end
end

UploadModal.UpdateTheme = UploadModal.ApplyTheme
UploadModal.RefreshTheme = UploadModal.ApplyTheme

function UploadModal:Open(genreManagerInstance, activeThemeColors)
	if genreManagerInstance then
		self.GenreManager = genreManagerInstance
	end
	if type(activeThemeColors) == "table" then
		self.ActiveTheme = activeThemeColors
	end

	-- Clear fields on open
	self.TitleInput.Text = ""
	self.ArtistInput.Text = ""
	self.ContentInput.Text = ""
	self.StatusLabel.Text = ""
	self.IsPublishing = false

	if self.GenreContainer then self.GenreContainer.BackgroundTransparency = 1 end
	if self.DiffContainer then self.DiffContainer.BackgroundTransparency = 1 end

	self:PopulateGenres()
	self:ApplyTheme(self.ActiveTheme)

	self.Frame.Visible = true
end

function UploadModal:Close()
	if self.Frame then
		self.Frame.Visible = false
	end
	self.IsPublishing = false
end

function UploadModal:Destroy()
	if self.TitleConn then self.TitleConn:Disconnect() end
	if self.ArtistConn then self.ArtistConn:Disconnect() end

	if self.Frame then
		self.Frame:Destroy()
	end
	self.OnPublishedCallback = nil
	self.GenreManager = nil
	self.Service = nil
end

return UploadModal