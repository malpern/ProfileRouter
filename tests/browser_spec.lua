local helper = require("tests.test_helper")
local browser = helper.loadModule("browser")

describe("browser", function()

    describe("KNOWN", function()
        it("has Dia as first entry", function()
            assert.equals("Dia", browser.KNOWN[1].name)
        end)

        it("has Chrome as second entry", function()
            assert.equals("Google Chrome", browser.KNOWN[2].name)
        end)

        it("all entries have required fields", function()
            for _, b in ipairs(browser.KNOWN) do
                assert.is_not_nil(b.name)
                assert.is_not_nil(b.bundleID)
                assert.is_not_nil(b.processName)
                assert.is_not_nil(b.jsWarning)
            end
        end)
    end)

    describe("detect", function()
        it("returns nil when no browser is running", function()
            hs.application.find = function() return nil end
            assert.is_nil(browser.detect())
        end)

        it("returns Dia when Dia is running", function()
            hs.application.find = function(bid)
                if bid == "company.thebrowser.dia" then return {} end
                return nil
            end
            local b = browser.detect()
            assert.equals("Dia", b.name)
        end)

        it("prefers Dia over Chrome", function()
            hs.application.find = function() return {} end
            local b = browser.detect()
            assert.equals("Dia", b.name)
        end)

        it("returns Chrome when only Chrome is running", function()
            hs.application.find = function(bid)
                if bid == "com.google.Chrome" then return {} end
                return nil
            end
            local b = browser.detect()
            assert.equals("Google Chrome", b.name)
        end)
    end)

    describe("getURL", function()
        it("returns URL when AppleScript succeeds", function()
            hs.osascript.applescript = function()
                return true, "https://example.com/page"
            end
            local url = browser.getURL(browser.KNOWN[1], 1)
            assert.equals("https://example.com/page", url)
        end)

        it("returns nil when AppleScript fails", function()
            hs.osascript.applescript = function() return false, nil end
            assert.is_nil(browser.getURL(browser.KNOWN[1], 1))
        end)

        it("returns nil for non-http URLs", function()
            hs.osascript.applescript = function()
                return true, "chrome://settings"
            end
            assert.is_nil(browser.getURL(browser.KNOWN[1], 1))
        end)

        it("defaults to window 1", function()
            local capturedScript
            hs.osascript.applescript = function(script)
                capturedScript = script
                return true, "https://example.com"
            end
            browser.getURL(browser.KNOWN[1])
            assert.truthy(capturedScript:find("window 1", 1, true))
        end)
    end)
end)
