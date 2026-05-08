local helper = require("tests.test_helper")
local router = helper.loadModule("router")

describe("router", function()

    before_each(function()
        router._cooldowns = {}
        router._cooldownSeconds = 600
    end)

    describe("markRouted", function()
        it("records current time for URL", function()
            router.markRouted("https://example.com")
            assert.is_not_nil(router._cooldowns["https://example.com"])
        end)
    end)

    describe("isOnCooldown", function()
        it("returns false for unknown URL", function()
            assert.is_false(router.isOnCooldown("https://example.com"))
        end)

        it("returns true immediately after marking", function()
            router.markRouted("https://example.com")
            assert.is_true(router.isOnCooldown("https://example.com"))
        end)

        it("returns false after cooldown expires", function()
            router._cooldowns["https://example.com"] = os.time() - 601
            assert.is_false(router.isOnCooldown("https://example.com"))
        end)

        it("returns true just before cooldown expires", function()
            router._cooldowns["https://example.com"] = os.time() - 599
            assert.is_true(router.isOnCooldown("https://example.com"))
        end)

        it("cleans up expired entry on check", function()
            router._cooldowns["https://example.com"] = os.time() - 601
            router.isOnCooldown("https://example.com")
            assert.is_nil(router._cooldowns["https://example.com"])
        end)

        it("respects custom cooldown duration", function()
            router._cooldownSeconds = 10
            router._cooldowns["https://example.com"] = os.time() - 11
            assert.is_false(router.isOnCooldown("https://example.com"))
        end)
    end)

    describe("clearCooldown", function()
        it("removes cooldown for URL", function()
            router.markRouted("https://example.com")
            router.clearCooldown("https://example.com")
            assert.is_false(router.isOnCooldown("https://example.com"))
        end)

        it("does not error for unknown URL", function()
            assert.has_no.errors(function()
                router.clearCooldown("https://unknown.com")
            end)
        end)
    end)

    describe("cooldown isolation", function()
        it("cooldowns are per-URL", function()
            router.markRouted("https://a.com")
            router.markRouted("https://b.com")
            router.clearCooldown("https://a.com")
            assert.is_false(router.isOnCooldown("https://a.com"))
            assert.is_true(router.isOnCooldown("https://b.com"))
        end)
    end)
end)
