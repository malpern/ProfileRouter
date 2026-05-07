local mover = {}

function mover.findProfileWindow(app, profile, profileList)
    if not app then return nil end
    for _, w in ipairs(app:allWindows()) do
        local title = w:title() or ""
        if profile.titlePattern and title:find(profile.titlePattern, 1, true) then
            return w
        end
        if profile.isDefault then
            local claimed = false
            for _, other in ipairs(profileList) do
                if other.titlePattern and title:find(other.titlePattern, 1, true) then
                    claimed = true
                    break
                end
            end
            if not claimed then
                return w
            end
        end
    end
    return nil
end

function mover.getWindowIndex(app, targetWin)
    for i, w in ipairs(app:allWindows()) do
        if w:id() == targetWin:id() then
            return i
        end
    end
    return 1
end

function mover.moveTab(browserMod, b, app, profileList, targetProfile, opts)
    opts = opts or {}
    local flog = opts.flog or function() end
    local youtubeMod = opts.youtube

    local sourceWin = hs.window.focusedWindow()
    if not sourceWin then
        flog("WARN: No focused window")
        return nil
    end
    local sourceIndex = mover.getWindowIndex(app, sourceWin)

    local url = browserMod.getURL(b, sourceIndex)
    if not url then
        flog("WARN: No valid URL")
        hs.notify.new(nil, {
            title = "Tab Move Failed",
            informativeText = "No valid URL in active tab",
            withdrawAfter = 3,
        }):send()
        return nil
    end
    flog("URL: " .. url)

    local wasPlaying = false
    if youtubeMod and youtubeMod.isVideo(url) then
        flog("YouTube video detected")
        local seconds, playing = youtubeMod.getVideoState(browserMod, b, sourceIndex)
        wasPlaying = playing
        if seconds then
            flog("Position: " .. seconds .. "s, playing: " .. tostring(playing))
            url = youtubeMod.appendTimestamp(url, seconds)
        end
    end

    flog("Closing active tab")
    browserMod.closeActiveTab(b, sourceIndex)

    local targetWin = mover.findProfileWindow(app, targetProfile, profileList)
    if not targetWin then
        flog("WARN: Could not find " .. targetProfile.name .. " window")
        hs.notify.new(nil, {
            title = "Tab Move Failed",
            informativeText = "Could not find " .. targetProfile.name .. " window",
            withdrawAfter = 3,
        }):send()
        return nil
    end

    local targetIndex = mover.getWindowIndex(app, targetWin)
    flog("Opening in " .. targetProfile.name .. " (window " .. targetIndex .. ")")
    browserMod.openTab(b, targetIndex, url)

    targetWin:focus()
    app:activate()

    if wasPlaying and youtubeMod then
        flog("Resuming playback")
        youtubeMod.autoPlay(browserMod, b, targetIndex)
    end

    return url
end

return mover
