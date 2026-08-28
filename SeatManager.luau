local SeatManager = {}

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local pianoModules = ReplicatedStorage:WaitForChild("PianoModules")
local VisualEffectsManager = require(pianoModules:WaitForChild("VisualEffectsManager"))

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local cameraConnection = nil
local seatedStateCallback = nil
local currentSeat = nil
local currentPianoModel = nil
local isSeated = false

-- Camera Angle State
local currentCameraMode = 1 -- 1: Standard, 2: Overhead, 3: Side View, 4: Dynamic Synthesia Follow
local targetNoteX = 0
local currentNoteX = 0
local strikeBounce = 0

-- Fixed Camera Angles
local CAMERA_ANGLES = {
	[1] = CFrame.new(0, 4.8, 6.5) * CFrame.Angles(math.rad(-26), 0, 0),             -- 1: Over-the-Shoulder
	[2] = CFrame.new(0, 5.5, 2.2) * CFrame.Angles(math.rad(-60), 0, 0),             -- 2: Overhead Keys View
	[3] = CFrame.new(4.5, 3.8, 3.5) * CFrame.Angles(math.rad(-18), math.rad(40), 0), -- 3: Side Angle View
}

local function HasVisualType(pianoModel)
	if not pianoModel then return false end
	local attr = pianoModel:GetAttribute("VisualType")
	if type(attr) == "string" and attr ~= "" then return true end

	local valObj = pianoModel:FindFirstChild("VisualType", true)
	if valObj and valObj:IsA("StringValue") and valObj.Value ~= "" then return true end

	return false
end

local function GetKeyboardWidth(pianoModel)
	if not pianoModel then return 6.0 end
	local origin = pianoModel:FindFirstChild("EffectsOrigin", true)
	if origin and origin:IsA("BasePart") then
		return origin.Size.X * 0.78 -- Tighter width mapping
	end
	return 6.0
end

local function IsPianoSeat(seatPart)
	if not seatPart or not seatPart:IsA("Seat") then return false end
	if seatPart.Name == "PianoSeat" or seatPart:GetAttribute("IsPianoSeat") == true then
		return true
	end
	local ancestorModel = seatPart:FindFirstAncestorOfClass("Model")
	return ancestorModel and (ancestorModel:FindFirstChild("SoundOrigin") ~= nil or ancestorModel.Name:lower():find("piano") ~= nil)
end

local function SinkConflictInputs(actionName, inputState, inputObject)
	return Enum.ContextActionResult.Sink
end

local function HandleCameraCycleInput(actionName, inputState, inputObject)
	if inputState ~= Enum.UserInputState.Begin or not isSeated then return Enum.ContextActionResult.Pass end

	local maxModes = HasVisualType(currentPianoModel) and 4 or 3

	if inputObject.KeyCode == Enum.KeyCode.Equals or inputObject.KeyCode == Enum.KeyCode.KeypadPlus then
		currentCameraMode = currentCameraMode + 1
		if currentCameraMode > maxModes then currentCameraMode = 1 end
	elseif inputObject.KeyCode == Enum.KeyCode.Minus or inputObject.KeyCode == Enum.KeyCode.KeypadMinus then
		currentCameraMode = currentCameraMode - 1
		if currentCameraMode < 1 then currentCameraMode = maxModes end
	end

	return Enum.ContextActionResult.Sink
end

function SeatManager.IsSeated()
	return isSeated
end

function SeatManager.GetCurrentPianoModel()
	return currentPianoModel
end

function SeatManager.GetCurrentCameraMode()
	return currentCameraMode
end

function SeatManager.RegisterNoteActivity(noteIndex, velocityVolume)
	if not isSeated or currentCameraMode ~= 4 or not HasVisualType(currentPianoModel) then return end

	local clampedNote = math.clamp(noteIndex or 44, 1, 88)
	local normalizedRatio = ((clampedNote - 1) / 87) - 0.5
	local keyboardWidth = GetKeyboardWidth(currentPianoModel)
	local keyXOffset = normalizedRatio * keyboardWidth

	local weight = math.clamp(velocityVolume or 0.5, 0.25, 1.0)
	targetNoteX = (targetNoteX * (1 - weight * 0.35)) + (keyXOffset * weight * 0.35)
	strikeBounce = math.clamp(strikeBounce + (weight * 0.12), 0, 0.5)
end

function SeatManager.OnSeated(pianoSeat)
	if isSeated or not IsPianoSeat(pianoSeat) then return end
	isSeated = true
	currentSeat = pianoSeat
	currentPianoModel = pianoSeat:FindFirstAncestorOfClass("Model") or pianoSeat.Parent

	currentCameraMode = 1
	targetNoteX = 0
	currentNoteX = 0
	strikeBounce = 0

	VisualEffectsManager.SetActivePiano(currentPianoModel)

	local character = localPlayer.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		end
	end

	camera.CameraType = Enum.CameraType.Scriptable

	cameraConnection = RunService.RenderStepped:Connect(function(dt)
		if not isSeated or not currentSeat then return end

		local targetCFrame

		if currentCameraMode == 4 and HasVisualType(currentPianoModel) then
			-- Mode 4: Low-Angle Framed Camera
			targetNoteX = targetNoteX * (1 - math.clamp(dt * 1.8, 0, 1))
			strikeBounce = strikeBounce * (1 - math.clamp(dt * 6.0, 0, 1))
			currentNoteX = currentNoteX + (targetNoteX - currentNoteX) * math.clamp(dt * 4.5, 0, 1)

			local panX = currentNoteX * 0.45
			local verticalBounce = strikeBounce * 0.15

			-- Camera positioned closer to the keyboard level
			local cameraPos = (currentSeat.CFrame * CFrame.new(panX, 3.6 + verticalBounce, 5.8)).Position

			-- Aimed slightly above keybed level (4.8 studs Y) so it frames the notes without looking at the sky
			local focusTarget = (currentSeat.CFrame * CFrame.new(panX * 0.25, 4.8, -1.2)).Position

			targetCFrame = CFrame.lookAt(cameraPos, focusTarget)
		else
			local baseOffset = CAMERA_ANGLES[currentCameraMode] or CAMERA_ANGLES[1]
			targetCFrame = currentSeat.CFrame * baseOffset
		end

		camera.CFrame = camera.CFrame:Lerp(targetCFrame, math.clamp(dt * 8.0, 0, 1))
	end)

	ContextActionService:BindActionAtPriority(
		"BlockFreecamAndHotkeys",
		SinkConflictInputs,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.P,
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.RightShift
	)

	ContextActionService:BindAction(
		"PianoCameraAngleCycle",
		HandleCameraCycleInput,
		false,
		Enum.KeyCode.Equals,
		Enum.KeyCode.Minus,
		Enum.KeyCode.KeypadPlus,
		Enum.KeyCode.KeypadMinus
	)

	if seatedStateCallback then
		seatedStateCallback(true, currentPianoModel)
	end
end

function SeatManager.OnUnseated()
	if not isSeated then
		if seatedStateCallback then
			seatedStateCallback(false, nil)
		end
		return
	end

	isSeated = false
	currentSeat = nil
	currentPianoModel = nil
	currentCameraMode = 1

	VisualEffectsManager.SetActivePiano(nil)

	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end

	camera.CameraType = Enum.CameraType.Custom
	local character = localPlayer.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		end
	end

	ContextActionService:UnbindAction("BlockFreecamAndHotkeys")
	ContextActionService:UnbindAction("PianoCameraAngleCycle")

	if seatedStateCallback then
		seatedStateCallback(false, nil)
	end
end

function SeatManager.ExitSeat()
	local character = localPlayer.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.SeatPart then
			humanoid.Sit = false
		end
	end
	SeatManager.OnUnseated()
end

function SeatManager.Init(onStateChanged)
	seatedStateCallback = onStateChanged

	local function checkAndSeat(character)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		while not humanoid do
			character.ChildAdded:Wait()
			humanoid = character:FindFirstChildOfClass("Humanoid")
		end

		if humanoid.SeatPart and IsPianoSeat(humanoid.SeatPart) then
			SeatManager.OnSeated(humanoid.SeatPart)
		else
			SeatManager.OnUnseated()
		end

		humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
			if humanoid.SeatPart and IsPianoSeat(humanoid.SeatPart) then
				SeatManager.OnSeated(humanoid.SeatPart)
			else
				SeatManager.OnUnseated()
			end
		end)

		humanoid.Seated:Connect(function(active, currentSeatPart)
			if active and IsPianoSeat(currentSeatPart) then
				SeatManager.OnSeated(currentSeatPart)
			else
				SeatManager.OnUnseated()
			end
		end)
	end

	if localPlayer.Character then
		task.spawn(function()
			checkAndSeat(localPlayer.Character)
		end)
	end

	localPlayer.CharacterAdded:Connect(function(char)
		checkAndSeat(char)
	end)
end

return SeatManager