local helper = require("tests.test_helper")

describe("ProfileRouter init", function()
    local obj

    before_each(function()
        hs.application.find = function() return nil end
        hs.osascript.applescript = function() return false, nil end
        package.loaded["tests.test_helper"] = nil
        _G.hs = require("tests.hs_mock")
        local spoonPath = debug.getinfo(1, "S").source:match("@(.*/)")
        spoonPath = spoonPath .. "../ProfileRouter.spoon/"
        hs.spoons.scriptPath = function() return spoonPath end
        obj = dofile(spoonPath .. "init.lua")
    end)

    describe("init", function()
        it("returns self", function()
            assert.equals(obj, obj:init())
        end)
    end)

    describe("metadata", function()
        it("has required fields", function()
            assert.equals("ProfileRouter", obj.name)
            assert.is_not_nil(obj.version)
            assert.is_not_nil(obj.author)
            assert.is_not_nil(obj.license)
        end)
    end)

    describe("defaults", function()
        it("has nil browser by default", function()
            assert.is_nil(obj.browser)
        end)

        it("has nil profiles by default", function()
            assert.is_nil(obj.profiles)
        end)

        it("has 600s cooldown", function()
            assert.equals(600, obj.cooldownSeconds)
        end)

        it("has debug enabled", function()
            assert.is_true(obj.debug)
        end)

        it("routesDir points to ~/.hammerspoon/routes/", function()
            assert.truthy(obj.routesDir:find("/.hammerspoon/routes/$"))
        end)
    end)

    describe("start", function()
        it("returns self when no profiles found", function()
            local tmpDir = helper.tmpDir()
            obj.routesDir = tmpDir
            local result = obj:start()
            assert.equals(obj, result)
            helper.rmDir(tmpDir)
        end)

        it("sends notification when no profiles found", function()
            local notified = false
            hs.notify.new = function(_, opts)
                if opts and opts.informativeText and opts.informativeText:find("No route files") then
                    notified = true
                end
                return { send = function() end }
            end
            local tmpDir = helper.tmpDir()
            obj.routesDir = tmpDir
            obj:start()
            assert.is_true(notified)
            helper.rmDir(tmpDir)
        end)

        it("starts successfully with route files", function()
            local tmpDir = helper.tmpDir()
            helper.writeFile(tmpDir, "work.txt", "slack.com\n")
            helper.writeFile(tmpDir, "personal.txt", "youtube.com\n")
            obj.routesDir = tmpDir
            obj.debug = false
            local result = obj:start()
            assert.equals(obj, result)
            assert.is_not_nil(obj._profiles)
            assert.equals(2, #obj._profiles)
            obj:stop()
            helper.rmDir(tmpDir)
        end)

        it("uses explicit browser config", function()
            local tmpDir = helper.tmpDir()
            helper.writeFile(tmpDir, "work.txt", "slack.com\n")
            obj.routesDir = tmpDir
            obj.debug = false
            obj.browser = {
                name = "TestBrowser",
                bundleID = "com.test.browser",
                processName = "TestBrowser",
            }
            obj:start()
            assert.equals("TestBrowser", obj._browser.name)
            obj:stop()
            helper.rmDir(tmpDir)
        end)

        it("falls back to Dia when no browser detected", function()
            local tmpDir = helper.tmpDir()
            helper.writeFile(tmpDir, "work.txt", "slack.com\n")
            obj.routesDir = tmpDir
            obj.debug = false
            hs.application.find = function() return nil end
            obj:start()
            assert.equals("Dia", obj._browser.name)
            obj:stop()
            helper.rmDir(tmpDir)
        end)

        it("uses explicit profiles config", function()
            local tmpDir = helper.tmpDir()
            helper.writeFile(tmpDir, "w.txt", "slack.com\n")
            obj.routesDir = tmpDir
            obj.debug = false
            obj.profiles = {
                { name = "Alpha", routeFile = "w.txt" },
                { name = "Beta", isDefault = true },
            }
            obj:start()
            assert.equals(2, #obj._profiles)
            assert.equals("Alpha", obj._profiles[1].name)
            obj:stop()
            helper.rmDir(tmpDir)
        end)

        it("accepts custom cooldown setting", function()
            local tmpDir = helper.tmpDir()
            helper.writeFile(tmpDir, "work.txt", "slack.com\n")
            obj.routesDir = tmpDir
            obj.debug = false
            obj.cooldownSeconds = 120
            obj:start()
            assert.equals(120, obj.cooldownSeconds)
            obj:stop()
            helper.rmDir(tmpDir)
        end)
    end)

    describe("stop", function()
        it("cleans up watchers, timers, and hotkeys", function()
            local tmpDir = helper.tmpDir()
            helper.writeFile(tmpDir, "work.txt", "slack.com\n")
            obj.routesDir = tmpDir
            obj.debug = false
            obj:start()
            obj:bindHotkeys({ cycleTab = {{"ctrl"}, "s"} })
            obj:stop()

            local watcherCount = 0
            for _ in pairs(obj._watchers) do watcherCount = watcherCount + 1 end
            local timerCount = 0
            for _ in pairs(obj._timers) do timerCount = timerCount + 1 end
            local hotkeyCount = 0
            for _ in pairs(obj._hotkeys) do hotkeyCount = hotkeyCount + 1 end

            assert.equals(0, watcherCount)
            assert.equals(0, timerCount)
            assert.equals(0, hotkeyCount)
            helper.rmDir(tmpDir)
        end)

        it("returns self", function()
            assert.equals(obj, obj:stop())
        end)
    end)

    describe("bindHotkeys", function()
        it("registers cycleTab hotkey", function()
            obj:bindHotkeys({ cycleTab = {{"ctrl"}, "s"} })
            assert.is_not_nil(obj._hotkeys.cycleTab)
        end)

        it("returns self", function()
            local result = obj:bindHotkeys({ cycleTab = {{"ctrl"}, "s"} })
            assert.equals(obj, result)
        end)

        it("ignores unknown mappings", function()
            assert.has_no.errors(function()
                obj:bindHotkeys({ unknownAction = {{"ctrl"}, "x"} })
            end)
        end)
    end)

    describe("cycleTab", function()
        it("does nothing when browser not set", function()
            obj._browser = nil
            assert.has_no.errors(function()
                obj:cycleTab()
            end)
        end)

        it("does nothing when browser not frontmost", function()
            obj._browser = { bundleID = "com.test", name = "Test" }
            hs.application.frontmostApplication = function()
                return { bundleID = function() return "com.other" end }
            end
            assert.has_no.errors(function()
                obj:cycleTab()
            end)
        end)
    end)
end)
