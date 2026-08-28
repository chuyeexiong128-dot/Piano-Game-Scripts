local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local MultiTransposeController = {}

MultiTransposeController.Queue = {}
MultiTransposeController.CurrentIndex = 1
MultiTransposeController.OnTransposeChanged = nil

-- Set a custom transpose sequence (e.g. "0 2 5 -1")
function MultiTransposeController.SetSequence(rawInput)
	local queue = {}
	if type(rawInput) == "string" then
		for token in string.gmatch(rawInput, "[%+%-]?%d+") do
			local val = tonumber(token)
			if val then
				table.insert(queue, val)
			end
		end
	elseif type(rawInput) == "table" then
		queue = rawInput
	end

	MultiTransposeController.Queue = queue
	MultiTransposeController.CurrentIndex = 1

	if #queue > 0 then
		MultiTransposeController.ApplyCurrent()
	end

	return queue
end

-- Apply the active transpose from the current sequence index
function MultiTransposeController.ApplyCurrent()
	if #MultiTransposeController.Queue == 0 then return end

	local activeValue = MultiTransposeController.Queue[MultiTransposeController.CurrentIndex]

	if MultiTransposeController.OnTransposeChanged then
		MultiTransposeController.OnTransposeChanged(activeValue, MultiTransposeController.CurrentIndex, MultiTransposeController.Queue)
	end
end

-- Completely stop MultiTranspose and reset state
function MultiTransposeController.Reset()
	MultiTransposeController.Queue = {}
	MultiTransposeController.CurrentIndex = 1
end

-- Move to the next transpose in the sequence
function MultiTransposeController.Next()
	if #MultiTransposeController.Queue <= 1 then return end
	MultiTransposeController.CurrentIndex = MultiTransposeController.CurrentIndex + 1
	if MultiTransposeController.CurrentIndex > #MultiTransposeController.Queue then
		MultiTransposeController.CurrentIndex = 1
	end
	MultiTransposeController.ApplyCurrent()
end

-- Move to the previous transpose in the sequence
function MultiTransposeController.Previous()
	if #MultiTransposeController.Queue <= 1 then return end
	MultiTransposeController.CurrentIndex = MultiTransposeController.CurrentIndex - 1
	if MultiTransposeController.CurrentIndex < 1 then
		MultiTransposeController.CurrentIndex = #MultiTransposeController.Queue
	end
	MultiTransposeController.ApplyCurrent()
end

-- Aliases for compatibility
MultiTransposeController.NextTranspose = MultiTransposeController.Next
MultiTransposeController.PrevTranspose = MultiTransposeController.Previous

-- ============================================================================
-- CONTEXT ACTION SERVICE BINDINGS (Sinks input to prevent Roblox GUI overlaps)
-- ============================================================================
local ACTION_NEXT = "Piano_TransposeNext"
local ACTION_PREV = "Piano_TransposePrev"

local function handleTransposeAction(actionName, inputState, inputObject)
	-- Only trigger the action when the key is first pressed down
	if inputState ~= Enum.UserInputState.Begin then 
		return Enum.ContextActionResult.Pass 
	end

	-- Ignore keybinds if the player is currently typing in the chat or a GUI textbox
	if UserInputService:GetFocusedTextBox() ~= nil then 
		return Enum.ContextActionResult.Pass 
	end

	if actionName == ACTION_NEXT then
		if #MultiTransposeController.Queue > 1 then
			MultiTransposeController.Next()
		else
			-- Fallback: If no custom sequence is loaded, shift standard transpose up by +1 semitone
			if _G.PianoUI then
				local currentVal = _G.PianoUI.GetTranspose()
				_G.PianoUI.SetTranspose(currentVal + 1)
			end
		end
		return Enum.ContextActionResult.Sink -- Prevents Tab from opening the Roblox PlayerList/Leaderboard!

	elseif actionName == ACTION_PREV then
		if #MultiTransposeController.Queue > 1 then
			MultiTransposeController.Previous()
		else
			-- Fallback: If no custom sequence is loaded, shift standard transpose down by -1 semitone
			if _G.PianoUI then
				local currentVal = _G.PianoUI.GetTranspose()
				_G.PianoUI.SetTranspose(currentVal - 1)
			end
		end
		return Enum.ContextActionResult.Sink -- Sinks Caps Lock state-change behavior
	end

	return Enum.ContextActionResult.Pass
end

-- Call this when the player sits on the piano bench to activate keybinds
function MultiTransposeController.EnableBinds()
	ContextActionService:BindActionAtPriority(
		ACTION_NEXT,
		handleTransposeAction,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Tab
	)
	ContextActionService:BindActionAtPriority(
		ACTION_PREV,
		handleTransposeAction,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.CapsLock
	)
end

-- Call this when the player stands up to restore normal keyboard controls
function MultiTransposeController.DisableBinds()
	ContextActionService:UnbindAction(ACTION_NEXT)
	ContextActionService:UnbindAction(ACTION_PREV)
end

return MultiTransposeController