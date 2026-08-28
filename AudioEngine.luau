local AudioEngine = {}

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dynamic Soundfont Folder Container
local pianoSounds = ReplicatedStorage:WaitForChild("PianoSounds")
local currentSoundfontName = "Salamander Grand"

-- Load VelocityVolumes ModuleScript safely if present
local velocityVolumes = {}
local velocityModule = pianoSounds:FindFirstChild("VelocityVolumes")
if velocityModule and velocityModule:IsA("ModuleScript") then
	velocityVolumes = require(velocityModule)
end

-- In-Memory Sound ID Registry (Eliminates physical Instance memory overhead)
local SoundRegistry = {}

local function indexAndPurgePhysicalSounds()
	for _, fontFolder in ipairs(pianoSounds:GetChildren()) do
		if not fontFolder:IsA("Folder") then continue end

		local fontName = fontFolder.Name
		SoundRegistry[fontName] = {
			Soft = { _count = 0 },
			Medium = { _count = 0 },
			Loud = { _count = 0 },
		}

		local hasSubfolders = false
		for _, child in ipairs(fontFolder:GetChildren()) do
			if child:IsA("Folder") then
				hasSubfolders = true
				local layerName = child.Name
				local layerTable = SoundRegistry[fontName][layerName] or { _count = 0 }
				SoundRegistry[fontName][layerName] = layerTable

				for _, item in ipairs(child:GetChildren()) do
					local soundId = item:IsA("StringValue") and item.Value or (item:IsA("Sound") and item.SoundId or nil)
					if soundId and soundId ~= "" then
						layerTable[item.Name] = soundId
						layerTable._count = layerTable._count + 1
					end
				end
			end
		end

		-- Fallback for single-layer libraries
		if not hasSubfolders then
			local defaultTable = { _count = 0 }
			for _, item in ipairs(fontFolder:GetChildren()) do
				local soundId = item:IsA("StringValue") and item.Value or (item:IsA("Sound") and item.SoundId or nil)
				if soundId and soundId ~= "" then
					defaultTable[item.Name] = soundId
					defaultTable._count = defaultTable._count + 1
				end
			end
			SoundRegistry[fontName].Soft = defaultTable
			SoundRegistry[fontName].Medium = defaultTable
			SoundRegistry[fontName].Loud = defaultTable
		end
	end
end

indexAndPurgePhysicalSounds()

local MAX_POLYPHONY = 64

local FONT_VOLUME_GAINS = {
	["Salamander Grand"] = 0.85,
	["Piano in 162 PedalOn"] = 1.15,
	["Piano in 162 PedalOn Ambient"] = 1.10,
}

local activeNotes = {}
local sustainedNotes = {}
local transposeShift = 0
local reverbEffect = nil
local equalizerEffect = nil

local currentVelocityCurve = "Linear"
local recentNoteTimes = {}
local CHORD_WINDOW = 0.035

-- Spatial tracking tables (Weak-keyed to auto-GC destroyed instances)
local spatialActiveNotes = {}
local spatialSustainedNotes = setmetatable({}, { __mode = "k" })
local spatialTransposes = setmetatable({}, { __mode = "k" })
local spatialSoundfonts = setmetatable({}, { __mode = "k" })

-- Setup Piano SoundGroup, Reverb Engine, & Equalizer
local pianoGroup = SoundService:FindFirstChild("PianoSoundGroup")
if not pianoGroup then
	pianoGroup = Instance.new("SoundGroup")
	pianoGroup.Name = "PianoSoundGroup"
	pianoGroup.Parent = SoundService
end
pianoGroup.Volume = 1.0

reverbEffect = pianoGroup:FindFirstChild("PianoReverb")
if not reverbEffect then
	reverbEffect = Instance.new("ReverbSoundEffect")
	reverbEffect.Name = "PianoReverb"
	reverbEffect.Parent = pianoGroup
end

reverbEffect.DecayTime = 1.8
reverbEffect.Density = 0.5
reverbEffect.Diffusion = 0.6
reverbEffect.DryLevel = 0
reverbEffect.WetLevel = -18
reverbEffect.Priority = 2
reverbEffect.Enabled = false

equalizerEffect = pianoGroup:FindFirstChild("PianoEQ")
if not equalizerEffect then
	equalizerEffect = Instance.new("EqualizerSoundEffect")
	equalizerEffect.Name = "PianoEQ"
	equalizerEffect.Parent = pianoGroup
end

equalizerEffect.LowGain = 0.5
equalizerEffect.MidGain = 1.0
equalizerEffect.HighGain = 1.5
equalizerEffect.Enabled = true

-- ============================================================================
-- EXPRESSION, CURVES & SCALING HELPERS
-- ============================================================================

function AudioEngine.SetReverbEnabled(enabled)
	if reverbEffect then
		reverbEffect.Enabled = enabled
	end
end

function AudioEngine.SetVelocityCurve(curveType)
	if curveType == "Linear" or curveType == "Soft" or curveType == "Hard" or curveType == "SCurve" then
		currentVelocityCurve = curveType
	end
end

function AudioEngine.GetVelocityCurve()
	return currentVelocityCurve
end

local function applyVelocityCurve(rawVolume)
	rawVolume = math.clamp(rawVolume, 0, 1)
	if currentVelocityCurve == "Soft" then
		return math.pow(rawVolume, 0.60)
	elseif currentVelocityCurve == "Hard" then
		return math.pow(rawVolume, 1.30)
	elseif currentVelocityCurve == "SCurve" then
		return 1 / (1 + math.exp(-8 * (rawVolume - 0.5)))
	end
	return rawVolume
end

local function calculateChordScale()
	local now = os.clock()
	local chordCount = 0

	for i = #recentNoteTimes, 1, -1 do
		if (now - recentNoteTimes[i]) <= CHORD_WINDOW then
			chordCount = chordCount + 1
		else
			table.remove(recentNoteTimes, i)
		end
	end

	table.insert(recentNoteTimes, now)

	if chordCount > 1 then
		return math.max(0.85, 1.0 - ((chordCount - 1) * 0.025))
	end
	return 1.0
end

local function applyPan(sound, panValue)
	if sound and sound:IsA("Sound") then
		pcall(function()
			sound.Pan = panValue
		end)
	end
end

function AudioEngine.SetTranspose(shift)
	transposeShift = shift or 0
end

function AudioEngine.GetTranspose()
	return transposeShift
end

function AudioEngine.SetSpatialTranspose(pianoModelOrPart, shiftValue)
	if not pianoModelOrPart then return end
	local soundOrigin = pianoModelOrPart:IsA("BasePart") and pianoModelOrPart
		or (pianoModelOrPart:IsA("Model") and (pianoModelOrPart.PrimaryPart or pianoModelOrPart:FindFirstChildWhichIsA("BasePart")))

	if soundOrigin then
		spatialTransposes[soundOrigin] = shiftValue or 0
	end
end

local function getSpatialTranspose(soundOrigin)
	return spatialTransposes[soundOrigin] or 0
end

function AudioEngine.SetSpatialSoundfont(pianoModelOrPart, fontName)
	if not pianoModelOrPart then return end
	local soundOrigin = pianoModelOrPart:IsA("BasePart") and pianoModelOrPart
		or (pianoModelOrPart:IsA("Model") and (pianoModelOrPart.PrimaryPart or pianoModelOrPart:FindFirstChildWhichIsA("BasePart")))

	if soundOrigin then
		spatialSoundfonts[soundOrigin] = fontName
	end
end

local function getSpatialSoundfont(soundOrigin)
	return spatialSoundfonts[soundOrigin] or currentSoundfontName
end

function AudioEngine.SetSoundfont(fontName, onComplete)
	if SoundRegistry[fontName] then
		AudioEngine.DampenAllNotes()
		currentSoundfontName = fontName
	end
	if onComplete then onComplete() end
end

function AudioEngine.GetSoundfont()
	return currentSoundfontName
end

function AudioEngine.GetAvailableSoundfonts()
	local fonts = {}
	for name in pairs(SoundRegistry) do
		table.insert(fonts, name)
	end
	return fonts
end

function AudioEngine.UpdateReverbProperty(propertyName, rawValue)
	-- Extract only numbers, decimals, and minus signs if the string has units (e.g., "1.5s" -> "1.5")
	local cleanValue = type(rawValue) == "string" and string.gsub(rawValue, "[^%d%.%-]", "") or rawValue
	local numValue = tonumber(cleanValue) or 0 -- Replace 0 with your default fallback

	-- Set property on your ReverbSoundEffect instance
	if reverbEffect and reverbEffect[propertyName] ~= nil then
		reverbEffect[propertyName] = numValue
	end
end

function AudioEngine.UpdateEQProperty(prop, value)
	if equalizerEffect and equalizerEffect[prop] ~= nil then
		equalizerEffect[prop] = value
	end
end

function AudioEngine.SetMasterVolume(volume)
	pianoGroup.Volume = math.clamp(volume, 0, 1)
end

local function getReleaseTime(noteIndex)
	if noteIndex >= 68 then
		return nil
	end
	local factor = math.clamp((noteIndex - 1) / 67, 0, 1)
	return 0.45 - (factor * 0.20)
end

local function calculatePan(noteIndex)
	return math.clamp(((noteIndex - 1) / 87) * 1.2 - 0.6, -0.6, 0.6)
end

local function calculatePolyphonyScale()
	local totalActive = 0
	for _ in pairs(activeNotes) do
		totalActive = totalActive + 1
	end
	local totalRinging = totalActive + #sustainedNotes

	if totalRinging > 12 then
		return math.max(0.82, 1.0 - ((totalRinging - 12) * 0.008))
	end
	return 1.0
end

local function enforceVoiceStealing()
	while #sustainedNotes > MAX_POLYPHONY do
		local oldestSound = table.remove(sustainedNotes, 1)
		if oldestSound and oldestSound.Parent then
			oldestSound:Destroy()
		end
	end
end

-- ============================================================================
-- VELOCITY LAYERING (SOFT, MEDIUM, LOUD)
-- ============================================================================

local function calculateVelocityLayers(volume, fontOverride, noteIndex)
	local targetFontName = fontOverride or currentSoundfontName
	local fontData = SoundRegistry[targetFontName] or SoundRegistry["Salamander Grand"]
	if not fontData then return {} end

	local softTable = fontData.Soft
	local mediumTable = fontData.Medium
	local loudTable = fontData.Loud

	volume = applyVelocityCurve(volume)

	local polyphonyScale = calculatePolyphonyScale()
	local chordScale = calculateChordScale()
	local fontGain = FONT_VOLUME_GAINS[targetFontName] or 1.0

	volume = math.clamp(volume * polyphonyScale * chordScale * fontGain, 0.12, 1.0)

	local fontLayerGains = velocityVolumes[targetFontName] or {}
	local softMult = fontLayerGains.Soft or 1.0
	local medMult = fontLayerGains.Medium or 1.0
	local loudMult = fontLayerGains.Loud or 1.0

	if volume <= 0.38 then
		local weight = math.clamp((volume * 1.8) * softMult, 0.01, 1.0)
		return { { layerTable = softTable, weight = weight } }
	elseif volume < 0.48 then
		local alpha = (volume - 0.38) / 0.10
		local softWeight = math.clamp(((1 - alpha) * 0.75) * softMult, 0.01, 1.0)
		local medWeight = math.clamp((alpha * 0.70) * medMult, 0.01, 1.0)
		return {
			{ layerTable = softTable, weight = softWeight },
			{ layerTable = mediumTable, weight = medWeight }
		}
	elseif volume <= 0.78 then
		local weight = math.clamp((volume * 0.90) * medMult, 0.01, 1.0)
		return { { layerTable = mediumTable, weight = weight } }
	elseif volume < 0.88 then
		local alpha = (volume - 0.78) / 0.10
		local medWeight = math.clamp(((1 - alpha) * 0.80) * medMult, 0.01, 1.0)
		local loudWeight = math.clamp((alpha * 0.90) * loudMult, 0.01, 1.0)
		return {
			{ layerTable = mediumTable, weight = medWeight },
			{ layerTable = loudTable, weight = loudWeight }
		}
	else
		local weight = math.clamp(math.min(volume * 0.95, 1.0) * loudMult, 0.01, 1.0)
		return { { layerTable = loudTable, weight = weight } }
	end
end

local function getSampleParameters(layerTable, actualNoteIndex)
	local maxSamples = layerTable and layerTable._count or 88

	if maxSamples >= 80 then
		local sampleIndex = math.clamp(actualNoteIndex, 1, 88)
		return sampleIndex, 1.0
	else
		local sampleIndex = math.clamp(math.floor((actualNoteIndex - 1) / 3) + 1, 1, 30)
		local semitoneOffset = (actualNoteIndex - 1) - ((sampleIndex - 1) * 3)
		local calculatedPitch = math.pow(2, semitoneOffset / 12)
		return sampleIndex, calculatedPitch
	end
end

-- ============================================================================
-- NOTE PLAYBACK ENGINE
-- ============================================================================

function AudioEngine.PlayNote(keyCode, baseNoteIndex, volume)
	volume = volume or 0.65

	local actualNoteIndex = baseNoteIndex + transposeShift
	AudioEngine.ReleaseKey(keyCode, false, true)

	local panValue = calculatePan(actualNoteIndex)
	local layerSpecs = calculateVelocityLayers(volume, nil, actualNoteIndex)
	local spawnedSounds = {}

	for _, layer in ipairs(layerSpecs) do
		if layer.weight > 0.01 and layer.layerTable then
			local sampleIndex, calculatedPitch = getSampleParameters(layer.layerTable, actualNoteIndex)
			local soundId = layer.layerTable[tostring(sampleIndex)]

			if soundId and soundId ~= "" then
				local sound = Instance.new("Sound")
				sound.SoundId = soundId
				sound.SoundGroup = pianoGroup
				sound.PlaybackSpeed = calculatedPitch
				sound.Volume = layer.weight
				applyPan(sound, panValue)
				sound:SetAttribute("NoteIndex", actualNoteIndex)
				sound.Parent = SoundService

				sound.Ended:Connect(function()
					sound:Destroy()
				end)

				sound:Play()
				table.insert(spawnedSounds, sound)
			end
		end
	end

	activeNotes[keyCode] = {
		Sounds = spawnedSounds,
		NoteIndex = actualNoteIndex
	}

	enforceVoiceStealing()
end

function AudioEngine.ReleaseKey(keyCode, isSustainOn, isVoiceSteal)
	local noteData = activeNotes[keyCode]
	if noteData then
		if isSustainOn and not isVoiceSteal then
			for _, sound in ipairs(noteData.Sounds) do
				table.insert(sustainedNotes, sound)
			end
			enforceVoiceStealing()
		else
			local releaseTime = isVoiceSteal and 0.04 or getReleaseTime(noteData.NoteIndex)

			for _, sound in ipairs(noteData.Sounds) do
				if sound and sound.Parent then
					if releaseTime then
						local tween = TweenService:Create(
							sound,
							TweenInfo.new(releaseTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
							{ Volume = 0 }
						)
						tween:Play()
						tween.Completed:Connect(function()
							sound:Destroy()
						end)
					else
						sound:Destroy()
					end
				end
			end
		end
		activeNotes[keyCode] = nil
	end
end

function AudioEngine.DampenUnheldNotes()
	for _, sound in ipairs(sustainedNotes) do
		if sound and sound.Parent then
			local noteIndex = sound:GetAttribute("NoteIndex") or 44
			local baseReleaseTime = getReleaseTime(noteIndex) or 0.25
			local dampenDuration = math.clamp(baseReleaseTime * 1.15, 0.18, 0.45)

			local tween = TweenService:Create(
				sound,
				TweenInfo.new(dampenDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{ Volume = 0 }
			)
			tween:Play()
			tween.Completed:Connect(function()
				sound:Destroy()
			end)
		end
	end
	table.clear(sustainedNotes)
end

function AudioEngine.DampenLoudRingingNotes(targetCeiling)
	targetCeiling = targetCeiling or 0.40
	local dampenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	for _, noteData in pairs(activeNotes) do
		for _, sound in ipairs(noteData.Sounds) do
			if sound and sound.Parent and sound.Volume > targetCeiling then
				TweenService:Create(sound, dampenInfo, { Volume = sound.Volume * 0.50 }):Play()
			end
		end
	end

	for _, sound in ipairs(sustainedNotes) do
		if sound and sound.Parent and sound.Volume > targetCeiling then
			TweenService:Create(sound, dampenInfo, { Volume = sound.Volume * 0.45 }):Play()
		end
	end
end

function AudioEngine.DampenAllNotes()
	for _, noteData in pairs(activeNotes) do
		for _, sound in ipairs(noteData.Sounds) do
			if sound and sound.Parent then sound:Destroy() end
		end
	end
	table.clear(activeNotes)

	for _, sound in ipairs(sustainedNotes) do
		if sound and sound.Parent then
			sound:Destroy()
		end
	end
	table.clear(sustainedNotes)
end

-- ============================================================================
-- SPATIAL (WORLD 3D) AUDIO METHODS
-- ============================================================================

function AudioEngine.PlaySpatialNote(pianoModelOrPart, baseNoteIndex, volume)
	if not pianoModelOrPart then return end

	local soundOrigin = pianoModelOrPart:IsA("BasePart") and pianoModelOrPart
		or (pianoModelOrPart:IsA("Model") and (pianoModelOrPart.PrimaryPart or pianoModelOrPart:FindFirstChildWhichIsA("BasePart")))

	if not soundOrigin then return end

	volume = volume or 0.65
	local shift = getSpatialTranspose(soundOrigin)
	local actualNoteIndex = baseNoteIndex + shift

	local panValue = calculatePan(actualNoteIndex)
	local soundfontName = getSpatialSoundfont(soundOrigin)
	local layerSpecs = calculateVelocityLayers(volume, soundfontName, actualNoteIndex)
	local keyId = soundOrigin:GetFullName() .. "_" .. tostring(baseNoteIndex)

	if spatialActiveNotes[keyId] then
		for _, sound in ipairs(spatialActiveNotes[keyId]) do
			if sound and sound.Parent then sound:Destroy() end
		end
		spatialActiveNotes[keyId] = nil
	end

	local spawnedSounds = {}

	for _, layer in ipairs(layerSpecs) do
		if layer.weight > 0.01 and layer.layerTable then
			local sampleIndex, calculatedPitch = getSampleParameters(layer.layerTable, actualNoteIndex)
			local soundId = layer.layerTable[tostring(sampleIndex)]

			if soundId and soundId ~= "" then
				local sound = Instance.new("Sound")
				sound.SoundId = soundId
				sound.SoundGroup = pianoGroup
				sound.PlaybackSpeed = calculatedPitch
				sound.Volume = layer.weight
				applyPan(sound, panValue)
				sound.RollOffMode = Enum.RollOffMode.InverseTapered
				sound.RollOffMinDistance = 12

				local maxDist = 140
				local visualizer = pianoModelOrPart:FindFirstChild("AudioHitboxVisualizer")
					or (pianoModelOrPart.Parent and pianoModelOrPart.Parent:FindFirstChild("AudioHitboxVisualizer"))

				if visualizer and visualizer:IsA("BasePart") then
					maxDist = math.max(visualizer.Size.X, 20)
				end

				sound.RollOffMaxDistance = maxDist
				sound:SetAttribute("NoteIndex", actualNoteIndex)
				sound.Parent = soundOrigin

				sound.Ended:Connect(function()
					sound:Destroy()
				end)

				sound:Play()
				table.insert(spawnedSounds, sound)
			end
		end
	end

	spatialActiveNotes[keyId] = spawnedSounds
end

function AudioEngine.ReleaseSpatialNote(pianoModelOrPart, baseNoteIndex, isSustainOn)
	if not pianoModelOrPart then return end

	local soundOrigin = pianoModelOrPart:IsA("BasePart") and pianoModelOrPart
		or (pianoModelOrPart:IsA("Model") and (pianoModelOrPart.PrimaryPart or pianoModelOrPart:FindFirstChildWhichIsA("BasePart")))

	if not soundOrigin then return end

	local keyId = soundOrigin:GetFullName() .. "_" .. tostring(baseNoteIndex)
	local soundInstances = spatialActiveNotes[keyId]

	if soundInstances then
		spatialActiveNotes[keyId] = nil

		if isSustainOn then
			if not spatialSustainedNotes[soundOrigin] then
				spatialSustainedNotes[soundOrigin] = {}
			end
			for _, sound in ipairs(soundInstances) do
				table.insert(spatialSustainedNotes[soundOrigin], sound)
			end
		else
			local shift = getSpatialTranspose(soundOrigin)
			local actualNoteIndex = baseNoteIndex + shift
			local releaseTime = getReleaseTime(actualNoteIndex)

			for _, sound in ipairs(soundInstances) do
				if sound and sound.Parent then
					if releaseTime then
						local tween = TweenService:Create(
							sound,
							TweenInfo.new(releaseTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
							{ Volume = 0 }
						)
						tween:Play()
						tween.Completed:Connect(function()
							sound:Destroy()
						end)
					else
						sound:Destroy()
					end
				end
			end
		end
	end
end

function AudioEngine.DampenSpatialNotes(pianoModelOrPart)
	if not pianoModelOrPart then return end

	local soundOrigin = pianoModelOrPart:IsA("BasePart") and pianoModelOrPart
		or (pianoModelOrPart:IsA("Model") and (pianoModelOrPart.PrimaryPart or pianoModelOrPart:FindFirstChildWhichIsA("BasePart")))

	if not soundOrigin or not spatialSustainedNotes[soundOrigin] then return end

	for _, sound in ipairs(spatialSustainedNotes[soundOrigin]) do
		if sound and sound.Parent then
			local noteIndex = sound:GetAttribute("NoteIndex") or 44
			local baseReleaseTime = getReleaseTime(noteIndex) or 0.25
			local dampenDuration = math.clamp(baseReleaseTime * 1.15, 0.18, 0.45)

			local tween = TweenService:Create(
				sound,
				TweenInfo.new(dampenDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{ Volume = 0 }
			)
			tween:Play()
			tween.Completed:Connect(function()
				sound:Destroy()
			end)
		end
	end
	spatialSustainedNotes[soundOrigin] = nil
end

function AudioEngine.CleanupSpatial(pianoModelOrPart)
	if not pianoModelOrPart then return end
	local soundOrigin = pianoModelOrPart:IsA("BasePart") and pianoModelOrPart
		or (pianoModelOrPart:IsA("Model") and (pianoModelOrPart.PrimaryPart or pianoModelOrPart:FindFirstChildWhichIsA("BasePart")))

	if not soundOrigin then return end

	AudioEngine.DampenSpatialNotes(soundOrigin)

	local prefix = soundOrigin:GetFullName() .. "_"
	local keysToRemove = {}

	for keyId, sounds in spatialActiveNotes do
		if keyId:sub(1, #prefix) == prefix then
			for _, sound in sounds do
				if sound and sound.Parent then
					sound:Destroy()
				end
			end
			table.insert(keysToRemove, keyId)
		end
	end

	for _, keyToClear in ipairs(keysToRemove) do
		spatialActiveNotes[keyToClear] = nil
	end

	spatialTransposes[soundOrigin] = nil
	spatialSoundfonts[soundOrigin] = nil
end

return AudioEngine