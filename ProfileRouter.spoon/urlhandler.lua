local urlhandler = {}

function urlhandler.register(browserMod, b, profilesMod, profileList, moverMod, opts)
    opts = opts or {}
    local flog = opts.flog or function() end

    hs.urlevent.httpCallback = function(scheme, host, params, fullURL)
        flog("=== External URL: " .. fullURL .. " ===")

        local targetProfile = profilesMod.matchURL(fullURL, profileList)
        if not targetProfile then
            for _, p in ipairs(profileList) do
                if p.isDefault then
                    targetProfile = p
                    break
                end
            end
            targetProfile = targetProfile or profileList[1]
        end
        flog("Routing to " .. targetProfile.name)

        local app = hs.application.find(b.bundleID)
        if not app then
            hs.application.launchBundleID(b.bundleID)
            hs.timer.usleep(1000000)
            app = hs.application.find(b.bundleID)
        end
        if not app then
            flog("WARN: Could not launch browser")
            return
        end

        local targetWin = moverMod.findProfileWindow(app, targetProfile, profileList)
        if targetWin then
            local targetIndex = moverMod.getWindowIndex(app, targetWin)
            browserMod.openTab(b, targetIndex, fullURL)
            targetWin:focus()
        else
            flog("WARN: " .. targetProfile.name .. " window not found, using window 1")
            browserMod.openTab(b, 1, fullURL)
        end

        app:activate()
    end
end

function urlhandler.unregister()
    hs.urlevent.httpCallback = nil
end

return urlhandler
