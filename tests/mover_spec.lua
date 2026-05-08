local helper = require("tests.test_helper")
local mover = helper.loadModule("mover")

describe("mover", function()

    describe("findProfileWindow", function()
        local function makeWindow(title)
            return { title = function() return title end, id = function() return title end }
        end

        local function makeApp(titles)
            local windows = {}
            for _, t in ipairs(titles) do windows[#windows + 1] = makeWindow(t) end
            return { allWindows = function() return windows end }
        end

        it("finds window by titlePattern", function()
            local app = makeApp({ "Work: Slack", "Personal Tab" })
            local profile = { name = "Work", titlePattern = "Work:", isDefault = false }
            local w = mover.findProfileWindow(app, profile, {})
            assert.is_not_nil(w)
            assert.equals("Work: Slack", w:title())
        end)

        it("finds default window (unclaimed)", function()
            local app = makeApp({ "Work: Slack", "Google - New Tab" })
            local profiles = {
                { name = "Work", titlePattern = "Work:", isDefault = false },
                { name = "Personal", titlePattern = nil, isDefault = true },
            }
            local w = mover.findProfileWindow(app, profiles[2], profiles)
            assert.is_not_nil(w)
            assert.equals("Google - New Tab", w:title())
        end)

        it("returns nil when no matching window", function()
            local app = makeApp({ "Google - New Tab" })
            local profile = { name = "School", titlePattern = "School:", isDefault = false }
            local w = mover.findProfileWindow(app, profile, {})
            assert.is_nil(w)
        end)

        it("returns nil for nil app", function()
            local profile = { name = "Work", titlePattern = "Work:", isDefault = false }
            assert.is_nil(mover.findProfileWindow(nil, profile, {}))
        end)

        it("does not return claimed windows as default", function()
            local app = makeApp({ "Work: Slack", "School: Canvas" })
            local profiles = {
                { name = "Work",   titlePattern = "Work:",   isDefault = false },
                { name = "School", titlePattern = "School:", isDefault = false },
                { name = "Personal", titlePattern = nil, isDefault = true },
            }
            local w = mover.findProfileWindow(app, profiles[3], profiles)
            assert.is_nil(w)
        end)
    end)

    describe("getWindowIndex", function()
        it("returns correct index", function()
            local windows = {
                { id = function() return 1 end },
                { id = function() return 2 end },
                { id = function() return 3 end },
            }
            local app = { allWindows = function() return windows end }
            assert.equals(2, mover.getWindowIndex(app, windows[2]))
        end)

        it("returns 1 when window not found", function()
            local windows = {
                { id = function() return 1 end },
            }
            local app = { allWindows = function() return windows end }
            local unknown = { id = function() return 99 end }
            assert.equals(1, mover.getWindowIndex(app, unknown))
        end)
    end)
end)
