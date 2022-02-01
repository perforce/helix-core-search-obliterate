local cjson = require "cjson"
local curl = require "cURL.safe"

local initDone = false
local config = {}

-- Remove leading and trailing whitespace from a string.
function trim( s )
	return ( s:gsub( "^%s*(.-)%s*$", "%1" ) )
end

-- Read the configuration settings the first time.
-- Read the global config first, then the instance config. The latter could
-- override the former if there are duplicate variable names. This is assumed
-- to be a desirable feature.
function init()
	-- Uncomment for debugging
	-- print("Initializing...")
	if initDone == false then
		for k, v in pairs(Helix.Core.Server.GetGlobalConfigData()) do
			if string.len(trim(v)) > 0 then
				config[k] = trim(v)
			end
		end

		for k, v in pairs(Helix.Core.Server.GetInstanceConfigData()) do
			if string.len(trim(v)) > 0 then
				config[k] = trim(v)
			end
		end
		initDone = true
	end
end

function GlobalConfigFields()
	return {}
end

function InstanceConfigFields()
	return {}
end

function InstanceConfigEvents()
	return { command = "pre-user-obliterate" }
end

function Command()
	init()
	-- Read p4searchUrl and xAuthToken from P4
	local p4 = P4.P4:new()
	p4:autoconnect()
	if not p4:connect() then
		Helix.Core.Server.ReportError( Helix.Core.P4API.Severity.E_FAILED, "Error connecting to server\n" )
		return false
	end
	local props = p4:run("property", "-l", "-nP4.P4Search.URL")
	local p4searchUrl = props[1]["value"]
	props = p4:run("property", "-l", "-nP4.P4Search.AUTH_TOKEN")
	local xAuthToken = props[1]["value"]
	p4:disconnect()

	local status = purgeESDoc(p4searchUrl, xAuthToken)
	Helix.Core.Server.SetClientMsg(status)

	return true
end

function purgeESDoc(p4searchUrl, xAuthToken)
	print("Executing helix-core-search-obliterate extension... ")
	headers = {
			"Accept: application/json",
			"X-Auth-Token: " .. xAuthToken
	}
	local argsQuoted = Helix.Core.Server.GetVar( "argsQuoted")
	local client = Helix.Core.Server.GetVar( "client")
	local clientcwd = Helix.Core.Server.GetVar( "clientcwd")
	print("argsQuoted: " .. argsQuoted )

	-- Separate parameters and files within argsQuoted
	local params, filesStr = getParamsAndFiles(argsQuoted)

	-- Check for -y option if found call the end point
	local dashy = false
	for k,v in pairs(params) do
			-- Important: %-(.-)y means find - followed by any number of letters then y
			if string.find(v, "%-(.-)y") == 1
			then
				dashy = true;
				print("Found -y")
			end
	end

	if (dashy) then
		local t = {
			["argsQuoted"] = filesStr,
			["client"] = client,
			["clientcwd"] = clientcwd
		}
		local encoded_payload = cjson.encode(t)
		print("encoded_payload: " .. encoded_payload)
		p4searchUrl = p4searchUrl .. "/api/v1/obliterate"
		print("Going to call url: " .. p4searchUrl)

		local c = curl.easy{
			url			= p4searchUrl,
			post		 = true,
			httpheader = headers,
			postfields = encoded_payload,
		}

		print("Going to call purge endpoint...")
		local response = c:perform()
		local code = c:getinfo(curl.INFO_RESPONSE_CODE)
		c:close()

		-- Unreachable server
		if not response
		then
			print("Purge request returned error " .. tostring(code))
			return "Unreachable server: " .. p4searchUrl
		end

		if code == 200 then
			-- Return nothing as returning a string breaks p4java.
			return ""
		else
			return "Purge request failed: Purge url: " .. p4searchUrl
		end
	end
end

function getParamsAndFiles(args)
	local filesStr = ""
	local params = {};

	local skipNext = false
	for w in string.gmatch(args, "[^,]*,?") do
		w = trim(w)
		if string.len(w) > 0
		then
			w = string.gsub(w, ",$", "")
			if string.find(w, "-") == 1
			then
			-- Add to parameters array
			table.insert(params, w)
			else
			-- This must be one of the actual path we want.
			filesStr = filesStr .. w .. ","
			end
		end
	end
	-- Remove the last comma
	filesStr = string.gsub(filesStr, ",$", "")
	return params, filesStr
end
