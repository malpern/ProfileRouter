local youtube = {}

function youtube.isVideo(url)
    return url:match("youtube%.com/watch") or url:match("youtu%.be/") or false
end

function youtube.getVideoState(browserMod, b, windowIndex)
    local result = browserMod.executeJS(b, windowIndex,
        "var v = document.querySelector('video'); " ..
        "v ? JSON.stringify({time: Math.floor(v.currentTime), paused: v.paused}) : 'novideo'"
    )
    if not result then return nil, false end
    local s = tostring(result)
    if s == "novideo" then return nil, false end

    local time = tonumber(s:match('"time":%s*(%d+)')) or tonumber(s:match('\\"time\\":%s*(%d+)'))
    local pausedStr = s:match('"paused":%s*(%a+)') or s:match('\\"paused\\":%s*(%a+)')
    local paused = pausedStr == "true"

    if time and time > 0 then
        return time, not paused
    end
    return nil, false
end

function youtube.appendTimestamp(url, seconds)
    if not seconds or seconds <= 0 then return url end
    url = url:gsub("[?&]t=%d+s?", "")
    local separator = url:find("?") and "&" or "?"
    return url .. separator .. "t=" .. seconds .. "s"
end

function youtube.autoPlay(browserMod, b, windowIndex, delay)
    hs.timer.doAfter(delay or 3, function()
        browserMod.executeJS(b, windowIndex,
            "var v = document.querySelector('video'); if (v && v.paused) v.play();"
        )
    end)
end

return youtube
