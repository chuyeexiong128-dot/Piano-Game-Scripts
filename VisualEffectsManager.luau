local VisualEffectsManager = {}
VisualEffectsManager.__index = VisualEffectsManager

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local SeatManager = nil
local function getSeatManager()
	if not SeatManager then
		local seatModule = ReplicatedStorage:FindFirstChild("SeatManager", true)
		if seatModule then
			pcall(function() SeatManager = require(seatModule) end)
		end
	end
	return SeatManager
end

local CustomizationData = nil
local function getCustomizationData()
	if not CustomizationData then
		local customizationModule = ReplicatedStorage:FindFirstChild("CustomizationData", true)
		if customizationModule then
			pcall(function() CustomizationData = require(customizationModule) end)
		end
	end
	return CustomizationData
end

local OnscreenPiano = nil
local function getOnscreenPiano()
	if not OnscreenPiano then
		local onscreenModule = ReplicatedStorage:FindFirstChild("OnscreenPiano", true)
		if onscreenModule then
			pcall(function() OnscreenPiano = require(onscreenModule) end)
		end
	end
	return OnscreenPiano
end

local activePianoModel = nil
local activeEffectType = "FallingNotes"
local activePianoThemeId = "Default"

-- Physics Tracking
local activeHeldNotes = {} -- [noteIndex] = NoteObject
local activeFallingNotes = {} -- Array of all rendered note objects

local MIN_NOTE = 1
local MAX_NOTE = 88
local SCROLL_SPEED = 4.5 -- Studs per second moving upward

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function GetPlayerRoot()
	local character = LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function ResolveVisualType(pianoModel)
	if not pianoModel then return "FallingNotes" end
	local attr = pianoModel:GetAttribute("VisualType")
	if type(attr) == "string" and attr ~= "" then return attr end
	local valObject = pianoModel:FindFirstChild("VisualType", true)
	if valObject and valObject:IsA("StringValue") and valObject.Value ~= "" then
		return valObject.Value
	end
	return "FallingNotes"
end

local function GetOriginInfo(soundOrigin)
	local originPart = nil
	if activePianoModel then
		originPart = activePianoModel:FindFirstChild("EffectsOrigin", true)
			or activePianoModel:FindFirstChild("SynthesiaOrigin", true)
			or activePianoModel:FindFirstChild("SoundOrigin", true)
			or activePianoModel.PrimaryPart
	end
	if not originPart and soundOrigin then originPart = soundOrigin end

	local originCFrame = originPart and originPart.CFrame or (GetPlayerRoot() and GetPlayerRoot().CFrame)
	local totalWidth = ((originPart and originPart:IsA("BasePart")) and originPart.Size.X or 7.5) * 0.78
	local heightSpan = (originPart and originPart:IsA("BasePart")) and originPart.Size.Y or 5.0

	return originCFrame, totalWidth, heightSpan
end

local function IsBlackKey(noteIndex)
	local octaveOffset = (noteIndex - 1) % 12
	return octaveOffset == 1 or octaveOffset == 4 or octaveOffset == 6 or octaveOffset == 9 or octaveOffset == 11
end

-- Safely resolves theme colors across ColorThemes, KeyThemes, KeyPresets, direct tables, and OnscreenPiano
local function GetNoteColor(noteIndex)
	local custData = getCustomizationData()
	local onscreenPiano = getOnscreenPiano()
	local themeData = nil

	if type(activePianoThemeId) == "table" then
		themeData = activePianoThemeId
	elseif activePianoThemeId and activePianoThemeId ~= "Default" and custData then
		if typeof(custData.GetItemData) == "function" then
			themeData = custData.GetItemData("KeyThemes", activePianoThemeId)
				or custData.GetItemData("ColorThemes", activePianoThemeId)
				or custData.GetItemData("KeyPresets", activePianoThemeId)
		end

		if not themeData then
			local dict = custData.KeyThemes or custData.ColorThemes or custData.KeyPresets
			if dict then
				themeData = dict[activePianoThemeId]
			end
		end
	end

	-- Retrieve equipped theme data directly from OnscreenPiano if active theme isn't explicit
	if not themeData and onscreenPiano then
		if typeof(onscreenPiano.GetEquippedTheme) == "function" then
			themeData = onscreenPiano.GetEquippedTheme()
		elseif typeof(onscreenPiano.GetThemeData) == "function" then
			themeData = onscreenPiano.GetThemeData()
		elseif onscreenPiano.EquippedTheme then
			themeData = onscreenPiano.EquippedTheme
		end
	end

	-- Fallback to default theme in CustomizationData
	if not themeData and custData then
		if typeof(custData.GetItemData) == "function" then
			themeData = custData.GetItemData("KeyThemes", "Default")
				or custData.GetItemData("ColorThemes", "Default")
				or custData.GetItemData("KeyPresets", "Default")
		end

		if not themeData then
			local dict = custData.KeyThemes or custData.ColorThemes or custData.KeyPresets
			if dict then
				themeData = dict["Default"]
			end
		end
	end

	if IsBlackKey(noteIndex) then
		return (themeData and (themeData.PressedBlack or themeData.BlackKeyPressed or themeData.BlackKeyColor or themeData.BlackKey)) 
			or Color3.fromRGB(80, 120, 200)
	else
		return (themeData and (themeData.PressedWhite or themeData.WhiteKeyPressed or themeData.WhiteKeyColor or themeData.WhiteKey)) 
			or Color3.fromRGB(180, 210, 255)
	end
end

local function ClearActiveNotes()
	for _, note in ipairs(activeFallingNotes) do
		if note.Part and note.Part.Parent then
			note.Part:Destroy()
		end
	end
	table.clear(activeFallingNotes)
	table.clear(activeHeldNotes)
end

--------------------------------------------------------------------------------
-- Physics Render Loop
--------------------------------------------------------------------------------

RunService.Heartbeat:Connect(function()
	if #activeFallingNotes == 0 or not activePianoModel then return end

	local soundOrigin = activePianoModel:FindFirstChild("SoundOrigin", true)
	local originCFrame, totalWidth, heightSpan = GetOriginInfo(soundOrigin)
	if not originCFrame then return end

	local now = os.clock()
	local keybedY = -heightSpan * 0.5
	local topBoundaryY = heightSpan * 0.5

	for i = #activeFallingNotes, 1, -1 do
		local note = activeFallingNotes[i]
		if note.Part and note.Part.Parent then
			if note.IsHeld then
				local heldDuration = now - note.StartTime
				local currentHeight = math.clamp(heldDuration * SCROLL_SPEED, 0.2, heightSpan)
				local centerY = keybedY + (currentHeight * 0.5)

				note.Part.Size = Vector3.new(note.SingleKeyWidth, currentHeight, 0.15)
				note.Part.CFrame = originCFrame * CFrame.new(note.XOffset, centerY, 0)

				-- Auto-release safety fallback if key release event is dropped
				if heldDuration > 2.5 then
					VisualEffectsManager.StopNoteEffect(note.NoteIndex)
				end
			else
				local heldDuration = note.EndTime - note.StartTime
				local finalHeight = math.clamp(heldDuration * SCROLL_SPEED, 0.2, heightSpan)
				local timeSinceRelease = now - note.EndTime
				local bottomEdgeY = keybedY + (timeSinceRelease * SCROLL_SPEED)
				local centerY = bottomEdgeY + (finalHeight * 0.5)

				-- Smooth fade as it approaches top boundary
				if bottomEdgeY > (topBoundaryY - 1.0) then
					local fadeAlpha = math.clamp((topBoundaryY - bottomEdgeY) / 1.0, 0, 1)
					note.Part.Transparency = 0.05 + (1 - fadeAlpha) * 0.95
				end

				-- Remove note once it scrolls past top of origin
				if bottomEdgeY >= topBoundaryY then
					note.Part:Destroy()
					table.remove(activeFallingNotes, i)
				else
					note.Part.Size = Vector3.new(note.SingleKeyWidth, finalHeight, 0.15)
					note.Part.CFrame = originCFrame * CFrame.new(note.XOffset, centerY, 0)
				end
			end
		else
			table.remove(activeFallingNotes, i)
		end
	end
end)

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function VisualEffectsManager.SetPianoTheme(themeId)
	activePianoThemeId = (themeId and themeId ~= "") and themeId or "Default"

	-- Refresh colors on existing active falling notes
	for _, note in ipairs(activeFallingNotes) do
		if note.Part and note.Part.Parent then
			note.Part.Color = GetNoteColor(note.NoteIndex)
		end
	end

	-- Notify OnscreenPiano if available
	local onscreenPiano = getOnscreenPiano()
	if onscreenPiano then
		if typeof(onscreenPiano.SetPianoTheme) == "function" then
			pcall(function() onscreenPiano.SetPianoTheme(themeId) end)
		elseif typeof(onscreenPiano.SetKeyTheme) == "function" then
			pcall(function() onscreenPiano.SetKeyTheme(themeId) end)
		end
	end
end

function VisualEffectsManager.SetActivePiano(pianoModel, themeId)
	ClearActiveNotes()
	activePianoModel = pianoModel
	if themeId then activePianoThemeId = themeId end
	activeEffectType = ResolveVisualType(pianoModel)
end

function VisualEffectsManager.PlayNoteEffect(noteIndex, velocityVolume)
	if not activePianoModel then return end

	local seatMgr = getSeatManager()
	if seatMgr and typeof(seatMgr.RegisterNoteActivity) == "function" then
		seatMgr.RegisterNoteActivity(noteIndex, velocityVolume)
	end

	-- Finish any existing note object on the same key
	if activeHeldNotes[noteIndex] then
		VisualEffectsManager.StopNoteEffect(noteIndex)
	end

	local soundOrigin = activePianoModel:FindFirstChild("SoundOrigin", true)
	local originCFrame, totalWidth, heightSpan = GetOriginInfo(soundOrigin)
	if not originCFrame then return end

	local keyColor = GetNoteColor(noteIndex)
	local alpha = (math.clamp(noteIndex, MIN_NOTE, MAX_NOTE) - 1) / (MAX_NOTE - 1)
	local xOffset = (alpha - 0.5) * totalWidth
	local singleKeyWidth = math.max(0.04, (totalWidth / MAX_NOTE) * 0.95)

	local noteBlock = Instance.new("Part")
	noteBlock.Size = Vector3.new(singleKeyWidth, 0.2, 0.15)
	noteBlock.Color = keyColor
	noteBlock.Material = Enum.Material.Neon
	noteBlock.Transparency = 0.05
	noteBlock.Anchored = true
	noteBlock.CanCollide = false
	noteBlock.Parent = Workspace

	local noteData = {
		NoteIndex = noteIndex,
		Part = noteBlock,
		StartTime = os.clock(),
		EndTime = nil,
		IsHeld = true,
		XOffset = xOffset,
		SingleKeyWidth = singleKeyWidth,
	}

	activeHeldNotes[noteIndex] = noteData
	table.insert(activeFallingNotes, noteData)
end

function VisualEffectsManager.StopNoteEffect(noteIndex)
	local noteData = activeHeldNotes[noteIndex]
	if not noteData then return end

	noteData.IsHeld = false
	noteData.EndTime = os.clock()
	activeHeldNotes[noteIndex] = nil
end

function VisualEffectsManager.ClearAll()
	ClearActiveNotes()
end

-- Complete Function Aliases for ShopThemeManager & Client Compatibility
VisualEffectsManager.GetNoteColor = GetNoteColor
VisualEffectsManager.SetKeyTheme = VisualEffectsManager.SetPianoTheme
VisualEffectsManager.ApplyKeyTheme = VisualEffectsManager.SetPianoTheme
VisualEffectsManager.SetPianoColors = VisualEffectsManager.SetPianoTheme
VisualEffectsManager.SetKeyColor = VisualEffectsManager.SetPianoTheme
VisualEffectsManager.SetTheme = VisualEffectsManager.SetPianoTheme

return VisualEffectsManager