local router = {}

router._cooldowns = {}
router._cooldownSeconds = 600

function router.isOnCooldown(url)
    local t = router._cooldowns[url]
    if not t then return false end
    if os.time() - t > router._cooldownSeconds then
        router._cooldowns[url] = nil
        return false
    end
    return true
end

function router.markRouted(url)
    router._cooldowns[url] = os.time()
end

function router.clearCooldown(url)
    router._cooldowns[url] = nil
end

function router.startCleanupTimer()
    return hs.timer.doEvery(300, function()
        local now = os.time()
        for url, t in pairs(router._cooldowns) do
            if now - t > router._cooldownSeconds then
                router._cooldowns[url] = nil
            end
        end
    end)
end

function router.startWatcher(browserMod, b, profilesMod, profileList, moverMod, opts)
    opts = opts or {}
    local flog = opts.flog or function() end
    local youtubeMod = opts.youtube

    local filter = hs.window.filter.new(false):setAppFilter(b.name)
    filter:subscribe(hs.window.filter.windowTitleChanged, function(win)
        if not win then return end

        local app = win:application()
        if not app or app:bundleID() ~= b.bundleID then return end

        hs.timer.doAfter(0.5, function()
            local fw = hs.window.focusedWindow()
            if not fw or fw:id() ~= win:id() then return end

            local winIndex = moverMod.getWindowIndex(app, win)
            local url = browserMod.getURL(b, winIndex)
            if not url then return end

            flog("Title changed — URL: " .. url)

            local targetProfile = profilesMod.matchURL(url, profileList)
            if not targetProfile then
                flog("No routing rule")
                return
            end

            local currentProfile = profilesMod.detectCurrent(win:title(), profileList)
            if currentProfile and currentProfile.name == targetProfile.name then
                flog("Already in correct profile (" .. currentProfile.name .. ")")
                return
            end

            if router.isOnCooldown(url) then
                flog("On cooldown, skipping")
                return
            end

            flog("=== Auto-routing to " .. targetProfile.name .. " ===")
            router.markRouted(url)

            local movedURL = moverMod.moveTab(browserMod, b, app, profileList, targetProfile, {
                flog = flog,
                youtube = youtubeMod,
            })

            if movedURL then
                hs.notify.new(nil, {
                    title = (targetProfile.icon or "") .. "  Routed to " .. targetProfile.name,
                    informativeText = movedURL,
                    withdrawAfter = 2,
                }):send()
            end
        end)
    end)

    return filter
end

return router
