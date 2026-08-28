local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remoteFolder = ReplicatedStorage:WaitForChild("PianoRemotes")

local Service = {}
Service.publishSheetFunc = remoteFolder:WaitForChild("PublishCommunitySheet")
Service.fetchSheetsFunc = remoteFolder:WaitForChild("FetchCommunitySheets")
Service.deleteSheetFunc = remoteFolder:WaitForChild("DeleteCommunitySheet")
Service.fetchGenresFunc = remoteFolder:WaitForChild("FetchGenres")
Service.rateSheetFunc = remoteFolder:WaitForChild("RateCommunitySheet")

function Service.FetchAllSheets()
	local success, results = pcall(function()
		return Service.fetchSheetsFunc:InvokeServer("", "All")
	end)
	return success and type(results) == "table" and results or {}
end

function Service.FetchGenres()
	local success, results = pcall(function()
		return Service.fetchGenresFunc:InvokeServer()
	end)
	return success and type(results) == "table" and results or { "All" }
end

function Service.DeleteSheet(sheetId)
	return pcall(function()
		return Service.deleteSheetFunc:InvokeServer(sheetId)
	end)
end

function Service.RateSheet(sheetId, action)
	local success, res = pcall(function()
		return Service.rateSheetFunc:InvokeServer(sheetId, action)
	end)
	return success and type(res) == "table" and res or nil
end

function Service.PublishSheet(payload)
	local success, result, msg = false, false, "Network error"
	pcall(function()
		result, msg = Service.publishSheetFunc:InvokeServer(payload)
		success = true
	end)
	return success and result, msg
end

return Service