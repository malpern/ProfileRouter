local helper = {}

local projectRoot = debug.getinfo(1, "S").source:match("@(.*/)")
local spoonPath = projectRoot .. "../ProfileRouter.spoon/"

_G.hs = require("tests.hs_mock")
hs.spoons.scriptPath = function() return spoonPath end

function helper.loadModule(name)
    return dofile(spoonPath .. name .. ".lua")
end

function helper.tmpDir()
    local dir = os.tmpname() .. "_routes/"
    os.execute("mkdir -p " .. dir)
    return dir
end

function helper.writeFile(dir, filename, content)
    local f = io.open(dir .. filename, "w")
    f:write(content)
    f:close()
end

function helper.rmDir(dir)
    os.execute("rm -rf " .. dir)
end

function helper.makeProfiles(...)
    local list = {}
    for i, spec in ipairs({...}) do
        list[i] = {
            name = spec.name,
            titlePattern = spec.titlePattern,
            routeFile = spec.routeFile or (spec.name:lower() .. ".txt"),
            icon = spec.icon or "💼",
            isDefault = spec.isDefault or false,
            rules = spec.rules or { domains = {}, paths = {} },
        }
    end
    return list
end

return helper
