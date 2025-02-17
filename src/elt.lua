local elt = {}

elt._COPYRIGHT   = 'Copyright (c) 2024 Alejandro Exojo Piqueras'
elt._DESCRIPTION = 'Template engine in pure Lua'
elt._VERSION = '0.1.0'

local function shared_new(self)
    return setmetatable({}, self)
end

--- Chunks helper class.
-- Simple helper that can be called to construct a new instance with a certain
-- metatable, and which has a convenient `append` function.
local Chunks = {
    CODE = 1,
    RAW = 2,
    ESCAPE = 3,

    new = shared_new,

    append = function(self, value, position, kind)
        assert(self and value and type(value) == 'string')
        assert((kind and position) or (not kind and not position))
        if not position then
            table.insert(self, value)
        else
            table.insert(self, {value, position, kind})
        end
    end,

}
Chunks.__index = Chunks




--- Generator class.
-- The class that generates the string of Lua code that will be compiled into
-- the function that renders the template.
local Generator = {
    new = function(self)
        local instance = shared_new(self)
        instance.buffer = {}
        return instance
    end,

    result = function(self)
        return table.concat(self.buffer)
    end,

    push = function(self, text, ...)
        table.insert(self.buffer, text)
        if ... then
          return self:push(...)
        end
    end,

    header = function(self)
        return self:push('local __buffer = ...\n')
    end,

    footer = function(self)
        return self:push('return __buffer\n')
    end,

    mark = function(self, pos)
        return self:push('--[[', tostring(pos), ']] ')
    end,

    assign = function(self, value)
        self:push('table.insert(__buffer, ', value, ')\n')
    end,

    generate = function(self, chunks)
        self.buffer = {}
        self:header()
        for _, chunk in ipairs(chunks) do
            local kind = type(chunk)
            -- If it's a string, it should be put as a string literal in the
            -- generated code, just escaping the quote symbols using format().
            if kind == 'string' then
                self:assign(('%q'):format(chunk))
            elseif kind == 'table' then
                local value = chunk[1]
                local position = chunk[2]
                kind = chunk[3]

                self:mark(position)
                -- If it's code, it's just added to the buffer, raw.
                if kind == Chunks.CODE then
                    self:push(value, '\n')
                -- Similar to the literal string, but converting to string (and
                -- perhaps escaping).
                elseif kind == Chunks.RAW then
                    self:assign('tostring(' .. value .. ')')
                elseif kind == Chunks.ESCAPE then
                    self:assign('escape(tostring(' .. value .. '))')
                end
            else
                error('unknown type ' .. tostring(kind))
            end
        end
        self:footer()
        return self:result()
    end
}
Generator.__index = Generator




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

