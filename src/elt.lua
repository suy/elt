local elt = {}

elt._COPYRIGHT   = 'Copyright (c) 2024 Alejandro Exojo Piqueras'
elt._DESCRIPTION = 'Template engine in pure Lua'
elt._VERSION = '0.1.0'

local Generator = {}
local Parser = {}

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

