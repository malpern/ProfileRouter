local helper = require("tests.test_helper")
local profiles = helper.loadModule("profiles")

describe("profiles", function()

    -- ── matchURL ──

    describe("matchURL", function()
        local profileList

        before_each(function()
            profileList = helper.makeProfiles(
                { name = "Work",     titlePattern = "Work:",  rules = {
                    domains = { "slack.com", "figma.com", "linear.app" },
                    paths = { "github.com/myorg" },
                }},
                { name = "Personal", isDefault = true, rules = {
                    domains = { "youtube.com", "reddit.com" },
                    paths = { "github.com/malpern" },
                }}
            )
        end)

        it("matches exact domain", function()
            local p = profiles.matchURL("https://slack.com/messages", profileList)
            assert.is_not_nil(p)
            assert.equals("Work", p.name)
        end)

        it("matches subdomain", function()
            local p = profiles.matchURL("https://app.slack.com/client", profileList)
            assert.is_not_nil(p)
            assert.equals("Work", p.name)
        end)

        it("matches path rule", function()
            local p = profiles.matchURL("https://github.com/myorg/some-repo", profileList)
            assert.is_not_nil(p)
            assert.equals("Work", p.name)
        end)

        it("matches path rule for second profile", function()
            local p = profiles.matchURL("https://github.com/malpern/dotfiles", profileList)
            assert.is_not_nil(p)
            assert.equals("Personal", p.name)
        end)

        it("returns nil for unmatched URL", function()
            local p = profiles.matchURL("https://example.com", profileList)
            assert.is_nil(p)
        end)

        it("returns nil for invalid URL", function()
            local p = profiles.matchURL("not-a-url", profileList)
            assert.is_nil(p)
        end)

        it("is case-insensitive for domains", function()
            local p = profiles.matchURL("https://SLACK.COM/foo", profileList)
            assert.is_not_nil(p)
            assert.equals("Work", p.name)
        end)

        it("does not match partial domain", function()
            local p = profiles.matchURL("https://notslack.com", profileList)
            assert.is_nil(p)
        end)

        it("matches first matching profile when rules overlap", function()
            profileList[2].rules.domains[#profileList[2].rules.domains + 1] = "slack.com"
            local p = profiles.matchURL("https://slack.com", profileList)
            assert.equals("Work", p.name)
        end)

        it("handles URL with port", function()
            local p = profiles.matchURL("https://slack.com:443/foo", profileList)
            assert.is_not_nil(p)
            assert.equals("Work", p.name)
        end)

        it("handles URL with query string", function()
            local p = profiles.matchURL("https://youtube.com/watch?v=abc", profileList)
            assert.is_not_nil(p)
            assert.equals("Personal", p.name)
        end)

        it("handles URL with fragment", function()
            local p = profiles.matchURL("https://reddit.com/r/lua#top", profileList)
            assert.is_not_nil(p)
            assert.equals("Personal", p.name)
        end)
    end)

    -- ── detectCurrent ──

    describe("detectCurrent", function()
        local profileList

        before_each(function()
            profileList = helper.makeProfiles(
                { name = "Work",     titlePattern = "Work:" },
                { name = "School",   titlePattern = "School:" },
                { name = "Personal", isDefault = true }
            )
        end)

        it("detects profile by title pattern", function()
            local p = profiles.detectCurrent("Work: Slack", profileList)
            assert.equals("Work", p.name)
        end)

        it("detects second profile by title pattern", function()
            local p = profiles.detectCurrent("School: Canvas", profileList)
            assert.equals("School", p.name)
        end)

        it("falls back to default for unrecognized title", function()
            local p = profiles.detectCurrent("Google - New Tab", profileList)
            assert.equals("Personal", p.name)
        end)

        it("returns first profile when no default and no match", function()
            for _, p in ipairs(profileList) do p.isDefault = false end
            local p = profiles.detectCurrent("Random Title", profileList)
            assert.equals("Work", p.name)
        end)

        it("returns nil for nil title", function()
            local p = profiles.detectCurrent(nil, profileList)
            assert.is_nil(p)
        end)

        it("matches title pattern anywhere in string", function()
            local p = profiles.detectCurrent("Tab - Work: Figma", profileList)
            assert.equals("Work", p.name)
        end)
    end)

    -- ── findNext ──

    describe("findNext", function()
        it("cycles to next profile", function()
            local list = helper.makeProfiles(
                { name = "A" }, { name = "B" }, { name = "C" }
            )
            assert.equals("B", profiles.findNext("A", list).name)
            assert.equals("C", profiles.findNext("B", list).name)
        end)

        it("wraps around to first", function()
            local list = helper.makeProfiles(
                { name = "A" }, { name = "B" }, { name = "C" }
            )
            assert.equals("A", profiles.findNext("C", list).name)
        end)

        it("toggles with two profiles", function()
            local list = helper.makeProfiles({ name = "Work" }, { name = "Personal" })
            assert.equals("Personal", profiles.findNext("Work", list).name)
            assert.equals("Work", profiles.findNext("Personal", list).name)
        end)

        it("returns first when name not found", function()
            local list = helper.makeProfiles({ name = "A" }, { name = "B" })
            assert.equals("A", profiles.findNext("Unknown", list).name)
        end)
    end)

    -- ── loadRules ──

    describe("loadRules", function()
        local tmpDir

        before_each(function()
            tmpDir = helper.tmpDir()
        end)

        after_each(function()
            helper.rmDir(tmpDir)
        end)

        it("parses domain rules", function()
            helper.writeFile(tmpDir, "work.txt", "slack.com\nfigma.com\n")
            local rules = profiles.loadRules(tmpDir, "work.txt")
            assert.equals(2, #rules.domains)
            assert.equals("slack.com", rules.domains[1])
            assert.equals("figma.com", rules.domains[2])
            assert.equals(0, #rules.paths)
        end)

        it("parses path rules", function()
            helper.writeFile(tmpDir, "work.txt", "path:github.com/myorg\n")
            local rules = profiles.loadRules(tmpDir, "work.txt")
            assert.equals(0, #rules.domains)
            assert.equals(1, #rules.paths)
            assert.equals("github.com/myorg", rules.paths[1])
        end)

        it("ignores comments and blank lines", function()
            helper.writeFile(tmpDir, "work.txt", "# comment\n\nslack.com\n  \n# another\nfigma.com\n")
            local rules = profiles.loadRules(tmpDir, "work.txt")
            assert.equals(2, #rules.domains)
        end)

        it("strips whitespace", function()
            helper.writeFile(tmpDir, "work.txt", "  slack.com  \n")
            local rules = profiles.loadRules(tmpDir, "work.txt")
            assert.equals("slack.com", rules.domains[1])
        end)

        it("lowercases domains", function()
            helper.writeFile(tmpDir, "work.txt", "SLACK.COM\n")
            local rules = profiles.loadRules(tmpDir, "work.txt")
            assert.equals("slack.com", rules.domains[1])
        end)

        it("strips protocol from domain entries", function()
            helper.writeFile(tmpDir, "work.txt", "https://slack.com/foo\n")
            local rules = profiles.loadRules(tmpDir, "work.txt")
            assert.equals("slack.com", rules.domains[1])
        end)

        it("returns empty rules for missing file", function()
            local rules = profiles.loadRules(tmpDir, "nonexistent.txt")
            assert.equals(0, #rules.domains)
            assert.equals(0, #rules.paths)
        end)
    end)

    -- ── discover ──

    describe("discover", function()
        local tmpDir

        before_each(function()
            tmpDir = helper.tmpDir()
        end)

        after_each(function()
            helper.rmDir(tmpDir)
        end)

        it("discovers profiles from txt files", function()
            helper.writeFile(tmpDir, "work.txt", "slack.com\n")
            helper.writeFile(tmpDir, "personal.txt", "youtube.com\n")
            local list = profiles.discover(tmpDir)
            assert.equals(2, #list)
        end)

        it("capitalizes profile names", function()
            helper.writeFile(tmpDir, "work.txt", "")
            local list = profiles.discover(tmpDir)
            assert.equals("Work", list[1].name)
        end)

        it("sets last profile as default", function()
            helper.writeFile(tmpDir, "aaa.txt", "")
            helper.writeFile(tmpDir, "zzz.txt", "")
            local list = profiles.discover(tmpDir)
            assert.is_false(list[1].isDefault)
            assert.is_true(list[#list].isDefault)
            assert.is_nil(list[#list].titlePattern)
        end)

        it("returns empty list for empty directory", function()
            local list = profiles.discover(tmpDir)
            assert.equals(0, #list)
        end)

        it("sets titlePattern for non-default profiles", function()
            helper.writeFile(tmpDir, "work.txt", "")
            helper.writeFile(tmpDir, "personal.txt", "")
            local list = profiles.discover(tmpDir)
            local nonDefault = list[1]
            assert.is_not_nil(nonDefault.titlePattern)
            assert.truthy(nonDefault.titlePattern:find(nonDefault.name, 1, true))
        end)
    end)

    -- ── resolve ──

    describe("resolve", function()
        local tmpDir

        before_each(function()
            tmpDir = helper.tmpDir()
        end)

        after_each(function()
            helper.rmDir(tmpDir)
        end)

        it("uses user-provided profiles", function()
            local userProfiles = {
                { name = "Work", titlePattern = "Work:", routeFile = "work.txt" },
                { name = "Personal", isDefault = true, routeFile = "personal.txt" },
            }
            local list = profiles.resolve(userProfiles, tmpDir)
            assert.equals(2, #list)
            assert.equals("Work", list[1].name)
        end)

        it("falls back to discover when no user profiles", function()
            helper.writeFile(tmpDir, "work.txt", "slack.com\n")
            local list = profiles.resolve(nil, tmpDir)
            assert.equals(1, #list)
            assert.equals("Work", list[1].name)
        end)

        it("ensures exactly one default in user profiles", function()
            local userProfiles = {
                { name = "A" },
                { name = "B" },
            }
            local list = profiles.resolve(userProfiles, tmpDir)
            local defaults = 0
            for _, p in ipairs(list) do
                if p.isDefault then defaults = defaults + 1 end
            end
            assert.equals(1, defaults)
            assert.is_true(list[#list].isDefault)
        end)

        it("assigns default icon when none provided", function()
            local userProfiles = { { name = "Test" } }
            local list = profiles.resolve(userProfiles, tmpDir)
            assert.is_not_nil(list[1].icon)
        end)

        it("generates routeFile from name when not provided", function()
            local userProfiles = { { name = "Work" } }
            local list = profiles.resolve(userProfiles, tmpDir)
            assert.equals("work.txt", list[1].routeFile)
        end)
    end)

    -- ── loadAllRules ──

    describe("loadAllRules", function()
        local tmpDir

        before_each(function()
            tmpDir = helper.tmpDir()
        end)

        after_each(function()
            helper.rmDir(tmpDir)
        end)

        it("loads rules for all profiles", function()
            helper.writeFile(tmpDir, "work.txt", "slack.com\nfigma.com\n")
            helper.writeFile(tmpDir, "personal.txt", "youtube.com\n")
            local list = helper.makeProfiles(
                { name = "Work", routeFile = "work.txt" },
                { name = "Personal", routeFile = "personal.txt", isDefault = true }
            )
            profiles.loadAllRules(list, tmpDir)
            assert.equals(2, #list[1].rules.domains)
            assert.equals(1, #list[2].rules.domains)
        end)
    end)
end)
