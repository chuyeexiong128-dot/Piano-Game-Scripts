local MultiTransposePanel = {}

local UserInputService = game:GetService("UserInputService")
local UIUtils = require(script.Parent:WaitForChild("UIUtils"))

local PianoModules = script.Parent.Parent
local MultiTransposeController = require(PianoModules:WaitForChild("MultiTransposeController"))

-- State Management
local onTransposeChangedCallback = nil
local isOpen = false

-- UI References
local containerFrame = nil
local textBox = nil
local valueLabel = nil
local prevButton = nil
local nextButton = nil
local resetButton = nil

local function updateDisplay(fromInput)
	local queue = MultiTransposeController.Queue
	local currentIndex = MultiTransposeController.CurrentIndex

	if #queue == 0 then
		if valueLabel then valueLabel.Text = "OFF" end
		if not fromInput and textBox and not textBox:IsFocused() then textBox.Text = "" end
		return
	end

	local activeValue = queue[currentIndex] or 0
	if valueLabel then
		local sign = activeValue > 0 and "+" or ""
		valueLabel.Text = string.format("%s%d  (%d/%d)", sign, activeValue, currentIndex, #queue)
	end

	if not fromInput and textBox and not textBox:IsFocused() then
		textBox.Text = table.concat(queue, ", ")
	end

	if onTransposeChangedCallback then
		onTransposeChangedCallback(activeValue)
	end
end

local function setupDraggable(frame)
	local dragging = false
	local dragInput, dragStart, startPos

	frame.InputBegan:Connect(function(input)
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

	frame.InputChanged:Connect(function(input)
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

function MultiTransposePanel.Init(parentGui)
	if containerFrame then return end

	local C = UIUtils.Colors or {}
	local bgColor = C.BG or C.BG_MAIN or Color3.fromRGB(30, 30, 38)
	local textOnColor = C.TEXT_ON or Color3.fromRGB(255, 255, 255)
	local colorOffColor = C.COLOR_OFF or Color3.fromRGB(42, 42, 52)

	containerFrame = Instance.new("Frame")
	containerFrame.Name = "MultiTransposePanel"
	containerFrame.Size = UDim2.new(0, 210, 0, 95)
	containerFrame.Position = UDim2.new(1, -230, 0, 60)
	containerFrame.BackgroundColor3 = bgColor
	containerFrame.Visible = false
	containerFrame.Active = true
	containerFrame.Parent = parentGui

	if UIUtils.CreateCorner then UIUtils.CreateCorner(containerFrame, 6) end
	if UIUtils.CreateStroke then UIUtils.CreateStroke(containerFrame) end

	setupDraggable(containerFrame)

	-- Title Label
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, -38, 0, 20)
	titleLabel.Position = UDim2.new(0, 6, 0, 4)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "MULTI-TRANSPOSE"
	titleLabel.TextColor3 = textOnColor
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 10
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = containerFrame

	-- Reset Button
	resetButton = Instance.new("TextButton")
	resetButton.Name = "ResetBtn"
	resetButton.Size = UDim2.new(0, 22, 0, 18)
	resetButton.Position = UDim2.new(1, -28, 0, 5)
	resetButton.BackgroundColor3 = colorOffColor
	resetButton.Text = "R"
	resetButton.TextColor3 = textOnColor
	resetButton.Font = Enum.Font.GothamBold
	resetButton.TextSize = 11
	resetButton.Parent = containerFrame
	if UIUtils.CreateCorner then UIUtils.CreateCorner(resetButton, 4) end

	-- Text Box Input
	textBox = Instance.new("TextBox")
	textBox.Name = "SequenceInput"
	textBox.Size = UDim2.new(1, -12, 0, 26)
	textBox.Position = UDim2.new(0, 6, 0, 26)
	textBox.BackgroundColor3 = colorOffColor
	textBox.Text = ""
	textBox.PlaceholderText = "e.g. -2, 0, 3, 5"
	textBox.TextColor3 = textOnColor
	textBox.Font = Enum.Font.GothamMedium
	textBox.TextSize = 11
	textBox.ClearTextOnFocus = false
	textBox.Parent = containerFrame
	if UIUtils.CreateCorner then UIUtils.CreateCorner(textBox, 4) end

	textBox.FocusLost:Connect(function()
		if textBox.Text == "" then
			MultiTransposePanel.Reset()
		else
			MultiTransposeController.SetSequence(textBox.Text)
			updateDisplay(true)
		end
	end)

	-- Prev Button
	prevButton = Instance.new("TextButton")
	prevButton.Name = "PrevBtn"
	prevButton.Size = UDim2.new(0, 30, 0, 28)
	prevButton.Position = UDim2.new(0, 6, 0, 58)
	prevButton.BackgroundColor3 = colorOffColor
	prevButton.Text = "?"
	prevButton.TextColor3 = textOnColor
	prevButton.Font = Enum.Font.GothamBold
	prevButton.TextSize = 12
	prevButton.Parent = containerFrame
	if UIUtils.CreateCorner then UIUtils.CreateCorner(prevButton, 4) end

	-- Next Button
	nextButton = Instance.new("TextButton")
	nextButton.Name = "NextBtn"
	nextButton.Size = UDim2.new(0, 30, 0, 28)
	nextButton.Position = UDim2.new(1, -36, 0, 58)
	nextButton.BackgroundColor3 = colorOffColor
	nextButton.Text = "?"
	nextButton.TextColor3 = textOnColor
	nextButton.Font = Enum.Font.GothamBold
	nextButton.TextSize = 12
	nextButton.Parent = containerFrame
	if UIUtils.CreateCorner then UIUtils.CreateCorner(nextButton, 4) end

	-- Value Display Label
	valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "ValueLabel"
	valueLabel.Size = UDim2.new(1, -78, 0, 28)
	valueLabel.Position = UDim2.new(0, 39, 0, 58)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Text = "OFF"
	valueLabel.TextColor3 = textOnColor
	valueLabel.Font = Enum.Font.GothamBold
	valueLabel.TextSize = 12
	valueLabel.Parent = containerFrame

	prevButton.Activated:Connect(MultiTransposePanel.Prev)
	nextButton.Activated:Connect(MultiTransposePanel.Next)
	resetButton.Activated:Connect(MultiTransposePanel.Reset)

	-- Bind MultiTransposeController events directly to UI updates
	MultiTransposeController.OnTransposeChanged = function(activeValue, index, queue)
		updateDisplay()
	end

	updateDisplay()
end

-- API Methods
function MultiTransposePanel.SetOnTransposeChanged(callback)
	onTransposeChangedCallback = callback
end

function MultiTransposePanel.SetTransposes(transposeList)
	if type(transposeList) == "table" then
		MultiTransposeController.SetSequence(transposeList)
		updateDisplay()
	end
end

function MultiTransposePanel.Reset()
	if textBox then textBox.Text = "" end
	if valueLabel then valueLabel.Text = "OFF" end
	MultiTransposeController.Reset()
end

function MultiTransposePanel.Next()
	MultiTransposeController.Next()
end

function MultiTransposePanel.Prev()
	MultiTransposeController.Previous()
end

function MultiTransposePanel.ToggleMenu(overrideState)
	if overrideState ~= nil then
		isOpen = overrideState
	else
		isOpen = not isOpen
	end

	if containerFrame then
		containerFrame.Visible = isOpen
	end
end

function MultiTransposePanel.SetVisible(visible)
	MultiTransposePanel.ToggleMenu(visible)
end

return MultiTransposePanel