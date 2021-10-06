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

    local status = purgeESDoc()
    Helix.Core.Server.SetClientMsg(status)

    return true
end

function purgeESDoc()
    print("Executing helix-core-search-obliterate extension... ")

    local xAuthToken = config["auth_token"]
    local p4searchUrl = config["p4search_url"]
    local url = p4searchUrl
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
        print("Files extracted from argsQuoted: " .. filesStr)
        
        local t = {
            ["argsQuoted"] = filesStr,
            ["client"] = client,
            ["clientcwd"] = clientcwd
        }

        local encoded_payload = cjson.encode(t)
        print("encoded_payload: " .. encoded_payload)

        local c = curl.easy{
            url        = url,
            post       = true,
            httpheader = headers,
            postfields = encoded_payload,
        }

        print("Going to call purge endpoint...")
        local ok, err = c:perform()
        c:close()

        if not ok then
            return "Purge request failed: Purge url: " .. url
        -- Return nothing as returning a string breaks p4java.
        else return "" 
        end
    end
    return "Purge endpoint not called."

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
