local profiles = {}

local ICONS = { "💼", "🏠", "🎓", "🔬", "🎯", "🌍", "🎨", "🔧" }

function profiles.discover(routesDir)
    local list = {}
    local pipe = io.popen('ls "' .. routesDir .. '"*.txt 2>/dev/null')
    if not pipe then return list end
    for path in pipe:lines() do
        local filename = path:match("([^/]+)$")
        local basename = filename:gsub("%.txt$", "")
        local name = basename:sub(1, 1):upper() .. basename:sub(2)
        list[#list + 1] = {
            name = name,
            titlePattern = name .. ":",
            routeFile = filename,
            icon = ICONS[(#list % #ICONS) + 1],
            isDefault = false,
            rules = { domains = {}, paths = {} },
        }
    end
    if #list == 0 then return list end

    local hasDefault = false
    for _, p in ipairs(list) do
        if p.isDefault then hasDefault = true; break end
    end
    if not hasDefault then
        list[#list].isDefault = true
        list[#list].titlePattern = nil
    end
    return list
end

function profiles.resolve(userProfiles, routesDir)
    if userProfiles and #userProfiles > 0 then
        local list = {}
        for i, up in ipairs(userProfiles) do
            list[i] = {
                name = up.name,
                titlePattern = up.titlePattern,
                routeFile = up.routeFile or (up.name:lower() .. ".txt"),
                icon = up.icon or ICONS[(i % #ICONS) + 1],
                isDefault = up.isDefault or false,
                rules = { domains = {}, paths = {} },
            }
        end
        local hasDefault = false
        for _, p in ipairs(list) do
            if p.isDefault then hasDefault = true; break end
        end
        if not hasDefault and #list > 0 then
            list[#list].isDefault = true
            list[#list].titlePattern = nil
        end
        return list
    end
    return profiles.discover(routesDir)
end

function profiles.detectDefaultFromWindows(profileList, bundleID)
    local app = hs.application.find(bundleID)
    if not app then return end

    local titles = {}
    for _, w in ipairs(app:allWindows()) do
        titles[#titles + 1] = w:title() or ""
    end
    if #titles == 0 then return end

    for _, p in ipairs(profileList) do
        local found = false
        for _, title in ipairs(titles) do
            if title:find(p.name .. ":", 1, true) then
                found = true
                break
            end
        end
        if found then
            p.titlePattern = p.name .. ":"
            p.isDefault = false
        else
            p.titlePattern = nil
            p.isDefault = true
        end
    end

    local defaultCount = 0
    for _, p in ipairs(profileList) do
        if p.isDefault then defaultCount = defaultCount + 1 end
    end
    if defaultCount ~= 1 then
        for _, p in ipairs(profileList) do
            p.isDefault = false
        end
        profileList[#profileList].isDefault = true
        profileList[#profileList].titlePattern = nil
    end
end

function profiles.loadRules(routesDir, filename)
    local rules = { domains = {}, paths = {} }
    local f = io.open(routesDir .. filename, "r")
    if not f then return rules end
    for line in f:lines() do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" and line:sub(1, 1) ~= "#" then
            if line:sub(1, 5) == "path:" then
                rules.paths[#rules.paths + 1] = line:sub(6):lower()
            else
                local domain = line:lower():gsub("^https?://", ""):gsub("/.*$", "")
                rules.domains[#rules.domains + 1] = domain
            end
        end
    end
    f:close()
    return rules
end

function profiles.loadAllRules(profileList, routesDir)
    for _, p in ipairs(profileList) do
        p.rules = profiles.loadRules(routesDir, p.routeFile)
    end
end

local function extractHost(url)
    return url:match("^https?://([^/:]+)")
end

local function extractHostAndPath(url)
    return url:lower():gsub("^https?://", ""):gsub("[?#].*$", "")
end

local function domainMatches(host, pattern)
    host = host:lower()
    pattern = pattern:lower()
    if host == pattern then return true end
    if host:sub(-#pattern - 1) == "." .. pattern then return true end
    return false
end

local function matchesRules(url, rules)
    local host = extractHost(url)
    if not host then return false end

    local hostAndPath = extractHostAndPath(url)
    for _, pathPattern in ipairs(rules.paths) do
        if hostAndPath:sub(1, #pathPattern) == pathPattern then
            return true
        end
    end

    for _, domain in ipairs(rules.domains) do
        if domainMatches(host, domain) then
            return true
        end
    end
    return false
end

function profiles.matchURL(url, profileList)
    for _, p in ipairs(profileList) do
        if matchesRules(url, p.rules) then
            return p
        end
    end
    return nil
end

function profiles.detectCurrent(windowTitle, profileList)
    if not windowTitle then return nil end
    for _, p in ipairs(profileList) do
        if p.titlePattern and windowTitle:find(p.titlePattern, 1, true) then
            return p
        end
    end
    for _, p in ipairs(profileList) do
        if p.isDefault then return p end
    end
    return profileList[1]
end

function profiles.findNext(currentName, profileList)
    for i, p in ipairs(profileList) do
        if p.name == currentName then
            return profileList[(i % #profileList) + 1]
        end
    end
    return profileList[1]
end

return profiles
