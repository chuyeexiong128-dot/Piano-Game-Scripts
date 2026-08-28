local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PianoUI = ReplicatedStorage:WaitForChild("PianoModules"):WaitForChild("PianoUI")

local UIUtils = require(PianoUI:WaitForChild("UIUtils"))

local GenreModal = {}

-- Dynamic Theme Color Resolver
local function GetActiveThemeColors(activeTheme, uiUtils)
	local utils = uiUtils or UIUtils
	local C

	if type(utils.GetActiveThemeColors) == "function" then
		C = utils.GetActiveThemeColors(activeTheme)
	elseif type(utils.GetThemeColors) == "function" then
		C = utils.GetThemeColors(activeTheme)
	elseif type(utils.GetTheme) == "function" then
		C = utils.GetTheme(activeTheme)
	elseif type(utils.GetColors) == "function" then
		C = utils.GetColors(activeTheme)
	end

	if type(C) ~= "table" then
		C = (type(activeTheme) == "table" and activeTheme) or {}
	end
	if type(C.Colors) == "table" then
		C = C.Colors
	end

	return {
		MainBg = C.MainBg or C.MainBackground or C.BG_DARK or C.Background or C.BG or C.WindowBg or Color3.fromRGB(30, 30, 38),
		PanelBg = C.PanelBg or C.PANEL_BG or C.SecondaryBackground or C.SecondaryBg or C.SidePanelColor or Color3.fromRGB(38, 40, 48),
		CardBg = C.CardBg or C.CARD_BG or C.SecondaryBackground or C.SecondaryBg or C.ButtonBackground or C.ItemBg or Color3.fromRGB(44, 46, 56),
		CardSelect = C.CardSelect or C.CARD_SELECT or C.Highlight or C.AccentColor or C.Accent or Color3.fromRGB(60, 64, 80),
		InputBg = C.InputBg or C.INPUT_BG or C.TextBoxBg or Color3.fromRGB(24, 25, 30),
		TextMain = C.TextMain or C.TEXT_MAIN or C.TextColor or C.Text or C.PrimaryText or Color3.fromRGB(230, 230, 240),
		TextMuted = C.TextMuted or C.TEXT_MUTED or C.SubTextColor or C.SecondaryText or Color3.fromRGB(150, 150, 160),
		AccentGreen = C.AccentGreen or C.ACCENT_GREEN or C.Success or Color3.fromRGB(46, 204, 113),
		CloseRed = C.CloseRed or C.CLOSE_RED or C.Danger or C.Error or Color3.fromRGB(231, 76, 60),
	}
end

function GenreModal.Open(manager, activeThemeColors)
	if not manager or not manager.GenreBar then return end

	local utils = manager.UIUtils or UIUtils
	local makeElement = utils.makeElement

	if manager.ActiveModal and manager.ActiveModal.Parent then
		manager.ActiveModal:Destroy()
		manager.ActiveModal = nil
	end

	local C = GetActiveThemeColors(activeThemeColors or manager.ActiveTheme, utils)
	local parentScreenGui = manager.GenreBar:FindFirstAncestorOfClass("ScreenGui") or manager.GenreBar.Parent

	-- Main Popup Window
	local window = makeElement("Frame", {
		Name = "GenreManagerPopup",
		Size = UDim2.new(0, 390, 0, 350),
		Position = UDim2.new(0.5, -195, 0.5, -175),
		BackgroundColor3 = C.MainBg,
		BorderSizePixel = 0,
		ZIndex = 1000,
		Parent = parentScreenGui
	}, 8)
	window:SetAttribute("ForceSolid", true)
	manager.ActiveModal = window

	makeElement("UIStroke", {
		Name = "PopupBorder",
		Color = C.CardSelect or C.TextMuted or Color3.fromRGB(70, 75, 90),
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = window
	})

	-- Header
	local topBar = makeElement("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = C.PanelBg,
		BorderSizePixel = 0,
		ZIndex = 1001,
		Parent = window
	}, 8)

	if type(utils.MakeDraggable) == "function" then
		utils.MakeDraggable(window, topBar)
	end

	makeElement("TextLabel", {
		Name = "HeaderTitle",
		Size = UDim2.new(1, -40, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		BackgroundTransparency = 1,
		Text = "Manage & Reorder Genres",
		TextColor3 = C.TextMain,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 1002,
		Parent = topBar
	})

	local closeBtn = makeElement("TextButton", {
		Name = "CloseButton",
		Size = UDim2.new(0, 24, 0, 24),
		Position = UDim2.new(1, -30, 0.5, -12),
		BackgroundColor3 = C.CloseRed,
		Text = "X",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		ZIndex = 1002,
		Parent = topBar
	}, 4)

	local function closeModal()
		if manager.ActiveModal then
			manager.ActiveModal:Destroy()
			manager.ActiveModal = nil
		end
	end
	closeBtn.Activated:Connect(closeModal)

	-- Input Section
	local inputFrame = makeElement("Frame", {
		Name = "AddInputFrame",
		Size = UDim2.new(1, -20, 0, 32),
		Position = UDim2.new(0, 10, 0, 46),
		BackgroundTransparency = 1,
		ZIndex = 1001,
		Parent = window
	})

	local newGenreBox = makeElement("TextBox", {
		Name = "NewGenreInput",
		Size = UDim2.new(1, -80, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = C.InputBg,
		Text = "",
		PlaceholderText = "Create new genre...",
		PlaceholderColor3 = C.TextMuted,
		TextColor3 = C.TextMain,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		ClearTextOnFocus = false,
		ZIndex = 1002,
		Parent = inputFrame
	}, 4, {0, 8, 0, 8})

	local addGenreBtn = makeElement("TextButton", {
		Name = "AddGenreButton",
		Size = UDim2.new(0, 72, 1, 0),
		Position = UDim2.new(1, -72, 0, 0),
		BackgroundColor3 = C.AccentGreen,
		Text = "+ Add",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		ZIndex = 1002,
		Parent = inputFrame
	}, 4)

	-- List Container
	local listContainer = makeElement("ScrollingFrame", {
		Name = "GenreListContainer",
		Size = UDim2.new(1, -20, 1, -94),
		Position = UDim2.new(0, 10, 0, 84),
		BackgroundColor3 = C.PanelBg,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.TextMuted,
		ZIndex = 1001,
		Parent = window
	}, 6, {6, 6, 6, 6})

	local listLayout = makeElement("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = listContainer
	})

	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		listContainer.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 12)
	end)

	local function renderGridList()
		for _, child in ipairs(listContainer:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		local fetched = {}
		if manager.Service and type(manager.Service.FetchGenres) == "function" then
			local success, result = pcall(manager.Service.FetchGenres)
			if success and type(result) == "table" then
				fetched = result
			end
		end

		local genreSet = { ["All"] = true, ["Uncategorized"] = true }
		local currentList = {}

		for _, gName in ipairs(manager.CustomOrder or {}) do
			if not genreSet[gName] then
				genreSet[gName] = true
				table.insert(currentList, gName)
			end
		end

		for _, gName in ipairs(fetched) do
			if not genreSet[gName] then
				genreSet[gName] = true
				table.insert(currentList, gName)
			end
		end

		for _, gName in ipairs(manager.CustomGenres or {}) do
			if not genreSet[gName] then
				genreSet[gName] = true
				table.insert(currentList, gName)
			end
		end

		manager.CustomOrder = currentList

		for idx, gName in ipairs(currentList) do
			local isDisabled = manager.DisabledGenres and manager.DisabledGenres[gName]

			local itemCard = makeElement("Frame", {
				Name = "GenreItem_" .. gName,
				Size = UDim2.new(1, -4, 0, 32),
				BackgroundColor3 = C.CardBg,
				BackgroundTransparency = isDisabled and 0.4 or 0,
				LayoutOrder = idx,
				ZIndex = 1002,
				Parent = listContainer
			}, 4)

			-- Reorder Controls (? / ?)
			local upBtn = makeElement("TextButton", {
				Name = "UpBtn",
				Size = UDim2.new(0, 20, 0, 22),
				Position = UDim2.new(0, 6, 0.5, -11),
				BackgroundColor3 = C.InputBg,
				Text = "?",
				TextColor3 = C.TextMain,
				TextSize = 9,
				ZIndex = 1003,
				Parent = itemCard
			}, 3)

			local downBtn = makeElement("TextButton", {
				Name = "DownBtn",
				Size = UDim2.new(0, 20, 0, 22),
				Position = UDim2.new(0, 28, 0.5, -11),
				BackgroundColor3 = C.InputBg,
				Text = "?",
				TextColor3 = C.TextMain,
				TextSize = 9,
				ZIndex = 1003,
				Parent = itemCard
			}, 3)

			upBtn.Activated:Connect(function()
				if idx > 1 then
					manager.CustomOrder[idx], manager.CustomOrder[idx - 1] = manager.CustomOrder[idx - 1], manager.CustomOrder[idx]
					if manager.Refresh then manager:Refresh(C) end
					renderGridList()
				end
			end)

			downBtn.Activated:Connect(function()
				if idx < #manager.CustomOrder then
					manager.CustomOrder[idx], manager.CustomOrder[idx + 1] = manager.CustomOrder[idx + 1], manager.CustomOrder[idx]
					if manager.Refresh then manager:Refresh(C) end
					renderGridList()
				end
			end)

			makeElement("TextLabel", {
				Name = "GenreNameLabel",
				Size = UDim2.new(1, -175, 1, 0),
				Position = UDim2.new(0, 54, 0, 0),
				BackgroundTransparency = 1,
				Text = gName .. (isDisabled and " (Disabled)" or ""),
				TextColor3 = isDisabled and C.TextMuted or C.TextMain,
				TextSize = 11,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 1003,
				Parent = itemCard
			})

			if isDisabled then
				local restoreBtn = makeElement("TextButton", {
					Name = "RestoreBtn",
					Size = UDim2.new(0, 52, 0, 22),
					Position = UDim2.new(1, -114, 0.5, -11),
					BackgroundColor3 = C.AccentGreen,
					Text = "Restore",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 10,
					Font = Enum.Font.GothamBold,
					ZIndex = 1003,
					Parent = itemCard
				}, 4)

				local deleteBtn = makeElement("TextButton", {
					Name = "DeleteBtn",
					Size = UDim2.new(0, 52, 0, 22),
					Position = UDim2.new(1, -58, 0.5, -11),
					BackgroundColor3 = C.CloseRed,
					Text = "Delete",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 10,
					Font = Enum.Font.GothamBold,
					ZIndex = 1003,
					Parent = itemCard
				}, 4)

				restoreBtn.Activated:Connect(function()
					if manager.RestoreGenre then manager:RestoreGenre(gName, C) end
					renderGridList()
				end)

				deleteBtn.Activated:Connect(function()
					if manager.DeleteGenre then manager:DeleteGenre(gName, C) end
					renderGridList()
				end)
			else
				local removeBtn = makeElement("TextButton", {
					Name = "RemoveBtn",
					Size = UDim2.new(0, 52, 0, 22),
					Position = UDim2.new(1, -58, 0.5, -11),
					BackgroundColor3 = C.CloseRed,
					Text = "Remove",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 10,
					Font = Enum.Font.GothamBold,
					ZIndex = 1003,
					Parent = itemCard
				}, 4)

				removeBtn.Activated:Connect(function()
					if manager.RemoveGenre then manager:RemoveGenre(gName, C) end
					renderGridList()
				end)
			end
		end
	end

	local function commitAddGenre()
		local name = newGenreBox.Text:match("^%s*(.-)%s*$")
		if name and name ~= "" and name ~= "All" and name ~= "Uncategorized" then
			if manager.AddGenre then manager:AddGenre(name, C) end
			closeModal()
		end
	end

	addGenreBtn.Activated:Connect(commitAddGenre)
	newGenreBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then commitAddGenre() end
	end)

	renderGridList()
end

return GenreModal