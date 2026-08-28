local ThemeManager = {}

ThemeManager.CurrentTheme = nil
ThemeManager.CurrentGui = nil
ThemeManager.ThemeChanged = Instance.new("BindableEvent")
ThemeManager.OnThemeChanged = ThemeManager.ThemeChanged.Event

-- Key Color Management
ThemeManager.CurrentKeyColor = "Default"
ThemeManager.KeyColorChanged = Instance.new("BindableEvent")
ThemeManager.OnKeyColorChanged = ThemeManager.KeyColorChanged.Event

local descendantConnections = {}
local isApplying = false -- Re-entrancy guard lock

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

-- Lazy-require UIUtils to avoid circular dependency issues
local UIUtils = nil
local function getUIUtils()
	if not UIUtils then
		pcall(function()
			UIUtils = require(script.Parent:WaitForChild("UIUtils", 2))
		end)
	end
	return UIUtils
end

ThemeManager.Themes = {}

local STRICT_TRANSPARENT = {
	["ControlContainer"] = true,
	["SideToolbar"] = true,
	["RightPanel"] = true,
	["SideButtonContainer"] = true,
	["VelocityControlContainer"] = true,
	["BottomRightContainer"] = true,
}

-- Locate StoreItems / Customize folder directly
local function getCustomizeFolder()
	local storeItems = ReplicatedStorage:FindFirstChild("StoreItems", true)
	if storeItems then
		return storeItems:FindFirstChild("Customize!") or storeItems:FindFirstChild("Customize")
	end
	return nil
end

function ThemeManager.GetTheme()
	return ThemeManager.CurrentTheme
end

-- Resolve key color item data from StoreItems -> Customize! -> Piano Color Themes!
function ThemeManager.GetKeyColorData(keyColorName)
	if not keyColorName or keyColorName == "" or keyColorName == "Default" then
		return nil
	end

	local customizeFolder = getCustomizeFolder()
	if not customizeFolder then return nil end

	local colorsFolder = customizeFolder:FindFirstChild("Piano Color Themes!") or customizeFolder:FindFirstChild("PianoColors")
	if not colorsFolder then return nil end

	for _, config in ipairs(colorsFolder:GetChildren()) do
		if config.Name == keyColorName or config:GetAttribute("ItemName") == keyColorName or config:GetAttribute("ID") == keyColorName then
			return config:GetAttributes()
		end
	end

	return nil
end

-- Resolve theme data from StoreItems -> Customize! -> UI Themes
function ThemeManager.GetThemeData(themeNameOrData)
	if type(themeNameOrData) == "table" then
		return themeNameOrData
	end

	if not themeNameOrData or themeNameOrData == "" or themeNameOrData == "Default" or themeNameOrData == "None" then
		return nil
	end

	if ThemeManager.Themes[themeNameOrData] then
		return ThemeManager.Themes[themeNameOrData]
	end

	local customizeFolder = getCustomizeFolder()
	if customizeFolder then
		local uiThemesFolder = customizeFolder:FindFirstChild("UI Themes") or customizeFolder:FindFirstChild("UIThemes")
		if uiThemesFolder then
			for _, config in ipairs(uiThemesFolder:GetChildren()) do
				if config.Name == themeNameOrData or config:GetAttribute("ItemName") == themeNameOrData or config:GetAttribute("ThemeName") == themeNameOrData then
					local themeData = config:GetAttributes()

					for _, child in ipairs(config:GetChildren()) do
						if child:IsA("Color3Value") then
							themeData[child.Name] = child.Value
						elseif child:IsA("NumberValue") or child:IsA("IntValue") or child:IsA("BoolValue") then
							themeData[child.Name] = child.Value
						end
					end

					return themeData
				end
			end
		end
	end

	return nil
end

-- STRICT RESOLVER: Targets any valid Instance or GuiObject created by PianoUI modules
local function resolvePianoUI(target)
	if not target then return ThemeManager.CurrentGui end

	if typeof(target) == "Instance" then
		if target.Name == "PianoUI" or target.Name == "PianoGui" or target:GetAttribute("IsPianoUI") == true then 
			return target 
		end

		local found = target:FindFirstChild("PianoUI", true) or target:FindFirstChild("PianoGui", true)
		if found then return found end

		local ancestor = target:FindFirstAncestor("PianoUI") or target:FindFirstAncestor("PianoGui")
		if ancestor then return ancestor end

		if target:IsA("PlayerGui") or target:IsA("ScreenGui") or target:IsA("Frame") or target:IsA("Folder") then
			return target
		end
	end

	return ThemeManager.CurrentGui
end

local function extractThemeColors(themeData)
	if not themeData then return nil end

	local mainBg = themeData.MainBackground or themeData.MainBg or themeData.BG_DARK or themeData.Background or themeData.BG or themeData.WindowBg or themeData.MainColor or Color3.fromRGB(32, 34, 40)
	local secondaryBg = themeData.CardBackground or themeData.PANEL_BG or themeData.PanelBg or themeData.SecondaryBackground or themeData.SecondaryBg or themeData.CARD_BG or themeData.CardBg or themeData.ButtonBackground or Color3.fromRGB(42, 44, 52)
	local textColor = themeData.TextColor or themeData.Text or themeData.TEXT_MAIN or themeData.TextMain or themeData.PrimaryText or Color3.fromRGB(230, 230, 240)
	local subTextColor = themeData.TextMuted or themeData.SubTextColor or themeData.TEXT_MUTED or textColor:Lerp(mainBg, 0.4)
	local accentColor = themeData.AccentColor or themeData.ACCENT or themeData.Accent or themeData.Primary or themeData.Highlight or Color3.fromRGB(46, 204, 113)
	local strokeColor = themeData.StrokeColor or themeData.STROKE_COLOR or themeData.BorderColor or accentColor

	local inputBg = themeData.INPUT_BG or themeData.InputBg or themeData.TextBoxBg or mainBg:Lerp(Color3.fromRGB(0, 0, 0), 0.35)
	local trackBg = themeData.TrackBg or mainBg:Lerp(Color3.fromRGB(0, 0, 0), 0.5)

	return {
		-- Normalized Modern Palette Keys
		MainBg = mainBg,
		SecondaryBg = secondaryBg,
		InputBg = inputBg,
		TrackBg = trackBg,
		TextColor = textColor,
		SubTextColor = subTextColor,
		AccentColor = accentColor,
		StrokeColor = strokeColor,
		StrokeThickness = themeData.StrokeThickness or 1,
		EnableStroke = (themeData.EnableStroke ~= false) and ((themeData.StrokeTransparency or 0) < 1),

		-- Legacy Aliases for UIUtils Compatibility
		BG_DARK = mainBg,
		PANEL_BG = secondaryBg,
		CARD_BG = secondaryBg,
		CARD_SELECT = accentColor,
		INPUT_BG = inputBg,
		ACCENT = accentColor,
		ACCENT_GREEN = accentColor,
		TEXT_MAIN = textColor,
		TEXT_MUTED = subTextColor,
		STROKE_DEFAULT = strokeColor,
		COLOR_ON = accentColor,
		COLOR_BTN = secondaryBg,
		TEXT_ON = textColor,
		TEXT_OFF = subTextColor,
	}
end

-- Strictly validates if an instance belongs exclusively to Piano UI
local function isInsidePianoUI(inst)
	if not inst then return false end

	if inst:GetAttribute("IgnoreTheme") == true then
		return false
	end

	local root = ThemeManager.CurrentGui
	if root and (inst == root or inst:IsDescendantOf(root)) then
		return true
	end

	local curr = inst
	while curr and curr ~= game do
		if curr.Name == "PianoUI" or curr.Name == "PianoGui" or curr:GetAttribute("IsPianoUI") == true then
			return true
		end
		curr = curr.Parent
	end

	return true
end

local function isPianoKey(inst)
	local lowerName = inst.Name:lower()
	if lowerName == "onscreenpiano" or lowerName == "pianoframe" 
		or lowerName == "pianocontainer" or lowerName == "keyboardframe" 
		or lowerName == "keyscontainer" or lowerName == "keysframe" then
		return false
	end

	local current = inst
	while current and current ~= game do
		if current:GetAttribute("IsPianoKey") == true
			or current:GetAttribute("IgnoreTheme") == true
			or (current.Name:find("PianoKey") and current.Name:lower() ~= "onscreenpiano")
			or current.Name:find("Key_") then
			return true
		end
		current = current.Parent
	end
	return false
end

local function saveOriginalProperties(inst)
	if inst:GetAttribute("ThemeOriginalSaved") then return end
	inst:SetAttribute("ThemeOriginalSaved", true)

	if inst:IsA("GuiObject") then
		inst:SetAttribute("Orig_BGColor", inst.BackgroundColor3)
		inst:SetAttribute("Orig_BGTrans", inst.BackgroundTransparency)
	end
	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		inst:SetAttribute("Orig_TextColor", inst.TextColor3)
	end
	if inst:IsA("UIStroke") then
		inst:SetAttribute("Orig_StrokeColor", inst.Color)
		inst:SetAttribute("Orig_StrokeEnabled", inst.Enabled)
	end
end

local function restoreOriginalProperties(inst)
	if not inst:GetAttribute("ThemeOriginalSaved") then return end

	if inst:IsA("GuiObject") then
		local bg = inst:GetAttribute("Orig_BGColor")
		local trans = inst:GetAttribute("Orig_BGTrans")
		if bg ~= nil then inst.BackgroundColor3 = bg end
		if trans ~= nil then inst.BackgroundTransparency = trans end
	end
	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		local txt = inst:GetAttribute("Orig_TextColor")
		if txt ~= nil then inst.TextColor3 = txt end
	end
	if inst:IsA("UIStroke") then
		local sc = inst:GetAttribute("Orig_StrokeColor")
		local se = inst:GetAttribute("Orig_StrokeEnabled")
		if sc ~= nil then inst.Color = sc end
		if se ~= nil then inst.Enabled = se end
	end
end

local function isKnob(inst)
	local n = inst.Name:lower()
	return n:find("knob") or n:find("handle") or n:find("thumb") or inst:GetAttribute("IsSliderKnob") == true
end

local function isFill(inst)
	local n = inst.Name:lower()
	return n:find("fill") or n:find("progress") or inst:GetAttribute("IsSliderFill") == true
end

local function isTrack(inst)
	local n = inst.Name:lower()
	return n:find("track") or n:find("sliderbar") or inst:GetAttribute("IsSliderTrack") == true
end

function ThemeManager.ApplyToInstance(inst, rawThemeData)
	if not inst or isPianoKey(inst) or not isInsidePianoUI(inst) or inst:GetAttribute("IgnoreTheme") == true then return end
	if not (inst:IsA("GuiObject") or inst:IsA("UIStroke")) then return end

	saveOriginalProperties(inst)

	local colors = extractThemeColors(rawThemeData)
	if not colors then
		restoreOriginalProperties(inst)
		return
	end

	local instName = inst.Name
	local lowerName = instName:lower()

	if STRICT_TRANSPARENT[instName] or inst:GetAttribute("IsContainer") == true then
		if inst:IsA("GuiObject") then inst.BackgroundTransparency = 1 end
		local stroke = inst:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Enabled = false end
		return
	end

	if isKnob(inst) then
		if inst:IsA("GuiObject") then inst.BackgroundColor3 = Color3.fromRGB(255, 255, 255) end
		return
	end

	if isFill(inst) then
		if inst:IsA("GuiObject") then inst.BackgroundColor3 = colors.AccentColor end
		return
	end

	if isTrack(inst) then
		if inst:IsA("GuiObject") then inst.BackgroundColor3 = colors.TrackBg end
		return
	end

	if inst:IsA("TextBox") then
		inst.BackgroundColor3 = colors.InputBg
		inst.TextColor3 = colors.TextColor
		return
	end

	if inst:IsA("Frame") or inst:IsA("ScrollingFrame") or inst:IsA("CanvasGroup") then
		if lowerName:find("onscreenpiano") or lowerName == "pianoframe" or lowerName:find("keyboard") or lowerName:find("pianobar") then
			inst.BackgroundColor3 = colors.MainBg
			inst.BackgroundTransparency = 0
			return
		end

		if lowerName:find("header") or lowerName:find("topbar") or lowerName:find("sidebar") or lowerName:find("tab") then
			inst.BackgroundColor3 = colors.SecondaryBg
			inst.BackgroundTransparency = 0
			return
		end

		if lowerName:find("list") or lowerName:find("container") or lowerName:find("scroll") or lowerName:find("item") or lowerName:find("cell") or lowerName:find("row") then
			inst.BackgroundColor3 = colors.SecondaryBg
			inst.BackgroundTransparency = 0
			return
		end

		if lowerName:find("reverb") or lowerName:find("soundfont") 
			or lowerName:find("sheet") or lowerName:find("window") 
			or lowerName:find("panel") or lowerName:find("main") 
			or lowerName:find("nps") or lowerName:find("setting")
			or lowerName:find("dialog") or lowerName:find("popup")
			or lowerName:find("modal") or lowerName:find("menu") then
			inst.BackgroundColor3 = colors.MainBg
			inst.BackgroundTransparency = 0
			return
		end

		local depth = 0
		local p = inst.Parent
		while p and p ~= ThemeManager.CurrentGui do
			depth += 1
			p = p.Parent
		end

		local origTrans = inst:GetAttribute("Orig_BGTrans") or inst.BackgroundTransparency
		if origTrans < 0.95 or inst:GetAttribute("ForceSolid") == true then
			if depth > 2 then
				inst.BackgroundColor3 = colors.SecondaryBg
			else
				inst.BackgroundColor3 = colors.MainBg
			end
			inst.BackgroundTransparency = 0
		end
		return
	end

	if inst:IsA("TextButton") or inst:IsA("ImageButton") then
		local origBg = inst:GetAttribute("Orig_BGColor")
		local isGreenActive = (origBg == Color3.fromRGB(46, 204, 113)) or (inst:GetAttribute("IsActiveToggle") == true) or lowerName:find("active") or lowerName:find("on")

		if isGreenActive then
			inst.BackgroundColor3 = colors.AccentColor
		else
			inst.BackgroundColor3 = colors.SecondaryBg
		end
		inst.BackgroundTransparency = 0

		if inst:IsA("TextButton") then
			inst.TextColor3 = colors.TextColor
		end
		return
	end

	if inst:IsA("TextLabel") then
		inst.TextColor3 = colors.TextColor
		return
	end

	if inst:IsA("UIStroke") then
		if colors.EnableStroke then
			inst.Enabled = true
			inst.Color = colors.StrokeColor
			inst.Thickness = colors.StrokeThickness
		else
			inst.Enabled = false
		end
	end
end

local function disconnectAllDescendantListeners()
	for _, conn in ipairs(descendantConnections) do
		conn:Disconnect()
	end
	table.clear(descendantConnections)
end

function ThemeManager.ApplyTheme(targetGui, rawThemeData, suppressSignal)
	if isApplying then return end
	isApplying = true

	local rootUI = resolvePianoUI(targetGui)
	local themeData = ThemeManager.GetThemeData(rawThemeData)
	local previousTheme = ThemeManager.CurrentTheme

	ThemeManager.CurrentTheme = themeData

	-- Send extracted color palette straight into UIUtils
	local extractedColors = extractThemeColors(themeData)
	local utils = getUIUtils()
	if utils and extractedColors and type(utils.ApplyTheme) == "function" then
		utils.ApplyTheme(extractedColors)
	end

	if rootUI then
		ThemeManager.CurrentGui = rootUI
		disconnectAllDescendantListeners()

		for _, inst in ipairs(rootUI:GetDescendants()) do
			ThemeManager.ApplyToInstance(inst, themeData)
		end

		local conn = rootUI.DescendantAdded:Connect(function(newInst)
			task.defer(function()
				ThemeManager.ApplyToInstance(newInst, ThemeManager.CurrentTheme)
				for _, child in ipairs(newInst:GetDescendants()) do
					ThemeManager.ApplyToInstance(child, ThemeManager.CurrentTheme)
				end
			end)
		end)
		table.insert(descendantConnections, conn)
	end

	if not suppressSignal and previousTheme ~= themeData then
		ThemeManager.ThemeChanged:Fire(themeData)
	end

	isApplying = false
end

function ThemeManager.SetThemeByName(targetGui, themeName, skipSave)
	local target = resolvePianoUI(targetGui)
	local themeData = ThemeManager.GetThemeData(themeName)
	ThemeManager.ApplyTheme(target or ThemeManager.CurrentGui, themeData)

	if not skipSave then
		local remotes = ReplicatedStorage:FindFirstChild("PianoRemotes")
		if remotes then
			local updateSettingRemote = remotes:FindFirstChild("UpdatePlayerSetting")
			if updateSettingRemote then
				updateSettingRemote:FireServer("Settings", "Theme", themeName or "Default")
			end
		end
	end
end

-- Automatic Attribute Listeners
local function updateThemeFromAttribute()
	local themeName = localPlayer:GetAttribute("EquippedUITheme") 
		or localPlayer:GetAttribute("EquippedUIPreset") 
		or "Default"

	ThemeManager.SetThemeByName(ThemeManager.CurrentGui, themeName, true)
end

local function updateKeyColorFromAttribute()
	local keyColorName = localPlayer:GetAttribute("EquippedKeyColor") or "Default"
	ThemeManager.CurrentKeyColor = keyColorName

	local colorData = ThemeManager.GetKeyColorData(keyColorName)
	ThemeManager.KeyColorChanged:Fire(keyColorName, colorData)
end

localPlayer:GetAttributeChangedSignal("EquippedUITheme"):Connect(updateThemeFromAttribute)
localPlayer:GetAttributeChangedSignal("EquippedUIPreset"):Connect(updateThemeFromAttribute)
localPlayer:GetAttributeChangedSignal("EquippedKeyColor"):Connect(updateKeyColorFromAttribute)

task.spawn(function()
	updateThemeFromAttribute()
	updateKeyColorFromAttribute()
end)

return ThemeManager