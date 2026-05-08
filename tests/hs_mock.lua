local hs = {}

hs.spoons = { scriptPath = function() return "" end }

hs.application = {
    find = function() return nil end,
    watcher = {
        new = function() return { start = function() end, stop = function() end } end,
        launched = 1,
    },
}

hs.window = {
    focusedWindow = function() return nil end,
    filter = {
        new = function()
            local f = {}
            function f:setAppFilter() return f end
            function f:subscribe() return f end
            function f:unsubscribeAll() return f end
            return f
        end,
        windowTitleChanged = "windowTitleChanged",
    },
}

hs.timer = {
    doAfter = function(_, fn) if fn then fn() end end,
    doEvery = function(_, fn)
        return { stop = function() end, _fn = fn }
    end,
    usleep = function() end,
}

hs.notify = {
    new = function(_, opts)
        return { send = function() end }
    end,
    activationTypes = { actionButtonClicked = 1 },
}

hs.hotkey = {
    bind = function(mods, key, fn)
        return { delete = function() end, _fn = fn }
    end,
}

hs.osascript = {
    applescript = function() return false, nil end,
}

hs.urlevent = {}

hs.pathwatcher = {
    new = function(_, fn)
        return { start = function(self) return self end, stop = function() end, _fn = fn }
    end,
}

return hs
