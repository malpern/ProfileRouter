--- === ProfileRouter ===
---
--- Route browser tabs between profiles automatically.
--- Supports Dia and Google Chrome with any number of profiles.
--- [Homepage](https://github.com/malpern/ProfileRouter)

local obj = {}
obj.__index = obj

obj.name = "ProfileRouter"
obj.version = "1.0"
obj.author = "Micah Alpern <malpern@gmail.com>"
obj.license = "MIT - https://opensource.org/licenses/MIT"
obj.homepage = "https://github.com/malpern/ProfileRouter"

local spoonPath = hs.spoons.scriptPath()
local browserMod = dofile(spoonPath .. "browser.lua")
local profilesMod = dofile(spoonPath .. "profiles.lua")
local moverMod = dofile(spoonPath .. "mover.lua")
local routerMod = dofile(spoonPath .. "router.lua")
local youtubeMod = dofile(spoonPath .. "youtube.lua")
local urlhandlerMod = dofile(spoonPath .. "urlhandler.lua")

--- ProfileRouter.browser
--- Variable
--- Browser config table with keys: name (string), bundleID (string), processName (string).
--- Auto-detected from running applications if nil. Checks Dia first, then Google Chrome.
obj.browser = nil

--- ProfileRouter.profiles
--- Variable
--- List of profile tables, each with keys: name (string), titlePattern (string or nil),
--- routeFile (string), icon (string), isDefault (boolean).
--- Auto-discovered from route files in `routesDir` if nil. Profile names are derived from
--- filenames (e.g., `work.txt` becomes "Work"). The default profile is detected automatically
--- by scanning browser window titles at start time.
obj.profiles = nil

--- ProfileRouter.routesDir
--- Variable
--- Directory containing route text files. Each `.txt` file defines a profile.
--- Default: `~/.hammerspoon/routes/`
obj.routesDir = os.getenv("HOME") .. "/.hammerspoon/routes/"

--- ProfileRouter.cooldownSeconds
--- Variable
--- Seconds before a manually-moved URL can be auto-routed again. Default: 600 (10 minutes).
obj.cooldownSeconds = 600

--- ProfileRouter.debug
--- Variable
--- When true, log activity to `~/.hammerspoon/profile-router.log`. Default: true.
obj.debug = true

obj._browser = nil
obj._profiles = nil
obj._watchers = {}
obj._timers = {}
obj._hotkeys = {}

local LOGFILE = os.getenv("HOME") .. "/.hammerspoon/profile-router.log"

local function flog(msg)
    if not obj.debug then return end
    local f = io.open(LOGFILE, "a")
    if f then
        f:write(os.date("%H:%M:%S") .. " " .. msg .. "\n")
        f:close()
    end
end

--- ProfileRouter:init()
--- Method
--- Initialize the Spoon. Called automatically by `hs.loadSpoon`.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The ProfileRouter object
function obj:init()
    return self
end

--- ProfileRouter:start()
--- Method
--- Start watching for tabs and routing them. Detects the browser, discovers profiles
--- from route files, starts the window title watcher, route file watcher, cooldown timer,
--- and external URL handler.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The ProfileRouter object
function obj:start()
    self._browser = self.browser or browserMod.detect()
    if not self._browser then
        flog("WARN: No supported browser detected, using Dia as default")
        self._browser = browserMod.KNOWN[1]
    end
    flog("Browser: " .. self._browser.name)

    self._profiles = profilesMod.resolve(self.profiles, self.routesDir)
    if #self._profiles == 0 then
        flog("WARN: No profiles found. Create route files in " .. self.routesDir)
        hs.notify.new(nil, {
            title = "ProfileRouter",
            informativeText = "No route files found in " .. self.routesDir,
            withdrawAfter = 5,
        }):send()
        return self
    end

    profilesMod.detectDefaultFromWindows(self._profiles, self._browser.bundleID)
    profilesMod.loadAllRules(self._profiles, self.routesDir)
    local profileNames = {}
    for _, p in ipairs(self._profiles) do
        profileNames[#profileNames + 1] = p.name .. (p.isDefault and " (default)" or "")
    end
    flog("Profiles: " .. table.concat(profileNames, ", "))

    routerMod._cooldownSeconds = self.cooldownSeconds

    self._watchers.titleFilter = routerMod.startWatcher(
        browserMod, self._browser, profilesMod, self._profiles, moverMod,
        { flog = flog, youtube = youtubeMod }
    )

    self._watchers.routeFiles = hs.pathwatcher.new(self.routesDir, function()
        profilesMod.loadAllRules(self._profiles, self.routesDir)
        local total = 0
        for _, p in ipairs(self._profiles) do
            total = total + #p.rules.domains + #p.rules.paths
        end
        flog("Routes reloaded: " .. total .. " rules")
        hs.notify.new(nil, {
            title = "Routes reloaded",
            informativeText = total .. " rules across " .. #self._profiles .. " profiles",
            withdrawAfter = 2,
        }):send()
    end):start()

    self._timers.cooldownCleanup = routerMod.startCleanupTimer()

    urlhandlerMod.register(
        browserMod, self._browser, profilesMod, self._profiles, moverMod,
        { flog = flog }
    )

    self._watchers.appWatcher = hs.application.watcher.new(function(name, event, app)
        if not app or app:bundleID() ~= self._browser.bundleID then return end
        if event ~= hs.application.watcher.launched then return end
        hs.timer.doAfter(8, function()
            if not browserMod.checkJSSupport(self._browser) then
                flog("WARN: Browser launched without JS support")
                hs.notify.new(nil, {
                    title = "ProfileRouter",
                    informativeText = self._browser.jsWarning,
                    withdrawAfter = 5,
                }):send()
            end
        end)
    end)
    self._watchers.appWatcher:start()

    flog("=== ProfileRouter started ===")
    return self
end

--- ProfileRouter:stop()
--- Method
--- Stop all watchers, timers, and hotkeys. Unregisters the external URL handler.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The ProfileRouter object
function obj:stop()
    for k, w in pairs(self._watchers) do
        if type(w.stop) == "function" then w:stop()
        elseif type(w.unsubscribeAll) == "function" then w:unsubscribeAll()
        end
        self._watchers[k] = nil
    end
    for k, t in pairs(self._timers) do
        t:stop()
        self._timers[k] = nil
    end
    for k, h in pairs(self._hotkeys) do
        h:delete()
        self._hotkeys[k] = nil
    end
    urlhandlerMod.unregister()
    flog("=== ProfileRouter stopped ===")
    return self
end

--- ProfileRouter:bindHotkeys(mapping)
--- Method
--- Bind hotkeys for ProfileRouter actions.
---
--- Parameters:
---  * mapping - A table with action names mapped to hotkey specs: `{modifiers, key}`.
---    Supported actions: `cycleTab`, `cycleProfile`.
---    Example: `{cycleTab = {{"ctrl"}, "s"}, cycleProfile = {{"ctrl"}, "a"}}`
---
--- Returns:
---  * The ProfileRouter object
function obj:bindHotkeys(mapping)
    if mapping.cycleTab then
        local mods, key = mapping.cycleTab[1], mapping.cycleTab[2]
        self._hotkeys.cycleTab = hs.hotkey.bind(mods, key, function()
            self:cycleTab()
        end)
    end
    if mapping.cycleProfile then
        local mods, key = mapping.cycleProfile[1], mapping.cycleProfile[2]
        self._hotkeys.cycleProfile = hs.hotkey.bind(mods, key, function()
            self:cycleProfile()
        end)
    end
    return self
end

--- ProfileRouter:cycleTab()
--- Method
--- Move the current tab to the next profile. With 2 profiles this toggles;
--- with 3+ it advances to the next and wraps around. Marks the URL on cooldown
--- so the auto-router won't move it back. Shows a notification with an Undo button.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function obj:cycleTab()
    flog("=== Cycle triggered ===")
    local b = self._browser
    if not b then return end

    local app = hs.application.frontmostApplication()
    if not app or app:bundleID() ~= b.bundleID then
        flog("WARN: Browser not frontmost")
        return
    end

    local win = hs.window.focusedWindow()
    if not win then return end

    local currentProfile = profilesMod.detectCurrent(win:title(), self._profiles)
    if not currentProfile then return end

    local targetProfile = profilesMod.findNext(currentProfile.name, self._profiles)
    flog("Cycling: " .. currentProfile.name .. " -> " .. targetProfile.name)

    local url = moverMod.moveTab(browserMod, b, app, self._profiles, targetProfile, {
        flog = flog,
        youtube = youtubeMod,
    })

    if url then
        routerMod.markRouted(url)

        local n = hs.notify.new(function(notification)
            if notification:activationType() == hs.notify.activationTypes.actionButtonClicked then
                routerMod.clearCooldown(url)
                flog("Cooldown cancelled for: " .. url)
                hs.notify.new(nil, {
                    title = "Cooldown cancelled",
                    informativeText = "Auto-routing re-enabled for this URL",
                    withdrawAfter = 2,
                }):send()
            end
        end, {
            title = (targetProfile.icon or "") .. "  Moved to " .. targetProfile.name,
            informativeText = url,
            actionButtonTitle = "Undo Cooldown",
            hasActionButton = true,
            withdrawAfter = 5,
        })
        n:send()
    end

    flog("=== Cycle done ===")
end

--- ProfileRouter:cycleProfile()
--- Method
--- Bring the next profile's browser window to the front without moving any tabs.
--- With 2 profiles this toggles; with 3+ it advances and wraps.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function obj:cycleProfile()
    flog("=== CycleProfile triggered ===")
    local b = self._browser
    if not b then return end

    local app = hs.application.get(b.bundleID)
    if not app then
        flog("WARN: Browser not running")
        return
    end

    local frontWin = hs.window.focusedWindow()
    local currentProfile
    if frontWin and app:bundleID() == (hs.application.frontmostApplication():bundleID()) then
        currentProfile = profilesMod.detectCurrent(frontWin:title(), self._profiles)
    end
    if not currentProfile then
        currentProfile = self._profiles[#self._profiles]
    end

    local targetProfile = profilesMod.findNext(currentProfile.name, self._profiles)
    flog("CycleProfile: " .. currentProfile.name .. " -> " .. targetProfile.name)

    local targetWin = moverMod.findProfileWindow(app, targetProfile, self._profiles)
    if not targetWin then
        flog("WARN: Could not find " .. targetProfile.name .. " window")
        hs.notify.new(nil, {
            title = "Profile Switch Failed",
            informativeText = "Could not find " .. targetProfile.name .. " window",
            withdrawAfter = 3,
        }):send()
        return
    end

    targetWin:focus()
    app:activate()
    flog("=== CycleProfile done ===")
end

return obj
