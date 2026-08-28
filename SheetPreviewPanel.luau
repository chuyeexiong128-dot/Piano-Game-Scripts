local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PianoUI = ReplicatedStorage:WaitForChild("PianoModules"):WaitForChild("PianoUI")

local UIUtils = require(PianoUI:WaitForChild("UIUtils"))

local PreviewPanel = {}
PreviewPanel.__index = PreviewPanel

-- Dynamic Theme Color Resolver
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
		MainBg = C.MainBg or C.MainBackground or C.PANEL_BG or C.BG_DARK or Color3.fromRGB(32, 34, 40),
		CardBg = C.CardBg or C.CardBackground or C.CARD_BG or C.SecondaryBg or C.SecondaryBackground or Color3.fromRGB(42, 44, 52),
		InputBg = C.InputBg or C.INPUT_BG or C.TextBoxBg or Color3.fromRGB(24, 25, 30),
		TextColor = C.TextMain or C.TextColor or C.TEXT_MAIN or C.Text or C.PrimaryText or Color3.fromRGB(230, 230, 240),
		TextMuted = C.TextMuted or C.SubTextColor or C.TEXT_MUTED or C.SubText or C.SecondaryText or Color3.fromRGB(150, 150, 160),
		Accent = C.Accent or C.AccentColor or C.ACCENT or Color3.fromRGB(46, 204, 113),
		CloseRed = C.CloseRed or C.CLOSE_RED or C.Danger or Color3.fromRGB(231, 76, 60),
		MedYellow = C.MedYellow or C.MED_YELLOW or Color3.fromRGB(241, 196, 15),
		EasyGreen = C.EasyGreen or C.ACCENT_GREEN or Color3.fromRGB(46, 204, 113),
		HardRed = C.HardRed or Color3.fromRGB(231, 76, 60),
	}
end

local function GetDifficultyColor(diff, C, uiUtils)
	local util = uiUtils or UIUtils
	if util and type(util.getDifficultyColor) == "function" then
		local color = util.getDifficultyColor(diff)
		if color then return color end
	elseif util and type(util.GetDifficultyColor) == "function" then
		local color = util.GetDifficultyColor(diff)
		if color then return color end
	end

	local d = string.lower(tostring(diff or ""))
	if d == "easy" or d == "beginner" then
		return C.EasyGreen
	elseif d == "hard" or d == "expert" or d == "insane" then
		return C.HardRed
	end
	return C.MedYellow
end

function PreviewPanel.new(parentContainer, customUIUtils, service, isOwnerOrAuthorCallback, onLoadCallback, onDeleteCallback, initialTheme)
	local self = setmetatable({}, PreviewPanel)
	self.UIUtils = customUIUtils or UIUtils
	self.Service = service
	self.IsOwnerCallback = isOwnerOrAuthorCallback
	self.OnLoadCallback = onLoadCallback
	self.OnDeleteCallback = onDeleteCallback
	self.SelectedSheet = nil
	self.IsRating = false
	self.ActiveTheme = (type(initialTheme) == "table") and initialTheme or nil

	local C = GetThemeColors(self.ActiveTheme, self.UIUtils)
	local makeElement = self.UIUtils.makeElement

	self.PreviewContainer = makeElement("Frame", {
		Name = "PreviewPanelContainer",
		Size = UDim2.new(1, -340, 1, 0),
		Position = UDim2.new(0, 340, 0, 0),
		BackgroundColor3 = C.MainBg,
		BorderSizePixel = 0,
		Parent = parentContainer
	}, 6, {12, 12, 12, 12})

	self.TitleLabel = makeElement("TextLabel", {
		Name = "TitleLabel",
		Size = UDim2.new(1, -85, 0, 22),
		BackgroundTransparency = 1,
		Text = "Select a sheet to preview",
		TextColor3 = C.TextColor,
		TextSize = 15,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = self.PreviewContainer
	})

	self.DeleteBtn = makeElement("TextButton", {
		Name = "DeleteButton",
		Size = UDim2.new(0, 70, 0, 24),
		Position = UDim2.new(1, -70, 0, 0),
		BackgroundColor3 = C.CloseRed,
		Text = "Delete",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		Visible = false,
		Parent = self.PreviewContainer
	}, 4)

	self.MetaLabel = makeElement("TextLabel", {
		Name = "MetaLabel",
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 0, 24),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = C.TextMuted,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = self.PreviewContainer
	})

	self.RatingFrame = makeElement("Frame", {
		Name = "RatingFrame",
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0, 0, 0, 44),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = self.PreviewContainer
	})

	self.LikeBtn = makeElement("TextButton", {
		Name = "LikeButton",
		Size = UDim2.new(0, 80, 1, 0),
		BackgroundColor3 = C.CardBg,
		Text = "?? 0",
		TextColor3 = C.TextColor,
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		Parent = self.RatingFrame
	}, 4)

	self.DislikeBtn = makeElement("TextButton", {
		Name = "DislikeButton",
		Size = UDim2.new(0, 80, 1, 0),
		Position = UDim2.new(0, 88, 0, 0),
		BackgroundColor3 = C.CardBg,
		Text = "?? 0",
		TextColor3 = C.TextColor,
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		Parent = self.RatingFrame
	}, 4)

	local initialDiffColor = GetDifficultyColor("Medium", C, self.UIUtils)
	self.DiffBadge = makeElement("TextLabel", {
		Name = "DiffBadge",
		Size = UDim2.new(0, 80, 1, 0),
		Position = UDim2.new(1, -80, 0, 0),
		BackgroundColor3 = initialDiffColor,
		Text = "Medium",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		Parent = self.RatingFrame
	}, 4)

	self.PreviewBox = makeElement("TextBox", {
		Name = "PreviewBox",
		Size = UDim2.new(1, 0, 1, -120),
		Position = UDim2.new(0, 0, 0, 76),
		BackgroundColor3 = C.InputBg,
		TextColor3 = C.TextColor,
		TextSize = 12,
		Font = Enum.Font.RobotoMono,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ClearTextOnFocus = false,
		TextEditable = false,
		MultiLine = true,
		Text = "",
		Parent = self.PreviewContainer
	}, 4, {8, 8, 8, 8})

	self.LoadTabBtn = makeElement("TextButton", {
		Name = "LoadTabButton",
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.new(0, 0, 1, -34),
		BackgroundColor3 = C.Accent,
		Text = "Load to Active Sheet Tab",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		Visible = false,
		Parent = self.PreviewContainer
	}, 6)

	self.LikeBtn.Activated:Connect(function()
		if not self.SelectedSheet or not self.Service or self.IsRating then return end
		self.IsRating = true
		task.spawn(function()
			local sheetId = self.SelectedSheet.Id or self.SelectedSheet.Title
			if self.Service and type(self.Service.RateSheet) == "function" then
				local success, res = pcall(function()
					return self.Service.RateSheet(sheetId, "Like")
				end)
				if success and type(res) == "table" then
					self.SelectedSheet.Likes = res.Likes
					self.SelectedSheet.Dislikes = res.Dislikes
					if self.LikeBtn and self.LikeBtn.Parent then
						self.LikeBtn.Text = "?? " .. (res.Likes or 0)
					end
					if self.DislikeBtn and self.DislikeBtn.Parent then
						self.DislikeBtn.Text = "?? " .. (res.Dislikes or 0)
					end
				end
			end
			self.IsRating = false
		end)
	end)

	self.DislikeBtn.Activated:Connect(function()
		if not self.SelectedSheet or not self.Service or self.IsRating then return end
		self.IsRating = true
		task.spawn(function()
			local sheetId = self.SelectedSheet.Id or self.SelectedSheet.Title
			if self.Service and type(self.Service.RateSheet) == "function" then
				local success, res = pcall(function()
					return self.Service.RateSheet(sheetId, "Dislike")
				end)
				if success and type(res) == "table" then
					self.SelectedSheet.Likes = res.Likes
					self.SelectedSheet.Dislikes = res.Dislikes
					if self.LikeBtn and self.LikeBtn.Parent then
						self.LikeBtn.Text = "?? " .. (res.Likes or 0)
					end
					if self.DislikeBtn and self.DislikeBtn.Parent then
						self.DislikeBtn.Text = "?? " .. (res.Dislikes or 0)
					end
				end
			end
			self.IsRating = false
		end)
	end)

	self.LoadTabBtn.Activated:Connect(function()
		if self.SelectedSheet and self.OnLoadCallback then
			self.OnLoadCallback(self.SelectedSheet)
		end
	end)

	self.DeleteBtn.Activated:Connect(function()
		if self.SelectedSheet and self.OnDeleteCallback then
			self.OnDeleteCallback(self.SelectedSheet)
		end
	end)

	return self
end

function PreviewPanel:DisplaySheet(sheet, isOwner)
	self.SelectedSheet = sheet
	if not sheet then
		self:Clear()
		return
	end

	local C = GetThemeColors(self.ActiveTheme, self.UIUtils)

	self.TitleLabel.Text = sheet.Title or "Untitled"
	self.MetaLabel.Text = "Artist: " .. (sheet.Artist or "Unknown") .. " | Genre: " .. (sheet.Genre or "Misc") .. " | By: " .. (sheet.Author or "Anon")
	self.PreviewBox.Text = sheet.Content or ""

	self.LikeBtn.Text = "?? " .. (sheet.Likes or 0)
	self.DislikeBtn.Text = "?? " .. (sheet.Dislikes or 0)

	local difficulty = sheet.Difficulty or "Medium"
	self.DiffBadge.Text = difficulty
	self.DiffBadge.BackgroundColor3 = GetDifficultyColor(difficulty, C, self.UIUtils)
	self.DiffBadge.TextColor3 = Color3.fromRGB(255, 255, 255)

	self.RatingFrame.Visible = true
	self.LoadTabBtn.Visible = true

	local canDelete = isOwner
	if canDelete == nil and self.IsOwnerCallback then
		canDelete = self.IsOwnerCallback(sheet)
	end
	self.DeleteBtn.Visible = canDelete or false
end

function PreviewPanel:Clear()
	self.SelectedSheet = nil
	self.TitleLabel.Text = "Select a sheet to preview"
	self.MetaLabel.Text = ""
	self.PreviewBox.Text = ""
	self.RatingFrame.Visible = false
	self.LoadTabBtn.Visible = false
	self.DeleteBtn.Visible = false
end

function PreviewPanel:ApplyTheme(themeOverride)
	if type(themeOverride) == "table" then
		self.ActiveTheme = themeOverride
	end

	local C = GetThemeColors(self.ActiveTheme, self.UIUtils)

	if self.PreviewContainer then self.PreviewContainer.BackgroundColor3 = C.MainBg end
	if self.TitleLabel then self.TitleLabel.TextColor3 = C.TextColor end
	if self.MetaLabel then self.MetaLabel.TextColor3 = C.TextMuted end
	if self.DeleteBtn then
		self.DeleteBtn.BackgroundColor3 = C.CloseRed
		self.DeleteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
	if self.LikeBtn then
		self.LikeBtn.BackgroundColor3 = C.CardBg
		self.LikeBtn.TextColor3 = C.TextColor
	end
	if self.DislikeBtn then
		self.DislikeBtn.BackgroundColor3 = C.CardBg
		self.DislikeBtn.TextColor3 = C.TextColor
	end
	if self.DiffBadge then
		local diffText = self.SelectedSheet and self.SelectedSheet.Difficulty or "Medium"
		self.DiffBadge.BackgroundColor3 = GetDifficultyColor(diffText, C, self.UIUtils)
		self.DiffBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
	if self.PreviewBox then
		self.PreviewBox.BackgroundColor3 = C.InputBg
		self.PreviewBox.TextColor3 = C.TextColor
	end
	if self.LoadTabBtn then
		self.LoadTabBtn.BackgroundColor3 = C.Accent
		self.LoadTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

PreviewPanel.UpdateTheme = PreviewPanel.ApplyTheme
PreviewPanel.RefreshTheme = PreviewPanel.ApplyTheme

function PreviewPanel:Destroy()
	if self.PreviewContainer then
		self.PreviewContainer:Destroy()
	end
	self.SelectedSheet = nil
	self.IsOwnerCallback = nil
	self.OnLoadCallback = nil
	self.OnDeleteCallback = nil
end

return PreviewPanel