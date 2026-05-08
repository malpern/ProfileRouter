local helper = require("tests.test_helper")
local youtube = helper.loadModule("youtube")

describe("youtube", function()

    describe("isVideo", function()
        it("matches youtube.com/watch URLs", function()
            assert.truthy(youtube.isVideo("https://youtube.com/watch?v=abc123"))
        end)

        it("matches www.youtube.com/watch URLs", function()
            assert.truthy(youtube.isVideo("https://www.youtube.com/watch?v=abc123"))
        end)

        it("matches youtu.be short URLs", function()
            assert.truthy(youtube.isVideo("https://youtu.be/abc123"))
        end)

        it("rejects youtube.com homepage", function()
            assert.falsy(youtube.isVideo("https://youtube.com"))
        end)

        it("rejects youtube.com/channel", function()
            assert.falsy(youtube.isVideo("https://youtube.com/channel/UC123"))
        end)

        it("rejects youtube.com/playlist", function()
            assert.falsy(youtube.isVideo("https://youtube.com/playlist?list=PL123"))
        end)

        it("rejects non-youtube URLs", function()
            assert.falsy(youtube.isVideo("https://vimeo.com/watch/123"))
        end)
    end)

    describe("appendTimestamp", function()
        it("appends timestamp with ? when no query params", function()
            local url = youtube.appendTimestamp("https://youtube.com/watch", 120)
            assert.equals("https://youtube.com/watch?t=120s", url)
        end)

        it("appends timestamp with & when query params exist", function()
            local url = youtube.appendTimestamp("https://youtube.com/watch?v=abc", 90)
            assert.equals("https://youtube.com/watch?v=abc&t=90s", url)
        end)

        it("replaces existing t= parameter", function()
            local url = youtube.appendTimestamp("https://youtube.com/watch?v=abc&t=30s", 120)
            assert.equals("https://youtube.com/watch?v=abc&t=120s", url)
        end)

        it("replaces existing t= without s suffix", function()
            local url = youtube.appendTimestamp("https://youtube.com/watch?v=abc&t=30", 120)
            assert.equals("https://youtube.com/watch?v=abc&t=120s", url)
        end)

        it("replaces t= when it is the only param", function()
            local url = youtube.appendTimestamp("https://youtube.com/watch?t=30s", 120)
            assert.equals("https://youtube.com/watch?t=120s", url)
        end)

        it("returns original URL for nil seconds", function()
            local url = youtube.appendTimestamp("https://youtube.com/watch?v=abc", nil)
            assert.equals("https://youtube.com/watch?v=abc", url)
        end)

        it("returns original URL for zero seconds", function()
            local url = youtube.appendTimestamp("https://youtube.com/watch?v=abc", 0)
            assert.equals("https://youtube.com/watch?v=abc", url)
        end)

        it("returns original URL for negative seconds", function()
            local url = youtube.appendTimestamp("https://youtube.com/watch?v=abc", -5)
            assert.equals("https://youtube.com/watch?v=abc", url)
        end)
    end)
end)
