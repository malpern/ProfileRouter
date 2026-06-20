local browser = {}

browser.KNOWN = {
    {
        name = "Dia",
        bundleID = "company.thebrowser.dia",
        processName = "Dia",
        -- jsCapable=false: Dia 1.36.0's AppleScript-JS bridge CRASHES the browser
        -- (stack-overflow / EXC_BAD_ACCESS) when --enable-applescript-javascript is
        -- set and `execute javascript` is called. We never invoke the JS bridge on
        -- Dia, so YouTube playback-position preservation is unavailable here.
        -- Flip to true to re-test once The Browser Company fixes the crash.
        jsCapable = false,
        jsWarning = "Launch Dia with --enable-applescript-javascript for YouTube features",
    },
    {
        name = "Google Chrome",
        bundleID = "com.google.Chrome",
        processName = "Google Chrome",
        jsCapable = true,
        jsWarning = "Enable 'Allow JavaScript from Apple Events' in Chrome > View > Developer",
    },
}

function browser.detect()
    for _, b in ipairs(browser.KNOWN) do
        if hs.application.find(b.bundleID) then
            return b
        end
    end
    return nil
end

local function escape(s)
    return s:gsub('\\', '\\\\'):gsub('"', '\\"')
end

function browser.getURL(b, windowIndex)
    local ok, url = hs.osascript.applescript(string.format(
        'tell application "%s" to return URL of active tab of window %d',
        b.name, windowIndex or 1
    ))
    if ok and url and tostring(url):match("^https?://") then
        return tostring(url)
    end
    return nil
end

function browser.closeActiveTab(b, windowIndex)
    hs.osascript.applescript(string.format(
        'tell application "%s" to close active tab of window %d',
        b.name, windowIndex or 1
    ))
end

function browser.openTab(b, windowIndex, url)
    hs.osascript.applescript(string.format(
        'tell application "%s" to make new tab in window %d with properties {URL:"%s"}',
        b.name, windowIndex or 1, escape(url)
    ))
end

function browser.executeJS(b, windowIndex, js)
    -- Never drive the JS bridge on a browser whose engine crashes on it (see Dia).
    if b.jsCapable == false then return nil end
    local ok, result = hs.osascript.applescript(string.format(
        'tell application "%s" to tell active tab of window %d to execute javascript "%s"',
        b.name, windowIndex or 1, escape(js)
    ))
    if ok then return result end
    return nil
end

function browser.checkJSSupport(b)
    -- Browsers flagged jsCapable=false have no working/safe JS bridge; report
    -- "supported" so the launch watcher stays quiet (the feature is just off).
    if b.jsCapable == false then return true end
    local ok, _ = hs.osascript.applescript(string.format(
        'tell application "%s" to tell active tab of window 1 to execute javascript "true"',
        b.name
    ))
    return ok
end

function browser.sendKeystroke(b, key, mods)
    local modStr = ""
    if mods and #mods > 0 then
        local parts = {}
        for _, m in ipairs(mods) do
            parts[#parts + 1] = m .. " down"
        end
        modStr = "{" .. table.concat(parts, ", ") .. "}"
    end
    if modStr ~= "" then
        hs.osascript.applescript(string.format([[
            tell application "System Events"
                tell process "%s"
                    keystroke "%s" using %s
                end tell
            end tell
        ]], b.processName, key, modStr))
    else
        hs.osascript.applescript(string.format([[
            tell application "System Events"
                tell process "%s"
                    keystroke "%s"
                end tell
            end tell
        ]], b.processName, key))
    end
end

return browser
