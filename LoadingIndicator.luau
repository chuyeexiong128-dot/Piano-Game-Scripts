local TweenService = game:GetService("TweenService")

local LoadingIndicator = {}
LoadingIndicator.__index = LoadingIndicator

local C = {
	BG = Color3.fromRGB(22, 22, 26),
	BAR_BG = Color3.fromRGB(40, 40, 48),
	ACCENT = Color3.fromRGB(80, 130, 240),
	TEXT = Color3.fromRGB(240, 240, 245),
	MUTED = Color3.fromRGB(150, 150, 165)
}

function LoadingIndicator.new(parentGui)
	local self = setmetatable({}, LoadingIndicator)

	-- Frame Container
	local frame = Instance.new("Frame")
	frame.Name = "PianoLoadingIndicator"
	frame.Size = UDim2.new(0, 280, 0, 64)
	frame.Position = UDim2.new(0.5, -140, 0.85, 0)
	frame.BackgroundColor3 = C.BG
	frame.BorderSizePixel = 0
	frame.Parent = parentGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	-- Status Text
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, -24, 0, 20)
	statusLabel.Position = UDim2.new(0, 12, 0, 10)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Initializing Piano..."
	statusLabel.TextColor3 = C.TEXT
	statusLabel.TextSize = 12
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = frame

	-- Progress Track
	local trackFrame = Instance.new("Frame")
	trackFrame.Size = UDim2.new(1, -24, 0, 6)
	trackFrame.Position = UDim2.new(0, 12, 0, 38)
	trackFrame.BackgroundColor3 = C.BAR_BG
	trackFrame.BorderSizePixel = 0
	trackFrame.Parent = frame

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 3)
	trackCorner.Parent = trackFrame

	-- Progress Fill
	local fillFrame = Instance.new("Frame")
	fillFrame.Size = UDim2.new(0, 0, 1, 0)
	fillFrame.BackgroundColor3 = C.ACCENT
	fillFrame.BorderSizePixel = 0
	fillFrame.Parent = trackFrame

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 3)
	fillCorner.Parent = fillFrame

	self.Frame = frame
	self.StatusLabel = statusLabel
	self.FillFrame = fillFrame

	return self
end

function LoadingIndicator:Update(progressRatio, statusMessage)
	if statusMessage then
		self.StatusLabel.Text = statusMessage
	end

	local targetScale = math.clamp(progressRatio or 0, 0, 1)
	TweenService:Create(self.FillFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(targetScale, 0, 1, 0)
	}):Play()
end

function LoadingIndicator:Destroy()
	local fade = TweenService:Create(self.Frame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1
	})

	for _, child in ipairs(self.Frame:GetDescendants()) do
		if child:IsA("TextLabel") then
			TweenService:Create(child, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
		elseif child:IsA("Frame") then
			TweenService:Create(child, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
		end
	end

	fade:Play()
	fade.Completed:Connect(function()
		self.Frame:Destroy()
	end)
end

return LoadingIndicator