local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PianoConfig = {}

-- Customization Configuration & Defaults
PianoConfig.CustomizationFolder = ReplicatedStorage:WaitForChild("StoreItems"):WaitForChild("Customize!")
PianoConfig.DefaultKeyPreset = "Default"
PianoConfig.DefaultUIPreset = "Default"

-- Standard 61-Key Body (Notes 16 to 76)
PianoConfig.KEY_MAP_NORMAL = {
	-- Octave 2 (Notes 16 - 32)
	[Enum.KeyCode.One]   = {normal = 16, shift = 17},
	[Enum.KeyCode.Two]   = {normal = 18, shift = 19},
	[Enum.KeyCode.Three] = {normal = 20, shift = 20},
	[Enum.KeyCode.Four]  = {normal = 21, shift = 22},
	[Enum.KeyCode.Five]  = {normal = 23, shift = 24},
	[Enum.KeyCode.Six]   = {normal = 25, shift = 26},
	[Enum.KeyCode.Seven] = {normal = 27, shift = 27},
	[Enum.KeyCode.Eight] = {normal = 28, shift = 29},
	[Enum.KeyCode.Nine]  = {normal = 30, shift = 31},
	[Enum.KeyCode.Zero]  = {normal = 32, shift = 32},

	-- Octave 3 (Notes 33 - 41)
	[Enum.KeyCode.Q]     = {normal = 33, shift = 34},
	[Enum.KeyCode.W]     = {normal = 35, shift = 36},
	[Enum.KeyCode.E]     = {normal = 37, shift = 38},
	[Enum.KeyCode.R]     = {normal = 39, shift = 39},
	[Enum.KeyCode.T]     = {normal = 40, shift = 41},

	-- Octave 4 (Notes 42 - 50)
	[Enum.KeyCode.Y]     = {normal = 42, shift = 43},
	[Enum.KeyCode.U]     = {normal = 44, shift = 44},
	[Enum.KeyCode.I]     = {normal = 45, shift = 46},
	[Enum.KeyCode.O]     = {normal = 47, shift = 48},
	[Enum.KeyCode.P]     = {normal = 49, shift = 50},

	-- Octave 5 (Notes 51 - 62)
	[Enum.KeyCode.A]     = {normal = 51, shift = 51},
	[Enum.KeyCode.S]     = {normal = 52, shift = 53},
	[Enum.KeyCode.D]     = {normal = 54, shift = 55},
	[Enum.KeyCode.F]     = {normal = 56, shift = 56},
	[Enum.KeyCode.G]     = {normal = 57, shift = 58},
	[Enum.KeyCode.H]     = {normal = 59, shift = 60},
	[Enum.KeyCode.J]     = {normal = 61, shift = 62},

	-- Octave 6 & 7 (Notes 63 - 76)
	[Enum.KeyCode.K]     = {normal = 63, shift = 63},
	[Enum.KeyCode.L]     = {normal = 64, shift = 65},
	[Enum.KeyCode.Z]     = {normal = 66, shift = 67},
	[Enum.KeyCode.X]     = {normal = 68, shift = 68},
	[Enum.KeyCode.C]     = {normal = 69, shift = 70},
	[Enum.KeyCode.V]     = {normal = 71, shift = 72},
	[Enum.KeyCode.B]     = {normal = 73, shift = 74},
	[Enum.KeyCode.N]     = {normal = 75, shift = 75},
	[Enum.KeyCode.M]     = {normal = 76, shift = 76},
}

-- Visual Pianos Extended Ctrl Layout (27 Extension Keys)
PianoConfig.KEY_MAP_CTRL = {
	-- Lower Extension: Notes 1 to 15 (15 Keys)
	[Enum.KeyCode.One]   = {normal = 1,  shift = 1},
	[Enum.KeyCode.Two]   = {normal = 2,  shift = 2},
	[Enum.KeyCode.Three] = {normal = 3,  shift = 3},
	[Enum.KeyCode.Four]  = {normal = 4,  shift = 4},
	[Enum.KeyCode.Five]  = {normal = 5,  shift = 5},
	[Enum.KeyCode.Six]   = {normal = 6,  shift = 6},
	[Enum.KeyCode.Seven] = {normal = 7,  shift = 7},
	[Enum.KeyCode.Eight] = {normal = 8,  shift = 8},
	[Enum.KeyCode.Nine]  = {normal = 9,  shift = 9},
	[Enum.KeyCode.Zero]  = {normal = 10, shift = 10},
	[Enum.KeyCode.Q]     = {normal = 11, shift = 11},
	[Enum.KeyCode.W]     = {normal = 12, shift = 12},
	[Enum.KeyCode.E]     = {normal = 13, shift = 13},
	[Enum.KeyCode.R]     = {normal = 14, shift = 14},
	[Enum.KeyCode.T]     = {normal = 15, shift = 15},

	-- Upper Extension: Notes 77 to 88 (12 Keys)
	[Enum.KeyCode.Y]     = {normal = 77, shift = 77},
	[Enum.KeyCode.U]     = {normal = 78, shift = 78},
	[Enum.KeyCode.I]     = {normal = 79, shift = 79},
	[Enum.KeyCode.O]     = {normal = 80, shift = 80},
	[Enum.KeyCode.P]     = {normal = 81, shift = 81},
	[Enum.KeyCode.A]     = {normal = 82, shift = 82},
	[Enum.KeyCode.S]     = {normal = 83, shift = 83},
	[Enum.KeyCode.D]     = {normal = 84, shift = 84},
	[Enum.KeyCode.F]     = {normal = 85, shift = 85},
	[Enum.KeyCode.G]     = {normal = 86, shift = 86},
	[Enum.KeyCode.H]     = {normal = 87, shift = 87},
	[Enum.KeyCode.J]     = {normal = 88, shift = 88},
}

-- Keys to sink so Roblox Studio shortcuts don't trigger while playing
PianoConfig.OVERRIDE_KEYS = {
	Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
	Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine, Enum.KeyCode.Zero,
	Enum.KeyCode.Q, Enum.KeyCode.W, Enum.KeyCode.E, Enum.KeyCode.R, Enum.KeyCode.T,
	Enum.KeyCode.Y, Enum.KeyCode.U, Enum.KeyCode.I, Enum.KeyCode.O, Enum.KeyCode.P,
	Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.F, Enum.KeyCode.G,
	Enum.KeyCode.H, Enum.KeyCode.J
}

return PianoConfig