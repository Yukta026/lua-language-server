local parser  = require 'parser'
local guide   = require 'parser.guide'
local helper  = require 'plugins.astHelper'

---@diagnostic disable: await-in-sync
local function TestPlugin(script, plugin, checker)
    local state = parser.compile(script, "Lua", "Lua 5.4")
    state.ast = plugin(TESTURI, state.ast) or state.ast
    parser.luadoc(state)
    checker(state)
end

local function isDocClass(ast)
    return ast.bindDocs[1].type == 'doc.class'
end

local function TestAIsClass(state, next)
    assert(isDocClass(state.ast[1]))
end

--- when call Class
local function plugin_AddClass(uri, ast)
    guide.eachSourceType(ast, "call", function (source)
        local node = source.node
        if not guide.isGet(node) then
            return
        end
        if not guide.isGlobal(node) then
            return
        end
        if guide.getKeyName(node) ~= 'Class' then
            return
        end
        local wants = {
            ['local'] = true,
            ['setglobal'] = true
        }
        local classnameNode = guide.getParentTypes(source, wants)
        if not classnameNode then
            return
        end
        local classname = guide.getKeyName(classnameNode)
        if classname then
            helper.addClassDoc(ast, classnameNode, classname)
        end
    end)
end

local function plugin_AddClassAtParam(uri, ast)
    guide.eachSourceType(ast, "function", function (src)
        helper.addClassDocAtParam(ast, "A", src, 1)
    end)
end

local function TestSelfIsClass(state, next)
    guide.eachSourceType(state.ast, "local", function (source)
        if source[1] == 'self' then
            assert(source.bindDocs)
            assert(source.parent.type == 'function')
            assert(#source.parent.args == 0)
        end
    end)
end

local function TestPlugin1(script)
    TestPlugin(script, plugin_AddClass, TestAIsClass)
end

local function TestPlugin2(script)
    TestPlugin(script, plugin_AddClassAtParam, TestSelfIsClass)
end

TestPlugin1 [[
    local A = Class(function() end)
]]

TestPlugin1 [[
    A = Class(function() end)
]]

TestPlugin2 [[
    local function ctor(self) end
]]

TestPlugin2 [[
    function ctor(self) end
]]

require 'plugins.ast.helper'
