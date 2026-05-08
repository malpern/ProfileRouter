local helper = require("tests.test_helper")
local urlhandler = helper.loadModule("urlhandler")

describe("urlhandler", function()

    after_each(function()
        hs.urlevent.httpCallback = nil
    end)

    describe("register", function()
        it("sets httpCallback", function()
            local browserMod = { openTab = function() end }
            local b = { bundleID = "com.test", name = "Test" }
            local profilesMod = { matchURL = function() return nil end }
            local profileList = helper.makeProfiles(
                { name = "Default", isDefault = true }
            )
            local moverMod = { findProfileWindow = function() return nil end, getWindowIndex = function() return 1 end }

            urlhandler.register(browserMod, b, profilesMod, profileList, moverMod, {})
            assert.is_function(hs.urlevent.httpCallback)
        end)

        it("routes to matched profile", function()
            local openedWith = {}
            local browserMod = {
                openTab = function(b, idx, url)
                    openedWith = { index = idx, url = url }
                end,
            }
            local b = { bundleID = "com.test", name = "Test" }
            local workProfile = { name = "Work", titlePattern = "Work:", isDefault = false, rules = { domains = {}, paths = {} } }
            local profileList = {
                workProfile,
                { name = "Personal", isDefault = true, rules = { domains = {}, paths = {} } },
            }
            local profilesMod = {
                matchURL = function(url)
                    if url:find("slack.com") then return workProfile end
                    return nil
                end,
            }

            local targetWin = {
                focus = function() end,
                id = function() return 1 end,
            }
            local app = {
                activate = function() end,
                allWindows = function() return { targetWin } end,
            }
            hs.application.find = function() return app end

            local moverMod = {
                findProfileWindow = function(_, profile)
                    if profile.name == "Work" then return targetWin end
                    return nil
                end,
                getWindowIndex = function() return 1 end,
            }

            urlhandler.register(browserMod, b, profilesMod, profileList, moverMod, {})
            hs.urlevent.httpCallback("https", "slack.com", {}, "https://slack.com/messages")

            assert.equals("https://slack.com/messages", openedWith.url)
        end)

        it("falls back to default profile for unmatched URL", function()
            local routedTo = nil
            local browserMod = { openTab = function() end }
            local b = { bundleID = "com.test", name = "Test" }
            local profileList = {
                { name = "Work", titlePattern = "Work:", isDefault = false, rules = { domains = {}, paths = {} } },
                { name = "Personal", isDefault = true, rules = { domains = {}, paths = {} } },
            }
            local profilesMod = { matchURL = function() return nil end }

            local targetWin = { focus = function() end, id = function() return 1 end }
            local app = {
                activate = function() end,
                allWindows = function() return { targetWin } end,
            }
            hs.application.find = function() return app end

            local moverMod = {
                findProfileWindow = function(_, profile)
                    routedTo = profile.name
                    return targetWin
                end,
                getWindowIndex = function() return 1 end,
            }

            urlhandler.register(browserMod, b, profilesMod, profileList, moverMod, {})
            hs.urlevent.httpCallback("https", "example.com", {}, "https://example.com")

            assert.equals("Personal", routedTo)
        end)
    end)

    describe("unregister", function()
        it("clears httpCallback", function()
            hs.urlevent.httpCallback = function() end
            urlhandler.unregister()
            assert.is_nil(hs.urlevent.httpCallback)
        end)
    end)
end)
