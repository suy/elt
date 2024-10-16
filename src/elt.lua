local elt = {}

elt._COPYRIGHT   = 'Copyright (c) 2024 Alejandro Exojo Piqueras'
elt._DESCRIPTION = 'Template engine in pure Lua'
elt._VERSION = '0.1.0'

--- Chunks helper class.
-- Simple helper that can be called to construct a new instance with a certain
-- metatable, and which has a convenient `append` function.
local Chunks = {}
Chunks.CODE = 1
Chunks.RAW = 2
Chunks.ESCAPE = 3

function Chunks:append(value, position, kind)
    assert(self and value and type(value) == 'string')
    assert((kind and position) or (not kind and not position))
    if not position then
        table.insert(self, value)
    else
        table.insert(self, {value, position, kind})
    end
end

Chunks.__index = Chunks

setmetatable(Chunks, {
    __call = function()
        return setmetatable({}, Chunks)
    end
})


local Generator = {}
local Parser = {}

elt.Chunks = Chunks
elt.Generator = Generator
elt.Parser = Parser


elt.compile = function(...)
    local parser = Parser()
    return parser:compile(...)
end


elt.render = function(text, ...)
    local compiled, message = elt.compile(text)
    if compiled then
        return compiled(...)
    else
        return nil, message
    end
end

return elt

